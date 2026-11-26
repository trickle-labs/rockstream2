use slatedb::object_store::{path::Path, ObjectStore, ObjectStoreExt, PutMode};
use slatedb::{Db, WriteBatch};
use std::{collections::BTreeMap, error::Error, sync::Arc};

type Groups = BTreeMap<String, (i64, i64)>;
type Orders = BTreeMap<i64, (i64, i64)>;

fn evaluate(customers: &BTreeMap<i64, String>, orders: &Orders) -> Groups {
    let mut rows = BTreeMap::new();
    for (id, region) in customers {
        for (customer, cents) in orders.values() {
            if customer == id {
                let entry = rows.entry(region.clone()).or_insert((0_i64, 0_i64));
                entry.0 = entry.0.checked_add(1).expect("count overflow");
                entry.1 = entry.1.checked_add(*cents).expect("sum overflow");
            }
        }
    }
    rows
}

fn encode(row: Option<&(i64, i64)>) -> String {
    row.map_or_else(|| "-".to_owned(), |(count, sum)| format!("{count},{sum}"))
}

async fn reconstruct(
    store: &Arc<dyn ObjectStore>,
    expected_cut: u8,
) -> Result<Groups, Box<dyn Error>> {
    let root = store.get(&Path::from("w1g/root")).await?.bytes().await?;
    let root = std::str::from_utf8(&root)?;
    let cut: u8 = root.split(':').next().ok_or("missing root cut")?.parse()?;
    assert_eq!(cut, expected_cut);
    if cut > 4 {
        return Err("unexpected root cut".into());
    }
    let mut rows = Groups::new();
    for epoch_cut in 1..=cut {
        let delta = store
            .get(&Path::from(format!("w1g/deltas/{epoch_cut}")))
            .await?
            .bytes()
            .await?;
        let mut seen = BTreeMap::new();
        for line in std::str::from_utf8(&delta)?.lines() {
            let (region, value) = line.split_once('=').ok_or("invalid delta")?;
            if !["North", "South"].contains(&region) || seen.insert(region, ()).is_some() {
                return Err("invalid or duplicate region".into());
            }
            if value == "-" {
                rows.remove(region);
            } else {
                let (count, sum) = value.split_once(',').ok_or("invalid result")?;
                rows.insert(region.to_owned(), (count.parse()?, sum.parse()?));
            }
        }
    }
    Ok(rows)
}

pub async fn run(store: Arc<dyn ObjectStore>) -> Result<(), Box<dyn Error>> {
    let fixture = include_str!("../../../../fixtures/w1g/transactions.csv");
    let golden = include_str!("../../../../fixtures/w1g/expected.csv");
    let mut expected = BTreeMap::<u8, Groups>::new();
    for line in golden
        .lines()
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
    {
        let f: Vec<_> = line.split(',').collect();
        expected
            .entry(f[0].parse()?)
            .or_default()
            .insert(f[1].into(), (f[2].parse()?, f[3].parse()?));
    }
    let mut epochs = BTreeMap::<u8, Vec<&str>>::new();
    for line in fixture
        .lines()
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
    {
        let epoch = line.split(',').next().ok_or("missing epoch")?.parse()?;
        epochs.entry(epoch).or_default().push(line);
    }
    let index = Db::open("w1g/delta-index", store.clone()).await?;
    let history = Db::open("w1g/pure-history", store.clone()).await?;
    let mut customers = BTreeMap::new();
    let mut orders = Orders::new();
    let mut overlay = BTreeMap::<String, String>::new();
    let mut root_version = None;
    let mut snapshots = Vec::new();
    let mut previous = Groups::new();
    let mut checkpoint_id = String::new();
    let mut saw_overlay_difference = false;
    for (epoch, lines) in epochs {
        for line in lines {
            let f: Vec<_> = line.split(',').collect();
            let weight: i8 = f[2].parse()?;
            let id: i64 = f[3].parse()?;
            match (f[1], weight) {
                ("customer", 1) => assert!(customers.insert(id, f[4].to_owned()).is_none()),
                ("customer", -1) => assert_eq!(customers.remove(&id).as_deref(), Some(f[4])),
                ("order", 1) => {
                    assert!(orders.insert(id, (f[4].parse()?, f[5].parse()?)).is_none())
                }
                ("order", -1) => {
                    assert_eq!(orders.remove(&id), Some((f[4].parse()?, f[5].parse()?)))
                }
                _ => return Err("invalid W1-G transaction".into()),
            }
        }
        let cut = epoch.checked_add(1).ok_or("cut overflow")?;
        let result = evaluate(&customers, &orders);
        assert_eq!(result, w1g_oracle::evaluate(&customers, &orders));
        assert_eq!(result, expected.remove(&cut).unwrap_or_default());
        let mut delta = String::new();
        let mut batch = WriteBatch::new();
        for region in ["North", "South"] {
            let value = encode(result.get(region));
            if value != encode(previous.get(region)) {
                delta.push_str(&format!("{region}={value}\n"));
                overlay.insert(region.to_owned(), value.clone());
                if overlay.len() > 2 || overlay.values().map(String::len).sum::<usize>() > 128 {
                    return Err("W1-G overlay cap exceeded".into());
                }
            }
            batch.put(format!("cut/{cut}/{region}"), value.as_bytes());
        }
        let delta_path = Path::from(format!("w1g/deltas/{cut}"));
        store
            .put_opts(&delta_path, delta.clone().into(), PutMode::Create.into())
            .await?;
        assert_eq!(
            store.get(&delta_path).await?.bytes().await?.as_ref(),
            delta.as_bytes()
        );
        let mode = match root_version.take() {
            Some(version) => PutMode::Update(version),
            None => PutMode::Create,
        };
        root_version = Some(
            store
                .put_opts(
                    &Path::from("w1g/root"),
                    format!("{cut}:{checkpoint_id}").into(),
                    mode.into(),
                )
                .await?
                .into(),
        );
        assert_eq!(reconstruct(&store, cut).await?, result);
        history.write(batch).await?.await_durable().await?;
        for region in ["North", "South"] {
            let base = index.get(region.as_bytes()).await?;
            let base = base.as_deref().unwrap_or(b"-");
            let current = overlay.get(region).map_or(base, |value| value.as_bytes());
            assert_eq!(current, encode(result.get(region)).as_bytes());
            saw_overlay_difference |= base != current;
            let stored = history
                .get(format!("cut/{cut}/{region}"))
                .await?
                .ok_or("missing history")?;
            assert_eq!(stored.as_ref(), encode(result.get(region)).as_bytes());
        }
        snapshots.push(result.clone());
        previous = result.clone();
        if cut == 2 {
            let mut batch = WriteBatch::new();
            for (region, value) in &overlay {
                batch.put(region.as_bytes(), value.as_bytes());
            }
            batch.put(b"_meta/applied_cut", b"2");
            index.write(batch).await?.await_durable().await?;
            let checkpoint = index
                .create_checkpoint(
                    slatedb::config::CheckpointScope::All,
                    &slatedb::config::CheckpointOptions::default(),
                )
                .await?;
            let version = root_version.take().ok_or("missing root version")?;
            checkpoint_id = checkpoint.id.to_string();
            root_version = Some(
                store
                    .put_opts(
                        &Path::from("w1g/root"),
                        format!("{cut}:{}", checkpoint.id).into(),
                        PutMode::Update(version).into(),
                    )
                    .await?
                    .into(),
            );
            overlay.clear();
            for region in ["North", "South"] {
                assert_eq!(
                    index.get(region.as_bytes()).await?.as_deref(),
                    Some(encode(result.get(region)).as_bytes())
                );
            }
        }
    }
    assert!(expected.is_empty());
    assert_eq!(snapshots.len(), 4);
    assert!(saw_overlay_difference);
    history.close().await?;
    index.close().await?;
    let reopened_history = Db::open("w1g/pure-history", store.clone()).await?;
    let reopened_index = Db::open("w1g/delta-index", store.clone()).await?;
    assert_eq!(reconstruct(&store, 4).await?, snapshots[3]);
    for region in ["North", "South"] {
        let past = reopened_history
            .get(format!("cut/2/{region}"))
            .await?
            .ok_or("missing retained cut")?;
        assert_eq!(past.as_ref(), encode(snapshots[1].get(region)).as_bytes());
        assert_eq!(
            reopened_index.get(region.as_bytes()).await?.as_deref(),
            Some(encode(snapshots[1].get(region)).as_bytes())
        );
    }
    store
        .put_opts(
            &Path::from("w1g/deltas/5"),
            "South=999,999".into(),
            PutMode::Create.into(),
        )
        .await?;
    assert_eq!(reconstruct(&store, 4).await?, snapshots[3]);
    store.delete(&Path::from("w1g/deltas/2")).await?;
    assert!(reconstruct(&store, 4).await.is_err());
    reopened_index.close().await?;
    reopened_history.close().await?;
    println!("W1G-COMPARED");
    Ok(())
}
