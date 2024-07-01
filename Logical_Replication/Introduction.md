

## Logical replication
   - Perform a failover to the secondary once it's caught up. 
   - Elegant to use from Postgres. Use `pg_dump --schema-only` and restore that. 
   - Then use `CREATE PUBLICATION` (primary) and `CREATE SUBSCRIPTION` (secondary), and Postgres takes care of the rest. 
   - Even works across different Postgres versions and different machine architectures.

---

## Prerequisites

### (1) Primary Keys

   - Postgres needs to identify individual rows in the tables using a **REPLICA IDENTITY**. This defaults to the **primary key of the table if one is set**
 
   - The net effect is that once you start logical replication, all `UPDATES` and `DELETES` to the tables without primary keys now fail. 

```sql
psycopg2.errors.ObjectNotInPrerequisiteState: cannot delete from table "device_inbox" because it does not have a replica identity and publishes deletes
HINT:  To enable deleting from the table, set REPLICA IDENTITY using ALTER TABLE.
```

You can set the **REPLICA IDENTITY** per table manually, either to an existing unique index or to the full record as a fallback if you really have no better option. (see [PostgreSQL Documentation](https://www.postgresql.org/docs/15/sql-altertable.html#SQL-ALTERTABLE-REPLICA-IDENTITY))


This SQL can be used to find tables that are set to use the default replica identity but don't have a primary key (i.e., they don't have a valid replica identity after all):

This SQL will tell you replication Identities for tables: [replication_indentiy](sql/replication_identity.sql)


### OPTIONS

  - The Easiest Option is to make sure every table has a **primary key** - but for some applications this may not be trivial

One thing to note is that tables might have unique indices already. In Postgres, those can be converted for free with:

 `ALTER TABLE my_table ADD CONSTRAINT PK_my_table PRIMARY KEY USING INDEX my_index;`


### (2) Sequences

* Inbuilt Logical replication does not replicate sequence data
* **IMPORTANT !!!!** - if using this for a mjor upgrade - before switching application to point at the new DB make sure the sequences have been reset to the appropriate value
* e.g. >   SELECT setval('pegadata.report_event_seq', 30000000, true); 

This SQL will generate SQL to restart sequences for tables:

(1) Reset to specific value: [specified_value](../Sequences/reset_sequence_to_specified_value.sql)

(2) Reset to next value: [next_value](../Sequences/reset_sequences_nextval.sql)

(3) Reset to sequence ownership: [ownership](../Sequences/reset_sequence_to_specified_value.sql)