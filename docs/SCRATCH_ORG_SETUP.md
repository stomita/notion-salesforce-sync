# Scratch Org Setup Guide

This guide explains how to properly set up a scratch org for Notion Salesforce Sync development.

## Quick Start - Automated Setup

The easiest way to set up a scratch org is using the provided setup script:

```bash
# Default setup (creates org with alias 'notion-sync-scratch')
./scripts/setup-scratch-org.sh

# Custom alias
./scripts/setup-scratch-org.sh my-org-alias
```

## What the Setup Script Does

The setup script (`scripts/setup-scratch-org.sh`) performs the following steps:

1. **Creates a Scratch Org**
   - 30-day expiration
   - Sets as default org
   - Uses configuration from `config/project-scratch-def.json`

2. **Deploys All Metadata**
   - Deploys both `force-app/main` and `force-app/integration` folders
   - Includes test objects (Test_Parent_Object__c, Test_Child_Object__c)

3. **Assigns Permission Sets**
   - `Notion_Integration_User` - Required for API access
   - `Notion_Sync_Admin` - Required for admin UI access
   - `Notion_Integration_Test_User` - Required for test object access

4. **Generates Password**
   - Creates a password for the scratch org user
   - Useful for UI testing with tools like Playwright

## Manual Setup

If you need to set up the org manually or customize the process:

```bash
# 1. Create scratch org
sf org create scratch -f config/project-scratch-def.json -a notion-sync-scratch -d -y 30

# 2. Deploy metadata
sf project deploy start --source-dir force-app -o notion-sync-scratch

# 3. Assign permission sets
sf org assign permset --name Notion_Integration_User -o notion-sync-scratch
sf org assign permset --name Notion_Sync_Admin -o notion-sync-scratch
sf org assign permset --name Notion_Integration_Test_User -o notion-sync-scratch

# 4. Generate password
sf org generate password -o notion-sync-scratch

# 5. Open the org
sf org open -o notion-sync-scratch -p /lightning/n/Notion_Sync_Admin
```

## Important Notes

### Permission Sets

There are three permission sets that need to be assigned:

1. **Notion_Integration_User** (in `force-app/main`)
   - Grants API access permissions
   - Required for the sync functionality to work

2. **Notion_Sync_Admin** (in `force-app/main`)
   - Grants access to the Notion Sync Admin UI
   - Required to configure sync settings

3. **Notion_Integration_Test_User** (in `force-app/integration`)
   - Grants access to test objects and their fields
   - Required to see field metadata for Test_Parent_Object__c and Test_Child_Object__c
   - Without this, custom fields will show as "Unknown" type in the UI

### Test Objects

The integration folder contains test objects used for integration testing:
- `Test_Parent_Object__c` - Parent object with custom fields
- `Test_Child_Object__c` - Child object with lookup relationships

These objects are only deployed when you deploy the entire `force-app` directory.

## Troubleshooting

### Fields Show as "Unknown" Type

If custom fields for test objects show as "Unknown" type in the Notion Sync Admin UI:
1. Ensure you've assigned the `Notion_Integration_Test_User` permission set
2. Refresh the browser page after assignment

### Permission Errors

If you see "You do not have permission to access Notion Sync Admin features":
1. Ensure you've assigned the `Notion_Sync_Admin` permission set
2. Log out and log back in if necessary

### Deployment Failures

If deployment fails:
1. Check that your Dev Hub is enabled
2. Ensure you're authenticated: `sf org list`
3. Check the deployment status: `sf project deploy report`

## Useful Commands

```bash
# View org details (including password)
sf org display -o notion-sync-scratch

# Get org URL for UI testing
sf org open --url-only -o notion-sync-scratch

# Open specific page
sf org open -o notion-sync-scratch -p /lightning/n/Notion_Sync_Admin

# Delete scratch org when done
sf org delete scratch -o notion-sync-scratch -p
```