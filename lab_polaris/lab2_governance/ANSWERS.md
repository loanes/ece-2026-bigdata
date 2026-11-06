# Lab 2 — Govern Iceberg Tables with Polaris

## 1. Connect Spark to Polaris

### 1.1 Which component answered `SHOW NAMESPACES`?

Spark uses different catalogs to access the tables.

- `lab` refers to the existing Spark/Iceberg catalog.
- `polaris` refers to the catalog configured to communicate with the Polaris REST catalog.

The catalog name in the SQL query determines which catalog handles the request. Polaris is responsible for catalog operations when the `polaris` catalog is correctly configured in Spark.

### 1.2 Where is the credential used?

The Polaris credential is configured in the Spark session.

Spark uses this credential when it sends authenticated REST requests to the Polaris catalog. It is not used as a direct credential to access the S3 bucket.

Access to the underlying storage is handled separately through the S3 configuration and credentials.

---

## 2. Register an existing Iceberg table

### 2.1 What did `register_table` write?

The `register_table` operation registers an existing Iceberg table in Polaris.

It creates a catalog reference to the existing Iceberg metadata. It does not copy the table's data files into a new location.

The operation therefore changes the catalog registration, not the underlying table data.

The exact number of objects under `warehouse/silver/orders/` was not recorded before and after registration. Therefore, no numerical comparison can be provided.

### 2.2 Why is it dangerous to keep writing through `lab`?

After registration, the same Iceberg table can be accessed through two catalog references.

If writes continue through the original `lab` catalog while Polaris also manages the registered table, the two catalogs may not remain synchronized.

This can lead to inconsistent metadata references, conflicting updates, or unexpected behavior when accessing the table.

For this reason, once the table is registered in Polaris, Polaris should be used as the catalog for subsequent operations.

---

## 3. Create a table through Polaris

### 3.1 Where did Polaris store the files for `silver.users`, and why?

The `silver.users` table was created through Polaris and its Iceberg files were stored in the configured warehouse, under the `silver/users` table directory.

The table's metadata and data are stored in the S3 warehouse.

Polaris manages the catalog metadata and table registration, while the Iceberg table files are stored in the object storage.

### 3.2 What is the difference between a registered table and a table created through Polaris?

A registered table already exists in storage. Polaris registers a reference to its existing Iceberg metadata without copying its data files.

A table created through Polaris is a new table managed through the Polaris catalog. Its metadata and data files are written to the configured warehouse location.

The main difference is therefore whether the table already existed before registration or was created through Polaris.

---

## 4. Understand access control

### 4.1 Which metadata file records the schema change? Is it the same file referenced by `register_table`?

The schema change on `polaris.silver.users` generated new Iceberg metadata files.

The metadata files inspected were:

- `00000-e466ff9c-454e-4612-a609-c9d9578062a0.metadata.json`
- `00001-e8d637aa-6089-45d4-988a-a82882cac0bf.metadata.json`
- `00002-98b65067-1839-402c-b64a-c82882cac0bf.metadata.json`

The schema IDs showed the evolution of the table:

- Schema ID `0`: the original schema, without the `country` column.
- Schema ID `1`: the schema after adding the `country` column.
- Schema ID `0`: the schema after removing the `country` column.

These files belong to `silver.users`.

They are not the same table metadata referenced by `register_table`, because `register_table` was used for `silver.orders`, whereas the schema change was performed on `silver.users`.

### 4.2 Which privilege does Polaris check for `ALTER TABLE ... ADD COLUMN country`?

The operation was rejected for the analyst because the analyst does not have the required metadata-management permissions.

The RBAC configuration in the lab assigns the `catalog_contributor` role to the developer. This role includes:

- `CATALOG_MANAGE_ACCESS`
- `CATALOG_MANAGE_METADATA`
- `CATALOG_MANAGE_CONTENT`

The analyst has the more restrictive `catalog_reader` role, which only provides read-related permissions.

The operation reported by Polaris in the authorization error was `ADD_TABLE_SCHEMA`.

### 4.3 What can the analyst do?

The analyst is associated with the `catalog_reader` catalog role.

According to the lab's RBAC configuration, this role provides:

- `TABLE_READ_DATA`
- `TABLE_READ_PROPERTIES`
- `CATALOG_READ_PROPERTIES`

The following results were observed:

- `SHOW TABLES IN polaris.silver` succeeded.
- The attempted `SELECT` query was not successfully validated. The command returned a Spark `REQUIRES_SINGLE_PART_NAMESPACE` error because Spark tried to resolve `polaris.silver` through `spark_catalog`, instead of using a correctly configured Polaris catalog.
- The `INSERT` test and its resulting error were not successfully recorded.
- The analyst's attempt to modify the table schema was rejected by Polaris. The reported operation was `ADD_TABLE_SCHEMA`.
- The snapshot check after the attempted `INSERT` was not completed.

The `catalog_reader` role does not include a table-write permission. Therefore, the analyst is not granted the permissions required to insert data.

The failed `SELECT` test must not be interpreted as a Polaris authorization denial: it was a Spark catalog configuration error.

---

## 5. Commit the Iceberg metadata to Git

The warehouse was synchronized locally using `aws s3 sync`.

The Git staging operation included:

- `lab_polaris/lab2_governance/ANSWERS.md`
- `warehouse/silver/orders/metadata/`
- `warehouse/silver/users/metadata/`

The following directories were not staged:

- `warehouse/silver/orders/data/`
- `warehouse/silver/users/data/`
- `warehouse/gold/`

Only the relevant metadata directories and the lab answers were committed. The data files were not included in the commit.

The commit and push were completed successfully with:

```bash
git commit -m "feat(polaris-lab): complete governance exercises"
git push
```

---

## Exercise 1 — Remove a column and inspect Iceberg metadata

The following operation was executed:

```sql
ALTER TABLE polaris.silver.users DROP COLUMN country;
```

The operation succeeded.

The Iceberg metadata files were then inspected.

The schema ID returned to `0`, corresponding to the original schema without the `country` column.

The previous schema, with ID `1`, is still present in the metadata history.

The three metadata files referenced the same snapshot ID:

```text
8449789202928667315
```

This indicates that the schema change modified the table metadata without creating a new data snapshot.

The snapshot history query through Spark was not successfully completed. The conclusion is therefore based on the inspection of the Iceberg metadata JSON files.

Dropping a column is a metadata operation because Iceberg can update the table schema without rewriting the underlying data files.

---

## Exercise 2 — Create a restricted reader role

A restricted catalog role named `silver_reader` was created.

The role was scoped to the `silver` namespace and granted the permissions required to list and read tables in that namespace:

- `NAMESPACE_LIST`
- `TABLE_READ_DATA`
- `TABLE_READ_PROPERTIES`

A principal role named `silver_reader_role` was created and associated with the `silver_reader` catalog role.

A test principal named `silver_test` was then assigned this principal role.

A separate Spark catalog named `polaris_test` was configured to connect to Polaris using this principal.

### Access tests

The following results were observed:

| Test | Result | Explanation |
|---|---|---|
| `SHOW NAMESPACES IN polaris_test` | Denied | The role does not have catalog-wide namespace listing permission. |
| `SHOW TABLES IN polaris_test.silver` | Succeeded | The role has permission to list tables in the `silver` namespace. |
| `SELECT * FROM polaris_test.silver.users LIMIT 5` | Succeeded | The role has permission to read table data. |
| `SELECT * FROM polaris_test.gold.test_access` | Denied | The role is not authorized to access the `gold` namespace. |

The access-denied error for the `gold` table was a Polaris `ForbiddenException` with the operation `LOAD_TABLE`.

These tests demonstrate that the role can read tables in the authorized `silver` namespace without receiving access to the `gold` namespace.

The temporary test table `polaris.gold.test_access` was dropped after the tests.

---

## 6. Cleanup

The following cleanup operations were successfully executed as the developer:

```sql
DROP TABLE IF EXISTS polaris.silver.users;
DROP NAMESPACE IF EXISTS polaris.gold;
```

The table `polaris.silver.orders` was intentionally preserved because it is required for the next Trino lab.

The Spark session was stopped using:

```python
spark.stop()
exit()
```

The cleanup was completed successfully.