# G0.4 native kernel spike: preliminary evidence

**Verdict: inconclusive.** This is a draft experiment, not a foundation-gate
pass, an ADR decision or a supported runtime. G0.1 has merged into main at
`43b084989c166620d1f518ef7ea7c8fbc6c50406`; this candidate integrates that
revision and must be checked again against the actual integration revision.

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
state, the kernel computes a checked upper bound for four output scratch vectors,
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
resource exhaustion is safe. Independent review, a qualified resource contract and an ADR update remain
required for a feasibility decision. The prior small-fixture RSS observations do
not qualify resource admission. Do not infer the predeclared fallback trigger solely from missing
measurements.

### Allocation-failure gap

The input/state cardinality checks reject before retaining a 129th row, and
Arrow input array size is checked before processing. They are not a fallible
allocator or a reservation of process memory. The fixed state slots and clone are inline and bounded by their Rust type sizes;
the `result()` convenience method separately constructs an allocated map. The
scratch cap accounts for the four owned vector capacities, not allocator
metadata, stack, Arrow buffers, the convenience map, shared input, or process
headroom. The reservation regression forces a capacity-overflow error; it does
not simulate a physical OOM. Output also constructs `StringArray::from(Vec<&str>)`: in pinned
`arrow-array` 59.3.2, that calls `GenericByteArray::from_iter_values`, which
creates/grows `arrow-buffer` `MutableBuffer`s. In pinned `arrow-buffer` 59.3.2,
`MutableBuffer::with_capacity` calls `std::alloc::alloc` followed by
`handle_alloc_error` if allocation fails. Thus an allocator failure in this
path does not return the kernel's `Err`, and an RSS measurement cannot prove
otherwise. `Arc` and `RecordBatch` construction also allocate. A fallible
construction strategy or a separately qualified isolation/allocator mechanism
is needed before treating memory exhaustion as a controlled error; neither is
implemented by this spike.

Pinned `arrow-buffer` 59.3.2 also exposes an optional `MemoryPool`, but its
`reserve` operation is explicitly infallible and the pool can be overfilled;
it is accounting, not a fallible hard reservation. Enabling it alone therefore
cannot meet the exhaustion contract.
