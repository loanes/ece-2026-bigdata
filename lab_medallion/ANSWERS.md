# dbt lab: answers to the exercises

## 1. `username_normalized`
Added `lower(trim(username))` to `stg_users`, documented in `silver.yml` with `not_null` and `unique`. The `unique` test is the meaningful one: two usernames differing only by case would collide after normalization. The generator already produces clean lowercase names, so both columns are identical here.

## 2. Order validation
- `product` in the expected list: `accepted_values`.
- `user_id` exists in `stg_users`: `relationships` plus the singular test `assert_orders_have_users`.
- `quantity` positive: singular test `assert_orders_quantity_positive`, because no built-in generic test expresses `> 0` without an extra package (dbt_utils). It also catches `NULL`.

## 3. Invalid birthdates
5 users have a birthdate later than their first order (288 orders): Faker draws birthdates relative to today while orders are dated 2020. `stg_users` now sets the birthdate to `NULL` and exposes `birthdate_is_valid`. The test `assert_orders_after_user_birth` passes without `severity='warn'`. Trade-off: `stg_users` now depends on `stg_orders`.

## 4. Invalid ZIP codes
Seed `state_zip_ranges` (state, min, max) and singular test `assert_users_zip_matches_state` (severity warn): 49 of 50 users are flagged, including `KY 01352`.
- Source of reference data: an official source (USPS). My ranges were written from memory and are approximate, so some flags may be false positives.
- Seed: fine for a small, stable table, versioned with the code. A large or frequently changing table should come from an external source.
- Silver layer: the check belongs there. Fixing or rejecting rows is a separate decision, so for now it only warns. A `zip_is_valid` column would follow the `birthdate_is_valid` pattern.
- When the reference changes: reload with `dbt seed` and rerun the tests. Rows can switch between valid and invalid. The change is a commit, so it is traceable.
- Limit: the test cannot flag a wrong ZIP that happens to fall in its state's range.

## 5. Materialization
| | view | table |
|---|---|---|
| Database file size | 524 KB | 1.3 MB |
| `count(*)` on `stg_orders` | 0.477 s | 0.111 s |
| Stored where | nowhere, only the query | in `lab_medallion.duckdb` |
| Transformation runs | on every read | once, at `dbt build` |
| CSV changes | next read sees it | stale until the next build |

A table avoids re-reading the source files on every query, at the cost of storage and freshness. Configuration restored to `view`.