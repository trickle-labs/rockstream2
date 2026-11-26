# ADR 0003: compositional object metadata, lease-backed fast reads, and optional Raft tier

**Status:** Proposed default architecture; physics validated in G0.2/G0.3. **Date:** 2026-11-26. **Owners:** storage/consistency and operations roles.

## Decision

Keep all authoritative cloud data **and metadata** in a qualified object store in the default **Object-Native** profile. The metadata kernel is an in-process library—no external etcd, ZooKeeper, Redis, SQL catalog, or continuously running external metadata cluster is required.

### 1. Single conditional root with compositional intra-batch serialization

Start with **one logical conditional metadata root per installation** pointing into immutable metadata pages (catalog, domain heads, ownership generations, pins, quotas, intents, and operation outcomes). Use single-key conditional `PUT` (`If-Match` / `If-None-Match`) as the primary primitive on S3-compatible object stores; evaluate [`slatedb-txn-obj` 0.17.0](https://docs.rs/slatedb-txn-obj/0.17.0/slatedb_txn_obj/) only if its current-version discovery avoids `ListObjects` on the read path.

An embedded bounded commit scheduler batches concurrent metadata mutations into one conditional root transition (`R → R+1`):
- Instead of rejecting any two operations that touch the same tenant quota, domain head, or pin set, the committer applies queued operations **sequentially in memory against a working tree derived from `R`**, validating each operation's exact preconditions against the in-batch state, then writes the resulting immutable tree pages and commits one CAS.
- Every admitted operation records its own stable identity and durable outcome inside the committed tree so lost responses and regrouped retries resolve idempotently without duplicating effects.
- A disposable preferred committer minimizes competing CAS storms in distributed deployments without holding independent authority.

### 2. Lease-backed fast reads and conservative GC deletion grace windows

Requiring two synchronous S3 root reads per query (pre-read selection plus post-read revalidation) makes sub-5 ms reads physically impossible and causes serving pools to hammer the metadata root. Rockstream 2 separates **logical unpinning** from **physical object deletion**:

- **Conservative physical-deletion grace window (`Δ_gc_grace`):** After metadata reachability marks an immutable object or checkpoint unreferenced, physical deletion waits for a conservative grace window (e.g., 5–15 minutes) that strictly exceeds the maximum short-query lease (`Δ_read_lease + clock_skew_bound << Δ_gc_grace`).
- **Fast-path warm reads (0 post-read S3 round-trips):** Short bounded reads holding a valid reader-group/snapshot lease and cached authorization grant (`bounded-staleness` / `allowed-stale` policies) serve directly from local/NVMe cache with **zero synchronous S3 metadata calls at query completion**, making sub-5 ms P99 warm reads achievable and insulating `allowed-stale` serving from brief metadata blips.
- **Strict modes remain explicit:** `latest-committed` performs a linearizable head check at selection (one authoritative root read under Object-Native; local/quorum read under Embedded Raft). `strict-immediate-revocation` is an opt-in security mode that performs synchronous post-read authorization revalidation at its documented latency cost.
- Long-running queries, repeatable transactions, and subscriptions acquire durable pins through the metadata root.

### 3. Honest dual cloud profiles (Object-Native default + optional Embedded Raft)

A single S3-CAS root has a physical latency floor (~200 ms–1 s end-to-end cloud freshness depending on S3 conditional PUT latency). Rather than claiming ≤100 ms cloud freshness on an unverified S3 CAS path, Rockstream 2 defines two explicit cloud profiles implementing the **same logical metadata state machine**:

| Profile | Metadata authority | Freshness / read envelope | Availability & suspension |
| --- | --- | --- | --- |
| **Object-Native (default, G2+)** | Single conditional object-store root | ~200 ms–1 s freshness; <5 ms warm bounded-staleness reads; ~20–60 ms strict-latest S3 reads | Zero resident coordinator; full zero-process hibernation for eligible workloads |
| **Low-Latency Cloud (optional, G4+)** | Embedded [OpenRaft](https://docs.rs/openraft/0.9.21/openraft/docs/getting_started/index.html) library inside the same Rockstream binary | Targets ≤100 ms freshness and high-rate strict-latest reads | Requires an active voter quorum for commits; stateless maintenance/serving workers still scale to zero |

Embedded OpenRaft is implemented only in G4 (or earlier only if partner workloads require ≤100 ms cloud freshness). If installation-wide throughput exceeds a single root even with compositional batching, scoped metadata partitioning (with modeled cross-root import/retention handoff) is a separate G4+ ADR.

## Alternatives and consequences

- **Mandatory external etcd/Postgres:** Rejected; violates the single-binary zero-external-dependency product thesis.
- **No-lease synchronous post-read S3 GET on every query:** Rejected as the default; physically precludes <5 ms warm reads and creates single-prefix S3 read storms. Retained only as an explicit `strict-immediate-revocation` opt-in.
- **Conflict-disjoint-only batching:** Rejected; fails under single-tenant multi-view workloads where operations share tenant quotas and `domain.input_head`. Compositional intra-batch serialization preserves exact per-operation validation while achieving high batch density.
- **Trade-off accepted:** Grace-window GC retains deleted immutable bytes for an extra 5–15 minutes (negligible cloud storage cost in exchange for eliminating post-read S3 GETs). Bounded-staleness auth caching accepts a configurable revocation propagation delay (seconds) unless the caller requests strict immediate revocation.

## Gate

- **G0.2:** Benchmark single-key S3 conditional `PUT` + compositional batching (including single-tenant shared-quota and same-domain writes) and measure warm lease-backed vs. strict-latest read latencies on real object storage.
- **G0.3:** Model publication, ownership fencing, compositional batch outcomes, and grace-window lease/GC safety in **Quint** with deliberate negative controls.
- **G2/G4:** Real-process crash recovery, ambiguous CAS response recovery, and (G4) distributed contention and optional OpenRaft profile qualification.

The normative state machine and backend requirements are in [consistency and storage](../design/consistency-and-storage.md).
