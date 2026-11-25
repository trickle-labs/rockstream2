# Risks, unresolved decisions, and decision gates

**Status:** Proposed register, 2026-11-25. Owners are roles to assign. “Open” identifies implementation evidence still required; the semantic and safety contracts remain binding. None of the mitigations below has been executed in Rockstream 2.

## 1. Highest-impact risks

| ID | Risk and consequence | Mitigation / experiment | Owner; resolution gate |
| --- | --- | --- | --- |
| R01 | SlateDB checkpoint/clone semantics or cost do not fit one exact externally published version per interval | Test exact reopen, aborted prepare, independent readers, GC and request cost; retain immutable-batch fallback | Storage; G0 |
| R02 | Reused runtime cannot attach durable versioned state or safely add/remove graphs | Compare identical semantic/recovery workloads on runtime candidates; isolate adapter complexity | Runtime + compiler; G0 |
| R03 | SQL frontend behavior differs from promised NULL, casts, numeric or time semantics | Type/operator matrix, semantic adapter, independent PostgreSQL/reference oracle; reject unsupported combinations | Compiler; G0–G2 |
| R04 | Metadata becomes a cluster-wide operational or throughput bottleneck | Bounded root CAS, fixed generation, domain-count load test, separate notification caches; choose scalable substrate only with evidence | Storage + operations; G0/G4 |
| R05 | Shared state increases retention and scheduling coupling instead of reducing total cost | Per-consumer obligations/quotas, cost attribution, duplicate-isolation option, slow-consumer benchmark | Optimizer + runtime; G3 |
| R06 | “Independent domains” quietly permits inconsistent shared-source reads | Exact lineage and shared-cut equality; explicit imports and unavailable-cut errors; reject cycles initially | Consistency; G0/G4 |
| R07 | Small object writes/checkpoints prevent tight freshness or dominate cloud cost | Measure batching/request distribution; choose honest first profile; evaluate replicated input log only if justified | Storage + performance; G0/G4 |
| R08 | Large fanout, hot keys or transactions make work inherently expensive | Estimate and expose cost class; reservations, spill, partial aggregation only when algebraically valid; controlled backpressure | Runtime; G2/G4 |
| R09 | GC or backend-native compaction reclaims history, input or staging references too early | Atomic pin/retirement, allocation generations, non-expiring checkpoints, no resurrection, accepted-input roots | Storage + verification; G0/G3 |
| R10 | Source retention, missing before-images or schema changes prevent replay | Live connector qualification, explicit source contracts/headroom, versioned rebootstrap and rebuild | Connectors; G3 |
| R11 | A sink commits externally but the sender loses the response | Initial at-least-once stable envelope IDs; stronger destination-marker recovery must prove ambiguity resolution | Connectors; G3 and optional stronger sink gate |
| R12 | Restore revives stale ownership/tokens or repeats an external effect | New run incarnation, physical namespace/credential fencing, source/sink reconciliation and empty-environment drill | Operations; G6 |
| R13 | The clean rewrite drops mature security, SQL or operational behavior needed by users | Workload inventory, existing regression reuse, capability parity before migration; keep old engine active | Technical lead; G2–G6 |
| R14 | Advanced IVM generates more auxiliary state than it saves | Eligibility rules, total lifetime cost, reference strategy, explicit rollback and experiment budgets | Optimizer; each G5 feature |
| R15 | Estimated delivery effort expands beyond the team budget | Gate-based re-estimation, limit parallel G5 work, build one public vertical path, stop/narrow if partner value is absent | Technical lead; every gate |

## 2. Open choices that need evidence, not another abstract architecture

| Question | Current recommendation | Evidence that can change it |
| --- | --- | --- |
| Which execution substrate? | Reuse first if it meets fixed contracts; no final choice yet | ADR 0005 common experiment and adapter maintenance assessment |
| Which exact SlateDB/datafusion/runtime revisions? | Pin after G0, do not copy the old workspace lockfile automatically | Compatibility, security, license, state-format and lifecycle conformance |
| Cloud metadata backend? | etcd reference, SQLite embedded | Measured domain/head/pin transaction workload or operational constraint favoring an equivalent transactional service |
| How much is persisted per operator? | Inputs and expensive derived state durable; cheap state reconstructible only with protected recipe/input | Recovery budget and measured recomputation versus storage/compaction cost |
| How many domains and virtual partitions? | Explicit transaction/visibility groups and enough fixed partitions for first scale ladder | Partner dependency graphs, source transaction scope, metadata scale and skew |
| First cloud freshness profile? | Object-store durability with measured envelope; 100 ms as stretch target | Real object-store tail latency, batch/request costs, output amplification and quorum timing |
| Decimal accumulator and type-return matrix? | Declared precision ≤38 profile; exact/widened intermediate rules | G0 range proof, PostgreSQL compatibility tests and bounded arbitrary-precision cost |
| Scope of historical time syntax? | Exact SnapshotToken first | A documented mapping from wall time to complete retained cuts across required domains |
| Domain split/merge or finer ownership fences? | Defer; one generation per domain | Rebalancing abort cost becomes material and a refined protocol passes model/fault gates |
| First recursive fragment and deletion strategy? | Finite positive set recursion; no general deletion promise | Exact cyclic/deletion cases, rederivation/progress proof obligations and useful partner workload |
| Cross-tenant sharing? | Disabled | Security threat analysis, policy invalidation and cost isolation evidence; never a default optimization |
| Which G5 features precede first release? | Those required for named migration workloads and independently qualified | Capability inventory and measurable benefit, not speculative breadth |
| RPO/RTO per profile? | Zone recovery and regional DR specified separately; no universal zero-loss regional promise | Restore drills, backup lag, retained-state scale and dependency availability |

## 3. Decisions deliberately constrained now

These are not unresolved implementation preferences: no published reference to transient-only state; no cross-domain epoch comparison; no stale-owner publication; no reuse of abandoned tentative state; no resurrection of a GC-retired root; no forgotten arbitrary request key silently treated as a fresh retry; no unqualified exactly-once external side-effect claim; and no unsupported SQL silently lowered to an approximation.

The design also constrains default safety behavior. Missing source history stops the affected pipeline and requires rebootstrap. Resource exhaustion keeps the last correct publication. A publication wait timeout does not roll back accepted input. A valid history pin cannot be sacrificed to rescue an unbounded consumer. A later query/schema repair can intentionally rebuild at a later complete cut, but must declare unavailable intermediate history and include all accepted input.

## 4. Ambition versus first implementation

| Starting ambition | Treatment in the proposal |
| --- | --- |
| Unified DBSP engine | Core semantic contract; richer SQL progressively qualified |
| Shared arrangements and workload graph | G3 core; respect security, consumer retention and failure coupling |
| Dependency-scoped frontiers | Domain-local ordered time first, explicit imports in G4; nested iteration later |
| Object-storage-native durable state | First cloud profile with exact version/checkpoint contract; no hidden local-only authority |
| Factorized and higher-order IVM | First-class physical strategy interface, eligible shapes promoted in G5 |
| Broad SQL including recursion/time | Capability portfolio with explicit termination, deletion and replayable clock contracts |
| Independent serving | G4; shared object-store interference still measured |
| Serverless operation | G6 eligible pool pause/resume; ingestion, timers, metadata and retention retain obligations/cost |
| Cheap branches and zero-copy backup | Manifest/pin architecture permits them; independent backup and cloning qualification still required |
| 100 ms freshness, 5 ms reads, 80% scale efficiency, PB scale | Named workload/profile targets and expanding qualification ladder; never claimed current measurements |
| Better in every dimension | No safety regressions, declared protected workloads, measured cost/performance wins and honest tradeoffs |

## 5. Decision process

Assign one owner and due gate per open item. Before building a large dependency around it, record alternatives, fixed requirements, experiment, outcome and the affected ADR. A failed experiment is a useful result: narrow scope, change the component or revise the workload promise through review. Do not silently turn an uncertainty into an implementation assumption.

Critical safety disagreements block the affected implementation until a counterexample is resolved. Cosmetic preferences do not. Reopen a decision only when new workload evidence, component constraints or a concrete failure invalidates its assumptions. The [implementation plan](implementation-plan.md) names the work packages that supply this evidence.
