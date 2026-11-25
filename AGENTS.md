# Rockstream development guidance

This repository is currently an architecture and implementation plan, not an implemented engine. No Rust workspace or executable CI commands are established by this design PR. Do not claim unexecuted tests, benchmarks or production readiness.

Read [DESIGN.md](DESIGN.md), the relevant contract, [testing and verification](docs/design/testing-and-verification.md), [development workflow](docs/design/development-workflow.md) and [qualification](docs/planning/qualification.md) before changing a contract.

- Preserve every affected invariant and keep correctness non-negotiable. Implement the smallest independently safe change; avoid unrelated changes.
- Identify the owning contract and acceptance cases in the issue/PR. Keep design, ADRs, capability status, format and compatibility obligations aligned.
- Test at the lowest effective layer. Prefer pure unit/property tests, independent batch/differential oracles, production-logic deterministic simulation and focused real-dependency checks. Keep essential public-path coverage.
- Add a meaningful failing-before/passing-after regression for correctness fixes. Preserve minimized seeds, fault traces and independent expected results. Never weaken assertions, bypass checks or retry assertion failures into green.
- Run applicable focused and required checks with the same commands as CI. Escalate risk for changes to storage, metadata, concurrency, security, compatibility, dependencies or test/checker logic. Unknown impact requires broader checks.
- Keep PR feedback fast; run expensive exploration, cloud qualification, scale and long soaks in separate workflows unless required for the changed contract. Merge does not imply release qualification. Known correctness violations block affected promotion.
- Report actual checks executed, results, evidence, limitations and remaining risks. Keep secrets and privileged cloud operations out of untrusted workflows.

G0 must replace this paragraph with the actual reproducible local/CI commands (focused tests, fast gate, seed replay, extended suites, background and release qualification), prerequisites and artifact locations as they are implemented. Until then use documentation-only validation and state its limits explicitly.
