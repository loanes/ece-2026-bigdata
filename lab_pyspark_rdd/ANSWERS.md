# PySpark RDD Lab — Answers

## Exercise 1 — Aggregate Data with `aggregateByKey`

### 1. What does `aggregateByKey` do?

`aggregateByKey` aggregates values associated with the same key. It uses three arguments:

- **Zero value:** the initial accumulator for each key.
- **Sequence operation:** combines each value with the accumulator within a partition.
- **Combiner operation:** merges accumulators from different partitions.

In this exercise, each order is represented by `(1, quantity)`. The first value counts the order, while the second represents the ordered quantity.

### 2. How are the statistics calculated?

For each user, the code calculates:

- The number of orders.
- The total quantity ordered.
- The average quantity per order.

The average is calculated by dividing the total quantity by the number of orders.

For example, the first user has 4 orders and a total quantity of 12. Their average quantity per order is therefore `12 / 4 = 3.0`.

### 3. Why use `aggregateByKey`?

`aggregateByKey` allows several statistics to be calculated in a single aggregation. It is useful when the required result contains more than one value, such as a count and a sum.

---

## Exercise 2 — Handle Missing Users with `leftOuterJoin`

### 1. What is the purpose of `leftOuterJoin`?

`leftOuterJoin` combines two RDDs using their keys. It preserves every record from the left RDD, even if there is no matching key in the right RDD.

When a matching record exists, the result contains both values. Otherwise, the value from the right RDD is `None`.

### 2. What happens when a user does not exist?

A fake order was added with the user ID `fake-user-id-999`. Since this ID does not exist in the users dataset, the join returns the order with `None` for the user information.

The result was:

```text
Orders without a matching user: 1
```

This confirms that the unmatched order was preserved by the left outer join.

### 3. What is the difference between `join` and `leftOuterJoin`?

- `join` returns only records whose keys exist in both RDDs.
- `leftOuterJoin` preserves every record from the left RDD and uses `None` when there is no matching record on the right.

Therefore, `leftOuterJoin` is useful when missing matches must be identified rather than discarded.

---

## Exercise 3 — Compare RDDs and DataFrames

### 1. Do the RDD and DataFrame aggregations produce the same result?

Both aggregations returned 50 results, one for each user.

```text
RDD count: 50
DataFrame count: 50
```

The two approaches calculate the total quantity ordered by each user. Their results are equivalent, although the order in which rows are displayed may differ.

### 2. What does the DataFrame physical plan show?

The physical execution plan contains the following main operations:

- **Partial `HashAggregate`:** calculates intermediate sums before the shuffle.
- **`Exchange`:** redistributes data according to the user ID so that records with the same key can be aggregated together.
- **Final `HashAggregate`:** combines the intermediate sums to obtain the final result for each user.

The shuffle is necessary because records belonging to the same user may initially be located in different partitions.

### 3. What does the RDD lineage show?

The RDD lineage contains a `ShuffledRDD`, which corresponds to the shuffle performed by `reduceByKey`.

`reduceByKey` combines values locally before sending intermediate results across the network. This reduces the amount of data that needs to be shuffled compared with sending every individual value.

### 4. What is the main difference between RDDs and DataFrames?

RDDs provide a lower-level API with explicit transformations and functions written in Python. DataFrames provide a structured API with named columns and a schema.

DataFrames allow Spark to optimize queries using its execution engine. For structured data and common aggregations, DataFrames are generally preferable because Spark can optimize the execution plan.

---

## Exercise 4 — Measure the Effect of Caching

### 1. What is caching?

Caching stores the computed partitions of an RDD or DataFrame so that they can be reused by subsequent actions.

Without caching, Spark may recompute the transformations needed to produce a result each time an action is executed. With caching, Spark can reuse previously computed partitions when they are still available.

### 2. What were the measured execution times?

The following times were observed during the lab:

| Operation | With cache | Without cache |
|---|---:|---:|
| `orders_rdd.count()` | 0.1229 s | 0.1415 s |
| `user_quantity.count()` | 0.1597 s | 0.4994 s |

Both approaches returned the same results:

- `orders_rdd.count()` returned 2,829 orders.
- `user_quantity.count()` returned 50 users.

In these measurements, caching reduced the execution time of `user_quantity.count()` from approximately 0.4994 seconds to 0.1597 seconds.

### 3. Why can caching improve performance?

The `user_quantity` RDD depends on transformations applied to the orders RDD, including mapping and `reduceByKey`.

When the relevant data is cached, Spark can reuse computed partitions instead of repeating all the work required to reconstruct them. This can reduce execution time when the same data is used multiple times.

### 4. Does caching always improve performance?

No. Caching uses memory and may introduce storage overhead. It is most useful when an RDD or DataFrame is reused by several actions.

For a small dataset or a computation executed only once, caching may provide little benefit. Execution times can also vary because of JVM warm-up, scheduling, memory availability, and other system activity.

The measured times in this lab are therefore indicative rather than a universal benchmark.

---

## Overall Conclusion

This lab explored several fundamental Spark concepts:

- `aggregateByKey` for computing multiple statistics per key.
- `leftOuterJoin` for preserving records with missing matches.
- RDD and DataFrame aggregations and their execution plans.
- Caching and its potential effect on execution time.

The experiments showed that Spark provides several ways to process and aggregate distributed data. Choosing the appropriate API and using caching when data is reused can help improve the clarity and performance of data-processing applications.