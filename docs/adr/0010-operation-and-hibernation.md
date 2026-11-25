# ADR 0010: one binary with durable suspension and hibernation

**Status:** Proposed requirement; no stop/resume or operational qualification has run. **Date:** 2026-11-25. **Owners:** runtime, storage, connectors and operations roles.

## Context

Rockstream should be easy to run for one small workload and for a distributed installation. An idle database should not require an always-on coordination cluster merely to preserve its state. Shared computation and streaming ingestion can nevertheless impose real work, retention and freshness obligations while an individual view is idle.

## Decision

Ship one binary with composable roles. Support an embedded process with qualified durable local storage, one cloud process plus a qualified object-store bucket, and a distributed deployment of the same binary. No profile requires etcd, ZooKeeper, Redis, a separate catalog database or Kubernetes. Compiled libraries are ordinary implementation dependencies. Use the object-backed metadata direction in [ADR 0003](0003-publication-and-metadata.md); eligible running processes perform coordination, with no dedicated resident coordinator required by the sleeping profile.

Separate authoritative state from disposable compute. Protected data and metadata survive the loss of every cloud worker and its local cache. SlateDB is the preferred state backend. The local embedded adapter must qualify crash durability and exclusive ownership; a filesystem adapter is not assumed to provide the cloud conditional-update contract without validation.

Support continuous, freshness-batched, scheduled and on-demand maintenance. Logical MVCC and per-consumer cursors let one consumer sleep while another advances a shared arrangement, subject to retained history and explicit publication dependencies. Whole-deployment hibernation is a distinct, admitted lifecycle transition, `Active → Draining → Dormant → Restoring → Active`, recorded in authoritative metadata.

Each consumer has an independent retention, maintenance and recovery budget. For scheduled or on-demand work, compare continuous maintenance, retaining incremental history, replay from a protected base/input log, and rebuild from a durable snapshot with a certified tail. Choose only among qualified strategies satisfying the same source, retained-cut and freshness obligations, including cold reconstruction and catch-up. Rebuilding current state cannot replace promised history; initial required state stays durable until any replacement recipe and retention handoff are qualified. Isolate an expensive consumer when sharing costs more or violates another consumer's admitted SLO.

Before dormancy, serialize admissions and wake requests against the transition; publish completed work or retain accepted input for replay; protect exact state, history, outbox and recovery roots; and fence retiring owners. Protection cannot rely on the stopped process renewing a lease or checkpoint. On resume, re-read the authoritative root, conditionally acquire fresh generations, validate source/cursor continuity, restore protected state and replay under the ordinary correctness protocol. Concurrent activators and a crash during drain/resume must be safe.

## What full hibernation requires

| Requirement | Contract |
| --- | --- |
| Input and source continuity | Qualify upstream retention for the full sleep and catch-up interval, or have no continuing input obligation. If ingestion must remain active, only other pools can suspend; this is partial suspension. A lost interval causes explicit resnapshot/rebuild. |
| Freshness and temporal work | Admit sleep only if deadlines permit it; durable timers still require activation when due. |
| Reads, subscriptions and sinks | Honor existing pin/cursor/delivery obligations or close/transfer them under their contracts. Retain pending outbox data. |
| Retention | Preserve roots and replay coverage independently of live processes; include dormant storage and deferred cleanup in quotas/cost. |
| Activation | Manual restart or a configured platform/launcher trigger starts the process. A fully stopped binary cannot receive a new request or wake itself. |
| Resume latency | Include startup, restore and catch-up in the cold request's deadline; warm-cache targets do not apply. |

An always-on gateway or external event/schedule trigger is an optional integration with its own cost. A binary-plus-bucket deployment supports manual hibernation and restart without mandating such an integration. Full Rockstream scale-to-zero means zero running Rockstream processes; stopping only eligible pools is partial suspension. Neither means zero storage cost, continuous ingestion without an ingester, or automatic activation without a live trigger.

## Alternatives and consequences

A required external coordination cluster adds a separate operational system and idle capacity floor. Embedding a Raft library can avoid a separately installed service, but [Raft requires majority agreement](https://raft.github.io/raft.pdf) for committed decisions; it does not alone supply activation, source retention, or a hibernation protocol. Keep embedded Raft as an evidence-driven alternative if the object-backed metadata design cannot satisfy measured needs. Adopting it would require explicit storage, membership, restart and sleeping-profile qualification.

The chosen design accepts object-store request latency and an initially shared metadata root as costs to measure. Batching, history retention, cache restoration and consumer isolation need explicit budgets. Sleep can save compute but increase retained storage and wake-up work. Report these effects through sleep eligibility/blockers, active roles, consumer cursors, expected catch-up, and measured cold-start cost.

The object-native profile remains the default and may qualify zero-process hibernation from protected object state. An embedded-consensus profile uses the same logical metadata state machine but has its own durable log, membership, active-quorum and stop/restart contract; it cannot inherit the object-native hibernation claim. If source or freshness obligations defeat full hibernation, offer explicitly qualified partial suspension. No failed economic experiment relaxes recovery or retention guarantees.

## Evidence and gates

G0 runs an object-metadata contention probe and a complete stop/resume experiment with empty caches. G2 establishes single-process durable suspension and failure recovery. G3 adds independent shared consumers, cursor expiry/resnapshot and retained logical history. G4 proves distributed drain, concurrent wake-up and stale-owner rejection. G6 qualifies operators' runbooks, realistic idle/active cycles, connectors, restore and complete cost. These are required experiments, not results established by this ADR.

The detailed lifecycle and obligation matrix are in [runtime and operations](../design/runtime-and-operations.md); atomic publication, pin/GC races and recovery authority are governed by [consistency and storage](../design/consistency-and-storage.md).
