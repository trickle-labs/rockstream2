# ADR 0004: SlateDB-first storage with a logical MVCC arrangement layer

**Status:** Proposed working backend choice; release/API and performance unqualified. **Date:** 2026-11-25. **Owners:** storage and engine roles.

## Decision

Use **SlateDB as the preferred backend**, unless qualification establishes a material unresolved drawback. Implement a focused IVM arrangement layer over it for weighted indexed data, logical history, durable preparation, exact reads and safe release. Avoid building a new general storage engine or a large interchangeable-backend framework. Prefer layout/batching fixes and reasonable upstream improvements before replacing the backend.

Group compatible arrangements in partitioned databases with explicit namespaces; do not create a database per view by default. Grouping must preserve ownership, exact-parent recovery and resource isolation. The optimizer can separate incompatible retention or workload profiles.

Logical MVCC belongs to Rockstream. A published arrangement history identifies certified cuts, timestamped deltas/base, source lineage, schema/semantics, exact physical references and retention obligations. SlateDB sequence numbers and checkpoints are physical mechanisms, not the logical transaction clock. One physical checkpoint may protect many logical cuts if the adapter actually retains enough history to reconstruct them.

Only the metadata kernel publishes authority. Prepare all required data and recovery state, await actual backend durability, and establish non-expiring checkpoint protection before publication. An in-process `DbSnapshot` is insufficient. Readers open named protected checkpoints and select the certified logical cut; live or unprotected follow-latest readers cannot substitute. See [checkpoint documentation](https://slatedb.io/docs/design/checkpoints/) and [write durability](https://slatedb.io/docs/design/writes/); the implementation must pin a compatible release.

An abandoned attempt restarts from the exact published parent, never from a mutable prefix that may contain staged writes. Qualify cloning or another namespace/branch mechanism for grouped arrangements. No checkpoint is released until the metadata reachability proof allows it. Compaction cannot erase promised intermediate cuts or their source-lineage mappings.

## Alternatives and consequences

A simple immutable weighted-batch implementation is useful as an oracle and bounded prototype, not a commitment to a second production engine. Specialized columnar layouts may later complement indexed storage if actual scan workloads justify them. Exposing raw KV writes to operators would spread recovery and visibility assumptions throughout the engine.

The important costs are point-probe/scan behavior, checkpoint and clone frequency, retained MVCC history, request/write amplification, compaction, small batches, failed attempts and cold start. Physical grouping saves overhead but can introduce writer and I/O contention. MVCC helps schedule independent consumers; it does not prove grouped branch recovery or make history inexpensive.

## Gate

G0 must reopen exact cuts after process destruction, retain intermediate nonlinear results across disjoint physical checkpoint schedules, preserve source/transaction lineage, fence stale writers, retry abandoned grouped preparations, survive native GC and demonstrate non-expiring protection across full suspension. Measure both memory-resident and larger-than-memory workloads with realistic view counts.

If an important requirement fails, investigate a focused adapter/upstream change, narrow the qualified envelope, or record an explicit backend decision supported by evidence. Correctness and acknowledged retention are fixed requirements. [Consistency and storage](../design/consistency-and-storage.md) and [ADR 0009](0009-logical-mvcc.md) define the contract.
