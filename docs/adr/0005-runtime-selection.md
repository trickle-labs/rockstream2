# ADR 0005: lean native Arrow/DataFusion runtime with evidence-triggered fallback

**Status:** Proposed working choice; scoped feasibility decided in G0.4, with runtime resource qualification before G2 preview qualification under [ADR 0013](0013-minimum-mechanisms-and-independent-qualification.md). **Date:** 2026-11-26. **Owners:** runtime, compiler, and storage leads.

## Decision

Build a **lean Rockstream-native Rust runtime** over weighted Apache Arrow batches, DataFusion (SQL parsing and selected expression kernels), and Tokio (async I/O and task coordination), applying DBSP incremental semantics. Selectively reuse reviewed donor algorithms and regression corpora from Rockstream v1 via the donor disposition register ([migration](../planning/migration.md#donor-assets-and-regression-transfer)).

### Staged execution complexity (build step by step)

1. **Default until G3b-P is selected (acyclic, scalar-epoch, single-interval kernel):** Constrain the initial runtime to acyclic computation graphs, scalar domain epochs, weighted Arrow batches, Rockstream-owned checked widened numeric accumulators, deterministic error semantics, explicit prepare/publish boundaries, and **one active maintenance interval per publication group** (with operator/partition parallelism inside the interval and concurrency across independent groups).
2. **G3b-P (independent, evidence-triggered bounded single-depth pipelining):** Once single-interval correctness and recovery are proven, activate bounded single-depth pipelining (`P3.9`) only if measured single-interval freshness is I/O-bound—overlapping compute for interval `k+1` against durable S3 staging/publication of interval `k` (bounded to depth 1, naming `k` as `expected_parent`, counting `k+1` in peak memory reservations, discarding `k+1` immediately if `k` aborts or quarantines, and draining to depth 0 before isolation cutover or reassignment).
3. **G5 (Advanced execution):** General recursion, nested iteration time, and multi-step speculation remain separately gated capabilities.

### Practical G0 selection rule (avoid building two engines upfront)

Building two full comparable runtimes (native *and* Timely/Differential) before G1 slows delivery without proportional risk reduction—especially while the initial kernel is strictly acyclic and scalar-epoch, where Timely's multidimensional progress tracker provides minimal advantage and substantial adapter friction against object-store checkpoints and suspension.

Instead, **G0.4 builds and evaluates the minimal native kernel on `W1-G`** against predeclared correctness, resource-bound, and complexity criteria ([qualification](../planning/qualification.md#g0-feasibility-decisions)):
- **Keep native** if within the ~2-week Foundation timebox it passes exact independent-oracle parity on `W1-G` (including `Q(empty)`, retractions, and simultaneous both-side join updates), enforces explicit logical batch/state/queue/output bounds and ownership, and expresses acyclic scalar-epoch progress and single-owner operator state cleanly without ad hoc synchronization or cross-interval state leakage.
- **Trigger a single bounded Timely/Differential or Feldera/DBSP prototype on `W1-G`** only if the native kernel hits a native semantic, logical-bound or progress/state-ownership wall in G0.4—or later in G5 if general recursive/nested-iteration workloads prove uneconomical to build natively.

G0.4 is a bounded feasibility decision, not whole-process memory qualification. Preserve the current inconclusive native-spike and allocation-failure evidence; an independently reviewed verdict under the revised scope is required before G1 starts. G1 runtime work and P2.2/P2.5 must close physical allocation attribution, dependency/shared/temporary bytes, headroom, control reserves and fault/recovery behavior before any G2 runtime preview qualifies; each G6 profile repeats the applicable resource evidence. Expected logical admission exhaustion remains explicit. An allocator abort cannot be labeled a controlled error, and a dependency allocation gap alone does not establish that Timely is the remedy. Do not build a general allocator framework in G0.

A [proposed bounded feasibility decision](../../evidence/g0-4/bounded-feasibility-proposal.md) records the post-PR #41 evidence for independent review. It is not an adopted verdict and does not alter the historical inconclusive report or any later resource gate.

Keep the semantic IR, logical time, and durable storage/publication contracts decoupled from runtime scheduling so an evidence-triggered runtime substitution never forces rewriting the compiler or storage protocol.

## Consequences

- Focuses G0 engineering effort on the real existential risks (S3 metadata physics, SlateDB/immutable-delta layout, exact SQL semantics) instead of maintaining dual prototypes.
- Eliminates speculative plugin traits—maintain **one** production runtime at all times.
- Pure transition and operator logic runs directly in unit/property tests and deterministic state-machine replay; Tokio async I/O and SlateDB internals are verified with real-process crash/chaos tests rather than pretending a partial simulator covers third-party thread pools.

Research references: [DBSP](https://docs.feldera.com/vldb23.pdf), [Shared Arrangements](https://arxiv.org/abs/1812.02639), and [Timely capability accounting](https://timelydataflow.github.io/timely-dataflow/chapter_2/chapter_2_4.html).
