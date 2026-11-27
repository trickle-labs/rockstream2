# Implementation start: product experience and lean G0 execution

**Status:** Proposed, updated 2026-11-27. Practical pre-implementation execution brief. The [implementation plan](implementation-plan.md) is the gate/dependency authority; [DESIGN.md](../../DESIGN.md) and [requirements](requirements.md) govern contracts.

## 1. The smallest exceptional Rockstream

Build toward the ultimate cloud-native IVM through a narrow, production-worthy first product: exact durable SQL results, one binary with zero external coordination dependencies, economical object-backed state and fast qualified warm reads. Shared and factorized maintenance, independent serving and distributed scale remain goals; their adoption follows real workload requirements and evidence ([ADR 0013](../adr/0013-minimum-mechanisms-and-independent-qualification.md)). The [implementation plan](implementation-plan.md) is the single roadmap authority; this is a summary. Build **step by step**:
- **G0 foundation:** `G0.1` workspace/CI/oracle and a new independently reviewed `G0.4` native semantic/progress/ownership feasibility verdict unlock G1; historical inconclusive evidence remains unchanged.
- **G0 durability physics:** `G0.2` storage probe and `G0.3` Quint model run in parallel with G1 and unlock G2. The timebox bounds scope, not delivery date.
- **G1:** Pure in-memory semantic kernel with independent PostgreSQL/batch oracle verification.
- **G2 (developer preview):** Single-node durable MVP—one binary, 5-minute local quickstart, standard `pgwire` clients, single-node object-store durability, crash recovery, view-level fault quarantine, and warm in-process reads.
- **G3a (first public single-node preview):** Table-stakes SQL, direct writes, live PostgreSQL CDC and subscriptions. Kafka source/outbox qualify independently when a selected workload requires them.
- **G3b (independent capabilities):** Same-group/cadence sharing (**G3b-S**), eligible factorization (**G3b-F**), independent consumer schedules with arbitrary-cut history and isolation (**G3b-I**), and measured depth-one pipelining (**G3b-P**). No requirement to complete the whole family before production.
- **G6-S (single-node production qualification):** G3a plus only selected capabilities, with real-provider durability, security, backup/restore, upgrades/rollback, physical resource qualification, eligible suspension/wake, 72-hour soak and the two-partner business gate.
- **G4 (distributed preview) → G6-D (distributed production qualification):** Multi-node cloud, cache-affinity serving, reader leases and grace-window GC, optional Embedded OpenRaft, then the same production assurance for that profile. `G5` advanced features graduate independently.

Engage design partners continuously from G0 onward to prioritize real query shapes and profiles without blocking G0/G1 execution. Select capabilities before qualification runs; the smaller single-node product keeps the same invariants and the ≥30% total-cost improvement target on two real partner workloads. It declares owner-loss downtime and cannot borrow an unqualified distributed availability or cached-read claim.

Follow the [incremental build sequence](implementation-plan.md#incremental-build-sequence) within those gates ([ADR 0014](../adr/0014-incremental-delivery-and-earned-complexity.md)): typed semantics and SQL, one internal durable accept/publish/read/recover loop, the complete G2 preview, real PostgreSQL CDC and the complete G3a envelope, then a workload-selected differentiator and G6-S. Internal slices are not preview qualifications. Start metadata with one operation per root CAS and a compact bounded immutable manifest; batching or paging requires its measured trigger and applicable safety evidence. Use the first representative durable path to update the existing partner workload record with actual lifecycle cost and the next bottleneck before adding mechanisms.

### Target user journey (G2 MVP)

Obtain one binary (or container image), start an isolated local database with one documented command, connect with `psql` or standard PostgreSQL drivers, create tables and a maintained view, commit a transaction, wait for publication under the declared consistency policy, and query the exact result. Kill and restart the binary to verify durable state. Moving to cloud mode uses the exact same binary pointed at a qualified object-store bucket—zero external etcd, ZooKeeper, or metadata DB required.

Aim for **five minutes from a clean supported environment with the binary and client available to the first correct maintained view and observed update**.

### Narrow initial platform matrix

| Dimension | Initial qualification scope |
| --- | --- |
| Development | Linux canonical CI/agent environment; macOS supported for local development |
| Server | One Linux target (`x86_64` starting candidate) |
| Local persistence | One specified POSIX filesystem (`fsync`-capable) |
| Cloud persistence | Azure Blob Storage as first real provider; region/tier/redundancy and budgets frozen for G0.2; Silo for local diagnostics ([ADR 0015](../adr/0015-azure-first-object-storage.md)) |
| Client | PostgreSQL wire (`pgwire`), named driver versions, declared SQL subset |
| Packaging | Standalone binary + container image; no mandatory Kubernetes |

## 2. Canonical golden workload W1-G

Use the same small customer/orders join-aggregate throughout G0–G6. Handwritten expected rows and an independent PostgreSQL/batch evaluator check the production path—never derive expected answers from incremental code.

Logical schemas: `customers(customer_id BIGINT key, region binary-collated text)` and `orders(order_id BIGINT key, customer_id BIGINT, amount DECIMAL(18,2))`, all fields non-NULL. Both tables share one transaction domain.

```sql
SELECT c.region, COUNT(*) AS order_count, SUM(o.amount) AS revenue
FROM customers c JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.region;
```

Start empty. Published cut `C` contains complete epochs `e < C`. Each epoch is one atomic transaction; updates/deletes carry normalized preimages. A dash (`—`) means zero result rows (not a NULL aggregate).

| Epoch | Complete transaction | Published cut | Expected `(region, order_count, revenue)` |
| --- | --- | --- | --- |
| None | Empty relations | 0 | — |
| 0 | Insert customers `(1, North)`, `(2, South)`; insert orders `(101, 1, 10.00)`, `(102, 1, 20.00)`, `(103, 2, 7.00)` | 1 | `(North, 2, 30.00)`; `(South, 1, 7.00)` |
| 1 | Move customer 1 to `South`; change order 102 amount to `25.00`; delete order 103; insert order `(104, 2, 4.00)` | 2 | `(South, 3, 39.00)` |
| 2 | Delete order 101; move customer 2 to `North`; change order 104 amount to `6.00` | 3 | `(North, 1, 6.00)`; `(South, 1, 25.00)` |
| 3 | Delete orders 102 and 104 | 4 | — |

Epochs 1 and 2 change both join inputs in one transaction, exercising join cross-terms (`ΔL ⋈ ΔR`) and retractions. Test empty ungrouped `COUNT(*)` (`Q(empty)` = 1 row with `0`) separately.

| Gate | `W1-G` progression |
| --- | --- |
| G0 foundation | Frozen inputs/expected cuts, independent PostgreSQL/batch oracle, native semantics/progress/ownership feasibility and logical bounds |
| G0 durability physics | Conditional-write and storage-layout probe, concise protocol model |
| G1 | Exact incremental operators (`COUNT`/`SUM`/`AVG`, inner joins), SQL binding, retractions, checked widened decimal/NULL laws, property tests |
| G2 | End-to-end `pgwire`, durable local + single-node object store, selected storage layout, latest/RYW/pinned reads, view quarantine, crash recovery, physical runtime resource qualification and 5-minute quickstart; cached bounded-staleness mode only when independently qualified |
| G3a | Table-stakes SQL (`LEFT OUTER JOIN`, `DISTINCT`, semi/anti joins, delete-safe `MIN`/`MAX`), online lifecycle, live PG CDC (additive-DDL tolerant) and subscriptions; Kafka source/outbox selected independently |
| G3b-S / F / I / P | Independently qualified same-group sharing / eligible factorization / independent schedules, history and isolation / measured depth-one pipelining |
| G4 | Multi-node execution, fenced failover, reader leases and grace-window GC, cache-affinity serving pools, optional Embedded OpenRaft profile |
| G6-S / G6-D | Same production assurance for the selected single-node/distributed profile: 72-hour soak, backup/DR, upgrade/rollback, security/resource/activation drills, audited SLO/cost and workload-specific migration |

## 3. Lean G0: four kill-switch deliverables

Do **not** build two full engines, 1,000-view benchmarks, full hibernation, or an elaborate cluster simulator in G0. The foundation track (`G0.1`, `G0.4`) unlocks G1; the durability-physics track (`G0.2`, `G0.3`) runs in parallel and unlocks G2. The 2–4 week timebox bounds the probe scope; an overrun triggers a scope cut and risk record, not a longer forecast.

| Deliverable | Scope & concrete output | Exit / fallback trigger |
| --- | --- | --- |
| **G0.1** Bootstrap, CI & `W1-G` Oracle | Minimal Rust workspace (`Cargo.toml`, pinned toolchain), one-command local/CI fast check (<5 min), crate dependency-direction negative control, frozen `W1-G` fixture + independent PostgreSQL/batch oracle, deliberately broken cross-term negative control, and Rockstream v1 donor disposition register | Clean CI pass + proven negative controls; ready for G1 |
| **G0.2** Storage & Metadata Physics Probe | On real Azure Blob Storage (record region, primary endpoint, storage tier, redundancy and pinned client configuration): conditional-write conformance/latency, one-operation-per-CAS baseline and bounded metadata; a bounded group-commit experiment only if measured baseline throughput/freshness/request cost fails frozen budgets; **immutable-delta + per-group SlateDB index + bounded overlay** vs. pure SlateDB history on `W1-G` (amplification, post-CAS/mid-apply `SIGKILL` writable reopen with zero double-apply, metadata checkpoint registration and overlay-cap backpressure, cold recovery, one in-process historical point lookup); sequential freshness round trips | Apply the [predeclared G0.2 rubric](qualification.md#g0-feasibility-decisions): reject providers failing conditional-write/read-after-write conformance; disqualify layouts failing exact-parent/zero-double-apply recovery or hard trailing-state bounds; among safe candidates meeting frozen SLO/resource/cost limits, lock the simplest **one** layout considering lifetime recovery/operation/verification cost, without favoring hybrid or requiring a simpler candidate to win every metric; record comparable measurements before G2 (single-zone tiers are separately named durability profiles, never the default) |
| **G0.3** Core Protocol Model (Quint) | One concise model of (1) publication atomicity with expected-parent CAS and receipt coverage, (2) ownership-generation fencing and idempotent outcomes, including lost CAS response after root advance, and (3) GC pin/retire no-resurrection with abstract minimum object age; one negative control per property | Zero invariant violations within bounds; all negative controls caught |
| **G0.4** Native Kernel Feasibility | Acyclic scalar-epoch weighted Arrow batch kernel executing `W1-G` against the G0.1 independent oracle; logical row/byte/queue/work bounds, retained-output ownership and exhaustion behavior | Independently review native semantics/progress/state ownership under the [revised G0.4 criteria](qualification.md#g0-feasibility-decisions). Only a demonstrated native semantic/ownership/logical-bound wall triggers one Timely/Differential comparison. Record physical allocation/dependency/headroom gaps separately for P2.5 before any G2 runtime profile; missing evidence stays inconclusive and a dependency OOM alone is not a scheduler-selection result |

Do not extend the throwaway native spike into a production allocator or runtime framework. Preserve the existing inconclusive report and counterexamples; a new reviewed feasibility pass unlocks pure G1 work, while unresolved physical-resource behavior blocks publication of the affected G2 runtime profile. Reader-lease, grace-window GC under live readers, separate-process reader, cross-AZ WAL and OpenRaft probes move to the `G4.0` entry probe. Direct-DML primary-key-index recovery is accepted in P2.1.

## 4. Start with three parallel lanes (WIP ≤ 3)

Start immediately after design approval with three clean, non-overlapping lanes (one issue per lane):

| Lane | First issue | Unblocks |
| --- | --- | --- |
| **Lane A** | **G0.1 → G0.4** — Minimal workspace, CI and independent oracle, then native spike | G1 after both deliverables pass |
| **Lane B** | **G0.2** — Conditional-write and storage-layout probe | G2 together with G0.3 |
| **Lane C** | **G0.3** — Concise Quint model | G2 together with G0.2 |

G1 starts when the foundation lane passes under the revised, independently reviewed criteria. G2 starts when the durability-physics lane passes and ADRs 0003–0005 / 0011 / 0013 / 0014 record the measured storage/metadata/runtime choices; P2.5 must close the selected profile’s physical resource gaps before a G2 preview is published. Keep design-partner engagement parallel; do not make G1 wait for storage physics or launch another speculative design phase. Existing inconclusive verdicts and local probe evidence retain their recorded limits; this sequence promotes no gate.
