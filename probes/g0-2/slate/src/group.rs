use slatedb::object_store::{path::Path, ObjectStore, ObjectStoreExt, PutMode};
use std::{
    error::Error,
    sync::{mpsc, Arc},
    thread,
};

pub async fn run(store: Arc<dyn ObjectStore>) -> Result<(), Box<dyn Error>> {
    let path = Path::from("group/root");
    let initial = store
        .put_opts(&path, "0:0:0".into(), PutMode::Create.into())
        .await?;
    let (tx, rx) = mpsc::sync_channel(2);
    let workers: Vec<_> = ["a", "b"]
        .into_iter()
        .map(|id| {
            let tx = tx.clone();
            thread::spawn(move || tx.send(id).expect("queue receiver lost"))
        })
        .collect();
    drop(tx);
    for worker in workers {
        worker.join().map_err(|_| "queue worker panicked")?;
    }
    let pending: Vec<_> = rx.into_iter().collect();
    assert_eq!(pending.len(), 2);
    let mut head = 0u8;
    let mut outcomes = [0u8; 2];
    for id in pending {
        let slot = match id {
            "a" => 0,
            "b" => 1,
            _ => return Err("unknown operation".into()),
        };
        assert_eq!(outcomes[slot], 0);
        head = head.checked_add(1).ok_or("head overflow")?;
        outcomes[slot] = head;
    }
    let version = store
        .put_opts(
            &path,
            format!("{head}:{}:{}", outcomes[0], outcomes[1]).into(),
            PutMode::Update(initial.clone().into()).into(),
        )
        .await?;
    let batched = store.get(&path).await?.bytes().await?;
    assert_eq!(
        std::str::from_utf8(&batched)?,
        format!("2:{}:{}", outcomes[0], outcomes[1])
    );
    assert!(matches!(
        store
            .put_opts(
                &path,
                "invalid".into(),
                PutMode::Update(initial.into()).into()
            )
            .await,
        Err(slatedb::object_store::Error::Precondition { .. })
    ));
    store
        .put_opts(
            &path,
            format!("3:{}:{}", outcomes[0], outcomes[1]).into(),
            PutMode::Update(version.into()).into(),
        )
        .await?;
    let later = store.get(&path).await?.bytes().await?;
    let later = std::str::from_utf8(&later)?;
    let fields: Vec<_> = later.split(':').collect();
    assert_eq!(fields[0], "3");
    assert_eq!(fields[1].parse::<u8>()?, outcomes[0]);
    assert_eq!(fields[2].parse::<u8>()?, outcomes[1]);
    assert_ne!(outcomes[0], outcomes[1]);
    assert!([1, 2].contains(&outcomes[0]) && [1, 2].contains(&outcomes[1]));
    println!("GROUP-COMMIT");
    Ok(())
}
