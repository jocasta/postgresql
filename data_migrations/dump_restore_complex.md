

### (1) Do you need to speed things up?


<details>
  <summary>High-impact settings that do **not** need restart </summary>

| Setting                           | Suggested Value | Description                                                                                                     | Restart Required |
| --------------------------------- | --------------: | --------------------------------------------------------------------------------------------------------------- | :--------------: |
| `max_parallel_workers_per_gather` |             `0` | **Stops parallel query**, which is what multiplied memory during `REFRESH MATERIALIZED VIEW` and triggered OOM. |       ❌ No       |
| `synchronous_commit`              |           `off` | Faster commits during bulk load.                                                                                |       ❌ No       |
| `maintenance_work_mem`            |           `1GB` | Speeds up index builds (post-data).                                                                             |       ❌ No       |
| `checkpoint_timeout`              |         `30min` | Fewer checkpoints during restore.                                                                               |       ❌ No       |
| `max_wal_size`                    |          `64GB` | Lets WAL grow; avoids checkpoint churn.                                                                         |       ❌ No       |
| `checkpoint_completion_target`    |           `0.9` | Smoother checkpoint IO.                                                                                         |       ❌ No       |
| `wal_compression`                 |            `on` | Reduces WAL volume.                                                                                             |       ❌ No       |
| `autovacuum` (db-level)           |           `off` | Avoids autovacuum competing with restore.                                                                       |       ❌ No       |
| `pgaudit.log` (role/db-level)     |          `none` | Removes audit overhead during restore.                                                                          |       ❌ No       |

</details>

### (2) DUMP



```bash

pg_dump -v \
  -h em-vrai-pgrd48.ros.alpha.gov.uk -U rosdba \
  -d gis \
  -Fd -j 4 \
  --exclude-schema=osmm_archiving \
  --exclude-schema=mapping \
  -f /db/PostgreSQL/dump_restore/gis_alpha.dmp

  ```

### (3) RESTORE


  ```bash

  pg_restore -v \
  -U rosdba \
  -d gis_temp \
  -Fd -j 4 \
  /db/PostgreSQL/dump_restore/gis_alpha.dmp

  ```