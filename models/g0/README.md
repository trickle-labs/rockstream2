# G0.3 protocol model (draft)

`protocol.qnt` is a finite abstraction of a single publication group and one
retirable object, not the production metadata implementation. A successful
publication is one atomic root transition that checks its expected parent,
owner generation and complete receipt set. Operation 1 may lose its response;
its durable outcome survives a later root advance. The `advance` action is an
unrelated metadata-root transition, not a publication; publications still pass
the receipt and owner checks. Pin and retirement compete
at the same atomic boundary; collection additionally requires abstract age 2.

The bounds are two operation identities, two ownership generations, at most
three publication effects, expected participants `{1, 2}` plus foreign `3`,
and one object, root reference, pin and age counter. Receipt sets include missing and foreign
participants; `duplicate` and `foreignAttempt` model repeated and
foreign-attempt receipts. The negative controls
independently permit invalid receipts (including a foreign attempt), a stale parent, stale ownership,
reapplication of a completed operation, returning the current head instead of
the stored outcome, and pinning or restoring a root reference to a retired object. These must each produce a
counterexample. Checks explore all paths through eight steps, not an unbounded
proof. Apalache is symbolic and does not report an enumerated state count.

With Node, Java and Quint 0.34.0 installed, run:

```sh
models/g0/check.sh
```

Quint downloads Apalache 0.62.4 on first use and starts a local server. The
check script requires the positive check to pass and each mutant to report an
actual counterexample; infrastructure errors do not count as negative-control
success. `QUINT` may name a non-default Quint executable.

Observed on 2026-11-26: Quint 0.34.0 / Apalache 0.62.4, eight steps; positive
invariants passed and all eight mutants produced counterexamples. A reachability
check observes
operation 1 committed at root 1, an unrelated metadata operation advanced the
root to 2, and operation
1 resolved to its stored outcome at root 1 without another effect. This result
is model-level evidence only. This draft abstracts receipt payloads and attempt identities as a validity flag,
and models a single root-to-object edge rather than a full metadata tree. It
does not model staged allocations, operation
retention floors, or the complete production retry protocol. It does not
model reader leases or real-time grace periods (G4.0). In particular the
fencing and receipt assertions use ghost flags set on a bad commit: independent
review must assess whether the abstraction adequately represents the contract.
No implementation, provider or G0 gate is qualified by these checks.
