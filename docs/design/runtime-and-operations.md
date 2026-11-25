# Runtime, connectors, and cloud operations

**Status:** Proposed, 2026-11-25. No implementation or operational qualification is claimed. The [consistency specification](consistency-and-storage.md) governs publication and retention; this document describes how execution and operations obey it. [Requirements](../planning/requirements.md) define profiles and success criteria.

## 1. Execution model

A physical plan is a versioned graph of tasks over virtual partitions. Tasks own operator state while scheduled on a worker; durable state identity survives the worker. A task descriptor includes deployment incarnation, tenant, domain, plan generation, topology revision, partition ID, ownership generation, unique `AttemptId`, input interval, arrangement handles, output schema, and resource reservation.

Execute vectorized Arrow batches in cooperative lanes. Operators on a lane have one mutable owner. Pure map/filter/project and compatible aggregation work can be fused. Storage, network, timer and scheduling edges are asynchronous; individual scalar expressions are not separate tasks. This is a required execution shape, subject to the [runtime selection experiment](../adr/0005-runtime-selection.md), rather than an assertion that a custom runtime is already preferable.

The same operator, state, progress and publication interfaces run in embedded and distributed modes. The simulator injects deterministic implementations of the environment at those interfaces. It must not replace production algorithms with a simpler simulator-only commit or routing path.

### Task lifecycle

`Assigned → Restoring → Ready → Running → Preparing → Prepared → Published`, with `Draining`, `Fenced`, `Retrying`, and `Failed` branches. “Prepared” does not authorize reads. Initially a domain runs one publishing interval at a time. Later pipelining requires every staged version to name its exact predecessor and dependencies. Limit speculative intervals by memory, object bytes, and replay cost.

On failure, recover from the last published manifest and replay durable inputs. Mutable caches, partial output, and uncommitted accumulator changes cannot be reused without proving their input interval and generation. Operators never patch a published result in place to recover from an exception.

### Exchange and replay

An exchange envelope carries domain/plan/topology, source and destination partition, interval, `AttemptId`, sender generation, stream ID, sequence/chunk ID, schema and encoding version, payload length, and checksum. A credit-based protocol bounds queued bytes, not just message count. Reject mismatched routing, schema, attempt or generation; checksum errors fail the interval.

Use either durable replayable exchange references or deterministic recomputation from retained inputs and the previous committed state. The first implementation should favor replay from durable input and stage boundaries rather than invent another consensus log for every edge. Delivery can repeat: `(plan, interval, attempt, edge, sender, sequence)` identifies duplicates while an interval is active. On restart, discard all tentative operator effects for an uncommitted interval, allocate a new attempt, and replay from the exact published parent. Delayed messages from an abandoned attempt are rejected even if the owner and epoch did not change. A dedupe set without a coherent state rollback is insufficient.

Completion accounts for all admitted messages and outstanding capabilities, including timers, spill reads, retries and recursive feedback when supported. End-of-stream on one socket is not proof that an epoch is complete. State transitions producing output must transfer progress ownership before releasing the input capability. A worker cannot certify an output upper greater than any required input/dependency upper.

## 2. Memory, state and backpressure

Every task reserves memory for input, output, accumulators, arrangement cache, exchange, and staging. The scheduler admits a transaction or build only when its declared execution strategy can stay within the pool's limits. Large source transactions use durable chunks and a final complete envelope; their atomicity is independent of chunk size.

| Pressure | Required response | Forbidden shortcut |
| --- | --- | --- |
| Queue at byte limit | Withhold credits, stop upstream polling where supported | Drop records or acknowledge unseen source offsets |
| Operator working set exceeds memory | Use qualified spill representation or fail the affected publication | Evict correctness state as if it were cache |
| Output fanout exceeds budget | Stream bounded chunks to durable staging; admission can reject future oversized work | Truncate correct output to meet an SLO |
| Compaction debt grows | Reserve compaction capacity and reduce ingestion/admission rate | Report short-run throughput while debt grows indefinitely |
| History pins exceed quota | Refuse new pin/renewal or expire at the contracted boundary | Delete data under an unexpired acknowledged pin |
| Input log retention nearly exhausted | Wake consumers, retain more under policy, or stop acknowledgements/admission | Skip required replay or silently rebuild from an inconsistent source |
| Disk/cache fills | Evict reconstructible cache, throttle spill, reject new work | Treat local NVMe as the only copy of acknowledged input |

Backpressure must avoid circular resource waits. Reserve control/progress capacity separately from payload queues, and keep a small independently budgeted path for cancellation, fencing, error reporting, and lease/pin renewal. Spill writes cannot consume the memory required to release spilled buffers. Borrowed shared-state memory is charged once physically and attributed among consumers; enforce a hard pool limit independently of attribution.

An error after durable ingestion can stop maintenance without undoing the source's acknowledged input. The view exposes a blocked state and last good version. Repair changes the responsible query/schema through a validated replacement, or rebuilds at a later complete cut containing all accepted inputs under an explicit repair contract. A later compensating row alone does not make ordinary replay advance past an earlier failing epoch; intermediate results that could not be computed remain unavailable. The system never silently skips the offending event. Poison records and quarantines require a documented semantic policy and audit record, not an invisible dead-letter shortcut.

## 3. Scheduling and elasticity

Start with weighted fair scheduling across tenants and resource pools, then use freshness slack within a tenant's admitted budget. Favor a dependency on the critical path over a downstream task that cannot yet publish. Aging prevents starvation. Priority does not override durable ordering or memory admission.

Scale decisions use backlog growth, estimated remaining work, source retention headroom, completion latency, CPU, memory, cache miss/restore rate, object-store throttling, exchange saturation and compaction debt. CPU alone is inadequate: adding workers during an object-store throttle can worsen both cost and latency.

Use a bounded controller: configurable minimum/maximum capacity, hysteresis, cooldown, one topology change at a time per group, cost ceiling, and rollback when measured throughput/freshness deteriorates. Expose recommendations before enabling automatic action. An autoscaler is a consumer of stable APIs; it cannot bypass publication or ownership rules.

### Skew

Detect skew by key-frequency sketches and actual per-partition service time, memory and fanout. Associative/decomposable aggregates can use partials and merge. Selected join inputs can be replicated if a costed plan preserves multiplicities and null behavior. A general hot join key or one huge transaction may remain inherently serial or output-bound; report that limit. Splitting a key without an algebraically valid merge is prohibited.

### Maintenance modes

| Mode | Trigger | Resume obligation |
| --- | --- | --- |
| Continuous | Durable input arrives | Keep up within admitted freshness and durability profile |
| Adaptive microbatch | Size/deadline threshold | Batch only complete transactions; publish every sealed interval correctly |
| Scheduled incremental | Catalog schedule fires | Pin base state and all replay input since last published cut |
| On-demand | A read requires a newer cut | Return wait/progress/timeout; never label the old result fresh |

Pool suspension is a durable lifecycle transition, not a process crash masquerading as a feature. Record retained input obligations, timer deadlines, expected cold-start work, retention budget and wake triggers. Reject suspension if required source retention cannot be funded. Ingestion, metadata, and external sources may continue to cost money. Temporal queries can require clock-driven work even without data updates. A cold read's SLO includes restoration; warm-cache targets do not apply.

## 4. Reassignment, split and merge

Moving compute ownership and changing state partitioning are separate operations.

For a planned reassignment, choose a published boundary, stop admitting work that crosses the transfer, drain or discard tentative intervals, acquire the new ownership generation in metadata, reopen the exact durable state, and resume. The old owner is fenced even if its process is paused and later resumes. A failure-induced reassignment skips the graceful drain and replays from the published cut. Leases detect failure; generations checked at publication provide safety.

Split/merge builds a new layout from a pinned version, routes catch-up into the replacement generation, validates key-range/hash coverage and row multiplicities, and changes routing plus active state references at a publication boundary. Both layouts can exist during migration; neither routing gaps nor double-applied input are permitted. Read and backup pins retain the prior layout as necessary. The catalog records progress so a coordinator restart resumes or aborts deterministically.

First cloud qualification should favor fixed virtual partitions and reassignment. Online repartitioning earns promotion after its separate race and failure matrix passes. Configure enough virtual partitions to permit initial scale-out without pretending that one fine-grained partition per row is free.

## 5. Source ingestion

All connectors implement the same normalizer and durable envelope contract. A source identity includes the external system identity, source incarnation, partition/table mapping, and schema version. An offset without source incarnation is not globally unique after a topic is recreated or a database is restored.

### PostgreSQL CDC

Establish a consistent snapshot and corresponding replication position using a qualified connector protocol. Snapshot chunks may be ingested incrementally, but a source snapshot becomes usable only after its complete scope and the snapshot/stream handoff are certified. Buffer or durably stage WAL changes occurring during snapshot acquisition, then replay from the agreed boundary. Preserve all relevant table changes within each committed transaction, including transactions spanning snapshot chunks and multiple tables. Do not expose half a source transaction.

Updates and deletes require sufficient old values to retract the previous row. Use the configured replica identity/full before-image contract or a durable primary-key row image store tied to the input version; reject unsupported tables or schema changes. Treat missing preimages as a correctness error. Handle TOAST/unchanged-column representations explicitly. DDL is not assumed to appear as a complete schema migration in logical replication; validate source schema versions, stop incompatible ingestion, and apply an explicit catalog migration/backfill policy.

Advance external acknowledgement only after the normalized data and replay identity are durably recoverable. Detect slot/WAL loss and require a new snapshot incarnation with controlled rebuild; do not continue from an arbitrary current LSN. Monitor source disk pressure and lag because a stopped consumer can force retained WAL growth. PostgreSQL's [logical decoding documentation](https://www.postgresql.org/docs/current/logicaldecoding-explanation.html) supplies connector constraints; Rockstream's exact protocol still requires live integration qualification.

### Kafka source

Use source cluster/topic identity and incarnation plus partition and offset. Respect the configured isolation level and aborted transactions. Per-partition ordering does not imply total ordering across partitions. Unless a qualified adapter reconstructs complete producer transactions across the subscribed partition set, the supported semantic unit is the declared record/partition ingestion contract, not an undocumented global Kafka transaction.

Group rebalances fence old partition ingestion owners. Persist normalized changes before committing source offsets; retries deduplicate. On retention truncation, changed topic identity, unsupported schema or corrupted payload, stop the affected source and surface an actionable error. Bootstrapping from compacted topics requires a separately declared current-state/tombstone contract; arbitrary offset rewind is not a universal snapshot protocol. Kafka's [design documentation](https://kafka.apache.org/44/design/design/) is background for ordering and transaction behavior, not proof of connector conformance.

### Direct ingestion

A request identity contains a server-issued signed client generation and monotonic sequence, scoped by deployment incarnation, tenant and domain. Persist a bounded admitted sequence window, payload digests, results and an irreversible low-watermark with the accepted-input head. A request below that floor or from an expired generation is rejected, even if its detailed record was reclaimed. Optional client labels are not the deduplication authority. Reusing a retained identity with a different payload fails. Direct SQL updates normalize once against the domain's serialized accepted-input state, including durable transactions not yet published; replay applies those normalized effects rather than reevaluating SQL. Validate before-images and expected row versions at that admission boundary.

## 6. Serving and subscriptions

Serving resolves authorization and exact snapshot dependencies before executing a query. Pin the catalog generation and published versions in one coherent operation, then construct providers that read those versions only. Index absence can cause an admitted scan, a wait for an explicit build, or an actionable rejection; it cannot cause a read of a convenient newer mutable state.

Serving has separate CPU, memory, queue and cache budgets from maintenance. Shared object storage and network remain contention points, so measure mixed-workload interference. Cache keys include tenant, version, object generation, encoding and encryption context. Cancellation releases pins and work reservations idempotently. Long-running queries renew pins under policy or abort before accessing reclaimed history.

For subscriptions, acquire a snapshot pin and durable delta-log coverage from the same publication boundary. Send a delimited snapshot, then complete committed delta envelopes with stable IDs and the next cursor. Resume after the last acknowledged complete envelope; an interrupted envelope is retransmitted as one identifiable logical unit. Schema/plan changes either preserve a declared encoding contract or emit a control transition requiring client acknowledgement/rebootstrap. Authorization is rechecked on resume and policy changes.

Slow consumers retain state only within purchased quotas and a documented cursor lifetime. Expiry produces `history expired` with the last valid boundary and rebootstrap guidance. Do not silently jump to the latest frontier. Client acknowledgements advance delivery state, not the database's correctness frontier. The [API contract](../reference/sql-and-apis.md) specifies token fields and error behavior.

### Kafka sink and ambiguous commit

Published output is an outbox of deterministic complete envelopes. The initial sink contract is at-least-once delivery with stable IDs, enabling consumers to deduplicate. Kafka idempotent production alone does not prove exactly-once transfer from an external Rockstream commit log across all crash/restart cases.

A stronger candidate protocol atomically writes the output envelope and a durable delivery marker in the same Kafka transaction, uses a stable transactional identity with producer fencing, and recovers by reading committed markers before deciding whether an ambiguous send needs retry. Qualification must establish marker partitioning/order, retention and compaction, broker transaction timeout, producer fencing, configuration, and consumer `read_committed` behavior. If the destination cannot resolve whether an envelope committed, the connector must not claim exactly-once. Never hold Rockstream publication open on an indefinite external side effect.

## 7. Security and isolation

The first vertical slice includes authenticated sessions, explicit catalog ownership, authorization checks, secret references, and isolation tests. Production adds workload identity, mTLS between processes, TLS for clients, encryption at rest, least-privilege object/metadata access, key rotation, audit export and release provenance. Anonymous access is an explicitly local development mode, not a default cloud deployment.

| Threat / failure | Boundary |
| --- | --- |
| Cross-tenant arrangement or cache reuse | Tenant/security context in identity; full canonical descriptor equality; no cross-tenant sharing initially |
| Forged or replayed tokens | Authenticated tokens bound to tenant, object, incarnation, schema/version and expiry; authorization still checked |
| Stale process credentials | Workload identity plus generation fencing; credential validity alone cannot publish |
| SQL/source configuration accessing arbitrary networks or files | Disable unapproved DataFusion providers/UDFs and filesystem/network functions; connector destination allowlist and egress policy |
| Resource denial of service | Admission limits for fanout, transactions, reads, history, graph builds, spill and metadata size |
| Secret leakage | Secret-manager references; redacted logs, explain plans, errors and support bundles |
| Shared-state policy change | Reauthorize consumers and invalidate/rebuild incompatible identities at a catalog boundary |
| Corrupt or malicious stored data | Bounded parsers, format/version checks, authenticated transport, checksums and quarantine |

Initial isolation uses tenant/database roles and object grants. Row-level security and arbitrary policy predicates are later capabilities because they affect shared expression identities, subscriptions and cache invalidation. Until qualified, tenants requiring finer isolation use separate objects or deployments. Control/admin privileges are distinct from query privileges. Audit records include actor, request, affected catalog identities, result, incarnation and commit reference without raw credentials or row payloads.

## 8. Observability and user-facing diagnosis

Provide system tables for domains, views, plans, dependencies, arrangements, partitions, leases, source offsets, active pins, subscriptions, budgets, publications, builds and recovery jobs. Expose independent durable-input, computed and published uppers, and source lineage. All phase labels correspond to real durable or runtime boundaries.

Freshness diagnosis should answer: which dependency is blocking; what input age and backlog it carries; whether the bottleneck is source, schedule, compute, exchange, staging, metadata or delivery; and which intervention is supported. A sink lag must not be displayed as a materialization lag.

Metrics include throughput, rejected transactions, uncommitted bytes, object requests and latency, cache hit rate, state/history bytes, write amplification, exchange bytes, output fanout, pins and age, compaction debt, recovery bytes/work estimate, and attributed cost. Record histograms including timeout/error counts and correlate stage latencies with a domain/interval trace. Bound metric cardinality: per-row/key detail belongs in sampled diagnostic tables, not unbounded Prometheus labels.

`EXPLAIN INCREMENTAL` distinguishes estimates from measurements, identifies shared arrangements and state obligations, shows selected strategy and rejected alternatives, and states worst-case fanout/state caveats. An analyze mode must not mutate a production view or consume an unbounded stream without explicit bounds and budgets.

## 9. Failure handling and runbooks

| Incident | Immediate action | Recovery / evidence |
| --- | --- | --- |
| Worker loss | Fence generation; preserve last head | Restore exact state, replay durable interval, verify catch-up before reassignment completes |
| Metadata quorum unavailable | Stop new authoritative decisions and input acknowledgements requiring metadata | Existing pinned reads only within valid protection; revalidate heads/owners after quorum returns |
| Object store slow/unavailable | Bound retries and staged bytes; apply backpressure | Preserve manifests; resume from declared interval; do not claim a fresh result |
| Missing/corrupt published object | Fail affected reads/maintenance closed and isolate scope | Recover from protected replica/backup or qualified replay; exact validation before activation |
| Source retention loss | Stop source progress and mark rebuild required | New snapshot/incarnation, reconcile and replace dependent views |
| Runaway pin/history | Stop new pins or renewals per policy; notify owner | Honor existing contract until expiry; reclaim only through protected GC |
| Misbehaving query or huge fanout | Cancel or block affected work within its budget | Expose cause and previous good version; operator policy decides query/schema remediation |
| Sink ambiguity | Halt or use documented duplicate-allowed mode | Resolve committed destination marker before resuming stronger guarantee |

Incident tools perform conditional, audited state transitions. A “force advance frontier” operation is not an ordinary recovery primitive. Offline recovery produces a new validated incarnation, not a bypass of invariant checks.

## 10. Backup, restore and disaster recovery

A backup binds catalog, domain heads, source cuts, format/plan versions, durable arrangement checkpoints, input/output log requirements, security configuration references, and object checksums to one recovery root. Pin that root while copying or establishing protected immutable references. A same-account zero-copy snapshot is not an independent backup against account deletion or malicious credentials. Retention, encryption-key availability and separate failure scope are part of the backup profile.

Restore into an empty deployment, allocate a new incarnation, validate all manifests and required objects, establish new credentials/fencing, rebuild permitted derived state, reconcile source offsets/slots and sink delivery state, then validate exact results before serving. Restoring older metadata while leaving current writers active is prohibited. Tokens and workers from the original incarnation are rejected. Source resumption and external sink effects require reconciliation because restoring the database cannot undo external deliveries.

The first cloud profile targets zone failures with three metadata voters and suitably durable object storage. Asynchronous regional backup has a measured RPO and restore RTO; it does not offer zero acknowledged-data loss on region destruction. Synchronous multi-region publication would be a different latency/cost profile and remains outside initial scope. Publish DR measurements separately from ordinary worker failover.

## 11. Upgrade and compatibility

Version SQL semantics, plans, wire envelopes, arrangement codecs, manifests, token formats and metadata protocols independently where practical. Every binary declares minimum/maximum readable and writable versions and required feature bits. Mixed-version workers can participate only when their negotiated contract supports the active plan and publication descriptor.

Upgrade readers/control compatibility first, then workers, then enable new writes after the cluster supports them. Preserve old formats and generations through the rollback window. A state migration uses pinned backfill/catch-up/atomic activation, like a plan replacement. Do not roll back a binary that cannot read a newly written format; restore or forward-fix under an explicit runbook. Test interruption at every lifecycle state, including control-plane restart during a format migration.

Signing releases and recording dependencies/SBOMs support provenance; a signature does not establish correctness. Dependency versions are pinned only after the G0 adapter experiments. Existing Rockstream's versions are a baseline for comparison, not an automatic compatibility requirement for the successor.

## 12. Required qualification

G2 proves process-crash durability and resource errors through the actual public interface. G3 adds graph lifecycle, pins, subscriptions and live connector transcripts. G4 adds multi-process ownership, progress, skew, exchange, state beyond RAM and independent serving. G6 adds operational drills, rolling upgrades, restore, long-running isolation, and measured cost/freshness envelopes. Advanced G5 features rerun all affected lifecycle and recovery gates; an isolated operator benchmark never suffices.
