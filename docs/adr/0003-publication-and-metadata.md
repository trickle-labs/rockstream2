# ADR 0003: immutable data followed by atomic metadata publication

**Status:** Proposed architecture; component selections provisional through G0. **Date:** 2026-11-25. **Owners:** storage/consistency and operations roles.

## Decision

Write durable immutable input, state and output first. Publish one complete domain descriptor through a linearizable conditional metadata transaction. That transaction is the visibility point. No operator, storage backend or subscriber independently advances authority.

The publication compares parent head, run incarnation, catalog/plan revision, domain ownership generation, live publisher lease identity and sealed intent. Complete partition coverage is validated into an immutable bounded-root descriptor; the final CAS is constant-sized. A fixed ownership generation makes omitted/stale participants impossible to overlook through a partial generation check, at the cost of aborting prepares during reassignment.

Input acceptance is separately durable and fenced. Its head, admission/deduplication state and authoritative source snapshot remain GC roots even when there are no views. Lost responses resolve by stable identity. Execution retries allocate a new attempt and restore the exact published parent.

The proposed cloud metadata backend is etcd with three voters across failure zones. The embedded candidate is SQLite WAL with `synchronous=FULL` on a qualified local filesystem. They share API semantics but have different infrastructure failure guarantees. Readers/publishers use authoritative transactions; watch streams and cached reads cannot authorize mutations. [etcd's API guarantees](https://etcd.io/docs/v3.6/learning/api_guarantees/) and [SQLite WAL](https://www.sqlite.org/wal.html) are substrate documentation.

## Alternatives and consequences

Distributed mutable writes with a custom cross-shard consensus protocol would add a large correctness surface. A relational metadata backend is a credible alternative if G0 shows lower operational cost and the required CAS/pin semantics; it must pass the same conformance suite. Object-store conditional writes alone are insufficient unless the adapter implements and proves the complete multi-key catalog/fence/pin contract.

The chosen shape introduces metadata availability into admission/publication and requires backup of metadata plus objects. A metadata outage stops new authority rather than sacrificing safety. Large manifests are immutable objects, not a way to exceed backend transaction limits. The coordinator's completeness validator remains trusted code and needs model/test evidence; a root hash alone proves nothing about missing participants.

## Gate

G0 models publication, admission, ownership and pin/GC races and measures metadata transaction rates and size limits at projected domain counts. G2 crashes before/after every durable/CAS boundary. G4 adds real quorum loss and stale-owner resurrection. See [consistency and storage](../design/consistency-and-storage.md); replacing the substrate must preserve that contract.
