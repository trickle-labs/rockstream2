# Rockstream 2

**A cloud-native, SQL-first incremental view maintenance (IVM) database.**

Rockstream 2 maintains exact SQL materialized views over changing data, shares computation and state across an entire workload, and separates maintenance from serving on object storage. Its core contract is simple: every published result equals the declared query evaluated at its declared input cut, within explicit numeric semantics.

## Why Rockstream 2

Existing streaming databases typically force a painful trade-off between operational complexity (running external ZooKeeper/etcd/catalog clusters), single-view duplication (maintaining separate state per view), or weak cloud economics. Rockstream 2 targets a distinct design point:

1. **Single binary, zero external dependencies:** Run locally with one command, or in the cloud with the Rockstream binary and an object store—no etcd, ZooKeeper, Redis, SQL catalog, or Kubernetes required.
2. **Workload-wide shared and factorized IVM:** DBSP semantics over Apache Arrow and DataFusion with shared canonical arrangements and algebraically verified partial aggregation/factorization (F-IVM) where it cuts lifetime cost.
3. **Clean cloud-native storage separation:** Immutable object-backed input logs and timestamped delta segments carry authority, exact-parent recovery, and logical MVCC history; SlateDB plus a bounded in-memory delta overlay provides fast per-domain/partition indexed working state; a single-root compositional metadata kernel coordinates publication.
4. **Honest cloud latency profiles:** An **Object-Native** default (zero resident coordination, pre-allocated owner-generation namespaces, monotonic lease-backed sub-5 ms warm cached reads, ~150 ms–1.5 s S3 freshness, scale-to-zero eligible) and an optional G4+ **Low-Latency Cloud** profile (embedded OpenRaft metadata tier for `<10 ms` strict-latest reads and high-rate commits, with optional cross-AZ fast WAL tier for `≤100 ms` end-to-end freshness).
5. **Exact, independently verified SQL semantics:** Checked widened integer/decimal arithmetic, retractions, `Q(empty)` initialization, and independent PostgreSQL/batch oracle verification from day one.

**Repository status: architecture and implementation plan, not an implemented engine.** All APIs, deployment commands, capability targets, and performance numbers are proposals. No Rockstream 2 engine or benchmark has been executed yet. Baseline audit was prepared against Rockstream commit [`d3f973a`](https://github.com/trickle-labs/rockstream/commit/d3f973a84f4263bedd6505039d7f469d4708c478) (`0.72.0`).

## Start here

| Read | Purpose |
| --- | --- |
| [Design](DESIGN.md) | Integrated architecture, dual cloud profiles, invariants, storage/metadata model, and transaction walkthrough |
| [Requirements](docs/planning/requirements.md) | Product thesis, guarantees, target workloads, and honest profile SLOs |
| [Implementation plan](docs/planning/implementation-plan.md) | Step-by-step incremental gates (`G0 → G1 → G2 → G3a → G3b → G4 → G6`, independent `G5`) |
| [Implementation start](docs/planning/implementation-start.md) | Lean G0 kill-switch probes, canonical `W1-G` golden workload, and initial issue seeds |
| [Decision records](docs/adr/README.md) | Architectural commitments, alternatives, and decision gates (`ADR 0001`–`0011`) |
| [RockStyle](ROCK_STYLE.md) | Engineering constraints: types, release safety checks, bounds, and a small verification stack |
| [Current-system audit](docs/research/current-system-audit.md) | Evidence-based comparison with Rockstream v1 |
| [Implementation experience report](docs/research/implementation-experience-report.md) | Lessons from Rockstream v1's delivery history, verification, and CI |

## Engineering specifications

| Document | Questions it answers |
| --- | --- |
| [Semantics and compiler](docs/design/semantics-and-compiler.md) | What does a query mean, how is it incrementalized, and what makes a rewrite safe? |
| [Consistency and storage](docs/design/consistency-and-storage.md) | What is durable, how do compositional metadata CAS, immutable deltas, SlateDB indexes, lease-backed reads, and grace-window GC work? |
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

Build Rockstream 2 **step by step** from one executable vertical slice, proving physics before scaling complexity:

1. **G0 (2–4 week kill-switch & foundation):** Bootstrap the Rust workspace and fast CI, freeze the `W1-G` golden workload and independent PostgreSQL/batch oracle, prove S3 compositional metadata CAS + SlateDB/immutable-delta/overlay physics on real object storage, write one concise Quint protocol model, and validate the minimal native kernel.
2. **G1 (Pure Semantic Kernel):** Typed IR, exact Z-set operators, DataFusion SQL adapter, checked widened numeric/NULL/`Q(empty)` semantics, property tests and independent oracle—zero network or cloud complexity.
3. **G2 (Single-Node Durable MVP):** One binary, `pgwire`, local + single-node S3 durability, immutable delta segments + SlateDB working index + bounded overlay, lease-backed fast reads, view-level fault quarantine, crash recovery, and the 5-minute local quickstart.
4. **G3a (Real-World SQL & Live Connectors):** `LEFT OUTER JOIN`, `DISTINCT`, semi/anti joins, delete-safe `MIN`/`MAX`, online view lifecycle, PostgreSQL CDC (with benign additive-DDL tolerance), Kafka source/sink, and resumable subscriptions.
5. **G3b (Shared Engine & Eligible F-IVM):** Shared canonical arrangements, independent consumer domains and bounded logical MVCC, rule-based/explicit consumer isolation, bounded single-depth pipelining, eligible partial aggregation/factorization, and W2 100/1,000-view benchmark.
6. **G4 (Distributed Cloud Scale):** Multi-node execution, virtual-partition reassignment, independent serving pools (with cache-affinity routing), cross-domain imports, distributed suspension/wake, and the optional Embedded OpenRaft low-latency profile.
7. **G5 (Independent Advanced Track) & G6 (Production Qualification):** `FULL OUTER JOIN`, Top-K, windows, temporal SQL, bounded recursion, broader F-IVM, and automated cost-model advisory advance independently; G6 qualifies sustained 72-hour soaks, DR restore drills, upgrades, and v1 migration.

The project uses the [Apache-2.0 license](LICENSE). Migration from Rockstream v1 is an explicit, verified logical-replay workflow rather than implicit on-disk compatibility.
