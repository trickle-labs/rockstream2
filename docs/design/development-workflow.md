# Development workflow and CI strategy

**Status:** Proposed, 2026-11-26. These are initial delivery objectives and policies, not measured build times or configured workflows. The implementation begins with G0. The [implementation plan](../planning/implementation-plan.md) is the single roadmap authority; G0 foundation unlocks G1 while G0 durability physics runs in parallel and unlocks G2. See [testing and verification](testing-and-verification.md) for the test pyramid and [qualification](../planning/qualification.md) for release gates.

## 1. Fast and safe delivery

Autonomous coding agents are the primary implementation workforce; the [agent operating model](agent-development.md) defines issue ownership, independent review, human decision authority and risk-based autonomy. Keep issue-to-merged-PR lead time low. Favor small independently reviewable vertical changes, explicit contracts, stable dependency boundaries, trunk-based integration and automated checks. Merge and release are separate decisions: passing bounded PR checks permits an appropriate merge, not a production guarantee. Incomplete capabilities remain unsupported and disabled on supported paths; release promotion requires the full applicable evidence at the exact candidate commit/binary. Never trade a known correctness violation for a timing objective.

Initial objectives (measure and recalibrate after G0, not hard deadlines that bypass checks):

| Metric | Objective |
| --- | --- |
| Focused local feedback on warm development builds | 1–10 seconds |
| Required CI wall clock, median / P95 | Under 5 / 10 minutes for ordinary PRs, including queue and all required jobs |
| Small ready issue to merge | Under one hour where practical; track end-to-end lead time, including review and CI |
| Accepted safe change | Track agent/CI cost, rework, human review wait, escaped defects and qualification backlog; baseline in G0 |
| Simulation replay | Every deterministic failure reproducible from the archived inputs |
| Correctness regression prevention | Every fixed correctness defect has regression evidence; every critical invariant mapped |
| Flaky deterministic checks / known correctness violations in releases | Zero |

Record cold and warm compilation separately; measure median/P95 lead times, queueing, critical-path jobs, reruns, review wait, background evidence age/backlog, escaped defects, test stability and verification compute cost. Segment documentation-only, ordinary, and high-risk changes so difficult work is visible, not hidden as an exception. Timing failures call for optimization, more capacity or smaller changes, not deleting necessary checks. In G0.1, record run-created-to-start queue delay, job execution, and run-created-to-completion wall time from actual required jobs; review a repeatable sample against the existing queue-inclusive objective. If queueing dominates (see [preliminary G0.1 evidence](../../evidence/g0-1/preliminary.md)), prioritize current required jobs over superseded or deep jobs, investigate runner capacity and keep the local fast command available for development. Do not relabel a failed timing objective as a pass by excluding queue time, treat a missing result as successful, or retry assertion failures into green.

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

Risk-based integration follows the [agent operating model](agent-development.md): agents integrate authorized milestone work after required CI and independent review, including safety review for high-risk changes. The human reviews the completed milestone; release authorization is separate. A documentation or test-only change can still be high risk. Policy, selector, workflow, checker and permission changes cannot approve or authorize themselves, and enforced branch rules are never bypassed. In G0.1 confirm the actual repository settings enforce protected `main`, required checks on the integration revision and the existing independent-review policy. If plan/permissions prevent verification or enforcement, record the gap and ask the maintainer to configure the standard GitHub controls or explicitly resolve the policy through separate review; do not enable autonomous integration under unverified protection or pretend an advisory check is enforced. This is existing policy enforcement, not a new approval layer.

## 4. CI implementation

G0 establishes one documented local/CI task interface for fast, targeted, replay, extended and qualification commands (names/tool choice to be selected during implementation). Expose test discovery and concise actionable failures with command, seed, expected/actual result, trace/artifact and affected contract. Human and automated contributors use the same commands, not a separate agent-only or CI-only implementation.

Use the Rust crate dependency direction to avoid compiling storage/server/connector stacks for pure kernels. Profile build graph and test timing before tuning; pin toolchains and dependency locks, cache by toolchain/target/features/lockfile and relevant source, and verify clean builds independently. Evaluate a parallel test runner (such as cargo-nextest) and compiler caching during G0 rather than committing blindly to tools. Build once per compatible profile, shard independent tests by measured duration, reuse exact build artifacts when appropriate, and parallelize jobs without overloading runners. Isolate caches/artifacts by trust boundary; verify provenance. Documentation-only PRs should not pay a Rust build cost.

Use stable required status checks and a final gate that distinguishes passed, legitimately not applicable, failed, canceled and missing expected jobs. Test the selection logic itself. Cancel superseded PR runs, never the current required gate; prioritize PR/merge jobs with reserved capacity and isolate deep verification runner pools, cloud budgets, credentials and concurrency. Serialize final integration or use a merge queue when concurrency warrants it; validate the actual integration revision, not a stale PR head. No routine requirement to rerun the complete release matrix on each PR.

Use least-privilege workflow permissions and isolated environments. Establish reproducible clean bootstrap with pinned Rust toolchain, committed lockfile, declared native tools and service versions, deterministic build inputs and checksums. Distinguish reproducible instructions from bit-for-bit reproducibility (measure the latter before claiming it). Run dependency/license/vulnerability checks and record reviewed exceptions with owners and expiry. Automate small dependency updates; upgrades to critical SlateDB, DataFusion, Arrow and runtime components trigger contract/conformance, format compatibility and performance checks as applicable. Keep pinned upgrades isolated; start with the upstream-supported behavior behind narrow existing boundaries. A fork or new abstraction requires a demonstrated blocker, comparison with supported versions or replacement, ongoing security/upgrade ownership, and a reviewed removal or upstreaming path. Generate dependency inventory/SBOM and build provenance; sign or attest release artifacts in a separately protected release workflow. Do not give an implementation agent administrative or signing credentials. Never expose cloud credentials or privileged caches to untrusted PR code. Use scoped temporary cloud credentials and bounded disposable resources for trusted qualification jobs; capture cleanup and costs. Set timeouts, report partial/canceled evidence as incomplete and avoid silent background backlog.

## 5. Background failures and releases

A verified correctness, durability, isolation or security violation blocks promotion of affected code immediately. Notify the responsible maintainer, create or update a tracked incident with exact commit/seed/trace, classify severity, and stop affected merges until contained. For main regressions, normally revert promptly or land a verified fix; if isolation is demonstrated, unrelated development may proceed. Keep known-good artifacts available and prevent releases carrying the defect. Do not allow background results to disappear or be marked green by retries.

Distinguish test/harness failures and infrastructure failures from product assertions; investigate flaky checks with ownership and an expiry. Retry only classified transient infrastructure failures, record attempts, and fail closed on missing required evidence. Critical invariant regressions are not waivable for speed. Performance regressions follow the predeclared workload limits and explicit decision process in [qualification](../planning/qualification.md).

The release gate consumes exact-candidate qualification evidence, not just main's PR status. Record pass, fail, running, missing, and stale states; a changed candidate invalidates affected evidence, with reuse only where exact identities and scope meet the qualification contract. Do not promote a supported capability until its public path, backfill, live changes, failure/restart and applicable qualification are complete. Keep all existing G0–G6 exit criteria and independent safety review.

## 6. Issue-to-PR discipline

Use the issue contract and acceptance fields in the [implementation plan](../planning/implementation-plan.md). Split changes into small independently safe steps; avoid speculative scaffolding and large unrelated refactors. Include tests, applicable invariant ledger updates, migration/format changes, capability status and reproduction commands in the PR. Review high-risk changes with the appropriate independent contract owners; optimize review latency through focused diffs and clear evidence rather than removing review.

The [agent operating model](agent-development.md) governs the primary workforce. Maintain concise root [AGENTS.md](../../AGENTS.md), scoped instructions only where useful, stable module ownership, discoverable bootstrap/test/replay commands and actionable failure output. Use the repository's lightweight issue and PR templates. Tests are executable contracts, not a substitute for independent oracles or review. Never weaken tests to make an implementation pass.

## 7. Complexity and architectural integrity

Choose the simplest design satisfying the established contract and measured resource needs. Extra abstraction, dependency, configuration, alternate execution path or general framework must earn its lifetime verification and maintenance cost. Prefer composition, explicit state transitions, mature dependencies where justified, small cohesive modules, narrow APIs and one canonical production behavior; preserve independent reference implementations for verification. Delete failed prototypes, expired feature flags and obsolete paths rather than accumulating them. Document experiment owner, hypothesis, timebox/compute budget, exit criterion and cleanup decision.

Enforce the dependency direction in [DESIGN.md](../../DESIGN.md) with an executable crate-graph rule in G0, including transitive/prohibited dependencies and cycle checks; extend to important module/visibility boundaries as warranted. Add negative controls for violations. An exception is scoped, justified, recorded and reviewed; do not add a general dependency to make a local test convenient. Track meaningful dependency growth, duplicate paths, review/rework time and build graph cost as signals, not arbitrary line-count or crate-count quotas.

Keep main integrated through narrow vertical slices; limit concurrent work and retire unused scaffolding. Simplify within the scope of a change when safe; propose larger simplifications as separate issues with regression evidence. The project values useful behavior and sustainable complexity, not generated code volume.

## 8. Compatibility and sources of truth

Version durable formats from the first persistent prototype; identify disposable experimental formats and isolated datasets explicitly. No compatibility commitment is implied by experimental internals. Never silently interpret an incompatible format or erase durable data; reject unknown/incompatible versions and provide an explicit reset/export/migration path appropriate to the declared profile. Preview releases name their supported API/format versions, upgrade/downgrade and migration limits. Supported production releases enforce their declared compatibility, rollback window, data retention and upgrade promises with tests. Changes to supported contracts require a reviewed ADR/migration plan; this policy does not weaken existing G2–G6 durability or recovery gates.

| Authority | Responsibility |
| --- | --- |
| Detailed design contracts and ADRs | Intended semantics, invariants, alternatives and approved decisions |
| GitHub issues and PRs | Work scope, dependencies, acceptance and actual change/review history |
| Executable tests/models and verification ledger | Reproducible observations and bounded evidence of behavior |
| Machine-readable capability registry | Supported entry points, combinations, guarantees, status and evidence; generate user-facing capability docs and conformance cases where practical |
| Qualification bundles and release record | Exact commit/binary, environments, measured limits, provenance and approved public support envelope |

Tests cannot silently redefine a contract, and documentation cannot promote an unverified feature. If sources disagree, stop affected promotion, reconcile them in one reviewed change, and retain the counterexample. A capability begins Planned, may be Implemented (internal/public path exists), Verified (applicable correctness/recovery checks), Qualified (required production-profile evidence), and Supported (explicit approved release commitment). Stages are scoped to specific versions, combinations and deployment profiles; regressions can revoke qualification. Start a minimal schema during G0/G1, not a catalog service. See [SQL and APIs](../reference/sql-and-apis.md).

## 9. Continuous performance engineering and diagnosability

Establish representative microbenchmarks with independent semantic checks for kernel CPU, allocations, codecs, indexes and I/O; run affected ones on performance-sensitive changes when required, with larger regression benchmarks in background. Freeze comparable workload, revision, correctness/retention/durability guarantees and hardware; quantify noise and use repetitions before declaring significant regressions. Track throughput, freshness, tail latency, state/memory and write amplification, object requests, CPU and network across commits. Set resource/performance budgets from G0 measurements, not arbitrary targets; protect named baselines with predeclared limits, bisect suspect revisions, and use the full [qualification protocol](../planning/qualification.md) for release and cost claims.

Diagnosability is part of done for significant operations. Produce structured errors and traces with stable operation/contract IDs, logical cut, attempt/generation, blocking dependency and resource/timing context where applicable; expose actionable test/diagnostic commands. Redact credentials, tenant data and sensitive payloads. Test error/metric behavior and keep the overhead bounded. Instrument from the first vertical slice; agents and operators should be able to explain failed tests, stalled progress and resource regressions from retained evidence rather than guess.
