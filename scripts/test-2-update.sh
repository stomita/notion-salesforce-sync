#!/bin/bash
set -e

# Test 2: Update and Sync
echo "=== Test 2: Update and Sync ==="

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

echo ">>> Setting up test data (ensure records exist)..."
sf apex run -f "$SCRIPT_DIR/apex/test-2-update-setup.apex" $ORG_FLAG

echo ">>> Waiting 5 seconds for setup sync..."
sleep 5

echo ">>> Running update test..."
sf apex run -f "$SCRIPT_DIR/apex/test-2-update-run.apex" $ORG_FLAG

echo ">>> Waiting 5 seconds for sync..."
sleep 5

echo ">>> Checking results..."
"$SCRIPT_DIR/run-apex-with-validation.sh" "$SCRIPT_DIR/apex/test-2-update-check.apex" "$ORG_FLAG"

echo "Test 2 complete!"