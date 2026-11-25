# RockStyle: engineering constraints for Rockstream

**Status:** Proposed engineering policy; implementation and enforcement begin in G0. This is not a claim that the engine, checks or simulator already exist.

Inspired by [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md), adapted to Rust, incremental SQL, Arrow and object-backed state. The goal is correct, predictable, maintainable behavior, not a port of TigerBeetle's implementation. Read with [DESIGN.md](DESIGN.md), [AGENTS.md](AGENTS.md), [verification](docs/design/testing-and-verification.md), and [development workflow](docs/design/development-workflow.md). Existing product contracts, qualification gates and review authority remain binding.

## 1. Safety and explicit contracts

- Represent distinct protocol concepts with distinct types (e.g. domain epoch, source position, metadata revision, generation, attempt, run incarnation and byte count). Validate construction and conversions; do not interchange them as raw integers. Make interval endpoints, units and rounding explicit. Check arithmetic, conversions and size calculations at the boundary; implement the declared SQL numeric semantics rather than silently wrapping or saturating.
- Prefer explicit, exhaustive state transitions, small cohesive functions and a single owner of mutable operator state. Separate deciding a transition from executing I/O and selecting its durable result. Do not bury authorization, completeness, protection or fencing decisions in generic callbacks or implicit control flow.
- Turn invariants into executable checks at their owning boundaries. Use types and validated constructors where possible, then release-enabled checks (including `assert!` for genuinely impossible internal conditions) for remaining internal invariants. `debug_assert!` alone is insufficient for a safety-critical check. Check preconditions and postconditions where they constrain different risks. Link high-risk checks to an invariant ID and negative control; assertion counts are not a quality target.
- Treat invalid SQL, malformed input, unsupported capabilities, exhausted budgets, old messages, lost responses, corruption and other expected external faults as explicit errors or protocol outcomes, not assertion panics. An internal invariant failure prevents acknowledgement/publication of affected work. Stop or quarantine the affected domain only if isolation is established; otherwise terminate the process safely and recover from authoritative state. Never catch a panic and continue with potentially inconsistent mutable state, or assume unwinding itself establishes safety. Preserve the last correct publication and accepted-input obligations.
- Validate integrity **and identity** of data at trust boundaries: expected immutable reference, format, semantic/schema version, attempt/parent and coverage as applicable. A matching payload checksum alone cannot prove that a correctly encoded but wrong object belongs to the requested snapshot.

## 2. Bounded work and predictable performance

- Every queue, batch, retry episode, outstanding I/O set, allocation path, parser and speculative operation has a named bound and an exhaustion action. Bounds cover bytes and work, not just item counts. A durable obligation may require repeated recovery episodes; bound each episode and scheduling/backoff without silently abandoning accepted work. Reserve control/cancellation/recovery capacity separately.
- Give each operator a resource contract covering resident and temporary bytes, shared-buffer attribution, fanout/chunking, in-flight tasks and I/O, spill, cancellation and overload. Reserve before growth. Reuse buffers and scratch space where measurement justifies it, including Arrow buffers and message envelopes. Avoid hidden unbounded clones, allocations and work on hot paths; account for dependency allocations and process-level headroom. Dynamic allocation is permitted within the qualified resource envelope; startup-only allocation is not required.
- Prefer batched admission, vectorized computation, batched arrangement probes/writes, exchange, checkpoint preparation and metadata operations where fixed costs can be amortized. Physical chunking never changes logical transactions, exact cuts, order obligations or pin protection. Bound batch bytes, count, work and delay; preserve fairness and a timely control path. Measure tails, request/write amplification, allocation and resource debt on the complete path.
- Design for logical determinism: valid scheduling, batching, worker placement, sharing and compaction choices preserve the same observable results and guarantees at the same logical cut. Do not require identical physical files or impose a new global execution order merely to ease testing.

## 3. Simplicity and dependencies

- Maintain one production behavior for a contract, not a separate simulator implementation. Keep nondeterminism at narrow, injectable boundaries; do not invent a generic platform framework. Keep independent oracles and models separate from the implementation.
- A new abstraction, dependency, configuration knob or compatibility path must justify its verification and maintenance cost against a simpler alternative. Prefer Rust's ordinary types, ownership and standard tooling; use mature dependencies where qualified. Keep unsafe code exceptional, small, documented and independently reviewed; prefer safe Rust and enforce the approved dependency direction.
- Use names that express domain meaning and units, direct control flow, and comments that explain contract and failure reasoning. Remove obsolete experiments and dead paths. Do not use arbitrary function-size, assertion-count, dependency-count or allocation-count quotas as substitutes for reasoning and evidence.
- Keep changes small and independently reviewable. Do not broaden SQL support, add a production execution path or alter durable formats without the relevant contract, tests and approval. Prefer unsupported or explicitly scoped behavior to an incorrect generalization.

## 4. Verification and enforcement

| Rule | Initial enforcement/evidence | Owner work |
| --- | --- | --- |
| Type, arithmetic and transition boundaries | Compile-time types and exhaustive matches where applicable; property tests and negative transition cases; targeted review of unchecked conversions and panics | P0.1, P0.4, G1/G2 |
| Release-enabled safety checks | Ledger maps invariant to enforcement point, failure action, independent evidence and negative control; test affected checks under release semantics | P0.9 with contract owners |
| Bounds and batching | Admission/overload tests, explicit operator budgets, high-water/resource counters and comparable full-path measurements | P0.2, P0.3, P0.4, P0.8 |
| Deterministic production-path testing | Versioned seed replay, safety/liveness/swarm modes, exact independent oracle, varied physical executions, real-backend conformance | P0.1, P0.3, P0.9 |
| Dependency and code hygiene | Pinned toolchain and lockfile, formatting/lint, executable dependency rules and negative controls, risk-based independent review | P0.9a/P0.9 |

P0.9a establishes the smallest practical lint and dependency baseline in the real prototype workspace; do not build empty crates, custom lint frameworks or placeholder CI to simulate enforcement. Add checks at the point where actual code makes them meaningful. Document exceptions with scope, reason, owner, expiry/review trigger and evidence that the owning safety contract remains satisfied. Unimplemented enforcement is an explicit gap, not a passing check. Never waive a critical safety invariant to meet a style or delivery target.
