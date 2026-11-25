# Architecture decision records

**Status:** Proposed design decisions for review, 2026-11-25. These records describe a recommended direction; they do not assert implementation, maintainer approval, or completed qualification.

| ADR | Decision | Status and evidence needed |
| --- | --- | --- |
| [0001](0001-semantics.md) | Weighted relational algebra and a versioned SQL semantic contract | Proposed architectural commitment; G1 oracle and rewrite evidence |
| [0002](0002-consistency-domains.md) | Domain-local publication with explicit compatible source cuts | Proposed architectural commitment; G0 model, G4 isolation and dependency tests |
| [0003](0003-publication-and-metadata.md) | Immutable preparation plus atomic metadata publication | Proposed architectural commitment; etcd/SQLite are candidates until G0 adapters pass |
| [0004](0004-arrangement-storage.md) | IVM-specific arrangement interface; evaluate SlateDB first | Candidate backend; exact checkpoint, retry, GC and cost experiment required |
| [0005](0005-runtime-selection.md) | Select the runtime through a bounded reuse experiment | Open component choice with fixed semantic/recovery requirements |
| [0006](0006-sharing-and-optimization.md) | Share compatible state and optimize lifetime workload cost | Proposed direction; G3 evidence, advanced strategy promotion in G5 |
| [0007](0007-product-guarantees.md) | Explicit acknowledgements, capability tiers, and external guarantee limits | Proposed public contract; G2/G3 protocol and connector qualification |
| [0008](0008-verification-and-delivery.md) | Verification-driven vertical delivery and evidence-backed promotion | Proposed engineering policy; each gate supplies independently checked evidence |

When accepting a record, name reviewers and link the evidence/implementation commit. A later decision supersedes an earlier record explicitly; do not silently change the meaning of a published guarantee. Preserve alternatives and counterexamples so future maintainers know which constraints caused the choice.
