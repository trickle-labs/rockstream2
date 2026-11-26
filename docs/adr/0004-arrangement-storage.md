# ADR 0004: immutable delta traces with per-domain SlateDB working indexes and bounded overlays

**Status:** Proposed storage architecture; physics validated in G0.2. **Date:** 2026-11-26. **Owners:** storage and engine roles.

## Decision

Separate **authoritative durable history** from **indexed working state** so neither fights the other's physics, governed by one authoritative metadata manifest:

1. **Authoritative Input & Delta Traces (Immutable Object Segments):** Accepted input transactions and committed per-interval operator/output deltas are written as immutable weighted Arrow/batch objects on object storage and selected by the committed manifest. Because staged segments are immutable and unreferenced until publication CAS succeeds:
   - Abandoned preparations require **zero database cloning** and **zero LSM attempt-namespace key filtering**; they are simply unreferenced objects reaped by GC.
   - Sequential scans, replay, historical delta delivery, and subscriptions read immutable segments directly without LSM compaction overhead.
2. **Indexed Working State (SlateDB + Bounded In-Memory Delta Overlay):** Use **SlateDB** for persistent point probes, join lookups, current-state serving indexes, and (when direct SQL `UPDATE`/`DELETE` is enabled) the explicitly budgeted primary-key image index, paired with an explicit **bounded in-memory indexed overlay** for trailing deltas between periodic SlateDB checkpoints (`Cp_ckpt <= Cp`):
   - **Tentative writes never pollute SlateDB:** During an unpublished interval, maintenance holds tentative updates in a local in-memory overlay, uploads immutable delta segments, and applies committed deltas into SlateDB *only after* publication CAS succeeds. On abort/CAS conflict, discarding the in-memory overlay costs zero SlateDB reopens.
   - **Fast serving between checkpoints & historical lookups in `[S_hot, Cp]`:** Both maintenance and serving nodes merge the bounded trailing-delta overlay `(Cp_ckpt, Cp]` over the manifest-referenced SlateDB checkpoint, taking a new non-expiring SlateDB checkpoint whenever trailing delta count or bytes hit a configured cap. Historical point lookups at `C ∈ [S_hot, Cp]` open the nearest preceding retained checkpoint `Cp_ckpt(C) <= C` and overlay `(Cp_ckpt(C), C]`—no LSM multi-version explosion and no undo deltas.
   - **Uniform Direct-DML PK image index:** Keyed direct-DML tables use this exact same SlateDB checkpoint + bounded input-log overlay pattern (eliminating synchronous two-store atomicity between SlateDB and the metadata root).
   - **Per-domain isolation first:** Start in G0–G2 with **one SlateDB instance per consistency domain/partition** to preserve domain independence ([ADR 0002](0002-consistency-domains.md)). G0.2/G3b measures idle S3 WAL/manifest cost per SlateDB instance so multi-domain physical grouping (with fenced writer ownership) activates cleanly when domain counts exceed the measured threshold.
3. **One locked storage path after G0.2:** G0.2 runs a focused real-S3 comparison between this **immutable-delta + SlateDB-index + bounded overlay** layout and a **pure SlateDB-history** layout on `W1-G` (including *separate* serving-node point lookups at `Cp` and `C ∈ [S_hot, Cp]`, exact-parent `SIGKILL` recovery, Direct-DML PK index recovery, write/request amplification, and actual grace-window GC deletion)—and locks **one** production layout before G2.

## Alternatives and consequences

- **Per-interval SlateDB shallow clones:** Rejected as the default microbatch staging mechanism; shallow clones copy referenced WAL SSTs and create manifest/external-checkpoint dependencies designed for occasional branching, not sub-second interval preparation.
- **LSM attempt-namespace key filtering inside SlateDB:** Rejected as unnecessary complexity when immutable delta segments + in-memory tentative overlays already isolate unpublished preparations outside the LSM tree.
- **Premature multi-domain SlateDB physical grouping:** Deferred until measured idle per-instance WAL/manifest overhead justifies fenced physical grouping.
- **Trade-off accepted:** Keeping SlateDB checkpoints amortized means maintenance and serving nodes must maintain a small bounded in-memory overlay `(Cp_ckpt, Cp]` and write both compact delta segments and post-commit SlateDB updates. G0.2 explicitly measures overlay memory, cold-start replay latency, and dual-write cost against pure SlateDB history.

## Gate

**G0.2** measures both layouts on real S3/object storage with `W1-G` (separate-reader point lookup at `Cp` and historical `C`, exact-parent reopen after `SIGKILL`, Direct-DML PK index recovery, checkpoint amortization, nonlinear intermediate cuts, real grace-window GC reclamation, and cold recovery) and locks one storage design before G2. [Consistency and storage](../design/consistency-and-storage.md) and [ADR 0009](0009-logical-mvcc.md) define the normative contract.
