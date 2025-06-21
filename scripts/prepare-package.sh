#!/bin/bash

# Script to prepare the project for 2GP package creation
# This script dynamically adds namespace information when building the package

set -e

# Default values
NAMESPACE=""
DEVHUB=""
PACKAGE_ALIAS="Notion Salesforce Sync"

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
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --namespace <namespace>  The namespace to use for the package"
            echo "  --devhub <alias>        The DevHub alias to use"
            echo "  --help                  Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== Preparing Package Build ==="

# Check if namespace is provided
if [ -z "$NAMESPACE" ]; then
    echo "No namespace provided. Building without namespace (unlocked package)."
else
    echo "Building with namespace: $NAMESPACE"
fi

# Check if devhub is provided
if [ -z "$DEVHUB" ]; then
    echo "Error: --devhub is required"
    exit 1
fi

# Create a temporary copy of sfdx-project.json
cp sfdx-project.json sfdx-project.json.backup

# If namespace is provided, update the project file
if [ ! -z "$NAMESPACE" ]; then
    echo "Adding namespace to sfdx-project.json..."
    # Use jq if available, otherwise use sed
    if command -v jq &> /dev/null; then
        jq ".namespace = \"$NAMESPACE\"" sfdx-project.json > sfdx-project.json.tmp
        mv sfdx-project.json.tmp sfdx-project.json
    else
        # Fallback to sed for systems without jq
        sed -i.bak "s/\"namespace\": \"\"/\"namespace\": \"$NAMESPACE\"/" sfdx-project.json
        rm -f sfdx-project.json.bak
    fi
fi

echo "Current sfdx-project.json:"
cat sfdx-project.json | grep -E "(namespace|package|version)" | head -10

echo ""
echo "Ready to create package version. Run:"
echo "  sf package version create --package \"$PACKAGE_ALIAS\" --wait 20 --installation-key-bypass --target-dev-hub $DEVHUB"
echo ""
echo "To restore original sfdx-project.json, run:"
echo "  mv sfdx-project.json.backup sfdx-project.json"