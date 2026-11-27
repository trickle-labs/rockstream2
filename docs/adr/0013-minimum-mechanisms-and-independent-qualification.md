# ADR 0013: minimum mechanisms and independent capability qualification

**Status:** Proposed for review, 2026-11-27. Updates the working design under [issue #32](https://github.com/trickle-labs/rockstream2/issues/32). Supersedes the unconditional release sequence and bundled G3b acceptance in [ADR 0012](0012-staged-mechanism-adoption.md), the asymmetric storage-selection preference in [ADR 0004](0004-arrangement-storage.md), and the scope of the G0.4 resource decision in [ADR 0005](0005-runtime-selection.md). Other decisions remain in force except where explicitly refined below. No implementation, gate verdict or supported capability is promoted by this record.

**Further refinement:** [ADR 0014](0014-incremental-delivery-and-earned-complexity.md) makes the delivery path executable in small increments, starts metadata with a compact manifest and one operation per CAS, and makes batching/paging conditional on measured need. It retains this record's independent capability/profile gates and unchanged safety obligations.

## Context

Rockstream 2 aims to be a comprehensive cloud-native IVM database: exact SQL, workload-wide shared and factorized computation, disposable compute over durable cloud state, independent maintenance and serving, and economical operation from one binary. ADR 0012 already delays mechanisms until their first consumer, but three dependencies still put unnecessary work on the critical path:

1. Production qualification waits for distributed G4 even for a workload that fits one owning process.
2. G3b couples useful sharing and eligible factorization to independent scheduling, arbitrary-cut history, online isolation and pipelining.
3. G0 favors one storage implementation before comparable measurements and risks turning a bounded native-kernel experiment into production allocation infrastructure.

The product ambition is unchanged. Reduce the number of mechanisms needed to prove a useful product, and retain the evidence required for every guarantee it advertises.

## Decision

### 1. Preserve the product contract; make mechanisms justify their cost

Keep `INV-01`–`INV-10` and `CS-01`–`CS-08` unchanged: exact results at declared cuts, complete durable publication, transaction atomicity, fencing, one logical retry effect, protected reads, bounded resources, security-compatible sharing, protected recovery history and restore incarnation safety. Keep cloud object authority, one binary without an external coordinator, independent oracles and real-backend failure evidence.

Before adding an abstraction, protocol, dependency, knob or alternate execution path, its ordinary issue/ADR must identify the current workload or correctness obligation, the simplest complete alternative, why that alternative is insufficient, and the lifetime implementation, verification, recovery and operating cost. A hypothesis can justify a bounded experiment; adopting a mechanism requires the declared evidence. Use existing issues, ADRs and qualification records; do not build a new governance framework.

Future capabilities remain explicit goals with adoption gates. Their contracts become binding when selected; their implementation is not an implicit prerequisite for an unrelated capability. Preserve semantic identity, logical cuts, authoritative publication and dependency adapters as narrow boundaries. Do not prebuild plugin systems, empty crates or generalized distributed abstractions to reserve future options.

### 2. Qualify production by deployment profile

`G6` is the common production qualification contract, instantiated for a named topology, provider/tier, capability set, resource envelope and SLOs. It is no longer an unconditional successor of G4.

| Qualification | Prerequisites | Supported topology |
| --- | --- | --- |
| **G6-S** | G0/G1/G2/G3a plus only the independently qualified capabilities selected for the release | Single-node Object-Native: one active owning/serving process, one binary plus a qualified object store |
| **G6-D** | G4 and the capabilities selected for the distributed release | Multiple instances of the same binary; each claimed distributed, serving, import or consensus behavior qualified explicitly |

Neither profile must implement every G3b or G5 capability. Selecting multiple capabilities requires combined-path evidence, not a union of unrelated component results. A local-only or different durability profile requires its own named evidence; G6-S does not silently certify it.

Every production profile still requires the applicable exact-candidate security, quota/resource, backup/empty-environment restore, new-incarnation fencing, upgrade/rollback, incident/runbook and 72-hour mixed-load soak evidence. Cloud recovery must succeed after all local state is lost. Preserve the two real design-partner workload business gate and the predeclared cost target at equivalent semantics, durability, freshness and retention. Workloads must fit the declared profile; a single-node result cannot establish a horizontal scale or distributed-availability claim.

Single-node backups use the durable metadata pins and protected roots already required in G2/G3a. Single-node production qualifies eligible suspension/wake, source continuity, admitted-work recovery and competing/stale activators without requiring distributed pool drain. Full zero-process hibernation is advertised only for eligible measured workloads with an external activation contract; continuous CDC obligations do not disappear. Object durability does not imply continuous compute availability. Process-local read pins require exclusive owning/serving process lifetime: confirm predecessor drain/termination before a replacement serves or reclaims state; a generation CAS alone does not protect old reads. Uncertain termination blocks replacement serving/GC. Competing cold activators elect one owner before admitting readers. Overlapping failover needs separately qualified durable read protection; it is not a baseline G6-S availability promise.

### 3. Separate four advanced IVM capabilities

G3b remains the roadmap family for shared and optimized IVM, with independently qualified components. The labels identify acceptance scopes, not new runtime frameworks.

| Capability | Minimum complete mechanism | Evidence and boundary |
| --- | --- | --- |
| **G3b-S: same-cadence sharing** | Canonical descriptor matching and bounded shared-state ownership within one explicitly selected publication group and cadence | W2 sharing versus isolated execution at the same guarantees, including build, retention, recovery and idle cost. Coupled views share the group's atomicity/quarantine boundary; no independent schedule or isolation claim |
| **G3b-F: eligible factorization** | A bounded family of explicitly selected, algebraically valid partial-aggregation/factorization rules over the first-order baseline | Exact independent oracle/restart parity, enforced keys or multiplicity proofs, NULL/empty/retraction/numeric cases, skew/resource bounds and measured lifetime benefit. Does not require G3b-S, G3b-I or a global cost planner |
| **G3b-I: independent consumers** | Independent schedules and cursors, arbitrary-cut logical MVCC, retention-aware admission and safe online isolation | W14 and heterogeneous W2; nonlinear intermediate history, disjoint checkpoint schedules, live-head/cursor cutover, old-history protection and bounded peak coexistence |
| **G3b-P: depth-one pipelining** | One speculative successor interval with exact expected-parent chaining | Adopt only after a measured serialized-I/O freshness bottleneck; reserve peak resources, discard on predecessor abort/quarantine, drain before ownership or plan changes |

One active interval remains the default. Published interval-boundary history remains sufficient for G2/G3a and G3b-S/F/P when those capabilities promise only such cuts. G3b-I earns finer history through a concrete consumer; its full contract remains unchanged. Same-cadence sharing never merges existing independent groups implicitly. Broader higher-order derivatives, adaptive planning, general recursion and advanced SQL remain independently gated G5 goals.

G4 depends on the capabilities its selected distributed workload actually uses. Sharing across independent result groups and compatible-cut imports/joins across those groups cannot bypass G3b-I, but partitioning a single publication group does not require unrelated online isolation.

### 4. Select one storage layout using a neutral rubric

The immutable-delta + SlateDB working-index + bounded-overlay design remains a candidate, with its detailed recovery and checkpoint obligations. Pure SlateDB history is a competing candidate. G0.2 uses the same normalized workload, exact results, retained cuts, failure model, provider and resource/SLO/cost limits for both.

1. Reject providers or candidates that fail conditional-write/read-after-write conformance, durable retry outcomes, exact-parent and zero-double-apply recovery, protected history or hard resource bounds.
2. Freeze numeric freshness, recovery, amplification, memory and total-cost limits before confirmatory runs. Count metadata, indexes, checkpoints, replay, validation and requests consistently; disclose omissions and non-equivalent experiments.
3. Among passing candidates, choose the simplest complete implementation after assessing measured runtime cost and lifetime code, protocol, dependency, verification, recovery and operating cost. A simpler candidate need not win every microbenchmark; the hybrid has no default entitlement to win. Record tradeoffs and selection evidence.
4. Lock **one** production layout before G2 and update its owning spec and ADR. If none passes, record fail/inconclusive and narrow or re-decide the profile before proceeding. Do not maintain two production paths as insurance.

The current detailed hybrid specification is the candidate contract, not evidence that it won. This ADR selects no replacement, changes no durable format and does not use preliminary non-equivalent local probe counters as a layout decision. A compact metadata representation may be used where it meets measured limits, but cannot omit durable outcomes, atomic predicates, pins or recovery roots. Metadata partitioning and multi-domain physical grouping still require measured need.

### 5. Keep G0.4 a bounded feasibility decision

Separate two verdicts that answer different questions:

| Scope | Required evidence | Decision point |
| --- | --- | --- |
| **Native feasibility** | Exact W1-G and empty-input results against independent oracles; scalar progress and single-owner state without ad hoc synchronization; explicit logical batch/state/queue/output bounds with exhaustion behavior, ownership and retained-buffer tests | G0.4 foundation decision, with independent review, unlocks bounded G1 semantic work after G0.1 passes |
| **Runtime resource qualification** | Complete physical allocation attribution, shared/temporary/dependency bytes and process headroom, cancellation/control reserves, fault behavior and recovery for the actual supported runtime envelope | Owned by G1 runtime work and P2.2/P2.5; mandatory before any G2 runtime preview qualifies, and repeated on each G6 production candidate |

The [existing native-spike record](../planning/g0-native-spike.md) remains inconclusive. Its infallible allocation paths and injected abort observations remain open evidence, not a passing hard-memory or controlled-error contract. A new scoped, independently reviewed verdict is required under this revised rule; changing the rule alone does not unlock G1. No bounded logical counter is represented as a whole-process physical limit.

Expected admission exhaustion must have an explicit outcome. Any remaining dependency allocation failure policy must be documented and qualified for the actual process boundary; safe termination/recovery cannot be called a controlled per-query error. A native semantic, state-ownership or enforceable logical-bound failure still triggers the bounded alternate-runtime experiment. Missing physical measurements or an Arrow allocation issue alone do not demonstrate that Timely solves the problem. Keep one runtime and delete failed prototypes; do not expand G0 into a general allocator or scheduler framework.

### 6. Keep the first public surface focused

The initial path is pgwire, bounded direct writes, exact SQL read models and PostgreSQL CDC, with the G3a SQL/lifecycle/subscription contract. Kafka source/sink support remains planned and qualifies independently when a selected workload needs it; it is not a compulsory prerequisite for a PostgreSQL-based release.

Initial reads cover authoritative `latest-committed`, WriteToken/read-your-writes waits and durable pinned repeatable reads at retained published boundaries. Cached bounded-staleness is a separately qualified option where a named workload needs its warm-read SLO; it must expose its freshness and authorization bounds, recheck their deadlines at completion with a suspend-aware clock, and retain the correct pin/protection behavior. Never report cached latency as strict-latest latency. Arbitrary historical cuts require G3b-I, and out-of-process leases/immediate-revocation behavior remains G4 work. Unsupported modes, combinations and SQL fail explicitly rather than acquire weaker semantics silently.

## Consequences and alternatives

- A useful single-node cloud product can reach production without paying for distribution, while advanced capabilities retain an explicit path to production. The initial profile is a starting point, not a permanent SQL, state-size or topology ceiling.
- Sharing and factorization can demonstrate the product's differentiating economics earlier. Their measured benefit, resource envelope and composition remain mandatory.
- The storage choice may still be the hybrid. Simplicity is assessed against complete correctness and workload obligations, not a line-count quota.
- Splitting qualification creates more named scopes, so the existing capability registry must record exact combinations and evidence. It does not justify additional services or orchestration.
- Requiring all advanced mechanisms before any production release is rejected because unrelated mechanisms add failure surface and delay learning. Removing the advanced goals is also rejected because independent schedules, shared/factorized IVM, elastic serving and cloud economics are central to the product.
- Weakening recovery, resource or oracle evidence to accelerate release is rejected. Qualify a smaller complete support envelope instead.

## Execution and evidence

The [implementation plan](../planning/implementation-plan.md) remains the only roadmap authority. Finish the existing G0 work under the revised scopes, record the independent G0.4 verdict and resource blocker, perform the comparable real-provider G0.2 experiment, and proceed into G1/G2 only when their actual prerequisites pass. Do not open another speculative architecture phase.

Review this documentation change by checking profile dependencies, capability boundaries, unchanged invariants and relative links. Model, engine, provider, performance and release evidence remain separate; this record changes their required scope and ordering, not their observed results.
