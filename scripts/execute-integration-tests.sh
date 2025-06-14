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
sf apex run -f scripts/apex/run-integration-tests.apex $ORG_FLAG

echo
echo "=== Integration tests completed ==="
echo
echo "Check the output above for test results."
echo "To view sync logs, run:"
echo "  sf data query --query \"\$(cat scripts/soql/recent-sync-logs.soql)\" $ORG_FLAG"