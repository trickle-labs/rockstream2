# Preliminary local W1-G memory probe

Predeclared before execution: run the release-mode `frozen_w1g_all_cuts` test
once as a standalone process and record `/usr/bin/time -l` peak resident bytes.
A result at or below 64 MiB meets this diagnostic process budget for this tiny
fixture on the named local environment; an error, missing peak or higher value
is a failure of this diagnostic. This process includes the test harness and
allocator, and the input fixture does not approach the configured limits. It
is not a hard production memory cap, a stress test, or qualification evidence.
The logical limits are 128 input and state rows, 32 bytes per region, 16 KiB
input Arrow arrays, and no internal queue. Freeze these before the run.

## Observation

Source candidate `82d6e1119903d3fa59e53507f190b5b833e5306c`; release test
binary SHA-256 `e9c90a3a3bac021926deccf43426e7ee5b928b3aa08ca3265a6cc0f4826d7dd0`.
Environment: macOS 27.2.1, Darwin arm64, Homebrew rustc 1.100.0. Command:

```
/usr/bin/time -l target/release/build/w1g-kernel/4113c47d90c05e0c/out/w1g_kernel-4113c47d90c05e0c --exact tests::frozen_w1g_all_cuts
```

An initial sandboxed run passed the test but `time` could not access the OS
resource counters; it yielded no peak and is inconclusive. The subsequent
host-executed run returned the following observations:

```
running 1 test
 test tests::frozen_w1g_all_cuts ... ok
 test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 3 filtered out
        0.20 real         0.00 user         0.00 sys
             6111232  maximum resident set size
                 560  page reclaims
                   0  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                  11  involuntary context switches
            31809833  instructions retired
            17415450  cycles elapsed
             1737136  peak memory footprint
```

The measured peak is below the diagnostic limit. The missing full-process
admission enforcement, allocation-failure handling, load-boundary memory
measurements, independent checking, and repeat on merged revision remain open.
