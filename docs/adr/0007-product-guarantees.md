# ADR 0007: explicit public guarantees and a controlled product scope

**Status:** Proposed. **Date:** 2026-11-25. **Owners:** product/API, ingestion and serving roles.

## Decision

Expose two acknowledgements: durable input with a stable write token, and publication of named catalog-pinned dependencies with a snapshot token. A publication wait timing out does not undo input. Sessions retain relevant per-domain write tokens for read-your-writes.

G2 direct writes are bounded same-domain keyed transactions with serialized admission against accepted state, including accepted but unpublished writes. SELECT in a write transaction and cross-domain atomic writes are initially rejected. pgwire compatibility does not imply every PostgreSQL isolation, extension or client-retry behavior. Registered request identities are required for safe unknown-outcome retries; ordinary clients must reconcile a lost COMMIT result.

Snapshots name exact versions. Subscriptions send one initial snapshot and complete committed delta envelopes with resumable cursors; unacknowledged transport can repeat. Kafka delivery starts at-least-once with stable IDs. An exactly-once claim requires a qualified destination-visible marker/transaction recovery protocol, not merely an idempotent producer. Schema changes, expired history, invalid tokens and unavailable compatible cuts return explicit errors.

Maintain a capability registry distinguishing Planned, Experimental and Qualified behavior. Initial external integration growth is limited to PostgreSQL CDC, Kafka and pgwire; Arrow Flight SQL and richer SQL arrive through separate gates. Maintained time uses a durable clock input when promoted; ordinary `NOW()` is not silently reevaluated against wall time.

## Alternatives and consequences

One ambiguous “committed” response is easier to describe but obscures the central freshness/durability distinction. Always waiting for all views makes unrelated slow consumers an implicit write dependency. Unconditional external exactly-once claims would exceed the protocols' capabilities. Complete PostgreSQL compatibility would delay the core product and complicate admission/locking semantics.

Applications must understand the chosen acknowledgement and expiry rules. The first release will reject some queries the original engine supports; migration does not occur until that workload's required feature set is qualified. Clear errors and capability documentation are part of the product rather than an excuse for a silent fallback.

## Evidence

G2 proves public read/write/cancellation/lost-response transcripts. G3 proves source handoff, subscriptions and sink ambiguity. G4 proves compatible cross-domain reads. G6 certifies named client versions and migration behavior. The [SQL/API specification](../reference/sql-and-apis.md) is authoritative for this contract.
