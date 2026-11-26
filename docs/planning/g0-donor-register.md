# G0 donor disposition: initial kernel decision

Status: incomplete inventory; no code is imported. The source is Rockstream v1
commit `d3f973a84f4263bedd6505039d7f469d4708c478`, Apache-2.0. This is the
pinned revision in the [migration plan](migration.md#donor-assets-and-regression-transfer).

| Entry | Proposed disposition and dependency evidence | Target and remaining evidence |
| --- | --- | --- |
| `crates/rockstream-ops/src/factorized.rs` | Do not import for W1-G. Its imports include Arrow, `rockstream_storage::{JoinSide, ShardDb, ShardKeyEncoder, WriteBatch}`, Rockstream IDs/mutations, governor and join helpers; its package manifest also declares other workspace and third-party dependencies. Full transitive closure is not yet resolved. | G0.4 uses a bounded first-order kernel; G3b may adapt eligible factorization only after independent three-way correctness and resource evidence. Donor test inputs, exact results, notices and full closure remain to be inventoried. |
| `crates/rockstream-ops/src/join.rs` and `zset.rs` | Inspect for selective adaptation; no transfer has been accepted. | G0.4/G1 need weighted changes and simultaneous-input cross-term coverage against the W1-G independent batch/PostgreSQL oracles. Exact donor inputs, results and dependency closure remain unverified. |
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
  the retraction and three-way replay remain future G1 work.
- Owner/target: G0.4/G1 kernel. Disposition: adapt the input and expected
  behavior, not donor implementation. `join.rs` imports Arrow, Tokio-util,
  tracing, Rockstream storage/types, chunking, errors and `ArrowZSet`; its
  old storage and hashed row identity are not authorized as new authority.
  The package dependency closure and third-party notices remain unresolved.
  This single case does not complete the wider donor-test inventory.
