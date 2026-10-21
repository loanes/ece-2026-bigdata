# PySpark RDD Lab

## Objective

The objective of this lab is to explore Apache Spark RDDs, transformations, actions, data aggregation, joins, DataFrames, and caching.

## Exercise 1 — Aggregate Data with `aggregateByKey`

### Objective

Calculate the number of orders and the total quantity of products for each user, then compute the average quantity per order.

### Code

```python
user_stats = (
    orders_rdd
    .map(lambda o: (o["user_id"], (1, o["quantity"])))
    .aggregateByKey(
        (0, 0),
        lambda acc, value: (acc[0] + value[0], acc[1] + value[1]),
        lambda acc1, acc2: (acc1[0] + acc2[0], acc1[1] + acc2[1])
    )
)

user_average_quantity = user_stats.mapValues(
    lambda stats: stats[1] / stats[0]
)

print("Statistics per user:")
print(user_stats.take(5))

print("Average quantity per order:")
print(user_average_quantity.take(5))
```

### Results

The first five users had the following statistics:

| User ID | Number of orders | Total quantity | Average quantity |
|---|---:|---:|---:|
| `f143262f-dc5c-4eed-8da0-365bf89897b9` | 4 | 12 | 3.00 |
| `969b6662-0562-4059-968c-c69b1064005c` | 12 | 40 | 3.33 |
| `ce9e1a11-fcbb-4e59-bbdd-cf7c9c96e9ec` | 85 | 253 | 2.98 |
| `5563f616-00e8-4ece-8b49-452d46d483f3` | 21 | 57 | 2.71 |
| `f94d6204-6808-493f-9fed-2c43e256a6dc` | 49 | 175 | 3.57 |

## Exercise 2 — Handle Missing Users with `leftOuterJoin`

### Objective

Add an order associated with a user who does not exist in the users dataset and identify orders without a matching user.

### Code

```python
fake_order = orders_rdd.first().copy()
fake_order["user_id"] = "fake-user-id-999"

orders_with_fake = orders_rdd.union(
    sc.parallelize([fake_order])
)

orders_kv_fake = orders_with_fake.map(
    lambda o: (o["user_id"], o)
)

enriched_fake = orders_kv_fake.leftOuterJoin(users_kv)

orders_without_user = enriched_fake.filter(
    lambda pair: pair[1][1] is None
)

print(
    "Orders without a matching user:",
    orders_without_user.count()
)
print(orders_without_user.take(5))
```

### Results

One order has no matching user.

```text
Orders without a matching user: 1
```

The unmatched order has the user ID `fake-user-id-999`. The `leftOuterJoin` preserves the order and assigns `None` to the missing user information.

## Exercise 3 — Compare RDDs and DataFrames

### Objective

Perform the same aggregation using an RDD and a DataFrame, compare the results, and inspect their execution plans.

### Code

```python
from pyspark.sql import functions as F

orders_df = spark.createDataFrame(
    orders_rdd.map(
        lambda o: (o["user_id"], o["quantity"])
    ),
    ["user_id", "quantity"]
)

user_quantity_df = (
    orders_df
    .groupBy("user_id")
    .agg(F.sum("quantity").alias("total_quantity"))
)

print("RDD count:", user_quantity.count())
print("DataFrame count:", user_quantity_df.count())

user_quantity_df.show(5)
user_quantity_df.explain()

print(user_quantity.toDebugString().decode())
```

### Results

```text
RDD count: 50
DataFrame count: 50
```

Both aggregations produce 50 user-level results.

The DataFrame physical plan contains:

- A partial `HashAggregate`.
- An `Exchange` using hash partitioning.
- A final `HashAggregate`.

The RDD lineage contains a `ShuffledRDD`, corresponding to the shuffle required by `reduceByKey`.

## Exercise 4 — Measure the Effect of Caching

### Objective

Compare execution times with and without caching.

### Code

```python
import time

def measure_time(label, operation):
    start = time.perf_counter()
    result = operation()
    elapsed = time.perf_counter() - start

    print(f"{label}: {result}")
    print(f"Elapsed time: {elapsed:.4f} seconds")


# Measurements with caching
measure_time(
    "orders_rdd.count() with cache",
    lambda: orders_rdd.count()
)

measure_time(
    "user_quantity.count() with cache",
    lambda: user_quantity.count()
)
```

### Results with caching

| Operation | Result | Elapsed time |
|---|---:|---:|
| `orders_rdd.count()` | 2829 | 0.1229 s |
| `user_quantity.count()` | 50 | 0.1597 s |

### Code without caching

```python
orders_rdd.unpersist()
orders_data.unpersist()

orders_data = orders_lines.filter(
    lambda line: line != header and line.strip() != ""
)

orders_rdd = orders_data.map(parse_order)

user_quantity = (
    orders_rdd
    .map(lambda o: (o["user_id"], o["quantity"]))
    .reduceByKey(add)
)

measure_time(
    "orders_rdd.count() without cache",
    lambda: orders_rdd.count()
)

measure_time(
    "user_quantity.count() without cache",
    lambda: user_quantity.count()
)
```

### Results without caching

| Operation | Result | Elapsed time |
|---|---:|---:|
| `orders_rdd.count()` | 2829 | 0.1415 s |
| `user_quantity.count()` | 50 | 0.4994 s |

### Observation

The results were identical with and without caching. In these measurements, caching reduced the execution time of `user_quantity.count()` from approximately 0.4994 seconds to 0.1597 seconds. The measurements are indicative only because the dataset is small and execution times can vary.
