# ADR 0002: independent publication groups with compatible logical cuts

**Status:** Proposed architectural commitment; implementation unqualified. **Date:** 2026-11-25. **Owners:** storage/consistency and runtime roles.

## Context

A global progress barrier couples unrelated workloads. Removing it without another contract permits torn source transactions or inconsistent joins between committed views. Logical MVCC can decouple consumers' schedules while preserving exact read cuts, but it does not remove transaction boundaries or actual data dependencies.

## Decision

Use scalar ordered epochs within a consistency domain. A cut `C` contains epochs `e < C`; computed and durable published uppers are separate. Preserve complete source transactions in an ingestion domain. Every result domain has **one atomic publication group**, and multiple result domains can consume the same durable input/history at different rates. By default from G2 onward, each independent materialized view receives its own lightweight result publication head (so a runtime error in one view quarantines only that view), while views requiring joint atomic visibility are placed into one explicitly named **atomic publication group** (`WITH (publication_group = '...')`); a slow or failing required participant halts its group. The optimizer cannot silently change this boundary.

Sharing an arrangement never implicitly merges publication groups. G3b-S initially shares only inside an explicitly selected group and cadence, including its coupled quarantine boundary. G3b-I adds sharing across independent groups: consumers keep independent cursors, maintenance schedules and retention obligations. Certified retained history reconstructs exact logical cuts even if physical checkpoints occur at different times. Missing history, unsupported cuts and quota exhaustion have explicit wait, failure or resnapshot outcomes; sharing cannot promise unlimited free retention.

Cross-domain dependencies use versioned imports. Selected inputs must agree on the complete boundary for every overlapping source incarnation and satisfy transaction/import dependency closure. Every advertised logical cut has a protected mapping to that lineage and its applicable schema/semantics. Unrelated sources have no inferred global transaction guarantee. Numeric epochs in different domains are never compared.

G2 uses one ingestion domain with per-view or explicitly grouped publication heads. G3b-S qualifies same-group sharing; G3b-I qualifies independent scheduling across local consuming result domains over common input/history ([ADR 0013](0013-minimum-mechanisms-and-independent-qualification.md)). G4 adds distributed groups and general cross-domain imports. Domain merging/splitting, cross-domain atomic writes and arbitrary recursive import cycles are separate work.

## Alternatives and consequences

A global barrier is simpler but delays unrelated workloads. General vector clocks from the outset add complexity before demonstrating value; scalar domain time and explicit lineage are the initial choice. Independent latest values do not meet the promised consistent-read contract.

More groups can increase metadata traffic, imported state and retained history. A query can be temporarily unavailable even while each input is individually readable. MVCC improves the chance of finding a common cut; it cannot reconstruct a discarded or semantically invalid result. The cost model may choose isolated physical copies when schedules, history or SLOs conflict.

## Evidence

`G0.3` models publication atomicity, expected-parent CAS, ownership-generation fencing, idempotent operation outcomes, and abstract GC reachability in Quint (per [ADR 0012](0012-staged-mechanism-adoption.md)); `G2` exercises per-view and explicitly grouped publication heads with durable view quarantine. `G3b-I` stalls one local consumer while another advances shared state, then reconstructs a common cut from disjoint checkpoint schedules. `G4` repeats the contract across processes and tests cross-domain imports, incompatible source incarnations, and causal cuts. The authoritative selection and pin rules are in [consistency and storage](../design/consistency-and-storage.md); [ADR 0009](0009-logical-mvcc.md) defines the MVCC boundary.
