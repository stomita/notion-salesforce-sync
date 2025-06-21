#!/bin/bash

# Notion Salesforce Sync - Scratch Org Setup Script
# This script automates the complete setup of a scratch org for development

set -e  # Exit on error

echo "🚀 Setting up Notion Salesforce Sync scratch org..."

# Check if an org alias is provided, otherwise use default
ORG_ALIAS=${1:-notion-sync-scratch}

echo "📦 Creating scratch org with alias: $ORG_ALIAS"

# Step 1: Create scratch org
echo "1️⃣ Creating scratch org..."
sf org create scratch -f config/project-scratch-def.json -a "$ORG_ALIAS" -d -y 30

# Step 2: Deploy all metadata (including integration folder for test objects)
echo "2️⃣ Deploying metadata to scratch org..."
sf project deploy start --source-dir force-app -o "$ORG_ALIAS"

# Step 3: Assign permission sets
echo "3️⃣ Assigning permission sets..."

# Main permission sets
echo "   - Assigning Notion Integration User permission set..."
sf org assign permset --name Notion_Integration_User -o "$ORG_ALIAS"

echo "   - Assigning Notion Sync Admin permission set..."
sf org assign permset --name Notion_Sync_Admin -o "$ORG_ALIAS"

# Integration test permission set (for test objects)
echo "   - Assigning Notion Integration Test User permission set..."
sf org assign permset --name Notion_Integration_Test_User -o "$ORG_ALIAS"

# Step 4: Generate password for the org (useful for UI testing)
echo "4️⃣ Generating password for scratch org user..."
sf org generate password -o "$ORG_ALIAS"

# Step 5: Import sample data (optional)
# echo "5️⃣ Importing sample data..."
# sf data import tree --plan data/sample-data-plan.json -o "$ORG_ALIAS" 2>/dev/null || echo "   ⚠️  No sample data to import"

# Step 6: Open the org
echo "✅ Scratch org setup complete!"
echo ""
echo "📝 Next steps:"
echo "   - To open the org: sf org open -o $ORG_ALIAS"
echo "   - To open Notion Sync Admin: sf org open -o $ORG_ALIAS -p /lightning/n/Notion_Sync_Admin"
echo "   - To view org details: sf org display -o $ORG_ALIAS"
echo "   - To delete the org when done: sf org delete scratch -o $ORG_ALIAS -p"
echo ""
echo "🔑 For UI testing with Playwright:"
echo "   - Get org URL: sf org open --url-only -o $ORG_ALIAS"
echo "   - Get password: sf org display user -o $ORG_ALIAS"

# Optionally open the org
read -p "Would you like to open the org now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sf org open -o "$ORG_ALIAS" -p /lightning/n/Notion_Sync_Admin
fi