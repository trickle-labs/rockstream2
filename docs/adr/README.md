# Architecture decision records

**Status:** Proposed design decisions for review, 2026-11-25. These records capture the agreed working direction for this PR; they do not assert implementation, completed qualification or a merged maintainer decision.

| ADR | Decision | Status and evidence needed |
| --- | --- | --- |
| [0001](0001-semantics.md) | DBSP foundation, weighted algebra and versioned SQL semantics | Proposed commitment; G1 oracle and rewrite evidence |
| [0002](0002-consistency-domains.md) | Independent atomic publication groups with compatible logical cuts | G3 local consumer independence; G4 distributed imports |
| [0003](0003-publication-and-metadata.md) | Object-backed atomic metadata without an external coordination service | One scoped root; G0 batched commits, reader groups, contention and backend qualification |
| [0004](0004-arrangement-storage.md) | SlateDB-first indexed storage with a focused MVCC arrangement layer | G0 bounded history-placement and attempt-isolation comparisons, recovery closure and actual reclamation |
| [0005](0005-runtime-selection.md) | Prefer a bounded native runtime and validate it against reuse | Binding G0 selection; one active interval/domain with fixed semantics and safety |
| [0006](0006-sharing-and-optimization.md) | Make sharing cost-based, retention-aware and reversible | G0 economics/factorization; G3 isolation and production qualification; broader G5 strategies |
| [0007](0007-product-guarantees.md) | SQL-first product, exact cuts, explicit acknowledgements and guarantee limits | G2/G3 public protocol and connector evidence |
| [0008](0008-verification-and-delivery.md) | Agent-first vertical delivery with independent evidence and donor tests | G0 three-way oracle and agent/CI pilot; each gate supplies independently checked evidence |
| [0009](0009-logical-mvcc.md) | Logical MVCC independent of physical checkpoint cadence | G0–G4 reconstruction, nonlinear history, lineage and retention tests |
| [0010](0010-operation-and-hibernation.md) | One binary with admitted full suspension and durable recovery | G0 experiment; G2 single-process, G3 shared consumers, G4 distributed wake |
| [0011](0011-risk-reduction-before-implementation.md) | Bound architectural alternatives before implementation without weakening cloud-native contracts | Proposed critique and decision boundaries; existing six G0 gates and joint evidence remain mandatory |

When accepting a record, name reviewers and link the evidence/implementation commit. A later decision supersedes an earlier record explicitly; do not silently change the meaning of a published guarantee. Preserve alternatives and counterexamples so future maintainers know which constraints caused the choice.
