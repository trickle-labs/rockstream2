# G0 donor disposition: initial kernel decision

Status: seeded disposition and test inventory; no code is imported. Future
port decisions and their dependency reviews remain open. The source is Rockstream v1
commit `d3f973a84f4263bedd6505039d7f469d4708c478`, Apache-2.0. This is the
pinned revision in the [migration plan](migration.md#donor-assets-and-regression-transfer).

| Entry | Proposed disposition and dependency evidence | Target and remaining evidence |
| --- | --- | --- |
| `crates/rockstream-ops/src/factorized.rs` | Do not import for W1-G. Its imports include Arrow, `rockstream_storage::{JoinSide, ShardDb, ShardKeyEncoder, WriteBatch}`, Rockstream IDs/mutations, governor and join helpers; its package manifest also declares other workspace and third-party dependencies. Full transitive closure is not yet resolved. | G0.4 uses a bounded first-order kernel; Runtime/compiler owners, G3b `DONOR-FACTOR-01`: exact insert/retract/update outputs are recorded below. Independent three-way correctness, resource evidence, notices and full closure remain required before any code port. |
| `crates/rockstream-ops/src/join.rs` and `zset.rs` | Propose adapting the weighted join/Z-set semantics while replacing the storage-coupled implementation; no code transfer has been accepted. | Semantic-kernel owner, G0.4/G1 `DONOR-JOIN-01` and `DONOR-LAW-01`: the exact weighted join and cancellation expectations are recorded below. Full dependency closure/notices remain open before any code port. |
| Other donor assets in the [migration table](migration.md#donor-assets-and-regression-transfer) | Retain as proposed dispositions, not imported or certified. | Inventory exact inputs and results, dependency closure, notices and owners before accepting a port. |

This register does not claim donor results, historical tests or G0.1 qualification.

## Exact weighted join case

- Source: `crates/rockstream-ops/tests/delta_native_join_tests.rs`, test
  `test_delta_native_join_inner_i64`, at the pinned revision above. The source
  asserts these outputs; the donor has not been executed here.
- Input at epoch 0: left `((1,10), +2), ((2,20), +1)` and right
  `((1,0), +1), ((1,30), +1)`, joined on the first column. Independently,
  equal keys yield `(1,10,1,0): +2` and `(1,10,1,30): +2`; key 2 has no
  match. At the next epoch, left `((1,10), -2)` and empty right produce the
  same two rows at weight `-2`. The source asserts both outputs. The initial
  expected output is checked independently in `scripts/check-cross-term.py`;
  the retraction is also checked there; three-way replay remains future G1 work.
- Owner/target: G0.4/G1 kernel. Disposition: adapt the input and expected
  behavior, not donor implementation. `join.rs` imports Arrow, Tokio-util,
  tracing, Rockstream storage/types, chunking, errors and `ArrowZSet`; its
  old storage and hashed row identity are not authorized as new authority.
  The package dependency closure and third-party notices remain unresolved.
  This single case does not complete the wider donor-test inventory.

## Remaining audited components

These are proposed dispositions only, with no code ported and no claim of
executing donor tests. Each requires exact donor cases, independent expected
results, complete transitive dependency/notice review and target test IDs
before reuse.

| Pinned source path | Disposition and visible coupling | Target |
| --- | --- | --- |
| `crates/rockstream-types/src/arrangement.rs` | Propose adapting descriptors; direct imports include IDs, merge laws, serde and SHA-256. Replace hash-only admission. | Semantic-kernel/sharing owners, G1/G3b `DONOR-ARRANGEMENT-01`: the original spec and ID survive reopen; forced digest-collision and semantic/security mismatch tests are new obligations, not historical evidence. |
| `crates/rockstream-storage/src/trace.rs`, `arrangement_catalog.rs` | Propose adapting trace algorithms and replacing catalog authority; imports include types, serde, verified persistence and Tokio synchronization. | Storage/sharing owners, G2/G3b `DONOR-TRACE-01`: recovered cuts 50 and 100 return the exact rows below; root/pin integration and independent consumer schedules remain open. |
| `crates/rockstream-control/src/frontier.rs` | Propose adapting progress cases and replacing publication wiring; direct imports include SlateDB, audit, IDs and locking. | Runtime owner, G2/G4 `DONOR-FRONTIER-01`: a shard report of 3 after 5 cannot lower the published frontier from 5; new scope/generation fencing and omitted-work checks remain open. |
| `crates/rockstream-storage/src/shard_db.rs` | Propose extracting lessons and replacing commit authority; imports include object_store, SlateDB, types and format migration. | Storage owner, G0.2/G2 `DONOR-ACK-01`: injected ENOSPC must withhold ACK and recover the complete epoch; new exact-parent reopen and retained history remain open. |
| `crates/rockstream-sim/src`, `formal` | Propose adapting counterexamples and harness assumptions; replace old model bindings, not historical proof claims. | Verification owner, G0.3/G2/G4 `DONOR-SIM-01` and `DONOR-WORKER-01`: interrupted migration retains all three values and worker failure has the exact expected relation below. Model-to-new-transition mapping and delivered-fault evidence remain open. |
| `crates/rockstream-control/src/raft.rs` | Propose rejecting as metadata log and adapting election/fencing failures. Direct imports include Tokio, object_store and Rockstream raft types. | Metadata/runtime owners, G0.3/G4 `DONOR-FENCE-01`: obsolete A must reject authority after B wins term 2; new generation-fencing evidence remains open. No claim of log replication. |

## Seeded test and evidence inventory

The following entries cover the evidence families in the
[carry-forward seed list](../research/implementation-experience-report.md#5-carry-forward-register-donor-cases-and-mechanisms).
Unless a different revision is named, all source paths are at donor revision
`d3f973a84f4263bedd6505039d7f469d4708c478`, Apache-2.0. Expected results
below are stated independently from the required semantics and correspond to
source assertions; they are **not newly observed donor runs**. The target IDs
are planned ownership identifiers, not a claim that those tests already exist.
No donor implementation has been imported. Consequently no transitive donor
code or notices have been accepted into this workspace; the full dependency
closure and notices for any proposed port must be resolved before accepting it.
The seed list is not an exhaustive catalog of all historical donor tests.

| Seed / donor path and case | Exact input and independently expected result | Disposition, target owner/test ID and remaining evidence |
| --- | --- | --- |
| #8 / weighted join pilot: [`crates/rockstream-oracle/src/join_oracle.rs::oracle_join_weighted_deltas_across_epochs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-oracle/src/join_oracle.rs#L594) | Same key, L/R deltas `(+2,+3),(+1,0),(0,-1),(-1,-1),(-2,0),(+2,+1)`. The complete output row `(1,10,100)` has weights `6,9,6,2,0,4`; zero means absent. | Adapt history, not implementation; semantic-kernel owner, G1 `DONOR-JOIN-01`. The original #8 law case is separately pinned below; other law cases remain to be transferred at G1. |
| #8 historical source, revision `26c4b9aaf8ba14b2050773db5f77839220d01ddf`: [`crates/rockstream-oracle/tests/law_property_tests.rs::zset_insert_delete_cancels_to_identity`](https://github.com/trickle-labs/rockstream/blob/26c4b9aaf8ba14b2050773db5f77839220d01ddf/crates/rockstream-oracle/tests/law_property_tests.rs#L136) | For key `key`, value `val`, and each generated weight `w` in `1..10000`, insert `+w`, insert `-w`, and consolidate. The independently expected result is an empty Z-set; encoded weight merge `w + (-w)` is the identity. | Adapt the property, not its old harness; semantic-kernel owner, G1 `DONOR-LAW-01`. This historical path was read from #8’s immutable head; it was not found at the later donor revision and was not executed here. |
| #101: [`crates/rockstream-storage/tests/catalog_storage_tests.rs::test_snapshot_retry_preserves_deleted_table_and_objects`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/tests/catalog_storage_tests.rs#L49) | Create table ID 10 using op 555/revision 1; delete using op 556/revision 2; snapshot and compact. On two recoveries, retry 555 returns revision 2, current revision stays 2, tables stay empty, and the complete stored-object bytes are unchanged. The source fixture's only object is `retry/catalog/snapshots/00000000000000000002.snap`. | Adapt counterexample to new metadata transitions; metadata owner, G2 `DONOR-CATALOG-01`. Original uses an in-memory store, not process-crash evidence. |
| #149: [`crates/rockstream-storage/tests/catalog_identity_tests.rs::test_id_allocator_avoids_collisions_with_restored_ids`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/tests/catalog_identity_tests.rs#L10) | Allocate `1,2`, observe `100`, allocate `101,102`, observe `50`: high-water remains `102`, next allocation is `103`. | Adapt invariant; metadata owner, G2 `DONOR-ID-01`. Full workload-ID definition and recovery cases remain to be ported at their boundary. |
| #150: [`crates/rockstream-storage/tests/catalog_recovery_fault_tests.rs::failures_after_compaction_never_publish_or_mutate_objects`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/tests/catalog_recovery_fault_tests.rs#L230) | Inject snapshot LIST, GET, or body errors after compaction: recovery must fail with storage error, object inventory unchanged. A malformed snapshot must fail decoding and leave the inventory unchanged. | Adapt fault boundaries, replace old catalog authority; metadata owner, G2 `DONOR-RECOVERY-01`. Source-specific `RS-0003`/`RS-1003` are historical, not new API promises. |
| Persistence/post-ACK: [`crates/rockstream-storage/tests/enospc_recovery_tests.rs::enospc_withholds_ack_and_recovers_a_complete_epoch`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/tests/enospc_recovery_tests.rs#L187) and [fault matrix](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/docs/testing/post-ack-durability-fault-matrix.md) | Fail object-store puts with ENOSPC during epoch 2: no success ACK while failure is active. After recovery, exact state is row1 `10:200`, row2 absent, row3 `30:75`, offset `15`, frontier `2`, op `epoch-2`. | Adapt error/reopen scenario; storage owner, G2 `DONOR-ACK-01`. Adapter injection is not a real full filesystem or power cut. |
| #386: [`crates/rockstream-connectors/tests/postgres_cdc_guarantee_matrix_tests.rs::postgres_cdc_synchronized_snapshot_handoff_is_exact_across_restart`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-connectors/tests/postgres_cdc_guarantee_matrix_tests.rs#L562) | Snapshot is `{(1,10),(2,20)}`; insert `(3,30)`, update id 1 to `15`, delete id 2 after snapshot bind: live state `{(1,15),(3,30)}`. Restart polling from saved offset yields no replay; inserting `(4,40)` gives exactly those three final rows. | Adapt handoff transcript; connector owner, G3a `DONOR-CDC-01`. Source uses real PostgreSQL and timing hooks; new boundary must deliver and witness the faults. |
| #397: [`docs/testing/shared-pgoutput-recovery-v1.md`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/docs/testing/shared-pgoutput-recovery-v1.md) | Table a `{(1,10),(2,20)}` becomes `{(1,15),(2,20),(3,30)}`; b `{(11,110),(12,120)}` becomes `{(11,110),(13,130)}`; subsequent inserts add `(4,40)` and `(14,140)`. Each view maps `(id,val)` to `(id,2*val)`. The document names before-M3, after-M3/before-ACK, partial-decode disconnect and schema-rejection boundaries. | Adapt fixed transcript and delivered-fault checks; connector owner, G3a `DONOR-CDC-02`. Original source document includes the three-table extension and exact witnesses; no recovery run is claimed here. |
| #396: [`crates/rockstream-connectors/tests/source_coordination_sim_tests.rs::pending_ack_blocks_poll_until_idle_recovery_acks_exact_durable_checkpoint`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-connectors/tests/source_coordination_sim_tests.rs#L651) | Epoch 1 commits token `durable-01`, then ACK fails. Poll and epoch 2 commit reject until idle ACK recovery; the later healthy token is `healthy-02`. Expected ACK transcript: `(1,durable-01),(1,durable-01),(2,healthy-02)`; in-flight count returns to zero. | Adapt transcript, not old coordinator; connector owner, G3a `DONOR-ACK-02`. New failure/error mapping remains to be specified. |
| #398/#407: [`crates/rockstream-control/src/raft/heartbeat_lease_tests.rs`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-control/src/raft/heartbeat_lease_tests.rs#L385) | An old quorum ACK is delivered at 74 ms; replacement B wins term 2 at 151 ms. At 170 ms A may still report role Leader, but must reject authority and expose no leader epoch; B must report `Ok(2)` and epoch `131074`. | Adapt stale-actor scenario to new generation fencing; metadata/runtime owners, G0.3/G4 `DONOR-FENCE-01`. Reject donor election module as replicated-log authority. #407's dependency-scope isolation remains a separate unexecuted scenario. |
| #409: [`crates/rockstream-ops/tests/factorized_join_aggregate_oracle_tests.rs::incremental_updates_deletes_and_retractions_match_complete_output`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-ops/tests/factorized_join_aggregate_oracle_tests.rs#L673) | L `(1,2)`, R `(1,5)` produce `(1,5)×+1`; deleting and reinserting R produce the same row at `-1` then `+1`; replacing R `(1,5)` with `(1,7)` yields `(1,5)×-1,(1,7)×+1`. | Adapt expected behavior only; runtime/compiler owners, G3b `DONOR-FACTOR-01`. Full state/resource accounting and independent three-way comparison precede any implementation port. |
| #420: [`crates/rockstream-control/tests/direct_distributed_execution_400_tests.rs::r1_r2_r6_direct_arrow_ingestion_bypasses_control_and_wires_worker_inlets`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-control/tests/direct_distributed_execution_400_tests.rs#L110) | Epoch 1 sends `(1,100),(2,200),(1,50)`; epoch 2 sends `(1,25),(2,100),(3,77)`. Expected complete aggregate rows `(1,175),(2,300),(3,77)` each weight 1, with zero row payloads through control and at least two worker gRPC frames. | Adapt observable path/counter obligations, not old global dispatch; runtime owner, G4 `DONOR-DIRECT-01`. Separate-process and real cloud behavior remain unqualified by this source assertion. |
| #185: [`docs/testing/worker-failure-kafka-minio-v1.json`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/docs/testing/worker-failure-kafka-minio-v1.json) | Five weighted changes are `(1,a)+1,(2,b)+1,(1,a)-1,(1,c)+1,(2,b)-1`; kill after source epoch 3. Expected final relation is exactly `{(1,c)×1}` and frontier `5`; full expected sink records are pinned in the manifest. | Adapt fault/complete-output evidence; qualification owner, G4/G6 `DONOR-WORKER-01`. Fixture values are expectations, not evidence the scenario ran here. |
| #198/#405: [`tools/r1-local-harness/tests/v072_eight_oracle_cli_tests.rs::corrupt_observed_multiset_has_nonzero_exit_and_no_success_artifact`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/tools/r1-local-harness/tests/v072_eight_oracle_cli_tests.rs#L108) | Replace `result-4.json` (the fifth observed result file) with `[]`; the verifier must exit nonzero with `complete-result oracle mismatch` and no success artifact. | Adapt independent checker negative case; verification owner, G1/G6 `DONOR-ORACLE-01`. This is a structural fixture, not a scale measurement. #405's actual multi-process scale program remains unexecuted. |
| #157/#252/#253: [`scripts/ci-test-inventory.test.py::test_mandatory_missing_terminal_event`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/scripts/ci-test-inventory.test.py#L182) and [`scripts/record-verus-qualification.test.py::test_phase_identity_step_failures_and_budgets_fail_closed`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/scripts/record-verus-qualification.test.py#L93) | Mandatory case with no terminal event yields a missing-event error and zero passes; stale revision/lock digest, failed or over-budget step, or corrupt binary digest makes qualification merge raise an error and leaves no completed output. | Adapt evidence rules; verification owner, G0.1/G6 `DONOR-EVIDENCE-01`. Current fast suite has no full execution-accounting gate; implement where required before qualification. |
| v0.73 security: [`crates/rockstream-cli/tests/oidc_release_process_tests.rs::management_rejects_stale_grantor_revision_by_release_process`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-cli/tests/oidc_release_process_tests.rs#L1609) | Increment the grantor revision and remove its operator permission; submit a grant mutation with the old expected revision. Expected operation state `failed`, phase `security_policy_rejected`, historical reason `RS-2401`, unchanged target principal, and exact durable failure record on lookup. | Adapt denied-mutation and durable-audit behavior; security owner, G2+ `DONOR-SECURITY-01`. Donor v0.73 was not integrated sign-off; the historical code is not a new compatibility promise. |
| v0.59.13 surface: [`scripts/check-product-surface.test.sh`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/scripts/check-product-surface.test.sh#L82) | Tamper generated function `upper` return type to `INT4`; drift check must reject the signature mismatch. Remove error `RS-0001` or add dangling `RS-9999`; corresponding missing/reference checks must reject. | Adapt drift and source-owned capability evidence; product-surface owner, G2+ `DONOR-SURFACE-01`. Historical signed-off state does not qualify v2. |


## Additional component cases

- **`DONOR-ARRANGEMENT-01` / `DONOR-TRACE-01`** — At the pinned donor revision,
  [`test_lfs_shared_trace_durability_and_recovery`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-storage/tests/lfs_shared_trace_durability_tests.rs#L29)
  persists a spec for tenant 1 / `lfs_trades` with two consumers and two batches.
  After reopen the spec and arrangement ID match; cut 50 is `{AAPL:150,
  GOOG:2800}` and cut 100 is `{AAPL:155, GOOG:2800}`. The companion
  `test_lfs_shared_trace_compaction_and_slowest_consumer` has consumers at 30
  and 10, so compaction may advance only to 10; once both reach 30 it advances
  to 30 and the surviving `key_x` value is `v3`. Adapt the logical expected
  cuts and retention constraints; do not inherit the old storage format.
- **`DONOR-FRONTIER-01`** — The pinned donor
  [`cluster_frontier_is_non_decreasing`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-control/src/frontier.rs#L1166)
  ingests shard 0 at epoch 5 then stale epoch 3; the expected frontier is 5.
  The new progress/publication contract additionally needs scope and generation
  checks, which this old case alone does not establish.
- **`DONOR-SIM-01`** — The pinned donor
  [`test_crash_at_v2_to_v3_migration_boundary_recovery`](https://github.com/trickle-labs/rockstream/blob/d3f973a84f4263bedd6505039d7f469d4708c478/crates/rockstream-sim/tests/sim_shared_trace_crash_boundary_tests.rs#L24)
  writes `k1:v1`, `k2:v2`, `k3:v3`, interrupts after one migrated object, and
  expects all three values after resuming. Reuse the interruption/no-loss
  obligation, not a promise to read the donor's V2 or V3 physical formats.
