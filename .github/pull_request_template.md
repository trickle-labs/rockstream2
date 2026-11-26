## What changes and why

<!-- Lead with the observable difference or design decision and why it matters. A sentence is enough.
If order or ownership is the point, show a small diff sketch or state transition instead of listing files. -->

**Issue and scope:** <!-- Refs #<issue> for a partial step; Closes #<issue> only when all acceptance criteria are met. Name the gate/work ID if applicable. -->

**Contract:** <!-- Link the owning spec or ADR and name affected invariants. For a safety change, say where the invariant is enforced and what happens on failure. -->

## Acceptance evidence

<!-- Pair each affected acceptance case with evidence. For a correctness fix, show the same case failing before and passing after;
identify the independent expected result (e.g. W1-G rows at the affected cut) and include the seed or replay link when relevant.
For design-only work, compare the old and proposed rule and cite the sections checked for consistency. -->

**Verified:** <!-- Exact command or manual check, observed result, and CI run or artifact link if available. -->

**Not verified:** <!-- What was not run and why? Distinguish outstanding required pre-merge checks from background or release qualification. -->

## Merge risk

**Tier and blast radius:** <!-- Low / Medium / High / Architectural or Release. Justify by contract impact: who or what could break?
Call out affected APIs, durable formats, dependencies, security boundaries, resource limits or diagnostics. -->

**Rollback:** <!-- Is reverting the diff enough? If not, explain the migration, recovery or rollout constraint. -->

**Review and follow-up:** <!-- Name any required independent review or maintainer decision. Link affected ADR, capability or invariant ledger updates
and any unfinished work. Merge is not release qualification. -->
