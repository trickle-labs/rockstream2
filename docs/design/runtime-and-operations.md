# Runtime, connectors, and cloud operations

**Status:** Proposed, 2026-11-25. No implementation or operational qualification is claimed. The [consistency specification](consistency-and-storage.md) governs publication and retention; this document describes how execution and operations obey it. [Requirements](../planning/requirements.md) define profiles and success criteria.

## 1. Execution model

The working choice is a lean **Rockstream-native Rust runtime**, with Arrow weighted batches, DataFusion for the SQL frontend and selected expression kernels, and Tokio for asynchronous I/O and task coordination. DBSP defines the incremental semantics; choosing that model does not require adopting Feldera's runtime. Reuse qualified algorithms and test infrastructure from the existing Rockstream selectively. The [G0 comparison](../adr/0005-runtime-selection.md) must still be able to overturn this choice in favor of Timely/Differential or suitable DBSP components if integration, correctness, or total cost warrant it.

Begin the native prototype through the [component disposition register](../planning/migration.md#donor-assets-and-regression-transfer): extract or adapt qualified donor components, replace incompatible mechanisms, and carry independent regression checks across both. This remains one native candidate with explicit owned progress and recovery responsibilities. Keep required operator state durable through suspension until an exact protected reconstruction recipe meets its resource and recovery budgets.

The initial execution kernel has a deliberately bounded scope:

| Boundary | Initial contract |
| --- | --- |
| Graph and time | Acyclic computation graphs and scalar logical epochs within each domain; no general recursion or partially ordered iteration time |
| Work in flight | One active maintenance interval per domain in G1–G2 (keeping recovery simple via exact-parent generation replacement); G3–G4 add **bounded single-depth pipelining** (overlapping compute for interval `k+1` with durable S3 flush/publication of `k`, invalidating `k+1` if `k` aborts) so cloud freshness is not capped by serialized object-store I/O |
| Parallelism | Operators and partitions execute in parallel within an interval under explicit byte, task, and outstanding-I/O limits; independent domains run concurrently |
| Execution | Weighted Arrow batches, deterministic error semantics, explicit prepare/publish boundaries, and view-level fault quarantine on derived runtime errors |
| Progress | Account for every admitted unit of work and asynchronous continuation; completeness is never inferred from elapsed time or an empty local queue |

G0.4 builds and validates the minimal native kernel on `W1-G`. Timely/Differential or Feldera/DBSP component evaluation is triggered only if the native kernel hits a concrete predeclared complexity or correctness blocker—avoiding a mandatory double-build of two full runtimes before G1. Keep semantic IR, logical time, and durable publication decoupled from scheduler internals, while maintaining **one** production runtime.

A physical plan is a versioned graph of tasks over virtual partitions. Tasks own operator state while scheduled on a worker; durable state identity survives the worker. A task descriptor includes deployment incarnation, tenant, domain, plan generation, topology revision, partition ID, ownership generation, unique `AttemptId`, input interval, arrangement handles, output schema, and resource reservation.

Execute vectorized Arrow batches in cooperative lanes. Operators on a lane have one mutable owner. Pure map/filter/project and compatible aggregation work can be fused. Storage, network, timer and scheduling edges are asynchronous; individual scalar expressions are not separate tasks. Keep the scheduler and progress machinery small and independently testable. A native runtime is a working implementation direction, not a measured performance advantage or a plan to reimplement storage, SQL parsing, networking, and consensus.

The same operator, state, progress and publication logic runs in embedded and distributed modes and in simulation. Inject clocks, randomness, scheduling, networking and storage failures at controlled environment boundaries. Exercise delayed/duplicated packets, interrupted writes, worker crashes, cancellation and backpressure against that production state machine. The simulator must not replace production algorithms with a simpler commit or routing path; unmodeled dependency internals still require real-dependency tests.

### Deployment and authoritative state

Ship one binary with composable roles. Logical planes are responsibilities, not mandatory services. No profile requires etcd, ZooKeeper, Redis, a separate catalog database, or Kubernetes. Libraries compiled into Rockstream are compatible with this requirement.

| Profile | Operator-managed requirements | Durable authority |
| --- | --- | --- |
| Embedded | One process and a qualified durable local directory | Local storage plus an embedded implementation of the metadata contract |
| Single-process cloud | One Rockstream process and a qualified object-store bucket | Protected object data and the transactional metadata root in object storage |
| Distributed cloud | Multiple instances of the same binary and the same qualified storage | The same object-backed authority; local memory, SSD caches and worker placement are disposable |

SlateDB is the preferred durable state backend. The arrangement layer owns logical versions, history coverage, and IVM access patterns; SlateDB's physical sequence numbers do not become Rockstream commit timestamps. Group compatible arrangements within partitioned databases rather than creating a database per view. Storage and computation are separated: maintenance, serving, and compaction can receive separate resource budgets without making a worker's disk authoritative.

Eligible running processes perform coordination through the [metadata kernel](consistency-and-storage.md). The default cloud design has no dedicated always-on voter tier. Its initial atomic logical metadata root may serialize metadata transitions; measure batching, contention and request cost before adding complexity. An embedded Raft library is a qualified alternative only if the object-backed design cannot meet demonstrated needs; it is not a prerequisite for the sleeping profile or an interchangeable implementation requiring no new proof.

### Task lifecycle

`Assigned → Restoring → Ready → Running → Preparing → Prepared → Published`, with `Draining`, `Fenced`, `Retrying`, and `Failed` branches. “Prepared” does not authorize reads. Each result domain has one atomic publication group and initially one active maintenance interval, including preparation, not merely one concurrent publication call. Retire or fence an abandoned attempt before admitting its replacement; delayed packets and uploads may still arrive and must be rejected or isolated. G2 uses one domain; G3 adds locally independent consuming result domains over common input/history, and G4 distributes them and adds general imports. Later pipelining requires every staged version to name its exact predecessor and dependencies and separately qualifies bounded speculation, memory, object bytes and replay cost.

On failure, recover from the last published manifest and replay durable inputs. Mutable caches, partial output, and uncommitted accumulator changes cannot be reused without proving their input interval and generation. Operators never patch a published result in place to recover from an exception.

Prefer generation/attempt replacement over live repair of partially computed state, inspired by [FoundationDB's recovery model](https://github.com/apple/foundationdb/blob/main/design/recovery-internals.md). Initially recover the affected domain's whole unfinished interval: reconcile ambiguous durable outcomes against the authoritative root, fence superseded ownership/attempts, reopen the exact selected published parent and replay accepted input under a fresh attempt (and fresh ownership generation on reassignment). If publication already committed, recover from that newer head; never roll it back because the response was lost. Preserve unaffected domains and their protections. Use the same authoritative recovery transitions for crashes, planned replacement, activation and compatible upgrades where applicable; exercise them routinely, including interruption during recovery itself. Finer-grained salvage requires measured replay cost, a reviewed exact-parent/fencing contract and independent qualification. This is not a cluster-wide generation reset or a requirement for FoundationDB's coordination topology.

### Exchange and replay

An exchange envelope carries domain/plan/topology, source and destination partition, interval, `AttemptId`, sender generation, stream ID, sequence/chunk ID, schema and encoding version, payload length, and checksum. A credit-based protocol bounds queued bytes, not just message count. Reject mismatched routing, schema, attempt or generation; checksum errors fail the interval.

Use either durable replayable exchange references or deterministic recomputation from retained inputs and the previous committed state. The first implementation should favor replay from durable input and stage boundaries rather than invent another consensus log for every edge. Delivery can repeat: `(plan, interval, attempt, edge, sender, sequence)` identifies duplicates while an interval is active. On restart, discard all tentative operator effects for an uncommitted interval, allocate a new attempt, and replay from the exact published parent. Delayed messages from an abandoned attempt are rejected even if the owner and epoch did not change. A dedupe set without a coherent state rollback is insufficient.

Completion accounts for all admitted messages and outstanding capabilities, including timers, spill reads, retries and recursive feedback when supported. End-of-stream on one socket is not proof that an epoch is complete. State transitions producing output must transfer progress ownership before releasing the input capability. Within a common logical timeline, computed upper `Cc` cannot exceed a required input/dependency upper. Across domains, use certified import/source-cut completeness and lineage rather than comparing numeric epochs. Durable published upper `Cp` advances only when the exact state, output, and history descriptors are protected and atomically published; `Cp <= Cc` within that domain. Epoch `e` on the same timeline is visible only when `Cp > e`. A crash can discard unpublished computed progress.

## 2. Memory, state and backpressure

Every task reserves memory for input, output, accumulators, arrangement cache, exchange, and staging. The scheduler admits a transaction or build only when its declared execution strategy can stay within the pool's limits. Large source transactions use durable chunks and a final complete envelope; their atomicity is independent of chunk size.

Each operator declares and enforces a resource contract: reserved resident/temporary and retained bytes, shared Arrow buffer accounting, maximum queued/in-flight batch bytes and tasks, I/O credits, fanout/chunking strategy, qualified spill representation, cancellation and exhaustion action. Track dependency allocations and process headroom; reserve before growth and test skew, large values and retractions. Reuse buffers, message envelopes and scratch storage where measured to reduce hot-path allocation/copy work. This is bounded dynamic allocation, not a startup-only allocation policy. G0.4 and G2 measure peak memory, allocation/copy work, spill, and overload behavior on the admitted workload.

Batch arrangement probes and writes, operator execution, exchange and durable preparation where amortization pays for itself. Bound bytes, count, work and delay; include actual logical work and amplification in measurements. Neither adaptive batching nor a physical checkpoint may erase intermediate logical cuts, reorder noncommuting source operations or weaken admission, publication or retention. Keep the existing [metadata batching contract](consistency-and-storage.md#421-bounded-metadata-commit-scheduler).

| Pressure | Required response | Forbidden shortcut |
| --- | --- | --- |
| Queue at byte limit | Withhold credits, stop upstream polling where supported | Drop records or acknowledge unseen source offsets |
| Operator working set exceeds memory | Use qualified spill representation or fail the affected publication | Evict correctness state as if it were cache |
| Output fanout exceeds budget | Stream bounded chunks to durable staging; admission can reject future oversized work | Truncate correct output to meet an SLO |
| Compaction debt grows | Reserve compaction capacity and reduce ingestion/admission rate | Report short-run throughput while debt grows indefinitely |
| History pins exceed quota | Refuse new pin/renewal or durably revoke protection at the contracted boundary | Delete data while its authoritative pin still protects it |
| Input log retention nearly exhausted | Wake consumers, retain more under policy, or stop acknowledgements/admission | Skip required replay or silently rebuild from an inconsistent source |
| Disk/cache fills | Evict reconstructible cache, throttle spill, reject new work | Treat local NVMe as the only copy of acknowledged input |

Backpressure must avoid circular resource waits. Reserve control/progress capacity separately from payload queues, and keep a small independently budgeted path for cancellation, fencing, error reporting, and lease/pin renewal. Spill writes cannot consume the memory required to release spilled buffers. Borrowed shared-state memory is charged once physically and attributed among consumers; enforce a hard pool limit independently of attribution.

An error after durable ingestion must never undo accepted source input or silently skip an event. Instead, apply **view-level fault isolation**: if a valid durably accepted transaction triggers a runtime evaluation error (such as `DECIMAL` overflow or division by zero) in one derived view, **quarantine that failing view** at its last valid published cut with an explicit `ERROR` state and actionable diagnostic, while unaffected views continue advancing. Views explicitly placed in a coupled atomic publication group halt together as the documented cost of joint atomicity. Repair alters or replaces the failing view and backfills cleanly from retained history. Poison records and quarantines are always explicit, audited states—never silent dead-letter drops.

### Feedback-driven admission

Complement hard resource bounds with a simple feedback loop, inspired by [FoundationDB's Ratekeeper](https://apple.github.io/foundationdb/engineering.html#ratekeeper). Measure per-domain/tenant and shared-pool pressure: accepted-to-published lag and backlog bytes/estimated work, queue and in-flight bytes, memory/spill, metadata queue age/CAS contention, object-store latency/request pressure, compaction and retained-history debt, and recovery capacity. Expose the binding constraint, observed/estimated pressure, throttle/reject reason, and admission rate/queue age. An input row or transaction count alone is not an IVM work estimate: skew, joins, fanout, retractions and slow consumers can amplify work and retention.

Start with conservative per-scope admission budgets, bounded sampling and hysteresis/cooldown; lower new offered work before shared pools exhaust capacity, and raise limits cautiously after pressure recedes. Estimates are advisory, never substitutes for enforced operator/reservation limits. Reserve progress for accepted work, recovery, publication, GC/pin control and cancellation; account for coupled storage and metadata limits and isolate unrelated domains where their guarantees permit. For connectors use their qualified pause/backpressure and source-retention policy; never discard accepted input, advance an offset prematurely, or silently weaken history/freshness promises. A controller outage or missing pressure signal uses conservative bounded admission rather than unlimited capacity. No standalone ratekeeper service or sophisticated controller is required initially.

G2 and G3 measure pressure signals and overload responses on real burst, high-fanout/skew, fail-slow storage, metadata contention, and slow-consumer scenarios. Compare simple fixed bounds with feedback where available; require bounded queues/debt/retries, no starvation of admitted control work or unrelated admitted domains under declared capacity, and recovery after finite overload heals. If measurements do not justify adaptive feedback, retain safe fixed budgets and diagnostics.

### Capacity for builds and changes

Before admitting a backfill, replacement, repartitioning or consumer-isolation build, reserve its peak coexistence budget across memory, durable bytes, I/O, metadata work and replay capacity. Count the physical union of current state, replacement state, newly retained input/history, compaction workspace, rollback roots and recovery headroom; do not double-count shared objects or assume old history disappears at activation. Include the time needed to catch up under ongoing admitted input and the source-retention window. A cheaper steady-state layout is inadmissible when its transition cannot fit.

Reservations belong to the durable build/intent lifecycle, so restart cannot forget an admitted obligation or admit overlapping builds against the same free capacity. Reconcile estimates with measured consumption and bound concurrent builds. Keep control/recovery capacity available; pause or cancel optional work through safe cleanup, reduce new admission, or obtain capacity when actual growth exceeds the reservation. Cancellation does not release bytes still protected by another obligation, and accepted input remains recoverable. Expose which retained roots, replay deficit or capacity bound prevents a proposed change and the declared exhaustion action.

G3 lifecycle tests include an isolation/build that appears cheaper after cutover but cannot fit its old-history tail and replacement overlap. The admission decision must reject or defer it before exhausting the pool; test restart with the reservation outstanding and verify that other admitted work retains its reserved capacity. Resource estimates are not a proof of bounded future input, so enforce the admission limits throughout the transition.

## 3. Scheduling and elasticity

Start with weighted fair scheduling across tenants and resource pools, then use freshness slack within a tenant's admitted budget. Favor a dependency on the critical path over a downstream task that cannot yet publish. Aging prevents starvation. Priority does not override durable ordering or memory admission.

Schedule the shared workload graph, rather than assigning one isolated always-running circuit to every view. Each consumer records its own next required logical cut, retained-history obligation, publication group, and maintenance policy. An arrangement can continue to advance for a fast consumer while another reads an older retained cut. Sharing an arrangement does not add an atomic publication barrier between unrelated groups. Actual dependencies and explicitly grouped transaction visibility still constrain progress. Sharing is optional: use isolated state when its lifetime cost or failure/SLO isolation is better.

Apply these bounds at the [storage ownership boundary](consistency-and-storage.md#53-storage-group-ownership-deferred-multi-domain-co-location) as well as the task queue. In G0–G2, each consistency domain owns its own SlateDB working index to prevent cross-domain writer interference; if multi-domain physical grouping is introduced later, attribute wait and service time to the group and affected members. Select isolation only when its reserved transition and retained-history cost fit, and report residual shared metadata/storage dependencies after the move.

### Consumer retention contracts and sharing cost

Register each consumer's contract before admitting its dependency. The contract contains its freshness target and scheduling mode; required logical cut/coverage and replay floor; maximum history age and retained bytes; maintenance, reconstruction and recovery budgets; and the allowed action at exhaustion. Real-time, standard, analytical, on-demand and historical profiles may supply defaults, but their durations and service levels are explicit configuration, not guarantees implied by a profile name. Historical obligations receive an independent budget even when current-state maintenance is shared.

Admission first checks full semantic and security compatibility, then evaluates whether the combined scheduling and retention obligations fit the shared placement's economic and physical budgets. Different cadences and retention windows are supported; profile names do not define sharing boundaries. Choose an isolated placement before attaching a consumer whose obligations would exceed the shared budget, or defer/reject if its isolated placement cannot be reserved either. Reserve peak build/replay overlap, retained old history, rollback and recovery capacity through the lifecycle admission path. Recheck policy changes against the live dependency state and preserve existing pins and promises while an admitted isolation or retention transition completes.

The shared compaction boundary must preserve the earliest still-promised cut and every other authoritative read, build, backup and recovery obligation. Charge additional retained history to the consumer that requires it, while enforcing a physical pool limit regardless of attribution. Exceeding a budget does not itself revoke a promise: obtain capacity, isolate the consumer, block new admissions/renewals, or perform an explicitly permitted expiry and resnapshot. Report the last valid boundary and unavailable coverage. Never silently advance a consumer cursor or delete required history to meet a cost target.

Compare sharing with isolation over a declared workload horizon using maintained base/index bytes, additional history, CPU, storage requests, network, compaction, serving latency, backfill, changeover duplication and recovery/cold-start cost. Equivalent SQL only establishes a reuse candidate. A slow consumer can make one shared copy more expensive than several bounded copies; an arrangement that cannot recover within the admitted budget is inadmissible even if it saves steady-state RAM. Start with explicit or rule-based choices and measured counters. Automatic adaptation follows only after safe isolation is qualified and must use hysteresis, cooldown, minimum expected benefit and a hard reconfiguration budget.

Scale decisions use backlog growth, estimated remaining work, source retention headroom, completion latency, CPU, memory, cache miss/restore rate, object-store throttling, exchange saturation and compaction debt. CPU alone is inadequate: adding workers during an object-store throttle can worsen both cost and latency.

Use a bounded controller: configurable minimum/maximum capacity, hysteresis, cooldown, one topology change at a time per group, cost ceiling, and rollback when measured throughput/freshness deteriorates. Expose recommendations before enabling automatic action. An autoscaler is a consumer of stable APIs; it cannot bypass publication or ownership rules.

### Skew

Detect skew by key-frequency sketches and actual per-partition service time, memory and fanout. Associative/decomposable aggregates can use partials and merge. Selected join inputs can be replicated if a costed plan preserves multiplicities and null behavior. A general hot join key or one huge transaction may remain inherently serial or output-bound; report that limit. Splitting a key without an algebraically valid merge is prohibited.

### Maintenance modes

| Mode | Trigger | Resume obligation |
| --- | --- | --- |
| Continuous | Durable input arrives | Keep up within admitted freshness and durability profile |
| Freshness-batched (adaptive microbatch) | Size/deadline threshold | Batch only complete transactions; preserve every advertised logical cut and publish every sealed interval correctly |
| Scheduled incremental | Catalog schedule fires | Pin base state and all replay input since last published cut |
| On-demand | A read requires a newer cut | Return wait/progress/timeout; never label the old result fresh |

### Suspension and scale to zero

Separate **stateless compute scale-to-zero** (stopping idle maintenance or serving pools on *all* cloud profiles) from **full zero-process hibernation** (`Active → Draining → Dormant → Restoring → Active`, supported on the **Object-Native** profile for eligible workloads):

- **Stateless compute scale-to-zero:** Maintenance and serving workers hold no authoritative state and scale down to zero whenever their workload is idle, while required continuous ingesters or optional Embedded Raft voters remain active.
- **Full zero-process hibernation:** Available on the Object-Native profile for genuinely eligible workloads (scheduled, intermittent, dev/staging, or batch-replayed pipelines with sufficient upstream source retention, no active low-latency SLA, and a documented manual or external platform activation trigger). Workloads with continuous PostgreSQL CDC replication slots, active Kafka sinks, durable timers, or ≤100 ms freshness targets use partial suspension or the Low-Latency Cloud profile rather than distorting online serving latency for a dormancy mode they cannot enter.

Use a durable lifecycle, `Active → Draining → Dormant → Restoring → Active`, with retryable or failed transitions recorded in metadata:

1. **Plan and drain.** Record the sleep scope, accepted-input and published heads, remaining replay obligations, consumer cursors, timer deadlines, source retention headroom, sink outbox state, storage budget, and wake condition. Serialize new admissions and wake requests against the lifecycle transition so an arrival racing the drain is either retained for resume or prevents dormancy.
2. **Protect and fence.** Publish completed intervals or discard tentative work while retaining its accepted input. Protect the exact base, logical history and replay roots independently of the dying process. Transfer or retire ownership through a conditional metadata transition; stale owners cannot commit new internal acceptance, publication, cursor or protection changes afterward. This cannot cancel a previously issued source acknowledgement or sink send: reconcile source acknowledgements against durable accepted positions and retain the initial sink's at-least-once guarantee unless destination-side fencing is separately qualified. Do not depend on an in-memory pin, renewable worker lease, or expiring backend checkpoint to preserve a sleeping database.
3. **Become dormant.** Commit the dormant record only after the required protections and fences hold. Suspend eligible processes; unfinished compaction or garbage collection may wait if this only retains additional bytes and stays within the storage budget. Full hibernation requires no live-client obligation, due timer, unprotected input, or sink-delivery commitment that demands an active process.
4. **Restore and resume.** An activator starts the binary. Re-read authoritative metadata, conditionally acquire fresh ownership generations, reopen protected state, and replay from the accepted and published boundaries. Validate source continuity, cursor coverage, and sink delivery before advancing. Concurrent activators use the same conditional ownership protocol. A lost source interval requires explicit resnapshot/rebuild rather than invented continuity.

Crash recovery and wake-up obey the same input, publication, fencing and retention invariants. A planned sleep additionally has a durable reason, expected duration, wake condition and resource budget. A crash during drain or resume must recover from the last authoritative transition, including ambiguous metadata writes.

| Obligation | Consequence for sleep |
| --- | --- |
| Continuous ingestion or tight freshness | Keep the necessary roles active, or explicitly relax the workload's policy; sleeping cannot promise continuous work |
| PostgreSQL WAL or Kafka offsets | Qualify external retention for the sleep interval and catch-up time; detect loss and rebuild when necessary |
| Maintained clock/timer | Persist deadlines and arrange activation before required work is due, or reject sleep under that freshness contract |
| Subscriber, build or historical read | Protect its exact retained cuts under quota and expiry policy; an expired cursor resnapshots |
| Sink outbox | Retain undelivered envelopes and durable delivery state; delivery deadlines may require an active sink role |
| Cold serving | Include process startup, state restoration and required catch-up in the response deadline |

A stopped process cannot receive a request or start itself. Full hibernation therefore supports explicit manual restart or a configured platform/launcher trigger. An always-on gateway, external schedule, or event source may provide activation, but is an optional deployment integration with its own cost; Rockstream does not mandate a separate coordinator or orchestration product. A plain binary-plus-bucket installation can hibernate and restart manually without promising unattended request-triggered wake-up. Expose the chosen activation mechanism and minimum active roles as deployment facts.

G0 measures a complete cold stop/resume experiment and its request/restore cost. G2 establishes durable single-process suspension; G3 adds independent shared consumers and retained history; G4 adds distributed drain, concurrent wake and stale-owner fencing. G6 qualifies the complete operator experience and long-running economics. None of these gates has yet run.

For a scheduled consumer, compare continuous maintenance, retained incremental history, replay from a protected base and bounded input history, and rebuild from a durable source snapshot plus a certified tail. Choose only a qualified strategy that satisfies the same retained-cut, source, freshness and recovery promises. Initial recovery still persists required state; a cheaper rebuild recipe does not authorize deleting it before that recipe and its retention handoff are qualified. Rebuilding current state cannot replace promised historical reads. If full hibernation cannot satisfy these obligations, retain the required roles and advertise partial suspension.

## 4. Reassignment, split and merge

Moving compute ownership and changing state partitioning are separate operations.

For a planned reassignment, choose a published boundary, stop admitting work that crosses the transfer, drain or discard tentative intervals, acquire the new ownership generation in metadata, reopen the exact durable state, and resume. The old owner is fenced even if its process is paused and later resumes. A failure-induced reassignment skips the graceful drain and replays from the published cut. Heartbeats or leases can suggest failure; atomic ownership generations checked by authoritative transitions provide safety. Lease expiry alone never authorizes an unfenced write.

Split/merge builds a new layout from a pinned version, routes catch-up into the replacement generation, validates key-range/hash coverage and row multiplicities, and changes routing plus active state references at a publication boundary. Both layouts can exist during migration; neither routing gaps nor double-applied input are permitted. Read and backup pins retain the prior layout as necessary. The catalog records progress so a coordinator restart resumes or aborts deterministically.

First cloud qualification should favor fixed virtual partitions and reassignment. Online repartitioning earns promotion after its separate race and failure matrix passes. Configure enough virtual partitions to permit initial scale-out without pretending that one fine-grained partition per row is free.

### Isolating a shared consumer

Consumer isolation changes the consumer-to-arrangement binding; it need not repartition the whole database. Qualify an explicit or rule-based isolation path with the first shared arrangements in G3, using the same safe replacement protocol:

An isolation build is separately admitted, bounded shadow work with no authority to publish a second maintenance interval for the consumer domain. Its temporary state, replay and durable staging count against build budgets; activation serializes with the domain's sole active interval. This does not enable descendant pipelining or a second production runtime.

1. Reserve build, duplicate-state and catch-up capacity. Record every promised historical cut, reader/build/backup obligation and operator recovery/replay requirement. Pin a supported snapshot and the complete replay history through the intended cutover; keep the original consumer registration and obligations active.
2. Build an isolated arrangement in a new generation, replay each complete transaction once and compare exact results and source lineage at a complete cut `C`. Certify complete operator recovery state and replay closure at `C`. A snapshot or matching endpoint result at `C` does not prove older cut coverage: the replacement must certify every still-promised cut, or its authoritative descriptor must retain protected references to the old shared history for those cuts. Updates beyond `C` remain durably replayable.
3. Quiesce the moving consumer at the verified cut and drain or fence its old-plan attempts; other consumers of the shared arrangement may continue. In one authoritative metadata transition, compare the expected live consumer publication head and cursor corresponding to `C`, binding/plan, generations and all protection/coverage obligations, then activate the replacement and transfer the unchanged cursor and retention obligations. If the old consumer progressed after verification, the comparison fails: catch up and reverify at the new cut before retrying. The transition fences old-plan publication and must neither regress progress nor duplicate downstream effects. A cross-root transfer is unavailable until its separate protocol is qualified.
4. Resume from the transferred cursor, applying only input not already included at `C`. Retain old state for every remaining historical/recovery obligation, valid reader and declared rollback window; release old obligations only after replacement coverage or retained authoritative references protect all of them. On failure before activation the old binding remains authoritative; resolve an ambiguous activation by identity before retrying. Record enough durable progress to resume or abort the build after a crash.

Include any retained old-history tail and its compaction/recovery cost in isolation's resource budget and savings calculation until the ordinary retention protocol legitimately releases it. If isolation cannot fit the reserved capacity or replay window, retain the old protection and apply the declared admission/exhaustion policy. Do not make progress by discarding history. G3 qualifies this path on the 100/1,000-view workload; fully automatic splitting remains separately gated in G5.

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

A request identity contains a server-issued signed client generation and monotonic sequence, scoped by deployment incarnation, tenant and domain. Persist a bounded admitted sequence window, payload digests, results and an irreversible low-watermark with the accepted-input head. A request below that floor or from an expired generation is rejected, even if its detailed record was reclaimed. Optional client labels are not the deduplication authority. Reusing a retained identity with a different payload fails.

Tables accepting direct SQL `UPDATE`/`DELETE` normalize retractions once against an **explicitly budgeted durable primary-key image index** at the accepted-input head (using the same SlateDB storage layer, explicitly accounted for in memory, storage, compaction, and cold-recovery budgets). Replay applies the normalized retractions/insertions rather than reevaluating SQL. Append-only event tables and PostgreSQL CDC sources carrying full before-images avoid this extra primary-key index completely.

## 6. Serving and subscriptions

Serving resolves authorization and exact snapshot dependencies before executing a query. Pin the catalog generation, logical cuts, and their backing roots in one coherent operation, then construct providers that read those cuts only. Select cuts from published retained coverage, rather than requiring the physical checkpoints of every input to coincide. For shared source lineage, the selected cuts must represent the same source positions and satisfy transaction/causal closure. Domain-local scalar epochs are not comparable across domains. If no compatible retained cut exists, wait for admitted catch-up, rebuild under an explicit contract, or report unavailability. Index absence can cause an admitted scan, a wait for an explicit build, or an actionable rejection; it cannot cause a read of a convenient newer mutable state.

Latest-committed selection retains a linearizable authoritative selection point. A separately requested allowed-stale policy can select an older covered cut; it must not describe an arbitrary replica's newest-known version as the authoritative latest result. Cache immutable metadata and reuse an authorized repeatable-read token where allowed. Ordinary readers may share durable protection through bounded reader groups only under the registration, release, revocation and completion protocol in [consistency and storage](consistency-and-storage.md). All read policies use its protection and source-compatibility checks. Covered reads amortize durable pin writes; a protection miss acquires new protection and resolves strict latest selection under that protocol. A cached head never establishes strict latest semantics.

Serving has separate CPU, memory, queue and cache budgets from maintenance. Shared object storage and network remain contention points, so measure mixed-workload interference. Cache keys include tenant, version, object generation, encoding and encryption context. Cancellation releases the reader's registration or owned pin and work reservations idempotently; it cannot release a group's durable protection while other admitted readers rely on it. Long-running queries renew protection under policy. Revalidate authoritative protection and authorization after reading the required bytes and before reporting a successful result or complete streaming unit; revocation or uncertain metadata prevents successful completion. A local timeout or signed token alone does not establish protection against GC. Any future lease shortcut must separately prove its clock, pause and deletion assumptions.

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
| Secret leakage | Configured secret references, including local credential injection; optional secret-manager integration; redacted logs, explain plans, errors and support bundles |
| Shared-state policy change | Reauthorize consumers and invalidate/rebuild incompatible identities at a catalog boundary |
| Corrupt or malicious stored data | Bounded parsers, format/version checks, authenticated transport, checksums and quarantine |

Initial isolation uses tenant/database roles and object grants. Row-level security and arbitrary policy predicates are later capabilities because they affect shared expression identities, subscriptions and cache invalidation. Until qualified, tenants requiring finer isolation use separate objects or deployments. Control/admin privileges are distinct from query privileges. Audit records include actor, request, affected catalog identities, result, incarnation and commit reference without raw credentials or row payloads.

Decommissioning and deletion follow the authoritative lifecycle and retention rules in [consistency and storage](consistency-and-storage.md). Distinguish revoked access, logical retirement and verified physical reclamation; expose outstanding pins, history, backups, source/sink obligations, provider retention and failed cleanup. No ordinary administrative command may bypass fences or protected roots. Restore reconciles newer applicable retirement/access decisions before reopening affected data.

## 8. Observability and user-facing diagnosis

Provide system tables for domains, views, plans, dependencies, arrangements, partitions, leases, source offsets, active pins, subscriptions, budgets, publications, builds and recovery jobs. Expose deployment/profile, retention and decommission status with clear blockers. The [implementation-start user journey](../planning/implementation-start.md) establishes the one-binary quickstart and diagnostic acceptance from G2. Expose independent durable-input, computed and published uppers, and source lineage. All phase labels correspond to real durable or runtime boundaries.

Freshness diagnosis should answer: which dependency is blocking; what input age and backlog it carries; whether the bottleneck is source, schedule, compute, exchange, staging, metadata or delivery; and which intervention is supported. A sink lag must not be displayed as a materialization lag.

Metrics include throughput, rejected transactions, uncommitted bytes, object requests and latency, metadata retries/contention, cache hit rate, state/history bytes, write amplification, exchange bytes, output fanout, pins and age, compaction debt, recovery bytes/work estimate, and attributed cost. Expose consumer cursors, earliest retained cuts, sleep eligibility and blockers, minimum active roles, activation cause, cold-start/catch-up latency and dormant storage cost. Record histograms including timeout/error counts and correlate stage latencies with a domain/interval trace. Bound metric cardinality: per-row/key detail belongs in sampled diagnostic tables, not unbounded Prometheus labels.

`EXPLAIN INCREMENTAL` distinguishes estimates from measurements, identifies shared arrangements and state obligations, shows selected strategy and rejected alternatives, and states worst-case fanout/state caveats. An analyze mode must not mutate a production view or consume an unbounded stream without explicit bounds and budgets.

## 9. Failure handling and runbooks

| Incident | Immediate action | Recovery / evidence |
| --- | --- | --- |
| Worker loss | Fence generation; preserve last head | Restore exact state, replay durable interval, verify catch-up before reassignment completes |
| Metadata root unavailable or conditional updates cannot be resolved | Stop new authoritative decisions and input acknowledgements requiring metadata; do not complete reads without required pin revalidation | Resolve unknown outcomes and revalidate pins, heads and owners before continuing |
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

The first cloud profile targets compute/zone failures using a qualified object-storage durability and conditional-write contract for both bulk state and metadata. It does not require three always-on metadata voters. Actual tolerance depends on the chosen storage profile and tested recovery path; a generic S3-compatible label is insufficient. Asynchronous regional backup needs a measured RPO and restore RTO; it does not offer zero acknowledged-data loss on region destruction. Synchronous multi-region publication would be a different latency/cost profile and remains outside initial scope. Publish DR measurements separately from ordinary worker failover.

## 11. Upgrade and compatibility

Version SQL semantics, plans, wire envelopes, arrangement codecs, manifests, token formats and metadata protocols independently where practical. Every binary declares minimum/maximum readable and writable versions and required feature bits. Mixed-version workers can participate only when their negotiated contract supports the active plan and publication descriptor.

Upgrade readers/control compatibility first, then workers, then enable new writes after the cluster supports them. Preserve old formats and generations through the rollback window. A state migration uses pinned backfill/catch-up/atomic activation, like a plan replacement. Do not roll back a binary that cannot read a newly written format; restore or forward-fix under an explicit runbook. Test interruption at every lifecycle state, including control-plane restart during a format migration.

Signing releases and recording dependencies/SBOMs support provenance; a signature does not establish correctness. Dependency versions are pinned only after the G0 adapter experiments. Existing Rockstream's versions are a baseline for comparison, not an automatic compatibility requirement for the successor.

## 12. Required qualification

G0 compares the preferred runtime with reusable alternatives, probes metadata contention and MVCC/storage cost, and measures complete stop/resume with empty caches. G2 proves process-crash durability, single-process sleep/resume and resource errors through the actual public interface. G3 adds graph lifecycle, independent consumer schedules, retained logical cuts, initial eligible factorization/partial aggregation, pins, subscriptions and live connector transcripts. G4 adds multi-process ownership, distributed suspend/resume, progress, skew, exchange, state beyond RAM and independent serving. G6 adds operational drills, rolling upgrades, restore, long-running isolation, and measured cost/freshness envelopes including dormant periods and wake-up. Advanced G5 features rerun all affected lifecycle and recovery gates; an isolated operator benchmark never suffices.
