# kernel

Kernel counters from `/proc/stat` and entropy, plus optional Kernel Samepage Merging (KSM) and Pressure Stall Information (PSI).

- **Plugin:** `[[inputs.kernel]]`
- **Platforms:** Linux only
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/kernel>

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.kernel]]
  # collect = []          # options: "ksm", "psi"
```

| Option | Default | Description |
|---|---|---|
| `collect` | `[]` | Extra groups: `"ksm"` (Kernel Samepage Merging, from `/sys/kernel/mm/ksm`), `"psi"` (Pressure Stall Information, from `/proc/pressure`, kernel 4.20+) |

---

## Database tables

### `telegraf.kernel`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.kernel_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`kernel_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |

**Fields** (`kernel`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `boot_time` | integer | Boot time, seconds since epoch (`btime`) | Default |
| `context_switches` | integer (counter) | Context switches since boot (`ctxt`) | Default |
| `interrupts` | integer (counter) | Interrupts serviced since boot (`intr`) | Default |
| `processes_forked` | integer (counter) | Processes forked since boot (`processes`) | Default |
| `disk_pages_in` | integer (counter) | Pages paged in from disk (`page` 0) — only on kernels that expose it | Default |
| `disk_pages_out` | integer (counter) | Pages paged out to disk (`page` 1) — only on kernels that expose it | Default |
| `entropy_avail` | integer | Entropy available in the random pool | Default |
| `ksm_full_scans` | integer | Number of full scans of all mergeable areas | `collect = ["ksm"]` |
| `ksm_max_page_sharing` | integer | Max sharing allowed per KSM page | `collect = ["ksm"]` |
| `ksm_merge_across_nodes` | integer | Flag: merge pages across NUMA nodes | `collect = ["ksm"]` |
| `ksm_pages_shared` | integer | Shared KSM pages in use | `collect = ["ksm"]` |
| `ksm_pages_sharing` | integer | Number of sites sharing those pages (memory saved) | `collect = ["ksm"]` |
| `ksm_pages_to_scan` | integer | Pages scanned before ksmd sleeps | `collect = ["ksm"]` |
| `ksm_pages_unshared` | integer | Unique pages repeatedly checked for merging | `collect = ["ksm"]` |
| `ksm_pages_volatile` | integer | Pages changing too fast to merge | `collect = ["ksm"]` |
| `ksm_run` | integer | Flag: ksmd running | `collect = ["ksm"]` |
| `ksm_sleep_millisecs` | integer | ksmd sleep between scans (ms) | `collect = ["ksm"]` |
| `ksm_stable_node_chains` | integer | KSM pages that hit the `max_page_sharing` limit | `collect = ["ksm"]` |
| `ksm_stable_node_chains_prune_millisecs` | integer | How often KSM checks page metadata hitting the dedup limit (ms) | `collect = ["ksm"]` |
| `ksm_stable_node_dups` | integer | Duplicated KSM pages | `collect = ["ksm"]` |
| `ksm_use_zero_pages` | integer | Flag: empty pages treated specially | `collect = ["ksm"]` |

### `telegraf.pressure`

Separate measurement, only with `collect = ["psi"]`. `resource=cpu,type=full` is omitted (always zero).

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.pressure_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`pressure_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |
| `resource` | `cpu`, `memory` or `io` | `collect = ["psi"]` |
| `type` | `some` (at least one task stalled) or `full` (all non-idle tasks stalled) | `collect = ["psi"]` |

**Fields** (`pressure`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `avg10` | float (%) | % of time stalled, 10 s average | `collect = ["psi"]` |
| `avg60` | float (%) | % of time stalled, 60 s average | `collect = ["psi"]` |
| `avg300` | float (%) | % of time stalled, 300 s average | `collect = ["psi"]` |
| `total` | integer (counter, µs) | Total stall time | `collect = ["psi"]` |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).

---

## Notes

- PSI `avg*` and `total` are written as separate rows with the same `time` / `tag_id`.
- PSI is the best single indicator of resource saturation on a Postgres host — `memory full` or `io full` above zero means queries are stalling.
