#!/bin/bash
set -e

# Test 1: Create and Sync
echo "=== Test 1: Create and Sync ==="

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

echo ">>> Running create test..."
sf apex run -f "$SCRIPT_DIR/apex/test-1-create-run.apex" $ORG_FLAG

echo ">>> Waiting 5 seconds for initial sync..."
sleep 5

echo ">>> Checking results with retry (wait: 3s, max retries: 10)..."
"$SCRIPT_DIR/retry-check.sh" "$SCRIPT_DIR/apex/test-1-create-check.apex" 3 10 "$ORG_FLAG"

echo "Test 1 complete!"