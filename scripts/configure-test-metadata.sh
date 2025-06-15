#!/bin/bash

# Script to configure Custom Metadata XML files with actual Notion database IDs
# This replaces placeholder values with real IDs before deployment

set -e  # Exit on error

# Default values
WORKSPACE_ID=""
ACCOUNT_DB=""
CONTACT_DB=""
PARENT_DB=""
CHILD_DB=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace-id)
            WORKSPACE_ID="$2"
            shift 2
            ;;
        --account-db)
            ACCOUNT_DB="$2"
            shift 2
            ;;
        --contact-db)
            CONTACT_DB="$2"
            shift 2
            ;;
        --parent-db)
            PARENT_DB="$2"
            shift 2
            ;;
        --child-db)
            CHILD_DB="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$WORKSPACE_ID" ]; then
    echo "ERROR: --workspace-id is required"
    exit 1
fi

if [ -z "$ACCOUNT_DB" ]; then
    echo "ERROR: --account-db is required"
    exit 1
fi

if [ -z "$CONTACT_DB" ]; then
    echo "ERROR: --contact-db is required"
    exit 1
fi

if [ -z "$PARENT_DB" ]; then
    echo "ERROR: --parent-db is required"
    exit 1
fi

if [ -z "$CHILD_DB" ]; then
    echo "ERROR: --child-db is required"
    exit 1
fi

# Path to Custom Metadata files
METADATA_DIR="force-app/integration/default/customMetadata"

# Check if directory exists
if [ ! -d "$METADATA_DIR" ]; then
    echo "ERROR: Custom Metadata directory not found: $METADATA_DIR"
    exit 1
fi

echo "Configuring Custom Metadata with Notion database IDs..."

# Replace workspace ID in all database metadata files
find "$METADATA_DIR" -name "NotionDatabase.*.md-meta.xml" -type f | while read -r file; do
    echo "Updating workspace ID in: $file"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|REPLACE_WITH_NOTION_WORKSPACE_ID|$WORKSPACE_ID|g" "$file"
    else
        # Linux
        sed -i "s|REPLACE_WITH_NOTION_WORKSPACE_ID|$WORKSPACE_ID|g" "$file"
    fi
done

# Replace specific database IDs in all metadata files
echo "Updating Account database ID..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    find "$METADATA_DIR" -name "*.md-meta.xml" -type f -exec sed -i '' "s|REPLACE_WITH_NOTION_DATABASE_ID_FOR_ACCOUNT|$ACCOUNT_DB|g" {} \;
else
    find "$METADATA_DIR" -name "*.md-meta.xml" -type f -exec sed -i "s|REPLACE_WITH_NOTION_DATABASE_ID_FOR_ACCOUNT|$ACCOUNT_DB|g" {} \;
fi

echo "Updating Contact database ID..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    find "$METADATA_DIR" -name "*.md-meta.xml" -type f -exec sed -i '' "s|REPLACE_WITH_NOTION_DATABASE_ID_FOR_CONTACT|$CONTACT_DB|g" {} \;
else
    find "$METADATA_DIR" -name "*.md-meta.xml" -type f -exec sed -i "s|REPLACE_WITH_NOTION_DATABASE_ID_FOR_CONTACT|$CONTACT_DB|g" {} \;
fi

echo "Updating Test Parent database ID..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    find "$METADATA_DIR" -name "*.md-meta.xml" -type f -exec sed -i '' "s|REPLACE_WITH_NOTION_DATABASE_ID_FOR_TEST_PARENT|$PARENT_DB|g" {} \;
else
    find "$METADATA_DIR" -name "*.md-meta.xml" -type f -exec sed -i "s|REPLACE_WITH_NOTION_DATABASE_ID_FOR_TEST_PARENT|$PARENT_DB|g" {} \;
fi

echo "Updating Test Child database ID..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    find "$METADATA_DIR" -name "*.md-meta.xml" -type f -exec sed -i '' "s|REPLACE_WITH_NOTION_DATABASE_ID_FOR_TEST_CHILD|$CHILD_DB|g" {} \;
else
    find "$METADATA_DIR" -name "*.md-meta.xml" -type f -exec sed -i "s|REPLACE_WITH_NOTION_DATABASE_ID_FOR_TEST_CHILD|$CHILD_DB|g" {} \;
fi

# Verify no placeholders remain
echo "Verifying all placeholders have been replaced..."
if grep -r "REPLACE_WITH_NOTION" "$METADATA_DIR" > /dev/null; then
    echo "ERROR: Some placeholders were not replaced:"
    grep -r "REPLACE_WITH_NOTION" "$METADATA_DIR"
    exit 1
fi

echo "Custom Metadata configuration complete!"