# ADR 0003: atomic metadata on object storage without an external service

**Status:** Proposed default architecture; substrate and costs require G0 evidence. **Date:** 2026-11-25. **Owners:** storage/consistency and operations roles.

## Decision

Keep all authoritative cloud data **and metadata** in a qualified object store. The metadata kernel is part of the Rockstream binary. No external etcd, ZooKeeper, Redis, SQL catalog or continuously running metadata tier is required.

Start with one logical conditional metadata root per installation, pointing into immutable metadata pages. It selects the catalog, input/publication heads, deduplication state, ownership generations, pins, intents and lifecycle together. Prepare durable data and metadata pages first, then conditionally replace the expected root revision. That root transition is the logical transaction's linearization point. A single-object conditional update does not make separately written metadata objects atomic: all predicates and changes requiring atomicity must be covered by the same selected root.

Publication checks the expected parent, run, catalog/plan revision, ownership generation, authorized publisher and sealed intent. The sealed receipt tree must cover the complete fixed participant set. The final update contains a bounded root, not an unbounded receipt list. Completeness validation remains trusted, tested code; a digest alone does not establish it.

Input acceptance separately commits its head, admission/deduplication state and protected recovery references. They remain live roots even with zero views. Pin creation and eligibility, pin renewal/revocation, and retirement also use atomic root transitions. Unknown outcomes resolve through stable operation identities. CAS conflicts require refresh and revalidation of every predicate.

Evaluate reuse of [`slatedb-txn-obj` 0.17.0](https://docs.rs/slatedb-txn-obj/0.17.0/slatedb_txn_obj/) for the **single-object** primitive. Its transactional register, versioned-object protocol and optional epoch fence do not supply Rockstream's multi-record state machine, lease or GC semantics. Qualify the actual read, conditional-write, current-version discovery, ambiguity and reclamation protocol for each supported object service. [S3 conditional writes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes.html) are a concrete substrate reference, not a guarantee for every S3-compatible service.

The embedded profile runs the same logical transitions through a qualified local filesystem adapter with exclusive process ownership and durable acknowledged root updates. Compiled implementation libraries are permitted; they add no separately operated service.

## Alternatives and consequences

A mandatory etcd or external SQL deployment contradicts the operating requirement. Direct last-writer-wins object updates do not provide fencing. Splitting one root into independent keys prematurely would reintroduce atomicity gaps.

The single root serializes metadata commits and adds object-service latency, contention and tree-write amplification. Batch compatible work, keep roots small and measure aggregate ingestion, publication, pin churn and lifecycle operations. Computationally independent groups still share this metadata bottleneck; throughput is not assumed unlimited.

A mature embedded Raft library such as [OpenRaft](https://docs.rs/openraft/0.9.21/openraft/docs/getting_started/index.html) is an evidence-triggered alternative if the baseline cannot meet a material requirement economically. It still requires durable votes/logs/snapshots, networking, membership, restore and an available quorum for new decisions. Adoption needs a new ADR and a migration/hibernation contract; it is not a transparent configuration switch or permission to create a separate mandatory service.

## Gate

G0 models publication, admission, ownership, metadata-page reachability and pin/GC races; injects lost CAS responses and concurrent bootstrap/activation; and measures target metadata traffic. G2 proves loss of every cloud process/local file and recovery from protected object roots. G3 adds shared history and consumer pin pressure; G4 adds distributed contention, partitions and stale-owner resurrection. No gate has run.

The normative state machine and backend requirements are in [consistency and storage](../design/consistency-and-storage.md).
