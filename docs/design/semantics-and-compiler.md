# Semantics, incremental algebra, and compilation

**Status:** proposed design; no Rockstream 2 engine or SQL capability is implemented by this documentation PR. **Date:** 2026-11-26. Read [DESIGN.md](../../DESIGN.md) first and [SQL and API contracts](../reference/sql-and-apis.md) for the proposed public surface. The G0–G6 labels refer to the [implementation gates](../planning/implementation-plan.md), not release promises. G5 is an advanced capability track: each feature must qualify independently and need not block G6 production qualification of a smaller surface.

## Capability adoption

[ADR 0013](../adr/0013-minimum-mechanisms-and-independent-qualification.md) preserves workload-wide IVM as the product goal while splitting its mechanisms: `G3b-S` qualifies canonical sharing inside one publication group with one cadence; `G3b-F` qualifies bounded eligible factorization; `G3b-I` qualifies independent schedules, arbitrary-cut history and online isolation; `G3b-P` qualifies evidence-triggered pipelining. A release selects only the capabilities needed for its declared workloads and qualifies their combination. The first-order baseline and exact semantic obligations remain mandatory.

## 1. The semantic contract

Rockstream 2 is a SQL-first streaming database. Its internal unit of optimization is the whole admitted workload: compatible views can reuse subexpressions, arrangements and maintenance work while retaining their own freshness, retention and publication contracts. This internal computation model does not expand the initial public product into arbitrary user-defined distributed programs.

The semantic model is a sequence of finite weighted relations. For a relation with row type `T`, `ZSet<T>` is a finite-support function `T → Z`. Addition sums multiplicities; negation retracts them. SQL input and output snapshots are bags with nonnegative multiplicities. Signed intermediate deltas are legal; a negative committed table multiplicity is an error, not a negative number of database rows.

Within a consistency domain, `Epoch` is a totally ordered logical number. If `ΔR_e` is the complete input change at epoch `e`, then:

```text
R_e       = R_(e-1) + ΔR_e
O_e       = Q(R_e)
ΔO_e      = Q(R_e) - Q(R_(e-1))
O_e       = O_initial + Σ_(i ≤ e) ΔO_i
O_initial = Q(R_initial)
```

For a newly empty database, `R_initial` is empty. `Q(empty)` is not always empty: an ungrouped `COUNT(*)` produces one row containing zero. Initialization is part of the circuit and must be published exactly once. Backfill instead establishes `Q` at a pinned nonempty input cut `C`, followed by changes with epochs `e >= C`.

The required invariant is equality of complete typed bags between incremental evaluation and batch evaluation at every published cut. Ordered output additionally obeys its ordering contract. For an opted-in approximate numeric capability, equality is replaced by that capability's stated error and reproducibility contract; this never weakens exact capabilities.

DBSP provides a compositional framework for expressing integration, differentiation, and incremental transformations. Rockstream adopts that mathematical foundation; this is separate from choosing Feldera's DBSP runtime as an implementation dependency. The preferred native executor, any reused runtime components, the reference interpreter, lowering rules, and persistence protocol all require their own evidence. The paper is neither proof of this compiler nor a general performance guarantee. [S1]

A logical cut `C` includes exactly epochs `e < C`; the equations above use an after-epoch snapshot, so `R_e` corresponds to cut `e + 1`. A published exclusive upper `Cp = 28` includes epoch 27. The computed upper `Cc` certifies completed evaluation; the published upper `Cp <= Cc` additionally certifies protected durable state and an authoritative publication. An operator's computation frontier is not a durability acknowledgement. Domain-local epochs from different domains cannot be compared. A `SourceCut` describes the complete native source positions and imported relation versions represented by a snapshot; it is not a global clock.

An input transaction supplies an atomic set of changes. Intermediate retractions, transient negative counts, and intermediate join results are invisible until the whole epoch has been evaluated and published. Direct-write validation rejects invalid transactions before durable acceptance. By default from G2 onward, each independent materialized view owns its own lightweight result publication head consuming the ingestion domain, while views requiring joint atomic visibility are placed into an explicit named **atomic publication group** (`WITH (publication_group = '...')`). If a valid, durably accepted input later causes a derived view to hit a runtime arithmetic or resource error (such as `DECIMAL` overflow or division by zero), the engine commits a durable **`Active → Quarantined`** transition for that failing view (or its coupled atomic `publication_group`) at its last valid published cut with an explicit `ERROR` diagnostic—preventing crash-restart loops—while unaffected views continue advancing. While quarantined, `WAIT FOR PUBLICATION` and `read-your-writes` covering `>= failed_epoch` fail fast with `RS_VIEW_QUARANTINED`. A quarantined view's retention pin remains subject to its configured retention budget (`IncrementalRetained → BackfillRequired` on quota expiry) so it cannot indefinitely block compaction for healthy siblings; repair alters or replaces the failing view and replays incrementally while retained history exists, or backfills cleanly from a base snapshot plus tail once history expires (explicit recreate/rebuild in G2; online backfill in G3a `P3.2a`)—never silently skipping accepted input.

### Logical MVCC and bounded batching

**Stage:** Profiles without `G3b-I` retain latest, pinned and a bounded recent set of published versions and promise published interval-boundary cuts. Full arbitrary-cut coverage `[S_hot, Cp]` is introduced at `G3b-I` ([ADR 0013](../adr/0013-minimum-mechanisms-and-independent-qualification.md)).

Maintained relations and shared arrangements expose retained logical cuts independently of physical checkpoints. Let `S` be the inclusive earliest supported cut and `S_hot` the earliest fine-grained cut (`S <= S_hot <= Cp`):
- In the **hot fine-grained window `[S_hot, Cp]` at G3b-I**, exact immutable delta segments support every logical cut `C` (including intermediate nonlinear results for `DISTINCT`, `MIN`/`MAX`, and outer joins):

```text
R@C = R@S_hot + Σ_(S_hot <= e < C) ΔR_e, for S_hot <= C <= Cp
```

- In **longer retention `[S, S_hot)`**, periodic consolidated checkpoint bases (or explicitly budgeted archived deltas) bound state growth so hot keys do not accumulate unbounded uncoalesced per-epoch versions inside an LSM tree.

Empty changes still carry progress and lineage. A published descriptor declares exact coverage; descriptors without `G3b-I` declare supported interval-boundary cuts, while `G3b-I` may advertise arbitrary cuts in its qualified hot window. Missing or expired cuts always return explicit errors rather than falling back to newer data. Consolidating across epochs is legal only below `S_hot` when no active pin or promised intermediate cut requires them.

## 2. SQL meaning belongs to Rockstream

DataFusion and Arrow are valuable parsing (`sqlparser`), binding, and compatible expression components, but they do not define the product's SQL contract. DataFusion exposes configurable dialect and null ordering, can ignore `VARCHAR(n)` length constraints, caps standard `Decimal128` at precision 38 (insufficient for widened checked Z-set accumulators over `DECIMAL(38, s)` or large transient batches), and evaluates vectorized arrays where masked `CASE`/`AND` branches require explicit division-by-zero/overflow guards. Consequently, Rockstream owns its semantic binder adapter, checked widened integer/decimal accumulator kernels, and guarded scalar error semantics rather than assuming DataFusion matches PostgreSQL. [S2]

Each catalog object records a `SemanticVersion` and semantic fingerprint. Binding resolves names to stable `RelationId` and `FieldId` values; renaming a column does not change its identity. Expression nodes carry result type, nullability, collation, overflow mode, volatility, and error behavior. Kernel upgrades must preserve these properties or introduce a new semantic version and an explicit migration.

| Area | Required contract and implementation consequence |
| --- | --- |
| NULL | Predicates use SQL three-valued logic; `WHERE` retains only TRUE. Ordinary equality joins do not match NULL keys. Grouping and `DISTINCT` use their separate SQL equivalence relation, in which NULL values group together. |
| Duplicates | Projection combines identical result rows by adding weights. Join multiplicities multiply. `UNION ALL` adds bags; `UNION` includes thresholding. No implicit deduplication of user data. |
| Aggregates | `COUNT(*)` counts all rows; `COUNT(x)` counts non-NULL values. `SUM`/`AVG` maintain a non-NULL count as well as numeric state. Group disappearance and an empty ungrouped aggregate are distinct cases. |
| Exact numbers | G2 supports signed integer types and declared decimal precision up to 38. Every arithmetic operation has checked range and specified scale/rounding rules. Aggregation uses wider checked intermediates or a bounded exact representation; no wraparound or hidden conversion to float. Higher precision is rejected until separately qualified. |
| Float | Scalar and aggregate behavior must specify NaN, infinities, signed zero, comparison, and serialization. FLOAT aggregation is a separate opt-in experimental capability until its reproducibility/error model qualifies. Float reassociation is not an exact algebraic rewrite. |
| Text | The initial comparison/equality contract is versioned binary UTF-8 collation. Locale-sensitive collation requires a pinned implementation/version and separate qualification; it cannot share binary-collated arrangements. |
| Time | `TIMESTAMPTZ` stores an instant at declared precision. Timezone-dependent operations bind a timezone and timezone-database version. Event time, processing time, and logical epoch are distinct fields. |
| Ordering | A relation is unordered unless an ordered operator or final query requests order. NULL placement is explicit in physical keys. Persisted Top-K has a deterministic tie policy recorded in its plan. |
| Errors | Division by zero, invalid cast, overflow, unsupported expression, and invalid multiplicity are typed errors. The optimizer cannot rewrite away an observable error unless equivalence under the documented evaluation rules is established. |
| Volatility | Maintained expressions must be deterministic from their explicit inputs. Randomness, external network calls, wall-clock reads, and session-dependent functions are rejected unless converted into durable input data. |

PostgreSQL documents the empty-input and NULL behavior that the chosen aggregate subset should match; type-return differences must be listed as deliberate compatibility exceptions and tested. [S3] The oracle runs against a pinned supported PostgreSQL image with fixed timezone, collation, settings, and explicit casts. It does not assume every DataFusion output type equals PostgreSQL's. A small independent bag interpreter is also necessary: comparing two paths that use the same buggy expression kernel is not independent validation.

## 3. Primitive rules and difficult operators

### Linear operators and joins

Deterministic map, filter, projection, and flat-map distribute over weighted addition. A flat-map must emit exactly the same values when retracting a row as when inserting it. Its fanout is subject to a resource budget.

For a bilinear inner join, with `L0` and `R0` the pre-epoch snapshots:

```text
L1 = L0 + ΔL; R1 = R0 + ΔR
Δ(L ⋈ R) = (ΔL ⋈ R0) + (L0 ⋈ ΔR) + (ΔL ⋈ ΔR)
          = (ΔL ⋈ R0) + (L1 ⋈ ΔR)
```

The runtime chooses one decomposition and records whether each arrangement access uses pre-change or post-change state. It must not combine the three-term formula with a post-change `R1` in the first term. For one matching key, `L0 = 2`, `R0 = 3`, `ΔL = +1`, and `ΔR = -1`: the delta is `3 - 2 - 1 = 0`, and both old and new join multiplicities are six. This belongs in every implementation's exact regression suite.

The existing Rockstream differentiation pass already lowers relational nodes into physical operators. The new design makes the state-version obligations explicit in IR and verification rather than relying on a scheduling convention. The existing IVM document's first join formula uses `R1` alongside a separate cross term; this proposal deliberately uses unambiguous pre/post notation. That observation concerns documentation, not a claim that existing execution is incorrect. [S4]

### Distinct, outer joins, and absence

`DISTINCT` maintains support counts and emits only transitions across zero at a complete logical epoch. Outer joins maintain match counts for each preserved-side row/key. A left row's NULL-extended output exists exactly when its match count is zero; a first match retracts it, and deletion of the last match restores it. Duplicates, NULL keys, and simultaneous changes on both sides must be covered. FULL OUTER JOIN requires both unmatched sides.

Semi joins retain left multiplicity when right support is positive. Anti joins retain it when support is zero. `NOT IN` is not a synonym for an anti equi-join: NULL on the right can make the result UNKNOWN. Decorrelation therefore carries null-aware existence state rather than applying a blanket rewrite. Nonlinear threshold decisions wait for complete input changes at the relevant epoch.

### Aggregation and ordered state

An aggregate adapter declares its state type, identity, update law, merge law, finalize function, NULL handling, empty-input behavior, and retraction strategy. `AVG` uses exact sum plus non-NULL count before a specified final division. `MIN`/`MAX` with deletions retain an ordered multiset or equivalent recoverable index, not merely the current extremum. `COUNT(DISTINCT x)` needs support counts for distinct values. Approximate sketches that cannot retract cannot be advertised as exact delete-capable aggregates.

Exact accumulator capacity must cover legal transient delta consolidation, not only the declared output type. Otherwise a delete/insert reordering could overflow an intermediate state even when the final epoch result is representable. `G0.1` fixes the exact `DECIMAL(18, 2)` / `BIGINT` rules for `W1-G` and its independent oracle, and `P1.1`/`P1.3` (G1) fixes and proves the full G1/G2 widened accumulator and type-return matrix for signed integers and `DECIMAL(p, s)` (`p <= 38`) under the weight/count limits; a bounded arbitrary-precision fallback is preferable to order-dependent numeric results. Final output casts and empty-group transitions occur after complete-epoch consolidation. Resource rejection remains explicit and cannot publish a partial group.

Top-K requires enough information to replace a deleted winner. Its state is generally proportional to retained candidates, not just K. The first supported maintained form requires a deterministic complete ordering over distinguishable output rows; exact duplicate rows remain represented by multiplicity. A hidden stable row encoding may break otherwise unspecified ties only if this product rule is documented and fingerprinted. Users needing PostgreSQL-independent repeatability should provide a unique final sort key. General ranking/window functions can change many rows after one insertion; the planner reports that cost and may reject an unbounded frame under the selected budget.

### Time and recursion

Ordinary `NOW()` remains transaction-stable in ad hoc SQL and is rejected in a maintained view. PostgreSQL distinguishes transaction time from wall-clock functions; Rockstream should preserve that distinction. [S5] G5 temporal views instead depend on an explicit durable clock relation. Its monotone ticks, timer registrations, and expiration events are replayable. A recovery cannot re-evaluate historical rows against the current machine's clock. Timer coalescing is legal only when it preserves published boundaries and freshness policy.

Event-time windows specify whether late data corrects retained results, is rejected, or is durably routed to an error relation. A finalization watermark is a source/policy assertion; it does not prove that the world will never produce an older event. Finalization and retention must be visible in catalog metadata and `EXPLAIN`.

G5 begins recursion with a restricted, finite, positive set-valued fragment and an explicit fixed-point/termination contract. `UNION` and `UNION ALL` have different behavior; counting all paths through a cycle can diverge. PostgreSQL's recursive CTE evaluation rules are a useful compatibility reference, not an efficient incremental deletion algorithm. [S6] Deletions in recursive graphs require a qualified algorithm, such as a validated differential trace strategy or rederivation; naive support counts can preserve self-supporting cycles. Until deletion support qualifies, the capability is insert-only or rejects the view/source contract. Iteration, memory, and work limits stop a nonconvergent epoch before publication, preserving the last published result. Nested iteration timestamps stay inside the fixed-point scope; they do not escape as a second user-visible commit clock.

## 4. Compiler pipeline and typed interfaces

| Stage | Output and invariant |
| --- | --- |
| Parse and bind | Typed names and stable IDs against a pinned catalog revision; reject unsupported syntax, volatility, or semantic combinations early. |
| Relational IR | Pure bag semantics, explicit NULL and aggregate contracts, stable expression hashes, source/dependency closure. Batch interpreter defines meaning. |
| Incremental IR | Integration/differentiation, delay, weighted linear operators, bilinear joins, threshold/reduce, explicit clock inputs, and later fixed-point scopes. |
| State planning | Logical arrangement requirements, ownership-independent identities, consumer cursors, retained-cut coverage, retention and recoverability classes, algorithm alternatives. |
| Physical IR | Vectorized kernels, explicit logical cut and pre/post-state access, partitioning, exchanges, spill/recompute contracts, resource reservations, and complete-epoch output boundaries. |
| Deployment plan | Executable tasks, graph generation, semantic and binary versions, durable state schemas, and recovery recipe. |

Illustrative type shape, not a current Rust API:

```rust
struct RelType {
    schema: SchemaId,
    semantics: SemanticVersion,
    multiplicity: MultiplicityContract,
}
struct NodeContract {
    inputs: Vec<RelType>,
    output: RelType,
    time_domain: DomainId,
    determinism: Determinism,
    error_effects: ErrorEffects,
    state: Vec<ArrangementRequirement>,
    cost_class: UpdateCostClass,
}
enum StateRead { BeforeEpoch, AfterEpoch, PinnedCut(LogicalCut, VersionId) }
```

The actual semantic algebra remains small. `Arrange` changes representation, not relation meaning; `Exchange` changes placement, not meaning; `Integrate` and `Delay` make state/time dependence explicit. `Reduce` is a semantic operator with a specified batch interpretation, not an escape hatch for arbitrary imperative code. Fixed-point constructs cannot bypass termination or resource contracts.

Every rewrite is annotated with preconditions: determinism, exact arithmetic, uniqueness/functional dependencies, collation equivalence, nullability, and multiplicity behavior. Constraints used for correctness must be enforced or certified from a trusted source contract. Observed uniqueness statistics are insufficient. Rewrites preserve both results and relevant error semantics. Serialized IR records a version and validation digest; deserialization revalidates contracts rather than trusting persisted executable plans.

### Executable strategy contracts

Represent each admitted rewrite and physical strategy with a small versioned, machine-readable contract used by planning, diagnostics and verification. Start with the rules actually implemented in G1/P3.7/P3.8; this is neither a second rule engine nor a requirement to formalize every optimizer theorem before the first slice. The record must distinguish facts that authorize a transformation from statistics that only estimate its cost.

| Contract field | Required content |
| --- | --- |
| Identity and eligibility | Stable rule/strategy ID and version, input pattern, semantic profile, supported capability combinations and qualification evidence. |
| Semantic conditions | Types, NULL/error/multiplicity laws, determinism and required keys/dependencies; how each condition is enforced or certified, its catalog/source scope, and when it must be revalidated. |
| State and time | Required arrangements/auxiliary state, pre/post-epoch access, retained-cut coverage, retraction behavior and complete recovery/replay obligations. |
| Resource conditions | Bounded work/state assumptions, affected-key/fanout limits where required, reservations, and the qualified fallback or explicit rejection when a bound cannot be met. |
| Evidence | Independent reference cases, satisfying and violating preconditions, minimized counterexamples, public-path/restart coverage and measured profiles; missing evidence remains visible. |

An emitted plan records the selected contract versions and the facts satisfying them. Deserialization, replacement and relevant schema/constraint changes revalidate those facts before using the plan. Neither a digest, matching one sampled output nor equality at a single cut proves equivalence for future updates. Runtime same-cut verification complements the semantic argument and the historical/recovery checks. Statistics may rank semantically valid plans but cannot turn an unverified uniqueness assumption into a correctness condition.

The compiler separates semantic IDs from physical IDs. A change in worker placement or hash partition count does not create a different mathematical relation. A change in collation, filter expression, timezone semantics, or security interpretation does. This makes shared state possible without coupling correctness to worker lifetimes.

## 5. Algorithm portfolio and arrangement sharing

First-order delta execution is the mandatory baseline in G1–G3a. Eligible partial aggregation and factorization (F-IVM) are qualified independently in **G3b-F** as a bounded initial family with explicit algebraic side conditions, first-order semantic fallback, and matched lifetime benchmarks (including persistence and recovery). More general higher-order derivatives, multiway joins, recursion, and automated cost-model / adaptive plan replacement remain independently gated **G5** work. Every optimized algorithm must have a semantic fallback and a matched benchmark, or a clear capability rejection when no resource-safe fallback exists.

| Strategy | Admission condition | Material limit |
| --- | --- | --- |
| First-order indexed delta join | Qualified joins and versioned arrangements | One update may inherently produce a large output. |
| Partial aggregation/factorization | Proven distributivity, sufficient statistics, matching NULL/numeric semantics | Some groups or keys still have high fanout. |
| Higher-order IVM | Bounded auxiliary views and measured recurring benefit | Faster updates can require much larger persistent state. |
| Multiway/worst-case-optimal join | Qualified query shape and physical implementation | Better asymptotic bounds need not beat indexed binary joins on a given workload. |
| Localized recomputation | Explicit affected-key/partition bound and recoverable input | A fallback must not silently become a full unbounded database scan. |
| Recursive differential maintenance | Qualified recursive fragment and deletion algorithm | Termination and state growth remain workload dependent. |

A fixed, explicitly selected qualified factorization rule can ship before independent shared consumers, online isolation or a broad state-placement planner. It still records its eligibility facts, state bounds, recovery contract and first-order fallback/rejection in the ordinary plan and `EXPLAIN INCREMENTAL`. No generic optimizer framework is a prerequisite.

When multiple strategies are admitted, search a finite set of candidates, beginning with first-order execution and the bounded qualified factorization family. Cap candidate count, planning time/memory and proposed auxiliary state; record when search stops. Keep the best admissible candidate found, or reject when no qualified plan fits the resource contract. An incomplete search cannot claim global optimality, and a first-order fallback still needs its own admission checks. Higher-order or multiway candidates enter this set only after their separate capability gates; no universal auxiliary-view search is required for G3.

F-IVM research motivates maintaining hierarchies of auxiliary views and factorized payloads. Rockstream's choice of which patterns to implement is a product decision, not a claim to reproduce every research result. [S7]

For orders joined to customers and summed by region, maintain order sum and relevant counts by customer, then combine with customer-to-region rows. With an enforced unique customer key and exact arithmetic, moving a customer between regions can transfer the per-customer aggregate without scanning all historical orders. If customer keys have duplicates, correct multiplicities and sufficient statistics must be retained; the uniqueness-based shortcut is invalid. A filter on individual order attributes, DISTINCT aggregate, or later join can require a different factorization. Decimal overflow/rounding also constrains reassociation.

A reusable logical arrangement identity contains the normalized expression, input identities and lineage, time domain, schema, semantic version, equality/key expressions, collation, and security-sharing scope. Physical variants add partitioning, encoding, compression, and format version. A hash match is only an index into a catalog: full semantic descriptors must match before reuse, and a separate compatibility check verifies that the physical variant can satisfy the new consumer's retained-history and freshness requirements. Two views with different authorization policies cannot accidentally share a policy-dependent result. Shared physical input state is permitted only within an explicitly authorized isolation boundary.

**G3b-S baseline:** Share only among views explicitly placed in one atomic publication group with the same maintenance cadence and compatible retention contracts. Reuse still requires full semantic/security descriptors, lifecycle reference tracking, bounded state, exact restart and measured benefit against isolated state. All members accept the group's joint publication and quarantine boundary; the planner cannot merge independent groups merely to obtain reuse. A request for independent schedules or fault isolation uses separate arrangements until `G3b-I` qualifies.

**G3b-I extension:** Sharing does not imply identical freshness or infinite retention. Each consumer records its next required cut, retention protection, publication group, and maintenance policy. Shared arrangement progress can advance while a slower consumer reads retained older versions; unrelated groups do not acquire a common commit barrier merely through sharing. Explicit dependencies and atomically grouped publication still require compatible cuts. The planner may fork a physical arrangement when one consumer's retention, load, or availability requirements impose excessive cost on others. Slow consumers use a bounded history budget and may need to resnapshot after expiry. Dropping a view releases its references through the catalog lifecycle; it never directly deletes a shared trace. Differential Dataflow's arrangement abstraction supports indexed sharing as a useful precedent; durable multi-tenant sharing adds Rockstream-specific contracts. [S8]

## 6. Resource-aware placement, diagnostics, and G5 cost-model optimization

Use **deterministic, measurable rules**, scoped to the capability being adopted. A speculative monetary cost predictor is not a prerequisite; future workload parameters (update skew, failure frequency, sleep cycles) are unknown at `CREATE MATERIALIZED VIEW` time:

- **G3b-S sharing within one group/cadence:** Share an existing canonical arrangement when full semantic and security descriptors match and the new consumer is in the same publication group/cadence and its retention obligations fit within the shared arrangement's configured retention/memory budget. Independent publication or cadence requires `G3b-I`.
- **G3b-I explicit and rule-based isolation:** Isolate a consumer (via pinned snapshot, replay, exact-cut verification, and atomic binding cutover) when explicitly requested or when its retention window or lag exceeds the shared arrangement's configured budget, reserving peak coexistence capacity before starting.
- **G3b-F bounded eligible F-IVM (`P3.8`):** Apply a small catalog of algebraically verified join-aggregate factorization rules (checked against enforced uniqueness/nullability/numeric contracts) when the rule's preconditions hold and state bounds fit, retaining first-order IVM as the fallback.

Collect versioned, bounded runtime telemetry: update/delete rates, cardinality, key skew, output amplification, reuse count, state/history bytes, cache hit rate, object requests, and compaction debt.

`EXPLAIN INCREMENTAL` reports selected and considered strategies, contract/precondition decisions (distinguishing enforced keys from observed statistics), shared/reconstructed/persisted state, required indexes, expected update and output amplification, retention pins, exact/approximate status, and fallback/rejection conditions. Distinguish unavoidable output fanout from avoidable intermediate work, state maintenance, and remote-request amplification; label measured versus estimated values clearly. `ANALYZE` must explicitly opt in to a bounded sample or production telemetry; explanation never triggers unlimited backfill.

### G5 multi-term monetary cost advisor and online adaptive replacement

Once real production telemetry exists in **G5**, an optional **workload materialization advisor** (`P5.6`) may evaluate whole-workload cost over a planning horizon `H` (accounting for build, compute, retained state, object requests, network, compaction, recovery, cold catch-up, and transition overlap—with prices and units kept separate, shared benefits counted once, and uncertainty ranges exposed). Generating advice is read-only and never starts a build or alters catalog policy; explicit or automatic application requires hysteresis, minimum benefit, cooldown, peak transition budget reservation, catalog/constraint revalidation, and verified same-cut atomic cutover (`V`) with safe rollback tails. An adaptive experiment must never exhaust capacity needed by the active plan.

## 7. Execution and verification obligations

Vectorized kernels operate on bounded Arrow batches plus checked weights. Mutable state has one fenced owner at a time; operators return prepared effects to publication rather than committing independently. Memory reservation precedes allocation; high fanout yields cooperatively and spills under a plan budget. Exchange preserves run incarnation, schema, semantic version, epoch interval, plan/ownership/partition-map generations, and an explicit `AttemptId`. A retry of the same unpublished epoch gets a new attempt so delayed messages from abandoned work cannot enter its state. Within an attempt, edge/sender sequence identities detect duplicate delivery. In-flight messages count toward progress until processed or durably recoverable under the recovery protocol.

Timely's capability model is a useful foundation for proving when no further data can arrive at a logical time. [S9] Rockstream still needs its own bridge between computation progress and durable publication. A capability being dropped is not evidence that output objects were persisted.

| Obligation | Required evidence before promotion |
| --- | --- |
| Primitive law | Property tests over inserts, retractions, duplicates, NULLs, empty inputs, and checked boundary values; exact complete bags. |
| Rewrite | Preconditions exercised with both satisfying and violating cases; original and rewritten IR compared on the same histories. |
| Strategy admission | Contract/version mismatch, missing required constraint evidence and exhausted search/resource budgets reject or select a qualified fallback; favorable statistics never admit an invalid rewrite. |
| SQL reachability | Real public SQL through binding, planning, execution, persistence, restart, and response encoding. An internal Rust operator is insufficient. |
| Same-epoch join correctness | Both inputs change, including duplicate insert/delete cancellation and nonempty cross terms. |
| Nonlinear operators | Zero-crossing transitions, first/last matches, empty global aggregates, top-K replacement after deletions. |
| Logical MVCC | Exact answers at every advertised retained cut across different physical checkpoint intervals, compaction, crash, and slow-consumer catch-up; explicit failure at uncovered cuts. |
| Same-group sharing (G3b-S) | Full descriptor and group/cadence checks; lifecycle, restart, bounded state and measured benefit; rejection of independent-cadence attachment. |
| Shared scheduling (G3b-I) | Fast and scheduled consumers retain compatible cuts without a forced global barrier; bounded history, expiry/resnapshot, and deliberate duplication under SLO pressure. |
| Early factorization (G3b-F) | Grouped-join updates and deletes, enforced uniqueness violations, NULL/decimal limits, historical cuts, restart, and complete lifetime cost against first-order execution. |
| Time and recursion | No-data timer progress, replay after crash, late input policies, cyclic graphs, recursive deletions, limit exhaustion without partial publication. |
| Plan replacement | Exact cut alignment under concurrent writes, restart at each phase, old/new schema and subscription compatibility, rollback constraints. |
| Materialization advice | Stale recommendations revalidate before application; overlapping benefits are not double counted; peak transition and retained-history costs can reject an apparently cheaper steady-state plan; advisory inspection never starts a build or changes catalog/consumer policy. |

The batch interpreter, PostgreSQL oracle, production path, randomized histories, and recovery simulator each detect different failures. None alone is an end-to-end proof. Feature promotion requires the [qualification program](../planning/qualification.md), including resources and failure behavior alongside SQL results.

## Sources and evidence

Primary sources inspected on 2026-11-25. Statements about Rockstream 2 above are proposed contracts; references supply mathematical foundations, compatibility details, or evidence about existing code.

- **S1:** Budiu et al., [DBSP: Automatic Incremental View Maintenance for Rich Query Languages](https://docs.feldera.com/vldb23.pdf), PVLDB 2023, DOI 10.14778/3587136.3587137.
- **S2:** Apache DataFusion, [configuration settings](https://datafusion.apache.org/user-guide/configs.html) and [SQL reference](https://datafusion.apache.org/user-guide/sql/index.html). Pin a concrete release and settings during G0; these moving documentation pages are research references.
- **S3:** PostgreSQL, [aggregate functions](https://www.postgresql.org/docs/current/functions-aggregate.html).
- **S4:** Existing Rockstream at `d3f973a84f4263bedd6505039d7f469d4708c478`: [differentiation pass](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-diff/src/lib.rs), [pre-aggregation admission](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-plan/src/lib.rs), and [IVM design](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/IVM.md).
- **S5:** PostgreSQL, [date/time functions](https://www.postgresql.org/docs/current/functions-datetime.html).
- **S6:** PostgreSQL, [WITH and recursive queries](https://www.postgresql.org/docs/current/queries-with.html).
- **S7:** Kara, Nikolic, Olteanu, and Zhang, [F-IVM: Analytics over Relational Databases under Updates](https://arxiv.org/abs/2303.08583), 2023.
- **S8:** Differential Dataflow, [arrangements](https://timelydataflow.github.io/differential-dataflow/chapter_5/chapter_5.html).
- **S9:** Timely Dataflow, [creating operators and capabilities](https://timelydataflow.github.io/timely-dataflow/chapter_2/chapter_2_4.html).
