# ADR 0006: shared state, rule-based isolation, and eligible F-IVM

**Status:** Proposed; built and qualified in G3b (broader strategies and automated cost-model advisory in G5). **Date:** 2026-11-26. **Owners:** optimizer, storage, and runtime roles.

## Decision

Maintain a canonical workload graph with reusable subexpressions and arrangements behind the SQL-first product. After a digest lookup, compare full canonical descriptors (normalized expression, schema, key/equality/collation version, numeric profile, source lineage, tenant/security context). Physical layout variants remain distinct from logical equivalence. Cross-tenant sharing is disabled initially.

### Retention-aware admission and reversible isolation (simple rules first)

Sharing is a placement choice made *after* semantic and security eligibility—never an automatic mandate, and never gated on an error-prone speculative dollar-cost model:
- **Independent consumer schedules:** Logical MVCC lets fast and slow consumers read different retained cuts without merging their publication groups.
- **Deterministic rule-based admission (G3b):** Share an arrangement by default when semantic/security descriptors match and the new consumer's retention window and freshness cadence fit within the shared arrangement's configured retention/memory budget; otherwise isolate or reject with explicit diagnostics in `EXPLAIN INCREMENTAL`. Defer a multi-term monetary cost-model advisor to G5 once real production telemetry exists.
- **Safe consumer isolation (G3b):** Support explicit or rule-based isolation from a shared arrangement using a pinned snapshot, protected replay, exact-cut equality verification, and atomic consumer-binding cutover comparing the live consumer head/cursor and fencing old-plan attempts. Reserve peak coexistence capacity before starting, and retain required old-history references until every promised historical cut and rollback obligation is safely covered. Budget exhaustion never silently discards promised history.

### First-order baseline and eligible factorization

First-order IVM is the semantic and performance baseline in G1–G3a. In **G3b**, qualify a bounded family of **eligible partial aggregation and factorization (F-IVM)** rules backed by explicit machine-readable strategy contracts (semantic side conditions, uniqueness/nullability/multiplicity proofs, fallback plan, and independent positive/negative tests). Statistics rank semantically valid plans but never establish semantic preconditions such as uniqueness. Broader higher-order derivatives, automated monetary cost-model advisory, and online adaptive replanning advance independently in **G5** with hysteresis, cooldown, and changeover budgets.

## Alternatives and consequences

- **Per-view isolated circuits:** Simpler ownership, but duplicates state and compute across overlapping read models (W2).
- **Mandatory global sharing:** Couples slow/long-retention consumers to fast ones and bloats shared history; bounded admission plus reversible isolation avoids this trap.
- **Premature 9-term monetary cost advisor in G3:** Rejected; future update distributions, skew, and failure rates are unknown at `CREATE MATERIALIZED VIEW` time. Simple deterministic rules + explicit `EXPLAIN INCREMENTAL` state/fanout visibility + manual/rule-based isolation deliver the value cleanly in G3b.
- **Deferring heavy 1,000-view benchmarks from G0 to G3b:** Keeps G0 focused on existential storage/metadata physics instead of premature sharing benchmarks before the shared graph even exists.

## Evidence

G3b qualifies shared vs. isolated placement at 100 and 1,000 overlapping views (W2), independent consumer schedules, consumer isolation under concurrent progress/GC, and the eligible factorization family against first-order and independent batch oracles. [Semantics and compiler](../design/semantics-and-compiler.md) defines the optimizer and eligibility contracts.
