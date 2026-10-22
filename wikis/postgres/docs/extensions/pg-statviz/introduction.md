# pg_statviz: Introduction

- **Type:** third-party (extension + Python CLI)
- **Preload required:** No
- **Repo:** <https://github.com/vyruss/pg_statviz/>

## What it does

pg_statviz is a minimalist extension **plus** a Python utility for time-series analysis and visualisation of PostgreSQL's
internal statistics. The extension takes periodic **snapshots** of cumulative stats (buffers, checkpoints, connections,
I/O, locks, replication, WAL, wait events, transactions, …) into tables in the `pgstatviz` schema via
`SELECT pgstatviz.snapshot();`. The `pg_statviz` CLI then reads those snapshots for a time range and renders graphs
(one module per area: `buf`, `cache`, `checkp`, `conn`, `io`, `lock`, `repl`, `wait`, `wal`, `xact`, …), with an optional
`analyze --ai` mode that adds LLM commentary. Useful as a lightweight, self-contained alternative to a full monitoring stack.

## How it's installed

Two parts: the **extension** on the server (OS package, PGXN or source — no preload or restart, just `CREATE EXTENSION`)
and the **`pg_statviz` Python utility** on any client (`pip install`). Snapshots are then scheduled with cron or
[pg_cron](../pg-cron/index.md). Full procedure: [Install](install.md).

---

## Usage

```bash
pg_statviz --help
pg_statviz buf --host db.example.com -d postgres -U postgres -D 2026-10-01T00:00 2026-10-22T23:59
pg_statviz analyze -d mydb --ai
```

```sql
SELECT pgstatviz.delete_snapshots();   -- clear all snapshots
```
