# Integration Test Scripts

This directory contains scripts for running Notion integration tests individually or all together.

## Prerequisites

1. Scratch org with metadata deployed
2. Notion API credentials configured in Named Credentials
3. Custom metadata configured with real Notion database IDs

## Individual Test Scripts

Each test can be run independently:

```bash
# Clean up test data first (recommended before running tests)
./scripts/test-0-setup.sh [org-alias]

# Test 1: Create and Sync
./scripts/test-1-create.sh [org-alias]

# Test 2: Update and Sync
./scripts/test-2-update.sh [org-alias]

# Test 3: Relationship Sync
./scripts/test-3-relationship.sh [org-alias]

# Test 4: Relationship Change Sync
./scripts/test-4-relationship-change.sh [org-alias]

# Test 5: Delete and Sync
./scripts/test-5-delete.sh [org-alias]

# Test 6: Batch Processing
./scripts/test-6-batch.sh [org-alias]
```

## Run All Tests

To run all tests in sequence:

```bash
./scripts/execute-integration-tests.sh [org-alias]
```

## Test Descriptions

1. **Test 0 - Setup**: Cleans up any existing test data and enables sync logging
2. **Test 1 - Create**: Creates Account and Test Parent records and verifies sync to Notion
3. **Test 2 - Update**: Updates existing records and verifies changes in Notion
4. **Test 3 - Relationship**: Creates Contact and Test Child with relationships and verifies in Notion
4. **Test 4 - Relationship Change**: Changes relationships between records and verifies updates in Notion (depends on Test 3 records)
5. **Test 5 - Delete**: Deletes records and verifies removal from Notion
6. **Test 6 - Batch**: Creates 100 accounts to test batch processing

## Debugging

If a test fails:

1. Check the console output for error messages
2. View sync logs: `sf data query -f scripts/soql/recent-sync-logs.soql -o [org-alias]`
3. Run individual test phases separately (setup vs check)

## Test Phases

Each test follows a consistent pattern:
1. **Setup phase** (if needed): Prepares test data and ensures dependencies exist
2. **Run phase**: Executes the actual test action (create/update/delete)
3. **Wait phase**: Allows time for async sync to complete
4. **Check phase**: Verifies the sync results in Notion

Tests with dependencies:
- **Test 2 (Update)**: Setup phase ensures records from Test 1 exist
- **Test 4 (Relationship Change)**: Setup phase ensures records from Test 3 exist and creates second account

Tests with separate setup and run:
- **Test 4**: Setup (dependencies + second account) → Wait → Run (change relationships) → Wait → Check
- **Test 5**: Setup (create records) → Wait → Run (delete records) → Wait → Check