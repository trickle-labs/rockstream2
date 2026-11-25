# ADR 0003: atomic metadata on object storage without an external service

**Status:** Proposed default architecture; substrate and costs require G0 evidence. **Date:** 2026-11-25. **Owners:** storage/consistency and operations roles.

## Decision

Keep all authoritative cloud data **and metadata** in a qualified object store. The metadata kernel is part of the Rockstream binary. No external etcd, ZooKeeper, Redis, SQL catalog or continuously running metadata tier is required.

Start with one logical conditional metadata root per installation, pointing into immutable metadata pages. It selects the catalog, input/publication heads, deduplication state, ownership generations, pins, intents and lifecycle together. Prepare durable data and metadata pages first, then conditionally replace the expected root revision. That root transition is the logical transaction's linearization point. A single-object conditional update does not make separately written metadata objects atomic: all predicates and changes requiring atomicity must be covered by the same selected root.

Publication checks the expected parent, run, catalog/plan revision, ownership generation, authorized publisher and sealed intent. The sealed receipt tree must cover the complete fixed participant set. The final update contains a bounded root, not an unbounded receipt list. Completeness validation remains trusted, tested code; a digest alone does not establish it.

Input acceptance separately commits its head, admission/deduplication state and protected recovery references. They remain live roots even with zero views. Pin creation and eligibility, pin renewal/revocation, and retirement also use atomic root transitions. Unknown outcomes resolve through stable operation identities. CAS conflicts require refresh and revalidation of every predicate.

Make amortization an early requirement. An embedded adaptive commit scheduler uses bounded priority queues, fairness, a maximum commit delay and conflict-aware batching. Initially batch only operations whose writes preserve every other operation's predicates/read/write footprint, all validated against one authoritative revision. Commit individual stable identities and outcomes together so lost responses, partial retries and regrouping cannot duplicate effects. A preferred active committer is disposable and holds no independent authority. The [scheduler contract](../design/consistency-and-storage.md#421-bounded-metadata-commit-scheduler) defines bounds, ambiguity and overload behavior.

Ordinary reads may share durable protection for a bounded set of exact snapshots under the [reader-group protocol](../design/consistency-and-storage.md#81-amortized-reader-protection). Registration and drain use one local admission gate; durable generations fence release and revocation; current authorization and final completion remain authoritative checks. Group protection removes per-query pin writes only for covered snapshots. Latest committed reads still require a linearizable selection point; a cached head provides only explicitly requested stale semantics. Portable tokens need dedicated protection or a qualified handoff. No TTL or local reference count alone authorizes GC.

Evaluate reuse of [`slatedb-txn-obj` 0.17.0](https://docs.rs/slatedb-txn-obj/0.17.0/slatedb_txn_obj/) for the **single-object** primitive. Its transactional register, versioned-object protocol and optional epoch fence do not supply Rockstream's multi-record state machine, lease or GC semantics. Qualify the actual read, conditional-write, current-version discovery, ambiguity and reclamation protocol for each supported object service. [S3 conditional writes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes.html) are a concrete substrate reference, not a guarantee for every S3-compatible service.

The embedded profile runs the same logical transitions through a qualified local filesystem adapter with exclusive process ownership and durable acknowledged root updates. Compiled implementation libraries are permitted; they add no separately operated service.

## Alternatives and consequences

A mandatory etcd or external SQL deployment contradicts the operating requirement. Direct last-writer-wins object updates do not provide fencing. Splitting one root into independent keys prematurely would reintroduce atomicity gaps.

The single root serializes metadata commits and adds object-service latency, contention and tree-write amplification. Keep roots small and measure aggregate ingestion, publication, pin churn, authoritative read validation and lifecycle operations, including full metadata-tree cost. Computationally independent groups still share this metadata bottleneck; throughput is not assumed unlimited.

The [read envelope](../design/consistency-and-storage.md#82-read-latency-and-availability-envelope) applies to cached, explicitly stale and pinned reads as well as strict latest reads. All require current protection/authorization checks; metadata unavailability prevents successful completion even when data is cached. P0.4 must measure each policy's complete critical path and validate this outage behavior. Amortizing pin writes does not establish a 5 ms read guarantee or authorize a weaker revocation contract.

Expose logical transaction scopes and their complete predicates while mapping all scopes to the initial root. If batching/amortization cannot meet aggregate throughput, evaluate independent installations/tenants or dependency-closed domain groups. Partitioning requires a separate modeled protocol for protected immutable imports, durable references and retention handoff; it cannot split jointly atomic publication/fence/pin decisions across independent objects. Preserve this path without implementing partitioning in G0.

A mature embedded Raft library such as [OpenRaft](https://docs.rs/openraft/0.9.21/openraft/docs/getting_started/index.html) is an evidence-triggered alternative if the baseline cannot meet a material requirement economically. It still requires durable votes/logs/snapshots, networking, membership, restore and an available quorum for new decisions. Adoption needs a new ADR and a migration/hibernation contract; it is not a transparent configuration switch or permission to create a separate mandatory service.

Both profiles implement the same logical metadata state machine. Object-native remains the default, with protected object state and no active quorum required during eligible full suspension. Embedded consensus targets demonstrated coordination-latency needs and has distinct durable-state, linearizable-read, quorum and stop/restart obligations. Do not assume its hibernation contract matches the object-native profile or that an embedded library by itself qualifies either profile.

## Gate

G0 P0.4 models publication, admission, ownership, conflict-aware batches, per-operation ambiguous outcomes, metadata-page reachability and reader registration/drain/revocation/GC races; injects lost CAS responses, committer death and concurrent bootstrap/activation; and measures target metadata traffic with and without batching/group protection. Freeze acceptance limits and fallback decisions through [G0 feasibility decisions](../planning/qualification.md#g0-feasibility-decisions). G2 proves loss of every cloud process/local file and recovery from protected object roots. G3 adds shared history and consumer pin pressure; G4 adds distributed contention, partitions and stale-owner resurrection. No gate has run.

The normative state machine and backend requirements are in [consistency and storage](../design/consistency-and-storage.md).
