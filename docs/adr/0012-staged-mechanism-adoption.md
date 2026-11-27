# ADR 0012: staged mechanism adoption and decoupled G0

**Status:** Proposed for review, 2026-11-26. Refines the gate placement in ADRs [0003](0003-publication-and-metadata.md), [0004](0004-arrangement-storage.md), [0009](0009-logical-mvcc.md), [0010](0010-operation-and-hibernation.md) and [0011](0011-risk-reduction-before-implementation.md). It changes **when** a mechanism is built and qualified, never **what** an invariant (`INV-01`–`INV-10`, `CS-01`–`CS-08`) requires.

**Refinement (2026-11-27):** [ADR 0013](0013-minimum-mechanisms-and-independent-qualification.md) replaces the unconditional release ladder, splits G3b into independently qualified capabilities, makes the storage rubric neutral and separates native feasibility from full runtime resource qualification. [ADR 0014](0014-incremental-delivery-and-earned-complexity.md) further makes early group commit conditional on measured need and defines runnable increments inside the existing gates. The mechanism contracts below remain binding when selected.

## Context

ADR 0011 cut G0 to four deliverables, but the surviving scope still has three structural problems:

1. **G1 waits for storage physics it does not use.** G1 is a pure in-memory semantic kernel. Yet G0 closed only when the S3, SlateDB, lease and Quint probes had also passed.
2. **G0 and G2 carry mechanisms that nothing before G4 consumes.** Reader leases, the sweeper-observed GC grace protocol with post-read deadline checks, separate-process reader probes and VM-pause modeling exist to protect *out-of-process* readers. Until serving pools exist (G4), every reader runs inside the process that owns the state and can hold an in-process pin. Arbitrary-cut logical MVCC over `[S_hot, Cp]` is consumed only by independently scheduled consumers and compatible-cut multi-view reads (G3b-I).
3. **Every early mechanism is a protocol to model, qualify and maintain.** A mechanism built before its first consumer adds failure surface and review load without adding evidence.

## Decision

Adopt each mechanism at the first gate whose acceptance needs it. Before that gate, use the simplest baseline that preserves every invariant. A baseline is a deliberate subset, not a weaker guarantee.

### 1. Decouple G0 into two tracks

| Track | Deliverables | Unlocks | Timebox |
| --- | --- | --- | --- |
| **Foundation** | `G0.1` bootstrap, CI and `W1-G` oracle; `G0.4` scoped native semantic/progress/logical-bound feasibility verdict | **G1** | ~2 weeks |
| **Durability physics** | `G0.2` storage and metadata probe; `G0.3` Quint protocol model | **G2** (not G1) | ~2–4 weeks, parallel with G1 |

G1 starts when the Foundation track passes under an independently reviewed scoped verdict; current inconclusive evidence does not automatically pass. Physical allocation/resource qualification remains mandatory before any G2 runtime preview under ADR 0013. G2 starts only when both tracks have passed and ADRs 0003–0005 record the locked choices. A timebox bounds scope, not a delivery date: an overrun triggers a scope review that cuts the lowest-value probe and records the cut as a risk. It never silently extends the gate.

### 2. Mechanism ledger

| Mechanism | Baseline until adopted | Adopted at | Evidence that adopts it |
| --- | --- | --- | --- |
| Reader leases, `Δ_gc_grace` protocol, post-read deadline check, reader groups | Readers run in the owning process and hold in-process pins; tokens, repeatable reads and subscriptions hold durable metadata pins; physical deletion requires a committed tombstone **and** a configured minimum object age | **G4** (first out-of-process readers) | `G4.0` reader-pool probe and Quint extension |
| Logical MVCC at arbitrary cuts `[S_hot, Cp]`, nonlinear intermediate retention | Retained published versions (latest, pinned, and a bounded recent count or age). Promised cuts are published interval boundaries; netting inside an interval is allowed because only boundaries are promised | **G3b-I** | W14 and independent-consumer acceptance; not required by G3b-S/F/P |
| Compositional group commit | One logical operation per root CAS with durable individual outcomes and bounded scheduling | **G2+ only if needed**; bounded G0.2 experiment when the baseline misses its envelope | Measured throughput, freshness or request-cost need; full batch conflict/retry/fairness qualification |
| Preferred-committer hint, multi-writer root contention, scoped metadata partitioning | One owning process per installation; serialized root transitions, optionally qualified batching, with per-operation outcome records | **G4** | G4 contention measurements |
| Single-depth pipelining | One active interval per publication group | **G3b-P** (evidence-triggered) | Measured serialized-I/O freshness cap |
| Multi-domain SlateDB grouping | One SlateDB instance per publication group (plus ingestion PK index if keyed) | When measured idle cost demands | G0.2 and G3b idle-cost measurements |
| Embedded OpenRaft and fast cross-AZ WAL | Object-Native profile only | **G4+** (optional) | Partner requirement plus `G4.0` latency evidence |
| Distributed drain and wake | Single-process stop and restart | **G4** | G4 activation races |
| Monetary cost advisor, adaptive plans | Rule-based placement and `EXPLAIN INCREMENTAL` | **G5** | Measured production telemetry |

Two things are called a lease and must stay distinct. A **staleness bound** (periodic root refresh so a bounded-staleness read can skip a root GET) is a separately qualified cached-read option from G2 when a workload needs it; authoritative latest/RYW/pinned reads are the initial surface. A **GC-protection lease** (an out-of-process reader holds a deadline that the sweeper must outlive) exists only from G4.

### 3. Reduced G0.2 and G0.3, and a new G4.0

- **G0.2** measures what G2 needs, on one real provider: (a) conditional-write conformance and latency (create-if-absent, `If-Match` success and failure, lost-response behavior, read-after-write, current-version discovery without `ListObjects`), sequential freshness round trips, and serialized metadata under same-domain concurrency; compare bounded group commit only if that baseline misses the frozen workload envelope; (b) the immutable-delta + per-group SlateDB-index + bounded-overlay layout against pure SlateDB history on `W1-G` plus a synthetic update stream: write and request amplification, post-CAS and mid-apply `SIGKILL` writable reopen with zero double-apply, metadata checkpoint registration and hard overlay-cap backpressure, cold recovery, idle cost per SlateDB instance, and one in-process historical point lookup at a retained published boundary. Record the provider's storage tier and apply the [predeclared G0.2 rubric](../planning/qualification.md#g0-feasibility-decisions). An AWS S3 Express One Zone tier may be probed as a candidate, but it is never assumed to support required conditional writes until verified. Any single-zone tier is a separately named durability profile, never a silent default.
- **G0.3** is one concise Quint model of publication atomicity with expected-parent CAS and receipt coverage, ownership-generation fencing, idempotent operation outcomes (including a lost CAS response after a later root advance), and GC reachability (pin-versus-retire race, no resurrection, abstract minimum age). Each property has a negative control that must fail.
- **G4.0** (new, runs after G2 and before serving pools) measures separate-process readers at `Cp`, real grace-window deletion under live readers, warm versus strict-latest read latency, and decides whether Embedded OpenRaft or a fast WAL tier is justified. It extends the Quint model with reader leases, VM pauses and clock discontinuities. The lease clock must count suspended time (for example `CLOCK_BOOTTIME`, or a platform equivalent); a detected discontinuity is lease loss.
- Direct-DML primary-key index recovery moves from G0.2 to P2.1 acceptance. It reuses the checkpoint-plus-log-replay pattern that G0.2(b) validates.

### 4. Release ladder

Each gate ends in something a named audience can run, so scope cuts and course changes stay cheap. A preview declares its support envelope and makes no production claim. G6 is the common production qualification contract, instantiated as G6-S or G6-D. Production does not require unrelated advanced mechanisms, but every selected combination requires the full applicable evidence.

| Gate | Audience and artifact |
| --- | --- |
| G1 | Contributors: tested semantic library and independent oracle |
| G2 | Design partners: single-node durable developer preview |
| G3a | First external users: single-node SQL/PG CDC/subscription preview; Kafka qualifies independently when selected |
| G3b-S/F/I/P | Independent sharing, factorization, independent-consumer and pipelining capabilities with scoped evidence |
| G4 | Distributed preview using its actual capability prerequisites |
| G6-S | Single-node Object-Native production after G3a and selected capabilities, without mandatory G4 |
| G6-D | Distributed production after G4 and selected capabilities |

Both production profiles require applicable backup/restore, incarnation fencing, security, resource limits, upgrades/rollback, 72-hour soak, operational evidence and the two-partner business gate. G6-S uses existing durable pins and qualifies eligible single-process suspension/wake; no hidden dependency on G3b-I or G4 is allowed for those baseline operations.

### 5. Pre-1.0 dependency containment

SlateDB, DataFusion, pgwire and consensus crates change quickly. Keep each behind a narrow Rockstream-owned trait (`ArrangementStore`, object-store and metadata-root adapters, SQL binder adapter). Pin exact revisions, run an adapter conformance suite on every upgrade, and keep upgrades separate PRs. A dependency that cannot meet its conformance suite is replaced behind the trait, not worked around in callers.

## Alternatives

- **Keep every mechanism in G0.** Rejected: it preserves the G1 stall and front-loads protocols whose first consumer is gates away.
- **Drop leases, arbitrary-cut MVCC or OpenRaft from the design.** Rejected: serving pools, independent consumers and low-latency strict reads remain product goals. They keep their specifications and move to the gate that proves them.
- **Build two storage layouts through G2 and decide later.** Rejected: one measured layout lock in G0.2 is cheaper than two production paths.

## Consequences

- G1 can begin about as soon as the workspace, oracle and kernel spike pass.
- G2's acceptance shrinks to a single-process contract that is still exact, durable and fenced.
- Lease and arbitrary-cut specifications remain normative but are marked with their adoption gate. Their G0 probes become G3b-I and G4.0 probes. G3b-S/F can establish useful sharing/factorization before those consumers exist.
- All sizing numbers remain hypotheses until measured. This ADR claims no performance result.
