# VACUUM FULL, pg_repack and table rewrites

Regular VACUUM makes space **reusable** inside the table but rarely shrinks the file. To give space back to the OS you must **rewrite** the table:

| Method | Lock | Online? | Notes |
|---|---|---|---|
| `VACUUM FULL` | `ACCESS EXCLUSIVE` for the whole run | No | Built-in; needs ~2× space |
| `CLUSTER` | `ACCESS EXCLUSIVE` | No | Also orders rows by an index |
| [pg_repack](../../extensions/pg-repack/index.md) | Brief `ACCESS EXCLUSIVE` at start/end | Yes | Trigger-based, client binary |
| [pg_squeeze](../../extensions/pg-squeeze/index.md) | Brief at end | Yes | Logical-decoding based, scheduler built in |
| [`REPACK (CONCURRENTLY)`](repack-concurrently.md) | Brief `ACCESS EXCLUSIVE` at the end | Yes | **PG19+**, built in, logical-decoding based |
| `REINDEX CONCURRENTLY` | `SHARE UPDATE EXCLUSIVE` | Yes | Index bloat only (PG12+) |

Other operations that rewrite a table (new relfilenode, full copy, `ACCESS EXCLUSIVE`):

- `ALTER TABLE … ALTER COLUMN … TYPE` (unless binary-compatible, e.g. `varchar(10)` → `varchar(20)`)
- `ALTER TABLE … SET TABLESPACE`, `SET LOGGED / UNLOGGED`
- Adding a column with a **volatile** default (e.g. `DEFAULT random()`); constant defaults are instant since PG11
- `TRUNCATE` (new empty file, no copy)

!!! tip
    Rewriting removes bloat but not its cause — fix the xmin horizon / autovacuum settings first, or the table will bloat again.
