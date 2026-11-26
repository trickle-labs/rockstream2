# ADR 0004: immutable delta traces with per-domain SlateDB working indexes

**Status:** Proposed storage architecture; physics validated in G0.2. **Date:** 2026-11-26. **Owners:** storage and engine roles.

## Decision

Separate **authoritative durable history** from **indexed working state** so neither fights the other's physics, governed by one authoritative metadata manifest:

1. **Authoritative Input & Delta Traces (Immutable Object Segments):** Accepted input transactions and committed per-interval operator/output deltas are written as immutable weighted Arrow/batch objects on object storage and selected by the committed manifest. Because staged segments are immutable and unreferenced until publication CAS succeeds:
   - Abandoned preparations require **zero database cloning** and **zero LSM attempt-namespace key filtering**; they are simply unreferenced objects reaped by GC.
   - Exact-parent recovery is trivial: reopen the exact immutable delta segments and parent SlateDB checkpoint named in the committed manifest.
   - Sequential scans, replay, historical delta delivery, and subscriptions read immutable segments directly without LSM compaction overhead.
2. **Indexed Working State (SlateDB per Consistency Domain / Partition):** Use **SlateDB** for fast point probes, join lookups, current-state serving indexes, and (when direct SQL `UPDATE`/`DELETE` is enabled) the explicitly budgeted primary-key image index.
   - Start in G0–G2 with **one SlateDB instance per consistency domain (or domain partition)** rather than co-locating unrelated domains under a single mutable writer. This preserves true domain independence ([ADR 0002](0002-consistency-domains.md)) and avoids cross-domain checkpoint/failover coupling. Multi-domain physical grouping is deferred to G3/G4 only if measured manifest overhead across hundreds of small domains justifies it.
   - Physical SlateDB checkpoints are taken periodically (amortized across many logical epochs) and protected by non-expiring metadata references. Between checkpoints, committed immutable delta segments provide exact durability and recovery replay—eliminating per-microbatch SlateDB shallow clones and LSM attempt-namespace pollution.
3. **One locked storage path after G0.2:** G0.2 runs a focused real-S3 comparison between this **immutable-delta + SlateDB-index** layout and a **pure SlateDB-history** layout on `W1-G`, measuring write/request amplification, checkpoint cost, exact-parent recovery, point-probe latency, and actual reclamation—and locks **one** production layout before G2.

## Alternatives and consequences

- **Per-interval SlateDB shallow clones:** Rejected as the default microbatch staging mechanism; shallow clones copy referenced WAL SSTs and create manifest/external-checkpoint dependencies designed for occasional branching, not 100 ms–1 s interval preparation.
- **LSM attempt-namespace key filtering inside SlateDB:** Rejected as unnecessary complexity when immutable delta segments already isolate speculative preparations outside the LSM tree without breaking bloom-filtered point lookups.
- **Premature multi-domain SlateDB physical grouping:** Deferred; sharing one mutable SlateDB writer across independent domains reintroduces the physical writer and recovery coupling that ADR 0002 eliminated logically.
- **Trade-off accepted:** Updating the SlateDB working index from committed/staged deltas means write paths write both compact delta segments (for history/recovery/subscriptions) and index updates (for point probes). G0.2 explicitly measures this dual-write cost against pure SlateDB history and verifies that cold replay from the last SlateDB checkpoint plus trailing immutable delta segments stays within the recovery budget.

## Gate

**G0.2** measures both layouts on real S3/object storage with `W1-G` (exact-parent reopen after process kill, abandoned attempt isolation, checkpoint amortization, nonlinear intermediate cuts, real GC reclamation under the grace window, and cold recovery) and locks one storage design before G2. [Consistency and storage](../design/consistency-and-storage.md) and [ADR 0009](0009-logical-mvcc.md) define the normative contract.
