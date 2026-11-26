# W1-G fixture

`transactions.csv` records each atomic epoch as ordered insertions (`1`) and
normalized preimages (`-1`); ids/customer ids are signed BIGINT values, and
amounts are integer cents corresponding to DECIMAL(18,2). `expected.csv` lists
the complete grouped result at each nonempty cut; cuts 0 and 4 have no rows.
Regions are non-null binary-collated text. See the canonical workload in
[implementation start](../../docs/planning/implementation-start.md#2-canonical-golden-workload-w1-g).

For this fixture, sums use exact integer cents and SQL `numeric` aggregation;
counts use BIGINT. Every amount is within DECIMAL(18,2), and every count and sum
is within signed 64-bit cents. This is not the full G1/G2 numeric type matrix.
The batch oracle recomputes joins from current source relations at each cut;
PostgreSQL independently evaluates the SQL against the same inputs and frozen
expected rows. Neither implements the incremental kernel. The cross-term
negative control runs a deliberately incomplete incremental join and verifies
that it differs from batch evaluation at cut 2.
