# net

Per-interface network traffic and error counters (from `/proc/net/dev` on Linux).

- **Plugin:** `[[inputs.net]]`
- **Platforms:** all
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/net>

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.net]]
  # interfaces = []          # all "up" interfaces, excluding loopback
```

| Option | Default | Description |
|---|---|---|
| `interfaces` | all up interfaces except loopback | Explicit interfaces (glob patterns allowed), collected regardless of state, e.g. `["eth*", "enp0s[0-1]", "lo"]` |
| `ignore_protocol_stats` | — | **Deprecated in 1.37, ignored** — see notes |

---

## Database tables

### `telegraf.net`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.net_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`net_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |
| `interface` | Interface name (`eth0`, `ens5`, …) | `interfaces` |

**Fields** (`net`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `bytes_sent` | integer (counter, bytes) | Bytes transmitted | Default |
| `bytes_recv` | integer (counter, bytes) | Bytes received | Default |
| `packets_sent` | integer (counter) | Packets transmitted | Default |
| `packets_recv` | integer (counter) | Packets received | Default |
| `err_in` | integer (counter) | Receive errors | Default |
| `err_out` | integer (counter) | Transmit errors | Default |
| `drop_in` | integer (counter) | Received packets dropped | Default |
| `drop_out` | integer (counter) | Transmitted packets dropped | Default |
| `speed` | integer (Mbit/s) | Link speed; `-1` if not reported (common for virtual NICs) | Default (Linux) |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).

---

## Notes

- All traffic fields are cumulative counters — use `lag()` over `tag_id` to get rates (see [diskio](diskio.md)).
- Older Telegraf versions also wrote system-wide protocol counters (`tcp_*`, `udp_*`, `icmp_*`, `ip_*` from `/proc/net/snmp`) as rows with `interface = 'all'`. As of 1.37 this plugin no longer does; use the `[[inputs.nstat]]` plugin for protocol stats such as TCP retransmits.
