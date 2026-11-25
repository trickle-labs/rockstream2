# ADR 0005: prefer a lean native runtime and verify the choice

**Status:** Proposed working choice; G0 comparison may change the implementation. **Date:** 2026-11-25. **Owners:** runtime, compiler and storage leads.

## Context and decision

Prefer a lean **Rockstream-native Rust runtime** organized around weighted Arrow batches, logical MVCC, a shared workload graph, asynchronous storage and independent consumer schedules. Use DataFusion for the SQL frontend and selected expression kernels, and Tokio for asynchronous I/O and coordination. Reuse existing Rockstream algorithms and verification/test infrastructure after auditing their contracts. This targets a simple integrated implementation of Rockstream's persistence, lifecycle, and scheduling requirements; it is not evidence that native execution is faster.

DBSP is the semantic foundation, separate from Feldera's runtime implementation. Timely/Differential remains a serious alternative and reference for progress, arrangements and incremental execution. General incrementalization, progress accounting, recursion and shared traces are difficult to rebuild correctly; adopting an external runtime can also require substantial adaptation to exact durable versions, suspension and resource controls. Neither difficulty is settled by preference.

G0 compares the minimal native slice with **Timely/Differential Dataflow** on the same contract and assesses **Feldera/DBSP runtime components** for selective reuse or a smaller adapter. The comparison can reverse the working choice. Reusing libraries does not imply adopting another product's full SQL surface, control plane or licensing model. Verify the exact candidate revision, license and supported APIs in P0.6 before committing dependencies. Avoid building a general runtime/plugin abstraction before the experiment identifies an actual need.

## Common experiment

Run the same customers/orders grouped-join history, including duplicates, simultaneous changes, deletes and empty initialization. Compare first-order execution with a bounded eligible partial-aggregation/factorization prototype. Add two views sharing state at different maintenance cadences, reads at retained logical cuts across different physical checkpoint boundaries, a view created from a snapshot while updates continue, a staged-state crash/retry, a deliberately delayed abandoned-attempt packet, state beyond the memory budget, complete stop/resume with empty caches, and one multi-process exchange where feasible. Record unavailable features as gaps; do not relabel a weaker execution contract as a comparable result.

| Criterion | Required evidence |
| --- | --- |
| Semantics | Exact typed output against independent evaluator, not just throughput |
| State boundary | Logical-cut reads over protected SlateDB state, bounded history, nonauthoritative RAM, restore from exact published parent |
| Progress | Work/capability accounting, separate computed/published uppers and controlled epoch completion under replay |
| Sharing/lifecycle | Safe attach/detach, independent consumer cursors, backfill/catch-up and retention obligations without a gratuitous global publication barrier |
| Suspension | No required resident worker/coordinator in a qualified sleeping deployment; durable restart and explicit activation/retention costs |
| Resource behavior | Bounded queues, reservations, spill and cancellation without deadlock |
| Integration cost | Adapter complexity, unsupported extension points, maintenance risk and license fit |
| Performance | CPU, memory, durable bytes/requests and recovery cost for the same semantics |
| Testability | Production logic runs under deterministic environment controls |

Record a weighted decision matrix only after declaring non-negotiable pass/fail criteria. A candidate failing recovery or semantics cannot win on a weighted throughput score. If no candidate meets the full boundary, choose the smallest qualified substrate and defer advanced functionality while building the missing layer. The native candidate must justify the algorithms and maintenance burden it owns against measured adaptation cost; familiarity is not evidence. Preserve the comparison results, including cases where reuse wins.

## Consequences

The implementation plan's crate/API boundaries are architectural responsibilities, not a promise to write every mechanism from scratch. SlateDB remains the preferred storage implementation; the runtime does not grow a custom storage engine or consensus protocol. One production execution path serves embedded and distributed deployments. Advanced recursion may initially remain restricted if the selected substrate's nested progress/persistence integration is not qualified. G3 qualifies the initial partial-aggregation/factorization family; broader higher-order and automatic adaptation remain G5 capabilities.

Research references include [shared arrangements](https://arxiv.org/abs/1812.02639), [Timely capability accounting](https://timelydataflow.github.io/timely-dataflow/chapter_2/chapter_2_4.html), and [Feldera's DBSP publications](https://docs.feldera.com/literature/papers/). These motivate the candidates; only the experiment determines fit for this design.
