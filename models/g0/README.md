# G0.3 protocol model (draft)

`protocol.qnt` is a bounded abstraction of one publication group, two
partitions and one reclaimable object, not the production metadata implementation.
Publication atomically updates both visible partition flags and the root after
checking the root revision, publication parent, owner generation, complete
receipt set, receipt attempts, staged-object durability, staging protection and
object retirement state. It also checks Active, run incarnation, catalog
revision, accepted durable input and proof, and the allocation generation and
base revision of the uploaded metadata page. Ownership reassignment atomically registers the new
owner generation's open namespace. The prepared logical publisher is bound
to the seal and compared with the current authorized publisher. Authenticated
publisher identity is assumed; credential forgery is not modeled. An arbitrary
committer can submit the operation but its identity grants no authority. A
sealed preparation captures the attempt, parent, owner and receipt facts; a separate transition persists the validation
record before publication. Root CAS conflicts can refresh the revision while
retaining the original parent, generation and plan. One refresh is allowed per
retry episode; a further conflict defers the still-protected preparation, and a
new episode can resume it. A root plan change invalidates an old sealed preparation
even if its parent and owner are unchanged; a new plan can be prepared.
Either operation can lose its response; each stored outcome is checked against
an independent ghost of the original commit revision and survives an unrelated
root advance. Pin and retire requests prepare against a revision,
compete through CAS, and must refresh and revalidate after conflict. Collection
also requires abstract object age 2.

The model bounds are two publication operation IDs, two monotonic attempt IDs,
two owner generations, root revisions 0–5 (five advances), participants `{1, 2}` plus
foreign `3`, and one object and pin. Partitions arrive independently. Each
receipt scope encodes `(interval, plan)` as `(1,1)`, `(2,1)` or `(1,2)`; the
prepared interval is fixed at 1 and the plan can advance from 1 to 2. This
covers one mismatch at a time, not all possible values or simultaneous
mismatches; interval 2 under plan 2 is not represented. Sealing snapshots
each scope. Duplicates and delayed receipts from abandoned attempts are modeled.

Each preparation targets object 1; each receipt may refer to object 1 or a
foreign object 2. One abstract durability bit covers object 1 and its recovery
closure. A new preparation begins with pending staging; a separate transition
completes the durable upload. Within one owner generation, successive attempts
reuse the open namespace and its protection without a per-interval metadata
CAS. On reassignment a new owner namespace is registered atomically with the
generation, while any old staged object remains protected until its namespace
is explicitly closed. Closing the namespace updates the metadata revision.
One staged object is represented: after reassignment, a new generation waits
until the old represented object is closed. This does not model simultaneous
different objects in old and new namespaces. Protected staged data
cannot be retired. Publication requires the staged closure to be durable and
protected and installs a root reference in the same transition. These bits do
not implement an upload, inspect bytes, or model a full object graph.

The input segment becomes durable before an acceptance CAS binds its proof and
upper. The sealed request binds that proof and its upper, which publication
checks against accepted input. This single acceptance can cover upper 1 or stop
at upper 0; later input advancement is not modeled. Metadata page upload is a
separate action that records the allocation generation and base root revision.
A root advance requires rebuilding the page, while closure of an allocation
generation makes an unselected old-generation page ineligible. Closure does not
model a tombstone or physical deletion. The selected root page has separate
protection state that survives later preparation. Speculative metadata upload
before seal durability is allowed as a conservative diagnostic overapproximation;
publication still requires a durable seal.

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
Additional controls check namespace acquisition, an unauthorized logical
publisher, an undurable seal and an unsafe retry that rebinds an old sealed preparation to a new owner. The
namespace-publication control combines a faulty close that leaves a stale
protection view with bypassing the final namespace check; it advances the root
and requires a refresh before the invalid publication. With the additional
namespace fence, stale-owner and unprotected-publication mutants also bypass
that independent fence and are compound controls.
Additional controls cover Active, run, catalog, input acceptance, proof and
upper, stale page content, allocation generation and selected root protection.
Invalid input controls bypass both seal-time and publication validation;
the closed-generation control combines stale upload with final guard bypass.
The stale-revision single bypass remains safe within the checked bound because
the page-base guard masks it. A separate compound control bypasses both guards
and witnesses a stale revision and page at the actual commit.
The retired-publication mutant bypasses
retirement, staging-protection and namespace guards: normal protected staging prevents the
retired state from being reached, so this is a compound-fault control. Each
negative control in the control loop must produce a counterexample; the masked
single revision bypass is checked for safety separately.

With Node, Java and Quint 0.34.0 installed, run:

```sh
models/g0/check.sh
```

Quint downloads Apalache 0.62.4 on first use and starts a local server. The
script checks invariants through sixteen steps and checks bounded reachability
witnesses and mutants. Most witnesses and mutants use a thirteen-step bound;
selected witnesses and controls use up to nineteen steps to cover staged-data,
input acceptance, metadata-page and seal durability and
repeated attempts. See the script for the exact bound of each check. The corruption faults change a stored
outcome to the nonzero, later root revision; missing-outcome faults remain
separate. Infrastructure errors do not count as negative-control success.
Apalache is symbolic and does not report an enumerated state count. Separately,
`models/g0/count-states.sh` runs a depth-3 exhaustive TLC exploration using
Quint 0.34.0 and its Apalache 0.62.4 distribution. It appends a depth variable
and wrapper actions to the same model without modifying its transitions. The
recovered current-source run explored 16,490 distinct depth-tagged
configurations (50,117 generated, zero queued); a protocol state reached at
multiple depths is counted multiple times. The [evidence](../../evidence/g0-3/README.md#recovered-publication-boundary-run)
records this run and the source recovery. The earlier 6,260 count and
[projection](../../evidence/g0-3/README.md#depth-3-state-count) apply only to
older models. No projection was computed for this model, and none of these
counts enumerates the sixteen-step symbolic check. `QUINT` may name a
non-default executable.

The abstraction models receipt identities, object references, scopes, atomic
sealing and one combined data/recovery durability fact, not receipt payload
contents, individual recovery dependencies, more than one plan change, a
changing interval, the seal storage protocol, or the full metadata tree and
staging namespace lifecycle in full. Visibility flags do not model output values or multiple versioned partition roots. The
competing publication is an atomic abstract action rather than a second prepared
receipt set. GC models one pin and one retire request, not complete reachability
traversal or physical deletion retries. Operation retention floors and the
complete retry protocol are omitted; reader leases and real-time grace periods
belong to G4.0. Independent safety review must judge these limitations before
this model is cited for G0.3; no implementation, provider or G0 gate is
qualified by these checks.
