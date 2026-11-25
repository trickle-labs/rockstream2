# Consistency, publication, and durable state

**Status:** Proposed. **Design date:** 2026-11-25. No Rockstream 2 engine or storage adapter is implemented by this document.

This specification defines the safety boundary shared by ingestion, incremental execution, serving, and operations. The [main design](../../DESIGN.md) describes the architecture; [semantics and compiler](semantics-and-compiler.md) defines the meaning of the results being published. “Must” below is a proposed implementation requirement, not a claim about existing software.

## 1. The contract and its limits

A published version is an immutable, durable description of a complete result at a declared input cut. It remains correct if every maintenance and serving process disappears. An accepted input is recoverable independently of whether its consequences have finished computing. A prepared worker result is invisible until the metadata kernel publishes it.

The default object-native cloud failure model covers process crashes, lost responses, message duplication and reordering, network partitions, disposable disk loss, and an availability-zone failure within the selected object service's qualified durability envelope. All authoritative input, data, catalog, publication, deduplication, ownership and retention metadata reside in that object service. Rockstream requires its qualified conditional-update and consistency semantics; it does not require an external coordination service. The model assumes authenticated, non-Byzantine components and detects corrupted bytes through checksums. It does not promise availability when the metadata root or required objects are unavailable, recovery from destruction of all authoritative copies, or zero data loss after restoring an older asynchronous backup.

The same logical state machine runs in an embedded deployment against a qualified local filesystem adapter with exclusive process ownership and durable root updates. A laptop restart is recoverable; destruction of its only disk is not. Cloud RAM, local disks and every Rockstream process may disappear without losing acknowledged state. That is a recovery guarantee, not a promise that a sleeping deployment can receive requests without an external launcher or platform activation path.

The safety invariants are:

| ID | Required invariant |
| --- | --- |
| CS-01 | Every published relation equals its specified query over the manifest's complete input cut, under the declared SQL numeric semantics. |
| CS-02 | Published progress never exceeds durable input and fully prepared computation. |
| CS-03 | Each accepted input identity has one logical effect, even if physical processing repeats. |
| CS-04 | One metadata transaction selects the visible version for a consistency domain. |
| CS-05 | A stale owner, plan, configuration, or restore incarnation cannot publish. |
| CS-06 | A reader uses exactly the versions and schema recorded by its snapshot token. |
| CS-07 | No object reachable from a live root, valid pin, or protected staging intent is reclaimed. |
| CS-08 | Resource or availability failures preserve the previous published result and return an explicit incomplete/error state. |

These are independently testable obligations. Algebraic proofs do not prove the storage protocol; storage tests do not prove SQL semantics.

## 2. Names, time, and progress

The first implementation uses an ordered `Epoch` within each consistency domain. A domain groups relations that need atomic visibility and one input ordering. It is not a worker, storage shard, tenant, or cluster. A tenant may have several domains, and a domain may span many workers. A transaction that changes multiple tables belongs entirely to one domain. Cross-domain atomic writes are rejected initially.

For the initial PostgreSQL connector, all subscribed tables that can participate in one source transaction enter one ingestion transaction domain; an arbitrary per-table split is forbidden. Independently progressing downstream view groups use consuming domains that import complete published source transactions/versions from that domain. Publication remains atomic within each declared group, so a slow required participant can block its group. This deliberate local synchronization cost cannot be optimized away by changing the advertised transaction boundary.

An upper frontier is **exclusive**: `U = 43` means all work at epochs `t < 43` is complete. A published version with upper `43` includes epoch `42`. Genesis has empty history and `U = 0`; publishing epoch `e` advances through `e + 1`. Counters must fail on exhaustion rather than wrap. All APIs, tests, interval descriptors, and metrics use this convention. Version identifiers and metadata revisions are separate from epochs; compaction can create a new physical version without changing the input cut.

| Name | Meaning |
| --- | --- |
| `ClusterId`, `RunIncarnation` | Stable installation identity and a fresh identity after disaster restore. |
| `DomainId`, `Epoch` | Ordered computation time within one consistency domain. |
| `SourceId`, `SourceIncarnation` | Source identity and lineage; resetting a stream cannot reuse its former offset identity. |
| `SourceCut` | Map from relevant source partitions to complete, durable source positions, plus source transaction boundaries and imported version lineage. |
| `VersionId` | Unique immutable publication record; never inferred from wall time or object listing order. |
| `PlanRevision`, `OwnershipGeneration` | Execution and placement identities validated at publication. |
| `AttemptId` | Unique execution attempt for an unpublished interval; never reused after abandonment. |
| `SnapshotToken` | Run identity, catalog revision, logical read cuts, protected publication/arrangement roots, source cut, schema/semantic versions, and a retention pin. |

Epoch numbers from different domains are incomparable. Comparing sales epoch `100` to fraud epoch `99` says nothing about freshness or causal order. Source positions also need typed comparators: PostgreSQL log positions, Kafka partition offsets, and direct-input sequences are not interchangeable integers.

Expose accepted, input-durable, computed, published, retained-history, and delivered progress separately. Within one domain, `published_upper <= computed_upper <= input_durable_upper` for the same plan and input interval. A computed frontier is a completion claim, not durable evidence. Delivered progress is per subscription or sink. Event-time watermarks are input assertions used by particular SQL operators; they are not commit frontiers.

A domain's input sequencer durably assigns complete transactions to epochs and seals intervals `[L,U)`. Several transactions can share an epoch, but no transaction is split across published intervals. Large transactions may spill while assembling; they become admissible only after their end marker and all fragments are present. Empty intervals can advance progress only when their input completeness is established.

### 2.1 Logical MVCC and supported cuts

Logical MVCC is a core arrangement and relation contract. It lets readers and downstream maintenance choose an exact retained cut while another consumer progresses. It does not add general OLTP transaction isolation or make ownership and publication atomic by itself. [ADR 0009](../adr/0009-logical-mvcc.md) records this choice.

Use **cut** `C` for the state containing epochs `e < C`. Every advertised relation/arrangement history records a computed upper `Cc`, a durable published upper `Cp`, an inclusive earliest reconstructible cut `S` (the logical `since` boundary), and exact cut coverage. Normally all cuts `S <= C <= Cp` are available; `Cp <= Cc`. At genesis, `S = Cp = 0` and the relation is `Q(empty)`. Epoch `e` is visible only when `Cp > e`. Metadata revisions, backend sequence numbers, physical checkpoint IDs and wall-clock timestamps are separate identities.

One valid representation is a durable base `R(S)` plus timestamped output deltas `ΔR(e)` for `S <= e < Cp`:

```text
R(C) = R(S) + sum(ΔR(e) for S <= e < C),  S <= C <= Cp
```

Records carry relation/arrangement identity, logical epoch, row/key and signed weight under a versioned encoding. The read descriptor selects the authoritative records and their physical roots; a timestamp filter over an uncommitted writer is not a snapshot protocol. Every advertised cut also has a protected boundary-indexed mapping to source positions/incarnations, transaction/import dependency closure and applicable schema/semantics. The mapping may be compressed, but logical compaction must preserve it for all supported cuts even after input segments are removed. Reconstructible rows alone cannot certify cross-domain compatibility. Stateful operators also retain the recovery state or exact reconstruction recipe needed at their own published boundary. A result trace alone is not necessarily sufficient to rebuild internal operator state cheaply.

Physical checkpoints protect the bytes used by this representation; they need not exist at every logical cut. A checkpoint at `Cp = 100` can serve cut `80` if its protected base and deltas actually reconstruct `80`. Publishing one batch `[L,U)` may make several logical cuts available at once, but it must preserve the results at each promised cut. For nonlinear operators such as DISTINCT, outer joins and MIN/MAX, netting all input changes across that interval can erase an intermediate result. The baseline evaluates complete epochs and retains their timestamped output; coarser evaluation is allowed only with a proof or a narrower explicitly declared cut-coverage contract. Correctness and initial `Q(empty)` still apply at every advertised cut.

Published coverage is certified by a committed descriptor. Merely retaining raw input does not make an old cut immediately queryable: replay requires the matching semantics, schema, plans and dependencies, and may be an explicit rebuild operation. Repair that bypasses an invalid intermediate snapshot records a coverage gap. A cut selector checks coverage as well as `[S,Cp]`; it never silently fills a gap or substitutes a nearby snapshot.

Consumers keep independent durable cursors, requested freshness and retention obligations. Shared producers can advance without waiting for every consumer to publish. A slow consumer can hold back logical compaction and consume storage; quotas, isolation into another copy, or an explicit expired-cursor/resnapshot outcome bound that cost. Physical sharing does not combine publication groups or impose a global barrier. A transaction is still all-or-nothing within its declared group.

## 3. Durable ingestion and acknowledgements

The authoritative input log contains normalized changes, source provenance, transaction boundaries, schema identifiers, input identity, and the epoch assignment. Raw source payloads may be retained separately for diagnosis, with access controls and an explicit retention policy. Parsing or schema failures stop the affected source or enter a declared quarantine workflow; silently omitting a record is not the default.

Initial cloud ingestion writes immutable log segments to object storage. A segment header includes format version, source and run identities, epoch interval, per-source position ranges, row/transaction counts, byte length, and checksums. Multipart uploads are not accepted as durable segments until completion succeeds. A small metadata transaction records their manifest root, advances the accepted input head, and records deduplication progress. It compares the expected input head, source incarnation, connector ownership generation, schema/catalog revision, and current ingestion authorization, so a stale source reader cannot accept input after reassignment or rebootstrap. Only then may Rockstream acknowledge the durable input or acknowledge source progress upstream.

Direct-write validation uses a serialized admission index at the **durable accepted-input head**, including previously accepted transactions whose views are not yet published. Validate key uniqueness, before-images, expected versions, and constraints there, normalize the SQL operation once, and replay those normalized effects. The index is either durable with that head or reconstructible from its protected source checkpoint and accepted log; recovery restores it before admitting further writes. Validating against only the last published view could admit conflicting updates while maintenance is behind.

Two distinct acknowledgements are supported:

1. **Durable input:** the exact input and its identity survive the declared fault model. Return a `WriteToken` binding the domain, assigned position, and run incarnation. A view can still be behind or blocked.
2. **Published result:** the named dependency set has a published version covering the write token. The response identifies that version. It does not mean external sink delivery completed.

A timeout can have an unknown outcome. The client retries the same idempotency identity or requests its status; it must not manufacture a new identity merely because an acknowledgement was lost. Reusing an identity with different bytes is an error.

Direct-input identities are `(client_id, signed_client_generation, sequence)`, scoped to run incarnation, tenant, database, domain, and operation stream; catalog mutations use a separate stream. Registration issues the generation and its validity bounds; clients assign sequences inside the admitted window. The input state durably records the generation, admission low/high watermarks, admitted gaps, payload digests, and recent result mappings. A closed generation or sequence below its replay floor returns `RS_IDEMPOTENCY_EXPIRED`, even if its detailed outcome was pruned. Optional opaque client labels cannot replace this identity. Unknown/expired generations require explicit registration; they are never treated as fresh retries. Once a request identity is registered, a definitive rejected outcome is recorded before replying and cannot become an acceptance on retry; a corrected request uses a new sequence. This avoids an impossible promise: an arbitrary forgotten string cannot be distinguished from a never-used string. Ordered source streams similarly retain a durable high-water position and lineage even after individual log segments are compacted.

For PostgreSQL CDC, the bootstrap protocol records a consistent exported snapshot and the corresponding stream fence, loads all captured tables against that snapshot, then consumes complete transactions after the fence. Restart must reconcile the recorded position and source incarnation. PostgreSQL explicitly documents possible retransmission after a crash and a snapshot/stream handoff mechanism; the connector therefore owns deduplication and gap detection. Slot invalidation or missing WAL causes a visible rebootstrap requirement. [S7]

For Kafka input, the identity is `(cluster/topic incarnation, partition, offset)`. Read-committed consumption excludes aborted transactions, but partition offsets alone do not establish a single atomic cut across arbitrary topics or databases. A cross-partition transaction guarantee requires a qualified connector protocol that assembles complete transaction boundaries; otherwise the capability is partition-ordered ingestion. Consumer-group offsets are advisory restart positions, never the authority for Rockstream's acceptance state.

Durable admission does not guarantee that every future view computation will succeed. An accepted transaction that triggers an arithmetic error or exceeds an operator's admitted bounds leaves published progress unchanged and marks the affected maintenance graph blocked. Repair requires a validated plan/schema change or a rebuild at a later complete cut containing all accepted inputs under an explicit repair contract. A later compensating row alone cannot make ordinary sequential replay pass an earlier failing epoch. A repair that widens an unpublished interval or rebuilds beyond that epoch preserves all accepted input and explicitly reports intermediate snapshots as unavailable; it does not manufacture historical results or silently skip the offending transaction.

## 4. The metadata kernel

### 4.1 One atomic metadata root on object storage

The default cloud deployment is the Rockstream binary plus a qualified object store. The metadata kernel is an in-process library. It requires no etcd, ZooKeeper, Redis or external SQL catalog, and no dedicated process that must stay alive during full suspension. Eligible Rockstream processes may coordinate active work; they recover authority from storage rather than from a privileged machine's memory.

Start with **one logical, conditionally updated metadata root per installation**. The bounded root identifies a monotonically increasing metadata revision, run incarnation, allocation generation and immutable metadata-tree root. Catalog, domain heads, ownership, pins, intents, operation outcomes and lifecycle records live in that tree. Immutable pages are prepared durably before the conditional root update. A successful expected-version root transition atomically selects the new tree and is the linearization point for its logical transaction. It may update several records together without a multi-object transaction in the object service.

The storage primitive must provide a linearizable read of the current root and a durable conditional transition from an expected revision. AWS S3 documents conditional object writes; other services and S3-compatible implementations require their own qualification. An ETag is an opaque condition token, not necessarily a content hash. Unconditional last-writer-wins overwrites, a successful object upload, or an eventually consistent root listing do not implement this contract. [S1]

Evaluate reuse of `slatedb-txn-obj` before writing this primitive. Its transactional object and optional epoch fencing concern **one logical object**. Its object-store protocol can use a sequence of versioned objects rather than overwriting one physical key. Rockstream must verify the chosen protocol's conditional-create, current-version discovery, deletion-boundary and error semantics. It does not provide automatic multi-record catalog transactions, ownership leases or the pin/GC protocol. Grouping the required records beneath one authoritative root is Rockstream's design responsibility. The root abstraction does not mandate one physical object layout. [S2]

The embedded profile uses the same logical root transitions on a qualified local filesystem, with an exclusive process lock and durable recovery of acknowledged changes. Its adapter must explicitly implement the required compare-and-update/durability behavior; ordinary rename alone is not a multi-process CAS. Embedded libraries may supply that implementation, but they add no separately operated service. Local storage has the failure envelope described in section 1.

### 4.2 Atomic predicates, contention and failures

| Record | Essential fields |
| --- | --- |
| Domain | Input head, publication head, plan/catalog revisions, ownership generation, status. |
| Publication | Parent/version identity, root digest, upper, supported cut coverage, source-cut digest, semantic/storage format versions. |
| Ownership | Immutable assignment-map root, generation, authorized publisher identity, scheduling heartbeat. |
| Staging intent | Attempt identity, expected parent/generation, protected bases, allocation namespace, lifecycle state. |
| Pin | Protected roots and logical cut/range, owner, purpose, revocation/renewal generation, explicit retention policy, run incarnation. |
| Restore/backup/lifecycle | Retained roots, metadata revision, completion state, suspension or activation generation. |

**All predicates that jointly authorize a transition are checked against the same root revision.** For publication these include expected parent, run, catalog/plan, ownership generation, publisher identity and sealed intent. For retention they include version eligibility, existing references/pins and retirement state. Checking a fence in one object and updating a publication pointer in another does not provide atomic fencing. A failed CAS refreshes the root and revalidates every predicate; it cannot blindly replay a mutation calculated from stale state.

The root write is small, but the tree, reads, conflicts and serialized transition rate still cost requests and latency. The initial design must qualify the commit scheduler below and [reader-group protection](#81-amortized-reader-protection); per-logical-operation remote writes are not an acceptable unexamined default. Notifications and caches cannot authorize a commit or pin. Measure root contention, pin churn, admission and publication together under thousands of views. One root is a first implementation constraint, not an assertion of unbounded scale. Independent groups need not wait for one another's computation; they do share this metadata serialization point.

An unknown write outcome is reconciled by stable operation/attempt identity recorded in the selected tree. A timeout is neither evidence of failure nor permission to repeat a non-idempotent effect. Bootstrap uses conditional creation and a unique installation identity; concurrent bootstrap/activation must converge on the existing root rather than create separate authoritative histories. Metadata revision and ownership counters never wrap or get reused. Loss of access stops new authoritative transitions and GC; it must not elect an unfenced local authority.

Large source cuts, schemas and partition receipts are immutable objects referenced by authenticated digests. A publication coordinator validates the full expected receipt set and creates a sealed preparation record tied to a fixed parent, plan, ownership generation and intent. A digest establishes content identity, not correctness: the validator traverses the expected partition set and rejects duplicates, gaps, mismatched intervals and foreign receipts. The final root transition compares the identities that made that validation valid.

The initial simplification is one `OwnershipGeneration` per publication domain. Reassignment invalidates all preparations under the old generation. Physical storage groups also have explicit ownership/fence identities; grouping arrangements does not let one domain's stale writer mutate another's committed storage. Finer-grained fences and partitioned metadata require separate models and measured benefit. Splitting the atomic root without replacing its cross-record transaction guarantees is forbidden.

#### 4.2.1 Bounded metadata commit scheduler

An embedded scheduler collects compatible logical operations into one root transition. Each operation declares a stable identity and payload digest, tenant/run and logical scope, expected versions, complete predicate/read and write footprint, required durable references, priority/deadline and result. These are logical contract fields, not a frozen Rust interface. All scopes initially map to the same root.

1. Admit into bounded queues with per-scope fairness and explicit overload responses. Bound queued count/bytes, batch count/bytes, metadata preparation work, retry work and maximum group-commit delay. Reserve service for fencing, revocation and lifecycle operations without allowing either priority traffic or bulk publication to starve other admitted work. A disposable preferred committer reduces competing CAS attempts; routing, heartbeats and its process identity grant no authority beyond each operation's checked authorization.
2. Read authoritative revision `R`. Resolve already-recorded operation identities before planning new effects. Validate every candidate against `R`, including authorization, quotas, absence/range predicates, retention references and the durable preparation proof. The initial batching rule accepts only operations whose writes do not invalidate another candidate's reads, predicates or writes. Disjoint domain IDs or distinct metadata pages alone do not prove compatibility. Defer conflicts; do not compose dependent transitions using an invented intermediate revision.
3. Prepare the immutable metadata tree containing all selected effects and their individual outcome records. Commit one conditional transition from `R`. All accepted effects become visible at that transition; each operation retains its own identity, result and source-transaction boundaries. Co-batching unrelated operations does not promise clients a new cross-domain transaction API. Unselected work remains pending; a definitive rejection follows the durable identity/outcome rules rather than silently becoming acceptance on retry.
4. A known conflict reloads and revalidates the whole remaining batch. An ambiguous response reconciles **each operation**, even if the root has since advanced or retries regroup operations into different batches. Durable outcome records and retained identity/replay floors prevent both duplicate effects and forgotten retries being treated as new work. Batch IDs alone are insufficient. Do not acknowledge a queued operation before its durable outcome exists.

Group-commit delay adapts to observed load within declared latency and resource limits; sparse traffic need not wait for a full batch. Losing the committer loses only unacknowledged volatile scheduling work: callers retry stable identities and another eligible process reconstructs authority from storage. Suspension drains or reconciles pending durable work under the normal lifecycle protocol. Report logical operations per successful root transition, total root reads/CAS attempts, conflicts, metadata-page writes, queue age, rejected/timed-out work and cost; batching the root while multiplying tree writes is not automatically an improvement.

#### 4.2.2 Scoped transactions without premature partitioning

Make the metadata transaction boundary explicitly name all affected scopes and predicates. Keep publication, fencing, ownership, authorization and retention conditions that must be atomic under one authority. The initial implementation resolves every scope to one root and rejects unsupported cross-authority operations; it does not implement distributed transactions or hidden best-effort updates.

If measured aggregate throughput remains inadequate after batching and reader amortization, evaluate independent installations/tenants or dependency-closed domain groups as partition boundaries. A cross-root import would require protected immutable source history, a durable import identity/reference, destination acceptance and an idempotent acknowledged handoff of every retention/replay obligation before source protection is released. Crash or ambiguity must retain protection conservatively. Independent CAS operations cannot replace an atomic publication/fence or a pin/retire decision. Model and qualify that protocol, including restore and retirement, in a separate ADR before moving a live scope.

### 4.3 Raft as an evidence-triggered alternative

If G0 establishes that the object-store root cannot meet an important supported workload's latency, contention or availability requirement, evaluate a mature **embedded Raft library**, such as OpenRaft, for a separately specified metadata profile. Do not implement a new consensus algorithm. The library still requires integration of durable votes/logs/snapshots, networking, membership, recovery and the same metadata state machine. A quorum must be available to commit new decisions; a dormant deployment cannot both stop every voter and keep answering requests. Durable quorum state and its backup/restore path would become authoritative infrastructure for that profile. [S3]

This is not a silent runtime switch or a prerequisite for the default deployment. Any alternative needs a new ADR, migration/recovery design, conformance evidence and a clear operating-cost benefit while preserving the requirement of no separately operated coordination service.

| Profile | Metadata authority and selection | Operating contract |
| --- | --- | --- |
| Object-native, initial default | Qualified conditional root and linearizable root reads | No active quorum; eligible full suspension relies on protected object state and an external activation path |
| Embedded consensus, candidate only | Replicated durable log applying the same logical metadata transitions; separately qualified linearizable reads | Active quorum for decisions; votes/logs/snapshots/membership and stop/restart must be preserved under its declared failure model |

Insufficient throughput triggers evaluation of scoped partitioning; irreducible coordination latency triggers evaluation of embedded consensus. Both need measured justification. Stopping every voter is not ruled out in principle, but complete hibernation requires its own qualified durable-state and restart protocol; the object-native guarantee cannot simply be copied to that profile.

## 5. Immutable arrangements and backend contracts

Use **SlateDB as the preferred backend**, with an IVM-specific arrangement layer that implements the logical MVCC contract. The goal is to reuse its storage, compaction and durable-version machinery. Do not plan a new general storage engine or a broad interchangeable-backend framework. A simple immutable-batch implementation may serve as a correctness oracle/prototype; a production replacement requires evidence of a material unresolved drawback, consideration of an upstream fix and an explicit decision.

An arrangement's logical identity includes normalized expression, schema, key/equality/collation rules, tenant/security scope, source/time lineage and semantic version. Its physical identity adds partitioning, encoding, algorithm version and storage group. Equivalent expressions do not authorize incompatible security or retention sharing. Avoid a database per view: place compatible arrangements in partitioned SlateDB databases using explicit namespaces. Grouping requires compatible ownership/recovery and I/O budgets; measure writer, checkpoint and compaction contention and isolate groups when needed.

The boundary deliberately has **no public publish method**. Operators prepare state; only the metadata kernel selects authority.

```rust
// Contract sketch; types and async syntax are not an implementation API.
trait ArrangementStore {
    fn open_as_of(&self, history: PublishedHistory, cut: LogicalCut,
                  pin: &ReadPin) -> Snapshot;
    fn lookup(&self, snapshot: &Snapshot, key: Key) -> WeightedRows;
    fn scan(&self, snapshot: &Snapshot, range: KeyRange) -> BatchStream;
    fn prepare(&self, base: PublishedHistory, changes: TimestampedChanges,
               intent: &StageIntent) -> DurablePrepared;
    fn verify(&self, prepared: &DurablePrepared) -> IntegrityResult;
    fn compact(&self, history: PublishedHistory, permit: &CompactionPermit)
               -> DurablePrepared;
    fn release(&self, retired: RetiredVersion) -> ReclamationWork;
}
```

`PublishedHistory` binds exact physical references, an authorized logical cut range/coverage, schema/semantic/codec versions and the per-cut lineage mapping. `DurablePrepared` certifies an exact parent, `[L,U)`, attempt, ownership identities, timestamped output/recovery state, checksum root and protected backend checkpoint(s). It is returned only after required bytes and backend retention survive process destruction. A successful mutable write, transient snapshot or local spill file does not satisfy it. `compact` prepares equivalent replacement data; it cannot advance `since` or retire old roots on its own.

SlateDB physical sequence/snapshot semantics do not implement Rockstream's logical time, source transactions or cross-arrangement atomic publication. Durable checkpoints and in-process `DbSnapshot` objects have different lifetimes. Published reads use named, protected checkpoints, never a live writer or an unprotected follow-latest reader. Await the selected release's actual durability and checkpoint completion boundary. [S4] [S5]

A conservative adapter restores an isolated attempt from the exact logical parent and its protected backend state; qualify native cloning before relying on it. It serializes each storage group's checkpoint boundary: finish the intended writes, prevent overlapping writes from making that boundary ambiguous, await durability, create the checkpoint, and verify its membership. A physical checkpoint can contain several arrangements and support several logical cuts. Per-arrangement descriptors specify which committed namespaces and logical history are readable; unrelated data present in the physical checkpoint gains no visibility. Physical batching must not require every independent consumer to reach the same logical upper.

After abandoning a preparation, discard its speculative mutable branch or exclude its namespace under the qualified protocol below, and initialize the next attempt from the exact published parent. Reopening a live prefix can recover unpublished writes; applying the interval again to that state is forbidden. Sharing physical databases does not relax this requirement. G0 must establish a concrete namespace/branch protocol for grouped arrangements without duplicating or losing another consumer's committed state. Reusing a writer after a successful publication requires proof of the selected parent and isolation from speculative descendants.

Before publication establish **non-expiring durable checkpoint protection**, linked to a registered staging intent. A temporary checkpoint may be used while preparing, but its expiration must be removed and durability confirmed before its dependent publication commits. Do not assume a background refresh after acknowledgement will run before a long outage or full suspension. An ambiguous checkpoint creation is reconciled by saved identity. A crash can leak an orphan; reconciliation must conservatively protect or quarantine it, not guess that it is disposable. No native checkpoint is deleted until Rockstream's root graph proves it unreferenced.

Qualification must demonstrate exact logical reads after process destruction; timestamp-aware compaction; physical checkpoint sharing; stale-writer fencing; aborted attempts and retries; independent readers during native GC; and rolling-upgrade compatibility. Measure point probes and scans, write/request amplification, retained history, merge/consolidation costs, small-batch overhead, clones, and cold start. If a contract or important cost target fails, first investigate layout, batching or upstream changes. Never weaken publication or retention semantics to fit a dependency.

### 5.1 Logical history and physical checkpoints

Qualify three complementary representations: an index for current-state point lookups and joins, timestamped logical deltas, and periodic consolidated bases that bound reconstruction. The current-state index may be durable or a reconstructible cache, depending on measured cost. It must bind to the selected committed history/cut and be recoverable from protected authoritative state; a mutable latest index cannot answer an older or uncommitted cut. Preserve separate operator recovery state when the output relation is insufficient.

One physical checkpoint should cover many logical epochs and, where compatible, several arrangements. Checkpoint frequency follows qualified durable preparation/grouping and publication latency, not a requirement to checkpoint every logical epoch. New bytes cannot be published until their checkpoint or other qualified durable retention reference exists. A later checkpoint can protect earlier cuts only when the descriptor and stored history certify them. SlateDB checkpoints pin manifests and reachable files rather than copying an entire database; many retained checkpoints can nevertheless keep obsolete files alive. Account for physically retained bytes separately from logical history bytes. [S5]

Budgets cover historical probe/scan amplification, reconstructed bytes and latency, retained logical/physical bytes, compaction debt, object requests, checkpoint count, clone dependencies and recovery time. Trigger base creation and index/compaction work from those budgets and observed workload, with bounded background work, not a fixed timer alone. Creating a newer base does not retire the older history: advance `since` only when every still-promised read, consumer and recovery cut remains reconstructible. Pressure causes admission/backpressure, isolation or a contractually permitted resnapshot, never silent history loss.

### 5.2 Exact-parent preparation alternatives

P0.2 must compare the following under identical histories, failures and retention promises before selecting an adapter strategy. These are alternatives to qualify, not three required production paths.

| Strategy | Intended role | Required proof and costs |
| --- | --- | --- |
| Protected checkpoint plus isolated clone | Conservative recovery/branch baseline | Exact explicit source checkpoint; include manifest requests, referenced WAL copying, external checkpoint dependencies and eventual GC |
| Immutable attempt namespaces selected by manifests | Candidate for frequent preparation/publication | Only committed manifest membership determines visibility; bound namespace/manifest growth and abandoned-attempt retention |
| Reuse an existing writer | Candidate normal path after successful publication | Prove exact committed parent, exclusive authorized writer and isolation from every speculative descendant across crash/reopen |

For attempt namespaces, use fresh identities bound to run, storage group, ownership and attempt. Register the protected parent and allocation intent before writing; never overwrite parent or sealed bytes. Seal the exact attempt object/namespace membership and protect its physical checkpoint before publication. A committed manifest selects that attempt plus explicit protected parent dependencies. A new attempt reads only that selected closure, even if its backend checkpoint also contains abandoned or future namespaces. This exclusion applies to point probes, range scans, join indexes, current-state caches, compaction and reopened-writer recovery, not just final output filtering. A logical epoch predicate alone cannot distinguish two attempts for the same epoch. No orphan can become a recovery parent through a backend latest pointer, raw key lookup or listing.

Abandonment prevents publication and leaves cleanup to the normal intent/retention/GC protocol. Stale writers may create isolated garbage but cannot overwrite committed namespaces. Physical grouping must not import speculative state from a different domain; serialize conflicting writer/checkpoint work or isolate the storage group. Bound parent-chain depth and lookup fanout through verified consolidated replacement manifests while preserving promised cuts and roots. Failure to prove these properties keeps the clone baseline or blocks the affected grouping capability.

SlateDB shallow clones share existing SSTs but have independent manifests/WAL, may copy referenced WAL SSTs, and retain external checkpoint dependencies. Administrative clone creation does not flush a live source writer; use an explicit checkpoint containing the required durable writes. Immutable attempt isolation is a Rockstream hypothesis, not a transaction facility supplied by SlateDB. Revalidate all API details at the selected revision. [S9]

### 5.3 Storage-group ownership and interference

A result domain is an atomic publication boundary; a storage group is a physical ownership and scheduling boundary. Distinct domain generations do not authorize concurrent independent writers to one mutable SlateDB database/branch. Each group has one fenced writer authority and a serialized preparation/checkpoint schedule under the selected adapter protocol. Work names both its domain attempt and group generation. Ownership-changing and publication transitions validate the applicable fences together; a new group owner restores each member's committed closure rather than treating one member's latest checkpoint as every member's parent. Group takeover may pause all colocated members and must be reported as their shared recovery scope.

Co-batch only already eligible preparations whose exact memberships remain independently selectable. A group may checkpoint several domain cuts without requiring unrelated domains to reach a common logical cut. Physical writer serialization can still delay one member behind another; bound batch-fill delay, checkpoint wait, queued bytes and per-member I/O work, with reserved capacity for control, recovery and compaction. If the selected backend cannot enforce the admitted interference envelope, use separate storage groups and account for their additional state and requests. Fair scheduling does not promise progress during an unavailable storage service.

P0.2/P0.8 compare grouped and isolated placement with one fast consumer, a history-pinning consumer and a large backfill or compaction load. Under the declared offered load, measure per-domain publication/read tails, checkpoint wait, retained physical bytes, recovery scope and the full cost of isolation. Inject writer loss and a delayed old writer while another member publishes; verify every member's exact parent and promised history after takeover. This evidence distinguishes independent publication from resource isolation without adding a global logical barrier.

## 6. Publication protocol

A version manifest contains domain/run/attempt identity; parent version; `[L,U)`; durable published upper, logical `since` and supported cut coverage; complete source-cut and imported-history lineage; plan/catalog/ownership revisions; arrangement roots; timestamped durable output-delta roots; input-log references; complete expected partition coverage; schema and codec versions; and reconstructibility descriptors. Unchanged arrangements reuse protected parent references. The graph is acyclic and integrity checked.

Preparation is speculative; visibility remains ordered per domain. Initially permit **one active maintenance interval and attempt per publication domain**, from parent selection through publication or abandonment. Operators and partitions within that interval, and independent domains, may execute concurrently. Descendant pipelining is deferred until a measured bottleneck and a separate progress/recovery qualification justify it; descendants would need invalidation whenever their expected parent is not published.

```mermaid
stateDiagram-v2
    [*] --> Registered
    Registered --> Preparing
    Preparing --> Sealed
    Sealed --> Published: atomic metadata transaction
    Registered --> Abandoned
    Preparing --> Abandoned
    Sealed --> Abandoned: fence or parent mismatch
    Published --> Retained
    Retained --> Retired: no required roots or pins
    Abandoned --> Reclaimable
    Retired --> Reclaimable
```

The protocol is:

1. Read the domain head and fixed membership. Register an intent, pin its base/dependencies, and reserve a unique allocation namespace. Seal the complete durable input interval. Admission reserves enough capacity or returns a controlled backlog condition.
2. Execute from the exact parent state. Exchange messages carry run, plan, generation, `AttemptId`, epoch, producer/partition identity, and sequence. Receivers reject messages outside their active attempt. Acknowledged transport completion does not replace logical frontier accounting.
3. Each expected partition prepares durable arrangement changes and output changes, then records a receipt bound to that exact attempt. Partitions with no changes still attest completion. A coordinator must not infer an absent partition from a lack of traffic or combine receipts from different attempts.
4. Validate the complete receipt set and all object/checkpoint references. Produce a sealed manifest and an immutable validation record. Sealing makes the attempt's object membership immutable.
5. Atomically compare the expected domain head, run incarnation, catalog/plan revision, membership generation, authorized publisher identity, and sealed intent; install the version, advance published upper/source cut, and mark the intent published. This is the visibility linearization point.
6. Notify serving and delivery workers. These notifications may repeat or disappear; workers reconcile from metadata. Resolve lost responses by looking up the attempt/version identity.

```text
publish(attempt):
    p = load_sealed_preparation(attempt)
    require verified_complete(p) and p.upper <= durable_input_upper
    return meta.compare_and_write(
        domain.head == p.parent,
        run == p.run,
        domain.plan == p.plan,
        domain.catalog == p.catalog,
        domain.generation == p.generation,
        domain.publisher == p.publisher,
        intent.state == SEALED and intent.digest == p.digest,
        writes = [version_record(p), domain_head(p), intent_state(PUBLISHED)]
    )
```

The comparison against durable input is tied to the sealed input reference and its recorded acceptance proof; a stale numeric observation alone is insufficient. The trusted coordinator validates the immutable preparation, while atomic comparisons prevent the validated facts about parent, membership, and authorization from changing underneath it.

**Concrete recovery example:** the published head is `V17`, upper `43`. Input `[43,46)` is durably accepted. All partitions stage `V18`, but the coordinator dies before the transaction. Readers still see `V17`; recovery may finish a valid sealed attempt or recompute `[43,46)`. If the transaction committed and its response was lost, recovery sees `V18`, upper `46`, and resumes at `46`. It never integrates `[43,46)` again into `V18` merely because a worker failed to hear the acknowledgement.

## 7. Ownership, exchange, and reassignment

Heartbeats and scheduling leases help detect abandoned work. Safety comes from immutable namespaces, monotonic generations, and generation comparisons in the same root transition that publishes. A worker's belief that its clock or lease permits work is not authority. Competing recovery/activation attempts acquire ownership by CAS; losing candidates cannot publish. Restart after ordinary failure and wake from suspension use the same fencing and exact-parent recovery invariants.

For reassignment, stop admitting new work for the selected domain interval, let eligible work publish or abandon it, pin the last published root, and atomically install the new assignment map with a higher generation. The replacement restores that root, replays only accepted unpublished input, then resumes preparation. A stale process may finish uploading old-generation objects, but it cannot make them visible. Its messages are rejected by new-generation receivers.

Moving ownership does not change the logical partition layout. Splitting or merging durable partitions is a separate operation: create shadow partitions from a pinned boundary, catch them up, validate coverage and output equivalence, and switch the layout with a new plan/catalog generation at a publication boundary. The old layout remains pinned until readers, rollback policy, and replay users release it. No partition is removed from completeness accounting before its replacement covers the cut.

The initial recovery design replays a whole unpublished interval instead of relying on durable per-message acknowledgement logs. Bounded exchange buffers and producer sequence identities permit duplicate suppression within an attempt; an attempt restart allocates a new `AttemptId` and reinitializes all affected mutable state from the published parent. Suppression state is keyed by attempt as well as producer and sequence. Delayed packets from an abandoned attempt must be rejected even when run, owner, plan, and epoch are unchanged. A later partial-task recovery scheme must prove it does not mix outputs from different attempts.

## 8. Cross-domain consistency and serving

Independent domains improve liveness only for independent dependencies. They do not create a global transaction order. A cross-domain maintained query initially imports explicit, published input versions into a consuming domain. Imports carry complete lineage and source cuts, and the consuming domain durably records the import as input. A new import is a version-to-version delta, not a change in a pointer to an independently moving latest value.

Compatibility requires **equal complete boundaries for every overlapping source incarnation**, complete source transactions, and closure over recorded causal/import dependencies. Merely requiring each view's frontier to be greater than or equal to a target is insufficient. For disjoint sources, the product cut is explicit but does not assert that those sources participated in a real-world atomic transaction. If overlapping dependencies cannot be aligned using certified logical history, the query waits for a supported compatible cut or fails with an actionable consistency error. It never picks independently latest versions and labels the join consistent.

An import first acquires a durable source-version pin and retains its lineage. It may release that pin only after all required imported bytes and future replay obligations are durably owned by the consumer, or after references to the source objects have disappeared. Sharing an object pointer across domains transfers no retention ownership by itself. Dropping or pausing a producer cannot invalidate an accepted consumer input.

Example: `orders_summary` has source cut `{orders: 100, customers: 70}`; `customer_flags` has `{customers: 73}`. Reading both latest versions mixes customer states. Reconstruct `customer_flags` at the compatible customer boundary `70` from certified retained history, advance and align the summary, or fail. It is not necessary that both producers created a physical checkpoint at `70`. It is necessary that the selected logical histories have compatible lineage, complete transactions and causal closure. Source offsets here are illustrative typed boundaries, not domain epoch values. An import cycle between domains is rejected initially; recursion belongs inside an explicitly supported computation scope.

For histories in the **same logical time domain**, a candidate cut satisfies `max(S_i) <= C <= min(Cp_i)` and belongs to every history's supported coverage. For a latest common read choose the greatest eligible cut; if no such cut exists, wait or fail. Across domains, perform this selection through source-cut/lineage mappings and dependency closure, not a numerical minimum of unrelated epochs. A physical checkpoint may be newer than `C` while its logical history validly reconstructs `C`. The returned token records both the logical cut and the exact protected roots used to produce it.

Read policies select a certified cut and physical roots, then use the same pinning protocol. Latest committed reads resolve authoritative heads at a linearizable metadata selection point and choose the latest compatible cut. An explicitly requested allowed-stale policy may select an older eligible cut and reports it; replica lag does not silently redefine latest committed. Bounded-staleness reads verify the freshness contract and wait/fail if the replica cannot load an eligible cut. Read-your-writes follows the write token's dependency coverage. Historical reads require a certified retained cut; they never fall back silently to newer data. Repeatable multi-statement reads reuse one snapshot token. Tenant binding and current authorization are checked for every token use; possession of a signed token is not a grant of access.

Pin creation and version/cut eligibility are one metadata root transition. A reader may reuse already-established protection only through the protocol below; reading a pointer, downloading data, and only then pinning it is unsafe. Pins and their protection are durable records, not process-local handles or object TTLs. Renewal, policy-driven revocation and retirement compete through the same root. An uncertain renewal or revoked/expired pin prevents successful completion under that token. Readers revalidate pin and current authorization after consuming the required bytes and before reporting a successful result or completed stream unit; a failed revalidation returns an explicit incomplete/expired outcome. That authoritative validation is the completion linearization point; later revocation does not retroactively invalidate a completed unit. An implementation using clock-based lease shortcuts must separately qualify clock bounds and GC delays. The initial design may retain abandoned pins conservatively until explicit revocation; bounded client duration does not itself prove that no reader remains. Serving caches never determine authority.

### 8.1 Amortized reader protection

Ordinary reads should reuse durable protection for a bounded set of snapshots rather than create and delete a metadata pin for each query. P0.4 must model and qualify this protocol before enabling it. Immutable manifests/pages may be cached by verified identity; authoritative heads, pin generations and current access rights are not made authoritative by caching.

A reader group belongs to one serving-process incarnation and tenant/security scope. Its durable pin fixes a unique group identity, lifetime/revocation generation, exact history roots and certified cuts/coverage, owner and resource/expiry policy. Group size, root count, retained bytes, reader duration and rotation work are bounded. Creating the group atomically checks eligibility and protects all roots. Changing its root set creates a new protected group before draining the old one; a rotating "latest" pointer cannot retarget existing readers.

| Step | Safety requirement |
| --- | --- |
| Admit | Under the local group's admission gate, register a reader and acquire its lifetime guard only while local admission is open. Before using protected bytes, validate the durable group generation/state, exact coverage and current authorization through an authoritative root read. Failed validation removes the registration and returns an error or performs a new valid selection. |
| Select | For latest committed reads, resolve authoritative compatible heads at a linearizable selection point during this request. If the selected roots are covered, reuse the group without a metadata write. On a miss, atomically acquire new protection and reselect/revalidate the latest compatible cut against the committing revision. A cached older head is usable only under an explicit allowed-stale policy. |
| Complete | After consuming the bytes for a result or stream unit, perform authoritative pin-generation and authorization validation. The lifetime guard remains held through every protected access and completion check. A stale, revoked or uncertain token cannot produce a successful completion. |
| Drain and release | Close local admission under the same gate used by registration, then record draining under the expected group identity/generation. Existing registered readers may finish while protection remains valid. Release the durable pin only after all local guards have drained; the release CAS checks owner, generation and draining state. Merely observing a zero counter before closing admission is unsafe. |
| Crash or revoke | Never transfer or reconstruct authority from a lost local reader count. A replacement process uses a new incarnation/group. Policy-driven revocation is an authoritative generation-fenced transition that invalidates old tokens; paused readers must fail completion. Retain roots until normal release/revocation and reachability permit reclamation. Elapsed TTL, missed heartbeat or process death alone does not authorize GC. |

Fresh admission requires an active group; existing registered readers can validate during draining. State transitions never reuse a released/revoked group identity. Local registration is sufficient only because the durable group retains its entire fixed root set until drain or authoritative revocation, and other processes cannot use that local admission authority. Failed/ambiguous drain, release and revocation operations reconcile by stable identity; stale owners cannot release a successor's protection. Quotas are checked before admitting new obligations and cannot silently erase valid ones.

Repeatable transactions retain one authorized token and its guard for their declared lifetime. A resumable or transferable token requires its own durable pin or an explicitly modeled atomic protection handoff; a process-local registration cannot authorize another server. Historical reads acquire appropriate durable protection, either a dedicated pin or an eligible already-protected group, before accessing the requested exact cut. Cancellation drops that reader's guard and releases dedicated protection when safe; it does not release a group used by other readers. Subscription cursor registration retains its separate snapshot/tail atomicity requirement.

This removes per-query **writes on the covered-snapshot path**, not required authoritative reads. Latest selection and final authorization checks still contribute to latency, object requests and the aspirational 5 ms server-read metric. They may be coalesced only when every included request has a valid selection/completion linearization point within its own operation. The initial implementation assumes no clock-based cache lease or revocation shortcut. If full-path latency misses the profile, narrow the measured envelope or evaluate the separately qualified consensus profile; do not relabel stale reads as latest.

### 8.2 Read latency and availability envelope

Qualify the actual critical path separately for these policies, including warm cache hits:

| Policy | Selection requirement | Authority still required |
| --- | --- | --- |
| Latest committed | Linearizable selection of the latest compatible published cut during the request | Valid protection before access and current pin/authorization validation after consuming bytes |
| Explicit allowed-stale | An older certified cut permitted by the requested policy | The same protection and completion validation; stale data permission does not permit stale access rights |
| Historical or pinned repeatable | Exact previously selected cut with retained coverage | The same protection and completion validation on each token use or completed stream unit |

In the object-native profile these checks can put remote metadata reads on the warm read path. Pin reuse does not establish a metadata-independent read service. If authority is unavailable, cached bytes or a previously signed token cannot turn an incomplete read into success. P0.4 records the ordered critical-path operations, their permissible coalescing, full request distributions and outage outcomes for each policy; it must not subtract validation to meet a latency target. A different revocation/lease contract requires a separate explicit design and qualification decision.

## 9. Retention, compaction, and garbage collection

Three operations must remain distinct: physical compaction rewrites equivalent bytes; logical history compaction combines changes into a base snapshot; garbage collection deletes objects proved unreachable. Dropping old deltas never permits deleting rows that still belong to the current relation. An inactive view's reconstruction needs may retain input that no historical query can access.

Retention roots include the **durable accepted-input head and its deduplication/admission state**, current publications, retained historical versions, active read pins, subscriptions, sink delivery cursors, branches, backups, rolling-upgrade rollback roots, staged replacement plans, and durable intents. Accepted but unpublished input stays protected after its upload intent closes, even if no view exists. Input-log compaction must preserve the authoritative source relation in a durable checkpoint and every remaining replay obligation before removing segments. A shared arrangement's retention is determined by all consumers. A slow consumer may exceed its budget and be explicitly disconnected or forced to resnapshot; the engine must not silently truncate its required history.

For scalar domain time, `since = S` is the **inclusive earliest supported cut**. Advancing it to `S2` requires a protected base at `S2` and sufficient timestamped deltas/recipes for every still-promised cut, after satisfying all consumer, read, rebuild and backup obligations. Consolidating changes across epochs below `S2` is allowed; coalescing away a promised intermediate cut at or above `S2` is not. Replacement history roots and coverage become authoritative in a root transition that checks pins and expectations; old physical roots remain protected until their references retire. Input-log retention follows each dependent consumer's replay floor, not merely the newest producer upper.

Compaction and GC may be paused for full suspension. Backend TTLs and external bucket lifecycle rules must not expire authoritative input, metadata, published checkpoints or retained dependency roots while no process is running. Expired customer retention policies can be reconciled on wake through the normal pin/retirement protocol; expiry is not permission for an independent cleaner to bypass reachability.

GC must close the “checked unreferenced, then newly referenced” race:

1. Data objects belong to registered allocation namespaces. An intent registers and pins every existing base before reading or reusing it. New objects cannot be adopted by arbitrary raw object key. Immutable metadata pages written while changing the root use its current open allocation generation; the root CAS checks that revision/generation. A failed CAS cannot resurrect pages from a closed generation. Metadata bootstrap and any sequenced-root GC have explicit qualified boundary rules.
2. At metadata revision `R`, close allocation generation `g` and mark every live root, pin, and protected staging namespace. New allocations use `g+1`. A still-open namespace is protected as a unit, including uploads finishing after the mark traversal.
3. New references to old-generation objects must descend from an already protected live root or namespace. The API prohibits resurrecting retired/tombstoned roots. Pin creation compares the version's live state; retirement compares its pin/reference state.
4. Sweep only unmarked, closed-generation allocations. Record durable tombstones before physical deletion. Retries are idempotent; deletion failure leaks bytes rather than invalidating a live root.
5. Reconcile backend checkpoint deletion under the same retirement proof. SlateDB's own GC must remain constrained by its durable checkpoints; Rockstream must not run an independent bucket lifecycle rule that bypasses them.

**Race example:** GC tries to retire `V17` while a query requests it. If the pin transaction wins, retirement cannot complete and the query is protected. If retirement wins, pin creation fails before any successful query result. A query that first reads `V17` from a cache and later asks to pin it receives that same failure. Neither ordering permits deletion underneath a valid pin.

Generational reachability and the no-resurrection rule require a model-checking gate. A timestamp grace period or two object listings alone is not a proof. The conservative fallback is retaining extra namespaces or pausing GC when metadata is unavailable.

### Customer data lifecycle and retirement

A logical row DELETE changes the declared relation at its published cut. It does not erase prior rows from accepted input, historical deltas, shared arrangements, caches, spill, audit artifacts, backups, object versions or downstream systems. Retention expiry changes supported history only through the normal authoritative pin/retirement protocol; physical reclamation follows reachability and provider semantics. Do not advertise immediate erasure or a general deletion/compliance guarantee.

Treat object/database/tenant retirement as an authorized, audited lifecycle transition with stable operation identity, not a recursive bucket delete. Reject new admissions and new dependency references in the affected scope; resolve or explicitly terminate reads, pins, subscriptions and delivery obligations under their declared contracts; fence old writers and credentials and record durable retirement intent and progress. A valid pin is never reclaimed underneath its contract. Shared objects remain until all entitled consumers and backup/rollback roots release them. Decommissioning must distinguish access disabled, logical retirement, remaining contractual retention, physical cleanup and verified completion; surface blockers, orphan cleanup, provider version/retention-lock constraints and outstanding external copies. Reconcile ambiguous effects and retries idempotently. Do not silently remove accepted input or promise to erase data in independently controlled sources/sinks.

Backups and old formats may contain retired data. Record retirement/deletion decisions and retention deadlines with sufficient durable evidence for the declared restore scope. Before reopening an older backup, reconcile applicable newer retirement decisions and access revocations against an authoritative surviving record or verified operator-supplied evidence; if that evidence is unavailable, fail closed for affected data pending explicit recovery review. A new incarnation alone is not erasure. This requirement does not introduce an always-running external coordinator or claim recovery of decisions lost with every authoritative copy. Include independent backups, versions, caches and key references in decommission inventories; destroying a shared key cannot be used to invalidate still-protected data. Claim physical reclamation only within verified storage and copy boundaries, and report unverifiable or externally retained copies separately. Qualification covers concurrent pin/retire, late writes, suspension, backup expiry and restore before supporting a deletion profile.

## 10. Reconstructibility and storage layout

Initially persist every stateful operator's required recovery state. Later the optimizer may classify state as authoritative, expensive derived, cheap derived, or ephemeral. A reconstructible arrangement descriptor must identify its exact input checkpoint/log interval, executable plan and semantic version, schema, required upstream pins, expected rebuild time, and fallback if its recovery budget is exceeded. Persisting only a label saying “rebuildable” is insufficient.

The durable format is versioned separately from the software release. Manifests include a format identifier, checksum algorithm, compression/encoding identifiers, row and key schema, weighted multiplicity encoding, epoch bounds, and content digest. Decode rejects unknown required fields, incompatible semantics, invalid ranges, and checksums. Encryption key references are part of restore requirements. Maintain compatibility fixtures and explicit upgrade readers; avoid embedding Rust's in-memory representation.

RAM holds active working sets; local NVMe holds caches and spill. Spill may bound a transaction's execution memory, but required bytes must reach authoritative storage before publication. Choose representation by access pattern within the same publication, retention and recovery contract:

| State/access pattern | Initial choice or qualified candidate |
| --- | --- |
| Point indexes and join arrangements | Indexed SlateDB state with committed logical-history selection |
| Hot aggregate working state | Bounded memory cache backed by durable state or an exact protected reconstruction recipe |
| Durable input | Append-oriented immutable segments with complete transaction boundaries |
| Large historical deltas or sequential scans | Compressed immutable/columnar batches only when a focused experiment justifies them |
| Temporary execution/spill | RAM/local NVMe; never the sole copy of acknowledged state |

Specialized immutable layouts complement the preferred backend only after the same exact-cut, checksum, authorization, retention and recovery qualification. They do not introduce a general-purpose storage engine or a second public semantics. Object count, metadata fanout, compaction amplification, and cache refill cost are qualification dimensions, not implementation afterthoughts.

## 11. Subscription and sink boundaries

A subscription pins snapshot version `V`, registers its change-retention cursor in the same metadata transition, emits the complete snapshot, then emits committed changes strictly after `V` in publication order. Cursor tokens bind run, relation/plan identity, version, output partition, and row/batch position. Snapshot and delta pages have stable identities. A reconnect can replay an unacknowledged page; clients use the cursor identity to deduplicate. Exactly-once logical state does not imply exactly-once network delivery.

Subscription acknowledgements release retention only after their recorded cursor advances. An expired cursor returns `RESNAPSHOT_REQUIRED`. Schema or incompatible plan changes terminate or version the stream according to an explicit contract; they must not reinterpret an old cursor.

The first Kafka sink capability is an outbox of published delta batches with stable delivery IDs and **at-least-once delivery**. A transactional producer alone does not atomically update Rockstream's metadata cursor. If Kafka commits but its response is lost, blindly resending after a restart can duplicate a committed output. Kafka's own documentation distinguishes Kafka transaction guarantees from coordination with external state. [S8]

A stronger optional sink protocol must atomically write output and a durable destination-side delivery marker, fence predecessor producers, and recover the last committed marker through read-committed consumption before advancing or retrying. Marker retention, transactional IDs, topic lineage, transaction size limits, and source/destination disaster restore must be qualified together. Nontransactional HTTP endpoints offer at-least-once attempts unless the receiver provides a durable idempotency contract.

An internal ownership generation cannot cancel a source acknowledgement or sink send already issued to an external system. Delayed source acknowledgements must refer only to input already durably accepted under its original valid authority. Reconcile native source positions on takeover. Delayed/duplicate sink effects remain possible under the initial at-least-once contract; prohibiting further predecessor effects requires separately qualified destination-side fencing. Drain/wake uses these same external contracts, rather than claiming that metadata CAS alone fences another system.

## 12. Failure behavior

| Failure boundary | Required outcome |
| --- | --- |
| Before input metadata acceptance | No durable acknowledgement; retry may find or discard orphan uploads. |
| After input acceptance, before its response | Status/retry returns the existing input identity and token. |
| During computation or exchange | Keep the old publication; replay the unpublished interval from its exact parent. |
| After state upload, before sealing | Protect active intents; incomplete receipts cannot publish. |
| After sealing, before publication | Reuse only if all recorded fences still match; otherwise abandon and recompute. |
| After publication, before response/notification | Read the committed attempt identity; do not apply its delta again. |
| Old worker resumes after reassignment | Generation rejects messages and publication; its immutable orphan bytes are reclaimable. |
| Metadata root unavailable or CAS outcome unknown | Stop new authority and GC; reconcile stable identities. Already protected reads may acquire bytes, but cannot report successful completion without required pin validation. |
| Object storage throttled/unavailable | Backpressure ingress/maintenance; serve only resolvable published snapshots; never acknowledge undurable state. |
| Corrupt or missing committed object | Fail the affected read/recovery, raise an integrity incident, repair from verified copies; do not substitute an older result as success. |
| Pin expires during query | Fail/restart under a new valid token; do not claim the old query completed successfully. |
| Sink response lost | Reconcile destination marker if qualified; otherwise replay with documented at-least-once behavior. |
| Concurrent wake or old process returns after suspension | Root CAS installs one new ownership generation; reject stale internal acceptance/publication/cursor/protection changes. Reconcile external effects under their separate delivery protocol. |
| All Rockstream processes and local caches disappear | Recover metadata root, protected input, published history and lifecycle from authoritative storage; replay accepted unpublished work. |

Test failures before and after every durable boundary, including response loss after successful operations. A single happy-path restart test cannot establish these properties.

## 13. Backup, restore, and upgrades

A backup is a verified metadata-root revision plus its entire reachable metadata/data/input/checkpoint graph, compatible executables or format readers, and decryptable key references. Begin with a durable backup intent that blocks reclamation of the capture boundary. Finish only after the metadata revision, root inventory, and required copied objects are verified and an immutable completion marker is recorded. All cloud authority is in object storage, but an uncoordinated bucket listing/copy is not a consistent backup: it can mix root revisions or omit still-referenced objects. A completed capture records and protects one coherent graph.

For regional recovery, restore the latest **complete** backup, quantify its RPO against acknowledged inputs/publications, and open read-only until integrity checks finish. Create a new `RunIncarnation`; all pre-restore worker credentials, publication attempts, snapshot tokens, and subscription cursors become invalid. Preserve source lineage separately so offsets cannot be confused with new source data.

A new run identifier alone does not stop a surviving old control plane from writing. The recovery procedure must fence or quarantine the former deployment, revoke its write credentials, isolate its object namespace, and reconcile destination-side sink ownership before opening traffic. Do not run two writable restored clusters against the same authoritative namespace. Sinks stay paused until duplicate-effect reconciliation is complete.

Rolling upgrades pin rollback roots, admit only mutually compatible plan/state formats, and change catalog/plan revisions at publication boundaries. A migration writes new immutable state and validates it before switching. Old code must reject unreadable formats explicitly. Rollback is possible only while compatible state and required input remain pinned; its retention cost is visible.

## 14. Qualification gates and unresolved choices

G0 must prototype exact logical MVCC over SlateDB, compare clone and immutable-attempt preparation with amortized checkpoints, qualify one-root batched metadata and reader-group lifecycle behavior, and exercise full stop/resume without a resident coordinator. The [G0 feasibility decisions](../planning/qualification.md#g0-feasibility-decisions) define predeclared budgets and fallback decisions. G2 requires crash-consistent input, exact historical reads, immutable publication, deduplication and recovery on both local and cloud adapters, including accepted input with zero views and destruction of every process/local cache. G3 adds shared retention, independently scheduled consumers, online graph changes, CDC handoff and subscription/sink cursors. G4 adds concurrent coordinators, metadata storage partitions/throttling, fenced reassignment, distributed drain/wake, complete coverage and scale tests. G6 supplies sustained economics, restore/upgrade drills and runbooks. All are proposed, unexecuted gates.

Required counterexamples include a missing receipt; delayed abandoned-attempt traffic; stale generation publishing after a successful takeover; a fence check separated from head update; a lost successful CAS response; concurrent bootstrap/wake; metadata-page GC during a root transition; checkpoint expiry across a long suspension; two physical checkpoint schedules with a valid common logical cut; an unavailable cut hidden inside nominal `[S,Cp]`; DISTINCT changes that cancel across an interval but produce an intermediate row; GC versus a history pin; accepted input with no views; and restore while the former deployment survives. Assert complete snapshots and transcripts, not just row counts.

Add batch conflicts through shared quota/retention predicates; partial retry/regrouping after a lost successful batch response; preferred-committer death; reader admission racing the last local release; revocation while a reader is paused; restart or cross-server token use with a lost local registration; cached-head selection after a newer completed publication; abandoned namespaces contaminating probes/scans/caches/compaction; and unbounded parent/checkpoint retention despite apparently small logical history. Safe extra retention is preferable to unsafe deletion, but cannot count as a passed bounded-cost experiment.

Open implementation choices are the compatible SlateDB and transactional-object releases, logical trace/index layout, grouping and checkpoint frequency, conditional-root protocol and supported object services, contention envelope, pin validation/revocation cost, source-cut representation and cold-recovery budget. These questions may narrow a qualified performance/deployment envelope or trigger an explicitly reviewed alternative. They do not reopen correctness, no mandatory external coordination service, or truthful retention guarantees.

## Sources and relationship to prior work

External pages were checked on **2026-11-25**. They establish component behavior and precedents; the Rockstream-specific protocol above is a proposal that still requires implementation and verification.

- **[S1]** [AWS S3 conditional writes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes.html) and [consistency model](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html#ConsistencyModel): storage primitives whose complete error and concurrency behavior must be qualified by the metadata adapter.
- **[S2]** [`slatedb-txn-obj` 0.17.0](https://docs.rs/slatedb-txn-obj/0.17.0/slatedb_txn_obj/): single-object optimistic updates, pluggable persistence and epoch fencing; not a multi-object metadata service.
- **[S3]** [OpenRaft 0.9.21 integration guide](https://docs.rs/openraft/0.9.21/openraft/docs/getting_started/index.html): application-owned storage/network/state-machine integration for the optional, evidence-triggered consensus alternative.
- **[S4]** [SlateDB writes](https://slatedb.io/docs/design/writes/): in-memory completion and durability waiting.
- **[S5]** [SlateDB checkpoints](https://slatedb.io/docs/design/checkpoints/): durable checkpoint lifetimes, snapshot distinction, and pinned readers. Current documentation must be matched to the release selected by the implementation spike.
- **[S6]** [Materialize Persist design](https://github.com/MaterializeInc/materialize/blob/main/doc/developer/design/20220330_persist.md): a primary design precedent for immutable blobs with a consensus-controlled root. This informs the architecture; it does not validate this new protocol.
- **[S7]** [PostgreSQL 18 logical decoding concepts](https://www.postgresql.org/docs/18/logicaldecoding-explanation.html): retransmission, slot lifecycle, and exported snapshots. Supported connector versions will be explicitly qualified.
- **[S8]** [Apache Kafka 4.1 delivery semantics](https://kafka.apache.org/41/design/design/#message-delivery-semantics): transactional boundaries and cooperation with external systems.
- **[S9]** [SlateDB clones](https://slatedb.io/docs/design/clones/) and [readers](https://slatedb.io/docs/design/readers/): explicit checkpoint ownership, clone WAL/external-reference costs and exact-source durability caveats; attempt namespaces remain a Rockstream proposal.
- **[R1]** [Rockstream scoped frontier implementation](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-control/src/frontier.rs): scope, generation, incarnation, and publication fencing are existing foundations to preserve.
- **[R2]** [Rockstream shared traces](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/src/trace.rs): retained snapshots and consumer-driven compaction already exist. The proposed redesign centralizes their durable lifecycle rather than claiming these concepts are new.
