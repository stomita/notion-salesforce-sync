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
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --namespace <namespace>    The namespace (defaults to NOTION_SYNC_PACKAGE_NAMESPACE from .env)"
            echo "  --devhub <alias>          The DevHub alias (defaults to current default DevHub)"
            echo "  --package-id <id>         The package ID (defaults to NOTION_SYNC_PACKAGE_ID from .env)"
            echo "  --wait <minutes>          Wait time for package creation (default: 20)"
            echo "  --skip-validation         Skip validation during package creation"
            echo "  --no-code-coverage        Skip code coverage calculation"
            echo "  --help                    Show this help message"
            echo ""
            echo "Environment variables (can be set in .env file):"
            echo "  NOTION_SYNC_PACKAGE_NAMESPACE    Package namespace"
            echo "  NOTION_SYNC_PACKAGE_ID           Package ID"
            echo ""
            echo "Examples:"
            echo "  # Use all defaults from .env and default DevHub:"
            echo "  $0"
            echo ""
            echo "  # Override specific values:"
            echo "  $0 --namespace notionsync --devhub my-devhub"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run $0 --help for usage information"
            exit 1
            ;;
    esac
done

# Use environment variables if not provided via command line
if [ -z "$PACKAGE_ID" ] && [ -n "$NOTION_SYNC_PACKAGE_ID" ]; then
    PACKAGE_ID="$NOTION_SYNC_PACKAGE_ID"
fi

if [ -z "$NAMESPACE" ] && [ -n "$NOTION_SYNC_PACKAGE_NAMESPACE" ]; then
    NAMESPACE="$NOTION_SYNC_PACKAGE_NAMESPACE"
fi

# If no DevHub specified, check for default
if [ -z "$DEVHUB" ]; then
    # Try to get the default DevHub
    DEFAULT_DEVHUB=$(sf config get target-dev-hub --json 2>/dev/null | jq -r '.result[0].value' 2>/dev/null || echo "")
    if [ -n "$DEFAULT_DEVHUB" ] && [ "$DEFAULT_DEVHUB" != "null" ]; then
        DEVHUB="$DEFAULT_DEVHUB"
        echo "Using default DevHub: $DEVHUB"
    fi
fi

# Validate required parameters
if [ -z "$NAMESPACE" ]; then
    echo "Error: Namespace is required. Set NOTION_SYNC_PACKAGE_NAMESPACE in .env or use --namespace"
    exit 1
fi

if [ -z "$DEVHUB" ]; then
    echo "Error: No DevHub found. Set a default with 'sf config set target-dev-hub <alias>' or use --devhub"
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
    
    # Add package ID to the package directory
    jq ".packageDirectories[0].id = \"$PACKAGE_ID\"" sfdx-project.json > sfdx-project.json.tmp
    mv sfdx-project.json.tmp sfdx-project.json
    
    # Ensure packageAliases exists and add the alias
    jq "if .packageAliases then . else . + {packageAliases: {}} end | .packageAliases[\"$PACKAGE_NAME\"] = \"$PACKAGE_ID\"" sfdx-project.json > sfdx-project.json.tmp
    mv sfdx-project.json.tmp sfdx-project.json
else
    # Fallback to sed
    sed -i '' "s/\"namespace\": \"\"/\"namespace\": \"$NAMESPACE\"/" sfdx-project.json
    
    # Add packageAliases if it doesn't exist
    if ! grep -q "packageAliases" sfdx-project.json; then
        # Add before the closing brace
        sed -i '' "s/}$/,\n  \"packageAliases\": {\n    \"$PACKAGE_NAME\": \"$PACKAGE_ID\"\n  }\n}/" sfdx-project.json
    fi
fi

# Show current configuration
echo ""
echo "Current sfdx-project.json configuration:"
if command -v jq &> /dev/null; then
    echo "  Namespace: $(jq -r .namespace sfdx-project.json)"
    echo "  Package ID: $(jq -r '.packageDirectories[0].id' sfdx-project.json)"
    echo "  Package Name: $(jq -r '.packageDirectories[0].package' sfdx-project.json)"
    echo "  Package Alias: $(jq -r ".packageAliases[\"$PACKAGE_NAME\"]" sfdx-project.json)"
else
    echo "  (Install jq for formatted output)"
fi
echo ""

# Build the package version create command
# Use path to avoid ambiguity
PACKAGE_CMD="sf package version create --path force-app/main --target-dev-hub $DEVHUB --wait $WAIT_TIME"

# Add optional flags
PACKAGE_CMD="$PACKAGE_CMD --installation-key-bypass"

if [ "$SKIP_VALIDATION" = true ]; then
    PACKAGE_CMD="$PACKAGE_CMD --skip-validation"
    # Can't use code coverage with skip validation
else
    if [ "$CODE_COVERAGE" = true ]; then
        PACKAGE_CMD="$PACKAGE_CMD --code-coverage"
    fi
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