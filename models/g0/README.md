# G0.3 protocol model (draft)

`protocol.qnt` is a bounded abstraction of one publication group, two
partitions and one reclaimable object, not the production metadata implementation.
Publication atomically updates both visible partition flags and the root after
checking the root revision, publication parent, owner generation, complete
receipt set, receipt attempts, staged-object durability, staging protection and
object retirement state. A sealed preparation captures the attempt, parent, owner and receipt facts; commit revalidates them.
Root CAS conflicts can refresh the revision while retaining the original parent,
generation and plan. A root plan change invalidates an old sealed preparation
even if its parent and owner are unchanged; a new plan can be prepared.
Either operation can lose its response; each stored outcome is checked against
an independent ghost of the original commit revision and survives an unrelated
root advance. Pin and retire requests prepare against a revision,
compete through CAS, and must refresh and revalidate after conflict. Collection
also requires abstract object age 2.

The model bounds are two publication operation IDs, two monotonic attempt IDs,
two owner generations, three root revisions, participants `{1, 2}` plus
foreign `3`, and one object and pin. Partitions arrive independently. Each
receipt scope encodes `(interval, plan)` as `(1,1)`, `(2,1)` or `(1,2)`; the
prepared interval is fixed at 1 and the plan can advance from 1 to 2. This
covers one mismatch at a time, not all possible values or simultaneous
mismatches; interval 2 under plan 2 is not represented. Sealing snapshots
each scope. Duplicates and delayed receipts from abandoned attempts are modeled.

Each preparation targets object 1; each receipt may refer to object 1 or a
foreign object 2. One abstract durability bit covers object 1 and its recovery
closure. Preparation observes a pre-allocated namespace and may observe staging as
already durable or still pending; opening the namespace is not modeled as a
CAS transition; a separate transition can complete pending durable staging. The
staging namespace remains protected after abandonment until an explicit close, which updates the metadata revision. Only one namespace is represented;
a new preparation waits until the previous one closes. Protected staged data
cannot be retired. Publication requires the staged closure to be durable and
protected and installs a root reference in the same transition. These bits do
not implement an upload, inspect bytes, or model a full object graph.

Coverage mutants bypass receipt validation at sealing and publication while
retaining the seal-integrity comparison. Witnesses require invalid missing,
duplicate, mixed-attempt, interval-mismatch and plan-mismatch sets to be
published with an intact seal. Another mutant changes one receipt identity after sealing and
commits it by bypassing the seal comparison. The remaining mutants cover partial
visibility, stale CAS or parent, unsafe ownership refresh, repeated effects,
incorrect reconciliation, omitted or corrupted outcomes, repeated effects for
either operation, a stale plan after CAS refresh, nondurable or
unprotected publication, a foreign-object receipt, protected-stage retirement,
pin/retire races, resurrection, and collection before the minimum age. A separate
witness reaches a retired, unpinned object younger than the minimum; the
young-collection mutant bypasses only that age guard. A second witness reaches
an old, unreferenced object without a retirement record; a mutant bypasses the
retirement guard and checks that deletion without retirement violates GC safety.
The retired-publication mutant bypasses both
retirement and staging-protection guards: normal protected staging prevents the
retired state from being reached, so this is a compound-fault control. Each
mutant must produce a counterexample.

With Node, Java and Quint 0.34.0 installed, run:

```sh
models/g0/check.sh
```

Quint downloads Apalache 0.62.4 on first use and starts a local server. The
script checks invariants through eleven steps and checks bounded reachability
witnesses and mutants; each mutant must produce an actual counterexample.
Witnesses and mutants use an eight-step bound, except the ten-step compound
retired-publication and corrupt-outcome witnesses/controls and the eleven-step
duplicate-retry witnesses and controls. The corruption faults change a stored
outcome to the nonzero, later root revision; missing-outcome faults remain
separate. Infrastructure errors do not count as negative-control success.
Apalache is symbolic and does not report an enumerated state count. Separately,
`models/g0/count-states.sh` runs a depth-3 exhaustive TLC exploration using
Quint 0.34.0 and its Apalache 0.62.4 distribution. It appends a depth variable
and wrapper actions to the same model without modifying its transitions. The
recorded run explored 11,782 distinct depth-tagged configurations (40,383
generated, zero queued); a protocol state reached at multiple depths is counted
multiple times. The [evidence](../../evidence/g0-3/README.md#idempotency-controls)
records this run; no projected count was computed for it. The
[earlier projection](../../evidence/g0-3/README.md#depth-3-state-count) applies
only to the older model. Neither count applies to the eleven-step symbolic
check. `QUINT` may name a non-default executable.

The abstraction models receipt identities, object references, scopes, atomic
sealing and one combined data/recovery durability fact, not receipt payload
contents, individual recovery dependencies, more than one plan change, a
changing interval, the seal storage protocol, or the full metadata tree and
staging namespace lifecycle. Visibility flags do not model output values or multiple versioned partition roots. The
competing publication is an atomic abstract action rather than a second prepared
receipt set. GC models one pin and one retire request, not complete reachability
traversal or physical deletion retries. Operation retention floors and the
complete retry protocol are omitted; reader leases and real-time grace periods
belong to G4.0. Independent safety review must judge these limitations before
this model is cited for G0.3; no implementation, provider or G0 gate is
qualified by these checks.
