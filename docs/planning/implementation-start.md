# Implementation start: product experience and lean G0 execution

**Status:** Proposed, 2026-11-26. Practical pre-implementation execution brief. The [implementation plan](implementation-plan.md) is the gate/dependency authority; [DESIGN.md](../../DESIGN.md) and [requirements](requirements.md) govern contracts.

## 1. The smallest exceptional Rockstream

Focus on a narrow, rock-solid SQL-first streaming database that maintains exact durable results, operates from one binary with zero external coordination dependencies, and delivers fast warm reads. Build **step by step**:
1. **G0 (2–4 weeks):** Prove existential storage/metadata/overlay physics on real object storage, write one concise Quint protocol model, bootstrap fast CI, and lock `W1-G` + native kernel direction.
2. **G1:** Pure in-memory semantic kernel with independent PostgreSQL/batch oracle verification (`COUNT`/`SUM`/`AVG`, inner equi-joins, checked widened numeric accumulators, `Q(empty)`).
3. **G2:** Single-node durable MVP—one binary, 5-minute local quickstart, standard `pgwire` clients, single-node S3 durability, crash recovery, view-level fault quarantine, and monotonic lease-backed warm reads.
4. **G3a → G3b → G4 → G6:** Table-stakes SQL (`LEFT OUTER JOIN`, `DISTINCT`, semi/anti joins, delete-safe `MIN`/`MAX`) + live PostgreSQL CDC (with benign additive-DDL tolerance) + Kafka + subscriptions (**G3a**); shared arrangements + bounded logical MVCC + rule-based isolation + eligible F-IVM (**G3b**); multi-node cloud + cache-affinity serving + optional Embedded OpenRaft low-latency profile (**G4**); production qualification & v1 migration (**G6**). `G5` advanced features graduate independently.

Engage design partners continuously from G0 onward to prioritize real query shapes and profiles without blocking G0/G1 execution.

### Target user journey (G2 MVP)

Obtain one binary (or container image), start an isolated local database with one documented command, connect with `psql` or standard PostgreSQL drivers, create tables and a maintained view, commit a transaction, wait for publication under the declared consistency policy, and query the exact result. Kill and restart the binary to verify durable state. Moving to cloud mode uses the exact same binary pointed at a qualified object-store bucket—zero external etcd, ZooKeeper, or metadata DB required.

Aim for **five minutes from a clean supported environment with the binary and client available to the first correct maintained view and observed update**.

### Narrow initial platform matrix

| Dimension | Initial qualification scope |
| --- | --- |
| Development | Linux canonical CI/agent environment; macOS supported for local development |
| Server | One Linux target (`x86_64` starting candidate) |
| Local persistence | One specified POSIX filesystem (`fsync`-capable) |
| Cloud persistence | One real S3-compatible provider/region selected and measured in G0.2 |
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
| G0 | Frozen inputs/expected cuts, independent PostgreSQL/batch oracle, S3/SlateDB/overlay physics probe, minimal native kernel |
| G1 | Exact incremental operators (`COUNT`/`SUM`/`AVG`, inner joins), SQL binding, retractions, checked widened decimal/NULL laws, property tests |
| G2 | End-to-end `pgwire`, durable local + single-node S3, bounded delta overlay, lease-backed fast reads, view quarantine, crash recovery, 5-minute quickstart |
| G3a | Table-stakes SQL (`LEFT OUTER JOIN`, `DISTINCT`, semi/anti joins, delete-safe `MIN`/`MAX`), online lifecycle, live PG CDC (additive-DDL tolerant), Kafka, subscriptions |
| G3b | Shared arrangements across overlapping views, independent consumer schedules, rule-based isolation, bounded single-depth pipelining, eligible F-IVM |
| G4 | Multi-node execution, fenced failover, cache-affinity serving pools, optional Embedded OpenRaft low-latency profile |
| G6 | 72-hour soak, DR restore drills, rolling upgrades, audited SLO/cost evidence, v1 migration |

## 3. Lean G0: four kill-switch deliverables (2–4 weeks)

Do **not** build two full engines, 1,000-view benchmarks, full hibernation, or an elaborate cluster simulator in G0. Run four tightly scoped deliverables that establish the workspace and prove the existential physics:

| Deliverable | Scope & concrete output | Exit / fallback trigger |
| --- | --- | --- |
| **G0.1** Bootstrap, CI & `W1-G` Oracle | Minimal Rust workspace (`Cargo.toml`, pinned toolchain), one-command local/CI fast check (<5 min), crate dependency-direction negative control, frozen `W1-G` fixture + independent PostgreSQL/batch oracle, deliberately broken cross-term negative control, and Rockstream v1 donor disposition register | Clean CI pass + proven negative controls; ready for G1 |
| **G0.2** Storage & Metadata Physics Probe | On real S3/object storage: (a) single-key conditional `PUT` (`If-Match`) + **compositional intra-batch serialization** under single-tenant shared-quota and same-domain load (with pre-allocated owner namespaces); (b) **immutable-delta + per-domain SlateDB working index + bounded delta overlay** vs. pure SlateDB history on `W1-G` (separate-reader point lookup at `Cp` and `C ∈ [S_hot, Cp]`, exact-parent reopen after `SIGKILL`, Direct-DML PK index recovery, checkpoint amortization, nonlinear cuts, sweeper-observed grace-window GC deletion); (c) full sequential S3 freshness round trips plus warm lease-backed (`<5 ms` target) vs. strict-latest read latency | Lock **one** storage layout and record honest Object-Native latency/cost envelope; if single-key S3 latency is unacceptable for target workloads, schedule Embedded OpenRaft earlier (and note whether a cross-AZ fast WAL tier is needed for `≤100 ms` P99 freshness) |
| **G0.3** Core Protocol Model (Quint) | One concise **Quint** spec modeling publication atomicity, pre-allocated owner-generation fencing, compositional batch outcomes (including lost CAS response after later root advance), and monotonic-lease + sweeper-observed grace-window (`Δ_gc_grace >> Δ_read_lease`) GC safety (including VM pauses), with deliberate negative controls | Zero invariant violations within bounds; all negative controls caught |
| **G0.4** Native Kernel Spike | Acyclic scalar-epoch weighted Arrow batch kernel executing `W1-G` against the G0.1 independent oracle with explicit memory/queue bounds | Confirm native kernel ergonomics and complexity; **only** prototype Timely/Differential if native hits a concrete predeclared complexity or correctness wall |

## 4. Start with three parallel lanes (WIP ≤ 3)

Start immediately after design approval with three clean, non-overlapping lanes (one issue per lane):

| Lane | First issue | Unblocks |
| --- | --- | --- |
| **Lane A** | **G0.1** — Minimal Rust workspace, fast CI, dependency check, and `W1-G` independent oracle | G0.4, all of G1 |
| **Lane B** | **G0.2** — Real S3 compositional CAS + SlateDB vs. immutable-delta physics probe | Storage layout lock, all of G2 |
| **Lane C** | **G0.3** — Quint protocol model (publication, fencing, compositional batch, grace-window GC) | Metadata/GC contracts in G2 |

Close G0 as soon as **G0.1–G0.4** pass and ADRs 0003–0005 / 0011 record the measured storage/metadata/runtime choices. Then move directly into **G1** (pure semantic kernel) and **G2** (usable single-node durable MVP). Do not launch another speculative design phase.
