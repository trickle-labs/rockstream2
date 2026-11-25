# ADR 0008: vertical delivery with independently checked evidence

**Status:** Proposed engineering policy. **Date:** 2026-11-25. **Owners:** technical lead and verification role.

## Decision

Use deterministic environment interfaces, independent batch comparison, protocol models, crash injection, real connector tests and selected machine-verified kernels from the first implementation slice. Preserve a small production correctness boundary: canonical semantics, durable admission, completeness/progress validation, publication/fencing, and pin/GC rules.

Deliver G0 experiments, G1 semantics, G2 durable single-node operation, G3 sharing/lifecycle, G4 distribution and G6 production qualification. G5 advanced features graduate independently. Do not postpone failure testing or security until the final phase. Do not create a separate simplified simulator execution algorithm that can pass while production fails.

Require measured-execution provenance and negative controls for release claims. Exact output checking includes row identity/weights, not only totals or latency. Distinguish model bounds, verified kernel properties, finite tests and deployed failure assumptions. Performance claims compare equivalent semantics and total infrastructure cost at a fixed SLO.

## Alternatives and consequences

Building the whole distributed product before establishing a durable vertical slice permits cross-layer assumptions to accumulate. Unit tests alone cannot establish crash and ownership behavior. Formal proofs alone do not cover unmodeled connectors, infrastructure or deployment assumptions. Benchmark-first development can optimize an incorrect or unbounded execution path.

This approach spends engineering effort on harnesses and independent checkers early. In return, it reduces the cost of changing algorithms or dependencies later and makes regression evidence reusable. A long-running qualification requirement must be budgeted as compute and engineering work, not treated as a last-minute checkbox.

## Evidence and adoption

The [qualification plan](../planning/qualification.md) specifies models, failure points, negative controls and benchmark provenance. [Implementation packages](../planning/implementation-plan.md) assign evidence to each gate. The original Rockstream's qualification program provides reusable structure; the [FoundationDB paper](https://www.foundationdb.org/files/fdb-paper.pdf) is a primary precedent for deterministic simulation. Neither source substitutes for new-system evidence.

A release reviewer other than the implementing author verifies the exact commit/binary bundle. Unresolved safety violations block promotion. A later design change updates the relevant contract, model, capability record and counterexample corpus in the same review chain.
