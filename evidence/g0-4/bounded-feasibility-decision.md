# G0.4 native feasibility: bounded decision

**Verdict: pass, within the bounded scope below.** The reviewed `W1-G` spike
supports native feasibility for G0.4 under [ADR 0013 §5](../../docs/adr/0013-minimum-mechanisms-and-independent-qualification.md).
This decision is subject to independent safety review and applicable checks on
its integration revision. It supersedes the earlier inconclusive *feasibility*
verdict for this scoped experiment; that historical report and its physical
resource counterexamples remain valid. The human reviews the completed
milestone separately. This does not qualify G0, G1, G2, a runtime profile or a
release.

## Candidate and observed behavior

The native spike is in merged [PR #41](https://github.com/trickle-labs/rockstream2/pull/41),
merge `207f8a3fc329a2f6896fd428b0adee62e1b01772`. The tested kernel source was
`74c1abfd6afeb7de371dee5df3ca4b730aed16b0`; the later PR evidence commit did
not change that kernel. The PR's actual integration
[fast check](https://github.com/trickle-labs/rockstream2/actions/runs/46077734260)
passed for head `28571b15ca9a406255091245cfa79580938bae25` and base
`3841613514f28ecd5c1f165b838caac16d6c44f7`. The hosted job ran for about
72 seconds; creation to completion took about 11 minutes 49 seconds including
queueing. This is not evidence of a repeatable queue-inclusive five-minute CI
gate.

The [recorded spike evidence](../../docs/planning/g0-native-spike.md#recorded-experiment)
describes the exact commands and artifacts. `frozen_w1g_all_cuts` checks the
weighted Arrow result at each complete cut against frozen expected rows and an
independent Rust batch evaluator, including the empty grouped result and
ungrouped `COUNT`. The separately run PostgreSQL oracle checks the same frozen
cuts. Retractions and simultaneous customer/order updates exercise the join
cross-term. The exact source passed 21 kernel unit tests and a compile-fail
doctest in debug and release, and the PostgreSQL-backed optimized-Python fast
gate. As recorded in [PR #41's description](https://github.com/trickle-labs/rockstream2/pull/41),
a separate agent independently reviewed the candidate and ran
`CARGO_TARGET_DIR=/Users/grove/.p2p/g04-review-target cargo test -p w1g-kernel --locked --offline`;
the 21 unit tests and doctest passed. It did not independently rerun PostgreSQL
or release tests.

The [logical-envelope evidence](../../docs/planning/g0-native-spike.md#logical-feasibility-envelope-for-review)
documents a worst-fanout case checked against an independent batch result, and
records a deliberately omitted customer adjustment that fails that test. A
separate admission archive records a retry-on-conflict mutant that fails the
bounded-contention regression and the failing-before/passing-after malformed
nested-input case. The initial test-build error is retained separately.

## Scope of the decision

For the tested, unsupported synchronous spike and trusted standard-Arrow
producer boundary, one exclusive `&mut Kernel` applies one scalar interval at
a time and rejects an unexpected epoch. The call has no internal input queue.
Fixed-capacity state and a tentative clone limit retained customer/order rows to
128; a failed interval does not commit the tentative state. Input admission
limits the combined batch to 128 rows, a region to 32 UTF-8 bytes, and the
reported Arrow array memory to 16 KiB. The documented maximum logical input
value/offset payload is 6,660 bytes. Fixed loops bound group adjustments to
16,512 per interval, apart from separately bounded map probes and output
comparisons; this is not a wall-clock or scaling guarantee.

An explicitly shared output budget admits at most two outstanding outputs.
Each retains its ticket through Arrow buffer clones, slices and producer
destruction, and each admitted output's five checked vector capacities total at
most 17,412 bytes. A full budget or one unsuccessful strong CAS returns a
bounded backlog or contention error; a caller may retry in a separate bounded
episode. Tests cover budget release, forgotten outputs, input and state limits,
and rollback on late errors. The pool is shared only among kernels supplied
with the same budget. The caller owns and accounts for its input backing;
arbitrary custom Rust `Array` implementations are outside this trusted-code
boundary.

On this evidence, the bounded native feasibility criteria for `W1-G`, scalar
progress, state ownership and logical admission are met. No predeclared native
wall has been demonstrated, so the Timely/Differential comparison is not
triggered. This is a bounded experiment, not a claim about arbitrary workloads
or a supported API.

## Explicitly outstanding

The historical [inconclusive report](../../docs/planning/g0-native-spike.md)
and its counterexamples remain valid. Arrow custom input can retain more
backing than it reports; output capacity can transiently exceed its logical
check; metadata, wrappers, allocator overhead, shared input and process
headroom are not fully attributed. The retained
[allocation-failure probe](allocation-failure-probe/README.md) observed aborts
in dependency/owner allocation paths; it is injected-failure evidence, not an
OS-OOM qualification. P2.5 must independently qualify actual physical
allocation, overload/cancellation, reserves, process containment and exact
fenced recovery before any G2 runtime preview. The fixed-state scan/clone
spike also does not establish P1.3's separately required 1×/10×/100×
fixed-delta work envelope or its scan/copy negative control.
