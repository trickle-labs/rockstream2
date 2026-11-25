# ADR 0011: Reduce implementation risk through bounded architectural choices

**Status:** Proposed for review, 2026-11-25. This record refines ADRs [0003](0003-publication-and-metadata.md), [0004](0004-arrangement-storage.md), [0005](0005-runtime-selection.md), [0006](0006-sharing-and-optimization.md), [0009](0009-logical-mvcc.md) and [0010](0010-operation-and-hibernation.md). It does not select unmeasured components, close risks or authorize a second engine project.

## Context and critique

The objective is a SQL-first, cloud-native incremental database that shares useful work, maintains exact results and history, scales maintenance and serving independently, and can stop every process for eligible workloads. The [requirements](../planning/requirements.md) make correctness, operational simplicity, bounded resources and full lifetime cost part of that objective. No single layout or scheduler dominates every workload.

The risk-reduction proposals contain useful alternatives, but several already exist in the design. Adopting all alternatives together would enlarge the correctness surface before measuring the original risks. The following decisions distinguish choices we can make now from questions that need G0 evidence.

| Proposal | Critique | Decision before implementation |
| --- | --- | --- |
| Partition metadata by publication domain immediately | Publication boundaries do not close catalog, authorization, quota, writer, retention and restore dependencies. Partitioning also does not remove required remote-read latency. | Retain one root per installation, explicit scopes and a dependency map. Evaluate partitioning for a measured contention problem with a qualified cross-root protocol. |
| Make SlateDB only a disposable index over separate immutable history | Current access and logical history are already separate contracts. External history introduces its own format, write, compaction and GC costs; output history alone may omit necessary operator state. | Compare two bounded history placements under the same authority. Keep required recovery state durable initially; permit reconstruction only from complete protected dependencies within measured budgets. |
| Reconstruct selectively from the old engine | Valuable algorithms and regressions should survive, but old publication/progress assumptions may conflict with the new contracts. Existing code is not a correctness oracle. | Start the native candidate with an explicit donor disposition register. Compare it with established runtime reuse; retain independent semantic authority and a binding selection. |
| Begin with deterministic microbatches | The design already limits the initial kernel to acyclic graphs, scalar domain epochs and one active interval per domain. This still needs complete work accounting and correct intermediate histories. | Keep this scope. Preserve source transactions and nonlinear outputs at every promised cut; defer recursion and pipelined progress. |
| Restrict sharing to matching cadence and retention cohorts | Cadence is a cost input, not a semantic or security boundary. Rigid cohorts would weaken independent consumer schedules and may still hide physical writer contention. | Check semantic/security compatibility first, then compare lifetime cost and reserve capacity before attachment. Admit heterogeneous schedules where economical; provide isolated placement and verified isolation. |
| Centralize reachability and initially disable deletion | A common retirement authority reduces inconsistent destruction paths. Reachability alone cannot prove SQL equivalence, complete recovery or native-backend correctness; retaining everything hides leaks. | Use the existing protection/retirement contract with an independent checker. Allow bounded shadow reclamation during bootstrap, followed by actual reclamation in component and joint G0 evidence. |
| Use a faster object tier or Raft to meet 5 ms reads and 100 ms freshness | Faster metadata does not accelerate every durable input/state dependency. A faster tier may have a weaker failure model. | Measure the full ordered path at sparse and burst load. Preserve the declared fault envelope; qualify any consensus profile separately. The targets remain aspirations. |

## Decisions

### 1. Keep the cloud-native contract stable while comparing implementations

The default remains one binary plus a qualified object store, with no mandatory external coordination service or resident Rockstream quorum. Acknowledged input, authoritative metadata, publications, protected history and required operator recovery state survive loss of every Rockstream process and local cache. Full suspension remains conditional on source, timer, delivery and freshness obligations and a named activation path.

The initial metadata root is per installation, not per view or publication domain. P0.4 records which operations depend jointly on catalog/schema, authorization/revocation, quotas, physical writer ownership, pins, GC, backup and restore. Multiple installations are a deployment choice only for workloads whose obligations are independent; cross-installation atomicity or sharing requires a new qualified protocol. A future partitioning decision must carry this dependency map and the protected import/retention handoff. An explicit logical scope makes that decision reviewable without building sharding now.

Use one authoritative transition contract for admission, ownership, publication, protection and retirement. Backend adapters enforce that contract; the independent checker must not reuse production reachability decisions as its expected answer. This is a responsibility boundary, not a requirement for a new monolithic framework or one literal function.

### 2. Compare history placement separately from attempt isolation

P0.2 compares these placements using the same narrow durable workload, logical cuts and recovery obligations:

| Candidate | Durable arrangement representation | Costs that must be counted |
| --- | --- | --- |
| SlateDB history | SlateDB indexes plus timestamped deltas and consolidated bases, protected through the selected manifests/checkpoints | Index/history writes, WAL and checkpoint work, reconstruction reads, compaction and native GC |
| Separate immutable history | Registered immutable bases/deltas alongside SlateDB indexed state, selected by the same authoritative publication | Both write paths, format/index duplication, object requests, history compaction, protection/GC, cold loading and reconciliation |

Both candidates need one unambiguous published cut and complete protected recovery dependencies. Neither may independently advance a second authoritative timeline. History placement is distinct from whether a preparation uses a protected checkpoint/clone, immutable attempt namespaces or proven safe writer reuse. Narrow these axes with focused probes; integrate the finalists rather than implement their entire cross-product or support multiple production backends by default.

Persist required operator state initially. A future reconstructible index needs a versioned recipe identifying semantics, schema/plan, source state, replay bounds and every protected dependency. Test hidden state, not only visible results: `MIN` over `{1,2}` and `{1,3}` has the same answer until deleting `1`. Rebuilding only the visible answer cannot restore both correctly. Cold recovery and catch-up under ongoing admitted work must meet the frozen budget before an index is classified as disposable.

### 3. Reuse mature mechanisms without inheriting unverified guarantees

P0.1 records each relevant donor component's pinned source, contract, dependencies, regression evidence, license/attribution and disposition: reuse, extract, adapt, replace or reject. Missing evidence remains a gap. This register starts the native prototype; it does not create a third full runtime or mandate wholesale reuse of the old control plane.

P0.3 still compares that native candidate against Timely/Differential and applicable Feldera/DBSP reuse on equivalent semantics, durability, lifecycle, fault injection and resource bounds. Include adapter and maintenance burden in the decision. Scalar epochs simplify progress, but in-flight exchange, asynchronous I/O, spilled work, cancellation and retries still need complete accounting before an interval can finish. Batching must preserve nonlinear transitions at intermediate promised cuts as well as the final answer.

### 4. Make sharing an admitted, reversible economic choice

Full semantic identity, authorization and tenant isolation are mandatory eligibility checks. Freshness, history length, update rate, physical writer coupling, recovery scope and cold cost determine placement after those checks. Evaluate shared and isolated placement before attaching a consumer; reserve retained history and peak build/isolation capacity, not just expected steady-state savings.

Independent schedules remain a core capability. Similar-policy cohorts may be a simple placement rule, but are neither required for correctness nor sufficient evidence of savings. Policy changes cannot revoke existing promises or pins. A slow consumer may remain shared, receive more admitted resources, or move through the existing pinned snapshot/replay/verified cutover protocol. Preserve the 100/1,000-view comparison and the first-order versus eligible factorization experiment; a two-view demonstration cannot qualify workload sharing.

### 5. Reject infeasible latency paths before optimizing their internals

P0.4, with P0.2/P0.7, records the actual dependency order for durable input acceptance, protected preparation, arrangement durability, publication, snapshot selection and read-completion validation. Identify which operations overlap, which amortize and which remain causally ordered. Measure both a sparse singleton transaction and sustained/bursty workloads. Include same-tenant overlapping views with normal quota and retention predicates; report the fraction of operations actually co-batched and reasons for conflict.

A small mandatory-path probe can reject a candidate/profile whose measured authority or durability path already exceeds its budget. Passing that screen establishes no end-to-end SLO. Group commit and reader-group pins can reduce writes per operation while leaving required reads and singleton latency significant. Adding Raft to metadata does not remove remaining object-store durability operations; any replicated data path is a separate decision with its own cost and failure evidence.

An accelerated tier must declare whether it holds authority or reconstructible copies, what survives before acknowledgement/publication, and how recovery behaves when the tier is lost. For example, [AWS describes S3 Express One Zone](https://docs.aws.amazon.com/AmazonS3/latest/userguide/directory-bucket-high-performance.html) as single-digit-millisecond storage within one Availability Zone, without redundancy across zones. It cannot be the sole authority for the existing zone-loss cloud contract. Use it as a reconstructible tier, qualify sufficient durable protection before acknowledgement, or propose a separately named weaker profile; a weaker profile cannot count as an equivalent-guarantee performance win. Measure protection, transfer, idle and recovery costs too.

### 6. Close the existing gates with one reclamation-enabled system path

P0.2/P0.4 may initially compute and compare reclamation candidates without deleting physical objects, under an explicit time/byte cap. SQL deletes and retractions remain enabled. This stage cannot establish bounded storage, native-GC safety or lifetime cost. G0 then requires real reclamation, including retired garbage eventually leaving under declared bounds while every protected cut and recovery dependency remains readable.

P0.9 connects the selected components through the existing W1-G workload with mixed maintenance, protected reads, compaction/reclamation, bounded builds, independent consumers and a slow history-pinning consumer. Exercise abandoned preparations, lost CAS responses after later commits, pin/revocation races, stale activation, complete process/cache loss and exact cold recovery. Validate row equivalence, logical-cut coverage, recovery closure and liveness independently of reachability. The selected system must pass one frozen operating envelope; isolated component wins cannot substitute.

## Execution and consequences

Use the existing six [G0 decisions](../planning/qualification.md#g0-feasibility-decisions), work IDs, budgets and three [initial lanes](../planning/implementation-start.md#4-start-with-three-independent-workstreams). This record sharpens those experiments; it adds no gate or fourth lane. Record owners, candidate revisions, numeric limits, counterexamples, raw measurements, residual gaps and a pass/fail/inconclusive verdict. Timebox remediation and retire rejected prototypes. The qualification document remains the evidence authority.

This approach reduces speculative implementation commitments while preserving ambitious requirements. It deliberately leaves root partitioning, history placement, runtime selection and accelerated storage contingent on evidence. A failed or inconclusive combination requires remediation, another qualified choice or an explicit reviewed scope change; it does not justify weakening exactness or marking an open risk resolved. G0 selects an implementable direction, while later gates still establish public behavior, distributed operation and production readiness.
