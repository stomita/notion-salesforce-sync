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
            echo "  --wait <minutes>          Wait time for package creation (default: 20)"
            echo "  --skip-validation         Skip validation during package creation"
            echo "  --no-code-coverage        Skip code coverage calculation"
            echo "  --help                    Show this help message"
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

echo "=== Building 2GP Managed Package ==="
echo "Namespace: $NAMESPACE"
echo "DevHub: $DEVHUB"
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

# Add namespace to project configuration
echo "Adding namespace to sfdx-project.json..."
if command -v jq &> /dev/null; then
    jq ".namespace = \"$NAMESPACE\"" sfdx-project.json > sfdx-project.json.tmp
    mv sfdx-project.json.tmp sfdx-project.json
else
    # Fallback to sed
    sed -i '' "s/\"namespace\": \"\"/\"namespace\": \"$NAMESPACE\"/" sfdx-project.json
fi

# Build the package version create command
PACKAGE_CMD="sf package version create --package \"Notion Salesforce Sync\" --target-dev-hub $DEVHUB --wait $WAIT_TIME"

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