use sha2::{Digest, Sha256};
use slatedb::object_store::{path::Path, ObjectStore, ObjectStoreExt, PutMode};
use slatedb::{Db, WriteBatch};
use std::{
    collections::BTreeMap,
    error::Error,
    io::{self, Write},
    sync::Arc,
};

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
    namespace: &str,
    expected_cut: u8,
) -> Result<Groups, Box<dyn Error>> {
    let root = store
        .get(&Path::from(format!("{namespace}/root")))
        .await?
        .bytes()
        .await?;
    let root = std::str::from_utf8(&root)?;
    let parts: Vec<_> = root.split(':').collect();
    if parts.len() != 3 {
        return Err("invalid root".into());
    }
    let cut: u8 = parts[0].parse()?;
    assert_eq!(cut, expected_cut);
    if cut > 4 {
        return Err("unexpected root cut".into());
    }
    let digests: Vec<_> = parts[2].split(',').collect();
    if digests.len() != usize::from(cut) {
        return Err("invalid delta coverage".into());
    }
    let mut rows = Groups::new();
    for epoch_cut in 1..=cut {
        let delta = store
            .get(&Path::from(format!("{namespace}/deltas/{epoch_cut}")))
            .await?
            .bytes()
            .await?;
        if format!("{:x}", Sha256::digest(&delta)) != digests[usize::from(epoch_cut - 1)] {
            return Err("W1-G delta digest mismatch".into());
        }
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

pub async fn run(
    store: Arc<dyn ObjectStore>,
    namespace: &str,
    crash: &str,
) -> Result<(), Box<dyn Error>> {
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
    let index = Db::open(format!("{namespace}/delta-index"), store.clone()).await?;
    let history = Db::open(format!("{namespace}/pure-history"), store.clone()).await?;
    let mut customers = BTreeMap::new();
    let mut orders = Orders::new();
    let mut overlay = BTreeMap::<String, String>::new();
    let mut root_version = None;
    let mut snapshots = Vec::new();
    let mut previous = Groups::new();
    let mut checkpoint_id = String::new();
    let mut digests = Vec::new();
    let mut saw_overlay_difference = false;
    let mut delta_payload_bytes = 0usize;
    let mut history_value_bytes = 0usize;
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
            history_value_bytes = history_value_bytes
                .checked_add(value.len())
                .ok_or("history byte count overflow")?;
            batch.put(format!("cut/{cut}/{region}"), value.as_bytes());
        }
        delta_payload_bytes = delta_payload_bytes
            .checked_add(delta.len())
            .ok_or("delta byte count overflow")?;
        let delta_path = Path::from(format!("{namespace}/deltas/{cut}"));
        store
            .put_opts(&delta_path, delta.clone().into(), PutMode::Create.into())
            .await?;
        assert_eq!(
            store.get(&delta_path).await?.bytes().await?.as_ref(),
            delta.as_bytes()
        );
        digests.push(format!("{:x}", Sha256::digest(delta.as_bytes())));
        let mode = match root_version.take() {
            Some(version) => PutMode::Update(version),
            None => PutMode::Create,
        };
        root_version = Some(
            store
                .put_opts(
                    &Path::from(format!("{namespace}/root")),
                    format!("{cut}:{checkpoint_id}:{}", digests.join(",")).into(),
                    mode.into(),
                )
                .await?
                .into(),
        );
        assert_eq!(reconstruct(&store, namespace, cut).await?, result);
        if crash == "root" && cut == 3 {
            println!("READY");
            io::stdout().flush()?;
            std::future::pending::<()>().await;
        }
        history.write(batch).await?.await_durable().await?;
        if crash == "mid" && cut == 3 {
            let mut partial = WriteBatch::new();
            partial.put(b"North", encode(result.get("North")).as_bytes());
            partial.put(b"_meta/dirty", b"1");
            index.write(partial).await?.await_durable().await?;
            println!("READY");
            io::stdout().flush()?;
            std::future::pending::<()>().await;
        }
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
                        &Path::from(format!("{namespace}/root")),
                        format!("{cut}:{}:{}", checkpoint.id, digests.join(",")).into(),
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
    let reopened_history = Db::open(format!("{namespace}/pure-history"), store.clone()).await?;
    let reopened_index = Db::open(format!("{namespace}/delta-index"), store.clone()).await?;
    assert_eq!(reconstruct(&store, namespace, 4).await?, snapshots[3]);
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
            &Path::from(format!("{namespace}/deltas/5")),
            "South=999,999".into(),
            PutMode::Create.into(),
        )
        .await?;
    assert_eq!(reconstruct(&store, namespace, 4).await?, snapshots[3]);
    store
        .put(
            &Path::from(format!("{namespace}/deltas/2")),
            "South=999,999".into(),
        )
        .await?;
    let error = reconstruct(&store, namespace, 4).await.unwrap_err();
    assert!(error.to_string().contains("digest mismatch"));
    store
        .delete(&Path::from(format!("{namespace}/deltas/2")))
        .await?;
    assert!(reconstruct(&store, namespace, 4).await.is_err());
    reopened_index.close().await?;
    reopened_history.close().await?;
    println!("W1G-COMPARED delta_payload_bytes={delta_payload_bytes} history_value_bytes={history_value_bytes}");
    Ok(())
}

pub async fn recover(
    store: Arc<dyn ObjectStore>,
    namespace: &str,
    reuse_dirty: bool,
) -> Result<(), Box<dyn Error>> {
    let root = store
        .get(&Path::from(format!("{namespace}/root")))
        .await?
        .bytes()
        .await?;
    let root = std::str::from_utf8(&root)?;
    let fields: Vec<_> = root.split(':').collect();
    if fields.len() != 3 || fields[0] != "3" {
        return Err("invalid recovery root".into());
    }
    let checkpoint = uuid::Uuid::parse_str(fields[1])?;
    let result = reconstruct(&store, namespace, 3).await?;
    let mut golden = BTreeMap::<u8, Groups>::new();
    for line in include_str!("../../../../fixtures/w1g/expected.csv")
        .lines()
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
    {
        let f: Vec<_> = line.split(',').collect();
        golden
            .entry(f[0].parse()?)
            .or_default()
            .insert(f[1].into(), (f[2].parse()?, f[3].parse()?));
    }
    assert_eq!(result, *golden.get(&3).ok_or("missing cut 3")?);
    let source = format!("{namespace}/delta-index");
    let dirty = Db::open(source.clone(), store.clone()).await?;
    assert_eq!(
        dirty.get(b"_meta/dirty").await?.as_deref(),
        Some(b"1".as_slice())
    );
    assert_eq!(
        dirty.get(b"_meta/applied_cut").await?.as_deref(),
        Some(b"2".as_slice())
    );
    dirty.close().await?;
    let target = if reuse_dirty {
        source.clone()
    } else {
        let target = format!("{namespace}/takeover-index");
        let admin = slatedb::admin::AdminBuilder::new(target.clone(), store.clone()).build();
        admin
            .create_clone_builder_from_source(slatedb::admin::CloneSourceSpec::with_checkpoint(
                source, checkpoint,
            ))
            .build()
            .await?;
        target
    };
    let recovered = Db::open(target, store).await?;
    let baseline = golden.get(&2).ok_or("missing cut 2")?;
    let mut batch = WriteBatch::new();
    for region in ["North", "South"] {
        assert_eq!(
            recovered.get(region.as_bytes()).await?.as_deref(),
            Some(encode(baseline.get(region)).as_bytes())
        );
        if baseline.get(region) != result.get(region) {
            batch.put(region.as_bytes(), encode(result.get(region)).as_bytes());
        }
    }
    batch.put(b"_meta/applied_cut", b"3");
    recovered.write(batch).await?.await_durable().await?;
    for region in ["North", "South"] {
        assert_eq!(
            recovered.get(region.as_bytes()).await?.as_deref(),
            Some(encode(result.get(region)).as_bytes())
        );
    }
    recovered.close().await?;
    println!("W1G-RECOVERED");
    Ok(())
}

pub async fn recover_history(
    store: Arc<dyn ObjectStore>,
    namespace: &str,
    skip_replay: bool,
) -> Result<(), Box<dyn Error>> {
    let result = reconstruct(&store, namespace, 3).await?;
    let mut golden = Groups::new();
    for line in include_str!("../../../../fixtures/w1g/expected.csv")
        .lines()
        .filter(|l| l.starts_with("3,"))
    {
        let f: Vec<_> = line.split(',').collect();
        golden.insert(f[1].to_owned(), (f[2].parse()?, f[3].parse()?));
    }
    assert_eq!(result, golden);
    let path = format!("{namespace}/pure-history");
    let history = Db::open(path.clone(), store.clone()).await?;
    assert!(history.get(b"cut/3/North").await?.is_none());
    if !skip_replay {
        let mut batch = WriteBatch::new();
        for region in ["North", "South"] {
            batch.put(
                format!("cut/3/{region}"),
                encode(result.get(region)).as_bytes(),
            );
        }
        history.write(batch).await?.await_durable().await?;
    }
    for region in ["North", "South"] {
        assert_eq!(
            history.get(format!("cut/3/{region}")).await?.as_deref(),
            Some(encode(result.get(region)).as_bytes())
        );
    }
    history.close().await?;
    let reopened = Db::open(path, store).await?;
    for region in ["North", "South"] {
        assert_eq!(
            reopened.get(format!("cut/3/{region}")).await?.as_deref(),
            Some(encode(result.get(region)).as_bytes())
        );
    }
    reopened.close().await?;
    println!("HISTORY-RECOVERED");
    Ok(())
}
