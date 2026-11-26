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
    let delta = Path::from(format!("{prefix}/delta-1"));
    if mode == "publish" {
        store.put(&delta, "1".into()).await?;
        store
            .put_opts(
                &root,
                "1".into(),
                slatedb::object_store::PutMode::Create.into(),
            )
            .await?;
        println!("READY");
        io::stdout().flush()?;
        std::future::pending::<()>().await;
    } else {
        let committed = store.get(&root).await?.bytes().await?;
        let update = store.get(&delta).await?.bytes().await?;
        assert_eq!(committed.as_ref(), b"1");
        assert_eq!(update.as_ref(), b"1");
        let db = Db::open(format!("{prefix}/index"), store).await?;
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
        if mode == "apply-and-wait" {
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
