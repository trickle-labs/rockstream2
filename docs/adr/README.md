# Architecture decision records

**Status:** Proposed design decisions for review, 2026-11-27. These records capture the working direction; they do not assert implementation, completed qualification, or a merged maintainer decision.

| ADR | Decision | Status and evidence needed |
| --- | --- | --- |
| [0001](0001-semantics.md) | DBSP foundation, weighted algebra, and versioned SQL semantics | Proposed commitment; G1 oracle and rewrite evidence |
| [0002](0002-consistency-domains.md) | Independent atomic publication groups with compatible logical cuts | G2 per-view/grouped heads; G3b-S same-group sharing; G3b-I consumer independence; G4 distributed imports |
| [0003](0003-publication-and-metadata.md) | Single-root object metadata, measured batching, pre-allocated owner namespaces, staged reader leases, and optional Embedded OpenRaft tier | G0.2/G0.3 core probe; G4.0 reader-lease probe |
| [0004](0004-arrangement-storage.md) | Immutable object-backed delta traces plus per-domain SlateDB working indexes with bounded delta overlays | G0.2 neutral real-provider comparison; simplest passing layout locked |
| [0005](0005-runtime-selection.md) | Lean native Arrow/DataFusion runtime with evidence-triggered fallback | G0.4 scoped native feasibility; physical resource qualification before G2 preview qualification; G3b-P pipelining |
| [0006](0006-sharing-and-optimization.md) | Rule-based, retention-aware, reversible sharing and eligible F-IVM | Independent G3b-S sharing, G3b-F factorization and G3b-I isolation qualification |
| [0007](0007-product-guarantees.md) | SQL-first product, view fault isolation, five-stage capability registry, and honest latency profiles | G2/G3a public protocol, direct DML, and connector evidence |
| [0008](0008-verification-and-delivery.md) | Step-by-step vertical delivery with Quint, independent oracles, and real-backend crash testing | G0.1/G0.3 foundation and core model; gate-by-gate evidence |
| [0009](0009-logical-mvcc.md) | Bounded logical MVCC decoupled from physical checkpoints | G2/G3a published-boundary retention; G3b-I arbitrary-cut reconstruction |
| [0010](0010-operation-and-hibernation.md) | Single binary, stateless compute scale-to-zero, and workload-eligible full hibernation | G2 stop/restart; G6-S eligible single-node lifecycle; G4/G6-D distributed drain/wake |
| [0011](0011-risk-reduction-before-implementation.md) | Lean G0 physics-first validation and practical architectural simplifications | Four G0 deliverables, refined by ADR 0012 |
| [0012](0012-staged-mechanism-adoption.md) | Decoupled G0 and stage mechanisms at their first consuming gate | G0 foundation unlocks G1; durability physics unlocks G2; leases at G4 and arbitrary-cut MVCC at G3b-I; refined by ADR 0013 |
| [0013](0013-minimum-mechanisms-and-independent-qualification.md) | Minimum mechanisms, independent IVM capability qualification and profile-based production | G6-S without mandatory G4; G6-D after G4; neutral storage choice and scoped G0.4, with all safety evidence preserved |
| [0014](0014-incremental-delivery-and-earned-complexity.md) | Runnable increments, serialized compact metadata first, and evidence-driven complexity | Internal slices do not replace full gates; batching/paging require measured need; early workload economics guides selected differentiation |

When accepting a record, name reviewers and link the evidence/implementation commit. A later decision supersedes an earlier record explicitly; do not silently change the meaning of a published guarantee. Preserve alternatives and counterexamples so future maintainers know which constraints caused the choice.
