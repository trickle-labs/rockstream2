# G0.3 protocol model (draft)

`protocol.qnt` is a bounded abstraction of one publication group, two
partitions and one reclaimable object, not the production metadata implementation.
Publication atomically updates both visible partition flags and the root after
checking the root revision, publication parent, owner generation, complete
receipt set, receipt attempts and object retirement state. A sealed preparation
captures the attempt, parent, owner and receipt facts; commit revalidates them.
Root CAS conflicts can refresh the revision while retaining the original parent
and generation. Operation 1 can lose its response; its stored outcome survives
an unrelated root advance. Pin and retire requests prepare against a revision,
compete through CAS, and must refresh and revalidate after conflict. Collection
also requires abstract object age 2.

The model bounds are two publication operation IDs, two monotonic attempt IDs,
two owner generations, three root revisions, participants `{1, 2}` plus
foreign `3`, and one object and pin. Partitions arrive independently. Each
receipt scope encodes `(interval, plan)` as `(1,1)`, `(2,1)` or `(1,2)`; the
prepared interval and plan are fixed at `(1,1)`. This covers one mismatch at a
time, not all possible values or simultaneous mismatches. Sealing snapshots
each scope. Duplicates and delayed receipts from abandoned attempts are modeled.

Coverage mutants bypass receipt validation at sealing and publication while
retaining the seal-integrity comparison. Witnesses require invalid missing,
mixed-attempt, interval-mismatch and plan-mismatch sets to be published with an
intact seal. Another mutant changes one receipt identity after sealing and
commits it by bypassing the seal comparison. The remaining mutants cover partial
visibility, stale CAS or parent, unsafe ownership refresh, repeated effects,
incorrect reconciliation, pin/retire races and resurrection. Each must produce
a counterexample.

With Node, Java and Quint 0.34.0 installed, run:

```sh
models/g0/check.sh
```

Quint downloads Apalache 0.62.4 on first use and starts a local server. The
script checks invariants through ten steps and checks bounded reachability
witnesses and mutants; each mutant must produce an actual counterexample.
Witnesses and mutants use an eight-step bound except the ten-step duplicate
retry mutant. Infrastructure errors do not count as negative-control success.
Apalache is symbolic and does not report an enumerated state count. `QUINT` may
name a non-default Quint executable.

The abstraction models receipt identities, scopes and atomic sealing, not
receipt payload contents, a changing prepared plan/interval, the seal storage
protocol, or the complete metadata tree and staging namespaces. Visibility
flags do not model output values or multiple versioned partition roots. The
competing publication is an atomic abstract action rather than a second prepared
receipt set. GC models one pin and one retire request, not complete reachability
traversal or physical deletion retries. Operation retention floors and the
complete retry protocol are omitted; reader leases and real-time grace periods
belong to G4.0. Independent safety review must judge these limitations before
this model is cited for G0.3; no implementation, provider or G0 gate is
qualified by these checks.
