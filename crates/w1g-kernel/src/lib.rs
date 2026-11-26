//! Bounded, single-interval W1-G incremental kernel spike.
use arrow_array::{Array, Int64Array, RecordBatch, StringArray};
use arrow_schema::DataType;
use std::collections::BTreeMap;

const MAX_ROWS: usize = 128;
const MAX_REGION_BYTES: usize = 32;
const MAX_INPUT_BYTES: usize = 16 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
struct Order {
    customer: i64,
    cents: i64,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Kernel {
    epoch: u64,
    customers: BTreeMap<i64, String>,
    orders: BTreeMap<i64, Order>,
    groups: BTreeMap<String, (i64, i128)>,
}

fn integers(batch: &RecordBatch, column: usize) -> Result<&Int64Array, &'static str> {
    batch
        .column(column)
        .as_any()
        .downcast_ref::<Int64Array>()
        .ok_or("expected non-null BIGINT")
}

impl Kernel {
    /// Ungrouped COUNT returns exactly one Arrow row even for empty input.
    pub fn ungrouped_count(&self) -> Result<Int64Array, &'static str> {
        let count = self.groups.values().try_fold(0_i64, |n, (count, _)| {
            n.checked_add(*count).ok_or("count overflow")
        })?;
        Ok(Int64Array::from(vec![count]))
    }

    pub fn result(&self) -> &BTreeMap<String, (i64, i128)> {
        &self.groups
    }

    fn adjust(&mut self, region: &str, cents: i64, weight: i64) -> Result<(), &'static str> {
        let (count, sum) = self.groups.get(region).copied().unwrap_or_default();
        let count = count.checked_add(weight).ok_or("count overflow")?;
        let sum = sum
            .checked_add(
                i128::from(cents)
                    .checked_mul(i128::from(weight))
                    .ok_or("sum overflow")?,
            )
            .ok_or("sum overflow")?;
        if count < 0 || (count == 0 && sum != 0) {
            return Err("invalid group");
        }
        if count == 0 {
            self.groups.remove(region);
        } else {
            self.groups.insert(region.to_owned(), (count, sum));
        }
        Ok(())
    }

    /// One interval at a time; inputs are weighted Arrow batches in normalized order.
    /// Customer columns: id, region, weight. Order columns: id, customer, cents, weight.
    pub fn apply(
        &mut self,
        epoch: u64,
        customers: &RecordBatch,
        orders: &RecordBatch,
    ) -> Result<(), &'static str> {
        if epoch != self.epoch {
            return Err("unexpected epoch");
        }
        if customers.num_columns() != 3 || orders.num_columns() != 4 {
            return Err("invalid schema");
        }
        let size = customers
            .get_array_memory_size()
            .checked_add(orders.get_array_memory_size())
            .ok_or("input size overflow")?;
        if size > MAX_INPUT_BYTES
            || customers
                .num_rows()
                .checked_add(orders.num_rows())
                .ok_or("input size overflow")?
                > MAX_ROWS
        {
            return Err("input limit");
        }
        if customers
            .columns()
            .iter()
            .chain(orders.columns())
            .any(|a| a.null_count() != 0)
        {
            return Err("null input");
        }
        let ids = integers(customers, 0)?;
        let regions = customers
            .column(1)
            .as_any()
            .downcast_ref::<StringArray>()
            .ok_or("expected UTF8")?;
        let weights = integers(customers, 2)?;
        let order_ids = integers(orders, 0)?;
        let order_customers = integers(orders, 1)?;
        let cents = integers(orders, 2)?;
        let order_weights = integers(orders, 3)?;
        if customers.schema().field(1).data_type() != &DataType::Utf8 {
            return Err("expected UTF8");
        }
        let mut next = self.clone();
        for i in 0..customers.num_rows() {
            let id = ids.value(i);
            let region = regions.value(i);
            let weight = weights.value(i);
            if region.len() > MAX_REGION_BYTES {
                return Err("region limit");
            }
            match weight {
                1 if !next.customers.contains_key(&id) => {
                    next.customers.insert(id, region.to_owned());
                }
                -1 if next.customers.get(&id).is_some_and(|r| r == region) => {
                    next.customers.remove(&id);
                }
                _ => return Err("invalid customer delta"),
            }
            let matching: Vec<i64> = next
                .orders
                .values()
                .filter(|o| o.customer == id)
                .map(|o| o.cents)
                .collect();
            for amount in matching {
                next.adjust(region, amount, weight)?;
            }
            if next
                .customers
                .len()
                .checked_add(next.orders.len())
                .ok_or("state size overflow")?
                > MAX_ROWS
            {
                return Err("state limit");
            }
        }
        for i in 0..orders.num_rows() {
            let id = order_ids.value(i);
            let order = Order {
                customer: order_customers.value(i),
                cents: cents.value(i),
            };
            let weight = order_weights.value(i);
            if order.cents.unsigned_abs() > 999_999_999_999_999_999 {
                return Err("amount out of range");
            }
            match weight {
                1 if !next.orders.contains_key(&id) => {
                    next.orders.insert(id, order.clone());
                }
                -1 if next.orders.get(&id) == Some(&order) => {
                    next.orders.remove(&id);
                }
                _ => return Err("invalid order delta"),
            }
            if let Some(region) = next.customers.get(&order.customer).cloned() {
                next.adjust(&region, order.cents, weight)?;
            }
            if next
                .customers
                .len()
                .checked_add(next.orders.len())
                .ok_or("state size overflow")?
                > MAX_ROWS
            {
                return Err("state limit");
            }
        }
        next.epoch = next.epoch.checked_add(1).ok_or("epoch overflow")?;
        *self = next;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    fn customers(rows: &[(i64, &str, i64)]) -> RecordBatch {
        RecordBatch::try_from_iter(vec![
            (
                "id",
                Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.0))) as _,
            ),
            (
                "region",
                Arc::new(StringArray::from_iter_values(rows.iter().map(|r| r.1))) as _,
            ),
            (
                "weight",
                Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.2))) as _,
            ),
        ])
        .unwrap()
    }
    fn orders(rows: &[(i64, i64, i64, i64)]) -> RecordBatch {
        RecordBatch::try_from_iter(vec![
            (
                "id",
                Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.0))) as _,
            ),
            (
                "customer",
                Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.1))) as _,
            ),
            (
                "cents",
                Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.2))) as _,
            ),
            (
                "weight",
                Arc::new(Int64Array::from_iter_values(rows.iter().map(|r| r.3))) as _,
            ),
        ])
        .unwrap()
    }

    #[test]
    fn frozen_w1g_all_cuts() {
        let mut kernel = Kernel::default();
        assert!(kernel.result().is_empty());
        assert_eq!(kernel.ungrouped_count().unwrap().values(), &[0]);
        let input = include_str!("../../../fixtures/w1g/transactions.csv");
        let expected = include_str!("../../../fixtures/w1g/expected.csv");
        for epoch in 0..4 {
            let mut c = Vec::new();
            let mut o = Vec::new();
            for line in input
                .lines()
                .filter(|l| !l.starts_with('#') && !l.is_empty())
            {
                let f: Vec<_> = line.split(',').collect();
                if f[0].parse::<u64>().unwrap() != epoch {
                    continue;
                }
                let weight = f[2].parse().unwrap();
                let id = f[3].parse().unwrap();
                match f[1] {
                    "customer" => c.push((id, f[4], weight)),
                    "order" => o.push((id, f[4].parse().unwrap(), f[5].parse().unwrap(), weight)),
                    _ => panic!("unknown relation"),
                }
            }
            kernel.apply(epoch, &customers(&c), &orders(&o)).unwrap();
            let mut want = BTreeMap::new();
            for line in expected
                .lines()
                .filter(|l| !l.starts_with('#') && !l.is_empty())
            {
                let f: Vec<_> = line.split(',').collect();
                if f[0].parse::<u64>().unwrap() == epoch + 1 {
                    want.insert(
                        f[1].to_owned(),
                        (f[2].parse().unwrap(), f[3].parse().unwrap()),
                    );
                }
            }
            assert_eq!(kernel.result(), &want, "cut {}", epoch + 1);
        }
        assert_eq!(kernel.ungrouped_count().unwrap().values(), &[0]);
    }

    #[test]
    fn limits_and_bad_preimages_reject_the_whole_interval() {
        let mut kernel = Kernel::default();
        let before = kernel.clone();
        assert_eq!(
            kernel.apply(1, &customers(&[]), &orders(&[])),
            Err("unexpected epoch")
        );
        let too_many = vec![(1, "North", 1); MAX_ROWS + 1];
        assert!(
            kernel
                .apply(0, &customers(&too_many), &orders(&[]))
                .is_err()
        );
        assert!(
            kernel
                .apply(
                    0,
                    &customers(&[(1, "North", 1), (1, "South", -1)]),
                    &orders(&[])
                )
                .is_err()
        );
        assert_eq!(
            kernel.apply(0, &customers(&[]), &orders(&[(1, 1, i64::MAX, 1)])),
            Err("amount out of range")
        );
        assert_eq!(kernel, before);
        kernel
            .apply(0, &customers(&[(1, "North", 1)]), &orders(&[]))
            .unwrap();
    }
}
