# Answers – Explore Iceberg Tables with Spark

## 1. Inspect the files

**Q1. Which files contain the actual rows?**

The actual data is stored in the `.parquet` files located in the `data/` directory. These files contain the order records, including their IDs, user IDs, timestamps, quantities and products.

**Q2. Which files describe the table?**

The files located in the `metadata/` directory describe the Iceberg table. They include JSON metadata files, Avro manifest files and snapshot metadata files. They store information about the table structure, data files and different versions of the table.

**Q3. Why does an Iceberg table need more than the Parquet files?**

Parquet files only store the data itself. Iceberg needs additional metadata to manage the table as a consistent and reliable data structure. This metadata tracks which files belong to the table, stores the schema and maintains the history of snapshots. It also enables features such as time travel, schema evolution and reliable data updates.

## 2. Explore Iceberg metadata

**Q1. How many snapshots does the table currently have?**

At this stage of the lab, the table contains **2 snapshots**. The first snapshot corresponds to the initial table creation (`overwrite`), while the second one corresponds to an append operation.

**Q2. How many data files belong to the current table?**

At this stage of the lab, the table contains **2 data files**, both in Parquet format. The first file contains 2,829 records, while the second contains 1 record, giving a total of 2,830 records.

**Q3. What information does the `snapshots` table contain that the Parquet files do not?**

The `snapshots` metadata table provides information about the history of the Iceberg table. It contains snapshot IDs, commit timestamps, operation types and references to manifest lists. Parquet files only contain the actual records and do not provide this history or information about previous table versions.

## 3. Create a second snapshot

**Q1. How many snapshots are there now?**

After appending three new orders, the table contains **3 snapshots**. The new snapshot was created by an append operation on November 4, 2026.

**Q2. Did the original Parquet files disappear?**

No, the original Parquet files are still present in the S3 storage. Iceberg keeps the files referenced by previous snapshots so that historical versions of the table remain accessible. The new data is written into additional Parquet files rather than replacing the original ones.

**Q3. Why does Iceberg create a new snapshot instead of simply replacing the table?**

Iceberg creates a new snapshot to preserve the previous state of the table and maintain a history of all committed changes. This approach enables time travel and provides transactional consistency. Instead of replacing the entire table, Iceberg writes the new data and creates a new version of the table.

## 4. Time travel

**Q1. What does time travel read?**

Time travel reads a specific historical snapshot of the table. It allows users to query the data exactly as it existed at a particular point in time, using its snapshot ID or timestamp.

**Q2. Why can Iceberg access an older version without making a complete copy of the table?**

Iceberg uses metadata and manifest files to keep track of the data files associated with each snapshot. Since data files are generally immutable, different snapshots can reference the same files. Only new or modified data needs to be written, which avoids duplicating the entire table.

**Q3. What would happen if the old snapshot's metadata and data files were physically deleted?**

The deleted snapshot would no longer be accessible through time travel. If some data files were also required by the current snapshot, deleting them could make the current table incomplete or unreadable. Therefore, Iceberg must preserve the files that are still referenced by active snapshots.

## 5. Schema evolution

**Q1. Did the existing Parquet files have to be rewritten?**

No, the existing Parquet files did not have to be rewritten. Iceberg updates the table metadata to include the new column. Older data files can still be read, and the new column is returned as `NULL` for records that do not contain a value for it.

**Q2. Where is the new schema recorded?**

The new schema is recorded in the Iceberg table metadata, stored in the `metadata/` directory. It is maintained in the metadata JSON files rather than being directly added to all existing Parquet files.

**Q3. Why is schema evolution a table-level operation rather than simply changing a Parquet file?**

Schema evolution affects the structure and interpretation of the entire table, not just one individual file. Iceberg manages the schema centrally through table metadata, ensuring that all data files can be interpreted consistently, even if they were written with different schema versions.

## 6. Compare Iceberg with Parquet

**Q1. Which one is simply a collection of Parquet files?**

The `silver/spark/orders.parquet/` directory is simply a collection of Parquet files. It contains the data files and a `_SUCCESS` marker, but it does not provide Iceberg table management features.

**Q2. Which one has table metadata and snapshots?**

The `warehouse/silver/orders/` directory corresponds to the Iceberg table. It contains both Parquet data files and a `metadata/` directory with metadata files, manifests and snapshots.

**Q3. How would you safely replace a Parquet directory while another query is reading it?**

Directly replacing a Parquet directory while another query is reading it can lead to inconsistent results or missing files. A safer approach is to write the new data into a separate directory and then switch the reference to the new version through an atomic operation, where supported. This avoids exposing a partially written dataset to readers.

**Q4. How does Iceberg make the table state visible atomically?**

Iceberg first writes the new data files and metadata files. It then commits the new snapshot by updating the table's metadata reference. This commit is atomic, meaning that readers see either the previous snapshot or the new snapshot, rather than an incomplete intermediate state.

**Q5. Why is a catalog needed once several engines need to share the same Iceberg table?**

A catalog provides a central way for different processing engines to discover and access the same Iceberg table. It stores or resolves the table metadata location and helps coordinate table commits. This allows engines such as Spark and other compatible tools to work with a consistent version of the same table.