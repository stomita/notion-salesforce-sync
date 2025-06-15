# Integration Testing Guide

This guide explains how to run integration tests that verify the Notion sync functionality with real API calls.

## Prerequisites

1. A Notion account with API access
2. A Notion integration token
3. Test databases created in Notion (see CI_SETUP.md for database setup)
4. A Salesforce scratch org with the package deployed

## Test Database Setup

### Overview

The integration tests require four Notion databases with specific properties configured exactly as expected by the test mappings.

**IMPORTANT**: All databases must have a `salesforce_id` property (type: Text) for tracking Salesforce records.

### Step-by-Step Database Creation

#### 1. Create Four Test Databases in Notion

Create new database pages in your Notion workspace:
1. Account Test Database
2. Contact Test Database  
3. Test Parent Database
4. Test Child Database

#### 2. Configure Properties for Each Database

##### Account Test Database
Add these properties:
- Property name: `Name` → Type: `Title`
- Property name: `salesforce_id` → Type: `Text`

**Note**: Account Description is mapped to page body content.

##### Contact Test Database
Add these properties:
- Property name: `Name` → Type: `Title`
- Property name: `Email` → Type: `Email`
- Property name: `Account` → Type: `Relation` → Select "Account Test Database"
- Property name: `salesforce_id` → Type: `Text`

##### Test Parent Database
Add these properties:
- Property name: `Name` → Type: `Title`
- Property name: `Status` → Type: `Select` → Add options: Active, Inactive, In Progress
- Property name: `Amount` → Type: `Number`
- Property name: `Active` → Type: `Checkbox`
- Property name: `salesforce_id` → Type: `Text`

**Note**: Description__c is mapped to page body content.

##### Test Child Database
Add these properties:
- Property name: `Name` → Type: `Title`
- Property name: `Quantity` → Type: `Number`
- Property name: `Due Date` → Type: `Date`
- Property name: `Test Parent` → Type: `Relation` → Select "Test Parent Database"
- Property name: `Account` → Type: `Relation` → Select "Account Test Database"
- Property name: `salesforce_id` → Type: `Text`

**Note**: Details__c is mapped to page body content.

#### 3. Grant Integration Access

For each database:
1. Click `Share` button (top right)
2. Click `Invite`
3. Search for your integration name
4. Select your integration
5. Ensure it has edit access

#### 4. Get Database IDs

For each database:
1. Click `Share` → `Copy link`
2. The URL format is: `https://www.notion.so/{workspace}/{database-id}?v={view-id}`
3. Copy the database-id portion (32 characters)

#### 5. Configure Database IDs

Set these as environment variables or GitHub secrets:
- `NOTION_DATABASE_ID_ACCOUNT` = Account database ID
- `NOTION_DATABASE_ID_CONTACT` = Contact database ID
- `NOTION_DATABASE_ID_TEST_PARENT` = Test Parent database ID
- `NOTION_DATABASE_ID_TEST_CHILD` = Test Child database ID

### Common Database Setup Issues

#### "Property not found" errors
- Property names are case-sensitive and must match exactly
- Use "Name" not "Title" for title properties
- Check for trailing spaces in property names

#### "Relation not found" errors
- Create databases in order (Account first, then Contact, etc.)
- Ensure relation properties point to correct target databases
- Relation names must match exactly

#### Sync failures
- Verify `salesforce_id` property exists in ALL databases
- Check integration has edit access to all databases
- Ensure all required properties are created with correct types

### Body Content Field Mappings

These Salesforce fields sync to Notion page body content (not properties):
- Account: `Description` field → Page content
- Test Parent: `Description__c` field → Page content
- Test Child: `Details__c` field → Page content

These appear as rich text within the Notion page itself.

## Quick Start

The integration test framework now supports both automated CI execution and interactive local development.

### Choosing the Right Script

#### Use `run-integration-tests.sh` when:
- **First-time setup** - You haven't configured the test environment yet
- **CI/CD environment** - Running in a fresh scratch org that needs full setup
- **Complete automation needed** - You want the script to handle all configuration

This script provides:
- Interactive prompts for missing environment variables (API key, database IDs)
- Automatic test metadata configuration
- Integration test component deployment
- Named Credential setup with your API key
- Test execution
- Cleanup (restoring placeholder values)

```bash
# First time setup
./scripts/run-integration-tests.sh

# Specify a scratch org
./scripts/run-integration-tests.sh my-scratch-org
```

#### Use `execute-integration-tests.sh` when:
- **Everything is already configured** - Named Credentials, metadata, and components are set up
- **Quick re-runs** - You just want to run tests again without setup
- **Debugging** - You're iterating on test fixes and need fast execution

This lightweight script only runs the tests, skipping all setup steps.

```bash
# Quick test execution
./scripts/execute-integration-tests.sh

# After deploying test code changes
sf project deploy start --source-dir force-app/integration
./scripts/execute-integration-tests.sh
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

### Field Type Coverage

The test objects include various field types to ensure comprehensive sync support:
- Text and Long Text Areas
- Number and Currency
- Date and DateTime
- Checkbox (Boolean)
- Picklist values
- Master-Detail relationships
- Lookup relationships
- Body content mapping (Long Text Area → Notion page body)

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

Required GitHub configuration:

**Secrets** (sensitive data):
- `DEVHUB_SFDX_AUTH_URL` - Salesforce Dev Hub authentication
- `NOTION_API_KEY` - Notion API key

**Variables** (non-sensitive configuration):
- `NOTION_WORKSPACE_ID` - Notion workspace ID
- `NOTION_TEST_ACCOUNT_DB` - Account test database ID
- `NOTION_TEST_CONTACT_DB` - Contact test database ID
- `NOTION_TEST_PARENT_DB` - Test Parent database ID
- `NOTION_TEST_CHILD_DB` - Test Child database ID

The CI workflow will:
1. Validate all configuration is present (fail fast if not)
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
- Ensure Flows are properly configured with Invocable Apex

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

## Unit Testing

Before running integration tests, verify the core functionality with unit tests:

```bash
sf apex test run --tests NotionApiClientTest --code-coverage --result-format human --wait 10
```

Expected result: All tests should pass with high code coverage.

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
./scripts/execute-integration-tests.sh
```

## Advanced Usage

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

3. **Verify Invocable Apex:**
   ```apex
   // Test the invocable method directly
   NotionSyncInvocable.SyncRequest request = new NotionSyncInvocable.SyncRequest();
   request.recordId = 'test123';
   request.objectType = 'Account';
   request.operationType = 'CREATE';
   
   List<NotionSyncInvocable.SyncRequest> requests = new List<NotionSyncInvocable.SyncRequest>{request};
   NotionSyncInvocable.syncToNotion(requests);
   ```

### Customizing Test Data

The test executor uses specific prefixes for test data:
- Accounts: "Integration Test Account"
- Contacts: "Integration Test Contact"
- Test Objects: "Integration Test"

To use different test data, modify the executor class or create your own test scenarios.

## Security Best Practices

1. **Never commit API tokens** to version control
2. Use **Named Credentials** for all external API calls
3. Rotate API tokens regularly
4. Limit integration access to only necessary databases in Notion
5. Monitor sync logs for unauthorized access attempts

## Additional Debug Commands

```bash
# View recent logs
sf apex log list

# Get detailed log
sf apex log get --log-id <log-id>

# Monitor sync logs
sf data query --query "$(cat scripts/soql/check-sync-logs.soql)"

# Check Queueable Jobs
sf data query --query "SELECT Id, Status, JobType, MethodName, CreatedDate FROM AsyncApexJob WHERE JobType='Queueable' ORDER BY CreatedDate DESC LIMIT 10"
```

## Integration Test Structure

The `force-app/integration` directory contains:

- **objects/**: Custom test objects with various field types and relationships
  - `Test_Parent_Object__c`: Parent object with various field types
  - `Test_Child_Object__c`: Child object with Master-Detail and Lookup relationships
  
- **customMetadata/**: Test configurations for Notion sync
  - NotionDatabase records for test databases
  - NotionSyncObject records for sync configuration
  - NotionSyncField records for field mappings
  - NotionRelation records for relationship mappings
  
- **flows/**: Automated flows for test objects
  - Create/Update flows that call Invocable Apex
  - Delete flows for record removal
  
- **permissionsets/**: Permission set for test object access

- **classes/**: Test execution and credential setup classes
  - `NotionIntegrationTestExecutor`: Main test runner
  - `NotionTestCredentialSetup`: Programmatic credential configuration
  - `NotionTestCredentialSetupTest`: Unit tests for credential setup

Note: This directory is not part of the main package deployment (marked as `default: false` in sfdx-project.json).