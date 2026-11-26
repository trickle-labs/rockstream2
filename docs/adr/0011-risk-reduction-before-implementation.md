# ADR 0011: pragmatic risk reduction and lean G0 validation

**Status:** Proposed for review, 2026-11-26. Refines ADRs [0003](0003-publication-and-metadata.md)–[0010](0010-operation-and-hibernation.md) to eliminate physics contradictions, storage impedance mismatch, and pre-implementation G0 bloat.

## Context

An earlier draft piled ten G0 packages, dual full runtime prototypes, three attempt-isolation mechanisms, 1,000-view sharing benchmarks, full zero-process hibernation, and a FoundationDB-style cluster simulator onto G0 *before writing G1*. It also created irreconcilable physical contradictions (demanding two synchronous S3 root GETs per warm read while targeting 5 ms latency, and forbidding intra-batch composition while putting shared tenant quotas in one S3 root).

Building the ultimate cloud-native IVM requires **proving the existential physics in weeks, not quarters**, then shipping clean incremental vertical slices.

## Decisions

| Area | Earlier trap | Practical decision |
| --- | --- | --- |
| Read latency & GC | Two synchronous S3 root GETs on every read (including warm/stale) made <5 ms reads impossible | Conservative GC physical-deletion grace window (`Δ_gc_grace >> Δ_read_lease`) + lease-backed bounded-staleness fast path (0 post-read S3 round-trips); opt-in `strict-immediate-revocation` |
| Metadata root & profiles | Conflict-disjoint-only batching failed on shared tenant quotas and same-domain `input_head`; pretended S3 CAS could deliver ≤100 ms freshness | Compositional intra-batch serialization in the commit scheduler; explicit **Object-Native** (~200 ms–1 s freshness) and G4+ **Low-Latency Cloud** (embedded OpenRaft, ≤100 ms) profiles |
| Storage & MVCC | Co-locating unrelated domains in one SlateDB writer + per-interval clones / LSM attempt namespaces + unbounded multi-day nonlinear history | Immutable object-backed delta segments + per-domain SlateDB working index (no per-interval clones or LSM attempt filtering); bounded fine-grained hot history window + periodic checkpoints |
| Direct DML & poison records | Hidden unbudgeted PK admission index; single derived view overflow wedged an entire publication domain | Explicitly budget the SlateDB PK image index for keyed direct-DML tables (avoided by append-only & CDC); quarantine a failing derived view at its last valid cut instead of halting unrelated views |
| Hibernation | Full zero-process sleep constrained online low-latency/CDC profiles that cannot hibernate anyway | Stateless compute scales to zero on all profiles; full zero-process hibernation is an Object-Native capability for eligible workloads |
| Runtime selection | Mandatory upfront double-build of native AND Timely/Differential before G1 | Build and validate the lean acyclic scalar-epoch native kernel in G0.4; only prototype Timely/Differential if native hits a concrete predeclared complexity or correctness blocker |
| Verification stack | Contradictory Quint vs. FizzBee tooling; pretending a simulator covers Tokio/SlateDB/S3 internals | Standardize on **Quint** + `proptest` + independent PostgreSQL/batch oracle + deterministic pure state-machine replay + **real-process/real-backend crash tests** |
| G0 scope | 10 heavy work packages + 1,000-view benchmarks + full hibernation + joint harness before G1 | Cut G0 to **4 focused kill-switch deliverables (G0.1–G0.4)** runnable in 2–4 weeks; move sharing benchmarks to G3, full hibernation to G2/G4, and heavy governance to actual need |

## Consequences

- G0 becomes an actual 2–4 week engineering gate that unlocks G1 (semantic kernel) and G2 (usable single-node durable MVP) rapidly.
- Every architectural invariant (`INV-01`–`INV-10`) remains intact; none of these simplifications weakens exact SQL semantics, atomic publication, ownership fencing, or GC safety.
- Unproven claims remain unmeasured until G0.2/G2–G6 produce real artifacts. If G0.2 proves S3 conditional-root latency or SlateDB index maintenance misses its profile budget, the recorded fallback (layout change or earlier Embedded Raft adoption) triggers immediately before full-engine investment.
