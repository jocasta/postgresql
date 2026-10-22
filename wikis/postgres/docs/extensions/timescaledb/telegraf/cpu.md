# cpu

CPU time and utilisation, per CPU and/or for the whole system.

- **Plugin:** `[[inputs.cpu]]`
- **Platforms:** all
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/cpu>

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false
  core_tags = false
```

| Option | Default | Description |
|---|---|---|
| `percpu` | `true` | Report a row per CPU (`cpu0`, `cpu1`, …) |
| `totalcpu` | `true` | Report a combined row with `cpu = 'cpu-total'` |
| `collect_cpu_time` | `false` | Also report raw cumulative CPU seconds (`time_*` fields) |
| `report_active` | `false` | Also report `usage_active` (and `time_active` if `collect_cpu_time`) — sum of non-idle states |
| `core_tags` | `false` | Add `core_id` and `physical_id` tags (from `/proc/cpuinfo`) |

---

## Database tables

### `telegraf.cpu`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.cpu_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`cpu_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |
| `cpu` | CPU ID (`cpu0`…) or `cpu-total` | `percpu` / `totalcpu` |
| `core_id` | Physical core ID | `core_tags = true` |
| `physical_id` | Physical socket/package ID | `core_tags = true` |

**Fields** (`cpu`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `time_user` | float | Seconds spent in user mode | `collect_cpu_time = true` |
| `time_system` | float | Seconds spent in kernel mode | `collect_cpu_time = true` |
| `time_idle` | float | Seconds idle | `collect_cpu_time = true` |
| `time_nice` | float | Seconds in user mode with low priority (nice) | `collect_cpu_time = true` |
| `time_iowait` | float | Seconds idle while waiting for I/O | `collect_cpu_time = true` |
| `time_irq` | float | Seconds servicing hardware interrupts | `collect_cpu_time = true` |
| `time_softirq` | float | Seconds servicing software interrupts | `collect_cpu_time = true` |
| `time_steal` | float | Seconds stolen by the hypervisor for other VMs | `collect_cpu_time = true` |
| `time_guest` | float | Seconds running a guest VM | `collect_cpu_time = true` |
| `time_guest_nice` | float | Seconds running a niced guest VM | `collect_cpu_time = true` |
| `time_active` | float | Sum of all non-idle CPU seconds (**includes iowait**) | `collect_cpu_time = true` **and** `report_active = true` |
| `usage_user` | float | % of CPU time in user mode (excluding guest) | Default |
| `usage_system` | float | % in kernel mode | Default |
| `usage_idle` | float | % idle | Default |
| `usage_nice` | float | % in niced user mode (excluding guest_nice) | Default |
| `usage_iowait` | float | % idle waiting for I/O | Default |
| `usage_irq` | float | % servicing hardware interrupts | Default |
| `usage_softirq` | float | % servicing software interrupts | Default |
| `usage_steal` | float | % stolen by the hypervisor | Default |
| `usage_guest` | float | % running a guest VM | Default |
| `usage_guest_nice` | float | % running a niced guest VM | Default |
| `usage_active` | float | % of all non-idle time (**includes iowait**) | `report_active = true` |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).

---

## Notes

- `usage_*` fields are percentages computed from the difference between two samples, so the **first gather after start has no usage row**.
- With `collect_cpu_time = true`, the `time_*` and `usage_*` fields are written as **separate rows** with the same `time` / `tag_id`.
- With `percpu = true` the tag table gets one row per CPU per host — keep it if you need per-core skew, otherwise set it `false` to cut volume by ~N cores.
