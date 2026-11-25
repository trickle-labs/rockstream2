# Product requirements and success criteria

**Status:** Proposed, 2026-11-25. All targets are qualification goals; none are measured Rockstream 2 results. Read with the [design](../../DESIGN.md), [SQL contract](../reference/sql-and-apis.md), and [qualification plan](qualification.md).

## 1. Users and workloads

The external product is a **SQL-first streaming database**: users define tables and maintained views, then choose freshness, consistency and retention. Internally, a workload-centric incremental engine shares compatible computation and state across those views. Users should not need to operate a general computation graph or a separate coordination service to obtain the database guarantees.

| User | Job | Representative workload | Critical constraint |
| --- | --- | --- | --- |
| Application developer | Query a current application read model without repeatedly rebuilding it | Customer balance, entitlement membership, inventory availability | Transaction-consistent reads, predictable errors, read-your-writes |
| Data/platform engineer | Maintain changing relational transformations | CDC joins, grouped metrics, view-on-view pipelines | Replayable ingestion, schema evolution, cost and recovery visibility |
| Cloud operator | Meet freshness and read SLOs without permanent overprovisioning | Many tenants, large retained state, independent read pools | Isolation, bounded failure impact, upgrades, backups, resource attribution |
| Advanced analyst, later | Maintain expensive connected or temporal computations | Multiway aggregates, bounded recursive reachability, expiring sessions | Explicit algorithm eligibility, termination, retractions, state bounds |

Initial design partners should supply at least three concrete workloads: a transactional application projection, a join-heavy CDC analytical pipeline, and hundreds of overlapping maintained views. Freeze representative SQL, input distribution, update/delete mix, transaction sizes, retained history, read load, and failure budget before optimizing.

Start with the narrow product and [golden workload W1-G](implementation-start.md), not speculative feature breadth. P0.5 must identify concrete design-partner workload manifests and prioritize their required capabilities; the synthetic fixture is not partner evidence. Preview and production support envelopes are declared separately; G6 remains required for production.

## 2. Priorities

**P0: semantic correctness, durable acknowledgements, consistent visibility, recovery, explicit support boundaries, bounded resource behavior, and simple operation.** A faster result that silently changes the query, loses acknowledged input, drops a row, or mixes snapshots fails qualification. The supported cloud baseline must run with Rockstream binaries and a qualified object store, with no mandatory etcd, ZooKeeper, Redis, PostgreSQL catalog, or dedicated always-on control tier. Eligible deployments must be able to suspend all Rockstream compute and recover from durable state; this is an early design requirement.

**P1: lower total cost at a declared freshness SLO, shared-state efficiency, independent serving, usable SQL, observability, and safe lifecycle changes.** Improvements must be measured against the pinned original engine on supported common workloads.

**P2: advanced algorithms and broader SQL.** The architecture reserves contracts for recursion, temporal processing, higher-order maintenance and adaptive planning. Eligible partial aggregation and factorization are tested in G0 and implemented behind measured eligibility rules in G3; general advanced strategies remain separately gated. Feature breadth earns promotion through correctness and workload evidence, not an operator count.

Engineering quality, maintainability, simplicity and low issue-to-merge lead time are cross-cutting requirements, not optional feature work. Autonomous coding agents are the primary implementation workforce under the [agent operating model](../design/agent-development.md). Human maintainers retain safety/architecture and release authority; ordinary issues should not require manual approvals beyond their risk tier. Design for extensive deterministic tests, independent oracles, and focused real-dependency/public-path checks. Run deeper verification continuously outside the ordinary PR critical path; retain risk-based required checks and full release qualification.

## 3. Functional requirements

| ID | Requirement | First gate | Acceptance evidence |
| --- | --- | --- | --- |
| FR-01 | Maintain weighted bag relational queries with insert, update, delete and duplicates | G1 | Independent batch oracle at every completed logical time |
| FR-02 | Admit and durably acknowledge complete transactions with stable replay identity | G2 | Ambiguous acknowledgement and restart transcript |
| FR-03 | Publish complete input/state/output versions atomically within a domain | G2 | Crash-boundary, omitted-participant and stale-owner negative controls |
| FR-04 | Serve latest, result-fenced and repeatable pinned reads through pgwire | G2 | Protocol transcript proves snapshot and write-token meaning |
| FR-05 | Share compatible arrangements and subexpressions across independently scheduled consumers, with explicit/rule-based isolation | G3 | Same results at every promised cut, independent consumer budgets, verified snapshot/replay/cutover and retention handoff; share only where lifetime cost and SLOs justify it |
| FR-06 | Build, replace and drop views while unrelated readers continue | G3 | Snapshot/backfill/catch-up/cutover trace, cancellation and recovery |
| FR-07 | Support retained historical snapshots and resumable snapshot-plus-delta subscriptions | G3 | No gap, explicit duplicates on retry, exact cursor-expiry behavior |
| FR-08 | Qualify PostgreSQL CDC and Kafka inputs; provide Kafka delivery with an explicit guarantee tier | G3 | Live connector failover, source truncation, large transaction and sink-ambiguity tests |
| FR-09 | Distribute independently progressing result domains and independently size serving/maintenance pools | G4; local independent groups in G3 | Stalled domain isolation and concurrent query-load qualification |
| FR-10 | Reassign virtual partitions safely; split/merge only at a versioned routing boundary | G4 | Old-owner resurrection, mixed-routing, cold-restoration and scale tests |
| FR-11 | Explain maintenance strategy, retained state, reuse, cost estimates and freshness blockers | G3–G4 | Explain and system-table assertions tied to executed plans |
| FR-12 | Add advanced SQL/algorithms without changing the semantic or publication kernel | G5 | Feature-specific oracle, state and performance promotion gate |
| FR-13 | Operate rolling upgrades, disaster restore, failover and quotas | G6 | Automated operational drills against supported profiles |
| FR-14 | Preserve exact logical MVCC cuts independently of physical checkpoint cadence | G2; shared-consumer qualification in G3 | Distinct computed/published uppers, durable base plus timestamped history, exact reconstruction and explicit unavailable-history errors |
| FR-15 | Suspend eligible Rockstream compute and resume safely without an external coordination service | G0 experiment; G2 local/single-process; G4 distributed | No remaining Rockstream process required while dormant; new activation fences old owners and recovers accepted input, publications, timers and consumer obligations |

## 4. Guarantees and limits

| Boundary | Required guarantee | Explicit limit |
| --- | --- | --- |
| Direct writes / source → durable input | Deduplicated logical ingestion within the connector's declared identity and retention contract | A lost response requires status lookup/retry; expired dedupe identities cannot be silently reused |
| Durable input → published views | Exact logical effects and atomic domain visibility | Freshness is conditional on recoverable inputs and admitted capacity |
| Multi-table source transaction | All subscribed tables in the transaction domain advance together | No implied atomicity between unrelated external databases |
| Cross-domain reads | Dependency-compatible version set with explicit source lineage | No arbitrary “latest from each”; unavailable compatible cut waits or fails |
| Logical MVCC | Exact snapshots at advertised retained cuts, even when physical checkpoints have different cadences | Input retention alone does not promise materialized output history; expired or unrepresented cuts fail explicitly |
| Subscription transport | Initial snapshot and all subsequent committed deltas, with stable cursors | Unacknowledged envelopes may repeat; retention expiry is an error requiring rebootstrap |
| External sink | The guarantee actually provided by destination and protocol | No unconditional exactly-once claim for nontransactional side effects |
| Numeric results | Exact checked integer/decimal semantics; documented floating approximation | Floating reassociation is not bitwise equivalence; overflow stops the affected publication |
| Failure | No loss of acknowledged durable input or published data within the qualified failure model | Simultaneous loss of all authoritative copies or unprotected regional loss requires DR guarantees, not a compute-restart promise |
| Suspension | Protected durable state survives loss of every disposable Rockstream process and local cache | No requests, ingestion or deadlines can be serviced while all compute is off; activation requires a manual or platform trigger and cold-start time |

The first direct-write API serializes transactions within one domain and rejects cross-domain atomic writes. It does not promise PostgreSQL's complete isolation, locking, stored procedures, or catalog behavior. Compatible syntax and the pgwire transport are separately testable from semantic compatibility.

Each result domain has one atomic publication group. Independent maintenance schedules belong to separate consuming result domains, even when they share input history and arrangements. G3 qualifies this separation locally over a common input timeline; G4 adds distributed groups and general cross-domain imports. Views deliberately placed in one publication group retain that group's atomic visibility boundary.

## 5. Deployment profiles

| Profile | Intended use | Durability and availability claim |
| --- | --- | --- |
| Ephemeral developer | Fast tests and examples | No durable-acknowledgement claim; explicitly named mode |
| Embedded durable | Local durable engine, integration tests, small deployments | Process-crash recovery with fsync-capable local durable state; whole disk/host loss requires a backup |
| Cloud single process | Initial cloud vertical slice | One Rockstream binary plus a qualified object store; all authoritative data and metadata recoverable after process/cache loss |
| Cloud distributed | Initial distributed production target | Multiple instances of the same binary share protected object state; object-store conditional writes serialize authoritative metadata transitions; fail closed when these guarantees are unavailable |
| Embedded consensus tier, optional candidate | A demonstrated metadata or latency requirement that the baseline cannot meet economically | A qualified Raft library and replicated durable state inside Rockstream, only after an explicit architecture decision; active decisions require an available quorum and change the availability/suspension profile |

Limit the initial platform matrix to a named Linux server target, one local filesystem configuration and one real object-store provider/API/configuration profile. Linux is canonical agent/CI; macOS development is a candidate, not a durability or production-support claim. Package a standalone binary and container for the qualified target and qualify named PostgreSQL clients. Exact versions and provider are G0 decisions. See [implementation start](implementation-start.md).

Each profile exposes its failure model in catalog/system metadata and documentation. Embedded and cloud modes share semantics, but their infrastructure durability is not equivalent. Single-binary convenience must not disguise single-machine loss risk.

The initial cloud metadata design is one authoritative, conditionally updated root pointing to immutable metadata objects. It is a serialization point for admission, publication, ownership, pins and reclamation decisions. G0 must qualify bounded adaptive group commits, per-operation retry outcomes and amortized reader-group protection; latency still includes authoritative latest selection and final protection/authorization checks. Declare logical scopes while retaining one root. A conditional update of one object is not a transaction over independent roots. Throughput failure can trigger partitioning research and coordination-latency failure can trigger embedded consensus, each with separate correctness, durability and stop/restart qualification. Qualify strong read/conditional-write behavior, lost-response recovery and fencing for each supported provider; “S3 compatible” alone does not qualify a backend. Reuse SlateDB transactional-object primitives if they meet these contracts. Embedded mode needs its own crash-safe local implementation of the same logical transitions.

Scale-to-zero eligibility is workload-specific. Continuous CDC needs live ingestion or a qualified upstream retention and activation contract; freshness deadlines, pending sink delivery, durable clock inputs and history pins remain obligations. An inactive system needs an external caller, operator or hosting platform to launch a process, but no particular launcher or Kubernetes installation is mandatory. Report the remaining storage, source-retention and optional activation costs. Zero Rockstream compute does not mean zero total cost or immediate response after activation.

## 6. Measurements that define “better”

Every result specifies workload, commit, hardware, topology, data scale, source/output amplification, retention, durability profile, load, and error rate. The benchmark harness records both offered and achieved input rate and does not omit timeouts from latency reports.

| Dimension | Proposed qualification target | Qualification scope / caveat |
| --- | --- | --- |
| First maintained view | Within 5 minutes on a prepared supported local environment, aspirational | Include initialization, authenticated connection, SQL creation, update, publication wait and exact query; record installation and cloud cold start separately; qualify from G2 |
| Correctness | Zero unexplained exact-result, atomicity, or durable-acknowledgement violations | All promoted capabilities and declared failures; finite testing is not proof of the whole system |
| Freshness | P99 ≤ 100 ms aspirational low-latency profile; first cloud profile publishes its measured envelope | Small admitted transactions, warm working set, fixed read load and output amplification; replicated durability may be required |
| Indexed reads | P99 ≤ 5 ms aspirational server-side request latency on warm indexed point/range reads | Include required snapshot selection, pin acquisition/validation and data access; publish client latency and any separate kernel microbenchmark distinctly. Object-root I/O may make this goal infeasible without a qualified amortization protocol. |
| Scaling | `Q16 / (16 × Q1) ≥ 0.80` | Partitionable fixed-query workload, bounded backlog/debt, same worker class and per-worker resources |
| Sharing | ≥ 2× lower maintained-state bytes on the designated 100-view overlapping workload; pursue 10× on favorable workloads | Include retention, catalog, CPU and catch-up cost; 10× is a stretch goal, not generic compression |
| Cost | ≥ 30% lower total cost per million correct durable changes on two chosen design-partner workloads | Proposed business gate; both systems meet identical semantics, SLO, availability, serving and retention constraints |
| Mixed serving | Maintenance qualified throughput decreases by ≤ 10% under the specified isolated read-pool load | Includes object-store/cache/network contention; hardware and read QPS frozen in profile |
| Failover | Published results remain readable when serving compute and their protected snapshot are available; recovery target established from measured retained state | Working-set size, metadata recovery/contention and replay volume determine RTO; no universal cold-start number |
| Idle operation | Zero Rockstream processes for an eligible dormant workload, with exact recovery after reactivation | Publish cold-resume latency, replay/catch-up cost, remaining storage/source costs and the activation mechanism; continuous-ingest profiles may retain an ingestion process |
| Long-running stability | 72-hour mixed-load soak with bounded backlog, compaction debt, history and memory | Corrections and restarts included; no hiding growing debt after a short peak |
| Capacity | State beyond RAM in the first cloud release; petabyte scale as a long-term qualification ladder | Test 1×, 4× and 10× worker RAM before claiming storage independence; no PB-scale claim from extrapolation |

G0 instruments full-path latency and resource/cost feasibility before adopting targets. Measure actual end-to-end distributions and distinguish queue, object requests/CAS, computation, durability, pin validation, storage, serialization and network. Do not sum component percentiles or hide mandatory work. Establish comparable CPU, memory/state, write, network/request, recovery and dormant-cost baselines using [implementation start](implementation-start.md); adjust proposed profiles/targets from evidence without weakening guarantees.

The [six G0 feasibility decisions](qualification.md#g0-feasibility-decisions) make batching/read-pin amortization, clone-versus-attempt isolation, checkpoint amortization, bounded reconstruction, runtime selection, donor correctness, sharing economics and full hibernation explicit requirements. Freeze numeric profile budgets before confirmatory runs and record a fallback for each failed or inconclusive candidate. Logical epochs need not correspond one-to-one with physical checkpoints or metadata writes. This is an optimization obligation under the existing invariants, not permission to acknowledge undurable state or drop promised history.

Use both **source-to-publication freshness** (when an authoritative source commit time is trustworthy) and **durable-input-to-publication latency** (Rockstream-controlled boundary). Missing source timestamps are unknown, not zero lag. Client visible latency includes waiting, protocol, and network. Report stalled epochs, oldest incomplete transaction, rejected inputs, source-retention headroom, and output-amplification tails beside percentiles.

Freeze the denominator before comparing systems: one **unique change** is one source logical row mutation identified before normalization. An UPDATE counts once, even when represented internally as a retraction plus insertion. Replay, redelivery, and initial snapshot setup are excluded from the live-change denominator and reported separately; a transaction containing ten row mutations contributes ten changes. Also report transaction throughput and output amplification.

For `N` unique durable changes whose promised results are verified complete in an interval:

`cost_per_million = total_attributable_cost / (N / 1,000,000)`.

Include source infrastructure attributable to the test, ingress, metadata, maintenance, serving, compaction, object requests and storage, cross-zone transfer, retained logs/history, backups, activation infrastructure if used, and failover headroom. Count replay work as cost, not new user changes. Idle/bursty comparisons include stop/start cycles, cold reconstruction, retained history, and the time needed to catch up to the same freshness promise. At the run boundary, report accepted-but-unpublished changes explicitly; drain and verify them with the drain time/cost included, or exclude them from completed-work throughput and fail a sustained-run claim with growing backlog. A predeclared meaningful regression on any protected workload blocks an unqualified “better” claim; report a profile-specific improvement or fix the regression.

## 7. Nonfunctional requirements

Correctness and performance testing use replaceable clocks, networking, storage, metadata, randomness, and failure injection. Authentication and authorization apply before catalog access and before plan activation. Durable state and transports use encryption appropriate to the deployment profile; secrets never appear in explain plans or ordinary logs. Tenant budgets cover memory, CPU, state, history, network and storage requests, including shared resources.

Formats have explicit versions, feature bits, compatibility readers and corruption checks. Experimental formats are explicitly disposable or unsupported, with isolated state and explicit reset/migration; preview and production profiles declare their supported compatibility/rollback window. Never silently reinterpret or discard durable state promised by a profile. A rolling upgrade cannot rewrite away the rollback format until the rollback window closes. Backup qualification includes restore into an empty environment and exact result verification. Operational interfaces report the dependency responsible for staleness and distinguish data corruption, unavailable state, unsupported SQL, insufficient budget, and expired history.

Logical MVCC retention is a budgeted resource. For a domain, exclusive cut `C` includes epochs `e < C`. A computed upper is not a published durable upper. An advertised retention interval `[S, Cp]` includes the base cut `S` and durable published cut `Cp`; a retained base plus timestamped history must reconstruct every promised cut in it. Explicit coverage gaps cannot be filled by assuming that an endpoint checkpoint preserves nonlinear intermediate results. Consumer pins, retained deltas and reconstruction work are charged to their obligations; exhausted retention may reject/expire a consumer or require resnapshot under its declared contract, but cannot silently sacrifice a valid pin. Pin revocation is an authoritative metadata transition, and successful read completion validates the pin against that authority; elapsed wall time alone cannot authorize reclamation or a successful read.

Customer data lifecycle distinguishes row deletion, history expiry, object/tenant retirement, access revocation, backup expiration and verified physical reclamation. Account for accepted input, history, shared state, pins, sinks, backups, versions and key dependencies. A logical DELETE is not an erasure promise. Decommission explicitly, fence old workers, preserve contracted obligations, prevent unintended re-exposure on restore and report retained copies/blockers. See [consistency and storage](../design/consistency-and-storage.md). No unqualified compliance or physical deletion deadline is implied.

### Engineering quality and feedback objectives

The [testing and verification architecture](../design/testing-and-verification.md) and [development workflow](../design/development-workflow.md) govern these proposed, unmeasured targets from G0. Measure and refine budgets using actual build, queue and test telemetry; never trade a known correctness violation or necessary evidence for speed.

| Objective | Initial target |
| --- | --- |
| Focused local feedback | 1–10 seconds on warm focused development builds |
| Required ordinary PR CI | Median under 5 minutes, P95 under 10 minutes, including queue |
| Small ready issue to merge | Under one hour where practical; track review/CI separately |
| Critical invariants | All mapped to meaningful independent verification, with gaps explicit |
| Deterministic failures | Reproducible with recorded seed/trace; zero tolerated deterministic flakes |
| Correctness defects | Regression evidence for every fix; zero known correctness violations in releases |
| Deep verification | Continuous budgeted exploration, scheduled real-dependency/scale checks, exact-candidate release evidence and actionable background failure triage |
| Agent delivery capacity | G0 baseline of accepted issue throughput, lead-time distributions, review/decision wait, rework/reverts, agent/CI spend per accepted change and escaped defects; tune WIP without weakening gates |
| Maintainability and performance | Enforced dependency rules; measurable resource/benchmark baselines and diagnosable public/operational failures from first executable slice |
| Reproducible development and release | Clean bootstrap, pinned build inputs, dependency checks, artifact provenance and protected signing/attestation; independently checked before promotion |

## 8. Definition of a release

A release names its supported SQL/connector profiles, failure model, on-disk and protocol compatibility, measured operating envelope, known limits and reproducible evidence bundle. A passing unit test is necessary evidence for some requirements, but does not promote a distributed, connector, cost or production guarantee. Rockstream 2 replaces an existing workload only after its migration-specific capability parity and rollback gates pass.
