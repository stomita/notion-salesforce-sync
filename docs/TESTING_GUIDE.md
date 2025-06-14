# Notion Salesforce Sync - Testing Guide

## Prerequisites

Before testing the Named Credential authentication:

1. **Notion API Token**
   - Go to [https://www.notion.so/my-integrations](https://www.notion.so/my-integrations)
   - Create a new integration
   - Copy the Internal Integration Token (starts with `secret_`)

2. **Notion Database Setup**
   - Create or identify a test database in Notion
   - Share the database with your integration
   - Copy the database ID from the URL (32-character string after the workspace name)

## Step 1: Configure Authentication in Salesforce

1. Go to **Setup** → **Named Credentials** → **External Credentials**
2. Click on **Notion_Credential**
3. Find the **NotionIntegration** principal
4. Click **Edit** or **Add Authentication Settings**
5. Set the **SecretKey** parameter to your Notion API token
6. Save the changes

## Step 2: Run Unit Tests

Execute the following command to run the unit tests:

```bash
sf apex test run --tests NotionApiClientTest --code-coverage --result-format human --target-org notion-sync-scratch --wait 10
```

Expected result: All 27 tests should pass with 92% code coverage.

## Step 3: Test API Connection

1. Open **Developer Console** or VS Code with Salesforce extensions
2. Execute the test script as Anonymous Apex:

```bash
sf apex run --file scripts/test-notion-api.apex --target-org notion-sync-scratch
```

3. Check the debug logs for results:
```bash
sf apex log tail --target-org notion-sync-scratch
```

## Step 4: End-to-End Sync Test

1. Create a test Account record:
```apex
Account testAccount = new Account(
    Name = 'Test Account for Notion Sync - ' + DateTime.now().format(),
    Description = 'This account should sync to Notion automatically'
);
insert testAccount;
```

2. Monitor the sync:
```bash
sf data query --query "SELECT Id, Record_Id__c, Status__c, Error_Message__c FROM Notion_Sync_Log__c WHERE Record_Id__c = '<account-id>' ORDER BY CreatedDate DESC" --target-org notion-sync-scratch
```

## Step 5: Verify in Notion

1. Open your Notion database
2. Look for the newly created page
3. Verify that the Salesforce ID is stored in the designated property

## Troubleshooting

### Common Issues

1. **401 Unauthorized Error**
   - Verify the API token is correctly set in the External Credential
   - Ensure the token hasn't expired
   - Check that the token has the correct format (starts with `secret_`)

2. **403 Forbidden Error**
   - Make sure the integration is added to the Notion database
   - Verify the integration has the necessary permissions

3. **404 Not Found Error**
   - Double-check the database ID
   - Ensure the database hasn't been deleted or moved

4. **Connection Errors**
   - Verify the Named Credential endpoint is `https://api.notion.com`
   - Check if there are any firewall or proxy issues

### Debug Commands

```bash
# View recent logs
sf apex log list --target-org notion-sync-scratch

# Get detailed log
sf apex log get --log-id <log-id> --target-org notion-sync-scratch

# Monitor sync logs in real-time
sf data query --query "$(cat scripts/check-sync-logs.soql)" --target-org notion-sync-scratch
```

## Security Best Practices

1. **Never commit API tokens** to version control
2. Use **Named Credentials** for all external API calls
3. Rotate API tokens regularly
4. Limit integration access to only necessary databases in Notion
5. Monitor sync logs for unauthorized access attempts