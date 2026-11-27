#!/bin/sh
set -eu

quint=${QUINT:-quint}
model=$(dirname "$0")/protocol.qnt
"$quint" typecheck "$model"
"$quint" verify "$model" --invariants publication fencing_and_outcomes gc --max-steps 13 --verbosity 0

"$quint" verify "$model" --observation 's.head == 2 and s.outcome1 == 1 and s.metadataDone and s.response1 and s.reply1 == 1 and s.effects1 == 1' --max-steps 10 --verbosity 0

"$quint" verify "$model" --observation 's.head == 2 and s.outcome2 == 1 and s.metadataDone and s.response2 and s.reply2 == 1 and s.effects2 == 1' --max-steps 10 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_retry2_step --observation 's.effects2 == 2 and s.done2' --max-steps 15 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_corrupt_outcome1_step --observation 's.committed1 == 1 and s.head == 2 and s.outcome1 == 2 and s.response1 and s.reply1 == 2' --max-steps 12 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_corrupt_outcome2_step --observation 's.committed2 == 1 and s.head == 2 and s.outcome2 == 2 and s.response2 and s.reply2 == 2' --max-steps 12 --verbosity 0

"$quint" verify "$model" --observation 's.prepared and s.abandonedAttempt == 1 and s.attempt == 2 and s.receipt1Attempt == 1' --max-steps 10 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_reuse_step --observation 's.stalePublished and s.attempt == 1 and s.receipt1Attempt == 1 and s.abandonedAttempt == 1' --max-steps 10 --verbosity 0

"$quint" verify "$model" --observation 's.refreshed and s.metadataDone and s.publications == 1 and s.parent == 0 and s.publicationHead == 1 and s.effects1 == 1' --max-steps 10 --verbosity 0

"$quint" verify "$model" --observation 's.prepared and s.pinned and s.revision < s.head' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.pinned and s.retirePending and s.retireRevision < s.head' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.retired and s.pinPending and s.pinRevision < s.head' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.retired and not(s.pinned) and not(s.root) and not(s.deleted) and s.age < 2' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 'not(s.retired) and not(s.pinned) and not(s.root) and not(s.deleted) and not(s.stageProtected) and s.age >= 2' --max-steps 10 --verbosity 0

"$quint" verify "$model" --observation 's.prepared and s.abandonedAttempt == 1 and s.attempt == 2 and s.receipts == Set(1, 2) and s.receipt1Attempt == 1 and s.receipt2Attempt == 2 and s.receipt1Scope == 1 and s.receipt2Scope == 1' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.receipts == Set(1) and s.receipt1Attempt == s.attempt' --max-steps 10 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_seal_step --observation 's.badSealCommit and s.sealed and s.sealDurable and s.receipt1Id == 3 and s.sealedReceipt1 != 3' --max-steps 10 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_missing_step --observation 's.badPublication and not(s.badSealCommit) and s.receipts == Set(1)' --max-steps 10 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_mixed_step --observation 's.badPublication and not(s.badSealCommit) and s.abandonedAttempt == 1 and s.receipt1Attempt == 1 and s.receipt2Attempt == 2 and s.receipt1Scope == 1 and s.receipt2Scope == 1' --max-steps 10 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_interval_step --observation 's.badPublication and not(s.badSealCommit) and s.receipt1Scope == 2 and s.receipt2Scope == 1' --max-steps 10 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_plan_step --observation 's.badPublication and not(s.badSealCommit) and s.receipt1Scope == 3 and s.receipt2Scope == 1' --max-steps 10 --verbosity 0

"$quint" verify "$model" --observation 's.prepared and s.sealed and s.refreshed and s.preparedPlan == 1 and s.sealedPlan == 1 and s.planRevision == 2 and s.revision == s.head and s.parent == s.publicationHead and s.owner == s.generation' --max-steps 10 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_plan_revision_step --observation 's.badPlanCommit and s.refreshed and s.preparedPlan == 1 and s.sealedPlan == 1 and s.planRevision == 2 and s.publicationHead == s.parent + 1 and s.owner == s.generation' --max-steps 10 --verbosity 0

"$quint" verify "$model" --observation 's.planRevision == 2 and s.preparedPlan == 2 and s.sealedPlan == 2 and s.effects1 == 1 and not(s.prepared)' --max-steps 10 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_duplicate_step --observation 's.badPublication and not(s.badSealCommit) and s.duplicate and s.receipts == Set(1, 2) and s.receipt1Attempt == s.attempt and s.receipt2Attempt == s.attempt and s.receipt1Scope == expectedScope and s.receipt2Scope == expectedScope' --max-steps 10 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_undurable_step --observation 's.badDataCommit and not(s.stageDurable) and s.stageProtected and s.visible1' --max-steps 10 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_unprotected_step --observation 's.badDataCommit and s.stageDurable and s.stageClosed and not(s.stageProtected) and s.visible1' --max-steps 10 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_foreign_object_step --observation 's.badPublication and not(s.badSealCommit) and not(s.badDataCommit) and s.receipt1Object == 2 and s.receipt2Object == 1' --max-steps 10 --verbosity 0

"$quint" verify "$model" --observation 's.stageDurabilityAdvanced and s.publishedDataReady and s.effects1 == 1 and not(s.prepared)' --max-steps 10 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_stage_retire_step --observation 's.badGc and s.retired and not(s.prepared) and s.abandonedAttempt != 0 and s.abandonedAttempt == s.attempt and s.stageProtected and not(s.root) and not(s.pinned)' --max-steps 10 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_publish_retired_step --observation 's.badGc and s.badDataCommit and s.retired and s.visible1 and s.stageDurable and not(s.stageProtected)' --max-steps 12 --verbosity 0

"$quint" verify "$model" --observation 'not(s.prepared) and s.abandonedAttempt != 0 and s.abandonedAttempt == s.attempt and s.stageProtected and not(s.root) and not(s.retired)' --max-steps 10 --verbosity 0

# Owner-generation assignment registers its namespace in the same root update.
"$quint" verify "$model" --observation 's.generation == 1 and s.namespaceGeneration == 1 and s.namespaceOpen' --max-steps 4 --verbosity 0
# A protected owner namespace can serve another attempt without a root update.
"$quint" verify "$model" --observation 's.prepared and s.lastAttempt == 2 and s.stageProtected and s.head == 0 and s.namespaceGeneration == s.generation' --max-steps 6 --verbosity 0
# A sealed preparation may exist before the record is durable.
"$quint" verify "$model" --observation 's.prepared and s.sealed and not(s.sealDurable) and s.stageProtected' --max-steps 7 --verbosity 0
"$quint" verify "$model" --observation 's.effects1 == 1 and s.sealDurable and s.namespaceGeneration == s.generation' --max-steps 10 --verbosity 0
# Exhausting one bounded retry episode defers protected work; the next episode
# can resume without rewriting its prepared owner or parent.
"$quint" verify "$model" --observation 's.retryDeferred and s.retryCount == 1 and s.revision < s.head and s.stageProtected' --max-steps 8 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and not(s.retryDeferred) and s.retryCount == 0 and s.refreshed and s.revision < s.head and s.head == 2' --max-steps 10 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_namespace_publication_step --observation 's.badNamespaceCommit and s.stageProtected and not(s.namespaceOpen) and s.sealDurable and s.refreshed' --max-steps 11 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_undurable_seal_step --observation 's.badSealCommit and s.sealed and not(s.sealDurable) and s.stageProtected' --max-steps 11 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_retry_revalidation_step --observation 's.badFence and s.preparedGeneration == 0 and s.generation == 1 and not(s.retryDeferred)' --max-steps 13 --verbosity 0

# A committer can submit another authenticated publisher's authorized work.
"$quint" verify "$model" --observation 's.effects1 == 1 and s.preparedPublisher == s.authorizedPublisher and s.committedVia != s.authorizedPublisher and not(s.badPublisherCommit)' --max-steps 10 --verbosity 0
# A different publisher may prepare but the root must reject its publication.
"$quint" verify "$model" --observation 's.prepared and s.sealed and s.sealDurable and s.stageDurable and s.preparedPublisher != s.authorizedPublisher and namespaceMatches' --max-steps 9 --verbosity 0
# Bypass only publisher authorization, leaving the other guards intact.
"$quint" verify "$model" --no-invariant --step bad_publisher_step --observation 's.badPublisherCommit and s.visible1 and not(s.badNamespaceCommit) and not(s.badDataCommit) and not(s.badSealCommit) and not(s.badFence) and not(s.badParent) and not(s.badPublication)' --max-steps 10 --verbosity 0

for control in fencing_and_outcomes:bad_publisher_step publication:bad_namespace_publication_step publication:bad_undurable_seal_step fencing_and_outcomes:bad_namespace_step fencing_and_outcomes:bad_retry_revalidation_step publication:bad_publication_step publication:bad_seal_step publication:bad_atomic_step publication:bad_duplicate_step publication:bad_foreign_object_step publication:bad_undurable_step publication:bad_unprotected_step publication:bad_foreign_step publication:bad_mixed_step publication:bad_missing_step publication:bad_interval_step publication:bad_plan_step publication:bad_plan_revision_step publication:bad_parent_step publication:bad_revision_step fencing_and_outcomes:bad_reuse_step fencing_and_outcomes:bad_refresh_step fencing_and_outcomes:bad_fencing_step fencing_and_outcomes:bad_reply_step fencing_and_outcomes:bad_retry_step fencing_and_outcomes:bad_retry2_step fencing_and_outcomes:bad_missing_outcome1_step fencing_and_outcomes:bad_missing_outcome2_step fencing_and_outcomes:bad_corrupt_outcome1_step fencing_and_outcomes:bad_corrupt_outcome2_step fencing_and_outcomes:bad_reply2_step gc:bad_stage_retire_step gc:bad_pin_step gc:bad_retire_step gc:bad_resurrection_step gc:bad_publish_retired_step gc:bad_young_collect_step gc:bad_unretired_collect_step; do
  invariant=${control%%:*}
  step=${control#*:}
  bound=10
  case "$step" in bad_retry_step|bad_retry2_step) bound=15 ;; bad_retry_revalidation_step) bound=13 ;; bad_corrupt_outcome1_step|bad_corrupt_outcome2_step) bound=12 ;; esac
  [ "$step" != bad_publish_retired_step ] || bound=12
  output=$("$quint" verify "$model" --invariant "$invariant" --step "$step" --max-steps "$bound" --verbosity 0 2>&1) && {
    echo "ERROR: $step did not produce a counterexample" >&2
    exit 1
  }
  case "$output" in
    *'found a counterexample'*) echo "$step: counterexample found" ;;
    *) printf '%s\n' "$output" >&2; exit 1 ;;
  esac
done
