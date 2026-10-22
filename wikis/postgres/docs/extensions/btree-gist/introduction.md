# btree_gist: Introduction

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/btree-gist.html>

## What it does

btree_gist provides GiST operator classes that emulate B-tree behaviour for ordinary scalar types (`int`, `text`, `uuid`,
`timestamptz`, …). Its main use is **exclusion constraints** that mix scalar equality with range overlap — e.g.
`EXCLUDE USING gist (room_id WITH =, during WITH &&)` to stop the same room being double-booked — which is impossible with
GiST alone because plain scalars have no GiST support. It also enables multi-column GiST indexes mixing scalars with
geometry / range columns, and KNN (`<->`) ordering on scalars.

## How it's installed

Full procedure: [Install](install.md).

It's a contrib module — it ships in the PostgreSQL **contrib** package (`postgresql-contrib` on most distros; already included in the `postgresql-<ver>` package on Debian/Ubuntu and in the official Docker image), so there's nothing extra to download.
No preload or restart — run `CREATE EXTENSION btree_gist;` in the database, then reference the scalar columns in a GiST index or `EXCLUDE` constraint.

---

## Example: prevent overlapping bookings

```sql
CREATE TABLE room_bookings (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id  int       NOT NULL,
    during   tstzrange NOT NULL,
    EXCLUDE USING gist (room_id WITH =, during WITH &&)
);

INSERT INTO room_bookings (room_id, during) VALUES (1, '[2026-10-05 09:00, 2026-10-05 10:00)');
INSERT INTO room_bookings (room_id, during) VALUES (1, '[2026-10-05 09:30, 2026-10-05 11:00)');
-- ERROR:  conflicting key value violates exclusion constraint
INSERT INTO room_bookings (room_id, during) VALUES (2, '[2026-10-05 09:30, 2026-10-05 11:00)');
-- OK — different room
```

Without `btree_gist`, `room_id WITH =` fails because `int` has no GiST operator class.

### Other uses

- Multi-column GiST index combining a scalar with a geometry / range column (e.g. `(tenant_id, geom)` with PostGIS).
- KNN ordering on scalars: `ORDER BY some_int <-> 100` (distance operator provided by btree_gist).

---

## Gotchas

- Plain scalar lookups are slower via GiST than B-tree — only use it where you need GiST semantics.
- PG18 adds `WITHOUT OVERLAPS` temporal primary keys / unique constraints, which rely on btree_gist for the scalar parts.

See also: [GiST indexes](../../indexes/2-gist-index.md), [btree_gin](../btree-gin/index.md).
