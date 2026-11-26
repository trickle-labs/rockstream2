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

For every migrated capability, run a three-way comparison of original Rockstream, the new kernel/public path available at that gate, and an independent batch authority over the same normalized transaction history and complete cuts. Use PostgreSQL for the declared compatible subset and a separately implemented evaluator elsewhere. Freeze the donor revision, fixture provenance, semantic adapters and known dialect exclusions. Investigate every disagreement against that authority; two engines agreeing is not sufficient if they inherited the same defect. A legacy defect becomes a minimized regression, not a new expected answer. A capability unavailable in one engine is an explicit comparison gap and cannot establish migration parity.

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
| M2 publication and metadata | Root revision, immutable tree, scoped predicates/read-write sets, bounded commit queues, batch membership, per-operation outcomes, head, intent, complete participants, parent, plan, generation and attempts | INV-02–05; every batched operation validated against the same revision with compatible effects; no missing receipt, foreign attempt or stale predicate; each ambiguous outcome resolves after later root changes; committer identity grants no authority | Required participants/store eventually responsive; fair bounded scheduling; partition semantics established independently |
| M3 pin/GC | Live roots, input head, staging namespaces, reader-group process incarnation/security scope, exact protected roots, local admission/drain, admitted readers, pin generations, release/revocation, completion validation and tombstones | INV-06/09; no admission racing past group closure or release while a valid local reader remains; stale incarnation cannot release/reuse a new grant; accepted input preserved; no resurrection; no successful completion linearizes after authoritative revocation without new valid protection | Reclaimable namespaces close; readers finish or are explicitly revoked; metadata validation/deletion eventually succeed |
| M4 ownership/exchange | Assignment, capabilities, sequence/attempt, inflight messages | No stale publication; no progress beyond outstanding work | Fair scheduling, finite failures, bounded retry |
| M5 lifecycle | Backfill base, replay floor, promised historical coverage and recovery closure, live consumer head/cursor, verified cut, active generation, retained old references and cancellation | No snapshot/tail gap; activation compares live head/cursor and fences old attempts; no cursor regression, repeated effects or lost retained/recovery state | Adequate history and catch-up capacity |
| M6 restore/sink | Incarnations, backup cut, producer identity, destination marker | Old workers fenced; tokens invalidated; no unjustified external exactly-once claim | Destination exposes sufficient committed state to resolve ambiguity |
| M7 logical MVCC | Computed/published uppers, since/base cut, timestamped deltas, supported coverage, source-cut maps and consumer pins | No read beyond durable upper; every promised cut reconstructs exactly; compaction preserves valid pins and nonlinear intermediate results; no mixed lineage | Retained inputs/state and adequate reconstruction capacity available |
| M8 suspension/activation | Lifecycle state, admission/drain boundary, accepted head, obligations, owner generations, active/old processes and wake attempts | No lost durable work, hidden local authority, stale publication or double ownership after concurrent activation; sleep does not erase delivery/timer/retention obligations | An external caller/operator/platform eventually launches eligible work; required source history and durable storage remain available |

**Quint** is the single primary protocol-specification and model-checking language (standardized in [RockStyle](../../ROCK_STYLE.md)); do not maintain parallel formal models in multiple tools. Selected proof kernels (e.g., Verus) are added only when a concrete verification gap justifies their maintenance cost. M2 does not prove query equivalence (INV-01) unless combined with the independently oracle-tested relational kernel. Model files record bounds, explored state count, and deliberate negative controls as regressions. A model whose transitions omit a production write, retry, or grace-window boundary must be updated before citing its result.

## 5. Persistence and failure matrix

Inject a kill, delayed response, duplicate request and storage error before and after each of: input segment completion; accepted-input metadata CAS; immutable metadata-node upload; authoritative-root CAS; state write completion; durable checkpoint creation; preparation sealing; publication CAS; client acknowledgement; pin renewal; compaction root replacement; GC tombstone; physical deletion; suspension intent/drain completion; activation ownership acquisition; backup completion; source offset acknowledgement; and destination transaction commit.

| Scenario | Required observable result |
| --- | --- |
| Durable input with zero views, then GC and full restart | Accepted source relation and dedup result reconstruct exactly |
| Lost input/publication response | Retry/status resolves the original commit; no extra logical effects |
| Conditional root write succeeds but response is lost, followed by another root update | Operation identity and durable outcome resolve the original result even when the root has advanced; no blind replay or assumed failure |
| Two metadata transitions race on publication, ownership and catalog conditions | One validated transition wins; the loser reloads/revalidates against the new root; no torn multi-object update |
| Commit batch contains overlapping tenant quotas or same-domain operations, duplicated identities, or one invalid member | Compositional intra-batch serialization applies valid operations sequentially against the working tree from `R` in one CAS (`R → R+1`); rejects invalid members deterministically without aborting unrelated valid operations; every acknowledged member has one durable outcome validated against the selected revision |
| Preferred committer crashes before or after CAS; response lost and root advances again | Replacement discovers authoritative state and each operation outcome; retries cause no duplicate effect; no leader-memory authority or lost acknowledged member |
| Priority traffic continuously saturates the commit scheduler | Fixed queue/admission/wait limits and fairness apply; control, pin and independent-domain work is not silently starved |
| Aborted staged SlateDB write followed by retry | Retry starts from exact published parent and produces one interval's effects |
| Multiple attempt namespaces share a checkpoint; stale writer uploads later | Published manifest selects only committed namespaces and exact parent lineage; abandoned bytes affect neither lookup nor recovery; native GC respects every protected reference |
| Stale owner returns after new owner publishes | Old data uploads may leak temporarily; no published head or bytes are overwritten |
| Delayed packet from an abandoned attempt | Rejected despite same epoch, owner and plan |
| Missing or duplicated partition receipt | Publication rejected; last good version readable |
| Ownership changes during preparation or pin renewal is uncertain | Fencing rejects unauthorized publication; no successful expired-pin completion; a clock timeout alone does not grant publication authority |
| Reader pins while GC retires a version | One transaction wins; no successful pin to reclaimed data |
| Serving node pauses past `lease_deadline` (or durable pin is revoked while paused) and then wakes to finish query | Short bounded reads fail the post-read `monotonic_now() < lease_deadline` check before flushing the response; durable pins and `strict-immediate-revocation` reads fail authoritative root validation; a paused node never returns stale or revoked data |
| Local reader admission races with group drain/release or a reused process identity | Atomic local admission gate and generation-fenced durable grant prevent unprotected admission; normal release waits for admitted readers; restarted process reacquires protection |
| Latest read sees a cached group cut while the authoritative head advances | Authoritative linearizable selection determines the eligible latest cut; a group miss obtains protection/reselects safely; a cache hit cannot silently downgrade semantics |
| Group revocation, authorization change or metadata outage occurs during a query/stream | Each completion validates the required grant generation and current authorization after consuming bytes; no successful completion based only on local refcounts, cached grants or TTLs |
| Old-generation upload finishes after GC marking | Open intent namespace protects it or abandoned attempt cannot publish it |
| Source WAL/topic history lost | Explicit rebuild requirement; no guessed offset advance |
| Snapshot/CDC overlap and rebalance | Exact normalized source transcript with no missing/duplicate logical rows |
| Required object-store reads/conditional writes unavailable or heavily contended | Bounded retries/backpressure, no falsely fresh or durable acknowledgement; optional consensus profile additionally tests quorum loss |
| Selected object operations fail slowly while others succeed; long tail, delayed completion and eventual recovery | Bound concurrent I/O, retry work, queues and retention pressure; isolate or throttle according to reserved capacity; never report false success; after healing, verify progress under declared liveness assumptions |
| Corrupt/truncated bytes or a different well-formed immutable object with a valid checksum returned for an expected reference | Validate expected content/identity and lineage against protected references; fail affected work closed, preserve last correct publication, recover only from independently validated protected state; do not infer object-store Byzantine tolerance or guaranteed repair |
| Skew, oversized Arrow buffers or amplification combined with compaction and slow reads | Enforce operator/pool memory and I/O limits, control capacity and declared spill/reject behavior; no truncated results, lost accepted input or unbounded debt |
| One tenant exceeds state/read/history budget | Controlled failure/throttle within its scope; other admitted tenant progresses |
| Backup/restore with old fleet still scheduled | Old credentials/namespaces fenced before serving new incarnation |
| Kafka commit succeeds but acknowledgement is lost | Resolve marker or deliver under documented duplicate-allowed contract; no unfounded guarantee |
| All Rockstream cloud processes stop and every local cache/disk is lost | New processes reconstruct metadata, accepted input, dedupe state, retained views and obligations entirely from protected object state |
| Two activations race while a paused old process resumes | One authoritative ownership generation per scope; old/losing actors cannot publish, acknowledge new work or erase retention roots |
| Dormant CDC source loses its required history or wake trigger fails | Declared failure/deadline or resnapshot path; no silently skipped history or claimed freshness during sleep |
| Timer becomes due or sink commit becomes ambiguous during drain | Retained obligation blocks full suspension or is durably scheduled/reconciled under an explicit activation contract |
| MVCC compaction crosses a slow reader/consumer cut | Valid pin preserves exact reconstruction; expired consumers receive the declared error/reset, never an incorrect newer result |
| Shared arrangement splits while a consumer reads, sleeps or resumes | Pinned snapshot and replay reach a verified complete cut; atomic cutover transfers obligations with no lost history or duplicate sink authority; old/rollback roots survive until safe release |
| Original consumer advances its publication head/cursor after equality at cut C but before isolation activation | Cutover CAS rejects the stale expected head/cursor; catch up and verify again, or quiesce/fence old attempts before verification; activation never regresses progress or re-emits an already authorized effect |
| Isolated consumer promises cuts older than its build snapshot; other consumers then drop and GC runs | Replacement certifies every promised cut and complete operator recovery/replay closure, or retains authoritative old-history references; historical queries and exact recovery still succeed after other consumers drop and GC runs; account for the retained tail until ordinary release is safe |

Test both predictable faults and randomized interleavings using the [verification and crash-testing contract](../design/testing-and-verification.md#practical-simulation-scope-and-real-backend-crash-testing). For fail-slow tests, freeze the affected operation class, delay distribution, duration, and healing condition; include real-backend/process tests where possible, and record fault delivery and the limits of injected approximations. Record the exact event at which a fault fired; starting a fault injector process does not establish that a fault occurred. Deliberately pause a process across an ownership/topology change and a complete suspend/resume cycle; a graceful restart is not a zombie-writer test. Run backend conformance against each real supported object store, including strong reads, conditional creates/updates, conflict responses, ambiguous outcomes, and immutable-object reachability. A generic “S3 compatible” label or local test double is insufficient evidence.

## 6. Required negative controls

The [verification contract](../design/testing-and-verification.md#practical-simulation-scope-and-real-backend-crash-testing) requires targeted negative controls: a requested fault is suppressed or delivered at the wrong boundary; an old attempt uploads or sends after generation replacement; a successful publication loses its response and is discovered after the head advances; a valid tiny queue or high-fanout workload creates pressure. Require the checker to reject missing/wrong fault delivery, stale effects and false progress, and preserve the first failure signature and minimized replay. Exercise controlled fault activation only in test environments and reject a production-service fault activation path. A synthetic fault is not evidence of real object-store or process behavior.


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
17. A batched commit that checks one member against a stale revision or cannot recover a member's outcome after the root advances.
18. A group pin released during local admission, a cached grant reused after revocation, or a cached head presented as strict latest.
19. An abandoned namespace accepted by committed lookup or used as the next recovery parent.
20. A sharing comparison omitting slow-consumer history or split/rebuild/rollback cost, or a split that drops a still-promised cut.
21. An isolation activation that accepts stale equality evidence after the live head/cursor advances, regresses the cursor or emits a previously authorized effect again.
22. A split certified only by endpoint equality that releases older promised history or operator recovery dependencies, including after the other consumers drop and GC runs; a cost result hiding the necessary retained old-history tail.
23. Separate component runs with different configurations, loads or guarantees presented as a successful joint G0 run, or a selected combination promoted despite missing combined-path evidence.
24. An optimization justified by observed uniqueness rather than an enforced semantic condition, or an estimated saving presented as a measured result while omitting build overlap and still-protected old state.
25. A safety-critical internal check disabled in release settings, or an invariant violation permitted to acknowledge/publish invalid work.
26. A different validly encoded object substituted at a protected reference, with a checksum valid for the substituted payload.
27. A physically rebatched or rescheduled run silently changing a logical transaction/cut, or a shared-versus-isolated comparison ignoring a promised historical cut.
28. A liveness run that declares recovery despite an undrained admitted obligation after its predeclared healthy-phase bound, or a simulated performance diagnostic represented as a measured backend SLO.
29. A resource check omitting temporary/shared-buffer bytes, outstanding retry work or an exhausted control reserve.

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

W1-G in [implementation start](implementation-start.md) is the fixed, synthetic, tiny golden fixture within W1. Independently verify exact outputs at each of its five cuts; extend it through public SQL, crash recovery, sharing and distribution. It is not a measured benchmark or design-partner result. Retain the broad portfolio and generated histories.

These are workload families, not official benchmark compliance claims. Name modified SQL, skipped queries, changed scale factors, and synthetic change generators. Reject a comparison that gives one implementation weaker numeric or durability semantics, smaller retention, or a different output query.

## 8. Benchmark protocol

Freeze versions and profiles for both systems; archive build digests and deployment manifests. Restore identical logical input snapshots, then replay identical normalized complete transaction streams. Where source adapters differ, measure both the isolated engine and end-to-end connector path rather than conflating them. Use the new and original engines only where the common supported SQL is truly equivalent.

Sweep offered load to find **qualified throughput `Qn`**, the maximum sustained input rate on `n` fixed-class workers meeting correctness, durability, freshness/read SLOs and bounded queues, state and compaction debt. Count source logical row mutations before normalization: one UPDATE is one change, not two weighted records. Exclude replay, duplicate delivery and initial snapshot construction from the live-change denominator, while reporting their work/cost separately; publish transaction rate too. Report rejected and timed-out requests, offered load, achieved durable inputs and verified published throughput separately. Drain accepted-but-unpublished input at the end with drain time and cost included, or exclude it from completed work and fail any sustained-capacity claim whose backlog grows. Include predeclared warmup, at least three independent measured repetitions per main point, confidence/variance reporting, and the long soak; short diagnostics do not certify sustained capacity.

Run 1/2/4/8/16 workers for the first scale claim; expand to 32/64 only after the prior gate. For fixed query/data profiles, scaling efficiency is `Qn/(n*Q1)`. Separately report weak scaling with proportional state/input; do not mix the two. Source, serving or coordinator bottlenecks are part of the deployment result and must be shown, not subtracted after the run.

Freshness measurements separate source commit to durable input, durable input to publication, and publication to observed read/delivery. For source timestamps, document clock synchronization and uncertainty. Emit a sample for every promised boundary and account for timeouts/censored requests; do not derive P99 only from successes. Server request latency includes queueing, snapshot selection, required pin acquisition/renewal and completion revalidation, storage access and serialization. Report client round-trip latency separately and label warm/cold data, output bytes and network location. A kernel-only microbenchmark cannot establish the end-to-end or server request target; mandatory object-root work must not be subtracted to meet the aspirational 5 ms goal.

Cost uses recorded cloud prices/configuration on the experiment date or an explicitly hypothetical rate card, plus measured resource consumption. Include ingestion/source test infrastructure, metadata operations and any optional consensus replicas, maintenance, serving, compaction, backup, retained history, activation infrastructure, object requests, transfer and headroom. Archive both quantities and prices so cost can be recomputed. Report cost per million unique correct durable changes at fixed freshness, not raw rows processed including replays.

For suspension workloads, report active and dormant durations, actual live Rockstream process count, remaining durable/source costs, wake mechanism and its failure policy, first-correct-read latency, time to the required freshness cut and full cold catch-up cost. Compare against an always-on baseline at the same supported workload and obligations. A continuous CDC profile with a surviving ingest process may demonstrate partial pool suspension, but cannot be labeled full Rockstream scale-to-zero.

### G0 feasibility decisions

[ADR 0011](../adr/0011-risk-reduction-before-implementation.md) focuses G0 on **four high-signal kill-switch deliverables (`G0.1`–`G0.4`)** runnable in 2–4 weeks, rather than building two full engines, 1,000-view benchmarks, and full hibernation before G1. Freeze numeric budgets before confirmatory runs; every deliverable produces **pass, fail, or inconclusive**, raw evidence, and an ADR update.

| Deliverable | Required measurement & verification | Fallback / course correction |
| --- | --- | --- |
| **G0.1** Bootstrap, CI & `W1-G` Oracle | Minimal Rust workspace, fast local/CI entry point (<5 min), crate dependency-direction negative control, frozen `W1-G` transactions, independent PostgreSQL/batch oracle, broken cross-term negative control, and Rockstream v1 donor disposition register | Block G1 until negative controls reliably catch injected defects and CI runs cleanly |
| **G0.2** Storage & Metadata Physics Probe | On real S3/object storage: (a) single-key conditional `PUT` (`If-Match`) + **compositional intra-batch serialization** under single-tenant shared-quota and same-domain writes (with pre-allocated owner namespaces); (b) **immutable-delta + per-domain SlateDB working index + bounded delta overlay** vs. pure SlateDB history on `W1-G` (separate-reader point lookup at `Cp` and `C ∈ [S_hot, Cp]`, exact-parent reopen after `SIGKILL`, Direct-DML PK index recovery, checkpoint amortization, nonlinear intermediate cuts, real sweeper-observed grace-window GC deletion); (c) full sequential S3 freshness round trips plus warm lease-backed (`<5 ms` target) vs. strict-latest read latencies | Lock **one** storage layout before G2; if Object-Native S3 latency misses target partner needs, schedule Embedded OpenRaft earlier (and note whether a fast cross-AZ WAL tier is required for `≤100 ms` P99 freshness) |
| **G0.3** Core Protocol Model (Quint) | One concise **Quint** specification covering publication atomicity, pre-allocated owner-generation fencing, compositional batch outcomes (including lost CAS response after later root advance), and monotonic-lease + sweeper-observed grace-window (`Δ_gc_grace >> Δ_read_lease`) GC safety (including VM pauses), with deliberate negative controls | Resolve any protocol counterexample before writing G2 metadata/GC code |
| **G0.4** Minimal Native Kernel Spike | Acyclic scalar-epoch weighted Arrow batch kernel executing `W1-G` against the G0.1 independent oracle with explicit memory/queue bounds | Confirm native direction; **only** prototype Timely/Differential if native hits a concrete predeclared complexity or correctness wall |

Later-gate qualification remains binding where those features actually live: **G2** qualifies end-to-end durable single-node `pgwire` + crash recovery + view quarantine + stop/restart; **G3a** qualifies table-stakes SQL (`LEFT OUTER JOIN`, `DISTINCT`, semi/anti joins, `MIN`/`MAX`), online lifecycle, live PG CDC (additive-DDL tolerant), Kafka, and resumable subscriptions; **G3b** qualifies 100/1,000-view sharing economics, rule-based consumer isolation, bounded single-depth pipelining, and eligible F-IVM; **G4** qualifies multi-node cloud execution, cache-affinity serving, distributed suspension/wake, and optional Embedded OpenRaft; **G6** qualifies 72-hour soaks, DR restore drills, and v1 migration.

### Early feasibility and user experience

Run the G0 full-path latency/resource experiments in [implementation start](implementation-start.md) before promoting SLOs or platforms. Instrument actual metadata/pin paths, storage amplification, runtime and cold activation; record raw end-to-end observations, errors and predeclared workload/decision criteria. G2 measures the prepared local quickstart through authenticated SQL, correct initial view and observed update after required publication wait, with installation and cold starts separate. Capture unsuccessful setup attempts. G3–G6 extend to connectors, cloud profiles and operational diagnosis.

For deletion and decommissioning, exercise drop/retirement racing with valid pins, staged writes and suspended owners; distinguish logical row absence from physical reclamation and backup/external copies. Verify old actors cannot re-expose retired scopes; restore an older backup and require deletion/retirement reconciliation before reopening affected data. Report retained copies, provider versioning/retention locks, failed cleanup and unverified erasure explicitly. Do not remove protected roots to pass a cleanup target.

## 9. Evidence bundle schema

The implementation will define and version a machine-readable bundle with at least:

| Section | Required fields |
| --- | --- |
| Identity | Engine/repo commit, binary hash, dependencies, config hash, checker version, measured-vs-fixture provenance |
| Environment | Cloud/region/zone topology, instance/storage/network types, all Rockstream process IDs/roles, failure profile, object-store conformance profile, source/sink versions, activation mechanism |
| Workload | Query/generator hashes, semantic profile and dialect exclusions, donor/oracle versions, seed, input snapshot/transaction manifest, source cuts, amplification, per-consumer retention/scheduling budgets, sharing/isolation baseline, strategy/eligibility contract IDs |
| Time | Warmup, steady-state interval, repetitions, clocks, fault and recovery timeline |
| Observations | Raw transcripts/references, logical cuts/coverage, metadata revisions and operation outcomes, logical operations versus physical reads/writes/CAS, batch/group/checkpoint reuse, history/reconstruction/compaction debt, latency/errors, IO/network/resources and active/dormant process counts; per-domain physical-group interference, peak lifecycle overlap and predicted versus observed costs |
| Faults | Requested fault, verified target/event, expected invariant, observed recovery and loss/duplicate checks |
| Cost | Billable quantities, prices/date, included services, attribution, headroom and total |
| Verdict | Predeclared profile/limits/decision rubric, exact comparisons, negative controls, pass/fail/inconclusive, component and joint G0 verdicts where applicable, unresolved defects/gaps, fallback/ADR decision, reviewer identity |

Protect evidence against accidental overwrite and include checksums. For agent-led development, record the issue/PR, commit, implementing and independently reviewing identities, approved risk tier, commands, actual observations and applicable authorization. CI-produced artifacts and independent checking, not agent self-report, establish the verdict; do not store secrets or unnecessary private prompt histories. A provenance hash supports reproducibility; it does not replace an independent checker or trustworthy observation. Verification tooling should be usable outside the tested cluster.

## 10. Release gates and regression policy

The [development workflow](../design/development-workflow.md) defines the fast required PR baseline, risk-selected extended pre-merge checks, post-merge, continuous, nightly, weekly and release lanes. The ordinary required CI objective is median under 5 minutes and P95 under 10 minutes including queueing. These objectives are unmeasured and cannot waive a safety obligation. Fast PR checks cover changed contracts, a bounded deterministic seed corpus and focused real-dependency smoke tests. High-risk changes require applicable model, fault, compatibility or other safety evidence before merge. Background lanes broaden randomized exploration, real adapter tests, mutation, fuzzing, scale and soaks; they do not routinely block PRs. Pre-release and capability promotion run the declared full applicable workload/fault/upgrade/restore matrix. Exact durations, counts and seed budgets are selected from measured coverage/runtime, not arbitrary large counts intended to look rigorous.

A verified background correctness failure blocks affected promotion and triggers immediate triage, containment and a tracked fix or revert. Archive seeds, traces, independent observations and minimized regression cases. Keep passing, failing, missing, stale and incomplete evidence distinct; a canceled job or retry of a product assertion cannot yield green. Required checks validate the actual integration revision. Merging an unsupported, inert capability is not promotion; no known violation of an existing supported contract may merge.

Performance engineering starts with targeted kernel microbenchmarks and background commit-to-commit regression baselines; use fixed comparable workloads, repetitions/noise estimates and predeclared thresholds. A microbenchmark is not a release or economic qualification. Record significant regressions and bisect/triage them as tracked work.

Any invariant violation blocks promotion irrespective of benchmark speed. Performance gates use the predeclared [requirements](requirements.md); narrow the published support envelope when an improvement does not generalize. A regression exception requires an updated workload promise, explanation, measured tradeoff and explicit maintainer decision in the release record. Preserve counterexamples and add a meaningful regression case before closing a correctness defect.

An authorized human maintainer approves the release after independent review of the exact candidate evidence; an implementation agent cannot authorize or sign its own release. Review gate results at the exact release commit and binary. A passing previous head is not evidence for untested subsequent changes. This documentation package's validation record must remain separate from all future executable qualification results.
