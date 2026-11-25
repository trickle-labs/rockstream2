# ADR 0005: select the execution substrate with a bounded experiment

**Status:** Open component choice; required contracts fixed by the proposed design. **Date:** 2026-11-25. **Owners:** runtime, compiler and storage leads.

## Context and decision

General incrementalization, progress accounting, recursion and shared traces are difficult to rebuild correctly. Conversely, adopting a runtime whose state/recovery/lifecycle model cannot support durable versioned arrangements can move complexity into an unmaintainable adapter. Choose after a comparable G0 experiment rather than declaring a custom runtime by default.

Evaluate **Timely/Differential Dataflow**, **Feldera/DBSP runtime components**, and a **minimal custom vectorized executor**. Reusing libraries does not imply adopting another product's full SQL surface, control plane or licensing model. Verify the exact candidate revision, license and supported APIs in P0.6 before committing dependencies.

## Common experiment

Run the same customers/orders grouped-join history, including duplicates, simultaneous changes, deletes and empty initialization. Add two views sharing state, a view created from a snapshot while updates continue, a staged-state crash/retry, a deliberately delayed abandoned-attempt packet, state beyond the memory budget, and one multi-process exchange where feasible.

| Criterion | Required evidence |
| --- | --- |
| Semantics | Exact typed output against independent evaluator, not just throughput |
| State boundary | Exact pinned import/export, nonauthoritative RAM, restore from published parent |
| Progress | Work/capability accounting and controlled epoch completion under replay |
| Sharing/lifecycle | Safe attach/detach, backfill/catch-up, consumer retention obligations |
| Resource behavior | Bounded queues, reservations, spill and cancellation without deadlock |
| Integration cost | Adapter complexity, unsupported extension points, maintenance risk and license fit |
| Performance | CPU, memory, durable bytes/requests and recovery cost for the same semantics |
| Testability | Production logic runs under deterministic environment controls |

Record a weighted decision matrix only after declaring non-negotiable pass/fail criteria. A candidate failing recovery or semantics cannot win on a weighted throughput score. If no candidate meets the full boundary, choose the smallest qualified substrate and defer advanced functionality while building the missing layer. The custom candidate must demonstrate why reuse fails; unfamiliarity is not evidence.

## Consequences

The implementation plan's crate/API boundaries are architectural responsibilities, not a promise to write every mechanism from scratch. One production execution path serves embedded and distributed deployments. Advanced recursion may initially remain restricted if the selected substrate's nested progress/persistence integration is not qualified.

Research references include [shared arrangements](https://arxiv.org/abs/1812.02639), [Timely capability accounting](https://timelydataflow.github.io/timely-dataflow/chapter_2/chapter_2_4.html), and [Feldera's DBSP publications](https://docs.feldera.com/literature/papers/). These motivate the candidates; only the experiment determines fit for this design.
