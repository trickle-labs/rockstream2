#!/bin/sh
set -eu

quint=${QUINT:-quint}
model=$(dirname "$0")/protocol.qnt
"$quint" typecheck "$model"
"$quint" verify "$model" --invariants publication fencing_and_outcomes gc --max-steps 8 --verbosity 0

"$quint" verify "$model" --observation 's.head == 2 and s.outcome1 == 1 and s.metadataDone and s.response1 and s.reply1 == 1 and s.effects1 == 1' --max-steps 8 --verbosity 0

"$quint" verify "$model" --observation 's.prepared and s.abandonedAttempt == 1 and s.attempt == 2 and s.receiptAttempt == 1' --max-steps 8 --verbosity 0

"$quint" verify "$model" --no-invariant --step bad_reuse_step --observation 's.stalePublished and s.attempt == 1 and s.receiptAttempt == 1 and s.abandonedAttempt == 1' --max-steps 8 --verbosity 0

"$quint" verify "$model" --observation 's.refreshed and s.metadataDone and s.publications == 1 and s.parent == 0 and s.publicationHead == 1 and s.effects1 == 1' --max-steps 8 --verbosity 0

"$quint" verify "$model" --observation 's.prepared and s.pinned and s.revision < s.head' --max-steps 8 --verbosity 0
"$quint" verify "$model" --observation 's.pinned and s.retirePending and s.retireRevision < s.head' --max-steps 8 --verbosity 0
"$quint" verify "$model" --observation 's.retired and s.pinPending and s.pinRevision < s.head' --max-steps 8 --verbosity 0

for control in publication:bad_publication_step publication:bad_atomic_step publication:bad_foreign_step publication:bad_parent_step publication:bad_revision_step fencing_and_outcomes:bad_reuse_step fencing_and_outcomes:bad_refresh_step fencing_and_outcomes:bad_fencing_step fencing_and_outcomes:bad_reply_step fencing_and_outcomes:bad_retry_step gc:bad_pin_step gc:bad_retire_step gc:bad_resurrection_step gc:bad_publish_retired_step; do
  invariant=${control%%:*}
  step=${control#*:}
  output=$("$quint" verify "$model" --invariant "$invariant" --step "$step" --max-steps 8 --verbosity 0 2>&1) && {
    echo "ERROR: $step did not produce a counterexample" >&2
    exit 1
  }
  case "$output" in
    *'found a counterexample'*) echo "$step: counterexample found" ;;
    *) printf '%s\n' "$output" >&2; exit 1 ;;
  esac
done
