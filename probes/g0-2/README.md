# Local Silo conditional-write smoke probe

Run `python3 probes/g0-2/silo_smoke.py` with Python 3, Docker and a curl build
supporting `--aws-sigv4`. Docker must be running and localhost port 19020 must
be free. The script pulls the pinned Silo image if necessary, starts a disposable
container bound to loopback, creates a test bucket, and stops the container in a
`finally` block. Its fixed credentials are only for this temporary local instance;
it has no option to target a remote endpoint. If the process itself is forcibly
killed, remove any remaining `rockstream-g0-2-*` container manually.

The assertions cover create-if-absent, duplicate creation, read-after-write,
matching and stale expected-version writes, and two competing writes from the
same version. The output includes individual local timings for diagnostics, not
latency distributions or performance conclusions. The duplicate and stale
writes must fail, and exactly one competing write must succeed.

This smoke test is **not G0.2 qualification**: it does not exercise a real
provider, ambiguous responses, group commit, SlateDB layouts, fault-injected
recovery, checkpoint registration or overlay caps. It cannot select a storage
layout or establish cloud latency, cost, or durability. Apply the predeclared
qualification rubric and budgets separately for the real-provider run.

Silo image and usage: https://github.com/pgsty/silo
