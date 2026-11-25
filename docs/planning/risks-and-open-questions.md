# Risks, unresolved decisions, and decision gates

**Status:** Proposed register, 2026-11-25. Owners are roles to assign. “Open” identifies implementation evidence still required; the semantic and safety contracts remain binding. None of the mitigations below has been executed in Rockstream 2.

## 1. Highest-impact risks

| ID | Risk and consequence | Mitigation / experiment | Owner; resolution gate |
| --- | --- | --- | --- |
| R01 | SlateDB arrangement layout, history or checkpoint/clone cost makes logical MVCC uneconomical | Test exact base-plus-delta reconstruction, independent physical checkpoint cadences, aborted prepare, readers, GC and request cost; tune layout/batching and consider bounded upstream work before changing backend | Storage; G0 |
| R02 | Native runtime creates excessive maintenance burden or cannot support progress, durable state and graph lifecycle economically | Compare the lean native prototype with Timely/Differential on identical semantic/recovery workloads; assess Feldera reuse where feasible and retain the ability to change direction | Runtime + compiler; G0 |
| R03 | SQL frontend behavior differs from promised NULL, casts, numeric or time semantics | Type/operator matrix, semantic adapter, independent PostgreSQL/reference oracle; reject unsupported combinations | Compiler; G0–G2 |
| R04 | One authoritative metadata root becomes a contention, request-cost or availability bottleneck | Bounded root CAS over an immutable tree, safe batching, domain/head/pin load tests and notification caches; change partitioning or evaluate embedded Raft only with a modeled protocol and material evidence | Storage + operations; G0/G4 |
| R05 | Shared state increases retention and scheduling coupling instead of reducing total cost | Per-consumer obligations/quotas, cost attribution, duplicate-isolation option, slow-consumer benchmark | Optimizer + runtime; G3 |
| R06 | “Independent domains” or MVCC quietly permits inconsistent shared-source reads | Exact lineage, shared-cut equality and transaction/causal closure; qualify reconstruction at common logical cuts despite different physical checkpoints; explicit missing-coverage errors; reject cycles initially | Consistency; G0/G4 |
| R07 | Small object writes/checkpoints prevent tight freshness or dominate cloud cost | Measure batching/request distribution; choose honest first profile; evaluate replicated input log only if justified | Storage + performance; G0/G4 |
| R08 | Large fanout, hot keys or transactions make work inherently expensive | Estimate and expose cost class; reservations, spill, partial aggregation only when algebraically valid; controlled backpressure | Runtime; G2/G4 |
| R09 | GC or backend-native compaction reclaims history, input or staging references too early | Atomic pin/retirement, allocation generations, non-expiring checkpoints, no resurrection, accepted-input roots | Storage + verification; G0/G3 |
| R10 | Source retention, missing before-images or schema changes prevent replay | Live connector qualification, explicit source contracts/headroom, versioned rebootstrap and rebuild | Connectors; G3 |
| R11 | A sink commits externally but the sender loses the response | Initial at-least-once stable envelope IDs; stronger destination-marker recovery must prove ambiguity resolution | Connectors; G3 and optional stronger sink gate |
| R12 | Restore or activation revives stale ownership/tokens or repeats an external effect | New ownership fences on activation; new run incarnation and physical namespace/credential fencing on disaster restore; source/sink reconciliation and empty-environment drills | Operations; G2/G4/G6 |
| R13 | The clean rewrite drops mature security, SQL or operational behavior needed by users | Workload inventory, existing regression reuse, capability parity before migration; keep old engine active | Technical lead; G2–G6 |
| R14 | Factorization or advanced IVM generates more auxiliary state than it saves | Eligibility rules, total lifetime cost including shared reuse/history, first-order reference strategy, explicit fallback and experiment budgets | Optimizer; G0/G3 and each G5 feature |
| R15 | Agent implementation and verification effort expands beyond budget or human decision/review capacity | G0 pilot, track accepted changes/rework/cost/review wait, re-estimate gates from evidence, limit parallel work, build one public vertical path, stop/narrow if partner value is absent | Technical lead; every gate |
| R16 | Scale-to-zero hides an always-on authority, requires unavailable source history, or misses a freshness/timer/delivery obligation | Stop every Rockstream process in the experiment, discard cloud local files, verify manual/platform activation, retained roots, eligibility checks, source headroom and total cold catch-up cost | Runtime + operations; G0/G2/G4 |
| R17 | An object store or transactional-object helper lacks the required conditional-write and recovery semantics | Provider-specific conformance, ambiguous CAS and concurrent writer tests; do not treat one-object CAS as a multi-object transaction or an S3-compatible label as proof | Storage + verification; G0/G4 |
| R18 | Compaction or nonlinear maintenance erases an intermediate logical snapshot that was promised | Explicit inclusive since cut and coverage, timestamped bases/deltas, computed versus published uppers, pin/GC model and DISTINCT/aggregate/outer transition negative controls | Storage + compiler; G0/G2/G3 |
| R19 | Agents produce convincing but incorrect code, tests or claims and correlated reviews miss the flaw | Independent oracle and reviewer context, negative controls, protected CI evidence, no self-approval, human high-risk/release authority; test bypass attempts in P0.10 | Verification + maintainer; G0 and every gate |
| R20 | Parallel agents duplicate work, diverge contracts, overload CI/review, or accumulate complexity | Ready queue, exclusive issue claims, isolated worktrees, small WIP limit, dependency rules, merge queue, explicit experiment cleanup, measured conflict/rework and lead time | Dispatch + maintainer; G0 onward |
| R21 | Agent or dependency consumes untrusted instructions, exposes secrets, or changes policy to gain authority | Least privilege, no production secrets/signing keys, protected policy/checkers, independent approvals, scoped budgets, isolation and denial negative controls | Security + maintainer; G0 onward |
| R22 | Green fast CI conceals regression debt or background evidence becomes stale | Separate runner capacity, exact-revision evidence, prioritized triage/fix/revert, block affected promotion, track verification backlog and escaped defects | Verification + performance; every gate |
| R23 | Broad feature/platform scope or difficult setup prevents a useful first product | Narrow qualified matrix, partner workload selection, fixed golden fixture, measured local quickstart and explicit unsupported boundaries | Product + maintainer; G0/G2/G6 |
| R24 | Mandatory metadata/pin, object-store, write or recovery cost makes target SLO/economics infeasible | Instrument actual end-to-end paths and resource denominators in G0; compare equivalent profiles, sound amortization or honest target revision | Storage + performance; G0/G4/G6 |
| R25 | Logical deletion mistaken for erasure, or backup/old worker re-exposes retired data | Authorized retirement/fencing, retention/copy inventory, GC proof, restore reconciliation and explicit residual copies/blockers | Storage + security + operations; G0 design, G2/G6 qualification |

## 2. Open choices that need evidence, not another abstract architecture

| Question | Current recommendation | Evidence that can change it |
| --- | --- | --- |
| Which execution substrate? | Lean Rockstream-native runtime, reusing suitable existing algorithms and infrastructure; DBSP is the semantic foundation, not a mandatory runtime dependency | ADR 0005 common experiment, especially Timely/Differential, and maintenance assessment can reverse the preference |
| Which initial platform/backend and agent execution environment? | One Linux server target, one qualified filesystem and object-store profile; GitHub-centered isolated agent pilot | Real provider/conformance measurements, reproducible CI, bounded agent permissions and observed work/review capacity |
| Which exact SlateDB/datafusion/runtime revisions? | Pin after G0, do not copy the old workspace lockfile automatically | Compatibility, security, license, state-format and lifecycle conformance |
| Cloud metadata implementation? | In-process kernel with one conditional object root pointing to immutable metadata; evaluate `slatedb-txn-obj` for suitable primitives; no external coordinator required | Provider conformance, atomic condition coverage, ambiguity resolution and domain/head/pin contention experiments; an embedded Raft alternative requires a revised durability/quorum/suspension profile |
| SlateDB arrangement layout and physical checkpoint cadence? | Group compatible arrangements in partitioned databases; preserve logical bases/deltas separately from physical version identities | Read/reconstruction, retained-history, compaction, request and exact-parent retry costs; no database-per-view assumption or planned custom storage engine |
| How much is persisted per operator? | Inputs and expensive derived state durable; cheap state reconstructible only with protected recipe/input | Recovery budget and measured recomputation versus storage/compaction cost |
| How many domains and virtual partitions? | Explicit transaction/visibility groups and enough fixed partitions for first scale ladder | Partner dependency graphs, source transaction scope, metadata scale and skew |
| First cloud freshness profile? | Object-store durability with measured envelope; 100 ms as stretch target | Real object-store tail latency, batch/request costs, output amplification and metadata contention |
| Decimal accumulator and type-return matrix? | Declared precision ≤38 profile; exact/widened intermediate rules | G0 range proof, PostgreSQL compatibility tests and bounded arbitrary-precision cost |
| Scope of historical time syntax? | Exact SnapshotToken first | A documented mapping from wall time to complete retained cuts across required domains |
| Domain split/merge or finer ownership fences? | Defer; one generation per domain | Rebalancing abort cost becomes material and a refined protocol passes model/fault gates |
| First recursive fragment and deletion strategy? | Finite positive set recursion; no general deletion promise | Exact cyclic/deletion cases, rederivation/progress proof obligations and useful partner workload |
| Cross-tenant sharing? | Disabled | Security threat analysis, policy invalidation and cost isolation evidence; never a default optimization |
| Which workloads can fully suspend? | Those with no immediate compute obligations and protected durable state, sufficient source/history retention, and a declared activation path | Full-fleet stop/cold-activation experiments, measured catch-up time and source/timer/sink constraints; partial pool suspension is a separate claim |
| Which G5 features precede first release? | Those required for named migration workloads and independently qualified | Capability inventory and measurable benefit, not speculative breadth |
| RPO/RTO per profile? | Zone recovery and regional DR specified separately; no universal zero-loss regional promise | Restore drills, backup lag, retained-state scale and dependency availability |

## 3. Decisions deliberately constrained now

These are not unresolved implementation preferences: no published reference to transient-only state; no cross-domain epoch comparison; no stale-owner publication; no reuse of abandoned tentative state; no resurrection of a GC-retired root; no forgotten arbitrary request key silently treated as a fresh retry; no unqualified exactly-once external side-effect claim; and no unsupported SQL silently lowered to an approximation.

Operational simplicity is also a fixed requirement: the baseline needs no mandatory external etcd, ZooKeeper, Redis or PostgreSQL catalog, and no mandatory Kubernetes installation. All cloud-profile authority must survive loss of every Rockstream process and local cache. This does not promise operation while the durable store is unavailable, wake-up without a caller/platform, or zero storage cost. Optional embedded consensus cannot be introduced as a hidden requirement or assumed to make progress without an active quorum.

The design also constrains default safety behavior. Missing source history stops the affected pipeline and requires rebootstrap. Resource exhaustion keeps the last correct publication. A publication wait timeout does not roll back accepted input. A valid history pin cannot be sacrificed to rescue an unbounded consumer. A later query/schema repair can intentionally rebuild at a later complete cut, but must declare unavailable intermediate history and include all accepted input.

## 4. Ambition versus first implementation

| Starting ambition | Treatment in the proposal |
| --- | --- |
| SQL-first streaming database with DBSP semantics | Familiar relational product; workload-centric internal engine and richer SQL progressively qualified |
| Shared arrangements and workload graph | G3 core with logical MVCC and independent schedules; respect security, consumer retention and failure coupling |
| Dependency-scoped frontiers | Domain-local ordered time first, explicit imports in G4; nested iteration later |
| Object-storage-native durable state | SlateDB-first state plus transactional object metadata; exact logical cut/protection contract, no hidden local-only authority |
| Factorized and higher-order IVM | Eligible partial aggregation/factorization experiment in G0 and measured core in G3; broader factorization and higher-order strategies in G5 |
| Broad SQL including recursion/time | Capability portfolio with explicit termination, deletion and replayable clock contracts |
| Independent serving | G4; shared object-store interference still measured |
| Scale-to-zero behavior | G0 experiment, G2 single-process suspend/resume, G3 shared obligations, G4 distributed activation, G6 full qualification; ingestion, timers, sinks, retention and wake triggers constrain eligibility/cost |
| Cheap branches and zero-copy backup | Manifest/pin architecture permits them; independent backup and cloning qualification still required |
| 100 ms freshness, 5 ms reads, 80% scale efficiency, PB scale | Named workload/profile targets and expanding qualification ladder; never claimed current measurements |
| Better in every dimension | No safety regressions, declared protected workloads, measured cost/performance wins and honest tradeoffs |

## 5. Decision process

Assign one owner and due gate per open item. Before building a large dependency around it, record alternatives, fixed requirements, experiment, outcome and the affected ADR. A failed experiment is a useful result: narrow scope, change the component or revise the workload promise through review. Do not silently turn an uncertainty into an implementation assumption.

Critical safety disagreements block the affected implementation until a counterexample is resolved. Cosmetic preferences do not. Reopen a decision only when new workload evidence, component constraints or a concrete failure invalidates its assumptions. The [implementation plan](implementation-plan.md) names the work packages that supply this evidence.
