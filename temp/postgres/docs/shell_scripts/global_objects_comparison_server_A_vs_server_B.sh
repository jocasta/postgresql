#!/bin/bash

# Connection details
HOST_A="server_a"
HOST_B="server_b"
USER="mike"

TMP_A="/tmp/globals_A.sql"
TMP_B="/tmp/globals_B.sql"

NORM_A="${TMP_A}.norm"
NORM_B="${TMP_B}.norm"

# Dump globals
echo "Dumping globals from A..."
pg_dumpall -h "$HOST_A" -U "$USER" -g > "$TMP_A"

echo "Dumping globals from B..."
pg_dumpall -h "$HOST_B" -U "$USER" -g > "$TMP_B"

# Normalisation function
normalize() {
  sed -E '
    /^--/d;                         # remove comments
    /^$/d;                          # remove blank lines

    # Remove psql meta commands
    /^\\restrict/d;
    /^\\unrestrict/d;

    # Remove noise roles
    /repmgr/d;
    /streaming_barman/d;
    /\bbarman\b/d;

    # Normalize GRANT syntax
    s/ WITH INHERIT (TRUE|FALSE)//;
    s/ WITH ADMIN OPTION//;
    s/ GRANTED BY [^;]+//;

    # Normalize whitespace
    s/[[:space:]]+/ /g;
    s/ ;/;/g;
  ' "$1"
}

echo "Normalizing outputs..."
normalize "$TMP_A" > "$NORM_A"
normalize "$TMP_B" > "$NORM_B"

# Build lookup set from B
SORTED_B="${NORM_B}.sorted"
sort -u "$NORM_B" > "$SORTED_B"

# Output header with clean spacing
echo ""
echo "=== Objects in A but NOT in B (normalized, ordered) ==="
echo ""

# Compare (preserve order from A)
grep -F -x -v -f "$SORTED_B" "$NORM_A"

echo ""

# Cleanup (optional)
# rm -f "$TMP_A" "$TMP_B" "$NORM_A" "$NORM_B" "$SORTED_B"
