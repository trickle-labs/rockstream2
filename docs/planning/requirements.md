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

Start with the narrow product and [golden workload W1-G](implementation-start.md), not speculative feature breadth. Continuous design-partner engagement from G0 onward captures real workload manifests and prioritizes capabilities without blocking G0/G1 execution; the synthetic fixture is not partner evidence. Preview and production support envelopes are declared separately; G6 remains required for production.

For each partner workload, keep one versioned decision record that makes the evidence change implementation order:

| Decision field | Required content |
| --- | --- |
| User outcome and baseline | Named user job, current system/revision, migration reason and a repeatable comparison |
| Frozen contract | SQL/query shapes, source/update distribution, freshness/read SLOs, history, recovery and availability requirements |
| Cost and limiting resource | Measured dominant work and full-cost breakdown, with estimates and missing evidence labelled |
| Minimum capability set | Required operators/connectors and owning work IDs; identify any narrowly scoped G5 subset needed for that workload |
| Protected cases | Workloads, skew/delete cases and operational obligations whose predeclared regression limits must hold |
| Decision | Proceed, narrow or stop, with owner, evidence and the next falsifiable acceptance criterion |

Choose one initial user journey to order the first complete slice while retaining the three partner workload classes and the G6 two-workload business gate. A missing outer join, DISTINCT or Top-K requirement can reorder an existing capability package after its prerequisites and qualification are met; it does not justify implementing all of G5. Keep the declared success targets below until evidence supports a reviewed change.

## 2. Priorities

**P0: semantic correctness, durable acknowledgements, consistent visibility, recovery, explicit support boundaries, bounded resource behavior, and simple operation.** A faster result that silently changes the query, loses acknowledged input, drops a row, or mixes snapshots fails qualification. The supported cloud baseline must run with Rockstream binaries and a qualified object store, with no mandatory etcd, ZooKeeper, Redis, PostgreSQL catalog, or dedicated always-on control tier. Eligible deployments must be able to suspend all Rockstream compute and recover from durable state; this is an early design requirement.

**P1: lower total cost at a declared freshness SLO, shared-state efficiency, independent serving, usable SQL, observability, and safe lifecycle changes.** Improvements must be measured against the pinned original engine on supported common workloads.

**P2: advanced algorithms and broader SQL.** The architecture reserves contracts for recursion, temporal processing, higher-order maintenance and adaptive planning. Table-stakes SQL (`LEFT OUTER JOIN`, `DISTINCT`, semi/anti joins, delete-safe `MIN`/`MAX`) graduates in G3a, and bounded eligible partial aggregation/factorization graduates behind measured eligibility rules in G3b; general advanced strategies and automated cost-model advisory remain separately gated in G5. Feature breadth earns promotion through correctness and workload evidence, not an operator count.

Engineering quality, maintainability, simplicity and low issue-to-merge lead time are cross-cutting requirements, not optional feature work. Autonomous coding agents are the primary implementation workforce under the [agent operating model](../design/agent-development.md). Human maintainers retain safety/architecture and release authority; ordinary issues should not require manual approvals beyond their risk tier. Design for extensive deterministic tests, independent oracles, and focused real-dependency/public-path checks. Run deeper verification continuously outside the ordinary PR critical path; retain risk-based required checks and full release qualification.

## 3. Functional requirements

| ID | Requirement | First gate | Acceptance evidence |
| --- | --- | --- | --- |
| FR-01 | Maintain weighted bag relational queries with insert, update, delete and duplicates | G1 | Independent batch oracle at every completed logical time |
| FR-02 | Admit and durably acknowledge complete transactions with stable replay identity | G2 | Ambiguous acknowledgement and restart transcript |
| FR-03 | Publish complete input/state/output versions atomically within a domain | G2 | Crash-boundary, omitted-participant and stale-owner negative controls |
| FR-04 | Serve latest, result-fenced and repeatable pinned reads through pgwire | G2 | Protocol transcript proves snapshot and write-token meaning |
| FR-05 | Share compatible arrangements and subexpressions across independently scheduled consumers, with explicit/rule-based isolation | G3b | Same results at every promised cut, independent consumer budgets, verified snapshot/replay/cutover and retention handoff; deterministic rule-based share-vs-isolate placement |
| FR-06 | Build, replace and drop views while unrelated readers continue | G3a | Snapshot/backfill/catch-up/cutover trace, cancellation and recovery |
| FR-07 | Support retained historical snapshots and resumable snapshot-plus-delta subscriptions | G3a (subscriptions), G3b (multi-cadence MVCC) | No gap, explicit duplicates on retry, exact cursor-expiry behavior |
| FR-08 | Qualify PostgreSQL CDC (with benign additive-DDL tolerance) and Kafka inputs; provide Kafka delivery with an explicit guarantee tier | G3a | Live connector failover, additive vs. breaking DDL handling, source truncation, large transaction and sink-ambiguity tests |
| FR-09 | Distribute independently progressing result domains and independently size serving/maintenance pools (with cache-affinity routing) | G4; local independent groups in G3b | Stalled domain isolation and concurrent query-load qualification |
| FR-10 | Reassign virtual partitions safely; split/merge only at a versioned routing boundary | G4 | Old-owner resurrection, mixed-routing, cold-restoration and scale tests |
| FR-11 | Explain maintenance strategy, retained state, reuse, fanout/amplification and freshness blockers | G3b–G4 (monetary cost advisor in G5) | Explain and system-table assertions tied to executed plans; eligibility and rejection reasons, enforced keys vs. stats; automated monetary advisor and plan replacement remain P5.6 |
| FR-12 | Add advanced SQL/algorithms without changing the semantic or publication kernel | G3a (table-stakes SQL) & G5 (advanced) | Feature-specific oracle, state and performance promotion gate |
| FR-13 | Operate rolling upgrades, disaster restore, failover and quotas | G6 | Automated operational drills against supported profiles |
| FR-14 | Preserve exact logical MVCC cuts independently of physical checkpoint cadence | G2; shared-consumer qualification in G3b | Distinct computed/published uppers, nearest-checkpoint + bounded immutable delta overlay reconstruction, and explicit unavailable-history errors |
| FR-15 | Suspend eligible Rockstream compute and resume safely without an external coordination service | G2 local/single-process; G3b shared obligations; G4 distributed | No remaining Rockstream process required while dormant; new activation fences old owners and recovers accepted input, publications, timers and consumer obligations |

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

### Intentional non-goals (anti-features)

Following [FoundationDB's distinction between core features and anti-features](https://apple.github.io/foundationdb/anti-features.html), preserve the following product boundaries unless a reviewed product/architecture decision changes them:

- Rockstream is a SQL-first incremental database, not a general distributed-compute framework or an unrestricted OLTP replacement. No arbitrary user code in the correctness-critical execution path or implied transactions spanning independent source systems.
- No unbounded transactions, resource consumption, retry windows or historical retention promises. Define supported envelopes and explicit errors/backpressure; chunk physical work without splitting a promised atomic logical transaction or losing an accepted obligation.
- No requirement for a separately operated coordination service or always-running Rockstream quorum in the default object-native profile; full suspension is conditional on durable protection and a documented activation mechanism.
- No weaker correctness mode that silently skips input, truncates output, reads an incompatible cut or reclaims protected state in order to improve availability, cost or latency.

Distinguish these principles from initial release limits. One active maintenance interval per domain, one metadata root, bounded scalar acyclic execution, no general cross-domain atomic writes, and limited SQL capabilities are deliberate initial constraints; widening them requires a use case, measured benefit where relevant, a reviewed contract and qualification. They are not promises to implement every generalization or permanent exclusions. Record unsupported behavior explicitly instead of prebuilding speculative abstractions.

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

An accelerated storage tier declares whether it holds authority or reconstructible copies. Authoritative bytes require protection against the selected failure envelope before acknowledgement/publication; a single-zone tier alone cannot satisfy a zone-loss cloud profile. Qualify loss of the fast tier and include replication, transfer, idle and recovery costs. A separately named weaker profile cannot count as an equivalent-guarantee performance win. [ADR 0011](../adr/0011-risk-reduction-before-implementation.md) gives the concrete tier-selection constraint.

The initial cloud metadata design is one authoritative, conditionally updated root pointing to immutable metadata objects, using pre-allocated owner-generation namespaces, out-of-root worker heartbeats, compositional intra-batch serialization, and monotonic lease-backed fast reads protected by sweeper-observed GC grace windows (`Δ_gc_grace >> Δ_read_lease`). G0.2 qualifies compositional group commits, per-operation retry outcomes, bounded serving/maintenance overlays, and warm vs. strict-latest read latencies on real object storage. Declare logical scopes while retaining one root. A conditional update of one object is not a transaction over independent roots. Throughput failure can trigger partitioning research and strict-read/metadata-latency needs trigger the optional G4+ Embedded OpenRaft profile (recognizing that `≤100 ms` P99 cloud freshness also requires a fast cross-AZ WAL data tier), each with separate correctness, durability, and stop/restart qualification. Qualify strong read/conditional-write behavior, lost-response recovery, and fencing for each supported provider; “S3 compatible” alone does not qualify a backend. Reuse SlateDB transactional-object primitives only if current-version discovery avoids `ListObjects` on the read path. Embedded mode needs its own crash-safe local implementation of the same logical transitions.

Scale-to-zero eligibility is workload-specific. Continuous CDC needs live ingestion or a qualified upstream retention and activation contract; freshness deadlines, pending sink delivery, durable clock inputs and history pins remain obligations. An inactive system needs an external caller, operator or hosting platform to launch a process, but no particular launcher or Kubernetes installation is mandatory. Report the remaining storage, source-retention and optional activation costs. Zero Rockstream compute does not mean zero total cost or immediate response after activation.

## 6. Measurements that define “better”

Every result specifies workload, commit, hardware, topology, data scale, source/output amplification, retention, durability profile, load, and error rate. The benchmark harness records both offered and achieved input rate and does not omit timeouts from latency reports.

| Dimension | Proposed qualification target | Qualification scope / caveat |
| --- | --- | --- |
| First maintained view | Within 5 minutes on a prepared supported local environment, aspirational | Include initialization, authenticated connection, SQL creation, update, publication wait and exact query; record installation and cloud cold start separately; qualify from G2 |
| Correctness | Zero unexplained exact-result, atomicity, or durable-acknowledgement violations | All promoted capabilities and declared failures; finite testing is not proof of the whole system |
| Freshness | **Object-Native default:** ~150 ms–1.5 s measured S3 envelope (with pre-allocated owner namespaces); **Low-Latency Cloud (G4+ Embedded OpenRaft):** ~100–300 ms on S3 Standard segments, or P99 `≤100 ms` only with an optional separately qualified cross-AZ fast WAL tier | Small admitted transactions, warm working set, fixed read load and output amplification; honest separation of metadata vs. data-plane durability physics |
| Indexed reads | **Bounded-staleness / Allowed-stale (warm cache):** P99 `≤5 ms` target (0 post-read S3 round trips via `Δ_gc_grace` + post-read monotonic deadline check); **Strict latest (Object-Native):** ~20–60 ms S3 root check; **Strict latest (Embedded OpenRaft):** `≤10 ms` target | Includes selection, lease/pin checks, bounded delta overlay merge, and data access; `strict-immediate-revocation` is an explicit opt-in with its own latency profile |
| Scaling | `Q16 / (16 × Q1) ≥ 0.80` | Partitionable fixed-query workload, bounded backlog/debt, same worker class and per-worker resources |
| Sharing | ≥ 2× lower maintained-state bytes on the designated 100-view overlapping workload; pursue 10× on favorable workloads | Include retention, catalog, CPU and catch-up cost; 10× is a stretch goal, not generic compression |
| Cost | ≥ 30% lower total cost per million correct durable changes on two chosen design-partner workloads | Proposed business gate; both systems meet identical semantics, SLO, availability, serving and retention constraints |
| Mixed serving | Maintenance qualified throughput decreases by ≤ 10% under the specified isolated read-pool load | Includes object-store/cache/network contention; hardware and read QPS frozen in profile |
| Failover | Published results remain readable when serving compute and protected data are available; bounded-staleness and allowed-stale warm reads continue serving within their valid lease (`Δ_read_lease << Δ_gc_grace`) even during brief metadata hiccups | Working-set size and replay volume determine recovery envelope; no universal cold-start number |
| Idle operation | Stateless compute scales to zero on all cloud profiles; full zero-process hibernation supported on Object-Native for eligible workloads | Publish cold-resume latency, replay/catch-up cost, remaining storage/source costs and activation mechanism; continuous CDC/sink profiles use partial suspension or Low-Latency Cloud |
| Long-running stability | 72-hour mixed-load soak with bounded backlog, compaction debt, history and memory | Corrections and restarts included; no hiding growing debt after a short peak |
| Capacity | State beyond RAM in the first cloud release; petabyte scale as a long-term qualification ladder | Test 1×, 4× and 10× worker RAM before claiming storage independence; no PB-scale claim from extrapolation |

G0 instruments full-path latency and resource/cost feasibility before adopting targets. Measure actual end-to-end distributions and distinguish queue, object requests/CAS, computation, durability, pin validation, storage, serialization and network. Record causally ordered authority/durability operations and measure sparse singleton as well as sustained/burst load; group commit may reduce request cost without meeting singleton latency. Accelerating metadata does not remove durable input/state operations. Do not sum component percentiles or hide mandatory work. Establish comparable CPU, memory/state, write, network/request, recovery and dormant-cost baselines using [implementation start](implementation-start.md); adjust proposed profiles/targets from evidence without weakening guarantees.

The [lean G0 kill-switch decisions](qualification.md#g0-feasibility-decisions) (`G0.1`–`G0.4`) prove compositional S3 metadata batching, lease-backed fast reads, immutable-delta + SlateDB working index physics, Quint protocol safety, and the native `W1-G` kernel before building the full engine. Sharing-scale economics (100/1,000 views) qualify in G3 where sharing actually exists, and full distributed hibernation qualifies in G4. Logical epochs never require one-to-one physical checkpoints or metadata writes.

Use both **source-to-publication freshness** (when an authoritative source commit time is trustworthy) and **durable-input-to-publication latency** (Rockstream-controlled boundary). Missing source timestamps are unknown, not zero lag. Client visible latency includes waiting, protocol, and network. Report stalled epochs, oldest incomplete transaction, rejected inputs, source-retention headroom, and output-amplification tails beside percentiles.

Freeze the denominator before comparing systems: one **unique change** is one source logical row mutation identified before normalization. An UPDATE counts once, even when represented internally as a retraction plus insertion. Replay, redelivery, and initial snapshot setup are excluded from the live-change denominator and reported separately; a transaction containing ten row mutations contributes ten changes. Also report transaction throughput and output amplification.

For `N` unique durable changes whose promised results are verified complete in an interval:

`cost_per_million = total_attributable_cost / (N / 1,000,000)`.

Include source infrastructure attributable to the test, ingress, metadata, maintenance, serving, compaction, object requests and storage, cross-zone transfer, retained logs/history, backups, activation infrastructure if used, and failover headroom. Count replay work as cost, not new user changes. Idle/bursty comparisons include stop/start cycles, cold reconstruction, retained history, and the time needed to catch up to the same freshness promise. At the run boundary, report accepted-but-unpublished changes explicitly; drain and verify them with the drain time/cost included, or exclude them from completed-work throughput and fail a sustained-run claim with growing backlog. A predeclared meaningful regression on any protected workload blocks an unqualified “better” claim; report a profile-specific improvement or fix the regression.

## 7. Nonfunctional requirements

Correctness and performance testing use replaceable clocks, networking, storage, metadata, randomness, and failure injection. Authentication and authorization apply before catalog access and before plan activation. Durable state and transports use encryption appropriate to the deployment profile; secrets never appear in explain plans or ordinary logs. Tenant budgets cover memory, CPU, state, history, network and storage requests, including shared resources.

Formats have explicit versions, feature bits, compatibility readers and corruption checks. Experimental formats are explicitly disposable or unsupported, with isolated state and explicit reset/migration; preview and production profiles declare their supported compatibility/rollback window. Never silently reinterpret or discard durable state promised by a profile. A rolling upgrade cannot rewrite away the rollback format until the rollback window closes. Backup qualification includes restore into an empty environment and exact result verification. Operational interfaces report the dependency responsible for staleness and distinguish data corruption, unavailable state, unsupported SQL, insufficient budget, and expired history.

Logical MVCC retention is a budgeted resource. For a domain, exclusive cut `C` includes epochs `e < C`. A computed upper is not a published durable upper. An advertised retention interval `[S, Cp]` includes the base cut `S` and durable published cut `Cp`; within `[S_hot, Cp]`, periodic SlateDB checkpoints plus per-epoch immutable deltas reconstruct every promised cut via nearest-checkpoint overlay lookups. Explicit coverage gaps cannot be filled by assuming that an endpoint checkpoint preserves nonlinear intermediate results. Consumer pins, retained deltas, and reconstruction work are charged to their obligations; exhausted retention may reject/expire a consumer or require resnapshot under its declared contract, but cannot silently sacrifice a valid pin. Durable pins are revoked through an authoritative metadata transition; short bounded reads rely on a valid local lease checked against `monotonic_now() < lease_deadline` before flushing the response and protected by the sweeper-observed GC grace window (`Δ_gc_grace`), while `strict-immediate-revocation` performs synchronous post-read root validation.

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
