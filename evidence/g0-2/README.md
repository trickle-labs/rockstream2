# Local probe review evidence

The [archive](local-probe-review.tar.gz) records local Silo and SlateDB probe
checks on 2026-11-28, including source hashes, command output and exit status.
Its SHA-256 is `2cef78d1470ca3d373ae3f1abdfff341f58ca77fb9cae679ce196a0a6a3503ce`.
The `recovery-final-wording` directory records the final run and selected source
hashes; the earlier directories preserve the readiness and control-sensitivity
investigations. The archive does not identify every input to the build.
The before checks are minimized reproductions of the old expressions, not runs
of an old checkout. The final smoke test and three focused Python tests passed.

These are local diagnostic results. They do not qualify a real object-storage
provider, establish cloud costs or latency, or select the G0.2 storage layout.
