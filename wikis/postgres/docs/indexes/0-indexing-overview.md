PostgreSQL has more index types than most databases, and each exists because a B-tree alone is not enough.

Below is the complete, practical list, with why it exists and when you actually use it.

---

??? note "**B-tree** (default, workhorse)"

    **What it is**

    * Balanced tree, sorted order
    * Default index type

    **Good for**

    * Equality (`=`)
    * Range queries (`<`, `>`, `BETWEEN`)
    * Sorting (`ORDER BY`)
    * `LIKE 'prefix%'`

    **Use it when**

    * You're not sure which index to use
    * You need general-purpose performance
    * You query scalar values

    **Example**

    ```sql
    CREATE INDEX idx_users_email ON users(email);
    ```

    **Reality**

    > ~90% of indexes in production are B-trees.

??? note "2️⃣ Hash"

    **What it is**

    * Hash table lookup

    **Good for**

    * Equality only (`=`)

    **Bad for**

    * Ranges
    * Sorting

    **Use it when**

    * Almost never

    **Why it exists**

    * Historically faster for equality (no longer true in practice)

    **Reality**

    > Modern Postgres B-trees outperform Hash indexes almost everywhere.

??? note "3️⃣ GiST (Generalized Search Tree)"

    **What it is**

    * A framework for "fuzzy" data types
    * Supports custom operators

    **Good for**

    * Geospatial (`PostGIS`)
    * Ranges (`tsrange`, `int4range`)
    * Full-text nearest-neighbour
    * Similarity searches

    **Use it when**

    * Distance, overlap, containment queries
    * "Closest", "intersects", "within"

    **Example**

    ```sql
    CREATE INDEX idx_geom ON places USING gist(geom);
    ```

    **Reality**

    > Essential for PostGIS and range types.

??? note "4️⃣ SP-GiST (Space-Partitioned GiST)"

    **What it is**

    * Space-partitioned variant of GiST
    * Handles non-balanced data better

    **Good for**

    * Hierarchical or clustered data
    * IP addresses
    * Quadtrees, KD-trees

    **Use it when**

    * Data is naturally partitioned, not evenly distributed

    **Example**

    ```sql
    CREATE INDEX idx_ip ON logs USING spgist(ip_address);
    ```

    **Reality**

    > Less common, but powerful for specific shapes of data.

??? note "5️⃣ GIN (Generalized Inverted Index)"

    **What it is**

    * Indexes *elements inside containers*

    **Good for**

    * `jsonb`
    * Arrays
    * Full-text search (`tsvector`)
    * `@>`, `?`, `&&` operators

    **Use it when**

    * You search *inside* documents
    * Many-to-many relationships in one column

    **Example**

    ```sql
    CREATE INDEX idx_data_gin ON events USING gin(data jsonb_path_ops);
    ```

    **Reality**

    > The go-to index for JSONB and text search.

??? note "6️⃣ BRIN (Block Range Index)"

    **What it is**

    * Summarizes ranges of heap blocks
    * Extremely small

    **Good for**

    * Very large tables
    * Naturally ordered data (time series, IDs)

    **Use it when**

    * Table is hundreds of GB / TB
    * Data is append-only or mostly ordered

    **Example**

    ```sql
    CREATE INDEX idx_logs_time_brin ON logs USING brin(created_at);
    ```

    **Reality**

    > Amazing for time-series where B-tree would be huge.

??? note "7️⃣ Bloom (extension)"

    **What it is**

    * Probabilistic, multi-column index
    * False positives possible

    **Good for**

    * Queries filtering on many columns at once

    **Use it when**

    * You don't know which column will be filtered
    * You want one compact index instead of many

    **Example**

    ```sql
    CREATE INDEX idx_bloom ON t USING bloom (a, b, c);
    ```

    **Reality**

    > Niche, but excellent for exploratory / analytics queries.

??? note "8️⃣ RUM (extension, advanced GIN)"

    **What it is**

    * Enhanced GIN with ordering and ranking

    **Good for**

    * Full-text search with ranking
    * "Top-N" text results

    **Use it when**

    * You need relevance-ordered text search

    **Reality**

    > Powerful but heavier — use only if GIN isn't enough.

??? note "9️⃣ Partial indexes (modifier, not a type)"

    **What it is**

    * Index only rows matching a condition

    **Good for**

    * "Active" rows
    * Soft deletes
    * Sparse data

    **Use it when**

    * Most rows don't need indexing

    **Example**

    ```sql
    CREATE INDEX idx_active_users
    ON users(last_login)
    WHERE active = true;
    ```

??? note "🔟 Expression indexes (modifier)"

    **What it is**

    * Index on a function or expression

    **Good for**

    * Case-insensitive search
    * Computed values

    **Example**

    ```sql
    CREATE INDEX idx_lower_email ON users (lower(email));
    ```

??? note "1️⃣1️⃣ Covering indexes (`INCLUDE`) (modifier)"

    **What it is**

    * Adds non-key columns to avoid heap fetch

    **Good for**

    * Read-heavy queries

    **Example**

    ```sql
    CREATE INDEX idx_orders_user
    ON orders(user_id)
    INCLUDE (status, created_at);
    ```

---

## Quick decision guide

| Query type             | Index      |
| ---------------------- | ---------- |
| `=` / `<` / `>`        | B-tree     |
| JSONB / arrays         | GIN        |
| Time-series huge table | BRIN       |
| Geo / distance         | GiST       |
| IP / hierarchical      | SP-GiST    |
| Full-text              | GIN / RUM  |
| Sparse "active" rows   | Partial    |
| Case-insensitive       | Expression |

---

## Coach's rule of thumb

* Start with **B-tree**
* Add **GIN** for JSON/text
* Add **BRIN** for massive time-ordered tables
* Reach for GiST/SP-GiST only when you *know* why
