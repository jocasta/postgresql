# system

General system stats — load average, uptime, CPU counts, logged-in users — similar to `uptime`. Newer versions can also report OS and hardware (DMI) details.

- **Plugin:** `[[inputs.system]]`
- **Platforms:** all (`dmi` not on macOS/BSD)
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/system>

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.system]]
  # include = ["legacy"]     # options: legacy, cpus, dmi, load, os, uptime, users
  # os_cache_ttl = "8h"
  # dmi_cache_ttl = "8h"
```

| Option | Default | Description |
|---|---|---|
| `include` | `["legacy"]` | Groups to collect: `legacy`, `cpus`, `dmi`, `load`, `os`, `uptime`, `users` |
| `os_cache_ttl` | `"8h"` | How long to cache `os` data between gathers (`0` = every gather) |
| `dmi_cache_ttl` | `"8h"` | How long to cache `dmi` data between gathers (`0` = every gather) |

!!! tip
    `legacy` (the default) writes **three sparse rows** per gather into `telegraf.system`. For a SQL output, prefer the fine-grained groups, which write **one row** per gather: `include = ["load", "users", "cpus", "uptime"]` gives the same fields as `legacy` minus `uptime_format`.

    `n_users` / `n_unique_users` need read access to `/var/run/utmp` (add `telegraf` to the `utmp` group on some systems).

---

## Database tables

### `telegraf.system`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.system_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`system_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |

**Fields** (`system`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `load1` | float | 1-minute load average | `include` has `load` or `legacy` |
| `load5` | float | 5-minute load average | `include` has `load` or `legacy` |
| `load15` | float | 15-minute load average | `include` has `load` or `legacy` |
| `n_cpus` | integer | Logical CPUs | `include` has `cpus` or `legacy` |
| `n_physical_cpus` | integer | Physical CPUs | `include` has `cpus` or `legacy` |
| `uptime` | integer (s) | Uptime in seconds | `include` has `uptime` or `legacy` |
| `uptime_format` | string | Human-readable uptime (e.g. `5 days, 3:04`) | `legacy` only |
| `n_users` | integer | Logged-in user sessions | `include` has `users` or `legacy` |
| `n_unique_users` | integer | Unique logged-in usernames | `include` has `users` or `legacy` |
| `os` | string | OS family (`linux`) | `include` has `os` |
| `arch` | string | Architecture (`x86_64`) | `include` has `os` |
| `platform` | string | Distribution (`debian`, `fedora`) | `include` has `os` |
| `platform_family` | string | Platform family (`debian`, `rhel`) | `include` has `os` |
| `platform_version` | string | Distribution version | `include` has `os` |
| `kernel_version` | string | `uname -r` | `include` has `os` |
| `bios_vendor` | string | BIOS vendor | `include` has `dmi` |
| `bios_version` | string | BIOS version | `include` has `dmi` |
| `bios_date` | string | BIOS release date | `include` has `dmi` |
| `board_vendor` | string | Motherboard vendor | `include` has `dmi` |
| `board_product` | string | Motherboard product name | `include` has `dmi` |
| `board_version` | string | Motherboard version | `include` has `dmi` |
| `board_serial` | string | Motherboard serial (restricted) | `include` has `dmi` |
| `board_asset_tag` | string | Motherboard asset tag (restricted) | `include` has `dmi` |
| `chassis_vendor` | string | Chassis vendor | `include` has `dmi` |
| `chassis_type_code` | string | SMBIOS chassis type code | `include` has `dmi` |
| `chassis_type` | string | Chassis type description | `include` has `dmi` |
| `chassis_version` | string | Chassis version | `include` has `dmi` |
| `chassis_serial` | string | Chassis serial (restricted) | `include` has `dmi` |
| `chassis_asset_tag` | string | Chassis asset tag (restricted) | `include` has `dmi` |
| `product_vendor` | string | System vendor (e.g. `Dell Inc.`) | `include` has `dmi` |
| `product_name` | string | System product (e.g. `PowerEdge R750`) | `include` has `dmi` |
| `product_family` | string | Product family | `include` has `dmi` |
| `product_version` | string | Product version | `include` has `dmi` |
| `product_serial` | string | Product serial (restricted) | `include` has `dmi` |
| `product_sku` | string | Product SKU | `include` has `dmi` |
| `product_uuid` | string | Product UUID (restricted) | `include` has `dmi` |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).

---

## Notes

- `dmi` fields marked *restricted* read as `unknown` unless Telegraf runs as root.
- `os` and `dmi` string fields are near-static — consider a separate `[[inputs.system]]` with a long `interval` for them, so they don't repeat in every row of the hypertable.
