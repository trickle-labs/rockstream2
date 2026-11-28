#!/bin/sh
set -eu

quint=${QUINT:-quint}
model=$(dirname "$0")/protocol.qnt
"$quint" typecheck "$model"
"$quint" verify "$model" --invariants publication fencing_and_outcomes gc --max-steps 16 --verbosity 0
"$quint" verify "$model" --observation 's.head == 3 and s.outcome1 == 2 and s.metadataDone and s.response1 and s.responseHead1 == 3 and s.reply1 == 2 and s.effects1 == 1' --max-steps 14 --verbosity 0
"$quint" verify "$model" --observation 's.head == 3 and s.outcome2 == 2 and s.metadataDone and s.response2 and s.responseHead2 == 3 and s.reply2 == 2 and s.effects2 == 1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_retry2_step --observation 's.effects2 == 2 and s.done2' --max-steps 19 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_corrupt_outcome1_step --observation 's.committed1 == 2 and s.head == 3 and s.outcome1 == 3 and s.response1 and s.reply1 == 3' --max-steps 15 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_corrupt_outcome2_step --observation 's.committed2 == 2 and s.head == 3 and s.outcome2 == 3 and s.response2 and s.reply2 == 3' --max-steps 15 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.abandonedAttempt == 1 and s.attempt == 2 and s.receipt1Attempt == 1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_reuse_step --observation 's.stalePublished and s.attempt == 1 and s.receipt1Attempt == 1 and s.abandonedAttempt == 1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.refreshed and s.refreshedAfterMetadata and s.metadataDone and s.publications == 1 and s.parent == 0 and s.publicationHead == 1 and s.effects1 == 1' --max-steps 14 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.pinned and s.revision < s.head' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.pinned and s.retirePending and s.retireRevision < s.head' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.retired and s.pinPending and s.pinRevision < s.head' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.retired and not(s.pinned) and not(s.root) and not(s.deleted) and s.age < 2' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 'not(s.retired) and not(s.pinned) and not(s.root) and not(s.deleted) and not(s.stageProtected) and s.age >= 2' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.abandonedAttempt == 1 and s.attempt == 2 and s.receipts == Set(1, 2) and s.receipt1Attempt == 1 and s.receipt2Attempt == 2 and s.receipt1Scope == 1 and s.receipt2Scope == 1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.receipts == Set(1) and s.receipt1Attempt == s.attempt' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_seal_step --observation 's.badSealCommit and s.sealed and s.sealDurable and s.receipt1Id == 3 and s.sealedReceipt1 != 3' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_missing_step --observation 's.badPublication and not(s.badSealCommit) and s.receipts == Set(1)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_mixed_step --observation 's.badPublication and not(s.badSealCommit) and s.abandonedAttempt == 1 and s.receipt1Attempt == 1 and s.receipt2Attempt == 2 and s.receipt1Scope == 1 and s.receipt2Scope == 1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_interval_step --observation 's.badPublication and not(s.badSealCommit) and s.receipt1Scope == 2 and s.receipt2Scope == 1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_plan_step --observation 's.badPublication and not(s.badSealCommit) and s.receipt1Scope == 3 and s.receipt2Scope == 1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.sealed and s.refreshed and s.preparedPlan == 1 and s.sealedPlan == 1 and s.planRevision == 2 and s.revision == s.head and s.parent == s.publicationHead and s.owner == s.generation' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_plan_revision_step --observation 's.badPlanCommit and s.refreshed and s.preparedPlan == 1 and s.sealedPlan == 1 and s.planRevision == 2 and s.publicationHead == s.parent + 1 and s.owner == s.generation' --max-steps 14 --verbosity 0
"$quint" verify "$model" --observation 's.planRevision == 2 and s.preparedPlan == 2 and s.sealedPlan == 2 and s.effects1 == 1 and not(s.prepared)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_duplicate_step --observation 's.badPublication and not(s.badSealCommit) and s.duplicate and s.receipts == Set(1, 2) and s.receipt1Attempt == s.attempt and s.receipt2Attempt == s.attempt and s.receipt1Scope == expectedScope and s.receipt2Scope == expectedScope' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_undurable_step --observation 's.badDataCommit and not(s.stageDurable) and s.stageProtected and s.visible1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_unprotected_step --observation 's.badDataCommit and s.stageDurable and s.stageClosed and not(s.stageProtected) and s.visible1' --max-steps 14 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_foreign_object_step --observation 's.badPublication and not(s.badSealCommit) and not(s.badDataCommit) and s.receipt1Object == 2 and s.receipt2Object == 1' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.stageDurabilityAdvanced and s.publishedDataReady and s.effects1 == 1 and not(s.prepared)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_stage_retire_step --observation 's.badGc and s.retired and not(s.prepared) and s.abandonedAttempt != 0 and s.abandonedAttempt == s.attempt and s.stageProtected and not(s.root) and not(s.pinned)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_publish_retired_step --observation 's.badGc and s.badDataCommit and s.retired and s.visible1 and s.stageDurable and not(s.stageProtected)' --max-steps 19 --verbosity 0
"$quint" verify "$model" --observation 'not(s.prepared) and s.abandonedAttempt != 0 and s.abandonedAttempt == s.attempt and s.stageProtected and not(s.root) and not(s.retired)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.generation == 1 and s.namespaceGeneration == 1 and s.namespaceOpen' --max-steps 4 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.lastAttempt == 2 and s.stageProtected and s.head == 0 and s.namespaceGeneration == s.generation' --max-steps 6 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.sealed and not(s.sealDurable) and s.stageProtected' --max-steps 7 --verbosity 0
"$quint" verify "$model" --observation 's.effects1 == 1 and s.sealDurable and s.namespaceGeneration == s.generation' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.retryDeferred and s.retryCount == 1 and s.revision < s.head and s.stageProtected' --max-steps 8 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and not(s.retryDeferred) and s.retryCount == 0 and s.refreshed and s.revision < s.head and s.head == 2' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_namespace_publication_step --observation 's.badNamespaceCommit and s.stageProtected and not(s.namespaceOpen) and s.sealDurable and s.refreshed' --max-steps 14 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_undurable_seal_step --observation 's.badSealCommit and s.sealed and not(s.sealDurable) and s.stageProtected' --max-steps 14 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_retry_revalidation_step --observation 's.badFence and s.preparedGeneration == 0 and s.generation == 1 and not(s.retryDeferred)' --max-steps 16 --verbosity 0
"$quint" verify "$model" --observation 's.effects1 == 1 and s.preparedPublisher == s.authorizedPublisher and s.committedVia != s.authorizedPublisher and not(s.badPublisherCommit)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.sealed and s.sealDurable and s.stageDurable and s.preparedPublisher != s.authorizedPublisher and namespaceMatches' --max-steps 9 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_publisher_step --observation 's.badPublisherCommit and s.visible1 and not(s.badNamespaceCommit) and not(s.badDataCommit) and not(s.badSealCommit) and not(s.badFence) and not(s.badParent) and not(s.badPublication)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.effects1 == 1 and s.inputAccepted and s.inputSegmentDurable and s.inputUpper == 1 and s.sealedProof == s.inputProof and s.metadataPageSelected and s.rootPageProtected' --max-steps 13 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.lastAttempt == 1 and s.done2 and s.effects2 == 1 and s.inputUpper == 1 and s.rootPageProtected' --max-steps 9 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_active_step --observation 's.badContextCommit and not(s.active) and s.preparedRun == s.runIncarnation and s.preparedCatalog == s.catalogRevision and not(s.badInputCommit) and not(s.badPageCommit)' --max-steps 14 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_run_step --observation 's.badContextCommit and s.active and s.preparedRun != s.runIncarnation and s.preparedCatalog == s.catalogRevision and not(s.badInputCommit) and not(s.badPageCommit)' --max-steps 14 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_catalog_step --observation 's.badContextCommit and s.active and s.preparedRun == s.runIncarnation and s.preparedCatalog != s.catalogRevision and not(s.badInputCommit) and not(s.badPageCommit)' --max-steps 14 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_input_publication_step --observation 's.badInputCommit and not(s.inputAccepted) and not(s.badContextCommit) and not(s.badPageCommit)' --max-steps 12 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_foreign_input_step --observation 's.badInputCommit and s.inputAccepted and s.inputSegmentDurable and s.inputUpper >= s.sealedUpper and s.sealedProof != s.inputProof and not(s.badContextCommit) and not(s.badPageCommit)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_future_input_step --observation 's.badInputCommit and s.inputAccepted and s.inputSegmentDurable and s.inputProof == s.sealedProof and s.inputUpper < s.sealedUpper and not(s.badContextCommit) and not(s.badPageCommit)' --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_page_base_step --observation 's.badPageCommit and s.refreshed and s.metadataPageProtected and s.metadataPageGeneration == s.metadataGeneration and s.metadataPageBase + 1 < s.head and not(s.badContextCommit) and not(s.badInputCommit)' --max-steps 14 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_page_generation_step --observation 's.badPageCommit and not(s.metadataPageProtected) and s.metadataPageGeneration != s.metadataGeneration and s.metadataPageBase + 1 == s.head and not(s.badContextCommit) and not(s.badInputCommit)' --max-steps 14 --verbosity 0
"$quint" verify "$model" --observation 's.prepared and s.preparedAfterPublication and s.rootPageReferenced and s.rootPageProtected and s.metadataGeneration == 1 and s.rootPageGeneration == 0' --max-steps 16 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_root_page_step --observation 's.prepared and s.preparedAfterPublication and s.rootPageReferenced and not(s.rootPageProtected)' --max-steps 16 --verbosity 0
"$quint" verify "$model" --invariant publication --step bad_revision_step --max-steps 13 --verbosity 0
"$quint" verify "$model" --no-invariant --step bad_revision_and_page_step --observation 's.badParent and s.badPageCommit and s.revision == s.metadataPageBase and s.metadataPageBase + 2 == s.head and s.metadataPageProtected and s.metadataPageGeneration == s.metadataGeneration' --max-steps 13 --verbosity 0

for control in fencing_and_outcomes:bad_input_accept_step publication:bad_active_step publication:bad_run_step publication:bad_catalog_step publication:bad_input_publication_step publication:bad_foreign_input_step publication:bad_future_input_step publication:bad_page_base_step publication:bad_page_generation_step publication:bad_root_page_step fencing_and_outcomes:bad_publisher_step publication:bad_namespace_publication_step publication:bad_undurable_seal_step fencing_and_outcomes:bad_namespace_step fencing_and_outcomes:bad_retry_revalidation_step publication:bad_publication_step publication:bad_seal_step publication:bad_atomic_step publication:bad_duplicate_step publication:bad_foreign_object_step publication:bad_undurable_step publication:bad_unprotected_step publication:bad_foreign_step publication:bad_mixed_step publication:bad_missing_step publication:bad_interval_step publication:bad_plan_step publication:bad_plan_revision_step publication:bad_parent_step publication:bad_revision_and_page_step fencing_and_outcomes:bad_reuse_step fencing_and_outcomes:bad_refresh_step fencing_and_outcomes:bad_fencing_step fencing_and_outcomes:bad_reply_step fencing_and_outcomes:bad_retry_step fencing_and_outcomes:bad_retry2_step fencing_and_outcomes:bad_missing_outcome1_step fencing_and_outcomes:bad_missing_outcome2_step fencing_and_outcomes:bad_corrupt_outcome1_step fencing_and_outcomes:bad_corrupt_outcome2_step fencing_and_outcomes:bad_reply2_step gc:bad_stage_retire_step gc:bad_pin_step gc:bad_retire_step gc:bad_resurrection_step gc:bad_publish_retired_step gc:bad_young_collect_step gc:bad_unretired_collect_step; do
  invariant=${control%%:*}
  step=${control#*:}
  bound=13
  case "$step" in bad_retry_step|bad_retry2_step) bound=19 ;; bad_retry_revalidation_step|bad_root_page_step) bound=16 ;; bad_corrupt_outcome1_step|bad_corrupt_outcome2_step) bound=15 ;; bad_active_step) bound=14 ;; esac
  [ "$step" != bad_publish_retired_step ] || bound=15
  output=$("$quint" verify "$model" --invariant "$invariant" --step "$step" --max-steps "$bound" --verbosity 0 2>&1) && {
    echo "ERROR: $step did not produce a counterexample" >&2
    exit 1
  }
  case "$output" in
    *'found a counterexample'*) echo "$step: counterexample found" ;;
    *) printf '%s\n' "$output" >&2; exit 1 ;;
  esac
done

# Independent manifest contenders and retained client outcomes.
"$quint" verify "$model" --observation 's.retired and s.pinPending and s.otherUploaded and s.otherKind == 9 and s.otherBase < s.head and s.racerDone and s.racerKind == 10 and s.racerBase == s.otherBase' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.pinned and s.retirePending and s.otherUploaded and s.otherKind == 10 and s.otherBase < s.head and s.racerDone and s.racerKind == 9 and s.racerBase == s.otherBase' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.clientReplyIssued and s.clientReplyKind == 1 and s.clientEffects == 1 and s.clientReplyHead > s.clientGhostOutcome' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.clientReplyIssued and s.clientReplyKind == 2 and s.clientReplyDigest != s.clientGhostDigest' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.clientReplyIssued and s.clientReplyKind == 2 and s.clientReplyDigest != s.clientGhostDigest and s.clientEffects == 1' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.clientGhostOutcome == -1 and s.clientReplyIssued and s.clientReplyKind == 1 and s.clientReplyValue == -1' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.clientReplyIssued and s.clientReplyKind == 3 and s.clientFloor == 2 and not(s.clientRetained)' --max-steps 10 --verbosity 0
"$quint" verify "$model" --observation 's.clientReplyIssued and s.clientReplyKind == 3 and s.clientFloor == 2 and not(s.clientRetained) and s.clientEffects == 1' --max-steps 10 --verbosity 0

for control in publication:bad_other_unprotected_step publication:bad_other_stale_step publication:bad_other_generation_step publication:bad_other_kind_step fencing_and_outcomes:bad_forget_client_step fencing_and_outcomes:bad_expired_accept_step fencing_and_outcomes:bad_client_conflict_step fencing_and_outcomes:bad_client_expired_step fencing_and_outcomes:bad_pub_mismatch1_step fencing_and_outcomes:bad_pub_mismatch2_step; do
  invariant=${control%%:*}
  step=${control#*:}
  bound=10
  case "$step" in bad_pub_mismatch1_step|bad_pub_mismatch2_step) bound=16 ;; esac
  output=$("$quint" verify "$model" --invariant "$invariant" --step "$step" --max-steps "$bound" --verbosity 0 2>&1) && {
    echo "ERROR: $step did not produce a counterexample" >&2
    exit 1
  }
  case "$output" in
    *'found a counterexample'*) echo "$step: counterexample found" ;;
    *) printf '%s\n' "$output" >&2; exit 1 ;;
  esac
done
