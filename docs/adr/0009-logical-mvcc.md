# ADR 0009: bounded logical MVCC decoupled from physical checkpoints

**Status:** Proposed foundational contract; gate placement refined by [ADR 0012](0012-staged-mechanism-adoption.md). **Date:** 2026-11-26. **Owners:** semantics, storage, runtime, and serving roles.

## Decision

Make logical MVCC a relation and arrangement contract independent of SlateDB physical sequence numbers or checkpoint IDs. A cut `C` contains input epochs `e < C`. **Stage:** G2/G3a advertise latest, pinned and a bounded recent set of published versions and promise published interval-boundary cuts. Full arbitrary-cut coverage `[S_hot, Cp]` is adopted at G3b ([ADR 0012](0012-staged-mechanism-adoption.md)).

Each history advertises:

| Boundary | Meaning |
| --- | --- |
| Computed upper `Cc` | Completed evaluation (may still be volatile) |
| Durable published upper `Cp` | Certified durable publication; `Cp <= Cc` |
| Inclusive `since = S` | Earliest supported logical cut |
| Cut coverage | Exact supported cuts: fine-grained in `[S_hot, Cp]` plus named periodic checkpoint cuts in `[S, S_hot)` |

Genesis is cut zero with output `Q(empty)`. Counters and source incarnations never wrap into reused authority.

### Practical bounded retention granularity

Storing uncoalesced per-epoch nonlinear outputs (`DISTINCT`, `MIN`/`MAX`, outer joins) for days on high-churn keys inside an LSM tree causes unbounded version explosion. Rockstream 2 therefore makes history granularity explicit and bounded:
- **Hot fine-grained window (`[S_hot, Cp]`):** Retains periodic SlateDB checkpoints (including a checkpoint at or before `S_hot`) paired with per-epoch immutable delta segments (including nonlinear intermediate transitions). Serving a point lookup or scan at *any* cut `C ∈ [S_hot, Cp]` opens the nearest preceding checkpoint `Cp_ckpt(C) <= C` and applies the bounded in-memory overlay `(Cp_ckpt(C), C]`—eliminating both LSM multi-version explosion and undo deltas while supporting active pins, short historical queries, consumer catch-up, and cross-domain cut alignment without aligned checkpoints.
- **Longer retention (`[S, S_hot)`):** Uses periodic consolidated checkpoint bases (or explicitly budgeted immutable delta archives) rather than promising unbounded millisecond-granularity nonlinear history inside the working SlateDB index.
- Every advertised cut carries a protected mapping to its source positions, transaction/import dependency closure, and schema/semantic version. Missing or expired cuts always fail explicitly (`RESNAPSHOT_REQUIRED` or unavailable-history error), never silently returning newer data.

### Cut selection and lease-backed protection

In one domain, eligible common cuts lie within `max(S_i) <= C <= min(Cp_i)` and every input's certified coverage. Across domains, align complete shared-source boundaries via retained lineage—never compare unrelated numeric epochs.

Through G3b, ordinary reads run in the owning process under in-process pins; long-running historical queries, repeatable reads, tokens and subscriptions acquire durable pins through the metadata root. At G4, out-of-process short reads may use reader-group/snapshot leases checked against `monotonic_now() < lease_deadline` before response flush and protected by the sweeper-observed GC physical-deletion grace window ([ADR 0003](0003-publication-and-metadata.md)). The lease clock must count suspended time; a detected clock discontinuity is lease loss. Advancing `since` preserves every pinned cut and recovery dependency.

## Consequences and evidence

Separating immutable delta traces from the working SlateDB index with a bounded delta overlay ([ADR 0004](0004-arrangement-storage.md)) and bounding fine-grained nonlinear history keeps LSM compaction fast while preserving exact historical point lookups and scans where needed.

G0.2 compares storage layouts and exercises one in-process historical lookup at a retained earlier cut; it does not qualify arbitrary-cut MVCC. G2 qualifies published-boundary reads after restart; G3b qualifies exact arbitrary-cut reconstruction, nonlinear intermediate transitions, independent consumer schedules and disjoint checkpoint cadences; G4 qualifies leases, separate-process readers and cross-domain imported lineage. The normative rules are in [consistency and storage](../design/consistency-and-storage.md).
