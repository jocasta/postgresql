# processes

Process counts grouped by state. Linux reads `/proc`; BSD/macOS run `ps`.

- **Plugin:** `[[inputs.processes]]`
- **Platforms:** Linux, FreeBSD, macOS (not Windows)
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/processes>

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.processes]]
  # use_sudo = false
```

| Option | Default | Description |
|---|---|---|
| `use_sudo` | `false` | Run `ps` with sudo on BSD/macOS for system-wide stats (needs a passwordless sudoers entry for `/bin/ps`). Not used on Linux. |

Running Telegraf in a container: mount the host `/proc` and set `HOST_PROC`, e.g. `-v /proc:/rootfs/proc:ro -e HOST_PROC=/rootfs/proc`.

---

## Database tables

### `telegraf.processes`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.processes_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`processes_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |

**Fields** (`processes`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `total` | integer | Total processes | Default |
| `running` | integer | Running or runnable (`R`) | Default |
| `sleeping` | integer | Interruptible sleep (`S`) | Default |
| `blocked` | integer | Uninterruptible sleep, usually waiting on disk I/O (`D`) | Default |
| `stopped` | integer | Stopped/traced (`T`) | Default |
| `zombie` | integer | Exited but not reaped by parent (`Z`) | Default |
| `dead` | integer | Dead (`X`) | Default |
| `idle` | integer | Idle kernel threads (`I`) | Default (BSD, Linux 4+) |
| `paging` | integer | Paging (`W`, Linux < 2.6 only) | Default (Linux) |
| `parked` | integer | Parked kernel threads | Default (Linux) |
| `total_threads` | integer | Total threads | Default (Linux) |
| `wait` | integer | Waiting on interrupt (`W`) | Default (FreeBSD) |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).

---

## Notes

- A sustained non-zero `blocked` count on a Postgres host usually means storage can't keep up — check [diskio](diskio.md) `io_await`.
- A growing `zombie` count points to a parent process not reaping children.
