# Risks, unresolved decisions, and decision gates

**Status:** Proposed register, 2026-11-26. Owners are roles to assign. “Open” identifies implementation evidence still required; invariants remain binding. Prioritize **metadata coordination & read latency (R04)** and **storage/MVCC layout physics (R01)** as the two **critical** G0.2 kill-switch risks, followed by runtime complexity (R02), rewrite regressions (R13), and shared retention economics (R05).

[ADR 0011](../adr/0011-risk-reduction-before-implementation.md) resolves the earlier design contradictions (dual cloud profiles, compositional intra-batch metadata commits, lease-backed fast reads with conservative GC grace windows, immutable delta traces + per-domain SlateDB working indexes, view-level fault isolation, and a lean 4-deliverable G0 gate). These are concrete architectural simplifications, not claims that the underlying cloud physics have already been measured.

## 1. Highest-impact risks

| ID | Risk and consequence | Mitigation / experiment | Owner; resolution gate |
| --- | --- | --- | --- |
| R01 | Storage layout or logical MVCC write/checkpoint amplification makes cloud operation uneconomical | **G0.2** compares **immutable object-backed delta segments + per-domain SlateDB working index** against pure SlateDB history on real S3 (`W1-G`, `SIGKILL` exact-parent reopen, bounded hot-history window `[S_hot, Cp]`, real grace-window GC) and locks one layout before G2 | Storage; G0.2 lock, G2 qualification |
| R02 | Native Arrow/DataFusion runtime grows excessive complexity | **G0.4** validates the lean acyclic scalar-epoch kernel on `W1-G` (one interval/domain in G1–G2, single-depth pipelining in G3–G4). Only prototype Timely/Differential if native hits a concrete predeclared complexity or correctness blocker | Runtime + compiler; G0.4, G3/G4 |
| R03 | SQL frontend behavior differs from promised NULL, cast, decimal, or time semantics | Explicit type/operator matrix, DataFusion semantic adapter, independent PostgreSQL + Rust bag oracle; fail closed on unsupported combinations | Compiler; G0.1, G1–G2 |
| R04 | Single S3-CAS metadata root hits latency or throughput limits | **G0.2** measures single-key S3 conditional `PUT` with **compositional intra-batch serialization** (same-domain and shared-quota writes) and lease-backed warm reads (`Δ_gc_grace >> Δ_read_lease`); **G0.3** models safety in **Quint**. Dual cloud profiles separate Object-Native (~200 ms–1 s freshness) from G4+ Low-Latency Cloud (embedded OpenRaft, ≤100 ms) | Storage + operations; G0.2/G0.3, G4 |
| R05 | Shared state increases retention and scheduling coupling instead of lowering total cost | Cost-based placement after semantic/security eligibility; per-consumer budgets and reversible isolation via pinned snapshot/replay/cutover; 100/1,000-view benchmark in G3 where sharing exists | Optimizer + runtime; G3 |
| R06 | Independent domains or MVCC permit inconsistent shared-source reads | Exact lineage, shared-cut equality, and transaction/causal closure; never compare numeric epochs across domains; reject import cycles | Consistency; G3–G4 |
| R07 | Direct-DML primary-key image index or small object writes inflate cloud cost | Explicitly budget the SlateDB PK image index for keyed direct-DML tables (avoided by append-only & PostgreSQL CDC); batch small transactions | Storage + performance; G0.2, G2 |
| R08 | Large fanout, hot keys, or poison records wedge maintenance | View-level fault quarantine halts only the failing derived view (unless explicitly coupled); reservations, spill, and eligible F-IVM bound work | Runtime; G2–G4 |
| R09 | GC or SlateDB compaction reclaims protected state too early | Generational reachability + **conservative physical-deletion grace window (`Δ_gc_grace >> Δ_read_lease + clock_skew_bound`)** modeled in **Quint (G0.3)** and exercised with real deletion in G0.2/G2 | Storage + verification; G0.2/G0.3, G2 |
| R10 | Source retention loss, missing before-images, or schema changes prevent replay | Live PostgreSQL CDC / Kafka qualification, source headroom diagnostics, explicit rebootstrap | Connectors; G3 |
| R11 | Sink commits externally before sender sees response | Initial at-least-once outbox with stable envelope IDs; stronger destination-marker protocol separately gated | Connectors; G3+ |
| R12 | Restore or activation revives stale writers/tokens | Fresh `OwnershipGeneration` on activation; new `RunIncarnation` + credential/namespace fencing on DR restore | Operations; G2/G4/G6 |
| R13 | Clean rewrite drops mature v1 SQL, wire, or security behavior | G0.1 donor disposition register + three-way (v1 / v2 / independent oracle) comparison per migrated capability; strangler shadow migration | Technical lead + verification; G0.1, G2–G6 |
| R14 | Factorization (F-IVM) adds more auxiliary state than it saves | Executable strategy contracts, first-order baseline, lifetime cost model, explicit fallback | Optimizer; G3 and G5 |
| R15 | Agent throughput stalls on human review bottleneck or verification bloat | Contract-bounded Medium-risk PRs verified by independent oracles/Quint/CI flow smoothly; humans own invariants/architecture/security/releases; fast <5 min PR CI | Technical lead; G0.1 onward |
| R16 | Full zero-process hibernation conflicts with continuous CDC or low-latency read SLAs | Separate stateless compute scale-to-zero (all profiles) from full zero-process hibernation (eligible Object-Native workloads only); honest eligibility reporting | Runtime + operations; G2/G4 |
| R17 | Object store lacks strict conditional-write semantics | Provider-specific real-S3 conformance in G0.2/G4; never trust an "S3-compatible" label alone | Storage + verification; G0.2/G4 |
| R18 | Compaction erases promised nonlinear intermediate cuts | Explicit fine-grained hot window `[S_hot, Cp]` in immutable delta segments + periodic checkpoints in `[S, S_hot)`; negative controls for canceling transitions | Storage + compiler; G0.2/G2/G3 |
| R19 | Agents share correlated blind spots in code and review | Independent deterministic oracles (PostgreSQL/batch), Quint models, negative controls, and real-process crash tests—never rely on agent review alone | Verification + maintainer; G0.1 onward |
| R20 | Multi-domain SlateDB grouping reintroduces writer/recovery coupling | Start with one SlateDB instance per consistency domain/partition in G0–G2; defer multi-domain grouping to G3/G4 only if measured manifest overhead justifies it | Storage; G0.2/G3 |

## 2. Open choices that need evidence, not another abstract architecture

| Question | Current recommendation | Evidence that can change it |
| --- | --- | --- |
| Which execution substrate? | Lean Rockstream-native runtime, reusing suitable existing algorithms and infrastructure; DBSP is the semantic foundation, not a mandatory runtime dependency | ADR 0005 common experiment, especially Timely/Differential, and maintenance assessment can reverse the preference |
| Which initial platform/backend and agent execution environment? | One Linux server target, one qualified filesystem and object-store profile; GitHub-centered isolated agent pilot | Real provider/conformance measurements, reproducible CI, bounded agent permissions and observed work/review capacity |
| Which exact SlateDB/datafusion/runtime revisions? | Pin after G0, do not copy the old workspace lockfile automatically | Compatibility, security, license, state-format and lifecycle conformance |
| Cloud metadata implementation? | One conditional object root (`If-Match` PUT) with compositional intra-batch serialization and lease-backed fast reads (`Δ_gc_grace`); Object-Native default + optional G4+ Embedded OpenRaft Low-Latency profile | G0.2/G0.3 real-S3 latency/throughput measurements and Quint model; earlier Embedded Raft only if partner workloads require ≤100 ms cloud freshness |
| Storage & logical MVCC layout? | Immutable object-backed delta segments + per-domain SlateDB working index (bounded hot window `[S_hot, Cp]` + periodic checkpoints) | G0.2 real-S3 comparison against pure SlateDB history (write/request amplification, exact-parent reopen, real grace-window GC, cold recovery); lock one path before G2 |
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

Assign one owner and due gate per open item. Before building a large dependency around it, record alternatives, fixed requirements, experiment, outcome and the affected ADR. A failed experiment is a useful result: narrow scope, change the component or revise the workload promise through review. Use the predeclared pass/fail and fallback rules in [qualification](qualification.md#g0-feasibility-decisions); distinguish throughput failure, coordination-latency failure, storage-layout cost, runtime burden, sharing cost and ineligible hibernation rather than treating them as one architectural verdict. Preserve the failed profile and rerun any changed candidate against the same correctness contract. Do not silently turn an uncertainty into an implementation assumption. No performance failure authorizes weaker publication, fencing, authorization, source-transaction or retention guarantees.

Storage and metadata decisions are locked only after real measurements in the [lean G0 kill-switch decisions](qualification.md#g0-feasibility-decisions). Link the selected configuration and its residual limits to [partner decision records](requirements.md#1-users-and-workloads) as they arrive; an isolated microbenchmark or optimistic optimizer estimate cannot close a workload-level risk.

Critical safety disagreements block the affected implementation until a counterexample is resolved. Cosmetic preferences do not. Reopen a decision only when new workload evidence, component constraints or a concrete failure invalidates its assumptions. The [implementation plan](implementation-plan.md) names the work packages that supply this evidence.
