
# Lab 2 – Govern Iceberg Tables with Polaris

## 1. Connect Spark to Polaris

### 1.1. Which component answers `SHOW NAMESPACES`?

For the `lab` catalog, the request is handled by Spark's Iceberg Hadoop catalog implementation.

For the `polaris` catalog, the request is sent to the Polaris REST Catalog API.

The difference comes from the Spark catalog configuration:
- `lab` uses the Hadoop catalog implementation.
- `polaris` uses the REST catalog implementation.

Polaris provides centralized catalog management and access control.

### 1.2. Where is the credential used?

The Polaris credential is configured in Spark and used when Spark authenticates against the Polaris REST API.

It is different from the S3 credentials:
- Polaris credentials authenticate the client to the catalog.
- S3 credentials allow Spark to access the underlying object storage.

These two authentication mechanisms serve different purposes.

## 2. Register an existing Iceberg table

### 2.1. What does `register_table` do?

Registering the existing `lab.silver.orders` table in Polaris creates a catalog reference to its existing Iceberg metadata.

The operation does not require copying the existing data files. The table remains stored in the warehouse, while Polaris becomes another catalog through which the table can be accessed.

The exact S3 object count before and after registration was not recorded, so no numerical comparison is reported.

### 2.2. Why is it dangerous to keep writing through the original `lab` catalog?

The two catalogs maintain separate references to Iceberg metadata.

If a write is performed through the original Hadoop catalog after registration, its metadata pointer may be updated while Polaris still references an older metadata version.

This can lead to inconsistent or stale views of the table. After registration, writes should therefore be performed through Polaris.

## 3. Create a table through Polaris

### 3.1. Where is `silver.users` stored?

The managed table is stored under:

`s3://user-l-sacrez-ece/warehouse/silver/users/`

The directory contains Iceberg metadata and data files.

Polaris creates and manages the table in the warehouse location configured for the catalog.

### 3.2. What is the difference between a registered table and a table created through Polaris?

A registered table already exists in storage. Polaris registers a reference to its existing Iceberg metadata without copying the data.

A table created through Polaris is a managed table: Polaris creates the table metadata and manages its data and metadata files in the warehouse.

## 4. Schema evolution and access control

### 4.1. Which metadata files record the schema changes?

The schema changes are recorded in successive Iceberg metadata JSON files in:

`warehouse/silver/users/metadata/`

The local metadata inspection showed:

- `00000-e466ff9c-454e-4612-a609-c9d9578062a0.metadata.json`: schema ID 0, without `country`.
- `00001-e8d637aa-6089-45d4-988a-a82882cac0bf.metadata.json`: schema ID 1, with the additional `country` column.
- `00002-98b65067-1839-402c-b64e-20cbd957116f.metadata.json`: current schema ID 0, without `country`.

The older schema containing `country` remains in the metadata history. The current schema no longer contains this column.

### 4.2. Which privilege is checked when adding a column?

The analyst's attempt to add a column was rejected by Polaris with a `ForbiddenException` identifying the `ADD_TABLE_SCHEMA` operation.

This confirms that schema modification requires a privilege that was not granted to the analyst.

### 4.3. What happened when accessing the table as an analyst?

The analyst catalog could list the tables in the `silver` namespace.

An initial read attempt using the analyst catalog did not complete successfully in the Spark session, so its result is not considered confirmed.

The analyst was also denied permission to create a namespace and to modify a table schema. This demonstrates that read-oriented catalog permissions do not automatically provide administrative or schema-management rights.

## 5. Commit Iceberg metadata to Git

The Iceberg metadata directories for `silver.orders` and `silver.users` were synchronized into the repository.

Only the following paths were staged:

- `warehouse/silver/orders/metadata/`
- `warehouse/silver/users/metadata/`

The data directories and the `gold` directory were not staged.

This keeps the Iceberg metadata under version control without committing the table data files.

## Exercise 1 – Remove a column and inspect snapshots

The `country` column was removed using:

```sql
ALTER TABLE polaris.silver.users DROP COLUMN country;
```

The command completed successfully.

The metadata inspection confirmed that the current schema returned to schema ID 0, which does not contain `country`. The previous schema ID 1, which contains `country`, remains in the metadata history.

The metadata files all reference the same existing snapshot ID (`8449789202928667315`) for the table's data.

This shows that adding and dropping a column are metadata-only schema evolution operations in this case. They do not require rewriting the table's data files or creating a new data snapshot.

The snapshot history query through Spark did not complete in the session, so the metadata JSON files were inspected directly instead.

## Exercise 2 – Create a scoped reader role

### 2.1. Create a role restricted to the `silver` namespace

A catalog role named `silver_reader` was created with permissions scoped to the `silver` namespace:

- `NAMESPACE_LIST`
- `TABLE_READ_DATA`
- `TABLE_READ_PROPERTIES`

No catalog-wide listing permission or permissions on the `gold` namespace were granted.

A principal role named `silver_reader_role` was created and assigned the catalog role `silver_reader`.

A test principal named `silver_test` was then created and assigned the principal role.

### 2.2. Test access to `silver`

A Spark catalog named `polaris_test` was configured using the test principal's credentials.

The following command was denied:

```sql
SHOW NAMESPACES IN polaris_test;
```

Polaris rejected the operation because the principal did not have catalog-wide namespace listing permission.

However, the following command succeeded:

```sql
SHOW TABLES IN polaris_test.silver;
```

It listed the `users` and `orders` tables.

The following read query also succeeded:

```sql
SELECT * FROM polaris_test.silver.users LIMIT 5;
```

This confirms that the principal can list and read tables in the authorized `silver` namespace.

### 2.3. Test access to `gold`

A `gold` namespace and a test table named `test_access` were created using the development principal.

The test principal then attempted:

```sql
SELECT * FROM polaris_test.gold.test_access;
```

Polaris returned a `ForbiddenException` for the `LOAD_TABLE` operation.

This confirms that the `silver_reader` role does not provide access to the `gold` namespace.

The temporary test table was subsequently dropped.

## 6. Cleanup

The temporary `polaris.gold.test_access` table was dropped.

The remaining cleanup operations are:

```python
spark.sql("DROP TABLE IF EXISTS polaris.silver.users")
spark.sql("DROP NAMESPACE IF EXISTS polaris.gold")
spark.stop()
```

The `polaris.silver.orders` table must be preserved because it is required for the subsequent Trino lab.
