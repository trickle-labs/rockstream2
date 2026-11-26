# G0.3 protocol model (draft)

`protocol.qnt` is a bounded abstraction of one publication group, two
partitions and one reclaimable object, not the production metadata implementation.
A publication atomically updates both visible partition flags and the root
reference, after checking the expected root revision, publication parent,
owner generation, complete receipt set, matching receipt attempt and object
retirement state. Root CAS conflicts can refresh the revision while preserving
the original publication parent and generation for revalidation. Operation 1
may lose its response; its stored outcome survives a later root advance.
`advance` is an unrelated metadata-root transition with its own identity, not a
publication. Pin and retire requests read a root revision before competing
through CAS; after a conflict, each must refresh and revalidate. Root-reference
changes also advance the revision. Collection requires abstract object age 2.

The model bounds are two publication operation IDs, two attempt IDs, two owner
generations, three root revisions, participants `{1, 2}` plus foreign `3`, and
one object and pin. A monotonic allocator issues at most two attempt IDs
without reuse. A single receipt-attempt ID is shared by the abstract set;
duplicates are represented separately. A receive transition may deliver a
receipt for an abandoned attempt, and a witness exercises that interleaving.
Negative controls allow missing/foreign receipts, partial visibility, a stale root or publication parent, a refresh
that adopts a new owner generation, stale ownership, a repeated effect,
a response using the current root, stale pin or retire commits after the
other wins, referencing retired data, and publishing retired data. A separate
mutant reuses an abandoned attempt ID and can publish its stale receipt. Each mutant must produce a counterexample.

With Node, Java and Quint 0.34.0 installed, run:

```sh
models/g0/check.sh
```

Quint downloads Apalache 0.62.4 on first use and starts a local server. The
script checks all paths through eight steps, checks lost-response recovery,
delayed-receipt, bad attempt-reuse, root-refresh, pin-versus-publication
conflict and both pin/retire race witnesses, and requires each mutant to report an actual counterexample;
infrastructure errors do not count as a negative-control success. Apalache is
symbolic and does not report an enumerated state count. `QUINT` may name a
non-default Quint executable.

The abstraction does not model per-participant receipt payloads or arrival,
durable sealing, or the complete metadata tree and staging namespaces. Its
visibility flags do not model output values or multiple versioned partition
roots. The competing publication is an atomic abstract action rather than a
second prepared receipt set. GC models one pin and one retire request, not
complete reachability traversal, staging namespaces or physical deletion
retries. It omits operation retention floors and the complete retry protocol, and reader leases and
real-time grace periods belong to G4.0. Independent safety review must judge
these limitations before this model is cited for G0.3; no implementation,
provider or G0 gate is qualified by these checks.
