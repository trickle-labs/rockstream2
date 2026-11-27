//! Bounded, single-interval W1-G incremental kernel spike.
use arrow_array::{Array, Decimal128Array, Int64Array, RecordBatch, StringArray};
use arrow_schema::DataType;
use std::collections::BTreeMap;
use std::sync::Arc;

const MAX_ROWS: usize = 128;
const MAX_REGION_BYTES: usize = 32;
const MAX_INPUT_BYTES: usize = 16 * 1024;
const MAX_OUTPUT_ROWS: usize = 2 * MAX_ROWS;
const MAX_OUTPUT_SCRATCH_BYTES: usize = MAX_OUTPUT_ROWS
    * (std::mem::size_of::<&str>() + 2 * std::mem::size_of::<i64>() + std::mem::size_of::<i128>());

fn reserve<T>(buffer: &mut Vec<T>, rows: usize) -> Result<(), &'static str> {
    buffer
        .try_reserve_exact(rows)
        .map_err(|_| "allocation failed")
}

fn copy_region(region: &str) -> Result<String, &'static str> {
    let mut copy = String::new();
    copy.try_reserve_exact(region.len())
        .map_err(|_| "allocation failed")?;
    copy.push_str(region);
    Ok(copy)
}

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
        } else if let Some(group) = self.groups.get_mut(region) {
            *group = (count, sum);
        } else {
            self.groups.insert(copy_region(region)?, (count, sum));
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
    ) -> Result<RecordBatch, &'static str> {
        self.apply_with_scratch_limit(epoch, customers, orders, MAX_OUTPUT_SCRATCH_BYTES)
    }

    fn apply_with_scratch_limit(
        &mut self,
        epoch: u64,
        customers: &RecordBatch,
        orders: &RecordBatch,
        scratch_limit: usize,
    ) -> Result<RecordBatch, &'static str> {
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
        let input_regions = customers
            .column(1)
            .as_any()
            .downcast_ref::<StringArray>()
            .ok_or("expected UTF8")?;
        let input_weights = integers(customers, 2)?;
        let order_ids = integers(orders, 0)?;
        let order_customers = integers(orders, 1)?;
        let cents = integers(orders, 2)?;
        let order_weights = integers(orders, 3)?;
        if customers.schema().field(1).data_type() != &DataType::Utf8 {
            return Err("expected UTF8");
        }
        // shortcut: map and Arrow allocations remain unaccounted, use a fallible pool before promotion.
        let possible_groups = self
            .customers
            .len()
            .checked_add(customers.num_rows())
            .ok_or("output size overflow")?
            .min(MAX_ROWS);
        let output_rows = self
            .groups
            .len()
            .checked_add(possible_groups)
            .ok_or("output size overflow")?;
        if output_rows > MAX_OUTPUT_ROWS {
            return Err("output limit");
        }
        let bytes_per_row = std::mem::size_of::<&str>()
            .checked_add(2 * std::mem::size_of::<i64>())
            .and_then(|n| n.checked_add(std::mem::size_of::<i128>()))
            .ok_or("scratch size overflow")?;
        let requested = output_rows
            .checked_mul(bytes_per_row)
            .ok_or("scratch size overflow")?;
        if requested > scratch_limit {
            return Err("scratch limit");
        }
        let mut regions = Vec::<&str>::new();
        let mut counts = Vec::<i64>::new();
        let mut sums = Vec::<i128>::new();
        let mut weights = Vec::<i64>::new();
        reserve(&mut regions, output_rows)?;
        reserve(&mut counts, output_rows)?;
        reserve(&mut sums, output_rows)?;
        reserve(&mut weights, output_rows)?;
        let scratch_bytes = regions
            .capacity()
            .checked_mul(std::mem::size_of::<&str>())
            .and_then(|v| {
                counts
                    .capacity()
                    .checked_mul(std::mem::size_of::<i64>())
                    .and_then(|n| v.checked_add(n))
            })
            .and_then(|v| {
                sums.capacity()
                    .checked_mul(std::mem::size_of::<i128>())
                    .and_then(|n| v.checked_add(n))
            })
            .and_then(|v| {
                weights
                    .capacity()
                    .checked_mul(std::mem::size_of::<i64>())
                    .and_then(|n| v.checked_add(n))
            })
            .ok_or("scratch size overflow")?;
        if scratch_bytes > scratch_limit {
            return Err("scratch limit");
        }
        let mut next = self.clone();
        for i in 0..customers.num_rows() {
            let id = ids.value(i);
            let region = input_regions.value(i);
            let weight = input_weights.value(i);
            if region.len() > MAX_REGION_BYTES {
                return Err("region limit");
            }
            match weight {
                1 if !next.customers.contains_key(&id) => {
                    if next.customers.len() + next.orders.len() >= MAX_ROWS {
                        return Err("state limit");
                    }
                    next.customers.insert(id, copy_region(region)?);
                }
                -1 if next.customers.get(&id).is_some_and(|r| r == region) => {
                    next.customers.remove(&id);
                }
                _ => return Err("invalid customer delta"),
            }
            let mut matching = [0_i64; MAX_ROWS];
            let mut matching_count = 0;
            for order in next.orders.values().filter(|o| o.customer == id) {
                if matching_count == matching.len() {
                    return Err("state limit");
                }
                matching[matching_count] = order.cents;
                matching_count += 1;
            }
            for &amount in &matching[..matching_count] {
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
                    if next.customers.len() + next.orders.len() >= MAX_ROWS {
                        return Err("state limit");
                    }
                    next.orders.insert(id, order.clone());
                }
                -1 if next.orders.get(&id) == Some(&order) => {
                    next.orders.remove(&id);
                }
                _ => return Err("invalid order delta"),
            }
            if let Some(region) = next.customers.get(&order.customer) {
                let region = copy_region(region)?;
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
        for (region, old) in &self.groups {
            if next.groups.get(region) != Some(old) {
                regions.push(region.as_str());
                counts.push(old.0);
                sums.push(old.1);
                weights.push(-1);
            }
        }
        for (region, new) in &next.groups {
            if self.groups.get(region) != Some(new) {
                regions.push(region.as_str());
                counts.push(new.0);
                sums.push(new.1);
                weights.push(1);
            }
        }
        let decimal = Decimal128Array::from(sums)
            .with_precision_and_scale(38, 2)
            .map_err(|_| "invalid decimal output")?;
        let output = RecordBatch::try_from_iter(vec![
            ("region", Arc::new(StringArray::from(regions)) as _),
            ("count", Arc::new(Int64Array::from(counts)) as _),
            ("revenue", Arc::new(decimal) as _),
            ("weight", Arc::new(Int64Array::from(weights)) as _),
        ])
        .map_err(|_| "invalid output batch")?;
        *self = next;
        Ok(output)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
        assert_eq!(
            kernel.ungrouped_count().unwrap().values(),
            &w1g_oracle::ungrouped_count(&BTreeMap::new(), &BTreeMap::new())
        );
        let mut observed = BTreeMap::<(String, i64, i128), i64>::new();
        let mut oracle_customers = BTreeMap::new();
        let mut oracle_orders = BTreeMap::new();
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
                    "customer" => {
                        c.push((id, f[4], weight));
                        if weight == 1 {
                            assert!(oracle_customers.insert(id, f[4].to_owned()).is_none());
                        } else {
                            assert_eq!(oracle_customers.remove(&id).as_deref(), Some(f[4]));
                        }
                    }
                    "order" => o.push((id, f[4].parse().unwrap(), f[5].parse().unwrap(), weight)),
                    _ => panic!("unknown relation"),
                }
            }
            for &(id, customer, cents, weight) in &o {
                if weight == 1 {
                    assert!(oracle_orders.insert(id, (customer, cents)).is_none());
                } else {
                    assert_eq!(oracle_orders.remove(&id), Some((customer, cents)));
                }
            }
            let delta = kernel.apply(epoch, &customers(&c), &orders(&o)).unwrap();
            let regions = delta
                .column(0)
                .as_any()
                .downcast_ref::<StringArray>()
                .unwrap();
            let counts = delta
                .column(1)
                .as_any()
                .downcast_ref::<Int64Array>()
                .unwrap();
            let sums = delta
                .column(2)
                .as_any()
                .downcast_ref::<Decimal128Array>()
                .unwrap();
            let weights = delta
                .column(3)
                .as_any()
                .downcast_ref::<Int64Array>()
                .unwrap();
            for i in 0..delta.num_rows() {
                *observed
                    .entry((regions.value(i).to_owned(), counts.value(i), sums.value(i)))
                    .or_default() += weights.value(i);
            }
            observed.retain(|_, weight| *weight != 0);
            let oracle = w1g_oracle::evaluate(&oracle_customers, &oracle_orders)
                .into_iter()
                .map(|(region, (count, cents))| (region, (count, i128::from(cents))))
                .collect::<BTreeMap<_, _>>();
            assert_eq!(
                kernel.result(),
                &oracle,
                "independent batch at cut {}",
                epoch + 1
            );
            assert_eq!(
                kernel.ungrouped_count().unwrap().values(),
                &w1g_oracle::ungrouped_count(&oracle_customers, &oracle_orders)
            );
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
            let expected_bag = want
                .iter()
                .map(|(region, (count, sum))| ((region.clone(), *count, *sum), 1))
                .collect::<BTreeMap<_, _>>();
            assert_eq!(observed, expected_bag, "Arrow output at cut {}", epoch + 1);
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
        let huge = "x".repeat(MAX_INPUT_BYTES + 1);
        assert_eq!(
            kernel.apply(0, &customers(&[(1, &huge, 1)]), &orders(&[])),
            Err("input limit")
        );
        assert_eq!(kernel, before);
        let too_many = vec![(1, "North", 1); MAX_ROWS + 1];
        assert_eq!(
            kernel.apply(0, &customers(&too_many), &orders(&[])),
            Err("input limit")
        );
        assert_eq!(
            kernel.apply(
                0,
                &customers(&[(1, "North", 1), (1, "South", -1)]),
                &orders(&[])
            ),
            Err("invalid customer delta")
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
    #[test]
    fn invalid_inputs_and_late_order_failure_are_atomic() {
        let mut kernel = Kernel::default();
        let before = kernel.clone();
        let null_customer = RecordBatch::try_from_iter(vec![
            ("id", Arc::new(Int64Array::from(vec![None])) as _),
            ("region", Arc::new(StringArray::from(vec!["N"])) as _),
            ("weight", Arc::new(Int64Array::from(vec![1])) as _),
        ])
        .unwrap();
        assert_eq!(
            kernel.apply(0, &null_customer, &orders(&[])),
            Err("null input")
        );
        let wrong_type = RecordBatch::try_from_iter(vec![
            ("id", Arc::new(StringArray::from(vec!["1"])) as _),
            ("region", Arc::new(StringArray::from(vec!["N"])) as _),
            ("weight", Arc::new(Int64Array::from(vec![1])) as _),
        ])
        .unwrap();
        assert_eq!(
            kernel.apply(0, &wrong_type, &orders(&[])),
            Err("expected non-null BIGINT")
        );
        assert_eq!(
            kernel.apply(0, &customers(&[(1, "N", 2)]), &orders(&[])),
            Err("invalid customer delta")
        );
        assert_eq!(
            kernel.apply(
                0,
                &customers(&[(1, "N", 1)]),
                &orders(&[(1, 1, 100, 1), (2, 1, 100, -1)])
            ),
            Err("invalid order delta")
        );
        assert_eq!(kernel, before);
    }

    #[test]
    fn output_scratch_limit_rejects_atomically_before_growth() {
        let mut kernel = Kernel::default();
        let before = kernel.clone();
        let input = customers(&[(1, "N", 1)]);
        let empty = orders(&[]);
        let one_row = std::mem::size_of::<&str>()
            + 2 * std::mem::size_of::<i64>()
            + std::mem::size_of::<i128>();
        assert_eq!(
            kernel.apply_with_scratch_limit(0, &input, &empty, one_row - 1),
            Err("scratch limit")
        );
        assert_eq!(kernel, before);
        kernel
            .apply_with_scratch_limit(0, &input, &empty, one_row)
            .unwrap();
    }

    #[test]
    fn output_scratch_reservation_failure_is_reported() {
        let mut rows = Vec::<i64>::new();
        assert_eq!(reserve(&mut rows, usize::MAX), Err("allocation failed"));
        assert!(rows.is_empty());
        assert_eq!(rows.capacity(), 0);
    }

    #[test]
    fn state_and_region_limits_leave_state_unchanged() {
        let mut kernel = Kernel::default();
        let rows: Vec<_> = (0..MAX_ROWS).map(|id| (id as i64, "N", 1)).collect();
        kernel.apply(0, &customers(&rows), &orders(&[])).unwrap();
        let before = kernel.clone();
        assert_eq!(
            kernel.apply(1, &customers(&[(999, "N", 1)]), &orders(&[])),
            Err("state limit")
        );
        assert_eq!(kernel, before);
        let long_region = "x".repeat(MAX_REGION_BYTES + 1);
        assert_eq!(
            kernel.apply(1, &customers(&[(999, &long_region, 1)]), &orders(&[])),
            Err("region limit")
        );
        assert_eq!(kernel, before);
    }
    #[test]
    fn configured_boundary_workload() {
        let mut kernel = Kernel::default();
        let old: Vec<_> = (0..64).map(|i| format!("old-{i:028}")).collect();
        let new: Vec<_> = (0..64).map(|i| format!("new-{i:028}")).collect();
        let initial: Vec<_> = old
            .iter()
            .enumerate()
            .map(|(i, region)| (i as i64, region.as_str(), 1))
            .collect();
        let initial_orders: Vec<_> = (0..64).map(|i| (i, i, 100, 1)).collect();
        kernel
            .apply(0, &customers(&initial), &orders(&initial_orders))
            .unwrap();
        let mut changes = Vec::new();
        for i in 0..64 {
            changes.push((i as i64, old[i].as_str(), -1));
            changes.push((i as i64, new[i].as_str(), 1));
        }
        let batch = kernel.apply(1, &customers(&changes), &orders(&[])).unwrap();
        assert_eq!(batch.num_rows(), 128);
        assert_eq!(kernel.result().len(), 64);
        assert!(kernel.result().values().all(|&row| row == (1, 100)));
        let before = kernel.clone();
        assert_eq!(
            kernel.apply(2, &customers(&[(999, "N", 1)]), &orders(&[])),
            Err("state limit")
        );
        assert_eq!(kernel, before);
    }
}
