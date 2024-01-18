

## Logical replication
   - Perform a failover to the secondary once it's caught up. 
   - Elegant to use from Postgres. Use `pg_dump --schema-only` and restore that. 
   - Then use `CREATE PUBLICATION` (primary) and `CREATE SUBSCRIPTION` (secondary), and Postgres takes care of the rest. 
   - Even works across different Postgres versions and different machine architectures.

## Prerequisites

   - Postgres needs to identify individual rows in the tables using a REPLICA IDENTITY. This defaults to the **primary key of the table if one is set**
 
   - The net effect is that once you start logical replication, all `UPDATES` and `DELETES` to the tables without primary keys now fail. 

```sql
psycopg2.errors.ObjectNotInPrerequisiteState: cannot delete from table "device_inbox" because it does not have a replica identity and publishes deletes
HINT:  To enable deleting from the table, set REPLICA IDENTITY using ALTER TABLE.
```

You can set the **REPLICA IDENTITY** per table manually, either to an existing unique index or to the full record as a fallback if you really have no better option. (see [PostgreSQL Documentation](https://www.postgresql.org/docs/15/sql-altertable.html#SQL-ALTERTABLE-REPLICA-IDENTITY))


This SQL can be used to find tables that are set to use the default replica identity but don't have a primary key (i.e., they don't have a valid replica identity after all):

```sql
-- FIRST SET THE SEARCH PATH TO ALL YOUR SCHEMAS
-- EXAMPLE: 

set search_path = pegadata, pegarules, public ;

```


```sql
WITH tables_no_pkey AS (
    SELECT tbl.table_schema, tbl.table_name
    FROM information_schema.tables tbl
    WHERE table_type = 'BASE TABLE'
        AND table_schema NOT IN ('pg_catalog', 'information_schema')
        AND NOT EXISTS (
            SELECT 1 
            FROM information_schema.key_column_usage kcu
            WHERE kcu.table_name = tbl.table_name 
                AND kcu.table_schema = tbl.table_schema
        )
)
SELECT pgc.relnamespace, table_name::regclass, pgc.relreplident
FROM tables_no_pkey 
INNER JOIN pg_class as pgc
ON table_name::regclass::oid = pgc.oid
WHERE relreplident = 'd'
order by 1,2,3 ;
-- d = default
```

## OPTIONS

  - The Easiest Option is to make sure every table has a **primary key**

Maybe we should give every table a primary key? IIRC that would have been useful elsewhere, e.g. #15583

Agreed but may not be trivial. I would hope that all new tables we create have primary keys.

One thing to note is that many of these tables probably have worthy unique indices already. In Postgres, those can be converted for free with `ALTER TABLE my_table ADD CONSTRAINT PK_my_table PRIMARY KEY USING INDEX my_index;` (TIL!) but I'm not sure what we can do about SQLite 