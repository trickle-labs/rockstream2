# ADR 0006: shared state, cost-based isolation, and eligible F-IVM

**Status:** Proposed; built and qualified in G3 (broader strategies in G5). **Date:** 2026-11-26. **Owners:** optimizer, storage, and runtime roles.

## Decision

Maintain a canonical workload graph with reusable subexpressions and arrangements behind the SQL-first product. After a digest lookup, compare full canonical descriptors (normalized expression, schema, key/equality/collation version, numeric profile, source lineage, tenant/security context). Physical layout variants remain distinct from logical equivalence. Cross-tenant sharing is disabled initially.

### Cost-based admission and reversible isolation

Sharing is an economic placement choice made *after* semantic and security eligibility—never an automatic mandate:
- **Independent consumer schedules:** Logical MVCC lets fast and slow consumers read different retained cuts without merging their publication groups.
- **Pre-attachment cost check:** Compare a shared base plus marginal retained history against isolated bases over the workload horizon (CPU, base/index bytes, history bytes, object requests, compaction, build/replay overlap, and recovery time). Reserve peak build/rollback capacity before attaching.
- **Safe consumer isolation (G3):** Support explicit or rule-based isolation from a shared arrangement using a pinned snapshot, protected replay, exact-cut equality verification, and atomic consumer-binding cutover comparing the live consumer head/cursor and fencing old-plan attempts. Retain required old-history references until every promised historical cut and rollback obligation is safely covered. Budget exhaustion never silently discards promised history.

### First-order baseline and eligible factorization

First-order IVM is the semantic and performance baseline in G1–G2. In **G3**, qualify a bounded family of **eligible partial aggregation and factorization (F-IVM)** rules backed by explicit machine-readable strategy contracts (semantic side conditions, uniqueness/nullability/multiplicity proofs, fallback plan, and independent positive/negative tests). Statistics rank semantically valid plans but never establish semantic preconditions such as uniqueness. Broader higher-order derivatives and automatic adaptive replanning advance independently in **G5** with hysteresis, cooldown, and changeover budgets.

## Alternatives and consequences

- **Per-view isolated circuits:** Simpler ownership, but duplicates state and compute across overlapping read models (W2).
- **Mandatory global sharing:** Couples slow/long-retention consumers to fast ones and bloats shared history; cost-based admission plus reversible isolation avoids this trap.
- **Deferring heavy 1,000-view benchmarks from G0 to G3:** Keeps G0 focused on existential storage/metadata physics instead of premature sharing benchmarks before the shared graph even exists.

## Evidence

G3 qualifies shared vs. isolated placement at 100 and 1,000 overlapping views (W2), independent consumer schedules, consumer isolation under concurrent progress/GC, and the eligible factorization family against first-order and independent batch oracles. [Semantics and compiler](../design/semantics-and-compiler.md) defines the optimizer and eligibility contracts.
