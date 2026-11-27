# G0.3 bounded model runs

## Recovered publication-boundary run

**Verdict: inconclusive.** The isolated source checkout disappeared during a
later diagnostic; its cause is unknown. The surviving model was recovered on
base `aff8753778e1748bca9f2d986faf8f90a7410927` and independently reviewed.
The original checkout commit `c882148342ea1a705265e377e3c6bbee3ee0dd11`
was not available in an accessible object database. The recovered model was
reconstructed from the preserved original model and recorded revision-mutant
patch; the original check script and documentation were unavailable and were
reconstructed from surviving invocation records and the baseline. Do not treat
the recovered check script or documentation as byte-identical to the lost files.

The corrected model SHA-256 is
`30e4c2c050c0ae317e6acae5d6c1428e0e8fb494012005481f6a1278c3ed5526`;
the executed `models/g0/check.sh` was
`17446f2a05d085276b01a5e27eb81674a88e5cb0f51a9a9817942e74343184af`;
`models/g0/count-states.sh` is
`f0c6e65d466dcfb604c49d511650c57986884123b7c6604bf8313d9df44abaae`.
The source-hashed reconstructed suite finished status 0 with 107 recorded
invocations: 59 status 0 and 48 deliberate negative controls with status 1 and
actual counterexample markers. It checked the three invariants through sixteen
steps; witnesses and controls have their individually recorded bounds, up to
nineteen steps. After the suite, one trailing ASCII space was removed from the
check script's typecheck line; the final script SHA-256 is
`76f34824a980a4e2b3410841a9ac13b8d040de603d1d6b2beb562fb11ec34137`.
The archive retains the executed script and a byte comparison confirming this
is its only change; `sh -n` passed after the edit. The suite was not rerun for
this shell-inert whitespace change. The capture contains 104 invocations with
parseable traces;
typecheck, the invariant run and the separately safe revision-only check have
no trace. The separate depth-three TLC run finished status 0 with 50,117
generated and 16,490 distinct **depth-tagged configurations**, zero queued.
This is not a distinct untagged-state count or an enumeration of the
sixteen-step symbolic run.

The earlier full suite failed at invocation 87 because the single revision
bypass produced no counterexample. The metadata-page base check masked it
within that bound. The reconstructed suite checks that single bypass separately
for safety and includes a compound revision/page-base bypass with its own
counterexample; this is a different test, not a retry of the failed assertion
into green. The failed capture records pre-correction model SHA-256
`e27466cfaea221ba4ed1d7842f2ca10dc543e7afee86a7202e76423ff2ad632a`
and check-script hash
`9497aa16392087abfb488e7fbb216193bb2f829d4b96a8396db2e4ee171b2e69`.
A later focused capture records the corrected model and a different check-script
hash `21494b52237b7f653e817e8e52b71607c426a654b6024bcb3a4dfd5230cb4c5e`.
The two lost check-script contents and their full lineage are not available.
Earlier intentionally interrupted, superseded and environment-failed attempts
are retained separately and are not counted as passes. The original capture's
per-invocation arguments, outputs and statuses remain available.

The restored environment used Quint 0.34.0, Apalache 0.62.4, Node 26.13.1 and
OpenJDK 21.0.13.1 on Darwin arm64. Quint's npm lockfile is a fresh transitive
resolution, not the lost lockfile; `protobufjs@7.6.6` postinstall was not run.
The restored Apalache archive SHA-256 is
`8ac8488422c30d552735bae11b92a2d014d8e02e8608702acc08f9a2d8a9abb2`,
the npm lockfile is
`360799e9945a369203433b09d84ef1ce8371e961e27c6e98b44b6f160b6f11dc`,
and the downloaded Quint rust-evaluator v0.8.0 executable is
`c11e59471b5759354943f675824f03522649fd798a9357677d8a31bf5d5c8cde`.
These identify restored artifacts only; the lost transitive toolchain is not
claimed byte-identical. The exact outer shell commands and full environment for
the completed model and TLC runs were not retained; individual recorded Quint
arguments and the recording wrapper are included. With the same restored tools,
`QUINT=/path/to/quint models/g0/check.sh` and
`QUINT=/path/to/quint models/g0/count-states.sh` reconstruct the checks, but
are not asserted to be the original outer commands.

The recovered source also passed the PostgreSQL-backed fast gate, with
`PYTHONOPTIMIZE=1`, a fresh target and a disposable PostgreSQL 18.7 cluster.
The exact command, source hashes, log and status are in `recovered-fast-gate/`
inside the archive. The first sandboxed initdb failed with `shmget` EPERM before
any tests; the preserved host-executed run passed and cleaned up its temporary
database and target. This was an uncommitted recovered source based on
`aff8753`, not evidence for an untested future integration revision.

The [raw recovery archive](publication-boundaries-recovered-raw.tar.gz) has
SHA-256 `0d91fae1712e680187c752d4072d19c8f145bc16399641214b488c6be96887e7`.
It preserves the failed, interrupted and recovered records, tool lockfile,
source snapshots and appended provenance. Its 3,568 files were compared with
their source contents after excluding macOS AppleDouble metadata. Secret-pattern
scans found no matches, but cannot prove absence of sensitive data.

This result does not qualify G0.3 or the full G0 gate. [The model README](../../models/g0/README.md)
records the explicit bounds and remaining abstraction limits; independent
review of this recovered candidate and its actual integration revision remains
required.

## Namespace, seal and publisher boundaries

On 2026-11-27, the model at integration candidate
`f49b2fc66e17d3a73457adcba54b25ff7e5c32b2` modeled owner-generation namespace
registration, explicit staged-data and seal durability, bounded retry
deferral, and a sealed logical publisher checked against the current root. The
authenticated publisher is assumed; signature forgery is outside this model.
An independent committer may submit the operation and grants no authority.
Allowing an unauthorized logical publisher to prepare in the namespace is an
overapproximation, not a statement about storage access control.

The model SHA-256 was
`3a817ec9db7d0a8bef5091168475fc0f8d676f704f33f20242f38f78712f9592`;
the check script SHA-256 was
`8ac098a5408e8fede8be2c18e233fd617b3793d74a4a807c38379f9ee2c1cae8`.
The complete source-hashed suite exited zero: 83 invocations, including the
thirteen-step invariant check, 38 expected negative-control counterexamples,
and 81 checks with parseable traces. Separate depth-three TLC exploration
reported 21,075 generated, 6,260 distinct depth-tagged configurations and
zero queued; this is not a count of the thirteen-step symbolic state space.
Quint 0.34.0, Apalache 0.62.4, Node 26.13.1 and OpenJDK 21.0.13.1 ran on
Darwin arm64. The [raw evidence](namespace-publisher-raw-run.tar.gz) has
SHA-256 `0d1d61a142365276793d3f29b91d6698ce4853e792f2fe4905e9cda655a906b5`.

One earlier full attempt stopped at invocation 71 with a verifier `error:` and
no counterexample marker; its detailed log stops at Z3 context creation. A local `df` check reported approximately 116 MiB free when investigated;
that observation was not separately archived. After removing
three disposable build targets, an isolated verbose run on identical source
produced the expected duplicate-effect counterexample, and the complete fresh
suite passed with more free space. The original error's cause is **unclassified**;
it is not asserted to be disk exhaustion. The raw archive preserves the failed
run, diagnostic, and complete fresh run separately. Two superseded source runs
were stopped deliberately and are also retained as incomplete, not passes.
The archive excludes macOS AppleDouble provenance metadata; all 2,650
substantive files were compared with their source contents.

The [model README](../../models/g0/README.md) specifies finite bounds and
compound-fault controls. This observation does not qualify G0.3, a storage
implementation or a provider; M2 batching, the full metadata graph, and real
time and physical deletion remain outside the checked model.

## Idempotency controls

On 2026-11-27, bounded experiments against the prior invariant exposed three
gaps: an instrumented operation 2 could apply twice, operation 1 could finish
without a recorded outcome, and operation 1's recorded result could change from
revision 1 to a later revision 2 and be returned, all while the old invariant
held. Each operation now has its own effect, outcome and reply tracking. A ghost
of its original commit revision checks that a recorded outcome is present and
unchanged. Separate mutants cover retries, missing outcomes, nonzero corruption
after a root advance, and incorrect reconciliation. This remains a bounded
abstraction, not qualification of G0.3 or an implementation.

The model with SHA-256
`fb070bea70d95d720b53bc82399afa16e11a0ec51407ad0111b0627a2b48ac3e`
and check script with SHA-256
`ae5159e452707269badfd1432292bcfd555e4c43082c9e557416c761c2b8edc8`
passed eleven-step symbolic invariant checking, 31 witnesses and 33 negative
controls. The [raw run](idempotency-raw-run.tar.gz), SHA-256
`3e298bd9d18407af541523c80ff80f59491971f4a27808bc8142f30b994bf380`,
includes the before-fix mutant models, logs and traces, source hashes,
environment, per-invocation output, statuses and traces, a PostgreSQL-backed
fast gate and the separate depth-3 TLC run. All 66 statuses, 33 counterexamples
and 64 parseable traces were checked. TLC found 11,782 distinct depth-tagged
configurations (40,383 generated, zero queued); this count is not for the
eleven-step symbolic check. No projected count for the revised model was
computed. Quint 0.34.0, Apalache 0.62.4, Node 26.13.1 and OpenJDK 21.0.13.1 ran
on Darwin arm64. The fast gate preceded integration with later main revisions.

## Retirement-before-collection control

On 2026-11-27, a guard-bypass experiment against the prior invariant reached
`deleted && !retired` while `gc` was still true. The invariant now requires
retirement before deletion. An old, unpinned, unreferenced and unretired object
is reachable; bypassing the retirement guard then yields a `gc` counterexample.
This does not change the normal collection transition or qualify G0.3.

The model with SHA-256
`1d3d92320efc13e04986a6636c1bcd3d2168cf9128f3cac6464b8221ea1f4468`
and check script with SHA-256
`04c6be26cd723669f53d36851e175a8b68d98e6266bc3e4be74266000468a7f0`
passed eleven-step symbolic invariant checking, 27 witnesses and 27 negative
controls. The [raw run](retirement-order-raw-run.tar.gz), SHA-256
`8c5a36d8f2109c3149032871ccbf350cb071c0d613dbb709932035b0dedfc57b`,
includes the prior-invariant witness and trace, source hashes, environment,
per-invocation output, statuses and traces, a PostgreSQL-backed fast gate and
the separate depth-3 TLC run. All 56 statuses, 27 counterexamples and 54
parseable traces were checked. TLC found 11,746 distinct depth-tagged
configurations (40,375 generated, zero queued); this count is not for the
eleven-step symbolic check. Quint 0.34.0, Apalache 0.62.4, Node 26.13.1 and
OpenJDK 21.0.13.1 ran on Darwin arm64. The fast gate preceded integration with
later main revisions.

## Minimum-age control

On 2026-11-27, the model with SHA-256
`14a938189a332147d6bbb91783f6727db465b325b4a8c6572b3a2d1bc5a5a3c1`
and check script with SHA-256
`45df9eb432d3a9eb07bcb4ca1b5b0fb09255f9c7a058e57f624052f2e225899b`
passed the eleven-step symbolic invariant check, 26 witnesses and 26
negative controls. The new witness reaches an unpinned, retired object younger
than the minimum; the new mutant bypasses only the age guard and produces a GC
counterexample. These observations do not change the inconclusive G0.3 verdict.

The [raw run](age-guard-raw-run.tar.gz), SHA-256
`30b9a25fd2d3d078b9757a4c14cc648834fec773e54c08324d067c7a2edff696`,
contains per-invocation arguments, output, statuses and traces, source hashes,
environment, a PostgreSQL-backed fast-gate log, and the separately rerun TLC
count. All 54 invocation statuses, 26 control counterexamples and 52 traces
were checked. The separate depth-3 TLC run found 11,746 depth-tagged
configurations, with 40,375 generated and none queued; this count does not
describe the eleven-step symbolic check. The run used Quint 0.34.0, Apalache
0.62.4, Node 26.13.1 and OpenJDK 21.0.13.1 on Darwin arm64. The fast gate
was run before integration with later main revisions.

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
