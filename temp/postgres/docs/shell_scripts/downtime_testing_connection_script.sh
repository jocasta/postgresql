#!/bin/bash

HOST="host"
USER="mike"
DB="testdb"
OUTFILE="pg_upgrade_monitor.log"

# Optional:
# export PGPASSWORD='yourpassword'

# Convert HH:MM:SS → seconds
to_seconds() {
    IFS=: read h m s <<< "$1"
    echo $((10#$h * 3600 + 10#$m * 60 + 10#$s))
}

while true; do
    TIMESTAMP=$(date +"%H:%M:%S")

    VERSION=$(timeout 5 psql -h "$HOST" -U "$USER" -d "$DB" -t -A -c "SHOW server_version;" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$VERSION" ]; then
        echo "$TIMESTAMP, $VERSION" >> "$OUTFILE"

        # Stop when version is 16.x
        if [[ "$VERSION" == 16.* ]]; then
            echo "$TIMESTAMP, detected version 16 ($VERSION)" >> "$OUTFILE"

            # ---- Downtime calculation ----

            # Find first occurrence of "no connection"
            FIRST_FAIL_LINE=$(grep -n "no connection" "$OUTFILE" | head -n1 | cut -d: -f1)

            if [ -n "$FIRST_FAIL_LINE" ] && [ "$FIRST_FAIL_LINE" -gt 1 ]; then
                # Get last successful timestamp before outage
                LAST_OK=$(sed -n "$((FIRST_FAIL_LINE-1))p" "$OUTFILE" | cut -d',' -f1)

                START_SEC=$(to_seconds "$LAST_OK")
                END_SEC=$(to_seconds "$TIMESTAMP")

                DOWNTIME=$((END_SEC - START_SEC))

                echo "$TIMESTAMP, downtime_seconds=$DOWNTIME" >> "$OUTFILE"

                MIN=$((DOWNTIME / 60))
                SEC=$((DOWNTIME % 60))

                echo "$TIMESTAMP, downtime_pretty=${MIN}m${SEC}s" >> "$OUTFILE"
            else
                echo "$TIMESTAMP, could not determine downtime" >> "$OUTFILE"
            fi

            break
        fi

    else
        echo "$TIMESTAMP, no connection" >> "$OUTFILE"
    fi

    sleep 10
done