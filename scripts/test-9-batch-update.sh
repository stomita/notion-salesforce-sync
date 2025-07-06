#!/bin/bash
set -e

# Test 9: Batch Update Processing
echo "=== Test 9: Batch Update Processing ==="

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

echo ">>> Setting up batch update test..."
sf apex run -f "$SCRIPT_DIR/apex/test-9-batch-update-setup.apex" $ORG_FLAG

echo ">>> Waiting 15 seconds for initial sync to complete..."
sleep 15

echo ">>> Running batch update test..."
sf apex run -f "$SCRIPT_DIR/apex/test-9-batch-update-run.apex" $ORG_FLAG

echo ">>> Waiting 60 seconds for batch update sync (may require multiple queueable jobs)..."
sleep 60

echo ">>> Checking results with retry (wait: 30s, max retries: 6)..."
"$SCRIPT_DIR/retry-check.sh" "$SCRIPT_DIR/apex/test-9-batch-update-check.apex" 30 6 "$ORG_FLAG"

echo "Test 9 complete!"