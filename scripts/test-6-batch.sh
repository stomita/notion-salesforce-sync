#!/bin/bash
set -e

# Test 6: Batch Processing
echo "=== Test 6: Batch Processing ==="

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
sf apex run -f "$SCRIPT_DIR/apex/test-6-batch-setup.apex" $ORG_FLAG

echo ">>> Running batch test..."
sf apex run -f "$SCRIPT_DIR/apex/test-6-batch-run.apex" $ORG_FLAG

echo ">>> Waiting 60 seconds for sync to complete (100 records)..."
sleep 60

echo ">>> Checking results..."
"$SCRIPT_DIR/run-apex-with-validation.sh" "$SCRIPT_DIR/apex/test-6-batch-check.apex" "$ORG_FLAG"

echo "Test 6 complete!"