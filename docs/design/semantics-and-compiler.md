# Semantics, incremental algebra, and compilation

**Status:** proposed design; no Rockstream 2 engine or SQL capability is implemented by this documentation PR. **Date:** 2026-11-25. Read [DESIGN.md](../../DESIGN.md) first and [SQL and API contracts](../reference/sql-and-apis.md) for the proposed public surface. The G0–G6 labels refer to the [implementation gates](../planning/implementation-plan.md), not release promises. G5 is an advanced capability track: each feature must qualify independently and need not block G6 production qualification of a smaller surface.

## 1. The semantic contract

The semantic model is a sequence of finite weighted relations. For a relation with row type `T`, `ZSet<T>` is a finite-support function `T → Z`. Addition sums multiplicities; negation retracts them. SQL input and output snapshots are bags with nonnegative multiplicities. Signed intermediate deltas are legal; a negative committed table multiplicity is an error, not a negative number of database rows.

Within a consistency domain, `Epoch` is a totally ordered logical number. If `ΔR_e` is the complete input change at epoch `e`, then:

```text
R_e       = R_(e-1) + ΔR_e
O_e       = Q(R_e)
ΔO_e      = Q(R_e) - Q(R_(e-1))
O_e       = O_initial + Σ_(i ≤ e) ΔO_i
O_initial = Q(R_initial)
```

For a newly empty database, `R_initial` is empty. `Q(empty)` is not always empty: an ungrouped `COUNT(*)` produces one row containing zero. Initialization is part of the circuit and must be published exactly once. Backfill instead establishes `Q` at a pinned nonempty input cut, followed by changes strictly beyond that cut.

The required invariant is equality of complete typed bags between incremental evaluation and batch evaluation at every published cut. Ordered output additionally obeys its ordering contract. For an opted-in approximate numeric capability, equality is replaced by that capability's stated error and reproducibility contract; this never weakens exact capabilities.

DBSP provides a compositional framework for expressing integration, differentiation, and incremental transformations. Rockstream adopts that semantic foundation without treating a paper as proof of a particular implementation or of arbitrary performance. The reference interpreter, lowering rules, and persistence protocol all require their own evidence. [S1]

A published exclusive upper `U` means all epochs `e < U` are complete. `U = 28` includes epoch 27. An operator's computation frontier is not a durability acknowledgement. Domain-local epochs from different domains cannot be compared. A `SourceCut` describes the complete native source positions and imported relation versions represented by a snapshot; it is not a global clock.

An input transaction supplies an atomic set of changes. Intermediate retractions, transient negative counts, and intermediate join results are invisible until the whole epoch has been evaluated and published. Direct-write validation must reject an invalid transaction before durable acceptance. If a valid durably accepted input later makes a derived view exceed a resource or arithmetic limit, that view/domain stops publication with an explicit error; the accepted source transaction cannot be silently rolled back or skipped. Admission and safe numeric limits should make this exceptional, but recovery must preserve the distinction.

## 2. SQL meaning belongs to Rockstream

DataFusion and Arrow are valuable parsing, planning, and expression execution components. They do not define the product's SQL contract. DataFusion exposes configurable dialect and null ordering, and its documented `VARCHAR(n)` behavior can ignore the length because Arrow does not enforce it. Consequently, selecting a PostgreSQL parser dialect is insufficient to claim PostgreSQL semantic compatibility. [S2]

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

Exact accumulator capacity must cover legal transient delta consolidation, not only the declared output type. Otherwise a delete/insert reordering could overflow an intermediate state even when the final epoch result is representable. G0 must fix the widened accumulator/type-return matrix and prove its range under the weight/count limits; a bounded arbitrary-precision fallback is preferable to order-dependent numeric results. Final output casts and empty-group transitions occur after complete-epoch consolidation. Resource rejection remains explicit and cannot publish a partial group.

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
| State planning | Logical arrangement requirements, ownership-independent identities, retention and recoverability classes, algorithm alternatives. |
| Physical IR | Vectorized kernels, pre/post-state access, partitioning, exchanges, spill/recompute contracts, resource reservations, and complete-epoch output boundaries. |
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
enum StateRead { BeforeEpoch, AfterEpoch, PinnedVersion(VersionId) }
```

The actual semantic algebra remains small. `Arrange` changes representation, not relation meaning; `Exchange` changes placement, not meaning; `Integrate` and `Delay` make state/time dependence explicit. `Reduce` is a semantic operator with a specified batch interpretation, not an escape hatch for arbitrary imperative code. Fixed-point constructs cannot bypass termination or resource contracts.

Every rewrite is annotated with preconditions: determinism, exact arithmetic, uniqueness/functional dependencies, collation equivalence, nullability, and multiplicity behavior. Constraints used for correctness must be enforced or certified from a trusted source contract. Observed uniqueness statistics are insufficient. Rewrites preserve both results and relevant error semantics. Serialized IR records a version and validation digest; deserialization revalidates contracts rather than trusting persisted executable plans.

The compiler separates semantic IDs from physical IDs. A change in worker placement or hash partition count does not create a different mathematical relation. A change in collation, filter expression, timezone semantics, or security interpretation does. This makes shared state possible without coupling correctness to worker lifetimes.

## 5. Algorithm portfolio and arrangement sharing

First-order delta execution is the mandatory baseline. Every advanced algorithm must have a semantic fallback and a matched benchmark, or a clear capability rejection when no resource-safe fallback exists.

| Strategy | Admission condition | Material limit |
| --- | --- | --- |
| First-order indexed delta join | Qualified joins and versioned arrangements | One update may inherently produce a large output. |
| Partial aggregation/factorization | Proven distributivity, sufficient statistics, matching NULL/numeric semantics | Some groups or keys still have high fanout. |
| Higher-order IVM | Bounded auxiliary views and measured recurring benefit | Faster updates can require much larger persistent state. |
| Multiway/worst-case-optimal join | Qualified query shape and physical implementation | Better asymptotic bounds need not beat indexed binary joins on a given workload. |
| Localized recomputation | Explicit affected-key/partition bound and recoverable input | A fallback must not silently become a full unbounded database scan. |
| Recursive differential maintenance | Qualified recursive fragment and deletion algorithm | Termination and state growth remain workload dependent. |

F-IVM research motivates maintaining hierarchies of auxiliary views and factorized payloads. Rockstream's choice of which patterns to implement is a product decision, not a claim to reproduce every research result. [S7]

For orders joined to customers and summed by region, maintain order sum and relevant counts by customer, then combine with customer-to-region rows. With an enforced unique customer key and exact arithmetic, moving a customer between regions can transfer the per-customer aggregate without scanning all historical orders. If customer keys have duplicates, correct multiplicities and sufficient statistics must be retained; the uniqueness-based shortcut is invalid. A filter on individual order attributes, DISTINCT aggregate, or later join can require a different factorization. Decimal overflow/rounding also constrains reassociation.

A reusable logical arrangement identity contains the normalized expression, input identities and lineage, time domain, schema, semantic version, equality/key expressions, collation, and security-sharing scope. Physical variants add partitioning, encoding, compression, and format version. A hash match is only an index into a catalog: full semantic descriptors must match before reuse, and a separate compatibility check verifies that the physical variant can satisfy the new consumer's retained-history and freshness requirements. Two views with different authorization policies cannot accidentally share a policy-dependent result. Shared physical input state is permitted only within an explicitly authorized isolation boundary.

Sharing does not imply identical freshness or infinite retention. Each consumer acquires a lease and records the minimum history it needs. The planner may fork a physical arrangement when one consumer's retention, load, or availability requirements impose excessive cost on others. Dropping a view releases its references through the catalog lifecycle; it never directly deletes a shared trace. Differential Dataflow's arrangement abstraction supports indexed sharing as a useful precedent; durable multi-tenant sharing adds Rockstream-specific contracts. [S8]

## 6. Optimize lifetime cost under constraints

Use a planning horizon H and estimate money over that horizon:

```text
expected_cost(H) = initial_build_cost
  + compute_cost(H) + retained_state_cost(H) + object_request_cost(H)
  + network_cost(H) + compaction_cost(H) + expected_recovery_cost(H)
```

Prices and resource units are recorded separately; the model cannot add CPU seconds to bytes without conversion. Expected recovery cost uses an explicit scenario/failure frequency, while hard recovery objectives remain constraints. Optimize subject to semantic validity, tenant budgets, maximum state, freshness, serving latency, recovery limits, and allowed degradation. Cost estimates have ranges/confidence, not invented precision.

Collect update and delete rates, cardinality, key skew, output amplification, reuse count, state bytes, cache hit rate, object request size, and compaction debt. Keep statistics versioned and bounded. The workload optimizer admits a new view against the incremental cost of the whole graph; a locally cheaper plan may be more expensive after losing shared arrangements. Charge back shared costs using a documented policy, without turning billing attribution into a correctness dependency.

Initial adaptation is conservative: scheduling/batching adjustments and explicitly triggered alternative-plan evaluation. G5 automatic replacement requires hysteresis, minimum benefit, cooldown, and a budget for running both versions. Build the replacement from pinned cut C; retain/replay deltas after C; catch up to an exact complete cut V; verify its semantic identity and all required state; atomically switch the catalog's active generation at V. Old subscriptions continue with a compatible logical output stream or receive a documented schema break. Rollback uses retained old state or a rebuild; it cannot assume the previous plan kept advancing after cutover. An adaptive experiment must not exhaust the resources needed to maintain the active plan.

`EXPLAIN INCREMENTAL` reports algorithm, shared/reconstructed/persisted state, required indexes, expected update and output amplification, uncertainty, retention pins, exact/approximate status, and fallback/rejection conditions. `ANALYZE` must explicitly opt in to executing a bounded sample or reading production telemetry; an explanation request must not trigger unlimited backfill.

## 7. Execution and verification obligations

Vectorized kernels operate on bounded Arrow batches plus checked weights. Mutable state has one fenced owner at a time; operators return prepared effects to publication rather than committing independently. Memory reservation precedes allocation; high fanout yields cooperatively and spills under a plan budget. Exchange preserves run incarnation, schema, semantic version, epoch interval, plan/ownership/partition-map generations, and an explicit `AttemptId`. A retry of the same unpublished epoch gets a new attempt so delayed messages from abandoned work cannot enter its state. Within an attempt, edge/sender sequence identities detect duplicate delivery. In-flight messages count toward progress until processed or durably recoverable under the recovery protocol.

Timely's capability model is a useful foundation for proving when no further data can arrive at a logical time. [S9] Rockstream still needs its own bridge between computation progress and durable publication. A capability being dropped is not evidence that output objects were persisted.

| Obligation | Required evidence before promotion |
| --- | --- |
| Primitive law | Property tests over inserts, retractions, duplicates, NULLs, empty inputs, and checked boundary values; exact complete bags. |
| Rewrite | Preconditions exercised with both satisfying and violating cases; original and rewritten IR compared on the same histories. |
| SQL reachability | Real public SQL through binding, planning, execution, persistence, restart, and response encoding. An internal Rust operator is insufficient. |
| Same-epoch join correctness | Both inputs change, including duplicate insert/delete cancellation and nonempty cross terms. |
| Nonlinear operators | Zero-crossing transitions, first/last matches, empty global aggregates, top-K replacement after deletions. |
| Time and recursion | No-data timer progress, replay after crash, late input policies, cyclic graphs, recursive deletions, limit exhaustion without partial publication. |
| Plan replacement | Exact cut alignment under concurrent writes, restart at each phase, old/new schema and subscription compatibility, rollback constraints. |

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
