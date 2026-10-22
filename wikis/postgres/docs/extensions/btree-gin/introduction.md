# btree_gin: Introduction

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/btree-gin.html>

## What it does

btree_gin provides GIN operator classes that behave like B-tree for ordinary scalar types (`int`, `bigint`, `text`,
`timestamptz`, `uuid`, `numeric`, …). GIN normally only indexes "multi-value" types such as arrays, `jsonb` and `tsvector`;
with btree_gin you can build a **single multi-column GIN index** that combines, say, a `tenant_id` equality with a
`jsonb @>` or full-text match, instead of relying on two separate indexes and a BitmapAnd.

## How it's installed

Full procedure: [Install](install.md).

It's a contrib module — it ships in the PostgreSQL **contrib** package (`postgresql-contrib` on most distros; already included in the `postgresql-<ver>` package on Debian/Ubuntu and in the official Docker image), so there's nothing extra to download.
No preload or restart — run `CREATE EXTENSION btree_gin;` in the database, then use the scalar columns in a `USING gin (...)` index.

---

## Example

```sql
CREATE TABLE products (
    id         bigint PRIMARY KEY,
    tenant_id  int    NOT NULL,
    tags       text[] NOT NULL,
    attrs      jsonb
);

-- One GIN index that serves "this tenant + these tags"
CREATE INDEX products_tenant_tags_gin
    ON products USING gin (tenant_id, tags);

SELECT id
FROM products
WHERE tenant_id = 42
  AND tags @> ARRAY['red', 'sale'];
```

---

## When to use it

- Multi-tenant tables where every array / jsonb / full-text query also filters on a scalar like `tenant_id`.
- Low-cardinality scalar columns where a GIN posting list is smaller than a B-tree.

---

## When not to

- Pure scalar equality / range lookups — a normal B-tree is faster and supports ordering and uniqueness; GIN does neither.
- Write-heavy tables — GIN updates are expensive (see `fastupdate` / `gin_pending_list_limit`).

See also: [GIN indexes](../../indexes/4-gin-index.md), [btree_gist](../btree-gist/index.md).
