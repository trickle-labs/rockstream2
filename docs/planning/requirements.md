# Product requirements and success criteria

**Status:** Proposed, 2026-11-25. All targets are qualification goals; none are measured Rockstream 2 results. Read with the [design](../../DESIGN.md), [SQL contract](../reference/sql-and-apis.md), and [qualification plan](qualification.md).

## 1. Users and workloads

| User | Job | Representative workload | Critical constraint |
| --- | --- | --- | --- |
| Application developer | Query a current application read model without repeatedly rebuilding it | Customer balance, entitlement membership, inventory availability | Transaction-consistent reads, predictable errors, read-your-writes |
| Data/platform engineer | Maintain changing relational transformations | CDC joins, grouped metrics, view-on-view pipelines | Replayable ingestion, schema evolution, cost and recovery visibility |
| Cloud operator | Meet freshness and read SLOs without permanent overprovisioning | Many tenants, large retained state, independent read pools | Isolation, bounded failure impact, upgrades, backups, resource attribution |
| Advanced analyst, later | Maintain expensive connected or temporal computations | Multiway aggregates, bounded recursive reachability, expiring sessions | Explicit algorithm eligibility, termination, retractions, state bounds |

Initial design partners should supply at least three concrete workloads: a transactional application projection, a join-heavy CDC analytical pipeline, and hundreds of overlapping maintained views. Freeze representative SQL, input distribution, update/delete mix, transaction sizes, retained history, read load, and failure budget before optimizing.

## 2. Priorities

**P0: semantic correctness, durable acknowledgements, consistent visibility, recovery, explicit support boundaries, and bounded resource behavior.** A faster result that silently changes the query, loses acknowledged input, drops a row, or mixes snapshots fails qualification.

**P1: lower total cost at a declared freshness SLO, shared-state efficiency, independent serving, usable SQL, observability, and safe lifecycle changes.** Improvements must be measured against the pinned original engine on supported common workloads.

**P2: advanced algorithms and broader SQL.** The architecture reserves contracts for recursion, temporal processing, factorization and adaptive planning. Feature breadth earns promotion through correctness and workload evidence, not an operator count.

## 3. Functional requirements

| ID | Requirement | First gate | Acceptance evidence |
| --- | --- | --- | --- |
| FR-01 | Maintain weighted bag relational queries with insert, update, delete and duplicates | G1 | Independent batch oracle at every completed logical time |
| FR-02 | Admit and durably acknowledge complete transactions with stable replay identity | G2 | Ambiguous acknowledgement and restart transcript |
| FR-03 | Publish complete input/state/output versions atomically within a domain | G2 | Crash-boundary, omitted-participant and stale-owner negative controls |
| FR-04 | Serve latest, result-fenced and repeatable pinned reads through pgwire | G2 | Protocol transcript proves snapshot and write-token meaning |
| FR-05 | Share compatible arrangements and subexpressions | G3 | Same results, one shared state lineage, lower measured total resource cost |
| FR-06 | Build, replace and drop views while unrelated readers continue | G3 | Snapshot/backfill/catch-up/cutover trace, cancellation and recovery |
| FR-07 | Support retained historical snapshots and resumable snapshot-plus-delta subscriptions | G3 | No gap, explicit duplicates on retry, exact cursor-expiry behavior |
| FR-08 | Qualify PostgreSQL CDC and Kafka inputs; provide Kafka delivery with an explicit guarantee tier | G3 | Live connector failover, source truncation, large transaction and sink-ambiguity tests |
| FR-09 | Independently progress unrelated domains and independently size serving/maintenance pools | G4 | Stalled domain isolation and concurrent query-load qualification |
| FR-10 | Reassign virtual partitions safely; split/merge only at a versioned routing boundary | G4 | Old-owner resurrection, mixed-routing, cold-restoration and scale tests |
| FR-11 | Explain maintenance strategy, retained state, reuse, cost estimates and freshness blockers | G3–G4 | Explain and system-table assertions tied to executed plans |
| FR-12 | Add advanced SQL/algorithms without changing the semantic or publication kernel | G5 | Feature-specific oracle, state and performance promotion gate |
| FR-13 | Operate rolling upgrades, restore, failover, quotas and eligible pool suspension | G6 | Automated operational drills against supported profiles |

## 4. Guarantees and limits

| Boundary | Required guarantee | Explicit limit |
| --- | --- | --- |
| Direct writes / source → durable input | Deduplicated logical ingestion within the connector's declared identity and retention contract | A lost response requires status lookup/retry; expired dedupe identities cannot be silently reused |
| Durable input → published views | Exact logical effects and atomic domain visibility | Freshness is conditional on recoverable inputs and admitted capacity |
| Multi-table source transaction | All subscribed tables in the transaction domain advance together | No implied atomicity between unrelated external databases |
| Cross-domain reads | Dependency-compatible version set with explicit source lineage | No arbitrary “latest from each”; unavailable compatible cut waits or fails |
| Subscription transport | Initial snapshot and all subsequent committed deltas, with stable cursors | Unacknowledged envelopes may repeat; retention expiry is an error requiring rebootstrap |
| External sink | The guarantee actually provided by destination and protocol | No unconditional exactly-once claim for nontransactional side effects |
| Numeric results | Exact checked integer/decimal semantics; documented floating approximation | Floating reassociation is not bitwise equivalence; overflow stops the affected publication |
| Failure | No loss of acknowledged durable input or published data within the qualified failure model | Simultaneous loss of all authoritative copies or unprotected regional loss requires DR guarantees, not a compute-restart promise |

The first direct-write API serializes transactions within one domain and rejects cross-domain atomic writes. It does not promise PostgreSQL's complete isolation, locking, stored procedures, or catalog behavior. Compatible syntax and the pgwire transport are separately testable from semantic compatibility.

## 5. Deployment profiles

| Profile | Intended use | Durability and availability claim |
| --- | --- | --- |
| Ephemeral developer | Fast tests and examples | No durable-acknowledgement claim; explicitly named mode |
| Embedded durable | Local durable engine, integration tests, small deployments | Process-crash recovery with fsync-capable local durable state; whole disk/host loss requires a backup |
| Cloud object-store | Initial production target | Object-store durable data and three-voter metadata across three failure zones; fail closed without metadata quorum |
| Cloud latency tier, candidate | Tight freshness/durable-input latency | Adds a replicated log only after measured need; same publication meaning and explicitly qualified failure model |

Each profile exposes its failure model in catalog/system metadata and documentation. Embedded and cloud modes share semantics, but their infrastructure durability is not equivalent. Single-binary convenience must not disguise single-machine loss risk.

## 6. Measurements that define “better”

Every result specifies workload, commit, hardware, topology, data scale, source/output amplification, retention, durability profile, load, and error rate. The benchmark harness records both offered and achieved input rate and does not omit timeouts from latency reports.

| Dimension | Proposed qualification target | Qualification scope / caveat |
| --- | --- | --- |
| Correctness | Zero unexplained exact-result, atomicity, or durable-acknowledgement violations | All promoted capabilities and declared failures; finite testing is not proof of the whole system |
| Freshness | P99 ≤ 100 ms aspirational low-latency profile; first cloud profile publishes its measured envelope | Small admitted transactions, warm working set, fixed read load and output amplification; replicated durability may be required |
| Indexed reads | P99 ≤ 5 ms server-side execution on warm indexed point/range reads | Also publish client end-to-end latency, bytes and network placement; does not promise a 5 ms Internet round trip |
| Scaling | `Q16 / (16 × Q1) ≥ 0.80` | Partitionable fixed-query workload, bounded backlog/debt, same worker class and per-worker resources |
| Sharing | ≥ 2× lower maintained-state bytes on the designated 100-view overlapping workload; pursue 10× on favorable workloads | Include retention, catalog, CPU and catch-up cost; 10× is a stretch goal, not generic compression |
| Cost | ≥ 30% lower total cost per million correct durable changes on two chosen design-partner workloads | Proposed business gate; both systems meet identical semantics, SLO, availability, serving and retention constraints |
| Mixed serving | Maintenance qualified throughput decreases by ≤ 10% under the specified isolated read-pool load | Includes object-store/cache/network contention; hardware and read QPS frozen in profile |
| Failover | Published results remain readable when their protected snapshot is available; recovery target established from measured retained state | Working-set size, metadata election and replay volume determine RTO; no universal cold-start number |
| Long-running stability | 72-hour mixed-load soak with bounded backlog, compaction debt, history and memory | Corrections and restarts included; no hiding growing debt after a short peak |
| Capacity | State beyond RAM in the first cloud release; petabyte scale as a long-term qualification ladder | Test 1×, 4× and 10× worker RAM before claiming storage independence; no PB-scale claim from extrapolation |

Use both **source-to-publication freshness** (when an authoritative source commit time is trustworthy) and **durable-input-to-publication latency** (Rockstream-controlled boundary). Missing source timestamps are unknown, not zero lag. Client visible latency includes waiting, protocol, and network. Report stalled epochs, oldest incomplete transaction, rejected inputs, source-retention headroom, and output-amplification tails beside percentiles.

Freeze the denominator before comparing systems: one **unique change** is one source logical row mutation identified before normalization. An UPDATE counts once, even when represented internally as a retraction plus insertion. Replay, redelivery, and initial snapshot setup are excluded from the live-change denominator and reported separately; a transaction containing ten row mutations contributes ten changes. Also report transaction throughput and output amplification.

For `N` unique durable changes whose promised results are verified complete in an interval:

`cost_per_million = total_attributable_cost / (N / 1,000,000)`.

Include source infrastructure attributable to the test, ingress, metadata, maintenance, serving, compaction, object requests and storage, cross-zone transfer, retained logs/history, backups, and failover headroom. Count replay work as cost, not new user changes. At the run boundary, report accepted-but-unpublished changes explicitly; drain and verify them with the drain time/cost included, or exclude them from completed-work throughput and fail a sustained-run claim with growing backlog. A predeclared meaningful regression on any protected workload blocks an unqualified “better” claim; report a profile-specific improvement or fix the regression.

## 7. Nonfunctional requirements

Correctness and performance testing use replaceable clocks, networking, storage, metadata, randomness, and failure injection. Authentication and authorization apply before catalog access and before plan activation. Durable state and transports use encryption appropriate to the deployment profile; secrets never appear in explain plans or ordinary logs. Tenant budgets cover memory, CPU, state, history, network and storage requests, including shared resources.

Formats have explicit versions, feature bits, compatibility readers and corruption checks. A rolling upgrade cannot rewrite away the rollback format until the rollback window closes. Backup qualification includes restore into an empty environment and exact result verification. Operational interfaces report the dependency responsible for staleness and distinguish data corruption, unavailable state, unsupported SQL, insufficient budget, and expired history.

## 8. Definition of a release

A release names its supported SQL/connector profiles, failure model, on-disk and protocol compatibility, measured operating envelope, known limits and reproducible evidence bundle. A passing unit test is necessary evidence for some requirements, but does not promote a distributed, connector, cost or production guarantee. Rockstream 2 replaces an existing workload only after its migration-specific capability parity and rollback gates pass.
