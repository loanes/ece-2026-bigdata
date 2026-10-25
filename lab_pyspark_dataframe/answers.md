# Answers – Spark DataFrames Lab

## 1. SparkSession with S3 access

**Q1. What happens to a running Spark job if the service is restarted mid-lab, and why?**

The job may fail because the service restart can invalidate the temporary STS credentials and stop the Spark executors. The session must be restarted and valid credentials obtained again.

**Q2. Why does `SimpleAWSCredentialsProvider` fail here?**

`SimpleAWSCredentialsProvider` uses only the access key and secret key. Onyxia also provides a session token, which is required for temporary STS credentials. `TemporaryAWSCredentialsProvider` supports all three values.

## 2. Silver layer

**Q3. Explain the output of the code that was just run.**

The query groups users by state and counts the users in each group. `missing_city` counts users whose city is `NULL`. The results are sorted by the number of users, from highest to lowest.

**Q4. Compare the DataFrame and SQL approaches. Which would you choose for exploration and for a model reused by colleagues?**

I would use the DataFrame API for a one-off exploration because it is easy to build transformations step by step. For a model reused by several colleagues, I would choose Spark SQL when the logic is mainly relational, because it is readable and familiar to SQL users. Both approaches use Spark's optimizer.

**Q5. Where else could an empty string from `regexp_extract()` silently produce a wrong result?**

It can affect the `zip_code` extraction or any other extracted field. An empty string is not `NULL`, so it can be counted as a real value or create an incorrect group. Missing matches should be converted to `NULL` when appropriate.

## 3. Write the silver layer as Parquet

**Q6. How many part-files are written, and why?**

The number of part-files depends on the number of output partitions used by Spark when writing the DataFrame. Each output partition can produce a separate part-file. The exact number must be checked in the S3 listing.

**Q7. What do you lose by using `coalesce(1)` on a larger dataset?**

It reduces the output to one partition, limiting parallelism and potentially creating a bottleneck. One task must write the entire output, which can be slower and require more resources. Multiple part-files are generally better for large datasets.

## 4. Write the silver layer as Iceberg tables

**Q8. Compare the Parquet directory and the Iceberg table. Which files contain data and which describe the table?**

The Parquet directory contains data files but does not provide full table-level snapshot management. In Iceberg, the `data/` directory contains Parquet data files, while the `metadata/` directory contains metadata describing the schema, manifests and snapshots.

**Q9. What happens if a job overwrites a Parquet directory while a query is reading it? What changes with Iceberg?**

With a direct Parquet overwrite, a reader may encounter missing or replaced files, depending on the timing of the operation. Iceberg commits changes through metadata and snapshots, allowing readers to keep using a consistent table version while a new version is committed.

**Q10. What can go wrong if two jobs commit simultaneously, and what would a catalog service add?**

With a Hadoop catalog, concurrent commits can conflict when jobs update the current metadata pointer at the same time. A catalog service can coordinate commits and provide stronger concurrency control, reducing the risk of conflicting updates.

## 5. Compare with the dbt lab

**Q11. What differs between the schemas? What did you do about UUIDs, and what is the consequence?**

Spark does not have a dedicated UUID type like DuckDB, so UUID values are stored as strings. The values can still be compared and joined, but consumers no longer benefit from a specific UUID type and must handle them as strings.

**Q12. Compare the output layouts. Which is easier to read and which scales better?**

A single Parquet object per model, as in the dbt output, is simple for consumers to locate and read. Spark writes a directory of part-files, which supports parallel processing and generally scales better for large datasets.

**Q13. What did this lab use instead of dbt tests, and what is needed to get the same guarantees?**

This lab used assertions to check row counts and compare the DataFrame and SQL results. To obtain equivalent guarantees, I would add explicit checks for uniqueness, non-null values, accepted values and relationships between tables.

**Q14. What plays the role of `ref()` and `source()` in the notebook?**

The dependencies are defined manually through DataFrame variables, transformations, joins and temporary views. Unlike dbt, the notebook does not automatically build a dependency graph.

**Q15. Why are dbt and Spark execution times not directly comparable?**

The execution times depend on data size, caching, startup overhead, execution plans and the number of Spark actions. A fair comparison requires the same inputs, equivalent transformations and comparable execution conditions.

**Q16. Which would you choose: dbt with DuckDB or Spark?**

- **Daily batch of 10 GB:** I would generally choose dbt with DuckDB if the workload fits the available machine resources and the transformations are mainly SQL.
- **Daily batch of 10 TB:** I would choose Spark because it supports distributed processing across multiple executors.
- **Team of analysts who only know SQL:** I would choose dbt with DuckDB for its SQL-based workflow and built-in testing and dependency management, provided the data volume fits the available resources.