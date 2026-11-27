# G0.3 bounded model runs

## Comment-updated model run: e5aea35

On 2026-11-27 the model with SHA-256
`e5aea3554ee0ae5aad6dd4bfb8fbee39d2efcd00fc0c54cc507b6e237ea62926`
and check script with SHA-256
`52390aff8109668bf22b46a8a10c4fbd5230094623b1a9f442f98dc6eee69934`
completed the full eleven-step symbolic check, 25 bounded witnesses and
25 counterexample controls with overall exit 0. The local fast gate also
passed against a disposable PostgreSQL instance with `PYTHONOPTIMIZE=1`.
These results precede integration with the G0.4 main revision. This check is
symbolic; the distinct count for the separate depth-3 TLC run is below.

The [raw archive](e5aea35-raw-run.tar.gz), SHA-256
`0cae5338b654c92fa6401e89efe2a70b0122cc3569e9d4093ebee19424e10fae`,
contains environment and model hashes, 52 invocation statuses and logs, 50
parseable witness/control traces, the suite transcript and the fast-gate log.
The archive does not qualify an implementation or the complete G0 milestone.

## Depth-3 state count

On 2026-11-27, `models/g0/count-states.sh` completed with exit 0. It wraps the
same `protocol.qnt` initial state and transition action with an added depth
variable, starts at 0, and permits transitions only while depth is less than 3.
TLC enumerated **11,746 distinct depth-tagged configurations**, with 40,375
generated and zero remaining on the queue. Its graph depth of 4 includes the
initial configuration. These numbers describe the wrapper, including depth,
and do not count the separate eleven-step Apalache run. A protocol state
reached at different depths contributes multiple configurations. TLC uses
fingerprints, with a nonzero collision risk recorded in the log.

The [full count log](tlc-depth3.log) records Quint 0.34.0, its Apalache 0.62.4
distribution (including TLC), Node v26.13.1 and OpenJDK 21.0.13.1 on Darwin
arm64. The checker used one worker and a 512 MiB heap. The model SHA-256 was
`e5aea3554ee0ae5aad6dd4bfb8fbee39d2efcd00fc0c54cc507b6e237ea62926`;
the count script SHA-256 was
`f0c6e65d466dcfb604c49d511650c57986884123b7c6604bf8313d9df44abaae`.
Run `models/g0/count-states.sh` with those tools installed; as with the other
model checks, the Apalache server needs a local socket. `QUINT` can select the
executable and `QUINT_HOME` the cached distribution.

A separate [diagnostic archive](tlc-depth3-diagnostic.tar.gz) (SHA-256
`5747e941679a8bf4d6f25597caacf3ede9be9ad59977c13acbbfe8f10d188f58`)
contains the exported TLC states and parser from the same model before the
state-count comment was added; its transitions are identical. The parser removed the depth tag
and found 11,741 distinct printed protocol records. That is a syntactic count
of the exported representation, subject to TLC fingerprint collisions; it is
not a proven canonical semantic count or an eleven-step count. The archive's
TLC dump log reports successful model checking; the surrounding `time -l`
exited nonzero when the sandbox denied a later `sysctl` query.

## Staged-durability model: 9bd35ec

**Verdict: inconclusive for the G0.3 gate.** On 2026-11-26, the model and
check script at source commit `9bd35ec0b6cb280b96eea20cdb1eb2c70081224c`
completed the recorded check with exit code 0. Three invariants were checked
through eleven steps; twenty-five witnesses and twenty-five negative controls
were checked through eight steps, except the ten-step compound
retired-publication witness/control and eleven-step duplicate-retry control.
Each mutant produced a counterexample. This is bounded model evidence, not
proof of an implementation or a gate decision. The [model README](../../models/g0/README.md)
records the abstractions and the coupled retired-publication fault; independent
safety review, integration-candidate checks and human milestone review remain open.

[Raw run and traces](9bd35ec-raw-run.tar.gz) (SHA-256
`e2b74b5faef6837c322fb5f0071b596f30a52b663bcd0e85e5a74d0a1fbc3bc0`)
contains the shell transcript, environment and source hashes, overall exit
status, and 52 numbered invocations. Each records arguments, stdout, stderr and
exit status; verifier directories retain Apalache logs and generated bounded
traces. Invocations 1–2 are typecheck and invariants, 3–27 are witnesses and
28–52 are negative controls. All 50 witness/control traces are present. The
archive was created without macOS AppleDouble or provenance metadata; retained
files were compared by SHA-256 with the original capture. Inspect in a fresh
directory:

```sh
mkdir -p /tmp/rockstream-g03-staging-inspect
tar -xzf evidence/g0-3/9bd35ec-raw-run.tar.gz -C /tmp/rockstream-g03-staging-inspect
```

The run used Quint 0.34.0, Apalache 0.62.4, Node v26.13.1 and OpenJDK
21.0.13.1 on Darwin arm64. Apalache is symbolic and does not report an
enumerated state count. The archive includes `quint-record`, the temporary
wrapper that recorded each invocation while preserving its output and exit
code. `suite.log` records the `sh -x models/g0/check.sh` run through that
wrapper. A fresh run can use `models/g0/check.sh` with the same tools, as
explained in the model README. The evidence archive and ADR note were added
after the checked source commit; the later evidence-only commit was not itself
the checked commit. The archive records SHA-256 hashes of the tested model and
script for identity verification.

## Earlier bounded model run: f4424cf

**Verdict: inconclusive for the G0.3 gate.** On 2026-11-26, the model and
check script at source commit `f4424cffbc53d0a9513f5b6720b184d51b1ee541`
completed the recorded check with exit code 0. The model is bounded and has
material limitations listed in [its README](../../models/g0/README.md); this is
not evidence that a storage implementation or an entire gate is correct.
Independent safety review, integration-candidate checks and the human
milestone review remain open.

[Raw run and traces](f4424cf-raw-run.tar.gz) (SHA-256
`785b2b35e243f9db862ecd67dbbff14e697cc4f80c22a54053798551e826ca73`)
contains the environment and source hashes, shell transcript, overall exit
status, and 41 numbered invocations. Each records the arguments, stdout,
stderr and exit status; verifier directories retain Apalache's detailed logs
and generated bounded traces. Invocations 1–2 typecheck and check invariants;
3–20 are the eighteen witnesses; 21–41 are the twenty-one deliberate negative
controls. The controls return nonzero with counterexamples by design. All 39
witness/control traces are present. The original archive SHA-256 was
`7e82a295e1a6c498d02a675c09a25f55d011f0df034d05c15b60be8b88278a45`;
this repack removes only macOS AppleDouble entries and provenance extended
attributes. All retained file contents and substantive metadata were compared
with the original. Inspect without overwriting existing files:

```sh
mkdir -p /tmp/rockstream-g03-inspect
tar -xzf evidence/g0-3/f4424cf-raw-run.tar.gz -C /tmp/rockstream-g03-inspect
```

The run used Quint 0.34.0, Apalache 0.62.4, Node v26.13.1 and OpenJDK
21.0.13.1 on Darwin arm64. Invariants used a ten-step bound; witnesses and
mutants used eight, except the ten-step duplicate-retry mutant. Apalache is a
symbolic bounded checker and this run does not supply an enumerated state count.
The archive includes `quint-record`, the temporary wrapper that recorded each
invocation while preserving its output and exit code. `suite.log` records the
actual `sh -x models/g0/check.sh` run through that wrapper. For a fresh run,
install the same tool versions and execute `models/g0/check.sh` as described in
the model README; Apalache requires a local server and first-use download.

The archive and ADR note were added after the checked source commit. They do
not modify the model or check script, but the later evidence-only commit was not
itself the checked commit. The archive's `environment.txt` records SHA-256
hashes of both tested files so reviewers can verify their identities.
