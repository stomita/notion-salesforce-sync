#!/bin/bash
set -e

# Test Setup: Clean up test data
echo "=== Test Setup: Cleaning up test data ==="

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

echo ">>> Setting up test environment..."
sf apex run -f "$SCRIPT_DIR/apex/test-0-setup.apex" $ORG_FLAG

echo "Test setup complete!"