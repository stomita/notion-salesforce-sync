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

# Test 1: Create
echo
echo "=== Test 1: Create and Sync ==="
echo ">>> Setting up test data..."
sf apex run -f scripts/apex/test-1-create-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
sf apex run -f scripts/apex/test-1-create-check.apex $ORG_FLAG

# Test 2: Update
echo
echo "=== Test 2: Update and Sync ==="
echo ">>> Updating records..."
sf apex run -f scripts/apex/test-2-update-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
sf apex run -f scripts/apex/test-2-update-check.apex $ORG_FLAG

# Test 3: Relationships
echo
echo "=== Test 3: Relationship Sync ==="
echo ">>> Creating related records..."
sf apex run -f scripts/apex/test-3-relationship-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
sf apex run -f scripts/apex/test-3-relationship-check.apex $ORG_FLAG

# Test 4: Delete
echo
echo "=== Test 4: Delete and Sync ==="
echo ">>> Deleting records..."
sf apex run -f scripts/apex/test-4-delete-setup.apex $ORG_FLAG
echo ">>> Waiting 5 seconds for sync..."
sleep 5
echo ">>> Checking results..."
sf apex run -f scripts/apex/test-4-delete-check.apex $ORG_FLAG

# Final Report
echo
echo "=== Final Report ==="
sf apex run -f scripts/apex/test-final-report.apex $ORG_FLAG

echo
echo "=== Integration tests completed ==="
echo
echo "Check the output above for test results."
echo "To view sync logs, run:"
echo "  sf data query --query \"\$(cat scripts/soql/recent-sync-logs.soql)\" $ORG_FLAG"