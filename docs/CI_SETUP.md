# CI Setup Guide

This guide explains how to configure GitHub Actions for running integration tests with the Notion API.

## Prerequisites

1. A Notion integration token (API key)
2. Notion workspace with test databases created
3. Repository admin access to configure secrets

## Required GitHub Secrets

Configure the following secrets in your GitHub repository settings (Settings → Secrets and variables → Actions):

### 1. `NOTION_API_KEY`
Your Notion integration token. To get this:
1. Go to https://www.notion.so/my-integrations
2. Create a new integration or use an existing one
3. Copy the "Internal Integration Token"

### 2. `NOTION_WORKSPACE_ID`
The ID of your Notion workspace. To find this:
1. Open any page in your Notion workspace
2. Look at the URL: `https://www.notion.so/{workspace-name}-{workspace-id}`
3. Copy the workspace ID (32-character string)

### 3. Database IDs
Create four test databases in Notion and get their IDs:

- `NOTION_DATABASE_ID_ACCOUNT` - For Account records
- `NOTION_DATABASE_ID_CONTACT` - For Contact records  
- `NOTION_DATABASE_ID_TEST_PARENT` - For Test_Parent_Object__c records
- `NOTION_DATABASE_ID_TEST_CHILD` - For Test_Child_Object__c records

To get a database ID:
1. Open the database in Notion
2. Click "Share" and copy the link
3. Extract the ID from the URL: `https://www.notion.so/{workspace}/{database-id}?v={view-id}`

## Setting Up Test Databases in Notion

For detailed instructions on creating and configuring the test databases with all required properties, see the [Test Database Setup section in the Integration Testing Guide](INTEGRATION_TESTING.md#test-database-setup).

**Quick Summary**: You need to create four databases (Account, Contact, Test Parent, Test Child) with specific properties that match the integration test field mappings. All databases must have a `salesforce_id` property for tracking.

## Configuring GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret" for each required secret
4. Enter the name exactly as shown above and paste the value

## Verifying Setup

After configuring all secrets:
1. Push a change to trigger CI
2. Check the Actions tab to monitor the workflow
3. The "Validate Integration Test Configuration" step will verify all secrets are set

## Troubleshooting

### CI Fails at "Validate Integration Test Configuration"
- Ensure all 6 required secrets are configured
- Check for typos in secret names
- Verify the values are not empty

### Integration Tests Fail
- Verify your Notion API key has access to all test databases
- Check that database properties match the expected names
- Ensure the workspace ID is correct

### Permission Errors
- Grant your Notion integration access to all test databases
- In each database, click Share → Invite → Select your integration