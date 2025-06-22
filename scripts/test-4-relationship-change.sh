#!/bin/bash
set -e

# Test 4: Relationship Change Sync
echo "=== Test 4: Relationship Change Sync ==="

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

echo ">>> Setting up test data (ensure dependencies and create second account)..."
sf apex run -f "$SCRIPT_DIR/apex/test-4-relationship-change-setup.apex" $ORG_FLAG

echo ">>> Waiting 10 seconds for setup to complete..."
sleep 10

echo ">>> Running relationship change test..."
sf apex run -f "$SCRIPT_DIR/apex/test-4-relationship-change-run.apex" $ORG_FLAG

echo ">>> Waiting 10 seconds for relationship sync..."
sleep 10

echo ">>> Checking results..."
"$SCRIPT_DIR/run-apex-with-validation.sh" "$SCRIPT_DIR/apex/test-4-relationship-change-check.apex" "$ORG_FLAG"

echo "Test 4 complete!"