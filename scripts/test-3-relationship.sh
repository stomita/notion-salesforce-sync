#!/bin/bash
set -e

# Test 3: Relationship Sync
echo "=== Test 3: Relationship Sync ==="

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

echo ">>> Setting up prerequisite records..."
sf apex run -f "$SCRIPT_DIR/apex/test-3-relationship-setup.apex" $ORG_FLAG

echo ">>> Waiting 5 seconds for setup sync..."
sleep 5

echo ">>> Running relationship test..."
sf apex run -f "$SCRIPT_DIR/apex/test-3-relationship-run.apex" $ORG_FLAG

echo ">>> Waiting 5 seconds for initial sync..."
sleep 5

echo ">>> Checking results with retry (wait: 3s, max retries: 10)..."
"$SCRIPT_DIR/retry-check.sh" "$SCRIPT_DIR/apex/test-3-relationship-check.apex" 3 10 "$ORG_FLAG"

echo "Test 3 complete!"