use sha2::{Digest, Sha256};
use slatedb::config::{CheckpointOptions, CheckpointScope};
use slatedb::object_store::{aws::AmazonS3Builder, path::Path, ObjectStore, ObjectStoreExt};
use slatedb::Db;
use slatedb::WriteBatch;
use std::{
    error::Error,
    io::{self, Write},
    sync::Arc,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<_> = std::env::args().collect();
    let mode = args.get(1).ok_or("missing mode")?;
    let prefix = args.get(2).ok_or("missing prefix")?;
    let store: Arc<dyn ObjectStore> = Arc::new(
        AmazonS3Builder::new()
            .with_bucket_name("g0-probe")
            .with_region("us-east-1")
            .with_endpoint("http://127.0.0.1:19020")
            .with_access_key_id("rockstream-local")
            .with_secret_access_key("rockstream-local-test-only")
            .with_allow_http(true)
            .build()?,
    );
    let root = Path::from(format!("{prefix}/root"));
    if mode == "publish" || mode == "publish-corrupt" {
        store
            .put(&Path::from(format!("{prefix}/delta-orphan")), "9".into())
            .await?;
        let delta = Path::from(format!("{prefix}/delta-1"));
        let actual = if mode == "publish-corrupt" { "2" } else { "1" };
        store.put(&delta, actual.into()).await?;
        let root_value = format!("1:delta-1:{:x}", Sha256::digest(b"1"));
        store
            .put_opts(
                &root,
                root_value.into(),
                slatedb::object_store::PutMode::Create.into(),
            )
            .await?;
        println!("READY");
        io::stdout().flush()?;
        std::future::pending::<()>().await;
    } else {
        let root_read = store.get(&root).await?;
        let root_version = slatedb::object_store::UpdateVersion {
            e_tag: root_read.meta.e_tag.clone(),
            version: root_read.meta.version.clone(),
        };
        let committed = root_read.bytes().await?;
        let root_text = std::str::from_utf8(&committed)?;
        let parts: Vec<_> = root_text.split(':').collect();
        if parts.len() != 3 || parts[0] != "1" || parts[1] != "delta-1" {
            return Err("invalid committed root".into());
        }
        let delta = Path::from(format!("{prefix}/{}", parts[1]));
        let update = store.get(&delta).await?.bytes().await?;
        if format!("{:x}", Sha256::digest(&update)) != parts[2] {
            return Err("delta digest mismatch".into());
        }
        let db = Db::open(format!("{prefix}/index"), store.clone()).await?;
        let applied = db.get(b"_meta/applied_cut").await?;
        let count = db.get(b"count").await?;
        if applied.is_none() || mode == "recover-reapply" {
            let previous = match count.as_deref() {
                None => 0,
                Some(value) => std::str::from_utf8(value)?.parse::<u64>()?,
            };
            let increment = std::str::from_utf8(&update)?.parse::<u64>()?;
            let next = previous
                .checked_add(increment)
                .ok_or("count overflow")?
                .to_string();
            let mut batch = WriteBatch::new();
            batch.put(b"count", next.as_bytes());
            batch.put(b"_meta/applied_cut", b"1");
            db.write(batch).await?.await_durable().await?;
        } else if applied.as_deref() != Some(b"1".as_slice()) {
            return Err(format!("invalid applied cut: {applied:?}").into());
        }
        assert_eq!(db.get(b"count").await?.as_deref(), Some(b"1".as_slice()));
        if mode == "checkpoint" {
            let checkpoint = db
                .create_checkpoint(CheckpointScope::All, &CheckpointOptions::default())
                .await?;
            let registered = format!("{root_text}:{}", checkpoint.id);
            let options: slatedb::object_store::PutOptions =
                slatedb::object_store::PutMode::Update(root_version).into();
            store
                .put_opts(&root, registered.clone().into(), options.clone())
                .await?;
            assert!(matches!(
                store.put_opts(&root, "invalid".into(), options).await,
                Err(slatedb::object_store::Error::Precondition { .. })
            ));
            assert_eq!(
                store.get(&root).await?.bytes().await?.as_ref(),
                registered.as_bytes()
            );
            db.close().await?;
            println!("CHECKPOINTED");
        } else if mode == "apply-and-wait" {
            println!("READY");
            io::stdout().flush()?;
            std::future::pending::<()>().await;
        } else if mode == "recover" || mode == "recover-reapply" {
            db.close().await?;
            println!("RECOVERED");
        } else {
            return Err("unknown mode".into());
        }
    }
    Ok(())
}
