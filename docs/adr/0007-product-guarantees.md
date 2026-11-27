# ADR 0007: explicit public guarantees, view fault isolation, and controlled product scope

**Status:** Proposed. **Date:** 2026-11-26. **Owners:** product/API, ingestion, and serving roles. Gate placement and initial profile scope are refined by [ADR 0012](0012-staged-mechanism-adoption.md) and [ADR 0013](0013-minimum-mechanisms-and-independent-qualification.md).

## Decision

Expose two distinct acknowledgements: `durable_input` (with a stable `WriteToken`) and `published` for named catalog-pinned dependencies (with a `SnapshotToken`). A publication wait timeout never rolls back accepted input. Sessions carry relevant per-domain write tokens for read-your-writes.

### Bounded direct writes with explicit index accounting

G2 direct writes support bounded same-domain transactions (`INSERT`, plus primary-key `UPDATE`/`DELETE` on keyed tables). Keyed direct-DML tables maintain an **explicitly budgeted durable primary-key image index** using the selected layout's qualified checkpoint/replay pattern (the hybrid candidate uses SlateDB checkpoint + immutable input-log overlay) (eliminating synchronous two-store atomicity between SlateDB and the metadata root); append-only tables and PostgreSQL CDC sources carrying full before-images avoid that index entirely. `SELECT` inside a write transaction and cross-domain atomic writes are rejected initially. Registered `(client_id, signed_client_generation, sequence)` identities are required for safe unknown-outcome retries; ordinary `pgwire` clients reconcile lost `COMMIT` responses.

### View-level fault isolation for runtime evaluation errors

Source validation errors reject direct writes before durable acceptance. By default from G2 onward, each independent materialized view owns its own lightweight result publication head consuming the ingestion domain, while views requiring joint atomic visibility declare an explicit `publication_group`. If a valid, durably accepted transaction triggers a runtime evaluation error in one derived view (for example, `DECIMAL` overflow or division by zero), the engine commits a durable **`Active → Quarantined`** metadata transition for that failing view at its last valid published cut with an explicit `ERROR` status and actionable diagnostic—preventing crash-restart loops—while unaffected views continue advancing. Views in a coupled atomic publication group quarantine together as the documented cost of joint atomicity. While quarantined, `latest-committed` / `bounded-staleness` reads continue serving the last valid published cut (`INV-07`), while `WAIT FOR PUBLICATION` and `read-your-writes` covering `>= failed_epoch` fail fast with **`RS_VIEW_QUARANTINED`** rather than hanging until timeout. A quarantined view's retention pin remains bounded by its configured retention quota (`IncrementalRetained → BackfillRequired` on quota expiry) so it cannot indefinitely wedge compaction/GC for healthy siblings; repair replays incrementally while retained history exists, or backfills cleanly from a base snapshot + tail once history expires (explicit recreate/rebuild in G2; online backfill in G3a `P3.2a`)—accepted input is never silently skipped.

### Honest read policies and delivery guarantees

Snapshots name exact logical cuts and protected physical roots. The initial profile includes latest-committed, WriteToken/read-your-writes waits and durable pinned repeatable reads at retained published interval boundaries. Additional modes qualify independently for a named workload; an unsupported mode fails explicitly. Read policies are explicit:
- `latest-committed`: Linearizable authoritative head selection during the request.
- `bounded-staleness` / `allowed-stale`: Optional cached-read capability, selected only when a workload needs its measured warm-read SLO. In a single-node profile, periodic root refresh bounds staleness and in-process pins protect reads; G4 out-of-process readers may use a GC-protection lease. Zero post-read S3 round-trips and sub-5 ms warm reads are unmeasured targets.
- `strict-immediate-revocation`: G4 opt-in mode performing synchronous post-read authorization revalidation at its documented remote-read latency cost.
- `historical` / `repeatable`: Exact retained published boundary initially; arbitrary cuts require G3b-I. Use explicit `RESNAPSHOT_REQUIRED` or unavailable-history errors—never silent fallback to newer data.

Subscriptions deliver one pinned snapshot followed by complete committed delta envelopes with resumable cursors (at-least-once network transport). Kafka delivery starts at-least-once with stable delivery IDs; stronger destination-marker protocols are separately gated.

### Unified five-stage capability registry

Maintain one versioned, machine-readable capability registry across all docs and tooling using the five-stage lifecycle: **`Planned → Implemented → Verified → Qualified → Supported`**. The initial profile uses bounded direct writes, PostgreSQL CDC and `pgwire`. Kafka source/sink support qualifies independently when a selected workload requires it; it is not a prerequisite for a PostgreSQL-only release. Arrow Flight SQL and broader SQL features advance through independent G5 gates. G6-S/G6-D release records name the exact capability combination and evidence; planned capabilities cannot be advertised by association.

## Alternatives and consequences

- Collapsing `durable_input` and `published` into one ambiguous `COMMIT` couples write latency to the slowest downstream view.
- Halting an entire multi-view domain on a single derived view's arithmetic overflow creates an unacceptable operational blast radius; view-level quarantine preserves both INV-01 (no bad data published) and availability for healthy views.
- Requiring synchronous post-read object-store checks on every read conflicts with the unmeasured sub-5 ms warm-read target; separating bounded-staleness reads from opt-in strict immediate revocation makes latency contracts explicit.

## Evidence

G2 qualifies public read/write/quarantine/lost-response transcripts at published interval boundaries; G3a qualifies PostgreSQL CDC handoff and subscriptions, with Kafka/sink ambiguity when selected; G3b-I qualifies arbitrary-cut MVCC; G4 qualifies out-of-process reader leases, grace-window GC, cross-domain reads and distributed activation; each G6-S/G6-D profile certifies named client versions, applicable operations and v1 migration at its declared scope. The [SQL and API contract](../reference/sql-and-apis.md) is authoritative.
