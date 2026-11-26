#!/usr/bin/env python3
"""Replay the frozen transaction log into PostgreSQL and compare exact cuts."""
import csv
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent

def rows(name):
    with (root / 'fixtures' / 'w1g' / name).open(newline='') as f:
        return list(csv.reader(line for line in f if not line.startswith('#')))

transactions = rows('transactions.csv')
expected = rows('expected.csv')
for row in expected:
    if len(row) != 4 or row[1] not in ('North', 'South'):
        raise ValueError('invalid expected region')
sql = ['CREATE TEMP TABLE customers (id bigint primary key, region text COLLATE "C" NOT NULL);',
       'CREATE TEMP TABLE orders (id bigint primary key, customer bigint NOT NULL, amount numeric(18,2) NOT NULL);']
query = 'SELECT c.region, count(*)::bigint AS n, sum(o.amount) AS revenue FROM customers c JOIN orders o ON c.id=o.customer GROUP BY c.region'

def check(cut):
    values = [f"('{r[1]}', {int(r[2])}::bigint, {int(r[3])}::numeric / 100)" for r in expected if int(r[0]) == cut]
    want = 'VALUES ' + ','.join(values) if values else 'SELECT NULL::text, NULL::bigint, NULL::numeric WHERE false'
    sql.append(f"DO $$ BEGIN IF EXISTS (({query}) EXCEPT ALL ({want})) OR EXISTS (({want}) EXCEPT ALL ({query})) THEN RAISE EXCEPTION 'W1-G cut {cut} mismatch'; END IF; END $$;")

check(0)
for epoch in range(4):
    sql.append('BEGIN;')
    for e, table, weight, identifier, value, cents in transactions:
        if int(e) != epoch:
            continue
        identifier = int(identifier)
        if table == 'customer':
            if value not in ('North', 'South'):
                raise ValueError('invalid fixture region')
            predicate = f"id={identifier} AND region='{value}'"
            vals = f"{identifier}, '{value}'"
            target = 'customers'
        else:
            if table != 'order':
                raise ValueError('invalid fixture table')
            predicate = f'id={identifier} AND customer={int(value)} AND amount={int(cents)}::numeric/100'
            vals = f'{identifier}, {int(value)}, {int(cents)}::numeric/100'
            target = 'orders'
        if weight == '1':
            sql.append(f'INSERT INTO {target} VALUES ({vals});')
        else:
            if weight != '-1':
                raise ValueError('invalid fixture weight')
            sql.append(f"DO $$ BEGIN DELETE FROM {target} WHERE {predicate}; IF NOT FOUND THEN RAISE EXCEPTION 'missing preimage'; END IF; END $$;")
    sql.append('COMMIT;')
    check(epoch + 1)
sql.append("DO $$ BEGIN IF (SELECT count(*) FROM orders) <> 0 THEN RAISE EXCEPTION 'empty COUNT mismatch'; END IF; END $$;")
subprocess.run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-q', '-d', 'postgres'], input='\n'.join(sql), text=True, check=True, env=os.environ)
print('PostgreSQL W1-G complete-cut comparisons passed')
