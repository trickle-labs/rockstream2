# Proposed SQL and API contracts

**Status:** design proposal, not runnable product documentation. Every capability in this document is **Planned**. No SQL extension or protocol shown here exists in Rockstream 2 yet. **Date:** 2026-11-25. The semantic authority is [semantics and compilation](../design/semantics-and-compiler.md); the release sequence is the [implementation plan](../planning/implementation-plan.md).

## 1. A deliberately explicit compatibility surface

Rockstream 2 exposes a PostgreSQL-compatible connection protocol and a defined relational SQL subset. It is not a complete PostgreSQL server. PostgreSQL extensions, arbitrary OLTP transactions, row locks, triggers, stored procedures, catalogs, wire behavior, and authentication modes need separate capability declarations. Parsing syntax does not establish support.

The capability registry must eventually generate both documentation and executable conformance cases. Each entry contains stable ID, semantic version, status, public entry point, supported combinations, stage, exactness, resource limits, restart behavior, failure behavior, and evidence links. A feature cannot move from Planned to Qualified based only on an internal operator test. A later gate is a target for evaluation, not a guarantee that every row ships together.

| Capability group | First target gate | Planned scope and boundary |
| --- | --- | --- |
| Semantic interpreter and typed algebra | G1 | Weighted bag laws, exact numeric/reference semantics, relational primitives; no product availability claim. |
| PostgreSQL wire, direct writes, reads | G2 | Documented clients, simple/extended query paths, parameter binding, cancellation, typed results, same-domain atomic input transactions. |
| Foundational maintained SQL | G2 | Projection, deterministic expressions, filters, inner equi-joins, `UNION ALL`, grouped COUNT/SUM/AVG and delete-safe MIN/MAX over qualified types. |
| Catalog, shared graph, lifecycle | G3 | View dependencies, online backfill/replacement, shared indexes, historical snapshot tokens, resumable subscriptions. |
| PostgreSQL CDC and Kafka sources | G3 | Qualified snapshot/stream handoff, transaction/cursor identity, recovery, schema handling, and source retention contracts. |
| Distributed execution and serving | G4 | Fenced partitions, consistent publication, independent serving, explicitly imported cross-domain relations. |
| Outer/semi/anti joins, distinct, subqueries | G5 feature gates | NULL-aware semantics, retractions, decorrelation and resource contracts; promote useful subsets independently. |
| Top-K, ordered windows, nested types | G5 feature gates | Deterministic ordering, delete refill, bounded admission; arrays/JSON have explicit equality and serialization rules. |
| Temporal predicates and recursion | G5 feature gates | Explicit clock input, lateness/finalization policy, restricted recursive fragment and qualified deletion semantics. |
| Factorization, higher-order IVM, adaptive plans | G5 feature gates | Shape-specific qualification with semantic baseline and measured benefit. |
| Kafka sink and additional protocols | G3/G4 adapter gates | Qualify external delivery separately; sink availability is not implied by source support. Arrow Flight SQL is a later serving adapter. |
| Elastic maintenance and production release | G6 | Qualified workload envelope, operational/security gates, bounded pause/resume and recovery. G5 research does not all have to finish first. |

The first type profile includes booleans, fixed-width signed integers, declared decimal precision up to 38, binary-collated text, bytes, date, timestamp/timestamptz, and stable identifiers. Every type/operator combination still needs an entry. Unbounded NUMERIC, locale collations, unsupported casts, float aggregation, and arbitrary UDFs fail closed until their specific capability is admitted. Initial direct tables have declared primary keys for deterministic updates/deletes; connector bag sources may carry duplicates with explicit source identities.

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
    maintenance = 'continuous'
)
AS SELECT customer_id, COUNT(*) AS order_count, SUM(amount) AS total
   FROM orders
   GROUP BY customer_id;

CREATE INDEX spend_lookup ON spend_by_customer (customer_id);
```

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

`BEGIN`/`COMMIT` in input mode buffers DML and validates its base key versions at serialized acceptance; conflicting concurrent updates return a retryable conflict. Normalization reads an admission index at the **durable accepted-input head**, including earlier accepted transactions whose views have not published yet. It must not use the latest published materialized snapshot as the source's current row image. The domain sequencer serializes validation and atomic advancement of the input head plus admission state, waiting for prior normalization when necessary. Within a batch, statements see prior statements' normalized effects; the committed record contains the final retractions/insertions and payload digest, not a SQL statement to reevaluate later. The admission index is durable or reconstructible from protected input log/checkpoint data; after loss, rebuild it before accepting additional updates. SELECT inside an input transaction is rejected initially. Read-only repeatable snapshot transactions are a separate mode. This prevents an accidental promise of general PostgreSQL isolation levels or row locking.

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
  domain_versions, published_exclusive_uppers,
  source_cut, relation_generations, semantic_versions,
  retention_lease_id, token_format_version, integrity_tag
}
```

Visibility of a write assigned epoch `e` requires its target domain's published upper to exceed `e`, plus the requested dependency/source-cut checks. Token signatures prevent tampering but do not grant access; current authorization is checked on every operation. Restore creates a new `RunIncarnation` and rejects all prior write, snapshot, and subscription tokens in the initial release, avoiding accidental collision of reused epoch numbers. Any future token remapping requires its own qualified protocol.

Direct clients register a `ClientGeneration` and send `(client_id, signed_client_generation, sequence)` for every mutation. The generation is server-issued and scoped to run incarnation, tenant/database, domain, and operation stream; catalog operations use a separate catalog stream. The sequence is monotonic within a bounded admitted window. Durable admission records preserve generation validity, low/high watermarks, admitted gaps, payload digests, and recent result mappings. A sequence below the replay floor or an expired/unknown generation returns `RS_IDEMPOTENCY_EXPIRED` and requires reconciliation or explicit new registration. It is never interpreted as a new request. Optional arbitrary client labels cannot replace this identity: once a string has been completely forgotten, a server cannot distinguish its retry from a never-used string.

The public SDK/control API exposes registration and status lookup. The pgwire adapter needs documented Rockstream session settings or a transaction extension to supply a registered generation/sequence before COMMIT; G2 must qualify this path. Ordinary PostgreSQL clients that do not opt into that extension retain ordinary unknown-outcome behavior after a lost connection and must reconcile before resubmitting DML. The gateway must not advertise safe blind retry using an identity the client never received.

An unknown outcome retries the same identity and bytes. A definitive conflict or validation rejection has no accepted input effects; rebuilding that transaction after inspecting the rejection uses a new sequence. Reusing the rejected identity must not silently turn the previous rejection into a new accepted operation. This distinction belongs in SDK retry policy and protocol conformance tests.

Exactly-once ingestion depends on that replay-window contract. Connectors instead use qualified native source identities and persistent lineage/high-water positions. Source acknowledgements and Kafka offset commits occur only after Rockstream's durable input acceptance. Detailed result records may be reclaimed only while enough generation/window metadata remains to reject old retries safely.

## 4. Read policies and cross-domain behavior

Every query binds one pinned catalog revision and one compatible snapshot token before execution. A scan cannot move to a newer manifest halfway through a query. Query cancellation and statement timeout release pins; a replica cannot serve a version whose data it cannot verify/read.

| Policy | Contract |
| --- | --- |
| Latest committed | Choose the newest compatible published cut available to that serving path; return the actual token and progress. A replica may lag the authoritative head. |
| Bounded staleness | Require explicit freshness metrics within the bound, waiting until deadline or returning an error; unavailable source-freshness information is not success. |
| Read your writes | Wait until the target dependency closure includes the `WriteToken`; reject unrelated/incompatible tokens. |
| Historical | Read an exact retained `SnapshotToken`; fail if its required history or incarnation is unavailable. |
| Repeatable snapshot | Pin one token for the lifetime of a bounded read-only transaction, with an expiring renewable lease. |

Freshness has separate dimensions: source-observation lag, durable-ingestion lag, and published-result lag. An idle source can show no pending durable changes while its upstream availability is unknown. Report `unknown` rather than zero in that case. Wall-clock `AS OF TIMESTAMP` is a later convenience requiring a declared mapping to recorded domain publication times; it is not part of G3's exact-token guarantee and does not reconstruct a universal real-world snapshot.

Queries over multiple same-domain views use one common published version/cut. Across domains, arbitrary independently latest results are not silently joined. G4's initial supported path imports a published versioned relation/change stream as an explicit input to a consuming domain, preserving its source/dependency cut. The consumer can publish only a compatible input cut: dependencies sharing an upstream source must agree on the represented source prefix, with causal/dependency closure checked. Retained earlier versions may be selected when compatible.

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

System relations should include `relations`, `domains`, `source_progress`, `view_progress`, `arrangements`, `retention_pins`, `operations`, `leases`, `query_costs`, and `delivery_cursors`. Each reports actual versus target state and units. `EXPLAIN INCREMENTAL` shows maintained state, sharing, expected fanout, resource bounds, semantics, and uncertainty. Proposed `SHOW FRESHNESS FOR view` identifies source, queue, compute, exchange, persistence, publication, and delivery contributions; it does not sum overlapping intervals as if they were sequential.

| Application error | Typical SQLSTATE mapping | Client action |
| --- | --- | --- |
| `RS_UNSUPPORTED_CAPABILITY` | `0A000` | Change query or explicitly select a qualified feature. |
| `RS_NUMERIC_OVERFLOW` | `22003` | Correct data/type; an accepted input's blocked publication requires remediation. |
| `RS_WRITE_CONFLICT` | `40001` | After definitive rejection, retry a rebuilt transaction with a new sequence; unknown outcomes retain the same identity. |
| `RS_IDEMPOTENCY_EXPIRED` | `55000` | Reconcile the old outcome; explicitly register a new generation before new work. |
| `RS_SNAPSHOT_EXPIRED` / `RS_CURSOR_EXPIRED` | `55000` | Acquire a new snapshot; do not skip missing changes. |
| `RS_INCOMPATIBLE_CUT` | `55000` | Wait or configure an explicit compatible imported dependency. |
| `RS_DEADLINE_EXCEEDED` | `57014` | Inspect operation/transaction status before retrying a mutation. |
| `RS_RESOURCE_LIMIT` | `53000` | Reduce request, change admitted budget, or wait for capacity. |
| `RS_PERMISSION_DENIED` | `42501` | Obtain the required authorization; retries do not change permissions. |

Errors carry operation ID, retryability, whether input was durably accepted, whether a result was published, and a redacted diagnostic. SQLSTATE mappings are proposed and must be exercised through actual clients. Logs must not leak input values or credentials by default.

## 7. Public API qualification checklist

A supported example must run through the shipped server, not just a parser unit test. For each capability, qualification covers typed wire output, duplicate/retraction semantics, empty input, authorization, cancellation, retries, crash/restart, retention expiry, and resource exhaustion. Subscriptions require an exact full transcript across snapshot/tail boundaries and reconnects. CDC requires source transaction and schema-change tests against real supported services. Driver compatibility records exact tested versions without extrapolating to every PostgreSQL client.

The [semantic design](../design/semantics-and-compiler.md) links primary references for PostgreSQL behavior, DataFusion integration, DBSP, and differential execution. The contracts in this document are design decisions to implement and test; they are not claims that upstream dependencies or the existing Rockstream already provide these combined guarantees.
