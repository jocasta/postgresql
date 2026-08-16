# Pipe Dump Restore

## Important - With Pipe Dump you can't take advantage of parallel loading


## GLOBALS

**This will:**

* Create roles

* Preserve memberships

* Skip passwords > RDS Can't copy password hashes


```sh
pg_dumpall \
  -h old-host \
  -U master_user \
  --no-role-passwords \
  --globals-only \
| psql \
  -h new-host \
  -U master_user \
  postgres
```

<hr>

## DATA


```sh
pg_dump \
  -h old-host \
  -U master_user \
  -d source_db \
| psql \
  -h new-host \
  -U master_user \
  -d target_db
```



