# Proposed SQL and API contracts

**Status:** design proposal, not runnable product documentation. Every capability in this document is **Planned**. No SQL extension or protocol shown here exists in Rockstream 2 yet. **Date:** 2026-11-26. The semantic authority is [semantics and compilation](../design/semantics-and-compiler.md); the release sequence is the [implementation plan](../planning/implementation-plan.md).

## 1. A deliberately explicit compatibility surface

Rockstream 2 exposes a PostgreSQL-compatible connection protocol and a defined relational SQL subset. It is not a complete PostgreSQL server. PostgreSQL extensions, arbitrary OLTP transactions, row locks, triggers, stored procedures, catalogs, wire behavior, and authentication modes need separate capability declarations. Parsing syntax does not establish support.

Start a minimal versioned machine-readable capability registry in G0/G1; generate documentation and executable conformance cases where practical. Statuses are Planned (design only), Implemented (path exists, not a support claim), Verified (applicable correctness/recovery checks), Qualified (required profile-specific evidence) and Supported (approved public release commitment). A regression can revoke qualification; status and evidence are scoped by version, combinations and deployment profile. Every row here remains Planned. Each entry contains stable ID, semantic version, status, public entry point, supported combinations, stage, exactness, resource limits, restart behavior, failure behavior, and evidence links. A feature cannot move from Planned to Qualified based only on an internal operator test, and an agent cannot self-promote a feature to Supported without authorized release review. A later gate is a target for evaluation, not a guarantee that every row ships together.

| Capability group | First target gate | Planned scope and boundary |
| --- | --- | --- |
| Semantic interpreter and typed algebra | G1 | Weighted bag laws, exact numeric/reference semantics, relational primitives; no product availability claim. |
| PostgreSQL wire, direct writes, reads | G2 | Documented clients, simple/extended query paths, parameter binding, cancellation, typed results, same-domain atomic input transactions. |
| Foundational maintained SQL | G2 | Projection, deterministic expressions, filters, inner equi-joins, `UNION ALL`, and checked widened grouped `COUNT`/`SUM`/`AVG` over qualified types. |
| Table-stakes relational SQL & live connectors | G3a | `LEFT OUTER JOIN`, `DISTINCT`, semi/anti joins (`EXISTS`/`NOT EXISTS`), delete-safe `MIN`/`MAX`, online view backfill/replace/drop, resumable subscriptions, PostgreSQL CDC (with benign additive-DDL tolerance), Kafka source, and at-least-once Kafka outbox sink. |
| Shared workload graph, logical MVCC & eligible F-IVM | G3b | Shared canonical arrangements, independent consumer schedules, rule-based/explicit consumer isolation, multi-cadence bounded logical MVCC, bounded single-depth pipelining, and bounded eligible join-aggregate factorization (F-IVM) with first-order baseline. |
| Distributed execution and serving | G4 | Fenced partitions, preferred-committer hint/fallback, consistent publication, independent cache-affinity serving pools, explicitly imported cross-domain relations, distributed suspension/wake, and optional Embedded OpenRaft profile. |
| `FULL OUTER JOIN`, complex subqueries, nested types | G5 feature gates | NULL-aware semantics, retractions, decorrelation, and explicit array/JSON equality and serialization rules; promote useful subsets independently. |
| Top-K, ordered windows, temporal predicates, recursion | G5 feature gates | Deterministic ordering, delete refill, explicit replayable clock input, lateness/finalization policy, restricted recursive fragment, and qualified deletion semantics. |
| Broader higher-order IVM, monetary cost advisor & adaptive plans | G5 feature gates | Shape-specific higher-order strategies, whole-workload monetary cost advisory over measured telemetry, and automated plan replacement with hysteresis/rollback. |
| Additional protocols | G4/G5 adapter gates | Arrow Flight SQL and stronger destination-marker sink protocols are separately qualified adapters. |
| Suspension and activation | G2–G4 implementation | Durable single-process stop/restart (G2), shared-consumer retention (G3b), then distributed drain and fenced concurrent wake (G4). |
| Elastic maintenance and production release | G6 | Qualified workload envelope, operational/security gates and measured idle/wake economics. G5 research does not all have to finish first. |

The first type profile includes booleans, fixed-width signed integers, declared decimal precision up to 38, binary-collated text, bytes, date, timestamp/timestamptz, and stable identifiers. Every type/operator combination still needs an entry. Unbounded NUMERIC, locale collations, unsupported casts, float aggregation, and arbitrary UDFs fail closed until their specific capability is admitted. Initial direct tables have declared primary keys for deterministic updates/deletes; connector bag sources may carry duplicates with explicit source identities.

The [implementation-start user journey and golden workload](../planning/implementation-start.md) define the initial authenticated local quickstart and exact observed result, with proposed five-minute usability target. Keep SQL semantics and durability identical to the declared deployment profile; command names remain proposed until exercised.

## 2. Declarative objects and proposed syntax

The following is illustrative syntax to validate during G0/G2/G3. Names and options are proposed; they are not current commands.

```sql
CREATE TABLE orders (
    order_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    amount DECIMAL(18, 2) NOT NULL
);

CREATE MATERIALIZED VIEW spend_by_customer
WITH (
    freshness_target = '1 second',
    history_retention = '7 days',
    maintenance = 'continuous',
    publication_group = 'billing_views' -- optional; omit for default per-view publication head
)
AS SELECT customer_id, COUNT(*) AS order_count, SUM(amount) AS total
   FROM orders
   GROUP BY customer_id;

CREATE INDEX spend_lookup ON spend_by_customer (customer_id);
```

`maintenance` selects continuous, freshness-batched, scheduled or on-demand work; exact syntax and defaults remain to be qualified. Omitting `publication_group` gives the view its own independent publication head (and fault-quarantine scope) consuming its ingestion domain; naming a shared `publication_group` places participating views under one joint atomic visibility and quarantine boundary. A policy does not change the query result or authorize gaps in source transactions.

`freshness_target` is an admission/scheduling objective, measured over a specified qualified workload; it is not an unconditional guarantee for every query. `history_retention` is a minimum history policy within an admitted budget. The system may refuse creation or pause ingestion/maintenance according to the declared failure policy if it cannot satisfy that policy; it never silently expires promised history or weakens durability. The default durability contract is strict. A later fast durability tier must be a separately qualified deployment capability with its own recovery references.

Sources bind to catalog-managed connection objects with secret references, not credentials embedded in durable SQL or logs:

```sql
CREATE SOURCE source_orders
FROM POSTGRES (
    CONNECTION = production_db,
    TABLE = 'public.orders'
);
```

Creating a PostgreSQL source requires permissions, a supported table identity/before-image strategy, and sufficient source retention. Snapshot rows and subsequent CDC transactions must connect at a documented consistent boundary. Kafka tables declare topic/partition discovery, offset reset policy, key format, schema identity, and whether records represent append-only events, upserts, or signed changes. A Kafka offset by itself is not evidence of a cross-partition transaction unless the connector preserves and validates that contract.

Deployment manifests and SQL use the same versioned catalog operations. Each mutation includes the registered request identity defined below and, where needed, expected catalog generation. The system records who requested it, normalized configuration, resulting operation ID, and status. Sensitive values are redacted. Retry within the retained result window returns the previous result; reusing an identity with a different payload is an error. Catalog operations use the same generation/sequence admission rule as direct input, in a distinct operation scope; arbitrary client labels are not sufficient retry identities.

## 3. Writes, acknowledgements, and transaction scope

G2 input transactions are bounded atomic batches within one consistency domain. The first SQL DML surface supports INSERT and qualified primary-key UPDATE/DELETE; predicate-wide mutations and general write/read transactions require additional conflict-control design. Write batches validate keys, types, constraints, before-images, size, and admission before durable acceptance. A source CDC transaction touching several imported tables remains whole when those tables belong to one source transaction scope. It must not be split across publication boundaries.

`BEGIN`/`COMMIT` in input mode buffers DML and validates its base key versions at serialized acceptance; conflicting concurrent updates return a retryable conflict. Tables accepting direct SQL `UPDATE`/`DELETE` normalize retractions once against an **explicitly budgeted durable primary-key image index** at the durable accepted-input head (using the uniform SlateDB checkpoint + bounded input-log overlay with metadata checkpoint registration and overlay-cap backpressure defined in [consistency and storage](../design/consistency-and-storage.md#3-durable-ingestion-and-acknowledgements), explicitly accounted for in memory, storage, compaction, and cold-recovery budgets). Append-only tables and PostgreSQL CDC sources carrying full before-images avoid this extra primary-key index completely. The domain sequencer serializes validation and atomic advancement of the input head plus admission state. Within a batch, statements see prior statements' normalized effects; the committed record contains the final retractions/insertions and payload digest, not a SQL statement to reevaluate later. `SELECT` inside an input transaction is rejected initially; read-only repeatable snapshot transactions are a separate mode.

Two acknowledgements have distinct meaning:

| Acknowledgement | Meaning | Does not imply |
| --- | --- | --- |
| `durable_input` | Input transaction, identity, source positions, and recovery references are durably committed under the deployment's failure model. | That all materialized views have caught up. |
| `published` for named dependencies | A returned snapshot includes the write's effects in the requested, catalog-pinned dependency closure. | That an external sink has completed its side effect. |

The default input COMMIT returns after `durable_input` and provides an opaque `WriteToken`. A separate wait operation requests publication of named views. The gateway carries the session's relevant per-domain write tokens into read-your-writes requests; a later write in another domain cannot erase an earlier dependency. Applications can disable that read policy explicitly. A publication timeout never implies that the accepted input transaction was rolled back. The client can query its registered request identity or wait again.

Conceptual token payloads are shown for implementers; clients treat the wire representation as opaque:

```text
WriteToken = {
  tenant_id, database_id, run_incarnation, domain_id, input_transaction_id,
  client_id, signed_client_generation, request_sequence,
  assigned_epoch, source_positions, ingestion_generation,
  token_format_version, integrity_tag
}

SnapshotToken = {
  tenant_id, database_id, run_incarnation, catalog_revision,
  logical_read_cuts, published_history_roots, published_exclusive_uppers,
  source_cut, relation_generations, semantic_versions,
  retention_pin_id, pin_generation, token_format_version, integrity_tag
}
```

Within the write token's own domain/time lineage, visibility of a write assigned epoch `e` requires a durable published upper greater than `e`, plus the requested dependency checks. A consuming result domain instead proves inclusion of that transaction through its certified source-cut/import lineage; its local epoch must never be compared numerically with the ingestion epoch. Token signatures prevent tampering but do not grant access; current authorization is checked on every operation. Restore creates a new `RunIncarnation` and rejects all prior write, snapshot, and subscription tokens in the initial release, avoiding accidental collision of reused epoch numbers. Any future token remapping requires its own qualified protocol.

G2–G3b token retention uses a durable metadata pin; short-lived in-process queries use in-process pins. At G4, an out-of-process short query may use a reader lease protected by the sweeper-observed GC deletion grace window (`Δ_read_lease + clock_skew_bound << Δ_gc_grace`) and verified against `monotonic_now() < lease_deadline` before response flush. Lease-backed reads are local to the serving process and bounded in duration; resumable or transferable tokens require a dedicated durable pin. See [monotonic lease-backed reader protection](../design/consistency-and-storage.md#81-monotonic-lease-backed-reader-protection-and-sweeper-observed-gc-grace-windows).

Direct clients register a `ClientGeneration` and send `(client_id, signed_client_generation, sequence)` for every mutation. The generation is server-issued and scoped to run incarnation, tenant/database, domain, and operation stream; catalog operations use a separate catalog stream. The sequence is monotonic within a bounded admitted window. Durable admission records preserve generation validity, low/high watermarks, admitted gaps, payload digests, and recent result mappings. A sequence below the replay floor or an expired/unknown generation returns `RS_IDEMPOTENCY_EXPIRED` and requires reconciliation or explicit new registration. It is never interpreted as a new request. Optional arbitrary client labels cannot replace this identity: once a string has been completely forgotten, a server cannot distinguish its retry from a never-used string.

The public SDK/control API exposes registration and status lookup. The pgwire adapter needs documented Rockstream session settings or a transaction extension to supply a registered generation/sequence before COMMIT; G2 must qualify this path. Ordinary PostgreSQL clients that do not opt into that extension retain ordinary unknown-outcome behavior after a lost connection and must reconcile before resubmitting DML. The gateway must not advertise safe blind retry using an identity the client never received.

An unknown outcome retries the same identity and bytes. A definitive conflict or validation rejection has no accepted input effects; rebuilding that transaction after inspecting the rejection uses a new sequence. Reusing the rejected identity must not silently turn the previous rejection into a new accepted operation. This distinction belongs in SDK retry policy and protocol conformance tests.

Exactly-once ingestion depends on that replay-window contract. Connectors instead use qualified native source identities and persistent lineage/high-water positions. Source acknowledgements and Kafka offset commits occur only after Rockstream's durable input acceptance. Detailed result records may be reclaimed only while enough generation/window metadata remains to reject old retries safely.

## 4. Read policies and cross-domain behavior

Every query binds one protected catalog revision and one compatible snapshot token before execution. A scan cannot move to a newer manifest halfway through a query. Query cancellation and statement timeout release that reader's registration or dedicated pin through the normal lifecycle; they cannot release protection used by other group readers. A replica cannot serve a version whose data it cannot verify/read.

| Policy | Contract |
| --- | --- |
| Latest committed | Resolve authoritative published heads at a linearizable selection point during the request (one inline root read under Object-Native; low latency under Embedded Raft is an unmeasured target). G2–G3b hold an in-process pin for the query; out-of-process reader leases and the GC grace protocol arrive at G4. |
| Bounded staleness / Allowed stale | Serve verified immutable cached state within declared `max_staleness` and bounded auth-cache TTL. Through G3b, periodic root refresh bounds staleness and an in-process pin protects the query; G4 out-of-process readers may use a reader lease and GC grace protocol. Zero-round-trip warm reads and sub-5 ms P99 remain unmeasured targets. |
| Read your writes | Wait until the target dependency closure includes the `WriteToken`; reject unrelated/incompatible tokens and fail fast with `RS_VIEW_QUARANTINED` if a required target view/group is quarantined at `<= assigned_epoch`. |
| Historical / Repeatable snapshot | Pin one exact retained logical cut via a durable metadata pin across arbitrary durations; fail explicitly (`RESNAPSHOT_REQUIRED`) if history expired—never silently fall back to newer data. |
| Strict immediate revocation (G4 opt-in) | Perform synchronous post-read authorization validation against the authoritative root before returning the result, paying its documented remote-read latency. |

Freshness has separate dimensions: source-observation lag, durable-ingestion lag, and published-result lag. An idle source can show no pending durable changes while its upstream availability is unknown. Report `unknown` rather than zero in that case. Wall-clock `AS OF TIMESTAMP` is a later convenience requiring a declared mapping to recorded domain publication times; it is not part of G2–G3b's exact-token guarantee and does not reconstruct a universal real-world snapshot.

Queries over multiple views in one atomic publication group use one common logical cut. G3b qualifies local independently scheduled result groups consuming common durable input/history; before G3b, cross-view reads require the views to share a publication group. General cross-domain dependencies in G4 import a published versioned relation/change stream into a consuming domain, preserving its source/dependency cut. Dependencies sharing an upstream source must agree on its complete represented prefix and causal/transaction closure. Independent latest values are never silently joined.

Logical MVCC advertises an inclusive earliest retained cut `S`, a durable published exclusive upper `Cp`, and supported cut coverage. A read at `C` includes input epochs `e < C`; G2/G3a promise published interval-boundary cuts from a bounded retained set, while arbitrary-cut coverage within `[S_hot, Cp]` is introduced at G3b. The computed upper is distinct and cannot authorize a read. Certified base/deltas may reconstruct an earlier common cut at G3b even when the views used different physical checkpoint schedules. Before accessing bytes, G2–G3b acquire an in-process pin for the selected cuts/roots, or a durable metadata pin for long-lived tokens/queries/subscriptions; from G4, out-of-process readers also acquire lease protection. On a protection miss, strict latest selection is revalidated/reselected against the committing revision. Gaps and expired history return explicit errors, and domain epoch numbers cannot be compared across unrelated timelines.

Through G3b, short bounded reads run in the owning process and hold an in-process pin; `latest-committed` performs an inline root read, while bounded-staleness reads rely on periodic root refresh and bounded auth-cache TTL. At G4, out-of-process short reads may rely on a valid GC-protection lease (`Δ_read_lease << Δ_gc_grace`) and verify `monotonic_now() < lease_deadline` after reading but before flushing the response; the lease clock must count suspended time (`CLOCK_BOOTTIME` or platform equivalent), and a detected discontinuity is lease loss ([consistency and storage](../design/consistency-and-storage.md#81-monotonic-lease-backed-reader-protection-and-sweeper-observed-gc-grace-windows)). `strict-immediate-revocation` is introduced at G4 for callers requiring zero-window authorization revocation and pays its documented remote-read latency. Long-running queries, repeatable transactions, tokens and subscriptions acquire durable metadata pins.

By default from G2 onward, each independent materialized view owns its own lightweight result publication head; views requiring joint atomic visibility declare an explicit `publication_group`. If a valid, durably accepted transaction triggers a runtime evaluation error (such as `DECIMAL` overflow or division by zero) in one derived view, Rockstream 2 commits a durable **`Active → Quarantined`** transition for that failing view (or its coupled atomic `publication_group`) at its last valid published cut with an explicit `ERROR` diagnostic while unaffected views continue advancing. While quarantined, `latest-committed` and `bounded-staleness` reads continue serving the last valid published cut (`INV-07`), while `WAIT FOR PUBLICATION` and `read-your-writes` targeting `>= failed_epoch` fail fast with **`RS_VIEW_QUARANTINED`** (carrying the underlying error and `published_upper`) rather than blocking until timeout. A quarantined view's retention pin stays bounded by its configured retention quota (`IncrementalRetained → BackfillRequired` on quota expiry) so it cannot indefinitely wedge compaction for healthy siblings.

If the planner cannot construct that cut, it waits, requests explicit import/rebuild, or rejects the query. Distinct independent sources have no global external transaction order; the snapshot records each source's represented prefix without claiming a transaction that those systems never coordinated. Domain-local epoch numbers must never be compared to manufacture consistency.

## 5. Subscriptions and external delivery

The proposed `SUBSCRIBE relation` API provides a snapshot followed by committed changes. Its durable logical output is ordered by domain commit/version and contains row multiplicities. Network delivery can repeat frames. Consumers apply complete commits transactionally or deduplicate by the cursor; exactly-once client side effects are not implied by a reliable server log.

At subscription creation, the catalog chooses and pins version V, registers a retention lease covering V and the following output log, then returns the snapshot and start cursor atomically with respect to that registration. Snapshot streaming ends before changes strictly after V are emitted. Concurrent publication cannot create a gap because the tail position was registered before snapshot consumption. If snapshot transfer is interrupted, the protocol resumes a qualified snapshot page or restarts the same pinned snapshot; it never switches silently to a newer baseline.

```text
SnapshotBegin(snapshot_token, schema_version)
SnapshotRows(page_id, weighted_rows) ...
SnapshotEnd(start_cursor)
CommitBegin(version, source_cut)
DeltaRows(frame_id, weighted_rows) ...
CommitEnd(resume_cursor)
Progress(published_upper, source_status)
```

The initial resumable cursor is at a complete commit boundary and contains tenant/database incarnation, subscription/relation generation, schema version, output-log position, and integrity protection. A client acknowledges only after durable application of `CommitEnd`. Partial commits can be replayed from the prior boundary; they are not exposed as a complete snapshot. Frame IDs support retry detection. Wire order inside a commit is not SQL sort order unless the subscription explicitly contracts for ordered output.

The server enforces byte, age, and lag limits. Slow consumers get a bounded durable backlog and a lease renewal policy; they cannot retain all history indefinitely. Expiration returns `RS_CURSOR_EXPIRED` with the earliest resumable position and the need for a new snapshot. It never drops changes and continues from a newer cursor. Schema changes that preserve the subscribed contract continue under a versioned envelope; incompatible changes terminate at a clean boundary with a structured error.

A Kafka sink reads this committed outbox and has its own durable delivery cursor. Destination transactions, producer fencing, and destination-visible recovery markers must reconcile the crash between external commit and local acknowledgement. A marker/deduplication design must be qualified before advertising exactly-once effects; Kafka transactions alone do not make a local outbox acknowledgement atomic with the broker. Generic HTTP/webhook sinks default to at-least-once delivery with stable idempotency keys. Unsupported destination behavior is documented as such.

## 6. Lifecycle, control APIs, and diagnostics

Objects follow a durable lifecycle: `CREATING → BACKFILLING → CATCHING_UP → ACTIVE`, with explicit `PAUSED`, `FAILED`, `REPLACING`, and `DROPPING` transitions. Each operation persists its chosen starting cut, target generation, progress, resource reservation, and error state. After a restart, workers resume the recorded operation instead of guessing from object names.

View creation does not expose a partially populated result. Replacement keeps the old version available while a new generation builds and catches up, then atomically switches at a shared complete cut. DROP first prevents new references and cancels/drains dependents according to an explicit RESTRICT/CASCADE policy; storage deletion waits for snapshot, consumer, backup, and graph references. Compatible schema additions receive stable new field IDs; type/equality/key changes require a generation change and potentially a rebuild. No automatic reinterpretation of old bytes is allowed.

The versioned control API contains operations for catalog inspection, idempotent mutation, operation status/cancellation, snapshot acquisition/release, publication waiting, lease renewal, source pause/resume, and administrative recovery. Read-only query traffic and administrative mutation have separate authorization scopes. PostgreSQL wire and future Arrow Flight SQL adapters call the same service contracts; they cannot bypass capability checks or publication rules.

System relations should include `relations`, `domains`, `source_progress`, `view_progress`, `arrangements`, `retention_pins`, `operations`, `leases`, `query_costs`, `delivery_cursors` and `deployment_lifecycle`. Each reports actual versus target state and units, including computed versus published uppers, `publication_group`, `quarantine_status`, `failed_epoch`, `replay_state` (`IncrementalRetained` vs. `BackfillRequired`), supported logical history, consumer cursors, sleep eligibility/blockers, activation status and cold-start/catch-up cost. `EXPLAIN INCREMENTAL` shows maintained state, sharing, expected fanout, resource bounds, semantics, and uncertainty. Proposed `SHOW FRESHNESS FOR view` identifies source, queue, compute, exchange, persistence, publication, and delivery contributions; it does not sum overlapping intervals as if they were sequential.

### Optimizer decisions and `EXPLAIN INCREMENTAL`

P3.7 diagnostics expose the selected strategy's versioned contract, satisfied or missing semantic conditions, considered alternatives, and resource bounds. Distinguish enforced keys from observed cardinality/uniqueness statistics. Explain output fanout separately from intermediate work, retained-state, and remote-request amplification, with units and measured/estimated provenance. A rejected shape names the missing condition or resource bound and any qualified fallback; it does not silently approximate the query. P3.8 exposes only its qualified join-aggregate factorization shapes.

The optional multi-term monetary materialization advisor and automated plan replacement are **G5 (`P5.6`)** capabilities built on real production telemetry; inspection is always read-only and explicit application revalidates current catalog generation, constraints, and peak coexistence capacity before cutover. See [semantics and compiler](../design/semantics-and-compiler.md#6-resource-aware-placement-diagnostics-and-g5-cost-model-optimization).

### Suspension and user-visible availability

Single-process cloud operation needs only the binary and a qualified object store. Full suspension is permitted only after durable input, metadata, history, source/timer and delivery obligations are accounted for. Stopping serving alone and stopping every Rockstream process are different lifecycle states. An idle deployment still incurs storage cost, and a first request after activation may wait for recovery and catch-up within its deadline.

A completely stopped binary has no listening endpoint. Manual restart or a configured optional platform/router/event/schedule supplies activation. Continuous CDC or tight freshness may require ingestion to remain active; a source-retention gap requires visible rebootstrap, not silent catch-up. The control API reports blockers and the durable lifecycle operation before stopping. No Kubernetes, external catalog or coordinator is required. Exact commands are deferred until the lifecycle is qualified.

| Application error | Typical SQLSTATE mapping | Client action |
| --- | --- | --- |
| `RS_UNSUPPORTED_CAPABILITY` | `0A000` | Change query or explicitly select a qualified feature. |
| `RS_NUMERIC_OVERFLOW` | `22003` | Correct data/type; an accepted input's blocked publication requires remediation. |
| `RS_VIEW_QUARANTINED` | `55000` | Target view or `publication_group` halted at `published_upper` on `failed_epoch` (carries underlying error and `replay_state`); repair/replace the view before retrying `WAIT FOR PUBLICATION` or RYW. |
| `RS_WRITE_CONFLICT` | `40001` | After definitive rejection, retry a rebuilt transaction with a new sequence; unknown outcomes retain the same identity. |
| `RS_IDEMPOTENCY_EXPIRED` | `55000` | Reconcile the old outcome; explicitly register a new generation before new work. |
| `RS_SNAPSHOT_EXPIRED` / `RS_CURSOR_EXPIRED` | `55000` | Acquire a new snapshot; do not skip missing changes. |
| `RS_LEASE_EXPIRED` (G4) | `55000` | Retryable out-of-process read failure when `monotonic_now() >= lease_deadline` or clock discontinuity occurs before flush; refresh lease or use a durable pin. |
| `RS_INCOMPATIBLE_CUT` | `55000` | Wait or configure an explicit compatible imported dependency. |
| `RS_DEADLINE_EXCEEDED` | `57014` | Inspect operation/transaction status before retrying a mutation. |
| `RS_RESOURCE_LIMIT` | `53000` | Reduce request, change admitted budget, or wait for capacity. |
| `RS_PERMISSION_DENIED` | `42501` | Obtain the required authorization; retries do not change permissions. |

Errors carry operation ID, retryability, whether input was durably accepted, whether a result was published, and a redacted diagnostic. SQLSTATE mappings are proposed and must be exercised through actual clients. Logs must not leak input values or credentials by default.

## 7. Public API qualification checklist

A supported example must run through the shipped server, not just a parser unit test. For each capability, qualification covers typed wire output, duplicate/retraction semantics, empty input, authorization, cancellation, retries, crash/restart, retention expiry, and resource exhaustion. Subscriptions require an exact full transcript across snapshot/tail boundaries and reconnects. CDC requires source transaction and schema-change tests against real supported services. Driver compatibility records exact tested versions without extrapolating to every PostgreSQL client.

The [semantic design](../design/semantics-and-compiler.md) links primary references for PostgreSQL behavior, DataFusion integration, DBSP, and differential execution. The contracts in this document are design decisions to implement and test; they are not claims that upstream dependencies or the existing Rockstream already provide these combined guarantees.
