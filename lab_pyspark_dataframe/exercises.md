# PySpark DataFrame Lab

## Exercise 1 — Validate user birthdates

### Objective

Validate users' birthdates and calculate the date of their first order. The transformation was implemented using both the DataFrame API and Spark SQL.

### Implementation

The first order date was calculated using `MIN(ordered_at)` for each user.

The two implementations were compared using `exceptAll` in both directions to check whether their results were identical.

### Results

- Total users: 50
- Valid birthdates: 45
- Invalid birthdates: 5
- Differences between the two implementations: 0 rows

### Conclusion

Both implementations returned the same results. This confirms that the DataFrame API and Spark SQL produced equivalent outputs for this transformation.

---

## Exercise 2 — Compare UDF implementations

### Objective

Extract the ZIP code from each user address using three methods:

- Python UDF
- pandas UDF
- Native Spark function

### Implementation

**Native Spark function:**

```python
from pyspark.sql import functions as F

users_zip_native = users_bronze.withColumn(
    "zip_code",
    F.regexp_extract(
        F.col("address"),
        r"([0-9]{5})$",
        1
    )
)
```

The Python UDF and pandas UDF performed the same extraction using a regular expression.

### Results

The three methods processed 50 users. The results were compared with the native Spark implementation using `exceptAll` in both directions.

| Method | Rows returned | Differences |
|---|---:|---:|
| Python UDF | 50 | 0 |
| pandas UDF | 50 | 0 |
| Native Spark | 50 | Reference |

### Performance comparison

Each method was tested three times.

| Method | Run 1 | Run 2 | Run 3 | Average |
|---|---:|---:|---:|---:|
| Python UDF | 0.369 s | 0.312 s | 0.283 s | 0.322 s |
| pandas UDF | 0.237 s | 0.273 s | 0.285 s | 0.265 s |
| Native Spark | 0.608 s | 0.674 s | 0.204 s | 0.495 s |

### Conclusion

All three methods returned the same results. The pandas UDF had the lowest average execution time in this test. However, the dataset only contained 50 users, so these measurements are not sufficient to conclude that it is always the fastest method. The native Spark function remains a simple choice for this type of transformation.

---

## Exercise 3 — Cache Bronze DataFrames

### Objective

Cache the Bronze DataFrames and compare the execution time of the first and second count operations.

### Implementation

```python
users_bronze.cache()
orders_bronze.cache()

print(users_bronze.is_cached)
print(orders_bronze.is_cached)
```

Both DataFrames reported `True`, confirming that caching was enabled.

### Results

| DataFrame | Number of rows | First count | Second count |
|---|---:|---:|---:|
| `users_bronze` | 50 | 0.584 s | 0.205 s |
| `orders_bronze` | 2829 | 0.571 s | 0.318 s |

### Conclusion

The second count was faster for both DataFrames in these tests. Caching can improve performance when the same data is reused by several operations. The results may vary depending on the dataset and execution conditions.

---

### Exercise 4 — Iceberg snapshots vs Parquet

#### Objective

Verify Iceberg snapshot creation after an append and query the previous table version using time travel.

#### Initial state

The existing Iceberg table `lab.silver.orders` contained 2,829 rows.

- Initial snapshot ID: `6790038792092841675`
- Operation: `overwrite`

#### Append operation

A single test row was appended to the table. Its `order_id` was generated as a new UUID, while the other values were copied from an existing row.

The row count increased from 2,829 to 2,830, confirming that the append succeeded without replacing the existing table contents.

The new snapshot was:

- Snapshot ID: `6890707908170945907`
- Operation: `append`

#### Time-travel verification

The previous snapshot was queried using:

```sql
SELECT COUNT(*)
FROM lab.silver.orders VERSION AS OF 6790038792092841675;
```

The current table and previous snapshot returned the following counts:

| Query | Number of rows |
|---|---:|
| Current table after append | 2,830 |
| Previous snapshot | 2,829 |

Both counts matched the expected values. This confirms that the previous table version remained queryable after the append.

#### Conclusion

The append and time-travel tests both succeeded. Iceberg created a new snapshot for the appended row while preserving access to the previous snapshot.

Unlike a plain Parquet directory, which does not provide table snapshots or time travel by itself, Iceberg manages table metadata and versions. This makes it possible to query an earlier committed state of the table.
