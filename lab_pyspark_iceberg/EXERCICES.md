### Exercise 1 – Create `lab.silver.users` as an Iceberg table

The `lab.silver.users` table already existed in the Iceberg catalog. We inspected its structure using `DESCRIBE TABLE` and confirmed that it contains 10 columns.

We also used `SHOW CREATE TABLE` to verify that the table uses the Iceberg format (`USING iceberg`). Its underlying data is stored in Parquet format, with Zstandard compression.

The table is stored at:

`s3a://user-l-sacrez-ece/warehouse/silver/users`

Finally, we checked that the table contains 50 records.

Therefore, the table was already correctly created as an Iceberg table, so we did not need to recreate it.


### Exercise 2 – Append a new batch of users and inspect the snapshots

We loaded the source users from the `users.csv` file stored in the S3 bronze layer. We selected three users, generated new UUIDs and transformed the source columns to match the schema of `lab.silver.users`.

We then appended the new records using the Iceberg `append()` operation.

Before the append, the table contained 50 records. After the operation, it contained 53 records.

We inspected the Iceberg snapshots and identified two snapshots:
- Initial snapshot: 50 records, created on October 25, 2026.
- New snapshot: 53 records, created on November 5, 2026.

The second snapshot has the `append` operation and a new snapshot ID (`5535678597499870097`).

This confirms that Iceberg successfully added the three records while preserving the previous snapshot.


### Exercise 3 – Query the table before and after the append using time travel

We used Iceberg Time Travel to access the table at two different points in time.

First, we queried the initial snapshot using its snapshot ID (`4297243762782300340`) and the `versionAsOf` option. This returned 50 users.

Then, we queried the current version of the table, which returned 53 users.

Finally, we used a left anti-join on `user_id` to identify records present in the current version but missing from the initial snapshot.

The comparison returned exactly three new users: Charles Garcia, Ryan Munoz and Jacob Wood.

This demonstrates that Iceberg Time Travel allows us to access previous versions of a table and compare historical data with the current state.


### Exercise 4 – Add a country column and write new data using the evolved schema

We used the `ALTER TABLE` statement to add a new column named `country` of type `STRING` to `lab.silver.users`.

We then prepared a new batch of two users from the source CSV file. We added the `country` column to their DataFrame and assigned the value `USA` to both records.

We appended these records to the Iceberg table using the `append()` operation.

The table now contains 55 records (53 before the append and 2 new records).

Finally, we queried the table to verify the result. The two new users have `USA` in the `country` column, while existing records have `NULL` because this column was not present when they were originally inserted.

This demonstrates Iceberg schema evolution: we can add a column and write data using the new schema without recreating the table or rewriting all existing records.


### Exercise 5 – Compare the S3 layout of the users and orders tables

We inspected the S3 storage layout of both Iceberg tables using the AWS CLI.

Both tables follow the same directory structure, with two main folders:

- `data/`: contains the actual table data stored as Parquet files.
- `metadata/`: contains Iceberg metadata, including Avro manifest files, snapshot metadata files, JSON metadata versions and the version hint.

We observed the following differences:
- The `users` table contains 3 Parquet data files and 3 snapshots.
- The `orders` table contains 4 Parquet data files and 4 snapshots.

The `orders` table also has more metadata files because it has undergone more write operations.

This comparison shows that Iceberg separates the physical data files from the metadata used to manage the table. Both tables use the same storage organization, even though their number of files and snapshots differs.


### Exercise 6 – Explain the difference between Parquet, Iceberg and an Iceberg catalog

**Parquet** is a columnar file format used to store data efficiently. It provides compression and allows analytical queries to read only the required columns.

**Apache Iceberg** is an open table format that manages data files, usually stored in formats such as Parquet. It adds features such as ACID transactions, snapshots, time travel and schema evolution. It allows users to modify and query large datasets reliably without managing individual files manually.

**An Iceberg catalog** is the component responsible for managing and locating Iceberg tables and their metadata. It allows users to access tables using identifiers such as `lab.silver.users` instead of specifying individual file paths.

In our lab:
- Parquet stores the actual data files in the `data/` directory.
- Iceberg manages the table structure, metadata, snapshots and schema changes.
- The Hadoop catalog allows Spark to locate the Iceberg tables in the S3 warehouse.

In summary, Parquet is the file format, Iceberg is the table format, and the catalog is the component that manages table discovery and metadata references.