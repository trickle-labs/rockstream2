# G0.4 native kernel spike: preliminary evidence

**Verdict: inconclusive.** This is a draft experiment, not a foundation-gate
pass, an ADR decision or a supported runtime. It is based on an unmerged G0.1
candidate and must be rebased and retested after G0.1 merges.

The prototype applies customer deltas against the old order state, followed by
order deltas against the updated customer state. The latter includes the
simultaneous-input cross-term. It accumulates grouped counts and integer-cent
sums with checked arithmetic and replaces the state only after the entire epoch
is accepted. Its input is two Arrow record batches with signed BIGINT cents,
not a public SQL or Arrow DECIMAL interface. The fixture's DECIMAL(18,2)
range is checked, and the output sum uses signed 128-bit cents; this is not the
G1 numeric matrix.

The fixed per-interval input limit is 128 total rows and 16 KiB reported Arrow
array memory, region strings are at most 32 bytes, and retained customer plus
order state is at most 128 rows. One synchronous call handles one interval;
there is no internal batch queue. Exceeding a limit rejects the whole interval,
and tests check unchanged state on resource and preimage errors. These are
logical/input bounds, not a measured process resident-memory ceiling: allocator
and Arrow overhead, peak memory, allocation failure and process headroom have
not been qualified. The caller already owns its Arrow buffers on entry.

`frozen_w1g_all_cuts` compares all five cuts to frozen expected rows and, for
each nonempty epoch, the independent batch evaluator and ungrouped-count
oracle. The separate G0.1 PostgreSQL replay checks the same fixture. Local
fast checks passed against a disposable PostgreSQL instance; exact candidate,
commands and observations are in the PR. This evidence does not establish
performance, general SQL, durable state, cloud operation, or proof that all
resource exhaustion is safe. An independent review, resident-memory evidence,
retest against merged G0.1 and an ADR update remain required for a feasibility
decision. Do not infer the predeclared fallback trigger solely from missing
measurements.
