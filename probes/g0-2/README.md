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
One in-memory overlay instance rejects byte- and count-cap exhaustion, stays
full after a failed registration, and is trimmed only after registration succeeds.
This is a synthetic admission exercise, not a complete serving overlay.
For a split update it kills the writer after its first durable chunk and dirty
marker; a fresh instance replays from the empty initial base, while a negative
control that reuses the dirty instance fails. This tests one interval and one
writer; it does not exercise competing ownership or recovery from a registered
checkpoint.

The optional Rust probe also consumes the G0.1 `fixtures/w1g` transactions,
expected cuts and independent `w1g-oracle`. At each cut it batch-recomputes the
join separately, verifies both oracle and frozen result, stores changed output
rows in immutable objects with a capped overlay over a checkpointed SlateDB
index, and stores per-cut keyed snapshots in a second SlateDB instance. It
checks both layouts at each cut and a retained cut-2 read. The second path is
an exploratory keyed-history representation, not a qualified pure-SlateDB
history implementation. A separate read reconstructs each cut by reading the
root's upper and replaying its conventionally named immutable deltas; it ignores
an unreferenced later object and fails when a required delta is removed. Both
SlateDB instances are closed and reopened for retained-state checks. The W1-G
root binds the ordered deltas by SHA-256; corrupt and missing deltas are rejected.
Another W1-G run receives SIGKILL after publishing cut 3 and durably writing
only the first chunk to the cut-2 index. Recovery clones the registered cut-2
checkpoint, verifies its baseline, and applies the cut-3 changes from the
root-selected history. Reusing the dirty live instance fails the baseline
negative control. A separate run kills the keyed-history writer after cut-3
publication but before applying the history batch; recovery reconstructs that
cut, writes its rows and checks them after reopening. Skipping replay fails its
negative control. Both layouts receive writes derived from the same batch
result. The printed delta payload bytes and history value bytes omit keys,
metadata, SlateDB internals and requests, so they are not comparable write
amplification or cost measurements.

A separate local group-commit exercise accepts two concurrently enqueued
same-domain operations, composes their distinct outcomes in memory, and writes
both in one conditional root update. It checks rejection of a stale CAS and
that outcomes remain present after a later root advance. This is a two-operation
experiment, not a production scheduler, ambiguous-response fault injection,
fairness, bounded retry, or throughput qualification.

This smoke test is **not G0.2 qualification**: it does not exercise a real
provider, ambiguous responses, a complete group-commit scheduler, a full comparison of both storage layouts,
general mid-apply recovery, complete checkpoint-based recovery or an integrated serving
overlay. It cannot select a storage
layout or establish cloud latency, cost, or durability. Apply the predeclared
qualification rubric and budgets separately for the real-provider run.

Silo image and usage: https://github.com/pgsty/silo
