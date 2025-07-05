#!/bin/bash

# Test 8: Deduplication - Ensure duplicate Notion pages are removed

set -e  # Exit on error

echo "=== Test 8: Deduplication ==="

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

# Phase 1: Setup deduplication test
echo ">>> Setting up deduplication test..."
sf apex run -f "$SCRIPT_DIR/apex/test-8-deduplication-setup.apex" $ORG_FLAG

echo ">>> Waiting 15 seconds for initial sync of test records..."
sleep 15

# Phase 2: Run deduplication test (create duplicates)
echo ">>> Creating duplicate Notion pages intentionally..."
sf apex run -f "$SCRIPT_DIR/apex/test-8-deduplication-run.apex" $ORG_FLAG

echo ">>> Waiting 30 seconds for initial sync..."
sleep 30

# Phase 3: Check deduplication results
echo ">>> Checking results with retry (wait: 10s, max retries: 3)..."
"$SCRIPT_DIR/retry-check.sh" "$SCRIPT_DIR/apex/test-8-deduplication-check.apex" 10 3 "$ORG_FLAG"

echo "Test 8 complete!"