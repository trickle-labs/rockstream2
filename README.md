# Rockstream 2

**A cloud-native, SQL-first incremental view maintenance (IVM) database.**

Rockstream 2 maintains exact SQL materialized views over changing data, shares computation and state across an entire workload, and separates maintenance from serving on object storage. Its core contract is simple: every published result equals the declared query evaluated at its declared input cut, within explicit numeric semantics.

## Why Rockstream 2

Existing streaming databases typically force a painful trade-off between operational complexity (running external ZooKeeper/etcd/catalog clusters), single-view duplication (maintaining separate state per view), or weak cloud economics. Rockstream 2 targets a distinct design point:

1. **Single binary, zero external dependencies:** Run locally with one command, or in the cloud with the Rockstream binary and an object store—no etcd, ZooKeeper, Redis, SQL catalog, or Kubernetes required.
2. **Workload-wide shared and factorized IVM:** DBSP semantics over Apache Arrow and DataFusion with shared canonical arrangements and algebraically verified partial aggregation/factorization (F-IVM) where it cuts lifetime cost.
3. **Cloud-native durability with a measured storage choice:** Object-backed authority, atomic publication and exact-parent recovery are fixed contracts. Immutable delta traces plus SlateDB working indexes and bounded overlays are the current candidate; G0.2 selects one layout against a simpler history candidate using common correctness, resource, recovery, SLO and cost limits. [ADR 0015](docs/adr/0015-azure-first-object-storage.md) proposes Azure Blob Storage as the first real cloud target and Silo for local development; neither is qualified by that decision.
4. **Honest cloud latency profiles:** An **Object-Native** default (zero resident coordination, pre-allocated owner-generation namespaces, scale-to-zero eligible) and an optional G4+ **Low-Latency Cloud** profile (embedded OpenRaft metadata tier and optional cross-AZ fast WAL tier, adopted only on measured evidence). Latency targets are hypotheses until G0/G4.0 measure them: sub-5 ms warm cached reads, ~150 ms–1.5 s object-store freshness (prior S3-derived target, not an Azure prediction), `<10 ms` strict-latest and `≤100 ms` end-to-end freshness for the optional profile.
5. **Exact, independently verified SQL semantics:** Checked widened integer/decimal arithmetic, retractions, `Q(empty)` initialization, and independent PostgreSQL/batch oracle verification from day one.

**Repository status: architecture, implementation plan and early G0 experiments; no production engine or qualified deployment profile.** The Rust workspace, independent W1-G oracle, native-kernel spike and bounded Quint model have scoped evidence records. Public API/deployment capabilities and performance targets remain proposals; those experiments do not establish a gate pass or production result. Baseline audit was prepared against Rockstream commit [`d3f973a`](https://github.com/trickle-labs/rockstream/commit/d3f973a84f4263bedd6505039d7f469d4708c478) (`0.72.0`).

## Start here

| Read | Purpose |
| --- | --- |
| [Design](DESIGN.md) | Integrated architecture, dual cloud profiles, invariants, storage/metadata model, and transaction walkthrough |
| [Requirements](docs/planning/requirements.md) | Product thesis, guarantees, target workloads, and honest profile SLOs |
| [Implementation plan](docs/planning/implementation-plan.md) | The single roadmap: gate ladder, work IDs, exit evidence, and stop/pivot signals (`G0 → G1 → G2 → G3a`, independent IVM capabilities, and profile-based `G6-S`/`G6-D`) |
| [Implementation start](docs/planning/implementation-start.md) | Two-track G0 kill-switch probes, canonical `W1-G` golden workload, and initial issue seeds |
| [Decision records](docs/adr/README.md) | Architectural commitments, alternatives, and decision gates (`ADR 0001`–`0014`) |
| [RockStyle](ROCK_STYLE.md) | Engineering constraints: types, release safety checks, bounds, and a small verification stack |
| [Current-system audit](docs/research/current-system-audit.md) | Evidence-based comparison with Rockstream v1 |
| [Implementation experience report](docs/research/implementation-experience-report.md) | Lessons from Rockstream v1's delivery history, verification, and CI |

## Engineering specifications

| Document | Questions it answers |
| --- | --- |
| [Semantics and compiler](docs/design/semantics-and-compiler.md) | What does a query mean, how is it incrementalized, and what makes a rewrite safe? |
| [Consistency and storage](docs/design/consistency-and-storage.md) | What is durable, how do single-root metadata CAS, measured batching, immutable deltas, SlateDB indexes, logical MVCC, reader leases (G4), and grace-window GC work? |
| [Runtime and operations](docs/design/runtime-and-operations.md) | How do execution, memory/spill, connectors, view fault isolation, elasticity, suspension, and DR work? |
| [Testing and verification](docs/design/testing-and-verification.md) | How do we verify semantics and protocols pragmatically at the lowest effective layer? |
| [Development workflow](docs/design/development-workflow.md) | How do we keep PR CI fast (<5 min) while running deep verification asynchronously? |
| [Agent-first development](docs/design/agent-development.md) | How do autonomous agents and human maintainers collaborate without turning review into a bottleneck? |
| [SQL and API contract](docs/reference/sql-and-apis.md) | Which capabilities arrive when, and what do reads, writes, subscriptions, and errors mean? |
| [Qualification](docs/planning/qualification.md) | How are correctness, resilience, economics, and performance proved before promotion? |
| [Migration](docs/planning/migration.md) | How do Rockstream v1 workloads move with three-way reconciliation and rollback? |
| [Risks and open questions](docs/planning/risks-and-open-questions.md) | What remains uncertain, how G0 resolves existential physics risks, and what triggers fallbacks? |
| [Research and sources](docs/research/sources.md) | Primary references, source provenance, and limits on external conclusions |

## Incremental build philosophy

Build Rockstream 2 **step by step** from one executable vertical slice. [ADR 0013](docs/adr/0013-minimum-mechanisms-and-independent-qualification.md) preserves the ambition of workload-wide cloud-native IVM while removing unrelated release dependencies: single-node production can qualify without distribution, and useful sharing/factorization can qualify without independent scheduling. Every profile keeps its full applicable correctness, recovery, security, resource and economic evidence. Each mechanism is adopted at the first gate whose acceptance needs it ([ADR 0012](docs/adr/0012-staged-mechanism-adoption.md)); every gate ends in an artifact a named audience can run. The [implementation plan](docs/planning/implementation-plan.md) is the single authority for gate contents, exit evidence, and stop/pivot signals; this is the summary.

[ADR 0014](docs/adr/0014-incremental-delivery-and-earned-complexity.md) defines the next concrete simplification: a compact metadata manifest and one operation per root CAS, with batching/paging earned by measured need. Follow the [runnable increments](docs/planning/implementation-plan.md#incremental-build-sequence) from exact semantics through durable accept/publish/read/recover, complete the preview, then prove a selected shared or factorized gain. An internal demonstration does not qualify a preview, and early cost diagnostics do not replace the real-partner production gate.

| Gate | Release artifact | Headline scope |
| --- | --- | --- |
| **G0** | Contributors | Two parallel tracks. Foundation (`G0.1`, `G0.4`): Rust workspace, fast CI, `W1-G` golden workload with an independent PostgreSQL/batch oracle, scoped native feasibility decision; unlocks G1 only after independent review. Complete physical runtime resource evidence remains a blocker to G2 preview qualification, not to starting P2.2/P2.5. Durability physics (`G0.2`, `G0.3`): conditional-write metadata and delta + SlateDB storage probe on real object storage, one concise Quint model; unlocks G2 |
| **G1** | Contributors | Typed IR, exact Z-set operators, DataFusion SQL adapter, checked widened numeric/NULL/`Q(empty)` semantics, property tests; no network or cloud |
| **G2** | Design-partner developer preview | One binary, `pgwire`, durable single-node object-store state using the one selected layout, per-view fault quarantine, crash recovery, 5-minute local quickstart |
| **G3a** | First public single-node preview | `LEFT OUTER JOIN`, `DISTINCT`, semi/anti joins, delete-safe `MIN`/`MAX`, online view lifecycle, PostgreSQL CDC and resumable subscriptions; Kafka source/sink independently qualifies when selected |
| **G3b-S/F/I/P** | Independently qualified IVM capabilities | Same-group/cadence sharing; eligible factorization; independent schedules with arbitrary-cut MVCC and online isolation; evidence-triggered depth-one pipelining. Measure each selected capability and combination |
| **G4** | Distributed preview | Multi-node execution, reader leases and grace-window GC, independent serving pools, cross-domain imports, distributed suspension/wake, optional Embedded OpenRaft |
| **G5** | Independent | `FULL OUTER JOIN`, Top-K, windows, temporal SQL, bounded recursion, broader F-IVM and cost advisory graduate individually |
| **G6-S** | Single-node Object-Native production | After G3a plus selected capabilities; full applicable security, resource, backup/restore, upgrade/rollback, eligible suspension, 72-hour soak and two-partner economic evidence; no mandatory G4 |
| **G6-D** | Distributed production | After G4 plus selected capabilities; the same production contract applied to the distributed topology and advertised guarantees |

The project uses the [Apache-2.0 license](LICENSE). Migration from Rockstream v1 is an explicit, verified logical-replay workflow rather than implicit on-disk compatibility.

### G0.1 fast checks (in progress)

With Rust 1.100.0, Python 3, PostgreSQL 17 and `psql` installed, start a
local PostgreSQL instance and set the usual `PGHOST`, `PGPORT`, `PGUSER` and
`PGPASSWORD` variables for a disposable test database. Run
`scripts/check-fast.sh`. The check creates only temporary tables in database
`postgres`. It checks formatting, clippy, Rust batch results, dependency and
cross-term negative controls, and the PostgreSQL W1-G cuts. This is not G0
qualification; CI timing, independent review and donor inventory remain open. The dependency
policy checks the complete all-features resolved graph for paths between
workspace crates, including paths through external dependencies. Resolved path
dependencies must be workspace members.
