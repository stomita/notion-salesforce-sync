#!/bin/bash
set -e

# Simple script to execute integration tests
# Assumes all configuration is already done:
# - Metadata has real database IDs
# - Named Credentials are configured with API key

echo "=== Executing Notion Integration Tests ==="
echo
echo "Prerequisites:"
echo "- Metadata must be configured with real Notion database IDs"
echo "- Named Credentials must have valid API key"
echo "- Integration test components must be deployed"
echo

# Get the scratch org alias (default to current default org)
ORG_ALIAS="${1:-}"
if [ -z "$ORG_ALIAS" ]; then
    echo "No org alias provided, using default org"
    ORG_FLAG=""
else
    echo "Using org: $ORG_ALIAS"
    ORG_FLAG="-o $ORG_ALIAS"
fi

echo "Running integration tests..."

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Track test failures
TEST_FAILED=false

# Function to run test check and track failures
run_test_check() {
    local test_file="$1"
    "$SCRIPT_DIR/run-apex-with-validation.sh" "$test_file" "$ORG_FLAG"
    if [ $? -ne 0 ]; then
        TEST_FAILED=true
    fi
}

# Test 1: Create
echo
echo "=== Test 1: Create and Sync ==="
echo ">>> Setting up test data..."
sf apex run -f scripts/apex/test-1-create-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
run_test_check scripts/apex/test-1-create-check.apex

# Test 2: Update
echo
echo "=== Test 2: Update and Sync ==="
echo ">>> Updating records..."
sf apex run -f scripts/apex/test-2-update-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
run_test_check scripts/apex/test-2-update-check.apex

# Test 3: Relationships
echo
echo "=== Test 3: Relationship Sync ==="
echo ">>> Creating related records..."
sf apex run -f scripts/apex/test-3-relationship-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
run_test_check scripts/apex/test-3-relationship-check.apex

# Test 4: Relationship Changes
echo
echo "=== Test 4: Relationship Change Sync ==="
echo ">>> Changing relationships..."
sf apex run -f scripts/apex/test-4-relationship-change-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
run_test_check scripts/apex/test-4-relationship-change-check.apex

# Test 5: Delete
echo
echo "=== Test 5: Delete and Sync ==="
echo ">>> Deleting records..."
sf apex run -f scripts/apex/test-5-delete-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
run_test_check scripts/apex/test-5-delete-check.apex

# Test 6: Batch Processing
echo
echo "=== Test 6: Batch Processing ==="
echo ">>> Creating bulk records..."
sf apex run -f scripts/apex/test-6-batch-setup.apex $ORG_FLAG
echo ">>> Waiting 10 seconds for batch sync..."
sleep 10
echo ">>> Checking results..."
run_test_check scripts/apex/test-6-batch-check.apex

# Overall summary
echo
echo "=================================="
echo "=== Integration Test Summary ==="
echo "=================================="

# Check if all tests passed
if [ "$TEST_FAILED" = false ]; then
    echo "✅ All integration tests PASSED!"
else
    echo "❌ One or more integration tests FAILED!"
    echo "Check the output above for details."
    exit 1
fi

echo
echo "To view sync logs, run:"
echo "  sf data query -f scripts/soql/recent-sync-logs.soql $ORG_FLAG"