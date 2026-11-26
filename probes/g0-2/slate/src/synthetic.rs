use crate::count::{CountingStore, Counts};
use futures_util::StreamExt;
use slatedb::object_store::{path::Path, ObjectStore, ObjectStoreExt, PutMode};
use slatedb::{Db, WriteBatch};
use std::{
    error::Error,
    sync::{atomic::Ordering, Arc},
};

async fn exercise(inner: Arc<dyn ObjectStore>, delta_layout: bool) -> Result<(), Box<dyn Error>> {
    let counts = Arc::new(Counts::default());
    let store: Arc<dyn ObjectStore> = Arc::new(CountingStore {
        inner,
        counts: counts.clone(),
    });
    let name = if delta_layout {
        "synthetic-delta"
    } else {
        "synthetic-history"
    };
    let db = Db::open(format!("{name}/index"), store.clone()).await?;
    let mut root_version = None;
    let mut checkpoint_id = String::new();
    let mut overlay: Vec<u32> = Vec::new();
    for cut in 1_u32..=32 {
        let value = cut.to_string();
        if delta_layout {
            if overlay.len() >= 8 {
                return Err("synthetic overlay exhausted".into());
            }
            let delta = Path::from(format!("{name}/delta/{cut}"));
            store
                .put_opts(&delta, value.clone().into(), PutMode::Create.into())
                .await?;
            let mode = match root_version.take() {
                Some(v) => PutMode::Update(v),
                None => PutMode::Create,
            };
            root_version = Some(
                store
                    .put_opts(
                        &Path::from(format!("{name}/root")),
                        format!("{cut}:{checkpoint_id}").into(),
                        mode.into(),
                    )
                    .await?
                    .into(),
            );
            overlay.push(cut);
            assert_eq!(overlay.last(), Some(&cut));
            if cut % 8 == 0 {
                let mut batch = WriteBatch::new();
                batch.put(b"value", value.as_bytes());
                batch.put(b"_meta/applied_cut", value.as_bytes());
                db.write(batch).await?.await_durable().await?;
                let ckpt = db
                    .create_checkpoint(
                        slatedb::config::CheckpointScope::All,
                        &slatedb::config::CheckpointOptions::default(),
                    )
                    .await?;
                checkpoint_id = ckpt.id.to_string();
                let version = root_version.take().ok_or("missing synthetic root")?;
                root_version = Some(
                    store
                        .put_opts(
                            &Path::from(format!("{name}/root")),
                            format!("{cut}:{}", ckpt.id).into(),
                            PutMode::Update(version).into(),
                        )
                        .await?
                        .into(),
                );
                overlay.clear();
            }
        } else {
            let mut batch = WriteBatch::new();
            batch.put(format!("cut/{cut}"), value.as_bytes());
            batch.put(b"_meta/applied_cut", value.as_bytes());
            db.write(batch).await?.await_durable().await?;
        }
    }
    assert!(overlay.is_empty());
    let key = if delta_layout { "value" } else { "cut/32" };
    assert_eq!(db.get(key).await?.as_deref(), Some(b"32".as_slice()));
    if !delta_layout {
        assert_eq!(db.get("cut/8").await?.as_deref(), Some(b"8".as_slice()));
    }
    db.close().await?;
    let reopened = Db::open(format!("{name}/index"), store.clone()).await?;
    assert_eq!(reopened.get(key).await?.as_deref(), Some(b"32".as_slice()));
    if delta_layout {
        for cut in 1_u32..=32 {
            let stored = store
                .get(&Path::from(format!("{name}/delta/{cut}")))
                .await?
                .bytes()
                .await?;
            assert_eq!(stored.as_ref(), cut.to_string().as_bytes());
        }
    } else {
        for cut in 1_u32..=32 {
            assert_eq!(
                reopened.get(format!("cut/{cut}")).await?.as_deref(),
                Some(cut.to_string().as_bytes())
            );
        }
    }
    reopened.close().await?;
    let puts = counts.puts.load(Ordering::Relaxed);
    let put_ok = counts.put_ok.load(Ordering::Relaxed);
    let gets = counts.gets.load(Ordering::Relaxed);
    let get_ok = counts.get_ok.load(Ordering::Relaxed);
    assert_eq!(
        counts.multiparts.load(Ordering::Relaxed),
        0,
        "multipart payloads not measured"
    );
    println!("SYNTHETIC layout={name} updates=32 object_put_calls={puts} object_put_success={put_ok} attempted_put_bytes={} successful_put_bytes={} object_get_calls={gets} object_get_success={get_ok} advertised_get_bytes={} list_calls={} delete_stream_calls={} copy_calls={} multipart_starts=0", counts.put_bytes.load(Ordering::Relaxed), counts.put_ok_bytes.load(Ordering::Relaxed), counts.get_range_bytes.load(Ordering::Relaxed), counts.lists.load(Ordering::Relaxed), counts.deletes.load(Ordering::Relaxed), counts.copies.load(Ordering::Relaxed));
    Ok(())
}

pub async fn run(inner: Arc<dyn ObjectStore>) -> Result<(), Box<dyn Error>> {
    let counts = Arc::new(Counts::default());
    let check: Arc<dyn ObjectStore> = Arc::new(CountingStore {
        inner: inner.clone(),
        counts: counts.clone(),
    });
    let path = Path::from("instrumentation-check");
    check
        .put_opts(&path, "abc".into(), PutMode::Create.into())
        .await?;
    assert!(check
        .put_opts(&path, "xyz".into(), PutMode::Create.into())
        .await
        .is_err());
    assert_eq!(check.get(&path).await?.bytes().await?.as_ref(), b"abc");
    assert_eq!(
        (
            counts.puts.load(Ordering::Relaxed),
            counts.put_ok.load(Ordering::Relaxed),
            counts.put_bytes.load(Ordering::Relaxed),
            counts.put_ok_bytes.load(Ordering::Relaxed)
        ),
        (2, 1, 6, 3)
    );
    assert_eq!(
        (
            counts.gets.load(Ordering::Relaxed),
            counts.get_ok.load(Ordering::Relaxed),
            counts.get_range_bytes.load(Ordering::Relaxed)
        ),
        (1, 1, 3)
    );
    let copied = Path::from("instrumentation-check-copy");
    check.copy(&path, &copied).await?;
    let mut listing = check.list(Some(&path));
    while let Some(item) = listing.next().await {
        item?;
    }
    check.delete(&copied).await?;
    assert_eq!(
        (
            counts.copies.load(Ordering::Relaxed),
            counts.lists.load(Ordering::Relaxed),
            counts.deletes.load(Ordering::Relaxed)
        ),
        (1, 1, 1)
    );
    exercise(inner.clone(), true).await?;
    exercise(inner, false).await?;
    Ok(())
}
