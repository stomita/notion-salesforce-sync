# Integration Testing Guide

This guide explains how to run integration tests locally that verify the Notion sync functionality with real API calls.

## Prerequisites

1. A Notion account with API access
2. A Notion integration token
3. Test databases created in Notion (see CI_SETUP.md for database setup)
4. A Salesforce scratch org with the package deployed

## Environment Setup

### 1. Set Environment Variables

Export the following environment variables in your terminal:

```bash
export NOTION_API_KEY='your-notion-api-key'
export NOTION_WORKSPACE_ID='your-workspace-id'
export NOTION_TEST_ACCOUNT_DB='account-database-id'
export NOTION_TEST_CONTACT_DB='contact-database-id'
export NOTION_TEST_PARENT_DB='parent-database-id'
export NOTION_TEST_CHILD_DB='child-database-id'
```

### 2. Create Test Databases

Follow the database setup instructions in CI_SETUP.md to create the required test databases in Notion.

## Running Integration Tests

### Quick Start

Run all integration tests with:

```bash
./scripts/run-integration-tests.sh
```

Or specify a scratch org:

```bash
./scripts/run-integration-tests.sh my-scratch-org
```

### Manual Steps

If you prefer to run steps manually:

1. **Configure test metadata:**
   ```bash
   ./scripts/configure-test-metadata.sh \
     --workspace-id "$NOTION_WORKSPACE_ID" \
     --account-db "$NOTION_TEST_ACCOUNT_DB" \
     --contact-db "$NOTION_TEST_CONTACT_DB" \
     --parent-db "$NOTION_TEST_PARENT_DB" \
     --child-db "$NOTION_TEST_CHILD_DB"
   ```

2. **Deploy integration test components:**
   ```bash
   sf project deploy start --source-dir force-app/integration
   ```

3. **Set up API credentials:**
   ```bash
   NOTION_API_KEY="$NOTION_API_KEY" \
   sf apex run -f scripts/apex/setup-integration-credentials.apex
   ```

4. **Run tests:**
   ```bash
   sf apex run -f scripts/apex/run-integration-tests.apex
   ```

## Test Coverage

The integration tests verify:

1. **Create Sync** - Creating Salesforce records syncs to Notion
2. **Update Sync** - Updating Salesforce records updates Notion pages
3. **Relationship Sync** - Related records maintain relationships in Notion
4. **Delete Sync** - Deleting Salesforce records removes Notion pages

## Monitoring Test Results

### During Test Execution

The test output shows:
- Progress for each test
- Pass/fail status
- Any error messages

### After Test Execution

Check the Notion workspace to verify:
- Test records were created
- Relationships are properly linked
- Deleted records were removed

Query sync logs in Salesforce:
```apex
SELECT Record_Id__c, Object_Type__c, Operation_Type__c, 
       Status__c, Notion_Page_Id__c, Error_Message__c
FROM Notion_Sync_Log__c
WHERE CreatedDate >= :DateTime.now().addHours(-1)
ORDER BY CreatedDate DESC
```

## Troubleshooting

### Environment Variable Not Set

If you see "ERROR: NOTION_API_KEY environment variable is not set":
- Ensure you exported the variable in your current shell
- Check for typos in the variable name

### API Authentication Fails

If tests fail with 401 Unauthorized:
- Verify your API key is correct
- Check that the integration has access to all test databases
- Ensure the credential update script ran successfully

### Sync Not Happening

If records aren't syncing:
- Verify flows are active in the org
- Check that Custom Metadata was deployed correctly
- Look for errors in Notion_Sync_Log__c records

### Test Data Conflicts

If tests fail due to existing data:
- The test executor cleans up test data at the start
- Manually delete any lingering test records if needed

## Best Practices

1. **Use dedicated test databases** - Don't run tests against production data
2. **Clean up after tests** - The script restores metadata files automatically
3. **Monitor API limits** - Be aware of Notion API rate limits
4. **Test in isolation** - Use a dedicated scratch org for integration tests

## Advanced Usage

### Running Individual Tests

To run specific tests, modify the `run-integration-tests.apex` script:

```apex
NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();
// Run only specific test
executor.testCreateSync();
```

### Debugging Failed Tests

Enable debug logs before running tests:
```bash
sf apex tail log --target-org your-org
```

Then run tests and examine the detailed logs for issues.