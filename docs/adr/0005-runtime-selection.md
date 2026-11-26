# ADR 0005: lean native Arrow/DataFusion runtime with evidence-triggered fallback

**Status:** Proposed working choice; validated in G0.4. **Date:** 2026-11-26. **Owners:** runtime, compiler, and storage leads.

## Decision

Build a **lean Rockstream-native Rust runtime** over weighted Apache Arrow batches, DataFusion (SQL parsing and selected expression kernels), and Tokio (async I/O and task coordination), applying DBSP incremental semantics. Selectively reuse reviewed donor algorithms and regression corpora from Rockstream v1 via the donor disposition register ([migration](../planning/migration.md#donor-assets-and-regression-transfer)).

### Staged execution complexity (build step by step)

1. **G0.4–G2 (Acyclic, scalar-epoch, single-interval kernel):** Constrain the initial runtime to acyclic computation graphs, scalar domain epochs, weighted Arrow batches, deterministic error semantics, explicit prepare/publish boundaries, and **one active maintenance interval per publication domain** (with operator/partition parallelism inside the interval and concurrency across independent domains).
2. **G3–G4 (Bounded single-depth pipelining):** Once single-interval correctness and recovery are proven, overlap compute for interval `k+1` against durable S3 staging/publication of interval `k` (bounded to depth 1, with exact-parent invalidation if `k` aborts) so single-domain cloud freshness is not serialized behind object-store flush latency.
3. **G5 (Advanced execution):** General recursion, nested iteration time, and multi-step speculation remain separately gated capabilities.

### Practical G0 selection rule (avoid building two engines upfront)

Building two full comparable runtimes (native *and* Timely/Differential) before G1 slows delivery without proportional risk reduction—especially while the initial kernel is strictly acyclic and scalar-epoch, where Timely's multidimensional progress tracker provides minimal advantage and substantial adapter friction against object-store checkpoints and suspension.

Instead, **G0.4 builds and evaluates the minimal native kernel on `W1-G`** against predeclared correctness, resource-bound, and complexity criteria:
- **Keep native** if it passes exact independent-oracle parity, handles retractions/both-side join updates/empty initialization cleanly, enforces bounded queues/memory, and keeps progress/lifecycle code small and maintainable.
- **Trigger Timely/Differential or Feldera/DBSP component evaluation** if the native kernel hits a concrete complexity, progress-accounting, or performance wall in G0.4—or later in G5 if general recursive/nested-iteration workloads prove uneconomical to build natively.

Keep the semantic IR, logical time, and durable storage/publication contracts decoupled from runtime scheduling so an evidence-triggered runtime substitution never forces rewriting the compiler or storage protocol.

## Consequences

- Focuses G0 engineering effort on the real existential risks (S3 metadata physics, SlateDB/immutable-delta layout, exact SQL semantics) instead of maintaining dual prototypes.
- Eliminates speculative plugin traits—maintain **one** production runtime at all times.
- Pure transition and operator logic runs directly in unit/property tests and deterministic state-machine replay; Tokio async I/O and SlateDB internals are verified with real-process crash/chaos tests rather than pretending a partial simulator covers third-party thread pools.

Research references: [DBSP](https://docs.feldera.com/vldb23.pdf), [Shared Arrangements](https://arxiv.org/abs/1812.02639), and [Timely capability accounting](https://timelydataflow.github.io/timely-dataflow/chapter_2/chapter_2_4.html).
