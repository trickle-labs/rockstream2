# Sources, provenance, and interpretation

**Research date:** 2026-11-25. This document distinguishes observed source evidence, published research, external component documentation, and this proposal's own design choices. Live documentation can change; implementation work must pin exact dependency revisions and revalidate the needed APIs.

## 1. Project input and repository baseline

The user supplied the starting essay **“Rockstream 2 — the ultimate cloud-native IVM engine”** as `Pasted text(2).txt`. Its architectural ambitions informed this proposal. Its illustrative syntax, mock metrics, competitive comparisons and targets are not treated as measured results. The [risk register's ambition mapping](../planning/risks-and-open-questions.md#4-ambition-versus-first-implementation) records where ideas are adopted, narrowed or gated.

The source URL `grove/rockstream` resolves to `trickle-labs/rockstream`. The audited baseline is commit [`d3f973a84f4263bedd6505039d7f469d4708c478`](https://github.com/trickle-labs/rockstream/commit/d3f973a84f4263bedd6505039d7f469d4708c478), with workspace version `0.72.0`. Read-only source inspection covered top-level design/capability documents and selected compiler, storage, control, runtime and qualification paths. The audit is not exhaustive, and no original-engine benchmark or production qualification was executed for this design PR.

| Baseline source | Use in this design |
| --- | --- |
| [Cargo.toml](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/Cargo.toml) | Actual workspace version and dependency baseline; not successor version choices |
| [Architecture](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/ARCHITECTURE.md) and [design](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/DESIGN.md) | Existing execution/storage/control boundaries; reconcile stale prose against code |
| [IVM](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/IVM.md) | Existing semantic approach; no inference that every planned path is publicly supported |
| [Capability matrix](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/docs/capability-matrix.md) | Public support/reachability distinctions and reusable regression pointers |
| [Scale qualification](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/benchmarks/scale-qualification/README.md) | Qualified throughput, complete costs and negative-controlled evidence design |
| [Project focus](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/ROCKSTREAM_PROJECT_FOCUS.md) | Strategic scope; later connector amendment governs conflicting older passages |

The [current-system audit](current-system-audit.md) provides more precise implementation links and identifies features to retain or redesign. Documentation inconsistencies are reported as such; they are not evidence of runtime bugs without a reproducer.

## 2. Primary research

| Source | What it supports | What this proposal does not infer |
| --- | --- | --- |
| Budiu et al., [DBSP, PVLDB 2023](https://docs.feldera.com/vldb23.pdf); [extended 2025 article](https://doi.org/10.1007/s00778-025-00922-y) | Compositional formulation of incremental computation and rich query languages | That this compiler or every SQL feature is already correct, efficient, implemented or production-ready |
| McSherry et al., [Shared Arrangements](https://arxiv.org/abs/1812.02639) | Reuse of indexed maintained state across compatible dataflows | Universal 10× savings or free cloud durability/retention integration |
| Kara et al., [F-IVM](https://arxiv.org/abs/2303.08583) | Combining higher-order maintenance, factorization and algebraic payloads | That every join can avoid its inherent output size or every aggregate supports the same factorization |
| Zhou et al., [FoundationDB, SIGMOD 2021](https://www.foundationdb.org/files/fdb-paper.pdf) | Deterministic simulation as a foundation for distributed-system engineering | A proof of Rockstream's new protocol or an automatic transfer of FoundationDB's reliability |

The proposed kernel, publication rules, rollout sequence and budget targets are design judgments informed by these sources. They remain subject to the stated prototype and qualification gates.

## 3. Component and semantic documentation

| Source inspected | Relevant boundary |
| --- | --- |
| [Timely operator/capability guide](https://timelydataflow.github.io/timely-dataflow/chapter_2/chapter_2_4.html) | Explicit capabilities and progress obligations; runtime candidate requires persistence/lifecycle experiments |
| [Feldera publications](https://docs.feldera.com/literature/papers/) | Primary DBSP references and a runtime/compiler candidate; exact reusable component/license selection remains open |
| [DataFusion SQL reference](https://datafusion.apache.org/user-guide/sql/index.html), [configuration](https://datafusion.apache.org/user-guide/configs.html), [security](https://datafusion.apache.org/library-user-guide/securing-datafusion.html) | SQL/kernel reuse, dialect/configuration checks, application-owned access/resource boundaries |
| PostgreSQL [aggregate functions](https://www.postgresql.org/docs/current/functions-aggregate.html), [date/time functions](https://www.postgresql.org/docs/current/functions-datetime.html), [recursive queries](https://www.postgresql.org/docs/current/queries-with.html) | Compatibility oracle for explicitly supported semantics, including empty aggregates and transaction time |
| PostgreSQL [logical decoding concepts](https://www.postgresql.org/docs/current/logicaldecoding-explanation.html) | Consistent snapshot/stream handoff, replication identities, retransmission and retained-log obligations |
| [Kafka 4.4 design](https://kafka.apache.org/44/design/design/) | Ordering, transactional visibility and producer/consumer delivery boundaries; exact connector version still needs qualification |
| SlateDB [introduction](https://slatedb.io/docs/get-started/introduction/), [writes](https://slatedb.io/docs/design/writes/), [checkpoints](https://slatedb.io/docs/design/checkpoints/), [GC](https://slatedb.io/docs/design/gc/) | Single-writer/fencing model, durable completion, durable versus transient snapshots and backend retention |
| [etcd API guarantees](https://etcd.io/docs/v3.6/learning/api_guarantees/), [system limits](https://etcd.io/docs/v3.6/dev-guide/limit/) | Authoritative transactional operations, watches and bounded metadata design |
| SQLite [WAL](https://www.sqlite.org/wal.html), [synchronous pragma](https://www.sqlite.org/pragma.html#pragma_synchronous) | Embedded single-machine metadata durability; not a distributed HA claim |
| [Materialize Persist design](https://github.com/MaterializeInc/materialize/blob/main/doc/developer/design/20220330_persist.md) | Historical design precedent for immutable blob data and consensus-controlled state; the document itself is a point-in-time design, not a current API guarantee |

No competitor ranking or performance advantage is claimed from this reading. The new architecture's advantages must be demonstrated on equivalent workloads with the evidence protocol in [qualification](../planning/qualification.md).

## 4. Evidence classifications for future work

Use **Observed implementation** for a pinned code path actually inspected; **Declared support** for a versioned capability contract; **Research precedent** for a cited result; **Proposed requirement** for this repository's design; and **Measured result** only for a reproducible executed bundle. A unit fixture, mock UI number, unexecuted test specification or model with unstated bounds must never be labelled a measured result.

When a source changes, preserve the qualified dependency revision in the evidence bundle. When a design inference changes, update the ADR and affected contracts. Keep primary sources close to factual claims; keep this index as a navigation aid rather than a substitute for local reasoning.
