#!/bin/bash
set -e

# Test 6: Body Content Update Handling
echo "=== Test 6: Body Content Update Handling ==="

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

echo ">>> Setting up body content test..."
sf apex run -f "$SCRIPT_DIR/apex/test-6-body-content-setup.apex" $ORG_FLAG

echo ">>> Waiting 10 seconds for initial sync of 8 test records..."
sleep 10

echo ">>> Running body content update tests..."
echo "This test will verify:"
echo "- Content updates are properly synced"
echo "- Null/empty values clear page content"
echo "- Various content scenarios work correctly"
sf apex run -f "$SCRIPT_DIR/apex/test-6-body-content-run.apex" $ORG_FLAG

echo ">>> Waiting 20 seconds for all updates to sync..."
sleep 20

echo ">>> Checking results..."
"$SCRIPT_DIR/run-apex-with-validation.sh" "$SCRIPT_DIR/apex/test-6-body-content-check.apex" "$ORG_FLAG"

echo "Test 6 complete!"