# Testing and verification architecture

**Status:** Proposed, 2026-11-25. This is the engineering contract for a future implementation, not evidence of an executed test suite. [Qualification](../planning/qualification.md) defines the domain-specific cases, independent oracles, proof obligations and release evidence. [Development workflow](development-workflow.md) defines when checks execute.

## 1. Quality through testability

Rockstream must be extremely well tested. Correctness, testability, simplicity, runtime performance and development velocity are architectural concerns; correctness is non-negotiable. Optimize for confidence per second of developer waiting time, not minimum total testing compute. Prefer a smaller, well-verified supported surface over more unqualified features.

Test every behavior at the lowest layer that can expose the failure faithfully. Keep broad cross-layer tests only where they catch failures smaller tests cannot. Do not prescribe a fixed percentage of test cases: generated histories and simulation seeds make counts misleading. Measure invariant and risk coverage, feedback cost, escaped defects, and the ability to detect deliberately introduced errors. Line/branch coverage locates blind spots, not evidence of correctness.

## 2. The test pyramid

| Layer | Scope | Representative Rockstream cases |
| --- | --- | --- |
| Foundation: unit and property-based tests (largest) | Pure, in-process, no external I/O; many generated inputs | Z-set arithmetic, weights, canonical codecs, time/epoch bounds, SQL NULL and bag semantics, optimizer rules and exact numeric errors |
| Component and deterministic simulation (extensive) | Production logic driven through contract interfaces; controlled storage, clock, scheduler and network | Incremental versus independent batch results at each cut, publication and GC races, exact-parent retry, ownership, independent consumer progress, compaction and crash/restart schedules |
| Integration (focused) | Actual dependencies and public interfaces; minimal real instances | SlateDB durable checkpoints/restart, local filesystem sync, pgwire and client libraries, PostgreSQL CDC, Kafka, actual supported object-store behavior |
| End-to-end (small, representative portfolio) | Entire binary and user-visible deployment or lifecycle | Transaction to maintained view to pinned read; full loss of cloud caches and activation; multi-process failover, upgrade, backup/restore and migration |

A public SQL regression can be an inexpensive in-process integration test; the pyramid describes scope and dependency cost, not directory names. Avoid mock-heavy interaction tests of implementation detail and redundant permutations at the top. Use a small essential cross-layer smoke corpus on every code PR; add focused boundary tests when a contract changes. Run expanded integration, deployment and scale matrices outside the routine merge path, without weakening release qualification.

Formal models, differential testing, fuzzing, mutation testing, concurrency checking, security analysis and benchmarks complement the pyramid rather than form additional mandatory layers on every PR. Use small bounded protocol models for high-risk transitions, deeper exploration asynchronously, and proofs where the model/production correspondence can be maintained. Retain model bounds, assumptions and negative controls. No method alone establishes complete correctness.

## 3. Production architecture for deterministic verification

- Keep semantic kernels and metadata transition functions pure where practical. Separate state transition decisions from side effects; keep one implementation of production semantics and one independently implemented oracle.
- Pass clocks, RNG, scheduling, transport and faultable storage/metadata operations through narrow interfaces at actual nondeterministic boundaries. Do not build a general-purpose storage abstraction beyond the required adapter contract. Keep dependencies directed so core tests neither link nor start an entire server unnecessarily.
- Run production protocol, operator, exchange and lifecycle logic under a controlled scheduler, virtual clock, seeded randomness and faultable I/O. Make events observable, including durable writes, acknowledgements, fault delivery and publication decisions. Avoid simulator-only correctness branches.
- Exercise crashes before and after durability/visibility boundaries, lost responses, reordered/delayed/duplicated messages, old actors, corrupted or unavailable state, and competing activation and GC. Validate exact results, invariants and declared liveness assumptions throughout, not just at final quiescence.
- Simulate the Rockstream boundary faithfully, not an assumed full reproduction of every third-party implementation. Native threads, filesystem fsync, Tokio or SlateDB internals and provider-specific failures that cannot be controlled remain explicit gaps; cover those with bounded concurrency checks or real-dependency/process tests. Qualify each actual backend against the same observable adapter contract; fix simulator assumptions when conformance fails.
- Reuse the original Rockstream harness, SQL fixtures and proven kernels selectively after mapping to the new contracts and reviewing provenance. A test count or historical passing result is not proof for new semantics.

The first runtime simulation uses the bounded acyclic/scalar-epoch kernel and one active interval per domain from [runtime and operations](runtime-and-operations.md). Run its actual operators, interval lifecycle, exchange/progress accounting and publication transitions under fault injection. Include interrupted writes, delayed and duplicated abandoned-attempt messages, worker loss, cancellation under backpressure and concurrent independent domains. A pure protocol model remains independently useful, but passing that model cannot stand in for exercising production transitions.

A deterministic run must record the source/build, test and harness versions, seed, input history, scheduler decisions or trace as needed, fault locations, configuration and observed divergence. Replay should run locally without credentials or cluster setup where possible. Shrink failing histories and schedules while preserving validity, causal order and the triggering failure; preserve the original artifact too. Real-infrastructure failures require captured transcripts, environment and replay instructions even when exact deterministic reproduction is not possible.

## 4. Independent verification

Map every invariant in [DESIGN.md](../../DESIGN.md), supported capability, protocol failure boundary and relevant security property to a living verification ledger. For each entry record the owning contract, test/model IDs, independent oracle or expected outcome, known coverage gaps and responsible owner. Add or revise entries in the same change as a new contract. A covered invariant means meaningful positive and negative evidence, not a claim of mathematical completeness.

For incremental computation, generate valid and invalid transaction histories, including changes on both sides of a join, duplicates, retractions, NULLs, empty relations and numeric boundaries. Compare exact typed multisets and source lineage against the independent batch evaluator at every tested published cut, including historical cuts after compaction and restart. Differential SQL comparisons use PostgreSQL only within the declared compatible semantics. Reference implementations must not share the optimized rewrite or state transitions under test. For persistence and concurrency, assert externally observable acknowledgements, reachable roots, fences, pins, exact-parent recovery and no invalid visibility. Verify fault delivery independently.

For each migrated capability, replay one captured normalized transaction history through original Rockstream, the new kernel and the independent batch oracle. Compare every selected complete cut, including intermediate history after compaction/recovery, and preserve all three results with source-cut mappings. This is not a majority vote: two engines may share an inherited bug, and a reference may not implement an intentional dialect difference. Classify old defects, new regressions, explicit semantic differences and oracle/checker defects; require an independently justified expected result and zero unexplained differences before promotion. A missing old-engine capability or unsupported oracle case is a recorded coverage gap, not a passing three-way comparison. Use independently specified expectations for intentional differences and keep them separate from compatible-subset results.

Illustrative allocation of regression evidence:

| Contract | Lowest effective evidence | Additional boundary evidence |
| --- | --- | --- |
| Join cross-term / COUNT(empty) | Generated kernel histories and independent batch evaluation; deliberately broken variant rejected | SQL binding, live retractions and persisted restart |
| Logical MVCC intermediate cuts | Component histories with zero net interval delta but nonzero intermediate output | Real SlateDB checkpoint/compaction/reopen at disjoint physical cadences |
| Publication, fencing, dedupe and GC | Bounded state-machine model and deterministic production-transition schedules | Real conditional writes, ambiguous responses, process kill and stale-owner return |
| Full suspension | Simulated obligation/drain/activation transitions | Stop all processes, discard cloud local files, resume against actual durable state |
| Connector transaction handoff | Normalization and cursor properties | Live PostgreSQL/Kafka, offsets, retention loss and reconnect |
| Shared-consumer isolation | Snapshot/replay/cutover model with live head/cursor comparison, complete historical/recovery coverage and retention handoff | Consumer advances after equality check, old attempt publishes during cutover, historical reads/recovery after isolation, crash/ambiguous activation, retained-tail cost and no duplicate downstream effect |

For agent-authored changes, independent review must inspect actual assertions, reference independence, skipped cases and CI artifacts, not the author's summary. Changes to expected outputs, models, test selection and checkers require risk-appropriate independent review and negative controls. Treat agent-generated tests as untrusted until verified; the [agent operating model](agent-development.md) prohibits self-certification.

## 5. Continuous correctness and regressions

Maintain a fast deterministic regression corpus containing representative fixed seeds, minimized historical bugs and critical protocol counterexamples. Every correctness fix adds a failing-before/passing-after regression at the lowest effective layer; where that is impossible document the reason, alternate evidence and an owner-approved follow-up before closing the defect. Do not inflate the fast suite with thousands of equivalent seeds: retain diversity and the counterexample while moving redundant exploration to background workers.

P0.1 establishes a donor-test inventory before porting algorithms: original revision/path, failure or semantic contract captured, independent expected result, new owning contract and test ID, disposition and known gaps. Port compatible SQL and pgwire regressions, deterministic failure cases, formal protocol counterexamples and security/authorization cases as soon as their boundary exists. Adapt models to the new root, attempt and retention protocols; preserve their old counterexamples without claiming the old proof covers new transitions. Keep the batch oracle independent of reused factorized joins or other optimized kernels. The [migration donor table](../planning/migration.md#donor-assets-and-regression-transfer) governs which assets are reused, adapted or replaced.

Continuously generate new seeds and SQL/transaction histories, explore fault interleavings, fuzz parsers/codecs/wire inputs, check larger models and run targeted mutation tests. Preserve exact commit provenance and independent evidence; prioritize novel coverage and high-risk invariants. Minimize, reproduce, fix and feed new counterexamples back into the fast corpus. Cross-check the oracle and checker with deliberate row drops/duplicates, wrong join terms, stale owners, premature acknowledgements and faults that never fired, as specified in [qualification](../planning/qualification.md).

Do not normalize flaky tests. A deterministic flake is a defect in the test, harness or product. Distinguish infrastructure errors from assertion failures; do not retry an assertion into green. Quarantine only with a tracked owner, expiry, alternate coverage and explicit review; a critical invariant cannot lose its required coverage. Use code/branch coverage and sampled mutation results to identify weak assertions, not quotas to game. Keep security, format compatibility, performance regressions and resource bounds visible alongside correctness.
