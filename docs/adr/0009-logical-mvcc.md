# ADR 0009: bounded logical MVCC decoupled from physical checkpoints

**Status:** Proposed foundational contract; physics validated in G0.2. **Date:** 2026-11-26. **Owners:** semantics, storage, runtime, and serving roles.

## Decision

Make logical MVCC a relation and arrangement contract independent of SlateDB physical sequence numbers or checkpoint IDs. A cut `C` contains input epochs `e < C`. Each history advertises:

| Boundary | Meaning |
| --- | --- |
| Computed upper `Cc` | Completed evaluation (may still be volatile) |
| Durable published upper `Cp` | Certified durable publication; `Cp <= Cc` |
| Inclusive `since = S` | Earliest supported logical cut |
| Cut coverage | Exact supported cuts: fine-grained in `[S_hot, Cp]` plus named periodic checkpoint cuts in `[S, S_hot)` |

Genesis is cut zero with output `Q(empty)`. Counters and source incarnations never wrap into reused authority.

### Practical bounded retention granularity

Storing uncoalesced per-epoch nonlinear outputs (`DISTINCT`, `MIN`/`MAX`, outer joins) for days on high-churn keys inside an LSM tree causes unbounded version explosion. Rockstream 2 therefore makes history granularity explicit and bounded:
- **Hot fine-grained window (`[S_hot, Cp]`):** Preserves exact per-epoch immutable delta segments (including nonlinear intermediate transitions) for active pins, short historical queries, consumer catch-up, and cross-domain cut alignment—without requiring aligned physical checkpoints.
- **Longer retention (`[S, S_hot)`):** Uses periodic consolidated checkpoint bases (or explicitly budgeted immutable delta archives) rather than promising unbounded millisecond-granularity nonlinear history inside the working SlateDB index.
- Every advertised cut carries a protected mapping to its source positions, transaction/import dependency closure, and schema/semantic version. Missing or expired cuts always fail explicitly (`RESNAPSHOT_REQUIRED` or unavailable-history error), never silently returning newer data.

### Cut selection and lease-backed protection

In one domain, eligible common cuts lie within `max(S_i) <= C <= min(Cp_i)` and every input's certified coverage. Across domains, align complete shared-source boundaries via retained lineage—never compare unrelated numeric epochs.

Ordinary short reads reuse bounded reader-group/snapshot leases protected by the conservative GC physical-deletion grace window ([ADR 0003](0003-publication-and-metadata.md)); long-running historical queries and subscriptions acquire durable pins through the metadata root. Advancing `since` preserves every pinned cut and recovery dependency.

## Consequences and evidence

Separating immutable delta traces from the working SlateDB index ([ADR 0004](0004-arrangement-storage.md)) and bounding fine-grained nonlinear history keeps LSM compaction fast while preserving exact historical cuts where needed.

G0.2 validates exact cut reconstruction and nonlinear intermediate transitions on real object storage; G2 qualifies exact reads after restart; G3 qualifies independent consumer schedules and disjoint checkpoint cadences; G4 qualifies cross-domain imported lineage. The normative rules are in [consistency and storage](../design/consistency-and-storage.md).
