# ADR 0002: scope publication and make dependency cuts explicit

**Status:** Proposed. **Date:** 2026-11-25. **Owners:** storage/consistency and runtime roles.

## Context

A single cluster-wide progress boundary can couple unrelated workloads. Removing synchronization without a replacement contract can produce torn transactions or joins between individually committed but mutually inconsistent views. Existing Rockstream already has scoped frontier mechanisms; the new design must specify their end-to-end public meaning.

## Decision

Use a scalar total-order epoch per consistency domain and an exclusive published upper `U`. Complete source transactions are the indivisible input unit. An ingestion domain preserves co-transactional source tables; downstream result domains can independently consume its complete durable history. A publication group waits for all its required participants, and changes to that group are versioned catalog operations.

Cross-domain dependencies use explicit versioned imports at first. Compatible selected inputs have equal complete transaction boundaries for every shared source incarnation, include dependency closure, and retain their exact versions. Unrelated sources have no inferred global transaction guarantee. Numeric epochs across domains are never compared. If a compatible cut is not retained or cannot be reached, wait or fail; never choose independent latest values.

G2 uses a single domain. G4 adds independently progressing domains and qualified imports. Nested recursion time and arbitrary domain merge/split are later work. Cross-domain atomic writes are rejected initially.

## Alternatives

A global barrier is simpler and remains the local publication-group mechanism, but unnecessarily couples unrelated pipelines at cluster scale. Fully general vector clocks from day one add complex progress, compaction and query-selection obligations without first proving a benefit. Per-view latest-eventual reads improve apparent latency by weakening semantics; they do not satisfy the intended contract.

## Consequences and evidence

More domains can increase duplicate imported state and history pins. Explicit source cuts can make a cross-domain query unavailable while each individual view is readable. That is a visible, diagnosable consistency constraint. Shared ingestion does not guarantee every result group publishes at once; applications needing that behavior select one publication group.

G0 models input atomicity, import lineage and head transitions. G4 stalls one domain while advancing another, then attempts a shared-source join at mismatched cuts and confirms it waits/fails. The authoritative algorithm and pin requirements live in [consistency and storage](../design/consistency-and-storage.md).
