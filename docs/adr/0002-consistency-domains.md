# ADR 0002: independent publication groups with compatible logical cuts

**Status:** Proposed architectural commitment; implementation unqualified. **Date:** 2026-11-25. **Owners:** storage/consistency and runtime roles.

## Context

A global progress barrier couples unrelated workloads. Removing it without another contract permits torn source transactions or inconsistent joins between committed views. Logical MVCC can decouple consumers' schedules while preserving exact read cuts, but it does not remove transaction boundaries or actual data dependencies.

## Decision

Use scalar ordered epochs within a consistency domain. A cut `C` contains epochs `e < C`; computed and durable published uppers are separate. Preserve complete source transactions in an ingestion domain. Every result domain has **one atomic publication group**, and multiple result domains can consume the same durable input/history at different rates. Views requiring joint atomic publication belong to one group; a slow required participant still delays that group. The optimizer cannot silently change its boundary.

Sharing an arrangement does not merge publication groups. Consumers keep independent cursors, maintenance schedules and retention obligations. Certified retained history reconstructs exact logical cuts even if physical checkpoints occur at different times. Missing history, unsupported cuts and quota exhaustion have explicit wait, failure or resnapshot outcomes; sharing cannot promise unlimited free retention.

Cross-domain dependencies use versioned imports. Selected inputs must agree on the complete boundary for every overlapping source incarnation and satisfy transaction/import dependency closure. Every advertised logical cut has a protected mapping to that lineage and its applicable schema/semantics. Unrelated sources have no inferred global transaction guarantee. Numeric epochs in different domains are never compared.

G2 uses one domain. G3 qualifies independent local consuming result domains over common input/history. G4 adds distributed groups and general cross-domain imports. Domain merging/splitting, cross-domain atomic writes and arbitrary recursive import cycles are separate work.

## Alternatives and consequences

A global barrier is simpler but delays unrelated workloads. General vector clocks from the outset add complexity before demonstrating value; scalar domain time and explicit lineage are the initial choice. Independent latest values do not meet the promised consistent-read contract.

More groups can increase metadata traffic, imported state and retained history. A query can be temporarily unavailable even while each input is individually readable. MVCC improves the chance of finding a common cut; it cannot reconstruct a discarded or semantically invalid result. The cost model may choose isolated physical copies when schedules, history or SLOs conflict.

## Evidence

G0 models complete transactions, independent heads, logical history and import lineage. G3 stalls one local consumer while another advances shared state, then reconstructs a common cut from disjoint checkpoint schedules. G4 repeats the contract across processes and tests incompatible source incarnations and causal cuts. The authoritative selection and pin rules are in [consistency and storage](../design/consistency-and-storage.md); [ADR 0009](0009-logical-mvcc.md) defines the MVCC boundary.
