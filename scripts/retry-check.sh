#!/bin/bash
set -e

# Script to retry check operations with configurable wait time and retry count
# Usage: ./retry-check.sh <apex-check-file> <wait-seconds> <max-retries> [org-flag]
#
# Example: ./retry-check.sh apex/test-1-create-check.apex 5 10 "-o my-org"
#
# This will retry the check up to 10 times with 5 seconds wait between attempts

# Parse arguments
APEX_CHECK_FILE="$1"
WAIT_SECONDS="${2:-5}"
MAX_RETRIES="${3:-10}"
ORG_FLAG="${4:-}"

# Validate required arguments
if [ -z "$APEX_CHECK_FILE" ]; then
    echo "Error: Apex check file path required"
    echo "Usage: $0 <apex-check-file> <wait-seconds> <max-retries> [org-flag]"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Perform initial check attempt
echo ">>> Performing initial check..."
RETRY_COUNT=0
CHECK_PASSED=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if [ $RETRY_COUNT -gt 0 ]; then
        echo ">>> Retry $RETRY_COUNT/$MAX_RETRIES after ${WAIT_SECONDS}s wait..."
    fi
    
    # Run the check using the validation script
    if "$SCRIPT_DIR/run-apex-with-validation.sh" "$APEX_CHECK_FILE" "$ORG_FLAG"; then
        CHECK_PASSED=true
        echo "✓ Check passed!"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "⏳ Check not yet successful, waiting ${WAIT_SECONDS} seconds before retry..."
            sleep $WAIT_SECONDS
        fi
    fi
done

# Final result
if [ "$CHECK_PASSED" = true ]; then
    exit 0
else
    echo "❌ Check failed after $MAX_RETRIES attempts"
    exit 1
fi