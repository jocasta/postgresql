

## (1) Create Database on Target

```sql
CREATE DATABASE awx;
CREATE USER awx WITH PASSWORD 'securepassword';
--GRANT ALL PRIVILEGES ON DATABASE awx TO awx;
```


## (2) Dump the old DB 

```bash
nohup time pg_dump -v \
-h es-vrxi-pgrd19.control.ros.gov.uk -p 5432 -U rosdba_prod \
-d awx \
-Fd -j 4 \
-f /db/PostgreSQL/migration/tower_dump.dmp \
> /db/PostgreSQL/migration/tower_dump.log 2>&1 &
```
 

## (3) Restore the Dump to the New Host

```bash
nohup time pg_restore -v -U postgres -d awx -j 2 \
 /db/PostgreSQL/migration/tower_dump.dmp \
> /db/PostgreSQL/migration/tower_restore.log 2>&1 &
```
 

## (4) Run Analyze

```bash
$ vacuumdb -v --analyze-only -U postgres -d awx 
```