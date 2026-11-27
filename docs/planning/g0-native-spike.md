# G0.4 native kernel spike: preliminary evidence

**Verdict: inconclusive.** This is a draft experiment, not a foundation-gate
pass, an ADR decision or a supported runtime. G0.1 has merged into main at
`43b084989c166620d1f518ef7ea7c8fbc6c50406`; this candidate integrates that
revision and must be checked again against the actual integration revision.

## Scope of the next decision

[ADR 0013](../adr/0013-minimum-mechanisms-and-independent-qualification.md) separates the G0.4 **native feasibility** verdict from **runtime resource qualification**. A revised feasibility review covers exact `W1-G`/`Q(empty)` results, retractions and cross-terms, acyclic scalar-epoch progress, state ownership across success/failure, and explicit logical admission/queue/output-lifetime bounds. It must name the trusted input-attribution boundary; self-reported Arrow byte counts alone do not bound arbitrary external buffers. This decision change does not turn the recorded inconclusive experiment into a pass. A new independently reviewed verdict and ADR update are required before the foundation track unlocks G1.

The allocation failures and input-attribution counterexample below remain open blockers for any G2 runtime preview. Before qualifying that runtime, account for all resident/temporary/shared/dependency bytes, actual allocation and overload behavior, cancellation/control reserves and process headroom; prove the declared controlled-error or process-isolation/recovery behavior on the complete admitted path. A logical budget or small RSS observation cannot satisfy that gate. G1 semantic work may proceed after its revised foundation prerequisites pass while this work is tracked explicitly; it cannot advertise a safe production allocator or runtime.

Keep the spike disposable and bounded. Carry useful semantic tests and ownership findings into P1.3; do not keep adding production allocator infrastructure merely to close G0.4. A dependency allocation failure by itself does not establish the native scheduler wall or that Timely/Differential would fix it. The fallback decision requires the predeclared semantic, logical-bound or progress/ownership blocker and a bounded comparison.

## Recorded experiment

The prototype applies customer deltas against the old order state, followed by
order deltas against the updated customer state. The latter includes the
simultaneous-input cross-term. It accumulates grouped counts and integer-cent
sums with checked arithmetic and replaces the state only after the entire epoch
is accepted. Its input is two Arrow record batches with signed BIGINT cents,
not a public SQL or Arrow DECIMAL interface. The fixture's DECIMAL(18,2)
range is checked. Output is a weighted Arrow delta batch containing
DECIMAL(38,2) revenue, with signed 128-bit cents; this is not the G1 numeric
matrix.

The fixed per-interval input limit is 128 total rows and 16 KiB reported Arrow
array memory, region strings are at most 32 bytes, and retained customer plus
order state is at most 128 rows. Output is limited to 256 rows. Before cloning
state, the kernel computes a checked upper bound for five output buffers,
rejects a budget overrun and uses fallible reservation for those vectors. It
checks the returned capacities against the scratch-byte cap. Customer, order
and group state use fixed-capacity inline slots and fixed-width UTF-8 regions,
so the transactional clone and state updates do not allocate. Matching-order
scratch is a fixed-size stack array. One synchronous call handles one interval;
there is no internal batch queue. Exceeding a limit rejects the whole interval,
and tests check unchanged state on resource and preimage errors. These are
logical/input bounds, not a measured process resident-memory ceiling: allocator
and Arrow overhead, peak memory, allocation failure and process headroom have
not been qualified. A preliminary release-test RSS measurement is recorded in
[the local memory probe](../../evidence/g0-4/memory-profile.md); it is not a hard
process cap. The caller already owns its Arrow buffers on entry.

`frozen_w1g_all_cuts` compares all five cuts to frozen expected rows and, for
each nonempty epoch, the independent batch evaluator and ungrouped-count
oracle. The separate G0.1 PostgreSQL replay checks the same fixture. Local
fast checks passed against a disposable PostgreSQL instance; exact candidate,
commands and observations are in the PR. This evidence does not establish
performance, general SQL, durable state, cloud operation, or proof that all
resource exhaustion is safe. Independent review of the revised feasibility scope, explicit logical resource contracts and an ADR update remain
required for a feasibility decision; complete runtime resource evidence remains required before G2 preview qualification. The prior small-fixture RSS observations do
not qualify resource admission. Do not infer the predeclared fallback trigger solely from missing
measurements.

### Output lifetime admission experiment

A shared output budget admits at most two outstanding outputs across kernels
that explicitly receive that same budget. Kernel construction requires a budget;
the caller must pass the same budget to every kernel in the intended pool. Each output is charged one slot
before allocation, and its immutable vector owner holds the budget ticket.
The owner is attached to all five Arrow buffers through Arrow's unsafe custom
allocation API. Arrow slices, clones and extracted buffers therefore keep the
owner and ticket alive even after the producing kernel is dropped. COUNT output
uses the same mechanism. A full budget rejects the whole interval without
advancing its state; failed intervals release their tickets. The tests cover
nested and empty slices, a destroyed producer, competing admissions, retry,
forgotten outputs and late validation failure. The output schema is shared.

The sum of each output's five vector capacities is checked against 17,412 bytes
before transfer to Arrow, so two admitted outputs account for at most 34,824
bytes of accepted vector capacities per shared budget. Arrow custom buffers
report their initialized length instead of their owner's capacity; the explicit
pre-transfer capacity check is essential. `try_reserve_exact` may transiently
allocate more than requested before the post-allocation capacity check rejects
it. This is a logical admission budget, not a physical-memory reservation or a
process-wide pool: independently created budgets, consumer copies, shared input,
allocator metadata, wrapper objects, physical allocation failure and process
headroom remain outside it. Caller-provided custom Arrow buffers can also report
less than their true backing capacity and require separate input attribution.
A [local counterexample](../../evidence/g0-4/input-attribution.md) demonstrates
this through the kernel's actual input admission path; it is not a feasibility pass.

### Allocation-failure gap

The input/state cardinality checks reject before retaining a 129th row, and
Arrow input array size is checked before processing. They are not a fallible
allocator or a reservation of process memory. The fixed state slots and clone are inline and bounded by their Rust type sizes;
the `result()` view iterates without allocation. The output budget accounts
for the five owned vector capacities (UTF-8 values and offsets, counts, sums,
and weights), not allocator metadata, stack, Arrow wrappers, shared input, or
process headroom. At the 256-row output limit, the logical Arrow values and offsets
alone are at most 17,412 bytes: 256 rows times 32 region bytes, 8 count bytes,
16 revenue bytes and 8 weight bytes, plus 257 four-byte UTF-8 offsets. This is
not an allocation bound: it excludes alignment, capacity rounding, Arrow and
schema objects, temporary buffers and allocator metadata. The reservation
regression forces a capacity-overflow error; it does
not simulate a physical OOM. The output values and offsets are reserved fallibly before the state clone and
passed to Arrow without copying via the custom allocation API and `StringArray::try_new`.
However, pinned `arrow-buffer` 59.3.2 wraps each `Buffer`'s backing bytes in
`Arc::new`, which itself is infallible; array, schema and `RecordBatch`
construction also allocate. An allocator failure in those paths need not return
the kernel's `Err`; an [isolated injection probe](../../evidence/g0-4/allocation-failure-probe/README.md)
observed process aborts after both cold and warm admissions. An RSS measurement
cannot prove otherwise. A fully fallible
construction strategy or a separately qualified isolation/allocator mechanism
is needed before treating memory exhaustion as a controlled error; neither is
implemented by this spike.

Pinned `arrow-buffer` 59.3.2 also exposes an optional `MemoryPool`, but its
`reserve` operation is explicitly infallible and the pool can be overfilled;
it is accounting, not a fallible hard reservation. Enabling it alone therefore
cannot meet the exhaustion contract.
