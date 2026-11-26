# ADR 0011: pragmatic risk reduction and lean G0 validation

**Status:** Proposed for review, 2026-11-26. Refines ADRs [0003](0003-publication-and-metadata.md)–[0010](0010-operation-and-hibernation.md) to eliminate physics contradictions, storage impedance mismatch, and pre-implementation G0 bloat.

## Context

An earlier draft piled ten G0 packages, dual full runtime prototypes, three attempt-isolation mechanisms, 1,000-view sharing benchmarks, full zero-process hibernation, and a FoundationDB-style cluster simulator onto G0 *before writing G1*. It also created irreconcilable physical contradictions (demanding two synchronous S3 root GETs per warm read while targeting 5 ms latency, and forbidding intra-batch composition while putting shared tenant quotas in one S3 root).

Building the ultimate cloud-native IVM requires **proving the existential physics in weeks, not quarters**, then shipping clean incremental vertical slices.

## Decisions

| Area | Earlier trap | Practical decision |
| --- | --- | --- |
| Read latency & GC | Two synchronous S3 root GETs on every read made `<5 ms` reads impossible; distributed wall-clock tombstones & VM pauses created subtle races | Sweeper-observed monotonic GC grace window (`Δ_gc_grace >> Δ_read_lease`) + post-read monotonic deadline check (`monotonic_now() < lease_deadline`) with 0 post-read S3 round trips; opt-in `strict-immediate-revocation` |
| Metadata root & profiles | Conflict-disjoint batching failed on shared quotas/`input_head`; per-interval intent CAS & heartbeats inflated S3 round trips; pretended Raft metadata alone gave `≤100 ms` on S3 Standard | Pre-allocated owner-generation namespaces (no hot-path intent CAS), out-of-root heartbeats, compositional intra-batch serialization, advisory preferred-committer fallback; explicit **Object-Native** (~150 ms–1.5 s S3 freshness) and G4+ **Low-Latency Cloud** (Embedded OpenRaft `<10 ms` strict reads; `≤100 ms` P99 freshness only with optional cross-AZ fast WAL tier) |
| Storage & MVCC | Co-locating domains in one SlateDB writer + per-interval clones / LSM attempt namespaces + unspecified overlay between checkpoints | Immutable delta segments + per-domain SlateDB working index + **explicit bounded in-memory delta overlay** `(Cp_ckpt, Cp]` (post-commit SlateDB apply, nearest-checkpoint historical lookup in `[S_hot, Cp]`, uniform PK index recovery) |
| Direct DML & poison records | Hidden two-store PK index atomicity; single derived view overflow wedged an entire domain or pinned shared history forever | Uniform checkpoint + input-log overlay for Direct-DML PK index; default per-view result publication head (explicit `publication_group` when joint atomicity is required) with quota-bounded quarantine pins |
| Hibernation | Full zero-process sleep constrained online low-latency/CDC profiles that cannot hibernate anyway | Stateless compute scales to zero on all profiles; full zero-process hibernation is an Object-Native capability for eligible workloads |
| Runtime selection | Mandatory upfront double-build of native AND Timely/Differential before G1 | Build and validate the lean acyclic scalar-epoch native kernel in G0.4 (with Rockstream-owned checked widened numeric accumulators); only prototype Timely/Differential if native hits a concrete predeclared wall |
| Gate sequencing & optimizer | Overloaded G3 with premature 9-term monetary cost advisor while `LEFT JOIN`/`DISTINCT` waited for G5; delete-safe `MIN`/`MAX` bloated G2 | Move `MIN`/`MAX` out of G2; split G3 into **G3a** (table-stakes SQL: `LEFT JOIN`, `DISTINCT`, semi/anti joins, `MIN`/`MAX` + live PG CDC with additive-DDL tolerance, Kafka, subscriptions) and **G3b** (shared engine, MVCC, rule-based isolation, eligible F-IVM); defer monetary cost advisor to G5 |
| Verification & review | Contradictory Quint vs. FizzBee tooling; pretending a simulator covers Tokio/SlateDB/S3; auto-merging unbridged `rock-meta`/`rock-state` internals | Standardize on **Quint** + `proptest` + independent PostgreSQL/batch oracle + pure state-machine replay + **real-process/real-backend crash tests**; keep pure SQL/operator PRs at Medium risk and keep core protocol/recovery (`rock-meta`, `rock-state`) at High risk requiring human approval |
| G0 scope | 10 heavy work packages + 1,000-view benchmarks + full hibernation + joint harness before G1 | Cut G0 to **4 focused kill-switch deliverables (G0.1–G0.4)** runnable in 2–4 weeks; move sharing benchmarks to G3b, full hibernation to G2/G4, and heavy governance to actual need |

## Consequences

- G0 becomes an actual 2–4 week engineering gate that unlocks G1 (semantic kernel) and G2 (usable single-node durable MVP) rapidly.
- Every architectural invariant (`INV-01`–`INV-10`) remains intact; none of these simplifications weakens exact SQL semantics, atomic publication, ownership fencing, or GC safety.
- Unproven claims remain unmeasured until G0.2/G2–G6 produce real artifacts. If G0.2 proves S3 conditional-root latency or SlateDB index maintenance misses its profile budget, the recorded fallback (layout change or earlier Embedded Raft adoption) triggers immediately before full-engine investment.
