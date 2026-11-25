# ADR 0008: vertical delivery with independently checked evidence

**Status:** Proposed engineering policy. **Date:** 2026-11-25. **Owners:** technical lead and verification role.

## Decision

Use deterministic environment interfaces, independent batch comparison, protocol models, crash injection, real connector tests and selected machine-verified kernels from the first implementation slice. Preserve a small production correctness boundary: canonical semantics, durable admission, completeness/progress validation, publication/fencing, and pin/GC rules.

Transfer existing Rockstream's specification knowledge before porting implementation: inventory compatible SQL/wire/security tests, minimized historical bugs, deterministic fault scenarios, formal models, independent evaluators and qualification assets with their semantic assumptions. Every migrated capability requires a three-way comparison of original Rockstream, the new kernel and an independent batch oracle at identical complete transaction cuts. PostgreSQL serves as the oracle only for the declared compatible subset; intentional differences require independent explicit expectations. Neither agreement between two related engines nor inherited passing tests establishes correctness. The [migration plan](../planning/migration.md) defines donor and strangler-migration obligations.

Deliver G0 experiments, G1 semantics, G2 durable single-node operation, G3 sharing/lifecycle, G4 distribution and G6 production qualification. G5 advanced features graduate independently. Qualify suspension from the beginning: G0 feasibility, G2 single-process stop/resume from durable roots, G3 retained shared-consumer obligations, G4 distributed drain/fencing and concurrent activation, then G6 operational hardening. Eligible partial aggregation/factorization also starts with G0 experiments and a measured G3 core; general higher-order maintenance remains separately gated. Do not postpone failure testing or security until the final phase. Do not create a separate simplified simulator execution algorithm that can pass while production fails.

Require measured-execution provenance and negative controls for release claims. Exact output checking includes row identity/weights, not only totals or latency. Distinguish model bounds, verified kernel properties, finite tests and deployed failure assumptions. Performance claims compare equivalent semantics and total infrastructure cost at a fixed SLO.

The native-runtime and SlateDB preferences are working decisions to validate, not benchmark conclusions. Compare the native prototype seriously with Timely/Differential; test logical MVCC on SlateDB independently of physical checkpoint cadence. For metadata, exercise one-root atomic transitions, backend-specific conditional writes, ambiguous outcomes, stale ownership and pin/GC races. A single conditional object write does not prove a transaction over independent objects.

An eligible scale-to-zero claim requires an observed interval with no Rockstream process running, followed by exact recovery with no cloud-profile local authority surviving. Record the manual/platform activation mechanism, source/history headroom, timer/sink obligations, cold latency and total cost. Partial pool suspension and full hibernation are distinct claims. No executable qualification has been performed for this design PR.

Autonomous coding agents are the primary implementation workforce. Use small independently safe issues, isolated worktrees and protected exact-revision CI; allow policy-controlled routine auto-merge with independent review where required, but retain human approval for high-risk and architectural/policy changes and releases. No author may independently certify its own work. Separate merge and release; run broad verification in background, while requiring applicable safety evidence before high-risk merges. Design for maintainability, enforced dependency direction, reproducible bootstrap, continuous performance measurement and diagnostic evidence. The [agent operating model](../design/agent-development.md) and [development workflow](../design/development-workflow.md) define the operating rules. P0.9/P0.10 establish and exercise the foundation in G0; the prior human staffing/calendar assumptions are superseded, with forecasts to be based on observed agent throughput and independent review capacity.

Mechanically enforce crate dependency boundaries and the small trusted correctness kernel, with deliberately broken dependency and checker negative controls. Keep essential acceptance tests on the public path and choose additional CI by affected risk. Review growth in responsibilities, state-machine complexity, abstractions, compatibility paths and dependencies explicitly; arbitrary module line-count limits are not a substitute for that review.

## Alternatives and consequences

Building the whole distributed product before establishing a durable vertical slice permits cross-layer assumptions to accumulate. Unit tests alone cannot establish crash and ownership behavior. Formal proofs alone do not cover unmodeled connectors, infrastructure or deployment assumptions. Benchmark-first development can optimize an incorrect or unbounded execution path.

This approach spends engineering effort on harnesses and independent checkers early. In return, it reduces the cost of changing algorithms or dependencies later and makes regression evidence reusable. A long-running qualification requirement must be budgeted as compute and engineering work, not treated as a last-minute checkbox.

## Evidence and adoption

The [qualification plan](../planning/qualification.md) specifies models, failure points, negative controls and benchmark provenance. [Implementation packages](../planning/implementation-plan.md) assign evidence to each gate. The original Rockstream's qualification program provides reusable structure; the [FoundationDB paper](https://www.foundationdb.org/files/fdb-paper.pdf) is a primary precedent for deterministic simulation. Neither source substitutes for new-system evidence.

A release reviewer other than the implementing author verifies the exact commit/binary bundle; an authorized human maintainer approves the release. Unresolved safety violations block promotion. A later design change updates the relevant contract, model, capability record and counterexample corpus in the same review chain.
