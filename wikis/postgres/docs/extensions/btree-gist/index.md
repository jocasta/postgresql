# btree_gist

Provides GiST operator classes for ordinary scalar types. Its main use: **exclusion constraints** that mix scalar equality with range overlap (e.g. "no double-booking the same room").

- **Type:** contrib (ships with PostgreSQL)
- **Preload required:** No
- **Docs:** <https://www.postgresql.org/docs/current/btree-gist.html>

---

## Install

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;
```

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
