#!/bin/bash

# Script to run apex and validate the output
# Usage: ./run-apex-with-validation.sh <apex-file> [org-flag]

set -e

APEX_FILE="$1"
ORG_FLAG="${2:-}"

if [ -z "$APEX_FILE" ]; then
    echo "Error: Apex file path required"
    echo "Usage: $0 <apex-file> [org-flag]"
    exit 1
fi

# Create temp file for output
TEMP_OUTPUT="/tmp/apex-output-$$.txt"

# Run the apex script and capture output
echo "Running: $APEX_FILE"
if sf apex run -f "$APEX_FILE" $ORG_FLAG > "$TEMP_OUTPUT" 2>&1; then
    COMMAND_SUCCESS=true
else
    COMMAND_SUCCESS=false
fi

# Display the output
cat "$TEMP_OUTPUT"

# Check for our unique failure marker
if grep -q "INTEGRATION_TEST_FAILURE_MARKER" "$TEMP_OUTPUT"; then
    ERRORS_FOUND=true
else
    ERRORS_FOUND=false
fi

# Check for success indicators
SUCCESS_PATTERNS=(
    "✓"
    "PASSED"
    "SUCCESS"
)

SUCCESS_FOUND=false
for pattern in "${SUCCESS_PATTERNS[@]}"; do
    # Check in debug output lines
    if grep -E "DEBUG\|.*$pattern" "$TEMP_OUTPUT" > /dev/null 2>&1; then
        SUCCESS_FOUND=true
        break
    fi
done

# Clean up temp file
rm -f "$TEMP_OUTPUT"

# Determine final status
if [ "$COMMAND_SUCCESS" = false ]; then
    echo ""
    echo "❌ Apex execution failed!"
    exit 1
elif [ "$ERRORS_FOUND" = true ]; then
    echo ""
    echo "❌ Errors detected in output!"
    exit 1
elif [ "$SUCCESS_FOUND" = false ]; then
    echo ""
    echo "⚠️  Warning: No success indicators found in output"
    # Don't fail here, but warn
fi

exit 0