# Architecture decision records

**Status:** Proposed design decisions for review, 2026-11-26. These records capture the working direction; they do not assert implementation, completed qualification, or a merged maintainer decision.

| ADR | Decision | Status and evidence needed |
| --- | --- | --- |
| [0001](0001-semantics.md) | DBSP foundation, weighted algebra, and versioned SQL semantics | Proposed commitment; G1 oracle and rewrite evidence |
| [0002](0002-consistency-domains.md) | Independent atomic publication groups with compatible logical cuts | G3 local consumer independence; G4 distributed imports |
| [0003](0003-publication-and-metadata.md) | Compositional single-root object metadata, lease-backed fast reads, and optional Embedded Raft tier | G0.2/G0.3 probe and Quint model; G4 optional Raft profile |
| [0004](0004-arrangement-storage.md) | Immutable object-backed delta traces plus per-domain SlateDB indexed working state | G0.2 real S3 + SlateDB physics probe and layout selection |
| [0005](0005-runtime-selection.md) | Lean native Arrow/DataFusion runtime with evidence-triggered fallback | G0.4 native kernel spike on `W1-G`; G3 single-depth pipelining |
| [0006](0006-sharing-and-optimization.md) | Cost-based, retention-aware, reversible sharing and eligible F-IVM | G3 sharing, isolation, and eligible factorization qualification |
| [0007](0007-product-guarantees.md) | SQL-first product, view fault isolation, five-stage capability registry, and honest latency profiles | G2/G3 public protocol, direct DML, and connector evidence |
| [0008](0008-verification-and-delivery.md) | Step-by-step vertical delivery with Quint, independent oracles, and real-backend crash testing | G0.1/G0.3 bootstrap and Quint model; gate-by-gate evidence |
| [0009](0009-logical-mvcc.md) | Bounded logical MVCC decoupled from physical checkpoints | G0.2/G2 exact-cut reconstruction; G3 independent consumer schedules |
| [0010](0010-operation-and-hibernation.md) | Single binary, stateless compute scale-to-zero, and workload-eligible full hibernation | G2 single-process stop/restart; G4 distributed drain/wake |
| [0011](0011-risk-reduction-before-implementation.md) | Lean G0 physics-first validation and practical architectural simplifications | Governs G0.1–G0.4 kill-switch gates before full-engine work |

When accepting a record, name reviewers and link the evidence/implementation commit. A later decision supersedes an earlier record explicitly; do not silently change the meaning of a published guarantee. Preserve alternatives and counterexamples so future maintainers know which constraints caused the choice.
