# Postmaster, backends and process-per-connection

- The **postmaster** is the first process started (`postgres -D $PGDATA`). It owns the listening sockets, allocates shared memory, and `fork()`s every other process. It never touches shared data structures itself, so a crashing child can't corrupt it.
- Each client connection gets its own **backend process** (process-per-connection). The backend parses, plans and executes queries for that session only.
- If any child crashes (e.g. segfault, OOM-kill), the postmaster kills all other children and runs **crash recovery**, because shared memory may be corrupt. This is why one OOM-killed backend restarts the whole server.
- Consequences of the model:
    - Each connection costs memory (a few MB baseline, plus `work_mem` etc.) and a slot in the proc array — so hundreds/thousands of connections hurt. Use a pooler like PgBouncer.
    - Connection setup is expensive (`fork()` + authentication + catalog cache warm-up).
    - Snapshot computation scales with the number of connections (much improved in PG14).

```sql
-- Every process the server is running, by type
SELECT backend_type, count(*)
FROM pg_stat_activity
GROUP BY backend_type
ORDER BY count(*) DESC;
```

```bash
ps -ef --forest | grep [p]ostgres
# postgres: checkpointer
# postgres: background writer
# postgres: walwriter
# postgres: autovacuum launcher
# postgres: logical replication launcher
# postgres: app appdb 10.0.0.12(53412) idle
```
