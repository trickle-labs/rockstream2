# ADR 0014: incremental delivery and earned complexity

**Status:** Proposed for review, 2026-11-27, under [issue #34](https://github.com/trickle-labs/rockstream2/issues/34). Extends [ADR 0013](0013-minimum-mechanisms-and-independent-qualification.md). Supersedes mandatory early group commit in [ADR 0003](0003-publication-and-metadata.md) and the corresponding G0.2/G2 staging in [ADR 0012](0012-staged-mechanism-adoption.md). No gate, implementation, storage winner or supported capability is promoted by this record.

## Context

Rockstream 2 should become the ultimate cloud-native IVM: exact SQL, shared and factorized maintenance, economical object-backed state, disposable compute, independent serving and elastic scale. ADR 0013 removes unnecessary dependencies between those goals. The remaining risk is building a large collection of individually plausible mechanisms before a small complete engine demonstrates useful behavior and cloud economics.

The next unit of progress must be something that runs and answers an uncertainty. Specifications of future capabilities remain valuable, but do not make their machinery prerequisites for that increment.

## Decision

### 1. Build one engine through runnable increments

The [incremental build sequence](../planning/implementation-plan.md#incremental-build-sequence) is part of the existing roadmap, not a second set of gates. Extend one executable path from a general typed W1-G plan and independent SQL oracles to durable acceptance, publication, pinned reads and recovery; then complete the public preview and real PostgreSQL application path. W1-G is a test workload, not a hardcoded production query.

The first internal durability increment has one ingestion domain, one publication group, one active interval, one owning/serving process, one qualified cloud provider and the single storage layout selected by G0.2. It must reconcile lost acknowledgements, reject stale authority and recover exact results after process death and loss of all local state. Keep its declared state/input/output and metadata bounds explicit. Do not introduce distributed execution, independent consumer schedules, arbitrary-cut history, speculative intervals or a generalized optimizer for this increment.

An internal increment is not a supported preview or a completed gate. It cannot excuse a correctness failure on its implemented path. Complete G2 still requires its full SQL/API, accepted-head keyed DML, default per-view publication groups, sibling quarantine/retention isolation, security, pin/GC protection, resource qualification and restart evidence. A single-group test is not evidence for multi-group isolation. Process-local read pins still require confirmed predecessor termination/drain before replacement serving or GC. Keep all existing G3a and selected G6 obligations.

Use the existing issue's scope and acceptance fields to state what runs, which uncertainty it resolves, what remains deferred, and what observation would stop or narrow the next step. Do not add another registry, orchestration service or approval layer. Add modules/crates and interfaces when an actual consumer needs them; preserve semantic identity, cuts and the authority boundary without scaffolding future systems.

### 2. Start metadata with one operation per CAS

The initial Object-Native metadata implementation serializes **one logical operation per conditional root update**. One operation may atomically change several records: durable admission, publication, quarantine and pin transitions retain every jointly checked predicate. This is not one CAS per record and not a new cross-domain transaction API.

Start with a bounded compact immutable metadata manifest selected by the root. Do not require a paged metadata tree, general transaction framework or batch-composition scheduler before the measured workload needs one. Preserve durable individual outcomes and retry floors, ownership/run fences, quotas, protected roots and all accepted-input obligations. Bound queue count/bytes, preparation and retry work, and wait time; reserve capacity for control, recovery and completion of already accepted work. Exhaustion backpressures or rejects new work explicitly, never drops outcomes or protected references.

Measure the complete serialized path first, including metadata bytes/writes, root reads/CAS attempts, input and publication round trips, pin traffic, tail latency and idle/recovery cost. Independent publication groups share this authority serialization point but do not wait for each other's computation.

Adopt **compositional group commit** only when this baseline cannot meet the selected workload's predeclared throughput, freshness or request-cost envelope and a bounded comparison demonstrates a useful improvement. Use the same logical transition implementation with batch size one as the reference behavior; do not maintain two authority protocols. When enabled, all batch-member validation, durable individual outcomes, conflict/regrouped-retry, queue/fairness, maximum-delay and control-reserve requirements in [consistency and storage §4.2.1](../design/consistency-and-storage.md#421-bounded-metadata-commit-scheduler) are mandatory. A profile that needs batching cannot qualify until that evidence exists.

Introduce immutable metadata pages only for a measured size, write-amplification or recovery limit, preserving the same root atomicity and protected dependency closure. Metadata partitioning, preferred committers, OpenRaft and fast WAL retain their later adoption gates. A slow baseline is a finding to resolve, not automatic permission to add every optimization.

### 3. Test cloud economics before expanding mechanisms

G0.2 still requires a named real provider, scoped disposable resources and frozen numeric budgets. Compare the hybrid and pure SlateDB-history candidates on equivalent work, guarantees and complete costs. Measure serialized metadata first; a bounded batching experiment is required only if needed to meet that envelope. Existing batching experiments remain evidence within their recorded limits. Local emulator or non-equivalent counters cannot select a layout or qualify a cloud profile. Lock one production storage path before G2; do not introduce a third storage engine as insurance.

Use the earliest durable end-to-end increment to test a representative shape from the existing [partner workload decision record](../planning/requirements.md#1-users-and-workloads). Record exact output, freshness, recovery, memory, metadata/object requests, retained state, idle and catch-up cost. Compare the available first-order, batch-recompute and original-Rockstream baselines only where their semantics and service envelopes match; report gaps instead of treating an unavailable comparison as a win. Short runs and synthetic fixtures guide the next decision, not a production cost claim. Preserve G6's two-real-partner workload gate, total-cost target and protected workload limits.

If the baseline cannot meet the frozen envelope, investigate the measured bottleneck and choose a bounded improvement, explicitly revise the workload/profile, or stop that experiment. Missing access, inconclusive data or a failed safety case remains visible. Scope changes require a new declared comparison; do not relax correctness, freshness or durability inside the old result.

### 4. Prove the differentiators one at a time

After the applicable baseline gates, choose the smallest mechanism that improves a selected workload: same-cadence sharing in one explicit publication group or one finite eligible factorization rule. Prove exact independent-oracle parity and lower complete lifetime cost, including build, retention, recovery and failure behavior. Retain the first-order reference and explicit rejection/fallback for ineligible shapes; no generalized optimizer is needed to prove the first gain.

Independent schedules/history, online isolation, pipelining, serving pools, distribution and advanced SQL remain real goals with the dependencies in ADR 0013. Add them for a named workload requirement or demonstrated limit and qualify the combinations actually offered. Preserve one production runtime and layout; retain reference oracles, but retire failed prototypes and unused production paths. A workload that outgrows the single-node availability or capacity envelope waits for its qualified distributed profile.

## Consequences and alternatives

- Fewer mechanisms are required before the first complete engine. Serialized metadata may cost more requests and limit throughput; the first real-provider measurements make that tradeoff explicit rather than assuming batching is necessary or unnecessary.
- Compact metadata has a finite supported size. Limits and control/recovery reserves are required from the start; a larger workload earns a representation change before it is advertised.
- Useful shared/factorized IVM and cloud scale remain the destination. Incremental delivery preserves the option to change internal representations before making compatibility promises; experimental formats are versioned and isolated under the existing compatibility policy.
- Building the whole target architecture before a useful durable path is rejected. Replacing the ambition with an append-only toy, weakening safety tests, or declaring an internal demonstration production-ready is also rejected.

## Verification and immediate next work

Reconcile the owning metadata specification, roadmap, requirements and qualification with these decisions. Review unchanged `INV-01`–`INV-10` and `CS-01`–`CS-08`, conditional batching cases, retained G2/G6 requirements and links. This documentation review is not engine, model, provider or performance evidence.

Finish the already scoped G0 foundation and durability-physics work, including the independent native-feasibility verdict and comparable real-provider storage experiment. Preserve existing inconclusive records and the physical runtime resource blocker before G2 preview qualification. Proceed to the next runnable increment when its actual prerequisites pass; do not open another speculative architecture phase.
