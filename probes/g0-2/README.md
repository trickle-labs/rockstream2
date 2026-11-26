# Local Silo conditional-write smoke probe

Run `python3 probes/g0-2/silo_smoke.py` with Python 3, Docker and a curl build
supporting `--aws-sigv4`. Docker must be running and localhost port 19020 must
be free. The script pulls the pinned Silo image if necessary, starts a disposable
container bound to loopback, creates a test bucket, and stops the container in a
`finally` block. Its fixed credentials are only for this temporary local instance;
it has no option to target a remote endpoint. If the process itself is forcibly
killed, remove any remaining `rockstream-g0-2-*` container manually.
Startup waits at most 30 seconds for `/minio/health/cluster`; Silo documents
that `/minio/health/ready` can succeed before storage or IAM is initialized.
See https://silo.pgsty.com/compatibility/feature/healthcheck/.

The assertions cover create-if-absent, duplicate creation, read-after-write,
matching and stale expected-version writes, and two competing writes from the
same version. The output includes individual local timings for diagnostics, not
latency distributions or performance conclusions. The duplicate and stale
writes must fail, and exactly one competing write must succeed.

To also exercise a small SlateDB recovery slice, build the pinned standalone
probe and pass its executable to the same runner:

```sh
cargo build --locked --manifest-path probes/g0-2/slate/Cargo.toml
python3 probes/g0-2/silo_smoke.py probes/g0-2/slate/target/debug/g0-2-slate-probe
```

The Rust probe stages one immutable counter delta and an unreferenced decoy,
conditionally creates a published root naming the delta and its SHA-256, and
verifies that digest before applying the delta and applied-cut marker in one durable
SlateDB batch. The runner delivers SIGKILL after publication and after the
durable batch, reopens the writable instance and verifies the count is one.
A deliberate recovery mutation ignores the marker and must fail the same
count assertion. A corrupt referenced delta must fail digest validation. The
probe also creates a non-expiring checkpoint, conditionally registers its ID in
the root and checks that a stale root version cannot overwrite the registration.
For a split update it kills the writer after its first durable chunk and dirty
marker; a fresh instance replays from the empty initial base, while a negative
control that reuses the dirty instance fails. This tests one interval and one
writer; it does not exercise competing ownership or recovery from a registered
checkpoint.

This smoke test is **not G0.2 qualification**: it does not exercise a real
provider, ambiguous responses, group commit, W1-G, both SlateDB layouts,
general mid-apply recovery, checkpoint-based recovery or overlay caps. It cannot select a storage
layout or establish cloud latency, cost, or durability. Apply the predeclared
qualification rubric and budgets separately for the real-provider run.

Silo image and usage: https://github.com/pgsty/silo
