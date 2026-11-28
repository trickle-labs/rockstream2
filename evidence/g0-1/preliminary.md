# G0.1 preliminary evidence

**Verdict: inconclusive.** The implementation and bounded checks below are
reviewable. The integration observations below do not establish a reliable
queue-inclusive CI duration under five minutes, and the human review of the
completed milestone is still pending. This record does not
unlock G1, mark G0 complete, or change branch protection. Apply the acceptance criteria in
[qualification](../../docs/planning/qualification.md#g0-feasibility-decisions).

## Main integration observations

The push-triggered [fast check 45962067099](https://github.com/trickle-labs/rockstream2/actions/runs/45962067099)
passed on the actual G0.1 merge commit `43b084989c166620d1f518ef7ea7c8fbc6c50406`.
It completed 4 minutes 2 seconds after run creation, including queueing.

After the G0.4 and G0.3 preparatory merges, the push-triggered
[fast check 45972526560](https://github.com/trickle-labs/rockstream2/actions/runs/45972526560)
passed on actual main commit `54cc84947726e39bedaa0ea2af5a4a24c12222a5`.
The [fast job](https://github.com/trickle-labs/rockstream2/actions/runs/45972526560/job/140416168633)
ran the pinned toolchain and `scripts/check-fast.sh` against PostgreSQL 17.6.
It reported 17 kernel tests, one oracle test and nine Python tests passing,
the dependency and cross-term negative controls detected, and all frozen
PostgreSQL W1-G cuts matching. The job began at 09:25:54 UTC and finished at
09:27:02 UTC on 2026-11-27: 1 minute 8 seconds running and 9 minutes 10 seconds
from run creation at 09:17:52, including an 8-minute 2-second queue. This run
exceeded the queue-inclusive five-minute objective; two observations do not
establish a timing distribution or reliable attainment of that objective.

The job's `Run fast checks` step is retained as
[ci-run-45972526560-fast.log.gz](ci-run-45972526560-fast.log.gz), excluding
lines containing password, token, secret, authorization or credential labels.
It is a redacted step extract, not the full job log. Its compressed SHA-256 is
`47b978fd8dce4ee42bd18a6506fddefb854e22bf3c70908d441215344c96fa32`;
the extracted bytes have SHA-256
`0a4fd1f40615eed92ddb70d2568ef9dd8f669a9bcce02a3721b2d84a5de8aaba`.
This evidence records that specific integration revision, not this subsequent
evidence-only change or any later revision.

## Later hosted timing observations

The following selected successful Fast checks were observed in the public
repository on 2026-11-28. Queue is run creation to job start; execution is job
start to job completion; wall time is run creation to job completion. Times
are UTC and are taken from the linked run and job metadata. Each was attempt 1
with one `fast` job; the PR entries identify PR head revisions, while the main
entry identifies the actual push revision.

The [captured public run and job metadata](public-ci-timing-metadata.tar.gz)
has SHA-256 `dac25c53c7bf701b37e1c61a223426be06a83c8d6306e9f3c2d0e44d3d86b5b9`.
It contains the unmodified responses and exact `gh api` collection commands;
GitHub's later PR metadata may change.

| Run and revision | Created | Job start | Job completion | Queue | Execution | Wall |
| --- | --- | --- | --- | ---: | ---: | ---: |
| [PR #44, `911425fb`](https://github.com/trickle-labs/rockstream2/actions/runs/46141046406/job/140966828752) | 11:41:15 | 11:43:19 | 11:44:22 | 2:04 | 1:03 | 3:07 |
| [PR #44, `f4c7cb59`](https://github.com/trickle-labs/rockstream2/actions/runs/46144267253/job/140976742161) | 12:21:39 | 12:21:42 | 12:22:46 | 0:03 | 1:04 | 1:07 |
| [PR #44, `53456455`](https://github.com/trickle-labs/rockstream2/actions/runs/46146476179/job/140983532035) | 12:48:28 | 13:05:43 | 13:06:52 | 17:15 | 1:09 | 18:24 |
| [main, `9eb000ec`](https://github.com/trickle-labs/rockstream2/actions/runs/46101521940/job/140844813663) | 03:09:56 | 03:13:27 | 03:14:20 | 3:31 | 0:53 | 4:24 |

These selected observations span different revisions and PR/main strata and
are not a predeclared representative sample. The 18:24 result exceeds both
the five-minute median and ten-minute P95 objective thresholds for an
individual observation; it alone does not determine either percentile. The
short job execution times do not remove queue time from the objective. A
repeatable, appropriately classified sample including incomplete and failed
attempts remains necessary; no population timing percentile or G0.1 pass is
claimed here. PR #44 remains an in-progress model change, so its results are
not evidence for the final integration revision.

## Source and CI identity

The observed implementation candidate was PR #17 head
`c258891f79182ab471defa7c31c8267dcaf39206`, against base
`88349ac0e03be338a898b014881a0853b8214598`. GitHub PR CI checked out the
synthetic merge commit `2d442d2a451c27b050e5ef6f232a1afff9c90155`, not the
head commit itself. Its merge message identifies those head and base commits.
[CI run 45896494117](https://github.com/trickle-labs/rockstream2/actions/runs/45896494117)
and its [fast job and raw log](https://github.com/trickle-labs/rockstream2/actions/runs/45896494117/job/140171567253)
are the hosted observations. A copy of the `Run fast checks` step is retained as
[ci-run-45896494117-fast.log.gz](ci-run-45896494117-fast.log.gz). The gzip
SHA-256 is `63628efb96b301eea809e2b5a64d43df00baaab2bef7386206d9fff8c19a2153`;
its uncompressed bytes have SHA-256
`b2c705acb45ff83b34f87326dab825787a7221b6096a23456e201a833dc6e287`.
The extract was filtered from the hosted log to that one step, with the `PGPASSWORD`
environment line removed; it is a redacted extract, not a byte-for-byte copy
of the full job log. GitHub retention of the original is not established.

The job ran `scripts/check-fast.sh` on `ubuntu-latest` with PostgreSQL 17.6,
pinned Rust 1.100.0, and completed successfully. It started at 21:13:05 UTC
and ended at 21:13:53 UTC on 2026-11-26; the run was created at 21:12:21,
so creation-to-job-completion was 92 seconds including queue. The job log
reports one Rust unit test passed; nine Python regression tests passed; the
workspace dependency and cross-term negative controls were detected; the donor
weighted join check and PostgreSQL W1-G complete-cut comparisons passed.
The job log is the raw source for these observations. This one run does not
establish median or P95 CI timing. An earlier successful run at head `7df12ff`
took about 6 minutes 47 seconds including queue.

## Local observation and limits

A clean local clone of `c258891` with a previously empty target directory and
a fresh PostgreSQL cluster ran:

```sh
/usr/bin/time -p env CARGO_TARGET_DIR=/private/tmp/rockstream-g01-cold.0sjOKu/target PGHOST=/private/tmp/rockstream-g01-cold.0sjOKu PGPORT=55433 scripts/check-fast.sh
```

The observed result was exit 0, real 1.89 s, user 1.30 s, system 0.53 s.
The environment was macOS 27.2.1 arm64, Homebrew rustc/cargo 1.100.0,
Python 3.9.6 and PostgreSQL 18.7. The timer excluded clone, `initdb`, server
startup and toolchain installation; system and toolchain caches were not cleared.
The disposable server was stopped and its directory removed. The local log was
not retained: these figures are a reported observation, not an archived raw
artifact or substitute for hosted CI. Other locally observed regressions and
limits are in the [draft PR](https://github.com/trickle-labs/rockstream2/pull/17).

The donor register is seeded, not exhaustive; no donor implementation was
imported or executed for this record. Review dependency closure and notices
before accepting any later port. Changes adding this record and the observation
in ADR 0011 are evidence-only relative to `c258891`; re-run CI on the resulting
PR head and again on the actual integration revision. A green earlier commit or
synthetic merge cannot qualify a later source revision. Human review of the
completed milestone remains separate. For G0, the owner-directed procedure in
the [development workflow](../../docs/design/development-workflow.md#3-risk-based-required-checks)
uses independent review and observed required CI without claiming branch
enforcement. The workflow retains its separate protection requirement or
reviewed maintainer decision for G1 and later.
