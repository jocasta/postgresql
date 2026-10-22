# mem

System memory usage. On Linux the values come from `/proc/meminfo`. All sizes are bytes unless noted.

- **Plugin:** `[[inputs.mem]]`
- **Platforms:** all (fields vary by platform)
- **README:** <https://github.com/influxdata/telegraf/tree/master/plugins/inputs/mem>

!!! tip
    `used` excludes page cache, so a Postgres host with low `free` but high `available` is healthy — the OS is caching data files. See <https://www.linuxatemyram.com/>.

---

## Configuration

Defaults shown (commented lines are the defaults when unset).

```toml
[[inputs.mem]]
  # collect_extended = false
```

| Option | Default | Description |
|---|---|---|
| `collect_extended` | `false` | Collect extra fields from `/proc/meminfo` (Linux) or performance counters (Windows) |

---

## Database tables

### `telegraf.mem`

Hypertable (`time`, `tag_id`, then one column per field), plus tag table `telegraf.mem_tag` (`tag_id` + one column per tag) — with `tags_as_foreign_keys = true`.

**Tags** (`mem_tag`)

| Column | Description | Enabled by |
|---|---|---|
| `host` | Hostname of the Telegraf agent (global tag) | Always (agent `omit_hostname = false`) |

**Fields** (`mem`)

| Column | Type | Description | Enabled by |
|---|---|---|---|
| `total` | integer | Total usable RAM | Default (all) |
| `available` | integer | RAM available for new work without swapping (`MemAvailable`) | Default (all) |
| `available_percent` | float | `available / total * 100` (float) | Default (all) |
| `used` | integer | `total - available` on Linux | Default (all) |
| `used_percent` | float | `used / total * 100` (float) | Default (all) |
| `free` | integer | Completely unused RAM (`MemFree`) | Default (Linux, BSD, macOS) |
| `active` | integer | Recently used memory, not usually reclaimed | Default (Linux, BSD, macOS) |
| `inactive` | integer | Less recently used memory, reclaimable | Default (Linux, BSD, macOS) |
| `buffered` | integer | Raw block-device buffers (`Buffers`) | Default (Linux, FreeBSD) |
| `cached` | integer | Page cache (`Cached`) — includes Postgres data files cached by the OS | Default (Linux, BSD) |
| `shared` | integer | Shared memory / tmpfs (`Shmem`) — includes Postgres `shared_buffers` | Default (Linux) |
| `slab` | integer | Kernel data-structure cache | Default (Linux) |
| `sreclaimable` | integer | Reclaimable part of slab | Default (Linux) |
| `sunreclaim` | integer | Unreclaimable part of slab | Default (Linux) |
| `dirty` | integer | Data waiting to be written to disk | Default (Linux) |
| `write_back` | integer | Data actively being written to disk | Default (Linux) |
| `write_back_tmp` | integer | Writeback using FUSE temporary buffers | Default (Linux) |
| `mapped` | integer | Files mmap'd into memory | Default (Linux) |
| `page_tables` | integer | Memory used by page tables — large with many backends and no huge pages | Default (Linux) |
| `commit_limit` | integer | Total memory that can be committed (`CommitLimit`) | Default (Linux) |
| `committed_as` | integer | Memory currently committed (`Committed_AS`) | Default (Linux) |
| `huge_pages_total` | integer | Size of the huge page pool (pages) | Default (Linux) |
| `huge_pages_free` | integer | Unallocated huge pages | Default (Linux) |
| `huge_page_size` | integer | Huge page size (bytes) | Default (Linux) |
| `swap_total` | integer | Total swap | Default (Linux) |
| `swap_free` | integer | Unused swap | Default (Linux) |
| `swap_cached` | integer | Swapped-out memory also still in RAM | Default (Linux) |
| `vmalloc_total` | integer | Total vmalloc address space | Default (Linux) |
| `vmalloc_used` | integer | vmalloc space used | Default (Linux) |
| `vmalloc_chunk` | integer | Largest free vmalloc block | Default (Linux) |
| `high_total` | integer | HighMem total (32-bit systems) | Default (Linux) |
| `high_free` | integer | HighMem free | Default (Linux) |
| `low_total` | integer | LowMem total (32-bit systems) | Default (Linux) |
| `low_free` | integer | LowMem free | Default (Linux) |
| `wired` | integer | Memory that cannot be paged out | Default (BSD, macOS) |
| `laundry` | integer | Dirty pages queued for laundering | Default (FreeBSD) |
| `active_anon` | integer | Active anonymous (process) memory | `collect_extended = true` (Linux) |
| `inactive_anon` | integer | Inactive anonymous memory | `collect_extended = true` (Linux) |
| `active_file` | integer | Active file-backed (page cache) memory | `collect_extended = true` (Linux) |
| `inactive_file` | integer | Inactive file-backed memory | `collect_extended = true` (Linux) |
| `percpu` | integer | Memory used by per-CPU allocators | `collect_extended = true` (Linux) |
| `unevictable` | integer | Memory that cannot be reclaimed (e.g. mlock'd) | `collect_extended = true` (Linux) |
| `commit_limit` | integer | Commit limit | `collect_extended = true` (Windows) |
| `commit_total` | integer | Committed memory | `collect_extended = true` (Windows) |
| `page_file_avail` | integer | Page file available | `collect_extended = true` (Windows) |
| `page_file_total` | integer | Page file size | `collect_extended = true` (Windows) |
| `phys_avail` | integer | Physical memory available | `collect_extended = true` (Windows) |
| `phys_total` | integer | Physical memory total | `collect_extended = true` (Windows) |
| `virtual_avail` | integer | Virtual memory available | `collect_extended = true` (Windows) |
| `virtual_total` | integer | Virtual memory total | `collect_extended = true` (Windows) |

!!! note "Column types"
    Telegraf maps field types to PostgreSQL columns: float → `double precision`, signed integer → `bigint`,
    unsigned integer → `numeric` (default `uint64_type`), string → `text`. New fields are added as columns
    the first time they appear (`add_column_templates`).
