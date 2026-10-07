# Segments and forks

Each relation is stored as one or more files per **fork**, each split into **1 GB segments**:

```
base/16384/16422        main fork, first 1 GB
base/16384/16422.1      main fork, second 1 GB
base/16384/16422.2      ...
base/16384/16422_fsm    free space map fork
base/16384/16422_vm     visibility map fork
base/16384/16422_init   init fork (unlogged tables/indexes only)
```

| Fork | Purpose |
|---|---|
| `main` | The actual data / index pages |
| `fsm` | Free Space Map — where there's room for new tuples |
| `vm` | Visibility Map — all-visible / all-frozen bits per heap page |
| `init` | Empty template copied over an **unlogged** relation after a crash |

Segment size is fixed at compile time (`--with-segsize`); 1 GB keeps files manageable on any filesystem.

```sql
SELECT pg_relation_size('orders', 'main') AS main,
       pg_relation_size('orders', 'fsm')  AS fsm,
       pg_relation_size('orders', 'vm')   AS vm,
       pg_table_size('orders')            AS table_incl_toast,
       pg_total_relation_size('orders')   AS with_indexes;
```
