# G0.1 preliminary evidence

**Verdict: inconclusive.** The implementation and bounded checks below are
reviewable, but independent human approval and validation on the eventual
integration revision are still pending. This record does not unlock G1, mark
G0 complete, or change branch protection. Apply the acceptance criteria in
[qualification](../../docs/planning/qualification.md#g0-feasibility-decisions).

## Source and CI identity

The observed implementation candidate was PR #17 head
`c258891f79182ab471defa7c31c8267dcaf39206`, against base
`88349ac0e03be338a898b014881a0853b8214598`. GitHub PR CI checked out the
synthetic merge commit `2d442d2a451c27b050e5ef6f232a1afff9c90155`, not the
head commit itself. Its merge message identifies those head and base commits.
[CI run 45896494117](https://github.com/trickle-labs/rockstream2/actions/runs/45896494117)
and its [fast job and raw log](https://github.com/trickle-labs/rockstream2/actions/runs/45896494117/job/140171567253)
are the hosted observations. A copy of the `Run fast checks` step is retained as
[ci-run-45896494117-fast.log](ci-run-45896494117-fast.log), SHA-256
`b2c705acb45ff83b34f87326dab825787a7221b6096a23456e201a833dc6e287`.
It was filtered from the hosted log to that one step, with the `PGPASSWORD`
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
synthetic merge cannot qualify a later source revision. Human maintainer review,
required-check configuration and branch protection remain separate actions.
