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
