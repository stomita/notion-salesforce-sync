#!/bin/bash
set -e

# Main script to execute all integration tests
# Calls individual test scripts for better modularity

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
else
    echo "Using org: $ORG_ALIAS"
fi

echo "Running integration tests..."

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Track test failures
TEST_FAILED=false

# Function to run individual test and track failures
run_test() {
    local test_script="$1"
    "$SCRIPT_DIR/$test_script" "$ORG_ALIAS"
    if [ $? -ne 0 ]; then
        TEST_FAILED=true
        echo "❌ $test_script FAILED!"
    else
        echo "✅ $test_script PASSED!"
    fi
}

# Run setup first (clean up test data)
echo
echo "=== Running Test Setup ==="
run_test "test-0-setup.sh"

# Run all tests in sequence
echo
run_test "test-1-create.sh"

echo
run_test "test-2-update.sh"

echo
run_test "test-3-relationship.sh"

echo
run_test "test-4-relationship-change.sh"

echo
run_test "test-5-delete.sh"

echo
run_test "test-6-batch.sh"

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