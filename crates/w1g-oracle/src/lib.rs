//! Independent batch evaluation of the fixed W1-G input; no incremental operators.
use std::collections::BTreeMap;

pub fn evaluate(
    customers: &BTreeMap<i64, String>,
    orders: &BTreeMap<i64, (i64, i64)>,
) -> BTreeMap<String, (i64, i64)> {
    let mut groups = BTreeMap::<String, (i64, i64)>::new();
    for (customer, cents) in orders.values() {
        if let Some(region) = customers.get(customer) {
            let group = groups.entry(region.clone()).or_default();
            group.0 = group.0.checked_add(1).expect("W1-G count overflow");
            group.1 = group.1.checked_add(*cents).expect("W1-G sum overflow");
        }
    }
    groups
}

/// SQL ungrouped COUNT has one result row, including when no rows join.
pub fn ungrouped_count(
    customers: &BTreeMap<i64, String>,
    orders: &BTreeMap<i64, (i64, i64)>,
) -> [i64; 1] {
    [i64::try_from(
        orders
            .values()
            .filter(|(customer, _)| customers.contains_key(customer))
            .count(),
    )
    .expect("W1-G count overflow")]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Clone, Debug, PartialEq, Eq)]
    enum Row {
        Customer { id: i64, region: String },
        Order { id: i64, customer: i64, cents: i64 },
    }

    #[test]
    fn batch_matches_frozen_cuts() {
        let fixture = include_str!("../../../fixtures/w1g/transactions.csv");
        let expected = include_str!("../../../fixtures/w1g/expected.csv");
        let mut cuts = BTreeMap::<u8, BTreeMap<String, (i64, i64)>>::new();
        for line in expected
            .lines()
            .filter(|line| !line.starts_with('#') && !line.is_empty())
        {
            let fields: Vec<_> = line.split(',').collect();
            cuts.entry(fields[0].parse().unwrap()).or_default().insert(
                fields[1].into(),
                (fields[2].parse().unwrap(), fields[3].parse().unwrap()),
            );
        }
        let mut customers = BTreeMap::new();
        let mut orders = BTreeMap::new();
        assert_eq!(evaluate(&customers, &orders), BTreeMap::new());
        assert_eq!(ungrouped_count(&customers, &orders), [0]);
        let mut current_epoch = 0;
        let expected_counts = [3, 3, 2, 0];
        for line in fixture
            .lines()
            .filter(|line| !line.starts_with('#') && !line.is_empty())
        {
            let f: Vec<_> = line.split(',').collect();
            let epoch: u8 = f[0].parse().unwrap();
            if epoch != current_epoch {
                assert_eq!(
                    evaluate(&customers, &orders),
                    cuts.remove(&(current_epoch + 1)).unwrap_or_default()
                );
                assert_eq!(
                    ungrouped_count(&customers, &orders),
                    [expected_counts[usize::from(current_epoch)]]
                );
                assert_eq!(epoch, current_epoch + 1);
                current_epoch = epoch;
            }
            let weight: i8 = f[2].parse().unwrap();
            let id: i64 = f[3].parse().unwrap();
            let row = match f[1] {
                "customer" => Row::Customer {
                    id,
                    region: f[4].into(),
                },
                "order" => Row::Order {
                    id,
                    customer: f[4].parse().unwrap(),
                    cents: f[5].parse().unwrap(),
                },
                _ => panic!("unknown relation"),
            };
            match (weight, row) {
                (1, Row::Customer { id, region }) => {
                    assert!(customers.insert(id, region).is_none())
                }
                (-1, Row::Customer { id, region }) => {
                    assert_eq!(customers.remove(&id), Some(region))
                }
                (
                    1,
                    Row::Order {
                        id,
                        customer,
                        cents,
                    },
                ) => assert!(orders.insert(id, (customer, cents)).is_none()),
                (
                    -1,
                    Row::Order {
                        id,
                        customer,
                        cents,
                    },
                ) => assert_eq!(orders.remove(&id), Some((customer, cents))),
                _ => panic!("invalid fixture weight"),
            }
        }
        assert_eq!(current_epoch, 3);
        assert_eq!(
            evaluate(&customers, &orders),
            cuts.remove(&4).unwrap_or_default()
        );
        assert!(cuts.is_empty());
        assert_eq!(ungrouped_count(&customers, &orders), [0]);
    }
}
