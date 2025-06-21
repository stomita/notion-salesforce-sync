#!/bin/bash

# Script to run Notion integration tests locally
# This mimics the CI behavior for local development

set -e  # Exit on error

echo "=== Notion Integration Test Runner ==="
echo

# Load .env file if it exists
if [ -f ".env" ]; then
    echo "Loading environment variables from .env file..."
    set -a  # Mark all new variables for export
    source .env
    set +a  # Turn off automatic export
    echo "Environment variables loaded from .env"
    echo
fi

# Check required environment variables
echo "Checking environment variables..."

# Function to prompt for a value if not in CI
prompt_if_missing() {
    local var_name=$1
    local var_description=$2
    local is_secret=${3:-false}
    local current_value=${!var_name}
    
    if [ -z "$current_value" ]; then
        if [ "$CI" = "true" ]; then
            echo "ERROR: $var_name environment variable is not set"
            exit 1
        else
            echo "$var_name is not set."
            if [ "$is_secret" = "true" ]; then
                read -s -p "Please enter $var_description: " value
                echo  # New line after password input
            else
                read -p "Please enter $var_description: " value
            fi
            if [ -z "$value" ]; then
                echo "ERROR: No value provided for $var_name"
                exit 1
            fi
            export $var_name="$value"
        fi
    fi
}

# Check all required variables
prompt_if_missing "NOTION_API_KEY" "your Notion API key" "true"
prompt_if_missing "NOTION_WORKSPACE_ID" "your Notion workspace ID"
prompt_if_missing "NOTION_TEST_ACCOUNT_DB" "the Account test database ID"
prompt_if_missing "NOTION_TEST_CONTACT_DB" "the Contact test database ID"
prompt_if_missing "NOTION_TEST_PARENT_DB" "the Test Parent database ID"
prompt_if_missing "NOTION_TEST_CHILD_DB" "the Test Child database ID"

# Display configuration summary
echo
echo "Configuration:"
echo "  API Key: ****${NOTION_API_KEY: -4}"  # Show only last 4 chars
echo "  Workspace ID: $NOTION_WORKSPACE_ID"
echo "  Account DB: $NOTION_TEST_ACCOUNT_DB"
echo "  Contact DB: $NOTION_TEST_CONTACT_DB"
echo "  Parent DB: $NOTION_TEST_PARENT_DB"
echo "  Child DB: $NOTION_TEST_CHILD_DB"
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

# Save current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project root
cd "$PROJECT_ROOT"

echo
echo "Step 1: Configuring test metadata..."
./scripts/configure-test-metadata.sh \
    --workspace-id "$NOTION_WORKSPACE_ID" \
    --account-db "$NOTION_TEST_ACCOUNT_DB" \
    --contact-db "$NOTION_TEST_CONTACT_DB" \
    --parent-db "$NOTION_TEST_PARENT_DB" \
    --child-db "$NOTION_TEST_CHILD_DB"

echo
echo "Step 2: Deploying integration test components..."
sf project deploy start --source-dir force-app/integration $ORG_FLAG

echo
echo "Step 3: Setting up Notion API credentials..."
# Create a temporary script with the API key embedded
TEMP_SCRIPT="/tmp/setup-integration-credentials-$$.apex"
sed "s/NOTION_API_KEY_PLACEHOLDER/$NOTION_API_KEY/g" scripts/apex/setup-integration-credentials-template.apex > "$TEMP_SCRIPT"
sf apex run -f "$TEMP_SCRIPT" $ORG_FLAG
rm -f "$TEMP_SCRIPT"

echo
echo "Step 4: Running integration tests..."
./scripts/execute-integration-tests.sh

echo
echo "=== Integration tests completed ==="

# Clean up - restore placeholder values in metadata files
echo
echo "Cleaning up: Restoring placeholder values in metadata files..."
cd "$PROJECT_ROOT"
git checkout -- force-app/integration/default/customMetadata/*.xml 2>/dev/null || true

echo "Done!"