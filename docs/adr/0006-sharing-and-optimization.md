# ADR 0006: shared state and lifetime workload optimization

**Status:** Proposed; simple sharing/rules first, adaptive strategies individually gated. **Date:** 2026-11-25. **Owners:** optimizer, storage and runtime roles.

## Decision

Maintain a canonical workload graph with reusable subexpressions and arrangements behind the SQL-first product. After a digest lookup compare full canonical descriptors, including semantic/key/equality version and tenant/security context. Keep physical layout variants separate from logical equivalence. Record each consumer's next required cut, retained-history protection, publication group and maintenance policy; reject incompatible reuse or make a deliberate copy.

Use logical MVCC to let fast and slow consumers read different retained cuts while shared state advances. A shared arrangement does not force unrelated groups to publish together. Actual data dependencies, complete source transactions and explicitly atomic publication groups still constrain compatible cuts. Retaining old cuts consumes storage and replay budget; slow consumers may expire and resnapshot. Physical checkpoints need not coincide, but exact covered logical cuts and source lineage must.

Optimize total lifetime cost under SLOs: maintenance, state/history, object requests/bytes, metadata, exchange, compaction, serving, recovery, dormant retention, wake-up/catch-up and changeover duplication. Begin with rule-based choices and measured statistics. First-order IVM is the semantic/performance baseline. Prototype a bounded eligible partial-aggregation/factorization family in G0 and qualify it in G3; keep general higher-order derivatives and adaptive selection independently gated in G5. Every optimization has explicit semantic side conditions and tests. Local recomputation may be the best correct strategy when the affected region is small or incremental state is more expensive.

Use pinned snapshot, catch-up, equality at a complete cut and atomic plan activation for replacements. Keep previous plan/state protected through the rollback window. Adaptive choices require anti-thrashing, resource budgets and estimate-confidence reporting. A fast plan that cannot be rebuilt within the recovery contract is not admissible.

## Alternatives and tradeoffs

Independent per-view circuits simplify ownership but waste state on overlapping workloads. Aggressive global sharing can couple failures, hold expensive history and undermine tenant isolation. The design shares within compatible boundaries and permits duplication when it reduces total cost or isolates an SLO. Cross-tenant sharing is disabled initially.

A one-shot SQL cost optimizer ignores update/delete rates and future state. A universal higher-order strategy can explode auxiliary state. A learned/adaptive optimizer from day one adds hard-to-reproduce decisions before telemetry exists. The staged approach makes each strategy explainable and reversible.

## Evidence

G0 compares the grouped-join example with first-order and eligible factorized plans. G3 compares shared and unshared execution for 100 and 1,000 views with slow consumers, online drops, sleep/resume and retained snapshots. Qualify the initial factorization family through public SQL, deletes, numeric/NULL semantics, historical cuts and crash recovery. Count metadata/history/build and wake-up costs as well as steady-state RAM. G5 promotes each broader strategy only when exact results, recovery and lifetime cost improve on a predeclared eligible workload. Do not generalize research's favorable results into a universal gain: [F-IVM](https://arxiv.org/abs/2303.08583) and [shared arrangements](https://arxiv.org/abs/1812.02639) are algorithmic precedents.

The algorithm eligibility and optimizer contract are in [semantics and compiler](../design/semantics-and-compiler.md).
