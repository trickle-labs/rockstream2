# ADR 0001: one semantic kernel for incremental SQL

**Status:** Proposed. **Date:** 2026-11-25. **Owners:** compiler/algebra and verification roles.

## Context

Operators, SQL lowering, distributed execution and persistence can each appear locally reasonable while disagreeing on duplicates, NULL, initialization, numeric errors or simultaneous changes. The original engine's behavior is valuable evidence, but a clean implementation needs a small, explicit contract that does not depend on incidental physical execution order.

## Decision

Represent relational changes as weighted bags and use a typed DBSP-inspired incremental algebra. Maintain the law that the published result equals independent batch evaluation at the declared input cut, under the chosen SQL/numeric profile. Initialize from `Q(empty)`. Version semantic descriptors, not just code and file formats.

Use DataFusion/sqlparser and Arrow where their behavior matches the declared contract. Own binding adaptations, capability rejection and incremental planning. A DataFusion plan being accepted or executable does not imply PostgreSQL-compatible SQL or incremental support. Exact integer/decimal aggregation uses checked final semantics and exact/widened intermediate accumulation; approximate floats require an explicit separate profile.

The [detailed semantic specification](../design/semantics-and-compiler.md) governs keys, NULL, duplicates, outer/anti behavior, ordering, temporal input and recursion. Specialized kernels may differ physically while implementing the same typed operator contract.

## Alternatives

Handwritten SQL delta operators alone offer a faster initial path but multiply hidden interactions and make advanced rewrites difficult to audit. Adopting an external runtime's full language/semantic surface reduces some work but may constrain cloud persistence and public SQL choices. Full PostgreSQL emulation would absorb the project into compatibility engineering. The proposal reuses components while retaining a narrow explicit semantic boundary.

## Consequences and evidence

There will be less SQL in G2 than the original engine currently exposes. Migration requires workload parity before cutover. Every promoted feature needs public-path backfill, retraction, restart and resource evidence. G0 settles the type-return/overflow matrix; G1 proves the initial supported combinations against an independent evaluator, with deliberate cross-term and empty-aggregate errors as negative controls.

DBSP supplies a research foundation, not an automatic proof of this compiler: [DBSP, PVLDB 2023](https://docs.feldera.com/vldb23.pdf). See [qualification](../planning/qualification.md) for the implementation obligations.
