#!/bin/bash
set -e

# Test 1: Create and Sync with Direct Processing Debug
echo "=== Test 1: Create and Sync (Direct Processing Debug) ==="

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

echo ">>> Waiting 10 seconds for sync..."
sleep 10

echo ">>> Debug: Checking sync logs..."
sf apex run -f "$SCRIPT_DIR/apex/debug-sync-logs.apex" $ORG_FLAG

echo ">>> Debug: Testing direct async processing..."
sf apex run -f "$SCRIPT_DIR/apex/debug-async-chain.apex" $ORG_FLAG

echo ">>> Checking results..."
"$SCRIPT_DIR/run-apex-with-validation.sh" "$SCRIPT_DIR/apex/test-1-create-check.apex" "$ORG_FLAG"

echo "Test 1 complete!"