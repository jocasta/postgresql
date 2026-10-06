# PostGIS

Spatial and geographic types, functions and indexes for PostgreSQL.

- **Type:** third-party (packaged by most distros / managed providers)
- **Preload required:** No
- **Docs:** <https://postgis.net/documentation/>

---

## Install

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
-- optional extras
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_raster;   -- split out of core postgis since 3.0

SELECT postgis_full_version();
```

---

## geometry vs geography

| | `geometry` | `geography` |
|---|---|---|
| Model | Planar (cartesian) | Spheroid (lat/lon on the earth) |
| Units | Units of the SRID (degrees for 4326) | Metres |
| Function coverage | Full | Subset |
| Speed | Faster | Slower, but correct over long distances |

Rule of thumb: store lat/lon as `geography(Point, 4326)` when you mostly need distances in metres; use `geometry` with a projected SRID for heavy spatial analysis.

---

## Example

```sql
CREATE TABLE places (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  text NOT NULL,
    geog  geography(Point, 4326) NOT NULL
);

CREATE INDEX places_geog_gist ON places USING gist (geog);

-- NOTE: ST_MakePoint takes (longitude, latitude)
INSERT INTO places (name, geog)
VALUES ('Edinburgh Castle', ST_SetSRID(ST_MakePoint(-3.2008, 55.9486), 4326)::geography);

-- Everything within 5 km of a point (index-assisted)
SELECT name
FROM places
WHERE ST_DWithin(geog, ST_MakePoint(-3.19, 55.95)::geography, 5000);

-- 10 nearest neighbours (KNN via <-> uses the GiST index)
SELECT name, ST_Distance(geog, ST_MakePoint(-3.19, 55.95)::geography) AS metres
FROM places
ORDER BY geog <-> ST_MakePoint(-3.19, 55.95)::geography
LIMIT 10;
```

### Common functions

| Function | Purpose |
|---|---|
| `ST_DWithin(a, b, dist)` | Within distance — **use this instead of `ST_Distance(...) < x`** so the index is used |
| `ST_Intersects(a, b)` | Geometries share any space |
| `ST_Contains(a, b)` | `a` fully contains `b` |
| `ST_Distance(a, b)` | Distance |
| `ST_Transform(g, srid)` | Reproject |
| `ST_AsGeoJSON(g)` / `ST_GeomFromGeoJSON(txt)` | GeoJSON in/out |

---

## Gotchas

- Longitude first, latitude second.
- Upgrading PostGIS: `SELECT postgis_extensions_upgrade();` after installing new binaries.
- Major PostgreSQL upgrades (`pg_upgrade`) require the same PostGIS version installed on both old and new clusters.
