#!/bin/bash
set -e

# Test 7: Batch Processing
echo "=== Test 7: Batch Processing ==="

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

echo ">>> Setting up batch test..."
sf apex run -f "$SCRIPT_DIR/apex/test-7-batch-setup.apex" $ORG_FLAG

echo ">>> Running batch test..."
sf apex run -f "$SCRIPT_DIR/apex/test-7-batch-run.apex" $ORG_FLAG

echo ">>> Waiting 60 seconds for initial sync (100 records)..."
sleep 60

echo ">>> Checking results with retry (wait: 15s, max retries: 2)..."
"$SCRIPT_DIR/retry-check.sh" "$SCRIPT_DIR/apex/test-7-batch-check.apex" 15 2 "$ORG_FLAG"

echo "Test 7 complete!"