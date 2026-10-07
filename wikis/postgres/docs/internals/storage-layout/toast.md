# TOAST

**The Oversized-Attribute Storage Technique** — how values larger than a page fit.

- Triggered when a row exceeds `TOAST_TUPLE_THRESHOLD` (~2 KB, i.e. about 1/4 of a page).
- PostgreSQL then compresses and/or moves the largest variable-length values out of line until the row fits under `toast_tuple_target` (default ~2 KB, settable per table).
- Out-of-line values live in the table's **TOAST table** `pg_toast.pg_toast_<table_oid>`, split into ~2 KB chunks (`chunk_id`, `chunk_seq`, `chunk_data`) with its own index. The main row keeps an 18-byte pointer.
- Maximum value size: 1 GB.

| Storage strategy | Compress? | Out-of-line? | Default for |
|---|---|---|---|
| `PLAIN` | No | No | Fixed-length types (`int`, `timestamp`) |
| `MAIN` | Yes | Only as last resort | `numeric` |
| `EXTERNAL` | No | Yes | — (good for pre-compressed data or fast `substr()` on text) |
| `EXTENDED` | Yes | Yes | Most varlena: `text`, `bytea`, `jsonb` |

Compression: `pglz` (default) or `lz4` (PG14+, faster — recommended) via `default_toast_compression` or per column.

```sql
SELECT reltoastrelid::regclass FROM pg_class WHERE relname = 'documents';

ALTER TABLE documents ALTER COLUMN body SET STORAGE EXTERNAL;
ALTER TABLE documents ALTER COLUMN body SET COMPRESSION lz4;   -- applies to new values
SET default_toast_compression = 'lz4';

SELECT id, pg_column_size(body) AS stored_bytes,
       octet_length(body) AS raw_bytes,
       pg_column_compression(body) AS method
FROM documents LIMIT 5;
```

!!! warning
    Updating *any* column of a row copies the TOAST pointer, not the TOASTed data — cheap. But updating the TOASTed column itself rewrites all its chunks, and big jsonb values that are updated often cause lots of TOAST churn and bloat.
