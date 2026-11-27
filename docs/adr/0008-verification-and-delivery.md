# ADR 0008: step-by-step vertical delivery with a small, honest verification stack

**Status:** Proposed engineering policy. **Date:** 2026-11-26. **Owners:** technical lead and verification role.

## Decision

Build Rockstream 2 incrementally along one executable vertical path (`W1-G`) through seven clean gates—**G0 → G1 → G2 → G3a → G3b → G4 → G6** (with **G5** advancing independently)—and keep the verification stack small, fast, and honest about what each layer actually proves:

1. **Pure semantics (G0.1, G1+):** Unit tests, `proptest` generated transaction histories, and an **independent batch oracle** (PostgreSQL for the declared compatible subset plus a small independent Rust bag evaluator). Compare exact typed multisets at every published cut, including negative controls (broken cross-term, wrong `Q(empty)`).
2. **Protocol safety (G0.3, extended at G4.0):** One concise **Quint** specification. G0.3 covers publication atomicity/expected-parent CAS, ownership-generation fencing and idempotent operation outcomes, and abstract GC pin/retire reachability, each with a negative control. G4.0 extends it with reader leases, VM pauses, clock discontinuities and sweeper-observed grace-window GC safety. Do not maintain duplicate formal models across multiple tools.
3. **Pure state-machine replay + real-backend crash testing (G2+):** Run Rockstream's own pure transition state machines under deterministic fault schedules, and pair them with **real-process, real-backend crash and chaos tests** against actual SlateDB, object storage, and PostgreSQL/Kafka at the gate that first consumes each behavior. G0.2 checks layout reopen/recovery; G4.0 checks separate-process readers and lease/GC behavior. Because Tokio, SlateDB internals, DataFusion, and cloud HTTP SDKs run outside Rockstream's scheduler, never treat a partial simulator as a substitute for real-dependency crash evidence.
4. **Donor knowledge transfer:** Carry forward Rockstream v1's minimized bug histories, SQL/wire/security test cases, and three-way differential comparison (old engine, new engine, independent oracle) for migrated capabilities ([migration](../planning/migration.md)).
5. **Fast PR CI and calibrated agent autonomy:** Keep routine PR CI under 5 minutes median; run fuzzing, long soaks, and cloud scale campaigns asynchronously. Enforce crate dependency direction and [RockStyle](../../ROCK_STYLE.md) checks in CI. Under the [agent operating model](../design/agent-development.md), agents independently review and integrate milestone changes, including high-risk protocol and recovery work, after their required evidence passes. The human reviews the completed milestone; release authorization remains separate.

## Alternatives and consequences

- **Heavy upfront G0 mega-gate** (building dual runtimes, dual full storage engines, 1,000-view benchmarks, and a FoundationDB-style cluster simulator before G1): Rejected; creates massive pre-code drag and incentivizes checkbox theater rather than real executable slices.
- **Pretending deterministic simulation covers Tokio/SlateDB/S3 internals:** Rejected; focuses deterministic replay where it works (pure state machines) and relies on real-process kill/restart tests for storage and network boundaries.
- **Trade-off accepted:** Specialized tools (e.g., Verus proofs, targeted fuzzers, mutation campaigns) are added only when a concrete verification gap warrants their maintenance cost, rather than mandated from day one.
- **Milestone review trade-off (2026-11-27):** Independently reviewed changes can reach `main` before human review. The complete milestone receives one human review of the integrated candidate; findings may require repair or revert. Required checks and separate release authorization remain in force.

## Evidence

Each gate requires reproducible provenance and independent checks matching the [qualification plan](../planning/qualification.md) and [development workflow](../design/development-workflow.md). Release promotion requires human maintainer sign-off on exact-candidate evidence.
