//! Bounded, single-interval W1-G incremental kernel spike.
use arrow_array::{Array, Decimal128Array, Int64Array, RecordBatch, StringArray};
use arrow_buffer::{Buffer, OffsetBuffer};
use arrow_schema::{DataType, Field, Schema, SchemaRef};
use std::borrow::Borrow;
#[cfg(test)]
use std::collections::BTreeMap;
use std::sync::{
    Arc, OnceLock,
    atomic::{AtomicUsize, Ordering},
};

const MAX_ROWS: usize = 128;
const MAX_REGION_BYTES: usize = 32;
const MAX_INPUT_BYTES: usize = 16 * 1024;
const MAX_OUTPUT_ROWS: usize = 2 * MAX_ROWS;
const MAX_IN_FLIGHT_OUTPUTS: usize = 2;
const OUTPUT_ROW_BYTES: usize = MAX_REGION_BYTES
    + std::mem::size_of::<i32>()
    + 2 * std::mem::size_of::<i64>()
    + std::mem::size_of::<i128>();
const MAX_OUTPUT_SCRATCH_BYTES: usize =
    MAX_OUTPUT_ROWS * OUTPUT_ROW_BYTES + std::mem::size_of::<i32>();

fn output_schema() -> &'static SchemaRef {
    static SCHEMA: OnceLock<SchemaRef> = OnceLock::new();
    SCHEMA.get_or_init(|| {
        Arc::new(Schema::new(vec![
            Field::new("region", DataType::Utf8, false),
            Field::new("count", DataType::Int64, false),
            Field::new("revenue", DataType::Decimal128(38, 2), false),
            Field::new("weight", DataType::Int64, false),
        ]))
    })
}

fn reserve<T>(buffer: &mut Vec<T>, rows: usize) -> Result<(), &'static str> {
    buffer
        .try_reserve_exact(rows)
        .map_err(|_| "allocation failed")
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Region {
    bytes: [u8; MAX_REGION_BYTES],
    len: usize,
}

impl Region {
    fn new(value: &str) -> Result<Self, &'static str> {
        if value.len() > MAX_REGION_BYTES {
            return Err("region limit");
        }
        let mut bytes = [0; MAX_REGION_BYTES];
        bytes[..value.len()].copy_from_slice(value.as_bytes());
        Ok(Self {
            bytes,
            len: value.len(),
        })
    }

    fn as_str(&self) -> &str {
        std::str::from_utf8(&self.bytes[..self.len]).expect("region originates from UTF-8")
    }
}

impl Borrow<str> for Region {
    fn borrow(&self) -> &str {
        self.as_str()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct FixedMap<K, V> {
    entries: [Option<(K, V)>; MAX_ROWS],
    len: usize,
}

impl<K, V> Default for FixedMap<K, V> {
    fn default() -> Self {
        Self {
            entries: std::array::from_fn(|_| None),
            len: 0,
        }
    }
}

impl<K, V> FixedMap<K, V> {
    fn len(&self) -> usize {
        self.len
    }
    fn iter(&self) -> impl Iterator<Item = (&K, &V)> {
        self.entries
            .iter()
            .filter_map(|entry| entry.as_ref().map(|(k, v)| (k, v)))
    }
    fn values(&self) -> impl Iterator<Item = &V> {
        self.iter().map(|(_, value)| value)
    }
    fn get<Q: ?Sized + Eq>(&self, key: &Q) -> Option<&V>
    where
        K: Borrow<Q>,
    {
        self.iter()
            .find(|(k, _)| <K as Borrow<Q>>::borrow(*k) == key)
            .map(|(_, v)| v)
    }
    fn get_mut<Q: ?Sized + Eq>(&mut self, key: &Q) -> Option<&mut V>
    where
        K: Borrow<Q>,
    {
        self.entries
            .iter_mut()
            .filter_map(Option::as_mut)
            .find(|(k, _)| k.borrow() == key)
            .map(|(_, v)| v)
    }
    fn contains_key<Q: ?Sized + Eq>(&self, key: &Q) -> bool
    where
        K: Borrow<Q>,
    {
        self.get(key).is_some()
    }
    fn remove<Q: ?Sized + Eq>(&mut self, key: &Q)
    where
        K: Borrow<Q>,
    {
        if let Some(entry) = self
            .entries
            .iter_mut()
            .find(|entry| entry.as_ref().is_some_and(|(k, _)| k.borrow() == key))
        {
            *entry = None;
            self.len -= 1;
        }
    }
    fn insert(&mut self, key: K, value: V) -> Result<(), &'static str> {
        let entry = self
            .entries
            .iter_mut()
            .find(|entry| entry.is_none())
            .ok_or("state limit")?;
        *entry = Some((key, value));
        self.len += 1;
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Order {
    customer: i64,
    cents: i64,
}

#[derive(Debug, Default)]
pub struct OutputBudget(AtomicUsize);

impl OutputBudget {
    fn reserve(self: &Arc<Self>) -> Result<Ticket, &'static str> {
        self.reserve_at(self.0.load(Ordering::Acquire))
    }

    fn reserve_at(self: &Arc<Self>, observed: usize) -> Result<Ticket, &'static str> {
        if observed >= MAX_IN_FLIGHT_OUTPUTS {
            return Err("output backlog limit");
        }
        match self
            .0
            .compare_exchange(observed, observed + 1, Ordering::AcqRel, Ordering::Acquire)
        {
            Ok(_) => Ok(Ticket(self.clone())),
            Err(current) if current >= MAX_IN_FLIGHT_OUTPUTS => Err("output backlog limit"),
            Err(_) => Err("output contention limit"),
        }
    }
}

#[derive(Debug)]
struct Ticket(Arc<OutputBudget>);
impl Drop for Ticket {
    fn drop(&mut self) {
        let previous = self.0.0.fetch_sub(1, Ordering::AcqRel);
        assert!(previous > 0, "output reservation underflow");
    }
}

#[derive(Debug)]
struct OutputOwner {
    regions: Vec<u8>,
    offsets: Vec<i32>,
    counts: Vec<i64>,
    sums: Vec<i128>,
    weights: Vec<i64>,
    _ticket: Ticket,
}

impl OutputOwner {
    #[allow(unsafe_code)]
    fn buffers(self: Arc<Self>) -> [Buffer; 5] {
        macro_rules! buffer {
            ($field:ident) => {{
                let slice = &self.$field;
                let ptr = std::ptr::NonNull::new(slice.as_ptr() as *mut u8)
                    .expect("Vec pointers are non-null");
                let len = std::mem::size_of_val(slice.as_slice());
                // SAFETY: the immutable Vec remains owned by the Arc retained by
                // the Buffer. Its pointer is aligned and valid for initialized bytes.
                unsafe { Buffer::from_custom_allocation(ptr, len, self.clone()) }
            }};
        }
        [
            buffer!(regions),
            buffer!(offsets),
            buffer!(counts),
            buffer!(sums),
            buffer!(weights),
        ]
    }
}

/// A kernel must receive the output budget shared by its runtime.
///
/// ```compile_fail
/// let _ = w1g_kernel::Kernel::default();
/// ```
#[derive(Debug)]
pub struct Kernel {
    epoch: u64,
    customers: FixedMap<i64, Region>,
    orders: FixedMap<i64, Order>,
    groups: FixedMap<Region, (i64, i128)>,
    budget: Arc<OutputBudget>,
}

fn integers(batch: &RecordBatch, column: usize) -> Result<&Int64Array, &'static str> {
    batch
        .column(column)
        .as_any()
        .downcast_ref::<Int64Array>()
        .ok_or("expected non-null BIGINT")
}

impl Kernel {
    fn fork_state(&self) -> Self {
        Self {
            epoch: self.epoch,
            customers: self.customers.clone(),
            orders: self.orders.clone(),
            groups: self.groups.clone(),
            budget: self.budget.clone(),
        }
    }

    pub fn with_budget(budget: Arc<OutputBudget>) -> Self {
        Self {
            epoch: 0,
            customers: Default::default(),
            orders: Default::default(),
            groups: Default::default(),
            budget,
        }
    }

    /// Ungrouped COUNT returns exactly one Arrow row even for empty input.
    pub fn ungrouped_count(&mut self) -> Result<Int64Array, &'static str> {
        let count = self.groups.values().try_fold(0_i64, |n, (count, _)| {
            n.checked_add(*count).ok_or("count overflow")
        })?;
        let ticket = self.budget.reserve()?;
        let mut values = Vec::new();
        reserve(&mut values, 1)?;
        if values
            .capacity()
            .checked_mul(std::mem::size_of::<i64>())
            .ok_or("scratch size overflow")?
            > MAX_OUTPUT_SCRATCH_BYTES
        {
            return Err("scratch limit");
        }
        values.push(count);
        let owner = Arc::new(OutputOwner {
            regions: vec![],
            offsets: vec![],
            counts: values,
            sums: vec![],
            weights: vec![],
            _ticket: ticket,
        });
        let buffers = owner.buffers();
        Ok(Int64Array::new(buffers[2].clone().into(), None))
    }

    pub fn result(&self) -> impl Iterator<Item = (&str, (i64, i128))> {
        self.groups
            .iter()
            .map(|(region, value)| (region.as_str(), *value))
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
            self.groups.insert(Region::new(region)?, (count, sum))?;
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
        // A retained buffer remains charged through all Arrow array and slice clones.
        let ticket = self.budget.reserve()?;
        // shortcut: Arrow wrapper allocations remain unaccounted, reserve them before promotion.
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
        let requested = output_rows
            .checked_mul(OUTPUT_ROW_BYTES)
            .and_then(|n| n.checked_add(std::mem::size_of::<i32>()))
            .ok_or("scratch size overflow")?;
        if requested > scratch_limit {
            return Err("scratch limit");
        }
        let mut regions = Vec::<u8>::new();
        let mut offsets = Vec::<i32>::new();
        let mut counts = Vec::<i64>::new();
        let mut sums = Vec::<i128>::new();
        let mut weights = Vec::<i64>::new();
        reserve(
            &mut regions,
            output_rows
                .checked_mul(MAX_REGION_BYTES)
                .ok_or("scratch size overflow")?,
        )?;
        reserve(
            &mut offsets,
            output_rows.checked_add(1).ok_or("scratch size overflow")?,
        )?;
        reserve(&mut counts, output_rows)?;
        reserve(&mut sums, output_rows)?;
        reserve(&mut weights, output_rows)?;
        let scratch_bytes = regions
            .capacity()
            .checked_add(
                offsets
                    .capacity()
                    .checked_mul(std::mem::size_of::<i32>())
                    .ok_or("scratch size overflow")?,
            )
            .and_then(|n| n.checked_add(counts.capacity().checked_mul(std::mem::size_of::<i64>())?))
            .and_then(|n| n.checked_add(sums.capacity().checked_mul(std::mem::size_of::<i128>())?))
            .and_then(|n| {
                n.checked_add(weights.capacity().checked_mul(std::mem::size_of::<i64>())?)
            })
            .ok_or("scratch size overflow")?;
        if scratch_bytes > scratch_limit {
            return Err("scratch limit");
        }
        offsets.push(0);
        let mut next = self.fork_state();
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
                    next.customers.insert(id, Region::new(region)?)?;
                }
                -1 if next
                    .customers
                    .get(&id)
                    .is_some_and(|r| r.as_str() == region) =>
                {
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
                    next.orders.insert(id, order)?;
                }
                -1 if next.orders.get(&id) == Some(&order) => {
                    next.orders.remove(&id);
                }
                _ => return Err("invalid order delta"),
            }
            if let Some(region) = next.customers.get(&order.customer) {
                let region = *region;
                next.adjust(region.as_str(), order.cents, weight)?;
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
        for (region, old) in self.groups.iter() {
            if next.groups.get(region.as_str()) != Some(old) {
                regions.extend_from_slice(region.as_str().as_bytes());
                offsets.push(i32::try_from(regions.len()).map_err(|_| "output size overflow")?);
                counts.push(old.0);
                sums.push(old.1);
                weights.push(-1);
            }
        }
        for (region, new) in next.groups.iter() {
            if self.groups.get(region.as_str()) != Some(new) {
                regions.extend_from_slice(region.as_str().as_bytes());
                offsets.push(i32::try_from(regions.len()).map_err(|_| "output size overflow")?);
                counts.push(new.0);
                sums.push(new.1);
                weights.push(1);
            }
        }
        let owner = Arc::new(OutputOwner {
            regions,
            offsets,
            counts,
            sums,
            weights,
            _ticket: ticket,
        });
        let buffers = owner.buffers();
        let regions = StringArray::try_new(
            OffsetBuffer::new(buffers[1].clone().into()),
            buffers[0].clone(),
            None,
        )
        .map_err(|_| "invalid string output")?;
        let decimal = Decimal128Array::new(buffers[3].clone().into(), None)
            .with_precision_and_scale(38, 2)
            .map_err(|_| "invalid decimal output")?;
        let output = RecordBatch::try_new(
            output_schema().clone(),
            vec![
                Arc::new(regions),
                Arc::new(Int64Array::new(buffers[2].clone().into(), None)),
                Arc::new(decimal),
                Arc::new(Int64Array::new(buffers[4].clone().into(), None)),
            ],
        )
        .map_err(|_| "invalid output batch")?;
        *self = next;
        Ok(output)
    }
}

#[cfg(test)]
impl PartialEq for Kernel {
    fn eq(&self, other: &Self) -> bool {
        self.epoch == other.epoch
            && self.customers == other.customers
            && self.orders == other.orders
            && self.groups == other.groups
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn kernel() -> Kernel {
        Kernel::with_budget(Arc::new(OutputBudget::default()))
    }

    fn snapshot(kernel: &Kernel) -> BTreeMap<String, (i64, i128)> {
        kernel
            .result()
            .map(|(region, row)| (region.to_owned(), row))
            .collect()
    }

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
        let mut kernel = kernel();
        assert_eq!(kernel.result().count(), 0);
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
                snapshot(&kernel),
                oracle,
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
            assert_eq!(snapshot(&kernel), want, "cut {}", epoch + 1);
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
        let mut kernel = kernel();
        let before = kernel.fork_state();
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
        let mut kernel = kernel();
        let before = kernel.fork_state();
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
    fn fixed_storage_reuses_slots_and_preserves_utf8_keys() {
        let mut map = FixedMap::<i64, Region>::default();
        for id in 0..MAX_ROWS as i64 {
            map.insert(id, Region::new("é\0x").unwrap()).unwrap();
        }
        assert_eq!(
            map.insert(999, Region::new("x").unwrap()),
            Err("state limit")
        );
        assert_eq!(map.len(), MAX_ROWS);
        assert_eq!(map.get(&0).unwrap().as_str(), "é\0x");
        map.remove(&0);
        map.insert(999, Region::new("x").unwrap()).unwrap();
        assert_eq!(map.len(), MAX_ROWS);
        assert!(map.get(&0).is_none());
        assert_eq!(map.get(&999).unwrap().as_str(), "x");
        assert_eq!(Region::new(&"é".repeat(17)), Err("region limit"));
    }

    #[test]
    fn arrow_output_preserves_multibyte_and_embedded_null() {
        let mut kernel = kernel();
        let output = kernel
            .apply(0, &customers(&[(1, "é\0x", 1)]), &orders(&[(2, 1, 100, 1)]))
            .unwrap();
        let regions = output
            .column(0)
            .as_any()
            .downcast_ref::<StringArray>()
            .unwrap();
        assert_eq!(regions.value(0), "é\0x");
    }

    #[test]
    fn retained_arrow_slices_hold_output_admission() {
        let mut kernel = kernel();
        let empty_customers = customers(&[]);
        let empty_orders = orders(&[]);
        let first = kernel
            .apply(0, &customers(&[(1, "N", 1)]), &orders(&[(2, 1, 100, 1)]))
            .unwrap();
        let retained = first.column(0).slice(0, 1);
        drop(first);
        let second = kernel.apply(1, &empty_customers, &empty_orders).unwrap();
        let before = kernel.fork_state();
        assert_eq!(
            kernel.apply(2, &empty_customers, &empty_orders),
            Err("output backlog limit")
        );
        assert_eq!(kernel, before);
        drop(retained);
        let third = kernel.apply(2, &empty_customers, &empty_orders).unwrap();
        drop((second, third));
        assert!(kernel.apply(3, &empty_customers, &empty_orders).is_ok());
    }

    #[test]
    fn extracted_buffer_and_count_outputs_consume_slots() {
        let mut kernel = kernel();
        let empty_customers = customers(&[]);
        let empty_orders = orders(&[]);
        let batch = kernel
            .apply(0, &customers(&[(1, "N", 1)]), &orders(&[(2, 1, 100, 1)]))
            .unwrap();
        let extracted = batch.column(1).to_data().buffers()[0].slice_with_length(0, 0);
        drop(batch);
        let count = kernel.ungrouped_count().unwrap();
        assert_eq!(count.values(), &[1]);
        assert_eq!(
            kernel.apply(1, &empty_customers, &empty_orders),
            Err("output backlog limit")
        );
        drop(extracted);
        let next = kernel.apply(1, &empty_customers, &empty_orders).unwrap();
        drop(next);
        drop(count);
        assert!(kernel.apply(2, &empty_customers, &empty_orders).is_ok());
    }

    #[test]
    fn forgotten_output_remains_charged() {
        let mut kernel = kernel();
        let empty_customers = customers(&[]);
        let empty_orders = orders(&[]);
        std::mem::forget(kernel.apply(0, &empty_customers, &empty_orders).unwrap());
        std::mem::forget(kernel.ungrouped_count().unwrap());
        assert_eq!(
            kernel.apply(1, &empty_customers, &empty_orders),
            Err("output backlog limit")
        );
    }

    #[test]
    fn shared_budget_outlives_destroyed_kernel_and_slices() {
        let budget = Arc::new(OutputBudget::default());
        let empty_customers = customers(&[]);
        let empty_orders = orders(&[]);
        let retained = {
            let mut first = Kernel::with_budget(budget.clone());
            let output = first
                .apply(0, &customers(&[(1, "N", 1)]), &orders(&[(2, 1, 100, 1)]))
                .unwrap();
            output.column(1).to_data().buffers()[0].slice_with_length(0, 0)
        };
        let mut second = Kernel::with_budget(budget);
        let other = second.apply(0, &empty_customers, &empty_orders).unwrap();
        let before = second.fork_state();
        assert_eq!(
            second.apply(1, &empty_customers, &empty_orders),
            Err("output backlog limit")
        );
        assert_eq!(second, before);
        drop(retained);
        let retry = second.apply(1, &empty_customers, &empty_orders).unwrap();
        drop((other, retry));
    }

    #[test]
    fn live_kernels_compete_for_their_shared_output_budget() {
        let budget = Arc::new(OutputBudget::default());
        let mut first = Kernel::with_budget(budget.clone());
        let mut second = Kernel::with_budget(budget);
        let first_output = first.ungrouped_count().unwrap();
        let second_output = second.ungrouped_count().unwrap();
        assert_eq!(first.ungrouped_count(), Err("output backlog limit"));
        drop(second_output);
        assert!(first.ungrouped_count().is_ok());
        drop(first_output);
    }

    #[test]
    fn failed_scratch_admission_releases_shared_ticket() {
        let budget = Arc::new(OutputBudget::default());
        let mut kernel = Kernel::with_budget(budget.clone());
        let before = kernel.fork_state();
        assert_eq!(
            kernel.apply_with_scratch_limit(0, &customers(&[(1, "N", 1)]), &orders(&[]), 0),
            Err("scratch limit")
        );
        assert_eq!(kernel, before);
        assert_eq!(budget.0.load(Ordering::Acquire), 0);
        assert!(kernel.apply(0, &customers(&[]), &orders(&[])).is_ok());
    }

    #[test]
    fn late_order_error_releases_shared_ticket_and_state() {
        let budget = Arc::new(OutputBudget::default());
        let mut kernel = Kernel::with_budget(budget.clone());
        let before = kernel.fork_state();
        assert_eq!(
            kernel.apply(0, &customers(&[(1, "N", 1)]), &orders(&[(2, 1, 100, -1)])),
            Err("invalid order delta")
        );
        assert_eq!(kernel, before);
        assert_eq!(budget.0.load(Ordering::Acquire), 0);
        assert!(kernel.apply(0, &customers(&[]), &orders(&[])).is_ok());
    }

    #[test]
    fn competing_reservations_are_bounded() {
        let budget = Arc::new(OutputBudget::default());
        let barrier = Arc::new(std::sync::Barrier::new(9));
        let handles: Vec<_> = (0..8)
            .map(|_| {
                let budget = budget.clone();
                let barrier = barrier.clone();
                std::thread::spawn(move || {
                    barrier.wait();
                    let reservation = budget.reserve();
                    barrier.wait();
                    reservation.is_ok()
                })
            })
            .collect();
        barrier.wait();
        barrier.wait();
        let admitted = handles
            .into_iter()
            .map(|h| h.join().unwrap())
            .filter(|ok| *ok)
            .count();
        assert!((1..=MAX_IN_FLIGHT_OUTPUTS).contains(&admitted));
        assert_eq!(budget.0.load(Ordering::Acquire), 0);
    }

    #[test]
    fn stale_reservation_observation_returns_contention_without_leaking() {
        let budget = Arc::new(OutputBudget::default());
        let first = budget.reserve().unwrap();
        assert_eq!(budget.reserve_at(0).unwrap_err(), "output contention limit");
        let second = budget.reserve().unwrap();
        assert_eq!(budget.reserve_at(0).unwrap_err(), "output backlog limit");
        assert_eq!(budget.0.load(Ordering::Acquire), MAX_IN_FLIGHT_OUTPUTS);
        drop((first, second));
        assert_eq!(budget.0.load(Ordering::Acquire), 0);
        assert!(budget.reserve().is_ok());
    }

    #[test]
    fn count_slice_outlives_producer_and_retains_budget() {
        let budget = Arc::new(OutputBudget::default());
        let retained = {
            let mut producer = Kernel::with_budget(budget.clone());
            producer.ungrouped_count().unwrap().slice(0, 0)
        };
        let mut other = Kernel::with_budget(budget.clone());
        let second = other.ungrouped_count().unwrap();
        assert_eq!(budget.reserve().unwrap_err(), "output backlog limit");
        drop(retained);
        assert!(budget.reserve().is_ok());
        drop(second);
    }

    #[test]
    fn output_scratch_limit_rejects_atomically_before_growth() {
        let mut kernel = kernel();
        let before = kernel.fork_state();
        let input = customers(&[(1, "N", 1)]);
        let empty = orders(&[]);
        let one_row = OUTPUT_ROW_BYTES + std::mem::size_of::<i32>();
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
        let mut kernel = kernel();
        let rows: Vec<_> = (0..MAX_ROWS).map(|id| (id as i64, "N", 1)).collect();
        kernel.apply(0, &customers(&rows), &orders(&[])).unwrap();
        let before = kernel.fork_state();
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
        let mut kernel = kernel();
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
        assert_eq!(kernel.result().count(), 64);
        assert!(kernel.result().all(|(_, row)| row == (1, 100)));
        let before = kernel.fork_state();
        assert_eq!(
            kernel.apply(2, &customers(&[(999, "N", 1)]), &orders(&[])),
            Err("state limit")
        );
        assert_eq!(kernel, before);
    }

    #[test]
    fn bounded_fanout_repeated_retractions_match_batch_oracle() {
        let mut kernel = kernel();
        let initial_orders: Vec<_> = (0..127).map(|id| (id, 1, 100, 1)).collect();
        kernel
            .apply(0, &customers(&[(1, "N", 1)]), &orders(&initial_orders))
            .unwrap();

        let changes: Vec<_> = (0..MAX_ROWS)
            .map(|i| {
                (
                    1,
                    if i + 1 == MAX_ROWS { "S" } else { "N" },
                    if i % 2 == 0 { -1 } else { 1 },
                )
            })
            .collect();
        let delta = kernel.apply(1, &customers(&changes), &orders(&[])).unwrap();
        assert_eq!(delta.num_rows(), 2);
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
        let actual: BTreeMap<_, _> = (0..delta.num_rows())
            .map(|i| {
                (
                    regions.value(i),
                    (counts.value(i), sums.value(i), weights.value(i)),
                )
            })
            .collect();
        assert_eq!(
            actual,
            BTreeMap::from([("N", (127, 12_700, -1)), ("S", (127, 12_700, 1))])
        );

        let oracle_customers = BTreeMap::from([(1, "S".to_owned())]);
        let oracle_orders = (0..127).map(|id| (id, (1, 100))).collect();
        let expected = w1g_oracle::evaluate(&oracle_customers, &oracle_orders)
            .into_iter()
            .map(|(region, (count, cents))| (region, (count, i128::from(cents))))
            .collect();
        assert_eq!(snapshot(&kernel), expected);
        assert_eq!(kernel.ungrouped_count().unwrap().values(), &[127]);
    }
}
