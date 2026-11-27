# G0.4 allocator-failure diagnostic

**Verdict: inconclusive.** This isolated diagnostic demonstrates allocation
failure behavior in the experimental kernel. It does not qualify a resource
budget, measure RSS, simulate an operating-system OOM, or justify a runtime
selection. The production workspace and global allocator are unchanged.

On the source tree at `ad0de6123ea6abb0097067a474ed3b3bb99ab944`, with
Rust 1.100.0, Arrow 59.3.2, and Darwin 27.2.0 arm64, the test-only allocator
returned null on one selected allocation after inputs and the kernel were
constructed. The cold case applies a single customer/order interval; the warm
case first completes that interval, then retracts and replaces the order in a
second interval. Successful output contains one and two delta rows respectively.
For each case, the driver runs a fresh process per allocation position and
checks its status; core dumps are disabled. [The raw transcript](result.log)
records every attempt.

| Case | Successful allocation requests | Positions returning `Err("allocation failed")` | Positions aborting with SIGABRT |
| --- | --- | --- | --- |
| Cold | 27 | 0–4 | 5–26 |
| Warm | 16 | 0–4 | 5–15 |

In the warm case, requested sizes total 1,100 bytes: the first five requests
are the output vectors (140 bytes) and the remaining requests total 960 bytes.
These numbers are for this input and build; they are neither peak live bytes
nor a bound on other inputs, allocator overhead, stack, shared input, or RSS.
The injected failures show that successful vector admission alone does not
ensure a controlled error for the subsequent owner and Arrow allocations.
Prewarming schema metadata does not remove all such allocations.

To reproduce on the same platform and pinned toolchain, use a **disposable
checkout** of the exact base commit; the patch adds a diagnostic example and
must not be applied to a production checkout:

```sh
git apply /absolute/path/to/evidence/g0-4/allocation-failure-probe/probe.patch
CARGO_TARGET_DIR=/tmp/g04-alloc-target cargo build -p w1g-kernel --example allocation_failure_probe --locked --offline
python3 /absolute/path/to/evidence/g0-4/allocation-failure-probe/run.py /tmp/g04-alloc-target/debug/examples/allocation_failure_probe
```

The first command assumes the checkout is at the repository root; substitute
the real absolute paths and a fresh target directory. The driver uses Python's
`resource` module and checks POSIX SIGABRT as return code `-6`; other platforms
may report process failures differently. Each child is separate so an abort
does not terminate the driver. This observation does not establish that a
separate-process kernel is a supported execution or recovery architecture.

Artifacts:

- [Diagnostic patch](probe.patch): SHA-256 `98160038a26814e21411ac9756415d403824087e1dc1e720d49b94e5e0db572d`.
- [Driver](run.py): SHA-256 `06f3796ee25ccc997341f69e32461bfb40314317d562d150c01752e332ca6620`.
- [Raw transcript](result.log): SHA-256 `b9f79f9cda1372de8f0af1b930c6551c0259639ee486793bd64ab6fb1b5713bf`.
