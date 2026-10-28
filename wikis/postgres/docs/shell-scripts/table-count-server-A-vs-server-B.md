# Server Count(*) Comparison - Server A Vs Server B

``` bash title="table_count_comparison_server_A_vs_server_B.sh"
#!/usr/bin/env bash
#
# Compare exact row counts (count(*)) for every table on a source and a target
# PostgreSQL server, and print a table of the tables that do not match.
#
# Endpoints are defined below. Passwords are not stored in this script: they
# are taken from SRC_PASSWORD / TGT_PASSWORD, then PGPASSWORD, then ~/.pgpass.
#
# Optional env var:
#   SCHEMAS   comma separated list, e.g. "test,archive,monitoring"
#             (default: every non-system schema)
#
# Exit code: 0 = all counts match, 1 = mismatch/missing tables, 2 = error.

set -euo pipefail

# --- Endpoints ---------------------------------------------------------------
SRC_HOST=source-endpoint
SRC_PORT=5432
SRC_DB=sourcedb
SRC_USER=sourceuser

TGT_HOST=target-endpoint
TGT_PORT=5432
TGT_DB=targetdb
TGT_USER=targetser
# -----------------------------------------------------------------------------

SCHEMAS=${SCHEMAS:-}

# One connection per server. query_to_xml() runs a real count(*) against each
# table, so no statistics/estimates (pg_class.reltuples, n_live_tup) are used.
# Only user tables are counted: PostgreSQL system/catalog schemas (pg_*,
# information_schema), RDS internal schemas and extension-owned tables are
# excluded. Partitions are skipped because the partitioned parent's count
# includes them.
read -r -d '' COUNT_SQL <<'SQL' || true
SELECT n.nspname,
       c.relname,
       (xpath('/row/c/text()',
              query_to_xml(format('SELECT count(*) AS c FROM %I.%I', n.nspname, c.relname),
                           false, true, '')))[1]::text
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p')
  AND NOT c.relispartition
  AND n.nspname NOT IN ('information_schema', 'rdsadmin', 'rds_tools')
  AND n.nspname NOT LIKE 'pg\_%'
  AND NOT EXISTS (SELECT 1 FROM pg_depend d
                  WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.deptype = 'e')
  AND (:'schemas' = '' OR n.nspname = ANY (string_to_array(:'schemas', ',')))
ORDER BY 1, 2;
SQL

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fetch_counts() { # label host port user db password outfile
  local label=$1 host=$2 port=$3 user=$4 db=$5 pass=$6 out=$7
  echo "Counting tables on $label ($host/$db)..." >&2
  (
    if [[ -n $pass ]]; then export PGPASSWORD=$pass; fi
    export PGCONNECT_TIMEOUT=15
    printf '%s\n' "$COUNT_SQL" | psql -X -A -t -F $'\t' -v ON_ERROR_STOP=1 \
      -v "schemas=$SCHEMAS" -h "$host" -p "$port" -U "$user" -d "$db" -f - >"$out"
  ) || { echo "ERROR: counting tables on $label failed" >&2; exit 2; }
}

check_connection() { # label host port user db password
  local label=$1 host=$2 port=$3 user=$4 db=$5 pass=$6 err
  if err=$(
    if [[ -n $pass ]]; then export PGPASSWORD=$pass; fi
    export PGCONNECT_TIMEOUT=10
    psql -X -A -t -v ON_ERROR_STOP=1 -h "$host" -p "$port" -U "$user" -d "$db" -c 'SELECT 1' 2>&1 >/dev/null
  ); then
    echo "Connected to $label ($host:$port/$db as $user)" >&2
  else
    echo "WARNING: no connectivity to $label ($host:$port/$db as $user)" >&2
    echo "         ${err//$'\n'/$'\n'         }" >&2
    return 1
  fi
}

echo "Validating connections..." >&2
conn_ok=0
check_connection source "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_DB" "${SRC_PASSWORD:-${PGPASSWORD:-}}" || conn_ok=1
check_connection target "$TGT_HOST" "$TGT_PORT" "$TGT_USER" "$TGT_DB" "${TGT_PASSWORD:-${PGPASSWORD:-}}" || conn_ok=1
if (( conn_ok != 0 )); then
  echo "ERROR: cannot reach one or more servers - no counts were run." >&2
  echo "       Check VPN/security groups, host names and credentials (SRC_PASSWORD/TGT_PASSWORD/~/.pgpass)." >&2
  exit 2
fi
echo >&2

fetch_counts source "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_DB" "${SRC_PASSWORD:-${PGPASSWORD:-}}" "$tmp/src.tsv" &
src_pid=$!
fetch_counts target "$TGT_HOST" "$TGT_PORT" "$TGT_USER" "$TGT_DB" "${TGT_PASSWORD:-${PGPASSWORD:-}}" "$tmp/tgt.tsv" &
tgt_pid=$!
wait "$src_pid" || exit 2
wait "$tgt_pid" || exit 2

# Full outer join on schema+table; keep only rows that differ or are missing.
awk -F'\t' -v OFS='\t' '
  FNR == 1 { file++ }
  file == 1 { src[$1 FS $2] = $3; keys[$1 FS $2] = 1; next }
  file == 2 { tgt[$1 FS $2] = $3; keys[$1 FS $2] = 1 }
  END {
    print "schema", "table", "source_count", "target_count"
    for (k in keys) {
      s = (k in src) ? src[k] : "MISSING"
      t = (k in tgt) ? tgt[k] : "MISSING"
      if (s != t) print k, s, t
    }
  }' "$tmp/src.tsv" "$tmp/tgt.tsv" >"$tmp/all.tsv"

{ head -n1 "$tmp/all.tsv"; tail -n +2 "$tmp/all.tsv" | sort -t$'\t' -k1,1 -k2,2; } >"$tmp/diff.tsv"

total=$(cut -f1,2 "$tmp/src.tsv" "$tmp/tgt.tsv" | sort -u | wc -l)
bad=$(( $(wc -l <"$tmp/diff.tsv") - 1 ))

if (( bad == 0 )); then
  echo "OK: all $total tables have matching counts."
  exit 0
fi

column -t -s $'\t' "$tmp/diff.tsv"
echo
echo "$bad of $total tables do not match."
exit 1
```
