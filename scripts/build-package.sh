#!/bin/bash

# Script to build a 2GP managed package version
# This handles namespace injection and package version creation

set -e

# Default values
NAMESPACE=""
DEVHUB=""
WAIT_TIME=20
SKIP_VALIDATION=false
CODE_COVERAGE=true
PACKAGE_ID=""
PACKAGE_NAME="Notion Salesforce Sync"

# Load environment variables if .env file exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --devhub)
            DEVHUB="$2"
            shift 2
            ;;
        --package-id)
            PACKAGE_ID="$2"
            shift 2
            ;;
        --wait)
            WAIT_TIME="$2"
            shift 2
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --no-code-coverage)
            CODE_COVERAGE=false
            shift
            ;;
        --help)
            echo "Usage: $0 --namespace <namespace> --devhub <alias> [options]"
            echo "Options:"
            echo "  --namespace <namespace>    The namespace to use for the managed package (required)"
            echo "  --devhub <alias>          The DevHub alias to use (required)"
            echo "  --package-id <id>         The package ID (defaults to NOTION_SYNC_PACKAGE_ID from .env)"
            echo "  --wait <minutes>          Wait time for package creation (default: 20)"
            echo "  --skip-validation         Skip validation during package creation"
            echo "  --no-code-coverage        Skip code coverage calculation"
            echo "  --help                    Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  NOTION_SYNC_PACKAGE_ID    Package ID (can be set in .env file)"
            echo ""
            echo "Example:"
            echo "  $0 --namespace notionsync --devhub notion-sync-devhub"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run $0 --help for usage information"
            exit 1
            ;;
    esac
done

# Use environment variable if package ID not provided via command line
if [ -z "$PACKAGE_ID" ] && [ -n "$NOTION_SYNC_PACKAGE_ID" ]; then
    PACKAGE_ID="$NOTION_SYNC_PACKAGE_ID"
fi

# Validate required parameters
if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace is required for managed package"
    echo "Run $0 --help for usage information"
    exit 1
fi

if [ -z "$DEVHUB" ]; then
    echo "Error: --devhub is required"
    echo "Run $0 --help for usage information"
    exit 1
fi

if [ -z "$PACKAGE_ID" ]; then
    echo "Error: Package ID is required. Set NOTION_SYNC_PACKAGE_ID in .env or use --package-id"
    exit 1
fi

echo "=== Building 2GP Managed Package ==="
echo "Namespace: $NAMESPACE"
echo "DevHub: $DEVHUB"
echo "Package ID: $PACKAGE_ID"
echo "Wait Time: $WAIT_TIME minutes"
echo ""

# Backup original sfdx-project.json
echo "Backing up sfdx-project.json..."
cp sfdx-project.json sfdx-project.json.backup

# Function to restore backup on exit
restore_backup() {
    if [ -f sfdx-project.json.backup ]; then
        echo "Restoring original sfdx-project.json..."
        mv sfdx-project.json.backup sfdx-project.json
    fi
}

# Set up trap to restore backup on exit
trap restore_backup EXIT

# Update project configuration
echo "Updating sfdx-project.json..."
if command -v jq &> /dev/null; then
    # Add namespace
    jq ".namespace = \"$NAMESPACE\"" sfdx-project.json > sfdx-project.json.tmp
    mv sfdx-project.json.tmp sfdx-project.json
    
    # Ensure package ID is in packageAliases
    jq ".packageAliases[\"$PACKAGE_NAME\"] = \"$PACKAGE_ID\"" sfdx-project.json > sfdx-project.json.tmp
    mv sfdx-project.json.tmp sfdx-project.json
else
    # Fallback to sed
    sed -i '' "s/\"namespace\": \"\"/\"namespace\": \"$NAMESPACE\"/" sfdx-project.json
    
    # Check if package alias exists, if not add it
    if ! grep -q "\"$PACKAGE_NAME\": \"$PACKAGE_ID\"" sfdx-project.json; then
        # This is a simple approach - might need refinement for complex cases
        sed -i '' "s/\"packageAliases\": {/\"packageAliases\": {\n    \"$PACKAGE_NAME\": \"$PACKAGE_ID\",/" sfdx-project.json
    fi
fi

# Show current configuration
echo ""
echo "Current sfdx-project.json configuration:"
if command -v jq &> /dev/null; then
    echo "  Namespace: $(jq -r .namespace sfdx-project.json)"
    echo "  Package Alias: $(jq -r ".packageAliases[\"$PACKAGE_NAME\"]" sfdx-project.json)"
else
    echo "  (Install jq for formatted output)"
fi
echo ""

# Build the package version create command
# Use package name since it's mapped to the ID in packageAliases
PACKAGE_CMD="sf package version create --package \"$PACKAGE_NAME\" --target-dev-hub $DEVHUB --wait $WAIT_TIME"

# Add optional flags
if [ "$SKIP_VALIDATION" = true ]; then
    PACKAGE_CMD="$PACKAGE_CMD --skip-validation"
else
    PACKAGE_CMD="$PACKAGE_CMD --installation-key-bypass"
fi

if [ "$CODE_COVERAGE" = true ]; then
    PACKAGE_CMD="$PACKAGE_CMD --code-coverage"
fi

# Show the command that will be executed
echo ""
echo "Executing: $PACKAGE_CMD"
echo ""

# Create the package version
$PACKAGE_CMD

# If successful, show next steps
if [ $? -eq 0 ]; then
    echo ""
    echo "=== Package Version Created Successfully! ==="
    echo ""
    echo "Next steps:"
    echo "1. Test the package in a scratch org:"
    echo "   sf package install --package <version-id> --target-org <scratch-org>"
    echo ""
    echo "2. Promote to released (when ready):"
    echo "   sf package version promote --package <version-id> --target-dev-hub $DEVHUB"
    echo ""
    echo "3. View package versions:"
    echo "   sf package version list --package \"Notion Salesforce Sync\" --target-dev-hub $DEVHUB"
fi