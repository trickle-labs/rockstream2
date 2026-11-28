use async_trait::async_trait;
use futures_util::stream::BoxStream;
use slatedb::object_store::{self as os, path::Path, ObjectStore};
use std::{
    fmt,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
};

#[derive(Debug, Default)]
pub struct Counts {
    pub puts: AtomicU64,
    pub put_ok: AtomicU64,
    pub put_bytes: AtomicU64,
    pub put_ok_bytes: AtomicU64,
    pub gets: AtomicU64,
    pub get_ok: AtomicU64,
    pub get_range_bytes: AtomicU64,
    pub lists: AtomicU64,
    pub deletes: AtomicU64,
    pub copies: AtomicU64,
    pub multiparts: AtomicU64,
}

#[derive(Debug)]
pub struct CountingStore {
    pub inner: Arc<dyn ObjectStore>,
    pub counts: Arc<Counts>,
}
impl fmt::Display for CountingStore {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "counting({})", self.inner)
    }
}

#[async_trait]
impl ObjectStore for CountingStore {
    async fn put_opts(
        &self,
        path: &Path,
        payload: os::PutPayload,
        options: os::PutOptions,
    ) -> os::Result<os::PutResult> {
        self.counts.puts.fetch_add(1, Ordering::Relaxed);
        let len = payload.content_length() as u64;
        self.counts.put_bytes.fetch_add(len, Ordering::Relaxed);
        let result = self.inner.put_opts(path, payload, options).await;
        if result.is_ok() {
            self.counts.put_ok.fetch_add(1, Ordering::Relaxed);
            self.counts.put_ok_bytes.fetch_add(len, Ordering::Relaxed);
        }
        result
    }
    async fn put_multipart_opts(
        &self,
        path: &Path,
        options: os::PutMultipartOptions,
    ) -> os::Result<Box<dyn os::MultipartUpload>> {
        self.counts.multiparts.fetch_add(1, Ordering::Relaxed);
        self.inner.put_multipart_opts(path, options).await
    }
    async fn get_opts(&self, path: &Path, options: os::GetOptions) -> os::Result<os::GetResult> {
        self.counts.gets.fetch_add(1, Ordering::Relaxed);
        let head = options.head;
        let result = self.inner.get_opts(path, options).await;
        if let Ok(value) = &result {
            self.counts.get_ok.fetch_add(1, Ordering::Relaxed);
            if !head {
                self.counts
                    .get_range_bytes
                    .fetch_add(value.range.end - value.range.start, Ordering::Relaxed);
            }
        }
        result
    }
    fn delete_stream(
        &self,
        paths: BoxStream<'static, os::Result<Path>>,
    ) -> BoxStream<'static, os::Result<Path>> {
        self.counts.deletes.fetch_add(1, Ordering::Relaxed);
        self.inner.delete_stream(paths)
    }
    fn list(&self, prefix: Option<&Path>) -> BoxStream<'static, os::Result<os::ObjectMeta>> {
        self.counts.lists.fetch_add(1, Ordering::Relaxed);
        self.inner.list(prefix)
    }
    async fn list_with_delimiter(&self, prefix: Option<&Path>) -> os::Result<os::ListResult> {
        self.counts.lists.fetch_add(1, Ordering::Relaxed);
        self.inner.list_with_delimiter(prefix).await
    }
    async fn copy_opts(&self, from: &Path, to: &Path, options: os::CopyOptions) -> os::Result<()> {
        self.counts.copies.fetch_add(1, Ordering::Relaxed);
        self.inner.copy_opts(from, to, options).await
    }
}
