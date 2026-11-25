# Development workflow and CI strategy

**Status:** Proposed, 2026-11-25. These are initial delivery objectives and policies, not measured build times or configured workflows. The implementation begins with G0. See [testing and verification](testing-and-verification.md) for the test pyramid and [qualification](../planning/qualification.md) for release gates.

## 1. Fast and safe delivery

Keep issue-to-merged-PR lead time low. Favor small independently reviewable vertical changes, explicit contracts, stable dependency boundaries, trunk-based integration and automated checks. Merge and release are separate decisions: passing bounded PR checks permits an appropriate merge, not a production guarantee. Incomplete capabilities remain unsupported and disabled on supported paths; release promotion requires the full applicable evidence at the exact candidate commit/binary. Never trade a known correctness violation for a timing objective.

Initial objectives (measure and recalibrate after G0, not hard deadlines that bypass checks):

| Metric | Objective |
| --- | --- |
| Focused local feedback on warm development builds | 1–10 seconds |
| Required CI wall clock, median / P95 | Under 5 / 10 minutes for ordinary PRs, including queue and all required jobs |
| Small ready issue to merge | Under one hour where practical; track end-to-end lead time, including review and CI |
| Simulation replay | Every deterministic failure reproducible from the archived inputs |
| Correctness regression prevention | Every fixed correctness defect has regression evidence; every critical invariant mapped |
| Flaky deterministic checks / known correctness violations in releases | Zero |

Record cold and warm compilation separately; measure median/P95 lead times, queueing, critical-path jobs, reruns, review wait, background evidence age/backlog, escaped defects, test stability and verification compute cost. Segment documentation-only, ordinary, and high-risk changes so difficult work is visible, not hidden as an exception. Timing failures call for optimization, more capacity or smaller changes, not deleting necessary checks.

## 2. Verification lanes

| Lane | Trigger and scope | Gate |
| --- | --- | --- |
| Local | Focused unit/property/component/seed replay; same commands as CI | Developer feedback |
| PR fast | Every PR and final integration revision: docs/link checks as applicable; code build, formatting/lint, deterministic unit/property/component corpus, fixed critical simulation seeds and small real-dependency/public-path smoke suite for available supported capabilities | Required |
| PR extended | Contract/dependency/risk-based integration, fault, model/proof, compatibility or focused benchmark checks; author or reviewer can escalate | Required for affected risk; otherwise opt-in |
| Post-merge | Broader regression, more seeds and real integration across main revisions | Asynchronous; failures require action |
| Continuous | Parallel budgeted search, fuzzing and model exploration; sampled mutation checks and performance diagnostics | Asynchronous |
| Nightly | Broad randomized simulation, real supported cloud-backend conformance, connector/format compatibility and benchmark regression | Asynchronous |
| Weekly | Larger topologies, deeper proof/model exploration, full mutation samples, recovery drills and extended soaks | Asynchronous |
| Release/capability promotion | Full relevant workload/fault/upgrade/restore/security/performance matrix, including required long soaks, exact independent evidence and signoff | Required for release/promotion |

Schedule and seed counts follow measured cost and coverage. Continuous workers can run around the clock within a budget, not on the PR critical path. Run a bounded deterministic seed set on PRs; retain a small rotating, reproducible set and the historical counterexamples. Expensive checks may start during a PR and complete against the merged revision if applicable; a required risk check cannot be demoted merely because it is slow. On main, preserve evidence for exact revisions; a previous green revision or PR head is not qualification for the next commit.

## 3. Risk-based required checks

Maintain a versioned contract-to-test and dependency-to-suite mapping, with transitive reverse dependencies. Compute scope from the full change against the integration base, including manifests, lockfiles, build scripts, feature flags, fixtures, workflows and test/checker changes. Use conservative defaults: unknown paths, mapping errors, shared infrastructure changes or an uncertain impact require broader checks, not silent skips. Reviewers may always escalate; a PR author cannot unilaterally exempt a required check. Changes to the selector or oracle need independent review and negative controls proving relevant jobs cannot be silently skipped.

| Change | Required additions to the fast baseline |
| --- | --- |
| Documentation only | Markdown/link/contract consistency checks; no engine build if genuinely docs-only |
| Algebra, SQL, optimizer | Affected generated histories, rewrite counterexamples, SQL compatibility and independent oracle |
| Metadata, storage, logical MVCC, recovery, ownership, GC or suspension | Applicable bounded models/critical schedules, real durable reopen and stale-owner/fault smoke cases |
| Public API, connectors, formats, dependencies or security | Impacted integration, protocol/compatibility, security and upgrade smoke cases |
| Runtime scheduling, sharing or performance-sensitive optimization | Deterministic fault/progress scenarios, reference-path equivalence and focused resource/performance checks |

For high-risk changes require all evidence necessary for the changed safety contract before merge, even if that exceeds the ordinary budget. Split a risky implementation into inert preparatory work and separately verified activation where possible. A feature flag cannot conceal risk to existing supported behavior or durable state.

## 4. CI implementation

G0 establishes one documented local/CI task interface for fast, targeted, replay, extended and qualification commands (names/tool choice to be selected during implementation). Expose test discovery and concise actionable failures with command, seed, expected/actual result, trace/artifact and affected contract. Human and automated contributors use the same commands, not a separate agent-only or CI-only implementation.

Use the Rust crate dependency direction to avoid compiling storage/server/connector stacks for pure kernels. Profile build graph and test timing before tuning; pin toolchains and dependency locks, cache by toolchain/target/features/lockfile and relevant source, and verify clean builds independently. Evaluate a parallel test runner (such as cargo-nextest) and compiler caching during G0 rather than committing blindly to tools. Build once per compatible profile, shard independent tests by measured duration, reuse exact build artifacts when appropriate, and parallelize jobs without overloading runners. Isolate caches/artifacts by trust boundary; verify provenance. Documentation-only PRs should not pay a Rust build cost.

Use stable required status checks and a final gate that distinguishes passed, legitimately not applicable, failed, canceled and missing expected jobs. Test the selection logic itself. Cancel superseded PR runs, never the current required gate; prioritize PR/merge jobs with reserved capacity and isolate deep verification runner pools, cloud budgets, credentials and concurrency. Serialize final integration or use a merge queue when concurrency warrants it; validate the actual integration revision, not a stale PR head. No routine requirement to rerun the complete release matrix on each PR.

Use least-privilege workflow permissions and isolated environments. Never expose cloud credentials or privileged caches to untrusted PR code. Use scoped temporary cloud credentials and bounded disposable resources for trusted qualification jobs; capture cleanup and costs. Set timeouts, report partial/canceled evidence as incomplete and avoid silent background backlog.

## 5. Background failures and releases

A verified correctness, durability, isolation or security violation blocks promotion of affected code immediately. Notify the responsible maintainer, create or update a tracked incident with exact commit/seed/trace, classify severity, and stop affected merges until contained. For main regressions, normally revert promptly or land a verified fix; if isolation is demonstrated, unrelated development may proceed. Keep known-good artifacts available and prevent releases carrying the defect. Do not allow background results to disappear or be marked green by retries.

Distinguish test/harness failures and infrastructure failures from product assertions; investigate flaky checks with ownership and an expiry. Retry only classified transient infrastructure failures, record attempts, and fail closed on missing required evidence. Critical invariant regressions are not waivable for speed. Performance regressions follow the predeclared workload limits and explicit decision process in [qualification](../planning/qualification.md).

The release gate consumes exact-candidate qualification evidence, not just main's PR status. Record pass, fail, running, missing, and stale states; a changed candidate invalidates affected evidence, with reuse only where exact identities and scope meet the qualification contract. Do not promote a supported capability until its public path, backfill, live changes, failure/restart and applicable qualification are complete. Keep all existing G0–G6 exit criteria and independent safety review.

## 6. Issue-to-PR discipline

Use the issue contract and acceptance fields in the [implementation plan](../planning/implementation-plan.md). Split changes into small independently safe steps; avoid speculative scaffolding and large unrelated refactors. Include tests, applicable invariant ledger updates, migration/format changes, capability status and reproduction commands in the PR. Review high-risk changes with the appropriate independent contract owners; optimize review latency through focused diffs and clear evidence rather than removing review.

Make the repo suitable for human and AI-assisted development: concise root [AGENTS.md](../../AGENTS.md), explicit ownership and boundaries, discoverable commands, deterministic tests and actionable failure output. Tests are executable contracts, not a substitute for independent oracles or review. Never weaken tests to make an implementation pass.
