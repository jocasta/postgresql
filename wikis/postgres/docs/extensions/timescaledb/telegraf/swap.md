# swap

Swap space usage and swap traffic.

- **Plugin:** `[[inputs.swap]]`
- **Platforms:** all
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/swap>

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.swap]]
  # no configuration
```

This plugin has no plugin-specific options.

---

## Database tables

### `telegraf.swap`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.swap_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`swap_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |

**Fields** (`swap`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `total` | integer (bytes) | Total swap | Default |
| `used` | integer (bytes) | Swap used | Default |
| `free` | integer (bytes) | Swap free | Default |
| `used_percent` | float (%) | Percentage of swap used | Default |
| `in` | integer (counter, bytes) | Data swapped in since boot | Default |
| `out` | integer (counter, bytes) | Data swapped out since boot | Default |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).

---

## Notes

- Rising `in` / `out` matters more than `used`: a Postgres host with some swap used but no swap traffic is fine; steady swap-in means memory pressure.
