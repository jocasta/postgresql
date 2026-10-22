# disk

Filesystem space and inode usage per mount point (like `df`).

- **Plugin:** `[[inputs.disk]]`
- **Platforms:** all
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/disk>

!!! warning
    `used_percent` is `used / (used + free)`, **not** `used / total` as `df` reports — the two differ by the reserved-for-root blocks.

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.disk]]
  # mount_points = []          # all mount points
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]
  # ignore_mount_opts = []
```

| Option | Default | Description |
|---|---|---|
| `mount_points` | all mount points | Restrict to these mount points, e.g. `["/", "/var/lib/postgresql"]` |
| `ignore_fs` | `["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]` | Skip mounts with these filesystem types |
| `ignore_mount_opts` | `[]` | Skip mounts with these mount options; `bind` skips bind mounts |

Running Telegraf in a container: mount the host root and set `HOST_PROC` (and optionally `HOST_MOUNT_PREFIX`, which is stripped from the `path` tag), e.g. `docker run -v /:/hostfs:ro -e HOST_MOUNT_PREFIX=/hostfs -e HOST_PROC=/hostfs/proc telegraf`.

---

## Database tables

### `telegraf.disk`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.disk_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`disk_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |
| `path` | Mount point | Default |
| `device` | Device file (without `/dev/`) | Default |
| `fstype` | Filesystem type (`ext4`, `xfs`, …) | Default |
| `mode` | `rw` or `ro` | Default |
| `label` | Device-mapper label (e.g. LVM `vg-lv`) | Only if present |

**Fields** (`disk`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `total` | integer (bytes) | Filesystem size | Default |
| `free` | integer (bytes) | Free space available to non-root users | Default |
| `used` | integer (bytes) | Space used | Default |
| `used_percent` | float (%) | `used / (used + free) * 100` | Default |
| `inodes_total` | integer | Total inodes | Default |
| `inodes_free` | integer | Free inodes | Default |
| `inodes_used` | integer | Used inodes | Default |
| `inodes_used_percent` | float (%) | Inodes used as a percentage of total | Default |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).
