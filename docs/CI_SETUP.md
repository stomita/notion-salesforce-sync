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

Each test database must have specific properties configured to match the integration test mappings. 

### Required for ALL Databases
- `salesforce_id` (Text) - **REQUIRED** - Stores the Salesforce record ID for syncing

### Account Test Database Properties
Create these properties in your Account test database:
- `Name` (Title) - Maps to Account Name
- `salesforce_id` (Text) - For Salesforce ID tracking

**Note**: Account Description is mapped to the page body content, not a property.

### Contact Test Database Properties
Create these properties in your Contact test database:
- `Name` (Title) - Maps to Contact Name
- `Email` (Email) - Maps to Contact Email
- `Account` (Relation) - Links to Account database
- `salesforce_id` (Text) - For Salesforce ID tracking

### Test Parent Database Properties
Create these properties in your Test Parent database:
- `Name` (Title) - Maps to Test_Parent_Object__c Name
- `Status` (Select) - Maps to Status__c picklist
  - Add options: Active, Inactive, In Progress
- `Amount` (Number) - Maps to Amount__c currency field
- `Active` (Checkbox) - Maps to Active__c checkbox
- `salesforce_id` (Text) - For Salesforce ID tracking

**Note**: Description__c is mapped to the page body content, not a property.

### Test Child Database Properties
Create these properties in your Test Child database:
- `Name` (Title) - Maps to Test_Child_Object__c Name
- `Quantity` (Number) - Maps to Quantity__c number field
- `Due Date` (Date) - Maps to Due_Date__c date field
- `Test Parent` (Relation) - Links to Test Parent database
- `Account` (Relation) - Links to Account database
- `salesforce_id` (Text) - For Salesforce ID tracking

**Note**: Details__c is mapped to the page body content, not a property.

### Important Notes on Property Setup
1. Property names must match EXACTLY (case-sensitive)
2. Title properties must be named "Name" not "Title"
3. Relations must point to the correct target database
4. Select/Multi-select options can be added as needed
5. Body content mappings mean the field appears in the page content, not as a property

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