#!/bin/bash
set -e

# Test 5: Delete and Sync
echo "=== Test 5: Delete and Sync ==="

# Get the scratch org alias (default to current default org)
ORG_ALIAS="${1:-}"
if [ -z "$ORG_ALIAS" ]; then
    echo "No org alias provided, using default org"
    ORG_FLAG=""
else
    echo "Using org: $ORG_ALIAS"
    ORG_FLAG="-o $ORG_ALIAS"
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ">>> Setting up records for deletion test..."
sf apex run -f "$SCRIPT_DIR/apex/test-5-delete-setup.apex" $ORG_FLAG

echo ">>> Waiting 5 seconds for setup sync..."
sleep 5

echo ">>> Running deletion test..."
sf apex run -f "$SCRIPT_DIR/apex/test-5-delete-run.apex" $ORG_FLAG

echo ">>> Waiting 10 seconds for initial sync..."
sleep 10

echo ">>> Checking results with retry (wait: 5s, max retries: 6)..."
"$SCRIPT_DIR/retry-check.sh" "$SCRIPT_DIR/apex/test-5-delete-check.apex" 5 6 "$ORG_FLAG"

echo "Test 5 complete!"