# Correctness, resilience, and performance qualification

**Status:** Proposed test and evidence plan, 2026-11-25. No Rockstream 2 engine, formal model, benchmark, or production gate has run. This documentation PR can be checked for internal consistency and links; it cannot establish the runtime claims below.

## 1. What constitutes evidence

Qualification is a claim tied to a reproducible artifact: source commit, build digest, dependency lockfile, configuration, exact workload, environment, fault schedule, raw observations, independently checked outputs, and pass/fail limits fixed before the run. Test names, checked boxes, prose signoff, or benchmark fixture numbers alone are insufficient.

Retain the discipline of the original Rockstream's [independent scale program](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/benchmarks/scale-qualification/README.md): synthetic fixtures must be rejected as release evidence, failures must actually fire, and costs cover the whole deployment. Reuse its checker approach after adapting the new domain/source-cut and capability contracts; do not blindly reuse a format whose epoch assumptions differ.

## 2. Verification layers

Use the [testing and verification architecture](../design/testing-and-verification.md) for the test pyramid, deterministic execution boundaries and invariant-to-evidence ledger. The following table specifies domain obligations, not an instruction to execute the entire matrix on each PR.

| Layer | Method | Independent authority / principal failure detected |
| --- | --- | --- |
| Row, weight and numeric kernel | Property tests and selected machine proofs | Canonical equality, overflow, cancellation, multiplicity and codec laws |
| Incremental algebra | Pure batch vs incremental interpreter, rewrite counterexamples | Incorrect differentiation, initialization, NULL, empty-input and delete behavior |
| SQL frontend | PostgreSQL comparison for the declared compatible subset; explicit reference rules elsewhere | Parser/binder/cast/return-type and semantic normalization mismatch |
| Physical kernels | Same generated change stream through reference and optimized plans | Factorization preconditions, ordering, spill, skew and specialized fast-path defects |
| Storage adapter and logical MVCC | Actual SlateDB restart, reconstruction, pin, compaction, corruption and failover conformance | Physical snapshots mistaken for logical history, transient snapshots mistaken for durable versions, hidden staged writes, abandoned-parent reuse |
| Object metadata, publication and GC | Small state-machine models plus deterministic schedules against production logic | Torn visibility, missing participants, stale fencing, unsafe reclamation, ambiguous conditional writes and root contention |
| Runtime | Seeded simulation plus real process/network failures | Work accounting, duplicate/delayed packets, attempt mixing, resource deadlocks |
| Connectors/protocols | Real PostgreSQL/Kafka and client drivers, exact wire transcripts | Snapshot handoff, preimage loss, offsets, subscriptions, unknown external effects |
| Operations | Full suspension/activation, empty-environment restore, upgrades, AZ failures and long soak | Hidden always-on authority, missing wake triggers, incomplete backups, old-incarnation writers, compatibility and slow debt growth |
| Economics | Qualified sustained workload and independent cost accounting | Fast incorrect output, unbounded backlog, omitted supporting resources |

The batch reference must not lower through the same incremental rewrite or reuse the same state-transition implementation under test. PostgreSQL is not an oracle for intentional dialect differences unless the query is normalized to the agreed profile. Model checking and selected Verus proofs cover their stated abstractions; they do not prove the entire database. The [FoundationDB paper](https://www.foundationdb.org/files/fdb-paper.pdf) motivates deterministic simulation as an engineering technique, not a transferable correctness certificate.

## 3. Semantic qualification

For every completed cut, reconstruct the exact source relations and evaluate the view independently. Compare full typed multisets with weights; compare ordering only where the SQL contract defines it. A row count or one checksum is not sufficient. For large outputs, canonical partitioned digests can screen for differences, but the archived verifier must support exact canonical stream comparison and produce the first divergent row/weight on failure. No probabilistic digest-only result is promoted as an exact oracle proof.

Test matrices include duplicate rows, zero/negative deltas, repeated updates to one key, simultaneous changes to both join sides, multi-table transactions, empty aggregates, all-NULL groups, unmatched outer/anti transitions, distinct threshold crossings, order ties, delete-driven Top-K refill, cast errors and decimal boundary cases. An empty input must produce `Q(empty)`, including COUNT's initial zero row where applicable.

Weights and exact aggregates use an explicit wide/exact intermediate policy so delta consolidation order cannot determine success when the declared final result is representable. Errors must be deterministic under the declared rule. Floating aggregation tests use the chosen approximate contract, including error bounds and NaN handling; they cannot be counted as exact integer/decimal evidence.

Property generators create valid and invalid normalized transaction histories. Valid histories respect primary-key and source-retraction constraints. Invalid cases assert exact failure and unchanged published state. Shrink failures while preserving the semantic condition that made them meaningful, such as one transaction changing both join inputs. Fix the seed and archive the minimized reproducer.

For each optimizer rule record: input pattern, side conditions, type/NULL/multiplicity assumptions, proof sketch or proof link, counterexample when a side condition is removed, and public-path regression. Online swaps compare old/new results at the same source cut before activation and verify exactly one emitted downstream transition.

### Logical MVCC and independent schedules

Qualify the logical contract independently of SlateDB's physical versions. In one domain, state at exclusive cut `C` contains epochs `e < C`. Track computed upper `Cc`, published durable upper `Cp <= Cc`, and earliest reconstructible cut `S`. A declared continuous coverage interval `[S, Cp]` promises the base at `S`, the endpoint `Cp`, and every supported cut between them. A gap is an explicit capability/coverage limit, never inferred away because a later checkpoint exists.

Test two maintained relations over a compatible source history with different physical checkpoint schedules: one retains checkpoints at cuts 40 and 80, the other at 30 and 70. With sufficient protected logical history, a read at cut 60 must reconstruct exact results for both without requiring a physical checkpoint at 60. If the required history is absent, the read must report the missing coverage, choose another permitted common cut, or perform an explicitly qualified reconstruction; it must not mix individually latest versions. Domain-local epoch numbers alone do not establish compatible source lineage.

Include nonlinear intermediate states: a DISTINCT input can become present and then absent while its net interval delta is zero. A history-preserving implementation must retain the output changes needed to answer cuts between those transitions. Consolidating the whole interval into a zero delta is valid for its endpoint but cannot justify intermediate snapshot promises. Test analogous aggregate, outer/anti, Top-K and temporal cases as those capabilities graduate. Separate the exact-read contract from any recovery recipe that can only reconstruct the latest endpoint.

Run fast and scheduled/on-demand consumers of the same arrangement under different freshness and history budgets in separate result domains. Each domain has one atomic publication group; local G3 cases reuse a common input timeline, while G4 adds general imports/distributed groups. Verify independent publication, durable consumer cursors, pin/GC arbitration, explicit expiry/resnapshot, bounded retained state and the permitted decision to duplicate state for isolation. Record base/delta bytes, compaction cost, reconstruction latency and catch-up cost; MVCC must not hide an unbounded slow-consumer obligation.

## 4. Protocol models and invariants

| Model | State to model | Safety assertions | Liveness assumptions |
| --- | --- | --- | --- |
| M1 input admission | Input head, client windows, source positions, schema/owner, accepted state | One logical effect; no ack before durability; stale ingestion owner rejected | Durable store and sequencer eventually available |
| M2 publication and metadata | Authoritative root revision, immutable metadata tree, head, intent, complete participants, parent, plan, generation, attempts, operation identity | Publication aspects of INV-02–05; head/ownership/catalog conditions checked in one atomic transition; no missing receipt or foreign attempt; unique committed outcome after ambiguous CAS | Required participants and qualified object-store operations eventually responsive; partition-result semantics established independently |
| M3 pin/GC | Live roots, input head, staging namespaces, pin revocation, read-completion validation, tombstones | INV-06/09; accepted input preserved; no resurrection; late upload protected; no successful result after pin revocation without a new valid pin | Reclaimable namespaces eventually close and deletion succeeds |
| M4 ownership/exchange | Assignment, capabilities, sequence/attempt, inflight messages | No stale publication; no progress beyond outstanding work | Fair scheduling, finite failures, bounded retry |
| M5 lifecycle | Backfill base, replay floor, active generation, cancellation | No snapshot/tail gap; one activation; no retained-consumer state loss | Adequate history and catch-up capacity |
| M6 restore/sink | Incarnations, backup cut, producer identity, destination marker | Old workers fenced; tokens invalidated; no unjustified external exactly-once claim | Destination exposes sufficient committed state to resolve ambiguity |
| M7 logical MVCC | Computed/published uppers, since/base cut, timestamped deltas, supported coverage, source-cut maps and consumer pins | No read beyond durable upper; every promised cut reconstructs exactly; compaction preserves valid pins and nonlinear intermediate results; no mixed lineage | Retained inputs/state and adequate reconstruction capacity available |
| M8 suspension/activation | Lifecycle state, admission/drain boundary, accepted head, obligations, owner generations, active/old processes and wake attempts | No lost durable work, hidden local authority, stale publication or double ownership after concurrent activation; sleep does not erase delivery/timer/retention obligations | An external caller/operator/platform eventually launches eligible work; required source history and durable storage remain available |

FizzBee or another reviewed model checker can implement these finite models; selected proof kernels may use Verus where the production code and model are demonstrably related. M2 does not prove query equivalence (INV-01) unless its state is extended with actual relational semantics; the composition argument explicitly depends on the separately verified kernel and complete source-cut contract. Model files must record bounds and explored state count, and retain known counterexamples as negative regressions. A model whose transitions omit a production write, retry or lifetime boundary must be revised before its result is cited.

## 5. Persistence and failure matrix

Inject a kill, delayed response, duplicate request and storage error before and after each of: input segment completion; accepted-input metadata CAS; immutable metadata-node upload; authoritative-root CAS; state write completion; durable checkpoint creation; preparation sealing; publication CAS; client acknowledgement; pin renewal; compaction root replacement; GC tombstone; physical deletion; suspension intent/drain completion; activation ownership acquisition; backup completion; source offset acknowledgement; and destination transaction commit.

| Scenario | Required observable result |
| --- | --- |
| Durable input with zero views, then GC and full restart | Accepted source relation and dedup result reconstruct exactly |
| Lost input/publication response | Retry/status resolves the original commit; no extra logical effects |
| Conditional root write succeeds but response is lost, followed by another root update | Operation identity and durable outcome resolve the original result even when the root has advanced; no blind replay or assumed failure |
| Two metadata transitions race on publication, ownership and catalog conditions | One validated transition wins; the loser reloads/revalidates against the new root; no torn multi-object update |
| Aborted staged SlateDB write followed by retry | Retry starts from exact published parent and produces one interval's effects |
| Stale owner returns after new owner publishes | Old data uploads may leak temporarily; no published head or bytes are overwritten |
| Delayed packet from an abandoned attempt | Rejected despite same epoch, owner and plan |
| Missing or duplicated partition receipt | Publication rejected; last good version readable |
| Ownership changes during preparation or pin renewal is uncertain | Fencing rejects unauthorized publication; no successful expired-pin completion; a clock timeout alone does not grant publication authority |
| Reader pins while GC retires a version | One transaction wins; no successful pin to reclaimed data |
| Reader pauses across authoritative pin revocation and then completes | Final metadata validation rejects the expired/revoked snapshot; wall-clock assumptions cannot permit successful completion or authorize GC |
| Old-generation upload finishes after GC marking | Open intent namespace protects it or abandoned attempt cannot publish it |
| Source WAL/topic history lost | Explicit rebuild requirement; no guessed offset advance |
| Snapshot/CDC overlap and rebalance | Exact normalized source transcript with no missing/duplicate logical rows |
| Required object-store reads/conditional writes unavailable or heavily contended | Bounded retries/backpressure, no falsely fresh or durable acknowledgement; optional consensus profile additionally tests quorum loss |
| One tenant exceeds state/read/history budget | Controlled failure/throttle within its scope; other admitted tenant progresses |
| Backup/restore with old fleet still scheduled | Old credentials/namespaces fenced before serving new incarnation |
| Kafka commit succeeds but acknowledgement is lost | Resolve marker or deliver under documented duplicate-allowed contract; no unfounded guarantee |
| All Rockstream cloud processes stop and every local cache/disk is lost | New processes reconstruct metadata, accepted input, dedupe state, retained views and obligations entirely from protected object state |
| Two activations race while a paused old process resumes | One authoritative ownership generation per scope; old/losing actors cannot publish, acknowledge new work or erase retention roots |
| Dormant CDC source loses its required history or wake trigger fails | Declared failure/deadline or resnapshot path; no silently skipped history or claimed freshness during sleep |
| Timer becomes due or sink commit becomes ambiguous during drain | Retained obligation blocks full suspension or is durably scheduled/reconciled under an explicit activation contract |
| MVCC compaction crosses a slow reader/consumer cut | Valid pin preserves exact reconstruction; expired consumers receive the declared error/reset, never an incorrect newer result |

Test both predictable faults and independent randomized interleavings. Record the exact event at which a fault fired; starting a fault injector process does not establish that a fault occurred. Deliberately pause a process across an ownership/topology change and a complete suspend/resume cycle; a graceful restart is not a zombie-writer test. Run backend conformance against each real supported object store, including strong reads, conditional creates/updates, conflict responses, ambiguous outcomes and immutable-object reachability. A generic “S3 compatible” label or local test double is insufficient evidence.

## 6. Required negative controls

An independent qualification checker must reject deliberately corrupted evidence or behavior. Include at least:

1. One dropped row and one duplicated row, including equal total row count with a different row.
2. The missing `ΔL ⋈ ΔR` join term and wrong COUNT-empty initialization.
3. One stale-owner or wrong-attempt state reference.
4. A publication missing one required partition, with otherwise plausible metrics.
5. A mixed source-cut read where each component is individually committed.
6. A premature durable acknowledgement or GC deletion of unpublished accepted input.
7. An expired idempotency sequence readmitted as fresh work.
8. A failed subscription gap hidden by a cursor jump.
9. A fault plan whose fault never actually fired.
10. A synthetic fixture relabeled as a benchmark run or a binary digest that does not match the run.
11. A run with accumulating backlog/compaction debt or omitted error/timeout samples.
12. A cost bundle omitting metadata, serving, object requests or cross-zone costs.
13. A read at a computed-but-unpublished cut or an intermediate cut erased by interval-wide consolidation.
14. An advertised full-suspension run that leaves a Rockstream coordinator running or recovers authoritative state from an unreported local disk.
15. A competing activation or metadata retry that ignores a changed ownership/root revision.
16. A sleep-cost comparison that omits retained source/history, activation or cold catch-up cost, or relaxes the compared freshness promise.

Checker logic consumes captured input/output, source cuts, process identities, backend evidence and traces; it must not accept the implementation's own `correct=true` or `fault_injected=true` fields without verification. Corrupt one field at a time to prove the evidence gate notices it.

## 7. Workload portfolio

| ID | Workload | What it distinguishes |
| --- | --- | --- |
| W1 | Transactional customer/orders join-aggregate, mixed updates and deletes | Base IVM, cross-term, group movement, atomic multi-table input |
| W2 | 100 and 1,000 overlapping views with heterogeneous readers | Sharing benefit, graph lifecycle, history/metadata costs, slow-consumer isolation |
| W3 | Incremental TPC-H/TPC-DS-derived supported query subsets | Join/aggregate breadth with explicitly declared modifications and update generator |
| W4 | Nexmark-derived streams and late corrections | Bursts, windows and event-time policies for promoted capabilities |
| W5 | Live PostgreSQL CDC with large transactions/schema events | Snapshot/WAL handoff, source lag, accepted vs published state |
| W6 | Kafka source plus subscription/sink consumers | Rebalance, retention, ambiguous commit and consumer speed mismatch |
| W7 | Uniform versus severe hot-key skew and high output amplification | Limits of partitioning, factorization, admission and fairness |
| W8 | State at 1×, 4× and 10× aggregate worker memory; cold/warm cache | Spill, object requests, restoration and compaction cost |
| W9 | Two independent domains and a dependent imported-view graph | Scoped progress, compatible cuts and dependency bottlenecks |
| W10 | Read-heavy serving mixed with maintenance and backfill | Separation of serving/maintenance and shared storage contention |
| W11 | Recursive graph inserts/deletes and temporal expiry | Only after specific G5 promotion; cycles, alternate paths and clock replay |
| W12 | 72-hour mixed load with worker/AZ faults, scaling and backup | Bounded long-term debt, leak detection and operational behavior |
| W13 | Bursty and long-idle workloads, full suspension, concurrent wake and cold reads | Zero-process eligibility, source/timer/sink obligations, activation and catch-up cost, stale-owner rejection |
| W14 | Shared relations with disjoint checkpoint cadences and fast/slow consumers | Logical MVCC coverage, nonlinear intermediate states, common-cut reconstruction, history amplification and pin quotas |

These are workload families, not official benchmark compliance claims. Name modified SQL, skipped queries, changed scale factors, and synthetic change generators. Reject a comparison that gives one implementation weaker numeric or durability semantics, smaller retention, or a different output query.

## 8. Benchmark protocol

Freeze versions and profiles for both systems; archive build digests and deployment manifests. Restore identical logical input snapshots, then replay identical normalized complete transaction streams. Where source adapters differ, measure both the isolated engine and end-to-end connector path rather than conflating them. Use the new and original engines only where the common supported SQL is truly equivalent.

Sweep offered load to find **qualified throughput `Qn`**, the maximum sustained input rate on `n` fixed-class workers meeting correctness, durability, freshness/read SLOs and bounded queues, state and compaction debt. Count source logical row mutations before normalization: one UPDATE is one change, not two weighted records. Exclude replay, duplicate delivery and initial snapshot construction from the live-change denominator, while reporting their work/cost separately; publish transaction rate too. Report rejected and timed-out requests, offered load, achieved durable inputs and verified published throughput separately. Drain accepted-but-unpublished input at the end with drain time and cost included, or exclude it from completed work and fail any sustained-capacity claim whose backlog grows. Include predeclared warmup, at least three independent measured repetitions per main point, confidence/variance reporting, and the long soak; short diagnostics do not certify sustained capacity.

Run 1/2/4/8/16 workers for the first scale claim; expand to 32/64 only after the prior gate. For fixed query/data profiles, scaling efficiency is `Qn/(n*Q1)`. Separately report weak scaling with proportional state/input; do not mix the two. Source, serving or coordinator bottlenecks are part of the deployment result and must be shown, not subtracted after the run.

Freshness measurements separate source commit to durable input, durable input to publication, and publication to observed read/delivery. For source timestamps, document clock synchronization and uncertainty. Emit a sample for every promised boundary and account for timeouts/censored requests; do not derive P99 only from successes. Server request latency includes queueing, snapshot selection, required pin acquisition/renewal and completion revalidation, storage access and serialization. Report client round-trip latency separately and label warm/cold data, output bytes and network location. A kernel-only microbenchmark cannot establish the end-to-end or server request target; mandatory object-root work must not be subtracted to meet the aspirational 5 ms goal.

Cost uses recorded cloud prices/configuration on the experiment date or an explicitly hypothetical rate card, plus measured resource consumption. Include ingestion/source test infrastructure, metadata operations and any optional consensus replicas, maintenance, serving, compaction, backup, retained history, activation infrastructure, object requests, transfer and headroom. Archive both quantities and prices so cost can be recomputed. Report cost per million unique correct durable changes at fixed freshness, not raw rows processed including replays.

For suspension workloads, report active and dormant durations, actual live Rockstream process count, remaining durable/source costs, wake mechanism and its failure policy, first-correct-read latency, time to the required freshness cut and full cold catch-up cost. Compare against an always-on baseline at the same supported workload and obligations. A continuous CDC profile with a surviving ingest process may demonstrate partial pool suspension, but cannot be labeled full Rockstream scale-to-zero.

## 9. Evidence bundle schema

The implementation will define and version a machine-readable bundle with at least:

| Section | Required fields |
| --- | --- |
| Identity | Engine/repo commit, binary hash, dependencies, config hash, checker version, measured-vs-fixture provenance |
| Environment | Cloud/region/zone topology, instance/storage/network types, all Rockstream process IDs/roles, failure profile, object-store conformance profile, source/sink versions, activation mechanism |
| Workload | Query and generator hashes, type/semantics profile, random seed, input snapshot and transaction manifest, source cuts, amplification, retention |
| Time | Warmup, steady-state interval, repetitions, clocks, fault and recovery timeline |
| Observations | Raw input/output transcripts or complete immutable references, logical cuts/coverage and metadata revisions, histograms, errors, backlog/state/debt, IO/network, resource samples, active/dormant process counts |
| Faults | Requested fault, verified target/event, expected invariant, observed recovery and loss/duplicate checks |
| Cost | Billable quantities, prices/date, included services, attribution, headroom and total |
| Verdict | Exact comparison results, negative controls, gate limits, unresolved defects, reviewer identity |

Protect evidence against accidental overwrite and include checksums. For agent-led development, record the issue/PR, commit, implementing and independently reviewing identities, approved risk tier, commands, actual observations and applicable authorization. CI-produced artifacts and independent checking, not agent self-report, establish the verdict; do not store secrets or unnecessary private prompt histories. A provenance hash supports reproducibility; it does not replace an independent checker or trustworthy observation. Verification tooling should be usable outside the tested cluster.

## 10. Release gates and regression policy

The [development workflow](../design/development-workflow.md) defines the fast required PR baseline, risk-selected extended pre-merge checks, post-merge, continuous, nightly, weekly and release lanes. The ordinary required CI objective is median under 5 minutes and P95 under 10 minutes including queueing. These objectives are unmeasured and cannot waive a safety obligation. Fast PR checks cover changed contracts, a bounded deterministic seed corpus and focused real-dependency smoke tests. High-risk changes require applicable model, fault, compatibility or other safety evidence before merge. Background lanes broaden randomized exploration, real adapter tests, mutation, fuzzing, scale and soaks; they do not routinely block PRs. Pre-release and capability promotion run the declared full applicable workload/fault/upgrade/restore matrix. Exact durations, counts and seed budgets are selected from measured coverage/runtime, not arbitrary large counts intended to look rigorous.

A verified background correctness failure blocks affected promotion and triggers immediate triage, containment and a tracked fix or revert. Archive seeds, traces, independent observations and minimized regression cases. Keep passing, failing, missing, stale and incomplete evidence distinct; a canceled job or retry of a product assertion cannot yield green. Required checks validate the actual integration revision. Merging an unsupported, inert capability is not promotion; no known violation of an existing supported contract may merge.

Performance engineering starts with targeted kernel microbenchmarks and background commit-to-commit regression baselines; use fixed comparable workloads, repetitions/noise estimates and predeclared thresholds. A microbenchmark is not a release or economic qualification. Record significant regressions and bisect/triage them as tracked work.

Any invariant violation blocks promotion irrespective of benchmark speed. Performance gates use the predeclared [requirements](requirements.md); narrow the published support envelope when an improvement does not generalize. A regression exception requires an updated workload promise, explanation, measured tradeoff and explicit maintainer decision in the release record. Preserve counterexamples and add a meaningful regression case before closing a correctness defect.

An authorized human maintainer approves the release after independent review of the exact candidate evidence; an implementation agent cannot authorize or sign its own release. Review gate results at the exact release commit and binary. A passing previous head is not evidence for untested subsequent changes. This documentation package's validation record must remain separate from all future executable qualification results.
