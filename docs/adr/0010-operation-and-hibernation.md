# ADR 0010: single binary, stateless compute scale-to-zero, and workload-eligible hibernation

**Status:** Proposed operational architecture; qualified progressively in G2 and G4. **Date:** 2026-11-26. **Owners:** runtime, storage, connectors, and operations roles.

## Context

Rockstream should be effortless to run locally and in the cloud, with one binary and no mandatory external etcd, ZooKeeper, Redis, SQL catalog, or Kubernetes. At the same time, **forcing zero-process full hibernation onto every online workload distorts read latency and metadata design** for workloads that cannot sleep anyway (continuous PostgreSQL CDC holding replication slots, interactive reads with an unmeasured sub-5 ms target, active subscriptions, and Kafka sinks).

## Decision

Ship **one binary with composable roles** across three simple topologies: embedded local process, single-process cloud (binary + object store), and distributed cloud (multiple instances of the same binary). Separate two distinct elasticity capabilities so neither distorts the other:

1. **Stateless compute scale-to-zero (all cloud profiles):** Maintenance and serving worker pools hold no authoritative state and scale down to zero whenever their workload is idle, while required ingestion or optional Raft voters remain active.
2. **Full zero-process hibernation (`Active → Draining → Dormant → Restoring → Active`, Object-Native profile only):** Supported for **eligible workloads**—scheduled, intermittent, dev/staging, or batch-replayed pipelines that have no live continuous-ingestion slot, due timer, active subscription, or tight cold-read latency SLA, and have a documented manual or external platform activation trigger.

### Full hibernation contract (for eligible Object-Native workloads)

Before entering `Dormant`: serialize admissions/wake requests against the transition, protect all accepted input, published roots, history, and outbox state via non-expiring metadata/checkpoint references, and fence retiring owners in metadata. On resume, an external caller or launcher starts the binary; it reads the authoritative root, acquires fresh ownership generations via CAS, verifies source/cursor continuity, and replays accepted unpublished input. Concurrent activators and crashes mid-drain use the exact same fencing and recovery protocol as crash recovery.

### Honest eligibility boundaries

| Workload characteristic | Supported elasticity mode |
| --- | --- |
| Scheduled/intermittent views, dev/staging, replayable Kafka with long retention | Full zero-process hibernation (Object-Native profile) |
| Continuous PostgreSQL CDC (holding WAL slots), active Kafka sinks, durable timers | Partial suspension (stateless maintenance/serving scale to zero; ingester/sink stays active) |
| Low-latency interactive read models (unmeasured `<10 ms` strict-latest target; or unmeasured `≤100 ms` P99 freshness target with optional fast WAL tier) | Low-Latency Cloud profile (Embedded OpenRaft voters resident with durable voter disks; stateless workers elastic), only after G4.0 evidence |

## Alternatives and consequences

- **Making full zero-process hibernation a hard P0 veto over every online profile:** Rejected; penalizes the primary online read-model and CDC workloads for a dormancy capability those workloads cannot legally enter.
- **Requiring an external coordinator cluster:** Rejected; both Object-Native and optional Embedded Raft profiles run entirely inside the single Rockstream binary.

## Evidence

G2 qualifies single-process durable stop/restart from object storage with empty local caches; G3b accounts for shared consumer cursors; G4 qualifies distributed drain, concurrent activation, and stale-owner fencing; G6 qualifies runbooks and measured active/idle economics. [Runtime and operations](../design/runtime-and-operations.md) defines the detailed lifecycle.
