# ADR 0003: compositional object metadata, lease-backed fast reads, and optional Raft tier

**Status:** Proposed default architecture; physics validated in G0.2/G0.3. **Date:** 2026-11-26. **Owners:** storage/consistency and operations roles.

## Decision

Keep all authoritative cloud data **and metadata** in a qualified object store in the default **Object-Native** profile. The metadata kernel is an in-process library—no external etcd, ZooKeeper, Redis, SQL catalog, or continuously running external metadata cluster is required.

### 1. Single conditional root with pre-allocated owner namespaces and compositional batching

Start with **one logical conditional metadata root per installation** pointing into immutable metadata pages (catalog, domain heads, ownership generations, pins, quotas, and operation outcomes). Use single-key conditional `PUT` (`If-Match` / `If-None-Match`) as the primary primitive on S3-compatible object stores; evaluate [`slatedb-txn-obj` 0.17.0](https://docs.rs/slatedb-txn-obj/0.17.0/slatedb_txn_obj/) only if its current-version discovery avoids `ListObjects` on the read path.

- **Pre-allocated owner-generation namespaces:** Upon acquiring ownership generation `g`, an owner receives a protected open allocation namespace (`attempts/{domain}/{g}/...`), removing a separate per-interval intent-registration CAS from the critical path. Worker liveness heartbeats stay outside the metadata root (ephemeral peer gossip or lightweight advisory objects); the root only records durable ownership transitions.
- **Compositional intra-batch serialization:** Instead of rejecting any two operations that touch the same tenant quota, domain head, or pin set, the embedded commit scheduler applies queued operations **sequentially in memory against a working tree derived from `R`**, validating each operation's exact preconditions against the in-batch state, then writes the resulting immutable tree pages and commits one CAS (`R → R+1`).
- **Idempotent per-operation outcomes:** Every admitted operation records its own stable identity and durable outcome inside the committed tree so lost responses and regrouped retries resolve idempotently without duplicating effects.
- **Disposable preferred committer with clean fallback:** In distributed deployments (G4), an advisory endpoint hint routes batches to one preferred committer to prevent CAS storms; if unreachable or slow, callers fail over to a newly hinted committer or fall back directly to conditional S3 root CAS with jittered backoff—requiring zero external coordination.

### 2. Monotonic lease-backed fast reads and sweeper-observed GC grace windows

Requiring two synchronous S3 root reads per query (pre-read selection plus post-read revalidation) makes sub-5 ms reads physically impossible and causes serving pools to hammer the metadata root. Rockstream 2 separates **logical unpinning** from **physical object deletion**:

- **Sweeper-observed conservative physical-deletion grace window (`Δ_gc_grace`):** After metadata reachability marks an immutable object or checkpoint unreferenced and commits its tombstone, physical deletion waits at least `Δ_gc_grace` (default 10–15 minutes) measured on the GC sweeper's own monotonic clock after observing the committed tombstone (or verified object-store server timestamps), strictly exceeding the maximum short-query lease (`Δ_read_lease + clock_skew_bound << Δ_gc_grace`) without relying on synchronized distributed wall clocks.
- **Monotonic-checked fast-path warm reads (0 post-read S3 round trips):** Short bounded reads holding a valid local reader-group/snapshot lease and cached authorization grant (`bounded-staleness` / `allowed-stale` policies) read directly from local/NVMe cache and the bounded delta overlay, then check `monotonic_now() < lease_deadline` *after* reading bytes and *before* flushing the response—ensuring a paused or frozen VM cannot return stale or revoked data while eliminating post-read S3 calls.
- **Strict modes remain explicit:** `latest-committed` performs a linearizable head check at selection (`<10 ms` under Embedded OpenRaft; one S3 root read under Object-Native). `strict-immediate-revocation` is an opt-in security mode that performs synchronous post-read authorization revalidation at its documented latency cost.
- Long-running queries, repeatable transactions, and subscriptions acquire durable pins through the metadata root.

### 3. Honest dual cloud profiles (Object-Native default + optional Embedded Raft)

A single S3-CAS root plus S3 Standard data segments has an honest physical latency envelope (~150 ms–1.5 s end-to-end cloud freshness across input PUT, input CAS, delta/manifest PUT, and publication CAS). Rockstream 2 defines two explicit cloud profiles running the **same logical metadata state machine**:

| Profile | Metadata & data authority | Freshness / read envelope | Availability & suspension |
| --- | --- | --- | --- |
| **Object-Native (default, G2+)** | Single conditional object-store root + S3 Standard segments | ~150 ms–1.5 s end-to-end freshness (S3 P50–P99); `<5 ms` warm bounded-staleness reads; ~20–60 ms strict-latest S3 reads | Zero resident coordinator; every process/disk disposable; full zero-process hibernation for eligible workloads |
| **Low-Latency Cloud (optional, G4+)** | Embedded [OpenRaft](https://docs.rs/openraft/0.9.21/openraft/docs/getting_started/index.html) metadata inside the Rockstream binary; S3 Standard segments (or optional separately qualified cross-AZ fast WAL tier) | `<10 ms` strict-latest reads and high-rate metadata commits; ~100–300 ms freshness on S3 Standard segments, or `≤100 ms` P99 only with the optional replicated fast WAL tier | Active voter quorum with durable voter/WAL disks required for commits; stateless maintenance/serving workers still scale to zero |

Embedded OpenRaft is compiled into the single Rockstream binary (not an external service) and implemented only in G4 (or earlier if partner workloads require `<10 ms` strict-latest reads or high-rate metadata commits). Any profile transition or replicated fast WAL tier requires its own durability, failover, and backup/restore qualification. If installation-wide throughput exceeds a single root even with compositional batching, scoped metadata partitioning is a separate G4+ ADR.

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
