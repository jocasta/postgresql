# diskio

Block-device I/O counters and timings (from `/proc/diskstats` on Linux).

- **Plugin:** `[[inputs.diskio]]`
- **Platforms:** all
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/diskio>

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.diskio]]
  # devices = ["*"]
  # skip_serial_number = true
  # device_tags = []
  # name_templates = []
```

| Option | Default | Description |
|---|---|---|
| `devices` | all devices | Devices to collect, wildcards allowed: `["sda", "nvme*", "vd*"]` |
| `skip_serial_number` | `true` | Set `false` to add the `serial` tag |
| `device_tags` | `[]` | udev properties to add as tags (Linux), e.g. `["ID_FS_TYPE", "ID_FS_USAGE"]` — see `udevadm info -q property -n <dev>` |
| `name_templates` | `[]` | Templates for the `name` tag from udev properties, first match wins — e.g. `["$ID_FS_LABEL", "$DM_VG_NAME/$DM_LV_NAME"]` to show LVM names instead of `dm-0` |

Running Telegraf in a container requires `--privileged` (for `/dev`) and `HOST_PROC`; mount `/run/udev` if using `device_tags` or `name_templates`.

---

## Database tables

### `telegraf.diskio`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.diskio_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`diskio_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |
| `name` | Device name (`sda`, `nvme0n1`, `dm-0`, or from `name_templates`) | Default |
| `serial` | Device serial number (`unknown` if unavailable) | `skip_serial_number = false` |
| `<udev property>` | One column per listed udev property, e.g. `ID_FS_TYPE` | `device_tags` |

**Fields** (`diskio`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `reads` | integer (counter) | Completed read requests | Default |
| `writes` | integer (counter) | Completed write requests | Default |
| `read_bytes` | integer (counter, bytes) | Bytes read | Default |
| `write_bytes` | integer (counter, bytes) | Bytes written | Default |
| `read_time` | integer (counter, ms) | Total ms read requests spent waiting (sums across concurrent requests) | Default |
| `write_time` | integer (counter, ms) | Total ms write requests spent waiting | Default |
| `io_time` | integer (counter, ms) | ms the device had I/O queued (busy time) | Default |
| `weighted_io_time` | integer (counter, ms) | ms × number of requests waiting — basis for average queue depth | Default |
| `iops_in_progress` | integer (gauge) | Requests issued to the driver but not yet completed | Default |
| `merged_reads` | integer (counter) | Adjacent reads merged into one | Default |
| `merged_writes` | integer (counter) | Adjacent writes merged into one | Default |
| `io_util` | float (%) | % of the interval the device was busy (like `iostat %util`) | Default (from 2nd gather) |
| `io_await` | float (ms) | Average time per I/O including queueing (like `iostat await`) | Default (from 2nd gather) |
| `io_svctm` | float (ms) | Average service time per I/O excluding queueing | Default (from 2nd gather) |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).

---

## Notes

- Most fields are **cumulative counters** since boot — compute rates with a window function, e.g.

    ```sql
    SELECT time, tag_id,
           (read_bytes - lag(read_bytes) OVER w) / EXTRACT(EPOCH FROM time - lag(time) OVER w) AS read_bytes_per_sec
    FROM telegraf.diskio
    WINDOW w AS (PARTITION BY tag_id ORDER BY time);
    ```
- `io_util`, `io_await` and `io_svctm` are computed from the previous sample, so they are missing on the first gather.
