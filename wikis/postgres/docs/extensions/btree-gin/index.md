# btree_gin

Provides GIN operator classes for ordinary scalar types (`int`, `text`, `timestamptz`, `uuid`, …), so they can be combined with array / jsonb / tsvector columns in a **single multi-column GIN index**.

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/btree-gin.html>

---

## Install

```sql
CREATE EXTENSION IF NOT EXISTS btree_gin;
```

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

## When not to

- Pure scalar equality / range lookups — a normal B-tree is faster and supports ordering and uniqueness; GIN does neither.
- Write-heavy tables — GIN updates are expensive (see `fastupdate` / `gin_pending_list_limit`).

See also: [GIN indexes](../../indexes/4-gin-index.md), [btree_gist](../btree-gist/index.md).
