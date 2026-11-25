# Implementation start: product experience and G0 execution

**Status:** Proposed, 2026-11-25. Final pre-implementation brief, not a new design phase, an executed workload, created issues or a delivery forecast. Start executable work after design approval. The [implementation plan](implementation-plan.md) remains the gate/dependency authority; [requirements](requirements.md) and [design](../../DESIGN.md) govern contracts.

## 1. The smallest exceptional Rockstream

Focus on a narrow SQL-first streaming database that maintains correct durable results, is easy to operate and is demonstrably efficient. An explicitly scoped public preview may follow applicable G2/G3 evidence; it is not a production-readiness claim. G6 remains the production release gate with existing G0–G4 prerequisites. Complete foundational SQL, exact retractions, durable acceptance, consistent reads, restart, bounded resources and full suspension for eligible workloads before adding broad syntax or connector coverage. Shared state, independent schedules, cloud distribution and existing planned connectors remain on their specified gates. G5 research does not hold up a deliberately scoped release.

Select the first design-partner application read-model, CDC analytical and overlapping-view workloads under P0.5; prioritize query shapes and deployment requirements from actual partner evidence. Until then use the synthetic golden fixture below, not invented customer requirements or benchmark claims. Existing migration and rollback gates remain binding.

### Target user journey

Obtain one binary (or a supported container image), start an isolated local database with one documented command, connect using standard PostgreSQL tooling, create tables and a maintained view, commit a transaction, wait for its result under the declared consistency policy and query the exact result. Restart and verify durable state. A second example moves the same logical workload to qualified object storage through explicit configuration, identities and supported replay/export; changing a storage URL is not a data migration or durability upgrade.

Aim for **five minutes from a clean supported environment with the binary and client available to the first correct maintained view and observed update**, including initialization, authentication, SQL setup and required publication wait. Record prerequisites; separately measure artifact installation, cloud cold start, errors and unsuccessful setup attempts. This is an aspirational usability goal, not measured behavior or permission to bypass safety. Qualify the local quickstart at G2, extend with real sources and sharing at G3 and cloud diagnostics at G4/G6. Examples become executable conformance assets; do not present proposed commands as runnable.

Provide explicit profile/guarantee labels, validated configuration, understandable unsupported-feature errors and SQL/CLI diagnostics explaining stalled freshness, retained history, resource use, recovery and sleep eligibility. Stop/resume, credentials, backup/restore and destructive actions must be explicit. Do not expose unauthenticated network access or require an external control service for convenience.

### Narrow initial platform matrix

| Dimension | Initial qualification scope |
| --- | --- |
| Development | Linux canonical CI/agent environment; macOS developer candidate, qualified separately before promising support |
| Server | One Linux target/architecture; Linux x86-64 starting candidate, not a compatibility claim |
| Local persistence | One specified filesystem, mount/sync and failure profile |
| Cloud persistence | One named provider, region and API/configuration profile selected in G0 from real primitive, performance and cost evidence |
| Client | PostgreSQL wire, named driver/tool versions and declared SQL subset |
| Packaging | Standalone binary and container image for the qualified target, with provenance; no mandatory Kubernetes |
| Topology | Single process first, multiple instances of the same binary at G4; no hidden always-running coordinator |

G0 selects and records exact versions and backend. Add providers, architectures, filesystems and deployment targets when demand and qualification cost justify them. Emulators and macOS runs are useful tests, not evidence of Linux/cloud durability. An S3-compatible API name alone does not establish support.

## 2. Canonical golden workload W1-G

Use the same small customer/orders join-aggregate throughout G0–G6. This is a fixed proposed fixture, not executed engine output. Handwritten expected rows and an independent batch evaluator check the production path; do not derive expected answers from incremental code. Complement with generated histories and the full [qualification portfolio](qualification.md).

Logical schemas: customers(customer_id BIGINT key, region binary-collated text); orders(order_id BIGINT key, customer_id BIGINT, amount DECIMAL(18,2)); all fields non-NULL. Every order has an existing customer in this fixture; no foreign-key enforcement claim. Both tables share one transaction domain. Ordinary batch SQL defines the intended maintained result (materialized view syntax follows [SQL and APIs](../reference/sql-and-apis.md)):

```sql
SELECT c.region, COUNT(*) AS order_count, SUM(o.amount) AS revenue
FROM customers c JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.region;
```

Start empty. A published cut C contains complete epochs e < C. Each numbered epoch is one atomic transaction; updates/deletes carry normalized preimages. Expected outputs are complete unordered multisets, each listed row with multiplicity one. Numeric result types follow the G0 type matrix; values are exact decimals. A dash means no result rows, not a NULL aggregate.

| Epoch | Complete transaction | Published cut | Expected (region, order_count, revenue) |
| --- | --- | --- | --- |
| None | Empty relations | 0 | — |
| 0 | Insert customers (1, North), (2, South); insert orders (101, 1, 10.00), (102, 1, 20.00), (103, 2, 7.00) | 1 | (North, 2, 30.00); (South, 1, 7.00) |
| 1 | Move customer 1 to South; change order 102 amount to 25.00; delete order 103; insert order (104, 2, 4.00) | 2 | (South, 3, 39.00) |
| 2 | Delete order 101; move customer 2 to North; change order 104 amount to 6.00 | 3 | (North, 1, 6.00); (South, 1, 25.00) |
| 3 | Delete orders 102 and 104 | 4 | — |

Epochs 1 and 2 change both join inputs in one transaction, exercising cross-terms and retractions. No reader may observe a partial transaction. The last epoch removes the final groups. Test empty global COUNT separately. G0/G1 encode the history, typed expected cuts, reference query and independent evaluator as versioned replayable assets; retain checksums and deliberately broken cross-term/expected-output negative controls. G2 replays duplicate requests with stable input identities, faults acceptance/publication, reopens exact parents, preserves the previous publication until commit and verifies every promised historical cut after compaction/restart. A lost response is not a fresh transaction.

| Gate | Golden workload progression |
| --- | --- |
| G0 | Frozen inputs/reference answers, independent batch evaluation, comparable prototype costs |
| G1 | Exact incremental results and retractions at every cut; generated variants |
| G2 | SQL path, durable input/publication, token/wait semantics, crash and cold recovery, historical reads and quickstart |
| G3 | Customer-level spend/count and regional views; actual sharing, independent progress, slow-consumer retention, live source handoff and lifecycle |
| G4 | Distribute the same contract, fence old owners, fail over; expand scale and skew beyond RAM |
| G6 | Sustained workload, verified restore and upgrade, diagnostics, SLO and full-cost evidence |

The tiny fixture verifies correctness and integration, not throughput, scale, cost superiority or the whole SQL surface. The wider W1 family, W2–W14 and partner workloads remain required as applicable.

## 3. Early feasibility and economics

Before committing to a backend, runtime or public SLO, build instrumented comparable experiments. Freeze workload, durability/retention guarantees, load, warm/cold state and environment. Compare production-intended paths and alternatives, not just isolated dependency APIs. Record raw latency distributions, errors, correctness and cost inputs. Negative or inconclusive findings may change component choices, narrow a profile or revise a proposed target through ADR/maintainer review; never weaken an invariant.

The [G0 feasibility decisions](qualification.md#g0-feasibility-decisions) define six required experiments, predeclared numeric profile budgets, correctness conditions and explicit fallback decisions. Freeze confirmatory limits after separately labelled calibration and before measuring candidate results; missing or failed evidence cannot be treated as a pass. P0.5/P0.6 provide named workload/backend/filesystem/client candidates, comparable baselines, pinned versions and resource budgets.

P0.9 and the component owners then produce the [joint G0 feasibility record](qualification.md#joint-g0-feasibility-record). Narrow candidates through focused probes, connect the finalists through the same durable W1-G path, and measure mixed reads, maintenance, compaction, independent consumers and cold recovery within one frozen budget. Reuse this path for the required sharing-scale experiments. Component passes do not substitute for the combined verdict. Keep the prototype narrow: a complete frontend, broad connector matrix and autonomous optimizer remain later work, with missing public paths recorded explicitly.

| Experiment | Measure and decide |
| --- | --- |
| Metadata scalability (P0.4) | Adaptive conflict-aware batching, bounded priority/fairness queues, committer failover and reader-group admission/drain/revocation/GC; physical operations per logical operation, mixed contention and complete latest-selection/read/completion path; distinguish throughput-driven partitioning from latency-driven consensus fallback |
| Logical MVCC storage (P0.2) | Current-state access plus timestamped deltas/consolidated bases; checkpoint/clone versus immutable attempt namespaces and proven writer reuse; exact parent/cut isolation, checkpoint amortization, bounded history/reconstruction/compaction/request and recovery costs |
| Runtime selection (P0.3) | Native versus Timely/Differential under identical semantics, lifecycle, durability, recovery and production-logic simulation; acyclic scalar initial kernel, one active interval/domain, bounded internal parallelism; binding selection includes complexity and maintenance cost |
| Differential correctness (P0.1) | Original engine, new kernel and independent batch/PostgreSQL authority over identical supported histories; retain donor failures and SQL/wire/security cases, classify dialect differences, block promotion on unexplained mismatches |
| Sharing economics (P0.8) | Shared versus isolated prototypes at 100 and 1,000 overlapping views with independent schedules and slow consumers; pinned-snapshot/replay/verified atomic isolation, retained history, temporary duplication and cold cost; keep the eligible factorization comparison |
| Complete hibernation (P0.7) | Zero surviving Rockstream processes and complete local-cache loss; exact cold restore, concurrent/stale activation, first correct read and catch-up under unchanged obligations; include dormant source/history/wake costs and choose partial suspension where full sleep is ineligible |

Measure queue, source/admission, compute, durable staging, publication, pin acquisition/validation, storage, serialization and network, including actual end-to-end distributions. Summing component P99s does not establish end-to-end P99. The aspirational 5 ms indexed server read includes required metadata/pin work; 100 ms freshness includes actual durable publication. If mandatory remote operations cannot support a target, test sound amortization/batching under the same safety rules or publish a narrower measured envelope. Never move work outside the metric to obtain green results.

Record CPU time, peak memory, maintained/retained-state bytes per logical byte, physical writes per logical change, network bytes, object reads/writes/CAS and bytes per accepted batch and unique logical change, recovery work and idle resource cost. Specify denominators (zero-work intervals have no per-change rate) and boundaries. Apply the qualification rate card and full-cost accounting; distinguish estimates from measurements. Set initial resource budgets from evidence and track regressions asynchronously. Real infrastructure probes require authorized bounded disposable environments; no assumed access or spend.

## 4. Start with three independent workstreams

Use the existing P0 work IDs; these are issue seeds to refine and open after design approval, not created or claimed GitHub issues. Start at most one implementation issue per lane and three across the project under the [agent operating model](../design/agent-development.md). Required independent review and human high-risk approval remain binding; parallel lanes do not freeze Rust interfaces.

| Lane / first issue seed | Scope and acceptance | Subsequent dependencies |
| --- | --- | --- |
| A — P0.9a reproducible bootstrap and fast CI | Minimal Rust workspace for actual prototype needs, pinned toolchain/lockfile, one local/CI entry point, genuine small executable test, format/lint, stable required-check design, dependency-direction negative control; show clean run and intentionally failing check. No empty future-engine crates or unapproved changes to protected policy. | P0.9 harness/ledger, P0.10 agent pilot and permissions |
| B — P0.4a metadata transition model | Small independent model for root head, generation, conflict-disjoint batches/per-operation outcomes and reader-group admission/drain/release/revocation/GC; assert no stale publish, omitted receipt, invalid-pin success or unsafe retirement; preserve lost-CAS-response-after-later-commit counterexample. Record bounds and negative controls; no production storage assumption. | P0.4 real conditional-object probe, P0.2 SlateDB history/reopen, P0.7 suspend/resume |
| C — P0.1a golden fixture and independent evaluator | Freeze W1-G schemas, transactions, expected cuts and replay interface; independently evaluate all five cuts including empty/both-side changes; reject deliberately wrong answer. No optimized runtime or full SQL parser. | P0.1 donor inventory/three-way corpus and semantic matrix, P0.3 runtime comparison, P0.8 sharing/eligible optimization |

Sub-issues do not replace gates or estimates. The maintainer authorizes actual agent/CI environment before autonomous writes or merge; until then use supervised PRs and isolated prototypes. Real object-store tests wait for relevant P0.6 profile/dependency review and approved scoped resources. P0.5 supplies partner requirements, P0.6 selects candidates, P0.9/P0.10 supply verified tooling; schedule within WIP limits. Keep coordination in GitHub issues and PRs, branch/worktree ownership, Actions and versioned evidence; no custom agent orchestration platform by default.

Converge on the same golden input, evidence schema and invariants. Close G0 only on existing criteria plus the six recorded feasibility decisions, their selected qualified direction or scoped fallback, and the joint record for that selected combination; unresolved safety failures block the affected choice. Completing an experiment does not qualify the full engine or lower a risk without evidence. Then implement G1 and G2; do not launch another speculative design project. Reopen affected decisions for concrete counterexamples, new requirements or measured tradeoffs.
