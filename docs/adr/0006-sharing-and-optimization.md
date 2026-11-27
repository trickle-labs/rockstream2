# ADR 0006: independently qualified sharing, isolation, and eligible F-IVM

**Status:** Proposed; capability dependencies refined by [ADR 0013](0013-minimum-mechanisms-and-independent-qualification.md). **Date:** 2026-11-27. **Owners:** optimizer, storage, and runtime roles.

## Decision

Maintain a canonical workload graph with reusable subexpressions and arrangements behind the SQL-first product. After a digest lookup, compare full canonical descriptors (normalized expression, schema, key/equality/collation version, numeric profile, source lineage, tenant/security context). Physical layout variants remain distinct from logical equivalence. Cross-tenant sharing is disabled initially.

### Same-cadence sharing first (G3b-S)

Qualify canonical arrangement reuse within one explicitly selected publication group and maintenance cadence. Preserve exact descriptors, security eligibility, bounded shared-state accounting, durable lifecycle and recovery. Views in the group share atomic publication and quarantine; do not imply independent schedules or failure isolation. Never silently merge existing independent groups to enable sharing. Initial unsharing can use qualified create/backfill/replace at a published boundary; it need not implement a universal online isolation protocol.

### Retention-aware admission and reversible isolation (G3b-I)

Sharing is a placement choice made *after* semantic and security eligibility—never an automatic mandate, and never gated on an error-prone speculative dollar-cost model:
- **Independent consumer schedules:** G3b-I logical MVCC lets fast and slow consumers read different retained cuts without merging their publication groups; G3b-S does not make this promise.
- **Deterministic rule-based admission (G3b-I):** Share an arrangement when semantic/security descriptors match and the new consumer's retention window and freshness cadence fit within the shared arrangement's configured retention/memory budget; otherwise isolate or reject with explicit diagnostics in `EXPLAIN INCREMENTAL`. Defer a multi-term monetary cost-model advisor to G5 once real production telemetry exists.
- **Safe consumer isolation (G3b-I):** Support explicit or rule-based isolation from a shared arrangement using a pinned snapshot, protected replay, exact-cut equality verification, and atomic consumer-binding cutover comparing the live consumer head/cursor and fencing old-plan attempts. Reserve peak coexistence capacity before starting, and retain required old-history references until every promised historical cut and rollback obligation is safely covered. Budget exhaustion never silently discards promised history.

### First-order baseline and eligible factorization

First-order IVM is the semantic and performance baseline. In **G3b-F**, qualify a bounded family of **eligible partial aggregation and factorization (F-IVM)** rules backed by explicit machine-readable strategy contracts (semantic side conditions, uniqueness/nullability/multiplicity proofs, fallback plan, and independent positive/negative tests). A fixed, explicitly selected eligible rule may qualify without G3b-S sharing, G3b-I independent scheduling/isolation, or a global cost planner. It still needs exact NULL/empty/retraction/numeric behavior, durable recovery, resource/skew bounds and measured lifetime benefit against first-order and independent batch baselines. Statistics rank semantically valid plans but never establish semantic preconditions such as uniqueness. Broader higher-order derivatives, automated monetary cost-model advisory, and online adaptive replanning advance independently in **G5** with hysteresis, cooldown, and changeover budgets.

Depth-one pipelining is the independent **G3b-P** optimization in [ADR 0005](0005-runtime-selection.md). It is not a prerequisite for sharing or factorization.

## Alternatives and consequences

- **Per-view isolated circuits:** Simpler ownership, but duplicates state and compute across overlapping read models (W2).
- **Mandatory global sharing:** Couples slow/long-retention consumers to fast ones and bloats shared history; bounded admission plus reversible isolation avoids this trap.
- **Premature 9-term monetary cost advisor in G3:** Rejected; future update distributions, skew, and failure rates are unknown at `CREATE MATERIALIZED VIEW` time. Simple deterministic rules + explicit `EXPLAIN INCREMENTAL` state/fanout visibility + manual/rule-based isolation deliver the value cleanly in G3b.
- **Deferring heavy 1,000-view benchmarks from G0 to G3b:** Keeps G0 focused on existential storage/metadata physics instead of premature sharing benchmarks before the shared graph even exists.

## Evidence

G3b-S qualifies shared versus isolated placement at 100 and 1,000 overlapping views (W2) under the same publication/cadence guarantees, including build, history, recovery and idle cost. G3b-I adds heterogeneous W2/W14, independent consumer schedules and isolation under concurrent progress/GC. G3b-F qualifies each eligible factorization family against first-order and independent batch oracles. Evidence records the selected capabilities and their combined path; passing one never promotes the others. [Semantics and compiler](../design/semantics-and-compiler.md) defines the optimizer and eligibility contracts.
