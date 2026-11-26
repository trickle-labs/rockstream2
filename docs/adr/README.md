# Architecture decision records

**Status:** Proposed design decisions for review, 2026-11-26. These records capture the working direction; they do not assert implementation, completed qualification, or a merged maintainer decision.

| ADR | Decision | Status and evidence needed |
| --- | --- | --- |
| [0001](0001-semantics.md) | DBSP foundation, weighted algebra, and versioned SQL semantics | Proposed commitment; G1 oracle and rewrite evidence |
| [0002](0002-consistency-domains.md) | Independent atomic publication groups with compatible logical cuts | G2 per-view/grouped heads; G3b shared consumer independence; G4 distributed imports |
| [0003](0003-publication-and-metadata.md) | Compositional single-root object metadata, pre-allocated owner namespaces, staged reader leases, and optional Embedded OpenRaft tier | G0.2/G0.3 core probe; G4.0 reader-lease probe |
| [0004](0004-arrangement-storage.md) | Immutable object-backed delta traces plus per-domain SlateDB working indexes with bounded delta overlays | G0.2 real-provider layout comparison and lock |
| [0005](0005-runtime-selection.md) | Lean native Arrow/DataFusion runtime with evidence-triggered fallback | G0.4 native kernel spike on `W1-G`; G3b single-depth pipelining |
| [0006](0006-sharing-and-optimization.md) | Rule-based, retention-aware, reversible sharing and eligible F-IVM | G3b sharing, isolation, and eligible factorization qualification |
| [0007](0007-product-guarantees.md) | SQL-first product, view fault isolation, five-stage capability registry, and honest latency profiles | G2/G3a public protocol, direct DML, and connector evidence |
| [0008](0008-verification-and-delivery.md) | Step-by-step vertical delivery with Quint, independent oracles, and real-backend crash testing | G0.1/G0.3 foundation and core model; gate-by-gate evidence |
| [0009](0009-logical-mvcc.md) | Bounded logical MVCC decoupled from physical checkpoints | G2/G3a published-boundary retention; G3b arbitrary-cut reconstruction |
| [0010](0010-operation-and-hibernation.md) | Single binary, stateless compute scale-to-zero, and workload-eligible full hibernation | G2 single-process stop/restart; G4 distributed drain/wake |
| [0011](0011-risk-reduction-before-implementation.md) | Lean G0 physics-first validation and practical architectural simplifications | Four G0 deliverables, refined by ADR 0012 |
| [0012](0012-staged-mechanism-adoption.md) | Decoupled G0 and stage mechanisms at their first consuming gate | G0 foundation unlocks G1; durability physics unlocks G2; leases at G4 and arbitrary-cut MVCC at G3b |

When accepting a record, name reviewers and link the evidence/implementation commit. A later decision supersedes an earlier record explicitly; do not silently change the meaning of a published guarantee. Preserve alternatives and counterexamples so future maintainers know which constraints caused the choice.
