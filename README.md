# Rockstream 2

**A proposed SQL-first streaming database with shared incremental computation and simple operation.**

Rockstream 2 should maintain SQL results over changing data, optimize computation and state across the workload, and scale maintenance and serving independently. Its core contract is simple: every published result equals the declared query evaluated at its declared input cut, within the query's explicit numeric semantics.

The working architecture combines DBSP semantics, a lean Rockstream-native runtime, Arrow/DataFusion, SlateDB-backed arrangements and logical MVCC. Cloud operation requires the Rockstream binary and a qualified object store, including metadata; no separate coordination service is required. Eligible deployments should support full suspension and recovery through a documented activation path. These choices and their costs must pass the proposed qualification gates.

**Repository status: design and implementation plan, not an implemented engine.** All APIs, deployment commands, capability targets, and performance numbers in these documents are proposals. No Rockstream 2 performance or production-readiness claim has been measured. This design was prepared on **2026-11-25** against Rockstream commit [`d3f973a`](https://github.com/trickle-labs/rockstream/commit/d3f973a84f4263bedd6505039d7f469d4708c478), whose workspace version is `0.72.0`.

## Start here

| Read | Purpose |
| --- | --- |
| [Design](DESIGN.md) | Integrated architecture, decisions, boundaries, and an end-to-end transaction |
| [Requirements](docs/planning/requirements.md) | Product scope, guarantees, target workloads, and measurable success |
| [Implementation plan](docs/planning/implementation-plan.md) | Work packages, dependencies, exit gates, agent capacity and first milestones |
| [Implementation start](docs/planning/implementation-start.md) | First user experience, golden workload, feasibility experiments and initial issue seeds |
| [Current-system audit](docs/research/current-system-audit.md) | Evidence-based comparison with the existing Rockstream |
| [Implementation experience report](docs/research/implementation-experience-report.md) | Lessons from Rockstream's delivery history, verification, CI, and recommendations for Rockstream 2 |
| [Decision records](docs/adr/README.md) | Chosen direction, alternatives, consequences, and prototype gates |
| [Pre-implementation critique](docs/adr/0011-risk-reduction-before-implementation.md) | Which alternatives reduce risk, which add it, and how the existing experiments decide |

## Engineering specifications

| Document | Questions it answers |
| --- | --- |
| [Semantics and compiler](docs/design/semantics-and-compiler.md) | What does a query mean, how is it incrementalized, and what makes a rewrite safe? |
| [Consistency and storage](docs/design/consistency-and-storage.md) | What is durable, when is it visible, and how do publication, fencing, recovery, and GC work? |
| [Runtime and operations](docs/design/runtime-and-operations.md) | How do compute, exchange, connectors, isolation, elasticity, observability, upgrades, and disaster recovery work? |
| [Testing and verification](docs/design/testing-and-verification.md) | How do we build an extensive, balanced test pyramid and deterministic correctness engine? |
| [Development workflow](docs/design/development-workflow.md) | How do we keep issue-to-merge lead time low while continuously verifying main? |
| [Agent-first development](docs/design/agent-development.md) | How do autonomous coding agents implement, review, integrate and escalate work safely? |
| [SQL and API contract](docs/reference/sql-and-apis.md) | Which capabilities arrive when, and what do reads, writes, subscriptions, and errors mean? |
| [Qualification](docs/planning/qualification.md) | How will correctness, resilience, economics, and performance be established? |
| [Migration](docs/planning/migration.md) | How can existing workloads move with reconciliation and rollback? |
| [Risks and open questions](docs/planning/risks-and-open-questions.md) | What remains uncertain, who should resolve it, and what evidence changes a decision? |
| [Research and sources](docs/research/sources.md) | Primary references, source provenance, and limits on the conclusions |

## Implementation philosophy

Aim for a small exceptional product: one-binary local quickstart, standard PostgreSQL clients, exact incremental SQL and a qualified durable cloud profile. Use the canonical customer/orders workload to converge on executable behavior; see [implementation start](docs/planning/implementation-start.md). Prototype storage/MVCC, metadata, runtime and full suspension first, then build the semantic kernel and durable single-process slice. Qualify shared state, independent local consumer schedules, online lifecycle and eligible partial aggregation/factorization next; then distribute the same contracts. Broader higher-order maintenance, recursion, temporal SQL and adaptive optimization advance independently. Security, bounded resources, deterministic failures and operational simplicity start with the first slice.

Before building the full engine, [six G0 feasibility decisions](docs/planning/qualification.md#g0-feasibility-decisions) must qualify batched metadata and reader-group protection, checkpoint-amortized logical history and exact-parent isolation, a bounded native runtime against established alternatives, three-way correctness using donor tests, sharing economics with safe isolation, and complete cold hibernation. Each records acceptance budgets and a fallback; none permits weaker correctness or treats unexecuted experiments as resolved risks.

Autonomous coding agents are the primary implementation workforce. Agents take bounded issues through independently verified PRs; humans own direction, safety-critical/architectural approvals and releases. Prefer small vertical slices, reproducible environments, controlled parallelism, and evidence-driven simplification over large generated code changes. See the [agent operating model](docs/design/agent-development.md).

Correctness and fast feedback reinforce each other: design for a broad deterministic test foundation, focused integration and end-to-end coverage, and continuous deeper verification outside the ordinary PR critical path. Establish reproducible local/CI commands in G0, with [contributor guidance](AGENTS.md), risk-based required checks and exact-candidate release qualification.

The first production release follows the gates **G0 → G1 → G2 → G3 → G4 → G6**. **G5** is the advanced-capability track; completing every research feature is not a prerequisite for shipping a qualified, deliberately scoped release. See the implementation plan for the exact evidence each gate requires.

The project keeps the repository's existing [Apache-2.0 license](LICENSE). This proposal does not assume source, binary, wire, or on-disk compatibility with the existing engine; migration is a separate, verified workflow.
