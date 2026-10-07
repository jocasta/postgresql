# Vacuum and Bloat Management

Because MVCC leaves old row versions behind, PostgreSQL needs **VACUUM** to reclaim space, keep the visibility map current, and freeze old XIDs.

## Pages

| Page |
|---|
| [Dead tuple lifecycle and HOT pruning](dead-tuples-and-hot-pruning.md) |
| [VACUUM phases](vacuum-phases.md) |
| [Autovacuum triggering, throttling and tuning](autovacuum-tuning.md) |
| [Aggressive vacuum, freeze ages and relfrozenxid](aggressive-vacuum-and-freezing.md) |
| [Bloat causes](bloat-causes.md) |
| [VACUUM FULL, pg_repack and table rewrites](vacuum-full-and-rewrites.md) |
| [REPACK CONCURRENTLY (PostgreSQL 19)](repack-concurrently.md) |
