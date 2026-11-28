# G0.3 bounded model runs

## Current-model depth-3 TLC count

On 2026-11-28, the exact model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`
and `count-states.sh` SHA-256
`f0c6e65d466dcfb604c49d511650c57986884123b7c6604bf8313d9df44abaae`
completed the separate depth-three TLC count. TLC generated **162,607**
configurations and found **37,487 distinct depth-tagged configurations**, with
zero queued and no reported invariant violation. Graph depth 4 includes the
initial configuration. The wrapper can count the same protocol state more than
once at different depths. TLC uses fingerprints: its log reports collision
estimates of 2.5e-10 optimistically and 1.0e-11 based on actual fingerprints.
These values and the count describe this bounded wrapper, not the distinct
untagged state space or the separate sixteen-step symbolic check.

The [raw run and runner](current-model-tlc-raw.tar.gz) have SHA-256
`7d93ae457c4a552d84582345539696323b195952c185727cbd55716deadc0077`.
The archive preserves the exact outer runner and `docker create` arguments,
container inspections, generated wrapper and TLC configuration, per-invocation
arguments and output, status, source snapshots and before/after input manifests,
and the pinned image build record. All 78 archived regular files were compared
with their source contents. The outer command was:

```sh
sh /Users/grove/.p2p/evidence/rockstream-g0-3/container-prep/campaign/run.sh tlc sha256:5190102c30b439f4f4a2dfce6e99e918546614ab0d467d2775f585dd6205cf85
```

The runner used a Linux arm64 Docker container with network disabled, read-only
root and inputs, no published ports, a separate evidence mount, a 4 GiB memory
limit and two CPUs. The temporary filesystem was executable for native solver
libraries and remained `nosuid,nodev`. Pre- and post-run inspections passed;
the external network probe returned `ENETUNREACH`, both input manifests matched,
and the invocation and overall run exited zero without OOM. The wrapper records
each output stream separately before replaying stdout then stderr, so their
cross-stream ordering is not preserved.

The run used Quint 0.34.0, Apalache 0.62.4, Node 26.13.1, Python 3.12.16 and
Temurin OpenJDK 21.0.13+9. TLC reported one worker, a 512 MiB heap and a 64 MiB
off-heap allowance. The Apalache JAR SHA-256 was
`e5223915507b65cc5f1638bd037ede60f8a4fc1644aff46355779f9b05df9262`;
the Quint npm lockfile was
`360799e9945a369203433b09d84ef1ce8371e961e27c6e98b44b6f160b6f11dc`.
The recorded `check.sh` snapshot SHA-256 was
`93bb20790fcb2ad25ee84cb9b87ab72155a6eb46c981efae4e15a51dd21e091d`;
the count did not execute it and does not establish that the full check passes.
This evidence does not qualify G0.3, an implementation, or the G0 milestone.

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

The modeled single metadata page can abstract the initial compact immutable
manifest; it does not select or establish a paged tree. Its allocation-generation
and protection behavior are model assumptions, and a multi-page dependency graph
is outside this evidence. [ADR 0014](../../docs/adr/0014-incremental-delivery-and-earned-complexity.md)
keeps paging evidence-triggered. These clarifications do not change the captured
model, checks or inconclusive verdict.

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

## Root manifest and identity extension: focused evidence

The [focused archive](root-identity-focused.tar.gz) (SHA-256
`56b34088dbf5a20b8da0657fca67270d6f33574a0098649ff8feee743d07d3c1`)
records 14 bounded observations and deliberate fault checks against model
SHA-256 `c457138f53531e133529404fff3f7b56228defc4d1f00f1f07e9673778f8279d`.
It includes source, commands, per-check statuses and outputs, 14 inspected ITF
traces, and the corresponding raw Apalache runs. All 204 archived file hashes
were compared with the evidence directory. The archive's README identifies the
bounds, scope, compound fault and the separately frozen full-suite script.
These focused results do not establish a full-suite or G0.3 gate pass.

The [Active-guard depth evidence](bad-active-depth.tar.gz) (SHA-256
`b111bc5368601add8168ef7ba5dfc82c84f4eb8357b68f653fb9744719c2797f`)
preserves the original 13-step control failure and the separately reviewed
14-step counterexample on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
All 24 archived file hashes match their evidence copies. This supports only the
Active control's revised bound; it does not establish a full-suite pass.

The [plan-revision observation depth evidence](plan-revision-depth.tar.gz)
(SHA-256 `e5d4a03e3ced0c7f9f3de6ed69a0fea96bfa2fcdcbb6c1d3f2ef872fb1dd64e4`)
preserves the original 13-step non-reachability result and the separately
reviewed 14-step witness on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
All 25 archived file hashes match their evidence copies. This supports only the
observation's revised bound; the invariant control and full suite are separate.

The [unprotected-stage observation depth evidence](unprotected-observation-depth.tar.gz)
(SHA-256 `d98f233cbce0fe06cf919d76b781491f2df1f9d470b7f94be2210822aa656c12`)
preserves the original 13-step non-reachability result and the separately
reviewed 14-step witness on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
All 25 archived file hashes match their evidence copies. The observation is a
compound stage-protection and namespace-fence bypass; its revised bound is not
the separate invariant control or a full-suite pass.

The [retired-publication observation depth evidence](retired-observation-depth.tar.gz)
(SHA-256 `f99be73c55bee3c0dfa66d7eb97974094cd731c098de0260d8bac97619ffcf22`)
preserves the 15- and 16-step non-reachability results and independently reviewed
19-step witness on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
All 34 archived file hashes match their evidence copies. The witness bypasses
retirement, stage protection and namespace fences together; it is not the
separate invariant control or a full-suite pass.

The [Active-guard observation depth evidence](active-observation-depth.tar.gz)
(SHA-256 `5949643b0fc8169a740a305fb087fa28c3a86031d2f3ed4e44a268910da3c662`)
preserves the original 13-step observation miss and the independently reviewed
14-step invariant-control trace whose final state satisfies its predicate on
model SHA-256 `4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
All 25 archived file hashes match their evidence copies. The deeper trace was
not a separately executed observation; it is not a full-suite pass.

The [catalog-guard observation depth evidence](catalog-observation-depth.tar.gz)
(SHA-256 `90b6af0213c2809791a9f2d3256b733e7f7b0a3eb40585f0f34d471cfded12e1`)
preserves the original 13-step observation miss and the independently reviewed
14-step invariant-control trace whose final state satisfies its predicate on
model SHA-256 `4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
All 23 archived file hashes match their evidence copies. The deeper trace was
not a separately executed observation, and the original-bound invariant control
was not run; neither result establishes a full-suite pass.

The [run-incarnation observation depth evidence](run-observation-depth.tar.gz)
(SHA-256 `48dd8d8ffc98b5d22c8ea8a010104734211b3dae96a6293840328370d0b01fd5`)
preserves the original 13-step observation miss and the independently reviewed
14-step witness on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
All 25 archived file hashes match their evidence copies. This supports only the
observation's revised bound, not the invariant control or full suite.

The [observation preflight](observation-preflight.tar.gz) (SHA-256
`3c0bb731e63546a4d5d314cb070a6b5ad40c6ae625b3872091eb391d06961b70`)
records all 64 direct observations on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`
and the earlier check script SHA-256
`95b8c9a0cdb6d0db92d553fcedd39c566d0b5901129583ccc9132d6348e818ac`.
Fifty-eight returned status 0; cases 022, 026, 030, 046, 047 and 048 returned
`Observation not reached` and are preserved. Their separately reviewed deeper
witness evidence is linked above; among observations, the working script adjusts
only those six bounds. It also adjusts the separately evidenced Active control
bound from 13 to 14. All 922 archived file hashes match their evidence copies.
This preflight did not run the typecheck, invariant or control-loop checks and
is not a full-suite or gate pass.

The [supplemental 16-step invariant run](supplemental-16-step.tar.gz) (SHA-256
`2e5f9f094417332cfad7ac2b6d2d664a738d63fcafbc9b93a7171efe07f947ef`)
returned status 0 for publication, fencing/outcomes and GC invariants on model
SHA-256 `4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
It records the exact command, limits, tool hashes and raw verifier log; the
cached tool distribution is not included. All 12 archived file hashes match
their evidence copies. This bounded invariant result is not a full-suite or
G0.3 gate pass.

The [exploratory control-bound diagnostics](control-bound-diagnostics.tar.gz)
(SHA-256 `9739f992b216775ba66e65101a7479642054052a70232d9e7501bba36e85af7d`)
record 11 separate counterexamples on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
Ten controls were checked at exploratory depth 14 instead of their original
depth 13; retry revalidation used its original depth 16. The archive records
each actual trace length and identifies compound faults. These diagnostics do
not replace original-bound results, a full checker run or a G0.3 gate pass.

The [catalog-control depth evidence](catalog-control-depth.tar.gz) (SHA-256
`280494e705f7e6dc4f38a9795e86a21820bdf3f18b058395f93039238178e355`)
preserves an observed original-bound 13-step `NoError` failure and a separately
run, independently reviewed 14-step counterexample on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
The surrounding isolated diagnostic was still running when this archive was
created; it does not record that container's final status or inspection.

The retired-publication invariant control's original 15-step invocation was
not run. Its deeper bound of 19 is supported by the separately recorded
[15/16-step observation misses and 19-step mutant witness](retired-observation-depth.tar.gz),
combined with the [normal 16-step invariant result](supplemental-16-step.tar.gz):
the mutant publication transition necessarily satisfies the observation and
violates GC, while the normal transition alone had no GC violation through 16.
This is an inference from those separate checks, not an observed result of the
original invariant control. Neither correction establishes a full-suite pass.

The run-incarnation and unprotected-publication invariant controls' original
13-step invocations were not run. Their bounds of 14 are supported by the
separately recorded [run observation](run-observation-depth.tar.gz) and
[unprotected-stage observation](unprotected-observation-depth.tar.gz): each
direct observation was not reached at 13 and produced a reviewed witness at 14.
Each corresponding faulty publication necessarily satisfies its observation,
and the [normal 16-step invariant result](supplemental-16-step.tar.gz) excludes
an earlier violation from normal transitions within that bound. This is an
inference from separate checks, not an observed result of either original
invariant control. The unprotected-stage control bypasses both stage protection
and the namespace fence. These corrections do not establish a full-suite pass.

The [fencing-control depth evidence](fencing-control-depth.tar.gz) (SHA-256
`9c178ad913f79dbf36c57921764dd17336c2250bb1b3b0e4749a8bf721610a03`)
preserves the observed original-bound 13-step `NoError` failure and a separate
14-step counterexample on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
The faulty publication bypasses both stale-owner and namespace fences. The
surrounding isolated diagnostic was still running when the archive was created;
its final container status and inspection are not included. This correction
does not establish a full-suite pass.

The [namespace-control depth evidence](namespace-control-depth.tar.gz) (SHA-256
`e8903fc522d18b4404ac531815f424bc6646922dcacd75cd8fb3aefe04d8d3fa`)
preserves the observed original-bound 13-step `NoError` failure and a separate
14-step counterexample on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
The compound fault closes the namespace while stage protection remains, then
bypasses the independent namespace guard. The surrounding isolated diagnostic
was still running when the archive was created; its final container status and
inspection are not included. This does not establish a full-suite pass.

The [page-base control depth evidence](page-base-control-depth.tar.gz) (SHA-256
`09482fcdd0c0bb342e497044d9a81a63653de6887d2625c92f623c550240a6b4`)
preserves the original 13-step `NoError` failure and a separate 14-step
counterexample on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
The mutant bypasses the page-base check after a racer advances the head and the
CAS revision is refreshed without rebuilding the protected page. The surrounding
isolated diagnostic was still running when the archive was created; its final
container status and inspection are not included. This is not a full-suite pass.

The [refresh control depth evidence](refresh-control-depth.tar.gz) (SHA-256
`2e0c55ceeef31837e689d803f79f8bdd930fd47992bf43d5dc2965fb68caa204`)
preserves the original 13-step `NoError` failure and a separate 14-step
counterexample on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
The compound fault combines unsafe owner rebinding at refresh with bypass of
the namespace guard. The surrounding isolated diagnostic was still running
when the archive was created; its final container status and inspection are not
included. This is not a full-suite pass.

The [reply control depth evidence](reply-control-depth.tar.gz) (SHA-256
`399646f89b43245095c8c6920e27d7c8a7853a7075ade60bfb03f1a0b1ce7846`)
preserves the original 13-step `NoError` failure and a separate 14-step
counterexample on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
After a later head advance, faulty reconciliation replies with the current
head instead of the retained committed result. The surrounding isolated
diagnostic was still running when the archive was created; its final container
status and inspection are not included. This is not a full-suite pass.

The [parent control depth evidence](parent-control-depth.tar.gz) (SHA-256
`8e9150114f3d3aaa68a7f3c1b1a40a3fa0fa23943aa94fe7564735866f63c389`)
preserves the original 13-step `NoError` failure and a separate 14-step
counterexample on model SHA-256
`4f052d1c73d18bce4331ab64c0706ac0bd7b0d8e50a81f12b252b1cc1c772650`.
The mutant bypasses the parent guard after a competing publication advances
the head and the candidate revision and page are refreshed. The surrounding
isolated diagnostic was still running when the archive was created; its final
container status and inspection are not included. This is not a full-suite pass.
