# ADR 0004: immutable delta traces with per-domain SlateDB working indexes and bounded overlays

**Status:** Proposed storage architecture; G0.2 will validate the layout choice. **Date:** 2026-11-26. **Owners:** storage and engine roles. Gate placement is refined by [ADR 0012](0012-staged-mechanism-adoption.md).

## Decision

Separate **authoritative durable history** from **indexed working state** so neither fights the other's physics, governed by one authoritative metadata manifest:

1. **Authoritative Input & Delta Traces (Immutable Object Segments):** Accepted input transactions and committed per-interval operator/output deltas are written as immutable weighted Arrow/batch objects on object storage and selected by the committed manifest. Because staged segments are immutable and unreferenced until publication CAS succeeds:
   - Abandoned preparations require **zero database cloning** and **zero LSM attempt-namespace key filtering**; they are simply unreferenced objects reaped by GC.
   - Sequential scans, replay, historical delta delivery, and subscriptions read immutable segments directly without LSM compaction overhead.
2. **Indexed Working State (SlateDB + Bounded In-Memory Delta Overlay):** Use **SlateDB** for persistent point probes, join lookups, current-state serving indexes, and (when direct SQL `UPDATE`/`DELETE` is enabled) the explicitly budgeted primary-key image index, paired with an explicit **bounded in-memory indexed overlay** for trailing deltas between periodic SlateDB checkpoints (`Cp_ckpt <= Cp`):
   - **Tentative writes never pollute SlateDB:** During an unpublished interval, maintenance holds tentative updates in a local in-memory overlay, uploads immutable delta segments, and applies committed deltas into SlateDB *only after* publication CAS succeeds. On abort/CAS conflict, discarding the in-memory overlay costs zero SlateDB reopens.
   - **Fast serving between checkpoints & historical lookups in `[S_hot, Cp]`:** G2/G3a retain latest, pinned and a bounded recent set of published versions and serve published interval-boundary cuts. At G3b, arbitrary-cut historical point lookups at `C ∈ [S_hot, Cp]` open the nearest preceding retained checkpoint `Cp_ckpt(C) <= C` and overlay `(Cp_ckpt(C), C]`—no LSM multi-version explosion and no undo deltas.
   - **Uniform Direct-DML PK image index:** Keyed direct-DML tables use this exact same SlateDB checkpoint + bounded input-log overlay pattern (eliminating synchronous two-store atomicity between SlateDB and the metadata root).
   - **Per-domain isolation first:** Start in G0–G2 with **one SlateDB instance per consistency domain/partition** to preserve domain independence ([ADR 0002](0002-consistency-domains.md)). G0.2/G3b measures idle S3 WAL/manifest cost per SlateDB instance so multi-domain physical grouping (with fenced writer ownership) activates cleanly when domain counts exceed the measured threshold.
3. **One locked storage path after G0.2:** G0.2 runs a focused real-provider comparison between this **immutable-delta + SlateDB-index + bounded overlay** layout and a **pure SlateDB-history** layout on `W1-G` (write/request amplification, exact-parent `SIGKILL` recovery, cold recovery, and one in-process historical lookup)—and locks **one** production layout before G2. Separate-process reads and grace-window deletion under live readers move to G4.0; Direct-DML PK-index recovery is accepted in P2.1.

## Alternatives and consequences

- **Per-interval SlateDB shallow clones:** Rejected as the default microbatch staging mechanism; shallow clones copy referenced WAL SSTs and create manifest/external-checkpoint dependencies designed for occasional branching, not sub-second interval preparation.
- **LSM attempt-namespace key filtering inside SlateDB:** Rejected as unnecessary complexity when immutable delta segments + in-memory tentative overlays already isolate unpublished preparations outside the LSM tree.
- **Premature multi-domain SlateDB physical grouping:** Deferred until measured idle per-instance WAL/manifest overhead justifies fenced physical grouping.
- **Trade-off accepted:** Keeping SlateDB checkpoints amortized means maintenance and serving nodes must maintain a small bounded in-memory overlay `(Cp_ckpt, Cp]` and write both compact delta segments and post-commit SlateDB updates. G0.2 explicitly measures overlay memory, cold-start replay latency, and dual-write cost against pure SlateDB history.

## Gate

**G0.2** measures both layouts on one real provider with `W1-G` (amplification, exact-parent reopen after `SIGKILL`, cold recovery, overlay bounds, and an in-process lookup at a retained earlier cut) and locks one storage design before G2. Direct-DML PK-index recovery is in P2.1; arbitrary-cut and real grace-window deletion evidence is collected at G3b/G4.0 respectively. [Consistency and storage](../design/consistency-and-storage.md) and [ADR 0009](0009-logical-mvcc.md) define the normative contract.
