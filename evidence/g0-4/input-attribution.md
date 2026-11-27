# G0.4 borrowed Arrow input attribution counterexample

**Verdict: inconclusive.** On current-main source `82b564b26a770dbd2e17b610cf4594f377b57beb`, a local test constructed an Arrow custom UTF-8 buffer exposing one byte while its owner retained a 1,048,576-byte `Vec` capacity. After the test dropped its separate owner handle, the input batch kept that allocation alive. `get_array_memory_size()` reported 721 bytes for both input batches together, below the kernel's 16 KiB reported-input limit, and the current kernel accepted the interval.

This is a counterexample to using the reported input size as an attribution bound for arbitrary external Arrow backing allocations. Acceptance in this diagnostic is an observation of a limitation, **not desired behavior or a contract**. The number 721 is an observation on this build, not a portable bound. This result does not show process RSS, allocation failure, real workload performance, all Arrow buffer kinds, or a G0.4 feasibility pass. Caller-owned inputs, accounting ownership and transfer remain unresolved.

[Probe patch](input-attribution-probe.patch.gz) adds a test only in a disposable checkout; it must not be treated as a normal regression that blesses the observed acceptance. [Raw test output](input-attribution-probe.log.gz) records one passing diagnostic test. Test source was prepared at local-only commit `321e3b6` (tree and source identity are reproducible by applying the patch to the base above). Compressed patch SHA-256: `d19333f039acc9fc64806e8cd346ffd2cc1c392b1d99837d1e9164a05b3181d7`. Compressed log SHA-256: `383168f0f3e31b1d010bfbc9190484e2c21438e1ede72c659dc1a55c2ac146fe`.

The run used Darwin 27.2.0 arm64, Rust 1.100.0, Cargo 1.100.0 and the locked `arrow-buffer` 59.3.2. It exited 0. A second isolated checkout and fresh target reproduced the same observation. To reproduce without changing the working checkout, clone the repository locally into a new temporary directory, check out the base above, decompress and apply the patch from this evidence directory, and run:

```sh
cargo test -p w1g-kernel external_backing_capacity_is_not_input_admission --locked --offline -- --nocapture
```

Use an isolated `CARGO_TARGET_DIR` that has not been used by another checkout. Offline execution requires the locked dependencies already present in the Cargo cache. The test deliberately uses Arrow's unsafe custom-allocation constructor with a retained immutable owner; the pointer covers only the initialized byte and remains valid for the buffer's lifetime.
