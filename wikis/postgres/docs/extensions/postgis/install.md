# PostGIS: Install

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
-- optional extras
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_raster;   -- split out of core postgis since 3.0

SELECT postgis_full_version();
```
