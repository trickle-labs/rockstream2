#!/usr/bin/env python3
"""Reject an incremental join missing ΔL ⋈ ΔR using frozen W1-G cut 2."""
import csv
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parent.parent
with (root / 'fixtures/w1g/transactions.csv').open(newline='') as stream:
    rows = list(csv.reader(line for line in stream if not line.startswith('#')))

def join(left, right):
    out = Counter()
    for (cid, region), lw in left.items():
        for (_oid, customer, cents), rw in right.items():
            if cid == customer:
                out[(region, int(cents))] += lw * rw
    return out

def add(*bags):
    out = Counter()
    for bag in bags:
        out.update(bag)
    return Counter({row: weight for row, weight in out.items() if weight})

left, right = Counter(), Counter()
for epoch in (0, 1):
    dl, dr = Counter(), Counter()
    for e, table, weight, identifier, value, cents in rows:
        if int(e) == epoch:
            if table == 'customer':
                dl[(identifier, value)] += int(weight)
            else:
                dr[(identifier, value, cents)] += int(weight)
    prior = join(left, right)
    broken = add(prior, join(dl, right), join(left, dr))
    correct = add(broken, join(dl, dr))
    left, right = add(left, dl), add(right, dr)
    if correct != join(left, right):
        raise ValueError(f'complete delta does not match batch at epoch {epoch}')
    if epoch == 1:
        if broken == correct:
            raise ValueError('cross-term negative control escaped detection')
        expected = Counter({('South', 1000): 1, ('South', 2500): 1, ('South', 400): 1})
        if correct != expected:
            raise ValueError('batch result disagrees with frozen cut 2')
print('omitted join cross-term detected at W1-G cut 2')

# Donor regression: delta_native_join_tests::test_delta_native_join_inner_i64.
donor_left = Counter({('1', '10'): 2, ('2', '20'): 1})
donor_right = Counter({('101', '1', '0'): 1, ('102', '1', '30'): 1})
# This fixture's batch join returns (left payload, right payload) with product weights.
def donor_join(left, right):
    result = Counter()
    for (key, left_value), lw in left.items():
        for (_, right_key, right_value), rw in right.items():
            if key == right_key:
                result[(key, left_value, right_key, right_value)] += lw * rw
    return result

donor_actual = donor_join(donor_left, donor_right)
donor_expected = Counter({('1', '10', '1', '0'): 2, ('1', '10', '1', '30'): 2})
if donor_actual != donor_expected:
    raise ValueError('donor weighted join mismatch')
retraction = donor_join(Counter({('1', '10'): -2}), donor_right)
if retraction != Counter({('1', '10', '1', '0'): -2, ('1', '10', '1', '30'): -2}):
    raise ValueError('donor retraction mismatch')
print('donor weighted inner join independent expectation passed')
