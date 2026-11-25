# ADR 0004: versioned arrangements with a qualified SlateDB adapter

**Status:** Proposed interface; SlateDB is a candidate, not an unconditional dependency choice. **Date:** 2026-11-25. **Owners:** storage and engine roles.

## Decision

Expose snapshots, indexed lookup/scan, durable preparation and safe release through an IVM-specific arrangement interface. The interface does not expose publication to operators. Use SlateDB as the first candidate implementation while preserving the option of immutable weighted batches or specialized formats when measured access patterns justify them.

A durable arrangement version identifies the exact parent, interval, attempt, schema/semantic/codec versions, generation and protected backend checkpoint. A published reader opens that exact version. SlateDB transient `DbSnapshot` and durable checkpoint objects have different lifetimes; current documentation explicitly distinguishes them. [Checkpoint documentation](https://slatedb.io/docs/design/checkpoints/) and [write durability](https://slatedb.io/docs/design/writes/) inform this boundary.

Before publication, create non-expiring durable retention associated with a registered staging intent. Do not rely on asynchronously extending a temporary TTL after the result has been acknowledged. For an abandoned prepare, discard its mutable branch and restart from the exact published checkpoint; mutable backend “latest” can contain unpublished writes. Backend-native cloning is an optimization to qualify, not an assumed free operation.

## Alternatives

Building a new general KV/LSM store would duplicate mature engineering. Exposing raw KV writes directly to each operator would leak storage semantics and make atomic version selection fragile. A simple immutable sorted-batch backend is an appropriate correctness fallback and benchmark baseline, but may require indexes/compaction to be economical. A single universal row layout is unlikely to suit both point lookups and large scans; specialize only after measurement.

## Consequences and gate

The conservative exact-parent/checkpoint protocol can generate many manifests and clone/compaction costs. G0 must measure those costs for small batches and thousands of arrangements, including failed attempts. Success requires exact checkpoint reopening after process destruction, reads while compaction runs, stale-writer rejection, abandoned-attempt retry, non-expiring pin survival, and coordinated native/Rockstream GC.

If the backend cannot satisfy the contract or its overhead is unacceptable, keep the interface and change the adapter or physical versioning strategy. Do not reinterpret “durable” or expose staged state to meet the target. Versioned state, input replay floors and current-vs-historical retention rules are defined in [consistency and storage](../design/consistency-and-storage.md).
