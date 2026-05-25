
### (1) DUMP



```bash

pg_dump -v \
  -h em-vrai-pgrd48.ros.alpha.gov.uk -U rosdba \
  -d gis \
  -Fd -j 4 \
  --exclude-schema=osmm_archiving \
  --exclude-schema=mapping \
  -f /db/PostgreSQL/dump_restore/gis_alpha.dmp

  ```

### (2) RESTORE


  ```bash

  pg_restore -v \
  -U rosdba \
  -d gis_temp \
  -Fd -j 4 \
  /db/PostgreSQL/dump_restore/gis_alpha.dmp

  ```