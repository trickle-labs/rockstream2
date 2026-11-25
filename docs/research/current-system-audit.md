# Current Rockstream: evidence and redesign implications

**Status:** source review supporting the proposed Rockstream 2 architecture.

**Reviewed:** 2026-11-25.
**Baseline:** [`trickle-labs/rockstream` at `d3f973a84f4263bedd6505039d7f469d4708c478`][A01].

## 1. Scope and evidence standard

The user supplied `grove/rockstream`; repository metadata resolves that address to
`trickle-labs/rockstream`. The reviewed commit identifies the workspace as
**0.72.0**. Its architecture introduction still says 0.71.0, illustrating why this
review pins a commit and distinguishes source, capability contracts, tests, and
design intent. Dependency declarations include Rust 1.95, Arrow 59, DataFusion 55,
and SlateDB 0.16. These are observations about the existing project, not proposed
Rockstream 2 version pins. [A01], [A02]

This is a targeted architectural review, not an exhaustive security audit or a
benchmark run. No existing test suite, proof gate, or cloud qualification was
executed for this document. A named test demonstrates that a check exists; it
does not establish that the reviewed commit passes that check in a particular
deployment. The source's generated capability matrix is the starting point for
compatibility inventory, with its linked runtime and wire-level tests used as
implementation evidence. [A03]

## 2. What is already valuable

| Area | Evidence in the reviewed source | Implication for Rockstream 2 |
| --- | --- | --- |
| Weighted incremental execution | Arrow-backed weighted batches, DBSP-inspired compilation, runtime operator families and batch-oracle infrastructure | Keep weighted relational semantics and reuse adversarial test cases; separate the new semantic IR from deployment and persistence details. |
| Durable shard state | `ShardDb`, SlateDB write batches, durable epoch markers, checkpoints and storage fencing | Preserve the durability lessons; introduce an explicit versioned arrangement contract and one publication authority. |
| Scoped progress | `FrontierMembership` includes scope, generation and shard incarnation; report admission checks all of them | Dependency-scoped progress is an extension and architectural promotion of existing mechanisms, not an invention absent from Rockstream. |
| Shared arrangements | Canonical `ArrangementSpec`, consumer registration, security policy identity and shared traces | Promote arrangement ownership and lifecycle to a central catalog abstraction; prove end-to-end sharing rather than counting type definitions. |
| Factorized maintenance | `FactorizedJoinCore`, join-aggregate and star-join implementations, plus plan classification | Reuse algorithms and adversarial inputs after semantic review; general workload optimization remains a separate engineering task. |
| Verification | FizzBee coordination models, Verus production-kernel contracts, deterministic simulation and oracle suites | Carry forward invariants and failure scenarios; update proofs for the new protocol rather than claiming they transfer automatically. |
| Qualification discipline | Independent scale-qualification contract with negative controls and provenance requirements | Preserve this standard for every speed, cost, scale, or recovery claim. |

The architectural and implementation entry points supporting this inventory are
the workspace map [A02], storage commit path [A04], frontier implementation [A05],
arrangement identity/catalog/trace [A06], [A07], [A08], factorized operators [A09],
verification instructions [A10], [A11], and qualification contract [A12].

### Progress is more nuanced than a single global counter

The architecture's user-facing explanation describes globally committed epochs.
The control implementation also has membership-aware operation. It refuses
reports with the wrong scope, generation, incarnation, or report version;
activating or replacing a shard requires that shard to have caught up with the
published frontier. An empty membership does not publish a completeness claim.
Durable publication has a generation-scoped key. [A02], [A05]

The new design should therefore make the **consistency domain and its dependency
cut** the explicit unit of publication. It should not merely rename the existing
frontier aggregator, nor assume that deleting global coordination removes the
need to close transactions and account for all contributing partitions. Measure
how much unrelated work actually blocks publication before claiming a speedup.

### Sharing is present, but its full product effect still needs evidence

`ArrangementSpec` already captures tenant, security policy, source identity,
schema generation, key expressions/types, projection, predicate, NULL semantics,
decimal scale, collation identity/version, time semantics, merge-law
identity/version, and partitioning. `ArrangementCatalog` makes consumer
registration idempotent and protects retained snapshots and in-flight deltas
during reclamation. `SharedArrangementTrace` stores a base snapshot plus immutable
delta batches and advances compaction according to live consumers. [A06], [A07], [A08]

These are substantial foundations. They do not by themselves prove that every
equivalent SQL expression shares durable state across workers, deployment
generations, or independently progressing domains. The reviewed canonical ID
uses a truncated hash; Rockstream 2 should retain and compare the complete
canonical descriptor on lookup rather than trust a hash collision cannot occur.
Sharing must have tests for physical object reuse, avoided operator work,
security separation, lifecycle races and retention cost, in addition to result
equivalence. [A06]

### Correctness infrastructure should survive the rewrite

The formal directory models epoch commits, frontier aggregation, sink delivery,
self-fencing, migration and control-plane leadership. The Verus instructions
explicitly require the verified production implementation, locked verifier
tooling and failure on missing evidence. The simulator has replaceable clocks,
network and object-store behavior and dedicated coordination/recovery suites.
These assets embody failure knowledge that is expensive to rediscover.
[A10], [A11], [A13]

Port the obligations and counterexamples first. A model of the old commit
protocol does not prove a new manifest-publication protocol. A batch oracle that
shares the new compiler's lowering code cannot independently catch a lowering
bug; retain an independent SQL engine for supported overlap.

## 3. Public capability baseline

The following is an inventory of the existing contract, not a Rockstream 2
promise. `Core`, `Maintain`, and `Experimental` are the current repository's own
classifications. Scope and failure semantics matter as much as the label.
[A03], [A14]

| Capability family | Current documented status | Successor requirement |
| --- | --- | --- |
| PostgreSQL CDC and Kafka sources; Kafka sink | Core | Preserve transaction/offset handling, source acknowledgment boundaries and integration tests. |
| Direct DML, materialized views, exact integer/decimal aggregation | Core | Inventory supported shapes and numeric behavior; preserve exact results and explicit failure behavior. |
| Integer-key equi-joins | Core, including documented inner and outer forms | Do not present outer joins as wholly new; expand coverage only with semantic and deletion tests. |
| Text-key joins and text `MIN`/`MAX` | Maintain, binary UTF-8 semantics | Record collation explicitly in schema, keys, sharing identity and migration checks. |
| Floating-point aggregation | Experimental, approximate | Declare accuracy and reproducibility contracts; never silently compare to exact decimal semantics. |
| Floating-point join keys | Experimental classification; documented fail-closed rejection | A capability row does not imply successful execution. Preserve rejection until qualified support exists. |
| Top-K `ORDER BY ... LIMIT` | Core for documented forms | Preserve tie/NULL behavior, refill after deletion and resource limits. |
| Ranking functions | Maintain | Enumerate exact frame/order support before calling the entire window-function family compatible. |
| Tumbling/sliding windows | Core; separate HOP/session surface is Experimental | Preserve the distinction between supported forms and broader window ambitions. |
| View-on-view DAGs | Core | Acyclic dependent views are not recursive fixed points. |
| Recursive CTEs, LATERAL, broad source-lifecycle DDL | Experimental and not SQL-reachable | New work; use explicit release gates instead of inheriting a misleading implementation claim. |
| Historical/streaming reads | Core subscription forms include epoch-based history | `AS OF TIMESTAMP` is not the existing subscription syntax; design and test timestamp mapping separately. |
| View replacement and lifecycle visibility | Experimental but SQL-reachable | Promote only after atomic cutover, catch-up, failure and dependency tests. |
| Freshness fences and transaction controls | Core, with existing explicit idempotency/source-epoch rules | Provide a documented compatibility mapping; do not reuse old tokens as new tokens. |

The project's focus document deliberately narrowed supported external connectors
to PostgreSQL CDC and Kafka sources and a Kafka sink. Removed lakehouse/webhook
connectors are not hidden migration prerequisites. Internal object storage was
retained; an object-store sink and an object-store state backend are different
interfaces. [A15]

## 4. Reuse, adapt, and replace

| Asset | Proposed treatment | Required acceptance evidence |
| --- | --- | --- |
| SQL/wire transcripts and connector fixtures | Reuse as inputs and expected behavior where the new contract agrees | Run through the new public SQL/API path, including errors and reconnects. |
| Z-set arithmetic and codecs | Review and adapt small modules with provenance | Property tests, overflow tests and canonical encoding compatibility decisions. |
| Specialized factorized operators | Port only after mapping to the new IR semantics | Batch equivalence under duplicates, deletions, NULLs, dimension changes and overflow. |
| Formal models and verified kernels | Reuse obligations and proof techniques; revise models | New protocol-state mapping and proof coverage ledger. |
| Qualification harness | Adapt workload generation, independent checking and evidence schema | Checker detects intentionally dropped/duplicated rows, stale-owner writes and faults that never fired. |
| Catalog, shard runtime and epoch publication | Redesign around immutable versions and explicit domain contracts | Atomicity, fencing, closure, replay, GC and lifecycle model tests. |
| Existing on-disk arrangement/checkpoint layout | Treat as an import/export boundary | A separate versioned migration tool if direct import is later justified. |
| Deployment and operational patterns | Reuse concepts, not unverified manifest copies | Restore drills, identity isolation and load qualification in the intended environment. |

Retain upstream attribution and applicable license notices when porting code or
tests. Do not carry historical compatibility paths into the new kernel merely
because they are available. Conversely, replacing a mature component requires a
measured benefit or an unmet correctness contract, not a desire to minimize the
dependency list.

## 5. How to prove improvement

The existing scale contract defines qualified throughput as sustained input
throughput meeting correctness, freshness, backlog, compaction and durability
requirements. Its ladder covers worker counts up to 64, state beyond worker RAM,
skew, shared arrangements, concurrent serving and failure/recovery. It requires
actual measured provenance and rejects synthetic reference fixtures. [A12]

Reuse that discipline for comparisons. Publish the exact old/new revisions,
feature overlap, cloud configuration, source transcript, state size, output
amplification, retention, error rate, recovery behavior and complete costs. Run
the baseline in its own supported configuration. A simpler API, broader SQL
coverage, faster recovery and lower cost can improve different dimensions; no
single throughput number establishes that Rockstream 2 is better in every one.
The initial review has produced **no measured superiority claim**.

## Source references

All repository links below are pinned to the reviewed commit.

[A01]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/Cargo.toml
[A02]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/ARCHITECTURE.md
[A03]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/docs/capability-matrix.md
[A04]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/src/shard_db.rs
[A05]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-control/src/frontier.rs
[A06]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-types/src/arrangement.rs
[A07]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/src/arrangement_catalog.rs
[A08]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/src/trace.rs
[A09]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-ops/src/factorized.rs
[A10]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/formal/README.md
[A11]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/formal/verus/README.md
[A12]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/benchmarks/scale-qualification/README.md
[A13]: https://github.com/trickle-labs/rockstream/tree/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-sim/src
[A14]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/docs/language-features.md
[A15]: https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/ROCKSTREAM_PROJECT_FOCUS.md
