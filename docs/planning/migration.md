# Migration and coexistence plan

**Status:** proposed release requirement; no migration tooling is implemented.
**Baseline:** see the [current-system audit](../research/current-system-audit.md).

## 1. Objective and boundary

Move a selected workload from current Rockstream to Rockstream 2 with a recorded
source cut, exact reconciliation for supported exact semantics, controlled
subscription/sink handoff, and a usable rollback path. Continue qualifying and
operating current Rockstream while the successor develops. A rewrite is not a
reason to withdraw the existing supported contract before a replacement proves
it can carry the workload.

The initial migration path is **logical replay from authoritative inputs**.
Export schema and catalog definitions, create the new views, take a consistent
source snapshot, and replay changes through the ordinary new ingestion path.
Do not open old SlateDB prefixes with new binaries or assume that sharing a
storage dependency creates format compatibility. A future direct state importer
needs its own versioned specification, validation and rollback plan.

Migration is a workload operation, not an automatic full-cluster operation.
Group sources/views that require transaction atomicity into one migration unit.
Independent units can move separately; joining an old result and a new result
without a common cut is not a consistent cross-version read.

Use a strangler migration: first qualify a narrow useful slice with PostgreSQL
CDC, incremental joins and grouped aggregates, durable publication, consistent
reads and simple operation. Move selected workloads when their applicable gates
pass, while other workloads remain on the old engine. Broad feature parity is
not a prerequisite for that scoped delivery; every feature in a selected unit
must still have complete correctness, recovery and operational evidence.

### Donor assets and regression transfer

Treat original Rockstream as a source of algorithms, executable specifications
and historical failures. P0.1 records a versioned donor inventory before porting
implementation, with original revision/path, contract/bug covered, expected
result, target contract/test ID, owner, disposition and unresolved semantic gaps.

Use this as a component disposition register for the first native prototype.
Choose **reuse, extract, adapt, replace or reject** per component, with its exact
donor revision/path and provenance/license notices; target semantic, lifecycle,
security and resource contracts; inherited runtime/storage dependencies; required
changes and replacement rationale; transferred tests and independent oracle; and
observed evidence or remaining qualification gaps. Prefer selective extraction or
adaptation where it reduces owned complexity while satisfying those contracts.
Retain required attribution for transferred code. A disposition is a proposal
until its checks pass; previous production use and matching old/new outputs
alone cannot qualify inherited behavior. This register feeds the native candidate
in [P0.3](../adr/0005-runtime-selection.md) and bounds porting to the golden slice;
it does not require a third runtime or a parallel full-engine rewrite.

The [current-system audit](../research/current-system-audit.md#4-reuse-adapt-and-replace)
seeds the following dispositions at donor revision
`d3f973a84f4263bedd6505039d7f469d4708c478`. These are starting decisions for the
bounded prototype. P0.1 must resolve the actual dependency closure, notices,
named test IDs and independent expected results before accepting a port.

| Audited donor entry point | Seed disposition | Target contract, coupling to inspect and acceptance |
| --- | --- | --- |
| [`arrangement.rs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-types/src/arrangement.rs) | Adapt canonical descriptors; replace hash-only reuse decisions | Preserve semantic/security identity while separating physical layout. Inspect encoding/version assumptions; force digest collisions and semantic/security differences to demonstrate full-descriptor admission. |
| [`trace.rs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/src/trace.rs) and [`arrangement_catalog.rs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/src/arrangement_catalog.rs) | Extract/adapt trace algorithms and lifecycle cases | Inspect consumer ownership, reclamation and storage coupling. Require authoritative root/pin integration, exact logical cuts under independent schedules and recovery after drop/GC; the old catalog cannot independently authorize the new publication protocol. |
| [`factorized.rs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-ops/src/factorized.rs) | Extract/adapt the eligible factorized kernel | Map weighted batches, numeric semantics and auxiliary state into the new IR and recovery contract. Compare first-order, factorized and independent batch results under simultaneous changes, duplicates and deletions; retain full auxiliary-state cost. |
| [`frontier.rs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-control/src/frontier.rs) | Adapt membership checks and regressions; replace publication wiring | Inspect old control/shard dependencies. Separate computed progress from durable publication and reject stale scope/generation/incarnation reports, omitted work and delayed abandoned attempts under the new one-interval contract. |
| [`shard_db.rs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/src/shard_db.rs) | Extract useful batching/encoding lessons; replace incompatible epoch/commit authority | Audit SlateDB API and physical-format dependencies rather than inherit them. Require exact-parent reopening, protected logical history and speculative-attempt isolation; qualify any transferred implementation under P0.2. |
| [`rockstream-sim`](https://github.com/trickle-labs/rockstream/tree/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-sim/src) and [`formal`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/formal/README.md) | Reuse failures and obligations; adapt environment/model bindings | Inspect assumptions about old transition identities and schedules. Run new production logic under controlled faults with independent expected state, replayable histories and delivered-fault negative controls; old proof results cannot qualify new transitions. |
| [`raft.rs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-control/src/raft.rs) | Reject as a replicated metadata log; reuse election/fencing failures | The audited module provides election rather than catalog/publication log replication. Keep the single object-root baseline; any later consensus alternative must qualify a mature replicated-log implementation and its complete stop/restart contract. |

| Asset | Treatment |
| --- | --- |
| SQL and PostgreSQL wire regressions | Reuse where semantics agree; classify intentional differences with independently specified expectations |
| Deterministic failure scenarios and historical bugs | Port minimized histories and schedules early, with observed fault delivery and negative controls |
| Batch evaluator and qualification harness | Retain independent expected results and adapt cut/provenance formats; do not share optimized kernels with the oracle |
| Formal models and counterexamples | Adapt to new publication, ownership, attempt, retention and lifecycle transitions; old proofs do not certify the new protocol |
| Factorized joins and incremental operators | Selectively port only after semantic side conditions and three-way comparisons are established |
| PostgreSQL CDC and Kafka components | Audit source identities, complete transactions, preimages, handoff, acknowledgment and failure behavior before reuse |
| Security and authorization tests | Reuse from the first relevant implementation slice, including tenant sharing/cache boundaries |
| Existing control plane | Replace with the new metadata/lifecycle contracts; preserve useful failure scenarios |
| Legacy physical storage formats | Migrate by explicit logical replay or a separately qualified importer; do not inherit compatibility by accident |

Retain donor tests even when their implementation is replaced. A rejected or
inapplicable test needs an explicit semantic reason and replacement coverage,
not silent deletion. The [verification architecture](../design/testing-and-verification.md)
defines the independent three-way comparison required for every migrated capability.

## 2. Inventory before building

Produce a machine-readable migration manifest with the following fields:

| Category | Required fields |
| --- | --- |
| Identity | Migration ID, source/target deployment IDs, exact binaries and catalog digests, responsible owner |
| Sources | Connector type, source identity/incarnation, source offsets, transaction boundaries, snapshot method and retention limits |
| SQL | Normalized DDL, dependencies, types, precision/scale, collations, timezone, supported expression shapes and rejected constructs |
| Applications | Query templates, prepared statements, transaction modes, freshness fences and required wire behavior |
| Delivery | Subscription consumers/cursors, sink destinations, delivery identities, downstream acknowledgment method |
| Operations | Current state size, update/deletion rates, peak transaction size, freshness/read objectives and failure model |
| Suspension | Continuous versus scheduled/on-demand consumers, source-retention headroom, timer/sink obligations, wake trigger, cold-resume budget and rollback availability |
| Storage/metadata | Source and target durability profiles, qualified object-store conditional-write behavior, protected root namespaces and source-incarnation mappings |
| Security | Principals, effective grants, secret references, tenant assignments, audit destinations and encryption requirements |
| Recovery | Old/new replay windows, backups, rollback deadline, failure triggers and stop conditions |

Classify each feature as compatible, explicitly translated, blocked, or
intentionally changed. The compatibility report must describe observable
differences. For example, old epoch-based subscription history does not imply
new timestamp syntax has the same meaning; old idempotency/source-epoch session
settings need an explicit mapping to new input identities. Current Rockstream's
wire-level and capability tests are useful starting fixtures, not a complete
application inventory. [M01], [M02]

**Gate M0:** every production query/connector/delivery mode in the unit has a
classification; blocked features prevent cutover. Secrets are re-provisioned
through the target's configured secret provider or protected configuration, not
exported as plaintext with DDL. No external secret-management service is implied
by the single-binary baseline.

## 3. Establish one comparable input history

The comparison key is an **input cut**, not an old epoch number, new sequence
number, elapsed time or row count. Record a mapping from source identities and
complete transactions to the old published epoch and the new published manifest.
Source offsets are comparable only within the same source incarnation and
interpretation. A recreated PostgreSQL source or Kafka topic requires explicit
reconciliation.

For PostgreSQL, use a supported synchronized snapshot-and-stream procedure that
records the snapshot boundary and complete replication transactions. Maintain
separate replication slots when independently ingesting into both systems, and
budget the extra retained WAL and snapshot load. Do not allow two deployments to
compete for one mutable slot acknowledgment position. The existing connector's
tests for snapshot handoff, commit-boundary recovery and slot acknowledgment
provide relevant regression scenarios. [M03], [M04]

For Kafka, use separate consumer groups and retain identical topic/partition
histories for the reconciliation and rollback windows. Preserve transaction
visibility and the configured read isolation. A vector of partition offsets is
not automatically a cross-partition application transaction boundary; include
the connector's transaction/envelope contract in the manifest.

For direct application writes, avoid uncoordinated application-level dual
writes. During shadowing, either route through an authoritative durable ingress
log with stable request/transaction IDs that both deployments can consume, or
use a bounded write quiescence and consistent export/replay procedure. If neither
is available, the proposed zero-loss migration is blocked. Retry the same
request identity after an ambiguous response; do not create a fresh identity
and hope duplicate writes reconcile later.

Keep one authority for evaluating direct-write transactions during shadowing.
The shared history records its ordered, normalized transaction effects and
payload digests, not SQL statements independently re-evaluated against two
possibly different snapshots. Conditional updates and reads inside a transaction
otherwise introduce another source of divergence. An adapter that exposes the
authoritative transcript is an explicit migration prerequisite.

**Gate M1:** both systems can be reconstructed from the captured snapshot plus
the retained transaction log, and the same complete input cut can be identified
independently on both sides. Retention headroom must cover the measured
backfill/catch-up time plus an explicit safety margin. If history expires,
restart from a new consistent snapshot; never silently skip a gap.

## 4. Shadow and reconcile

Create the target catalog and views in dependency order. Keep target external
sinks disabled or pointed at isolated shadow destinations. Backfill a pinned
snapshot, replay subsequent transactions, and publish only complete target
versions. Serving traffic continues to use the old deployment during this phase.

At every selected recorded cut, compare the complete canonical weighted multisets
for every view in the unit through three paths: original Rockstream, Rockstream 2
and an independent batch evaluator over the same captured source history.
PostgreSQL is a reference for its declared compatible subset; use independent
explicit expectations for intentional dialect differences. The evaluator must
not reuse the incremental rewrites or optimized kernels under test. Agreement
between the two related engines does not establish correctness, and a two-of-three
vote cannot resolve a mismatch. Classify inherited bugs, new regressions, intended
semantic changes and oracle defects, preserving all transcripts and expected-result
justification. Missing comparison coverage blocks promotion of that migrated
capability until it is supplied or the unit's scope is explicitly narrowed.

Normalize only documented representation differences: decimal
encoding, timestamps/timezone display and explicitly defined collation behavior.
Do not normalize away duplicate multiplicities, NULL differences, missing rows,
ordering required by the query, or numeric overflow. For Top-K, compare selected
rows and specified tie/order behavior. For floating-point features, use a
predeclared accuracy contract and report error distributions separately from
exact reconciliation.

Do not assume the old deployment can export every view at an arbitrary retained
epoch. Qualify its snapshot/export API for the selected workload. Where it cannot
pin a historical cut, briefly stop input application at a complete transaction
boundary, wait for all compared views to publish that boundary, and export while
holding it stable; capture or pause logical clock inputs as well. Replay the same
finite input prefix into the target. If neither a pinned export nor an exercised
bounded barrier is available, reconciliation at a common cut is blocked.

The target's logical MVCC can reconstruct a common cut from protected bases and
timestamped history even when its physical checkpoints occur at different cuts.
Qualify the advertised coverage for each compared relation; a later checkpoint
or a retained input log alone does not prove intermediate output history is
available. Neither matching domain epoch numbers nor shared use of SlateDB
establishes cross-engine lineage or snapshot compatibility.

Counts, checksums and samples are efficient diagnostics, not final proof of
equality. Partition hashes can locate mismatches, but mismatched partitions need
exact row diffs; final qualification requires an exact comparison of the agreed
workload dataset. For very large datasets, use an independent external sort or
partitioned multiset checker rather than load all results into RAM.

Compare both state and delivery transcripts across inserts, updates, deletions,
large transactions and quiet periods with timers. Include crash/restart, stale
owner, network partition, source reconnect, object-store delay, compaction, scale
changes and schema changes supported by the migration contract. Reconciliation
must occur after faults as well as before them.

If the workload will use suspension, include a full stop/activation cycle and
loss of all target cloud-profile local caches, then reconcile accepted input,
published results, retry identities and consumer cursors. Exercise competing
activations and a paused old owner returning after wake. Verify actual source
retention and the activation mechanism under the workload's freshness budget;
do not infer these guarantees from the existing engine's advertised deployment
model. A continuous-ingest deployment may qualify partial pool suspension
without qualifying a zero-process state.

**Gate M2:** zero unexplained exact-result differences across the agreed workload
matrix and all applicable three-way comparisons; every fault was observed to fire;
intentional semantic differences and floating-point acceptance are separately
recorded. **Gate M3:** the target meets the workload's freshness, serving,
resource, cost and recovery acceptance criteria during a representative peak
and a sustained run. A passing synthetic fixture cannot substitute for an
observed deployment run. [M05]

## 5. Read and subscription cutover

1. Select a complete cut `C`. Record the old publication and new manifest that
   both represent `C`, and pin required old/new history.
2. Ensure the target has caught up through `C`. Temporarily hold the serving
   alias change if transactions or dependencies remain unresolved.
3. Route new read sessions to the target. Existing repeatable-read sessions
   finish against their pinned old snapshots or receive a documented retry;
   never move one transaction between engines.
4. Translate freshness requirements using the migration cut mapping. Old opaque
   tokens are not accepted by the target without a validated mapping. Requests
   requiring an unmapped write wait for reconciliation or fail explicitly.
5. Observe errors, lag, result probes and resource use against the rollback
   triggers. Keep the old engine consuming authoritative input during the
   agreed rollback window.

Subscriptions need a separate handoff. Pause at a recorded last acknowledged
old cursor, map its complete source cut to a new cursor, and deliver new changes
strictly after that cut. An old cursor is not a new resume token. If compatible
history or event identity cannot be mapped, explicitly terminate the old stream
and send a new snapshot with a reset event. Consumers must support that reset
before the workload is eligible to migrate. Never silently present a new
snapshot as a continuation of the old change stream.

## 6. External sink handoff

Never run both generations against the same effectful destination without an
explicit downstream deduplication/fencing contract. Shadow delivery must use an
isolated namespace or a non-effectful transcript recorder.

The migration manifest names one authorized external-effect owner for each
destination and cut range. Parallel computation and reconciliation never grant
the shadow engine effect authority. Any shared-destination exception must itself
be separately qualified and explicitly authorized before the migration.

For final handoff, stop old delivery after complete cut `D`, resolve any ambiguous
old destination commit, and confirm its durable acknowledgment. Record the
ownership transfer; then enable new delivery strictly after `D` with a destination
identity that cannot overlap ambiguously. For Kafka, define producer fencing,
transaction IDs and destination cursor evidence in the connector-specific
handoff implementation. A Kafka transaction cannot automatically make arbitrary
Rockstream metadata and destination commits one atomic transaction.

If destination state cannot establish whether an ambiguous old batch committed,
halt the handoff for reconciliation. Exactly-once internal publication does not
repair unknown external side effects. Choose a documented at-least-once handoff
with consumer deduplication only if the application explicitly accepts that
contract.

**Gate M4:** query routing, freshness-token translation, subscriptions and sinks
each have an exercised cutover and rollback procedure. Passing read comparison
alone is insufficient.

## 7. Rollback and retirement

Rollback triggers include unexplained result differences, freshness/availability
breaches beyond the agreed budget, failed recovery, security isolation failures
or an unresolved delivery ambiguity. Record thresholds before the migration,
not during an incident. Stop new sink ownership before restoring old ownership.
Resolve the new sink's last durable destination acknowledgment at complete cut
`E`, catch the old engine up through `E`, and resume old delivery strictly after
`E`. If the destination cannot resolve an ambiguous new commit, stop delivery
for reconciliation instead of guessing a rollback cursor.

For read-only traffic, route new sessions back to the old deployment after it
has reached the required authoritative cut. Pin or terminate existing target
sessions according to their transaction contract. For subscriptions, perform
the reverse explicit cursor/reset handoff. For direct writes accepted by the
target, verify they are in the shared durable ingress history and have reached
the old engine before rollback; otherwise rollback requires export/replay or
forward repair and is not instant. A format downgrade is not a rollback plan.

Keep old resources, source retention and backups until the rollback deadline and
acceptance signoff. Account for this temporary duplicate cost in the migration
budget. After signoff, revoke old sink/source credentials, remove obsolete
consumer registrations and source slots, retire old compute, and release history
pins in a controlled order. Delete data only under the normal retention policy.

Before switching clients, demonstrate the rollback path against the actual
old/new binaries, retained history and destination contract at a complete cut.
Record a measured catch-up/restore budget, retained replay horizon and expiry
deadline; monitor them throughout the rollback window. If retention or format
changes invalidate rollback, stop further cutover and report the explicit
forward-repair or resnapshot path. An old process left running without adequate
history and compatibility is not evidence of a usable rollback.

During the rollback window, suspension is permitted only if both the replay
window and the required rollback recovery time remain satisfied. Keeping the old
engine current may require live ingestion even when the new engine's serving or
maintenance pools are idle. Record that cost explicitly; a zero-compute target
does not eliminate the old deployment's rollback obligations.

The completion record contains exact revisions, catalog mappings, input cuts,
reconciliation artifacts, measured acceptance results, routing/delivery
ownership, exercised recovery evidence and the retirement date. It should be
sufficient for someone outside the implementation team to audit what moved and
which guarantees were actually verified.

## Source references

[M01]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/docs/capability-matrix.md
[M02]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/docs/language-features.md
[M03]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-connectors/src/postgres_cdc.rs
[M04]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-connectors/tests/postgres_cdc_guarantee_matrix_tests.rs
[M05]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/benchmarks/scale-qualification/README.md
