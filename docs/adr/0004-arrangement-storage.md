# ADR 0004: SlateDB-first storage with a logical MVCC arrangement layer

**Status:** Proposed working backend choice; release/API and performance unqualified. **Date:** 2026-11-25. **Owners:** storage and engine roles.

## Decision

Use **SlateDB as the preferred backend**, unless qualification establishes a material unresolved drawback. Implement a focused IVM arrangement layer over it for weighted indexed data, logical history, durable preparation, exact reads and safe release. Avoid building a new general storage engine or a large interchangeable-backend framework. Prefer layout/batching fixes and reasonable upstream improvements before replacing the backend.

Group compatible arrangements in partitioned databases with explicit namespaces; do not create a database per view by default. Grouping must preserve ownership, exact-parent recovery and resource isolation. The optimizer can separate incompatible retention or workload profiles.

Logical MVCC belongs to Rockstream. A published arrangement history identifies certified cuts, timestamped deltas/base, source lineage, schema/semantics, exact physical references and retention obligations. SlateDB sequence numbers and checkpoints are physical mechanisms, not the logical transaction clock. One physical checkpoint may protect many logical cuts if the adapter actually retains enough history to reconstruct them.

Qualify a current-state index for common probes/joins, timestamped deltas and periodic consolidated bases. The index may be durable or reconstructible, but must bind to committed history and cannot leak speculative attempts. Amortize physical checkpoints over logical epochs and compatible arrangements without publishing unprotected bytes. Trigger consolidation from budgets for reconstruction, retained bytes, compaction debt, object requests, checkpoint count and recovery work; preserve every still-promised cut. Logical-history size and physically pinned SST bytes are separate costs.

Only the metadata kernel publishes authority. Prepare all required data and recovery state, await actual backend durability, and establish non-expiring checkpoint protection before publication. An in-process `DbSnapshot` is insufficient. Readers open named protected checkpoints and select the certified logical cut; live or unprotected follow-latest readers cannot substitute. See [checkpoint documentation](https://slatedb.io/docs/design/checkpoints/) and [write durability](https://slatedb.io/docs/design/writes/); the implementation must pin a compatible release.

An abandoned attempt restarts from the exact published parent, never from a mutable prefix that may contain staged writes. P0.2 must compare protected checkpoint/clone recovery with immutable attempt-specific namespaces selected by committed manifests, and assess writer reuse only when parent identity and speculative isolation are proved. This comparison does not require shipping multiple production backends. The [attempt protocol](../design/consistency-and-storage.md#52-exact-parent-preparation-alternatives) binds membership and parent dependencies and excludes unpublished data from probes, scans, caches, compaction and recovery. No checkpoint is released until the metadata reachability proof allows it. Compaction cannot erase promised intermediate cuts or their source-lineage mappings.

## Alternatives and consequences

A simple immutable weighted-batch implementation is useful as an oracle and bounded prototype, not a commitment to a second production engine. Indexed SlateDB remains preferred for point probes and arrangements; compressed immutable/columnar batches may complement large historical deltas and sequential scans after qualification. Durable input uses append-oriented segments; bounded RAM/NVMe serves caches and temporary state. Every representation must satisfy the same publication/retention/recovery contract. Exposing raw KV writes to operators would spread recovery and visibility assumptions throughout the engine.

Shallow cloning shares existing SSTs but can still copy referenced WAL SSTs, create manifests and hold external checkpoint dependencies. Measure those costs and eventual reclamation. Creating a clone from an administrative latest manifest does not flush a live writer; exact-parent recovery uses the required durable explicit checkpoint. Immutable attempt namespaces are a proposed Rockstream isolation scheme, not an upstream SlateDB transaction guarantee. See [SlateDB clones](https://slatedb.io/docs/design/clones/).

The important costs are point-probe/scan behavior, checkpoint and clone frequency, retained MVCC history, request/write amplification, compaction, small batches, failed attempts and cold start. Physical grouping saves overhead but can introduce writer and I/O contention. MVCC helps schedule independent consumers; it does not prove grouped branch recovery or make history inexpensive.

## Gate

G0 must reopen exact cuts after process destruction, retain intermediate nonlinear results across disjoint physical checkpoint schedules, preserve source/transaction lineage, fence stale writers, retry abandoned grouped preparations, survive native GC and demonstrate non-expiring protection across full suspension. Measure both memory-resident and larger-than-memory workloads with realistic view counts.

Checkpoint amortization, bounded reconstruction and the clone-versus-attempt comparison are mandatory P0.2 experiments with predeclared limits and decisions in [G0 feasibility decisions](../planning/qualification.md#g0-feasibility-decisions). Excessive clone cost triggers qualification of namespaces; excessive reconstruction triggers indexes, base frequency or focused history-layout changes. A failed isolation or retention proof blocks the candidate regardless of speed.

If an important requirement fails, investigate a focused adapter/upstream change, narrow the qualified envelope, or record an explicit backend decision supported by evidence. Correctness and acknowledged retention are fixed requirements. [Consistency and storage](../design/consistency-and-storage.md) and [ADR 0009](0009-logical-mvcc.md) define the contract.
