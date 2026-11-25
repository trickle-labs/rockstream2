# ADR 0009: logical MVCC for shared incremental state

**Status:** Proposed foundational contract; storage/runtime qualification unexecuted. **Date:** 2026-11-25. **Owners:** semantics, storage, runtime and serving roles.

## Context

Views need different freshness and maintenance schedules. A shared producer should be able to advance for a fast consumer while a slower consumer reads an older consistent state. Aligning physical checkpoints alone is too restrictive, and reading independent latest values can mix source transactions.

## Decision

Make logical MVCC a relation and arrangement contract, independent of SlateDB physical sequence numbers or checkpoint IDs. It supports consistent reads, shared maintenance, view builds/replacements and recovery obligations. It does not by itself provide general OLTP isolation, distributed atomic writes or correct publication.

A cut `C` contains input epochs `e < C`. Each history advertises:

| Boundary | Meaning |
| --- | --- |
| Computed upper `Cc` | Completion of computation, which may still be volatile |
| Durable published upper `Cp` | Certified durable completion; `Cp <= Cc` |
| Inclusive `since = S` | Earliest supported logical cut |
| Cut coverage | Exact supported cuts, normally every `S <= C <= Cp`; explicit gaps remain unavailable |

Genesis is cut zero with output `Q(empty)`. A write at epoch `e` is visible only when `Cp > e` and its dependency checks pass. Counters and source incarnations never wrap into reused authority.

A protected base `R(S)` plus timestamped output deltas for `S <= e < Cp` can reconstruct `R(C)`. Every advertised cut also has a protected, possibly compressed mapping to its source positions/incarnations, transaction/import dependency closure and applicable schema/semantics. Physical checkpoints protect these bytes; one may serve many logical cuts. Recovery retains any additional operator state or exact recipe required at the operator's published boundary.

Separate current-state access, logical history and physical checkpoint cadence. A committed current-state index can avoid replaying extensive history for common probes/joins; it may be a reconstructible cache when measured economics support that choice. Periodic consolidated bases bound historical reconstruction. Their creation is driven by explicit read amplification, retained-byte, compaction/request and recovery budgets, not by treating each logical epoch as a distinct physical database snapshot. New bases do not authorize dropping older promised cuts. [ADR 0004](0004-arrangement-storage.md) and the storage contract define the physical experiments.

Preserve results at **every promised cut**, including nonlinear intermediate results. For example, inserting a distinct value at epoch 10 and deleting it at 11 leaves no value at cut 12, but the value exists at cut 11. Consolidating only the endpoint difference loses that snapshot. The baseline processes complete epochs and retains their output history; coarser algorithms need a proof or an explicitly narrower supported-cut contract. Retained input alone does not certify immediate historical query support.

Each consumer has a durable cursor, freshness/scheduling policy, retained cut/replay obligation and independent history, maintenance and recovery budgets. Producers can advance without making all consumers publish together. Each result domain still has one atomic publication group. Sharing is optional: admit extra capacity, isolate a consumer through pinned replay and atomic retention handoff, or apply an explicitly declared expiry/resnapshot policy when cost exceeds its contract. Never silently erase required history or revoke another consumer's protection to meet a budget.

## Cut selection and retention

In one time domain, candidate cuts lie within `max(S_i) <= C <= min(Cp_i)` and every input's certified coverage. Select an eligible cut and its exact physical roots under durable protection, either atomically acquiring a pin or using the qualified [reader-group protocol](../design/consistency-and-storage.md#81-amortized-reader-protection). Latest selection remains linearizable even when protection is reused. Across domains, align complete shared-source boundaries through retained lineage and causal/transaction closure; never compare unrelated epoch numbers.

A consumer whose physical checkpoint ends at 80 and another whose checkpoint ends at 70 may both reconstruct cut 60 without either having checkpointed at 60. This is valid only if their histories and lineage certify that cut. A missing cut causes a wait, explicit rebuild or error.

Advancing `since` preserves all remaining advertised snapshots, source mappings and recovery dependencies. Physical replacement and logical retirement are coordinated with durable pins and GC through the metadata root. Expiry of a policy or process does not authorize a backend cleaner to bypass those roots. Completed reads require valid pin authorization.

## Consequences and evidence

MVCC trades synchronization for retained data, history-aware probes, compaction and metadata cost. It does not eliminate actual dependencies, shared hot spots, publication-group barriers or common metadata contention.

G0 falsifies cut reconstruction and nonlinear history preservation over SlateDB. G2 qualifies exact reads after restart; G3 covers independent local consumer schedules, slow-consumer budgets and disjoint checkpoint cadence; G4 qualifies general imported lineage and distributed pin/reassignment races. The normative conventions, reconstruction formula and GC rules are in [consistency and storage](../design/consistency-and-storage.md).
