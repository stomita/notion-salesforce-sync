# Integration Testing Guide

This guide explains how to run integration tests that verify the Notion sync functionality with real API calls.

## Prerequisites

1. A Notion account with API access
2. A Notion integration token
3. Test databases created in Notion (see CI_SETUP.md for database setup)
4. A Salesforce scratch org with the package deployed

## Quick Start

The integration test framework now supports both automated CI execution and interactive local development.

### Running Integration Tests Locally

Simply run:

```bash
./scripts/run-integration-tests.sh
```

The script will:
- Prompt you for any missing environment variables (API key, database IDs, etc.)
- Automatically configure test metadata
- Deploy integration test components
- Set up Named Credentials programmatically
- Execute all integration tests
- Clean up temporary files

You can also specify a scratch org:

```bash
./scripts/run-integration-tests.sh my-scratch-org
```

### Environment Variables (Optional)

For non-interactive execution, set these environment variables:

```bash
export NOTION_API_KEY='your-notion-api-key'
export NOTION_WORKSPACE_ID='your-workspace-id'
export NOTION_DATABASE_ID_ACCOUNT='account-database-id'
export NOTION_DATABASE_ID_CONTACT='contact-database-id'
export NOTION_DATABASE_ID_TEST_PARENT='parent-database-id'
export NOTION_DATABASE_ID_TEST_CHILD='child-database-id'
```

## How It Works

### 1. Automated Credential Setup

The `NotionTestCredentialSetup` class programmatically configures the Named Credential:
- Handles both credential creation and updates
- Sets the API key securely
- Ensures proper permissions are assigned

### 2. Metadata Configuration

The `configure-test-metadata.sh` script:
- Replaces placeholder values in Custom Metadata files
- Validates all placeholders are replaced
- Works across different operating systems

### 3. Test Execution

The `NotionIntegrationTestExecutor` class:
- Runs comprehensive sync tests
- Validates create, update, delete operations
- Tests relationship synchronization
- Provides detailed progress and error reporting

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

## CI/CD Integration

### GitHub Actions Setup

The integration tests run automatically in CI when:
1. All required secrets are configured in GitHub
2. A pull request is created or updated
3. Code is pushed to the main branch

Required GitHub secrets:
- `NOTION_API_KEY`
- `NOTION_WORKSPACE_ID`
- `NOTION_DATABASE_ID_ACCOUNT`
- `NOTION_DATABASE_ID_CONTACT`
- `NOTION_DATABASE_ID_TEST_PARENT`
- `NOTION_DATABASE_ID_TEST_CHILD`

The CI workflow will:
1. Validate all secrets are present (fail fast if not)
2. Create a scratch org
3. Deploy all metadata including integration tests
4. Configure Named Credentials automatically
5. Run integration tests
6. Report results

## Troubleshooting

### Interactive Prompts Not Working

If the script hangs or doesn't show prompts:
- Ensure you're running in an interactive terminal
- Try setting environment variables instead of using prompts

### Environment Variable Not Set (CI)

In CI, missing environment variables cause immediate failure:
- Check that all required secrets are configured in GitHub
- Verify secret names match exactly (case-sensitive)

### API Authentication Fails

If tests fail with 401 Unauthorized:
- Verify your API key is correct and active
- Check that the Notion integration has access to all test databases
- Ensure the Named Credential was properly configured

### Credential Setup Fails

If you see "Failed to configure credential":
- Check that the External Credential and Named Credential exist
- Verify the permission set is deployed
- Ensure you have proper permissions in the org

### Sync Not Happening

If records aren't syncing:
- Verify flows are active in the org
- Check that Custom Metadata was deployed correctly
- Look for errors in Notion_Sync_Log__c records
- Ensure Platform Events are enabled

### Test Data Conflicts

If tests fail due to existing data:
- The test executor cleans up test data at the start
- Manually delete any lingering test records if needed
- Check for unique constraint violations in Notion

## Best Practices

1. **Use dedicated test databases** - Don't run tests against production data
2. **Clean up after tests** - The script restores metadata files automatically
3. **Monitor API limits** - Be aware of Notion API rate limits
4. **Test in isolation** - Use a dedicated scratch org for integration tests

## Manual Test Execution

If you need more control over the test process:

### 1. Configure Test Metadata

```bash
./scripts/configure-test-metadata.sh \
  --workspace-id "your-workspace-id" \
  --account-db "account-db-id" \
  --contact-db "contact-db-id" \
  --parent-db "parent-db-id" \
  --child-db "child-db-id"
```

### 2. Deploy Integration Tests

```bash
sf project deploy start --source-dir force-app/integration
```

### 3. Set Up Credentials

Create a temporary script from the template:
```bash
sed "s/NOTION_API_KEY_PLACEHOLDER/your-api-key/" \
  scripts/apex/setup-integration-credentials-template.apex > /tmp/setup-creds.apex

sf apex run --file /tmp/setup-creds.apex
```

### 4. Run Tests

```bash
sf apex run --file scripts/apex/run-integration-tests.apex
```

## Advanced Usage

### Running Individual Tests

To run specific tests, create a custom apex script:

```apex
NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();
// Run only specific test
executor.testCreateSync();
// Or
executor.testUpdateSync();
// Or
executor.testRelationshipSync();
// Or
executor.testDeleteSync();
```

### Debugging Failed Tests

1. **Enable debug logs:**
   ```bash
   sf apex tail log --target-org your-org
   ```

2. **Check sync logs:**
   ```apex
   // In Developer Console or Anonymous Apex
   List<Notion_Sync_Log__c> logs = [
       SELECT Record_Id__c, Object_Type__c, Operation_Type__c, 
              Status__c, Error_Message__c, CreatedDate
       FROM Notion_Sync_Log__c
       WHERE CreatedDate = TODAY
       ORDER BY CreatedDate DESC
       LIMIT 50
   ];
   System.debug(JSON.serializePretty(logs));
   ```

3. **Verify Platform Events:**
   ```apex
   // Check if events are being published
   EventBus.getPublisher().publishImmediate(
       new Notion_Sync_Event__e(
           Record_Id__c = 'test123',
           Object_Type__c = 'Account',
           Operation_Type__c = 'CREATE'
       )
   );
   ```

### Customizing Test Data

The test executor uses specific prefixes for test data:
- Accounts: "Integration Test Account"
- Contacts: "Integration Test Contact"
- Test Objects: "Integration Test"

To use different test data, modify the executor class or create your own test scenarios.