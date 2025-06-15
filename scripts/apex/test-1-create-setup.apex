// Test 1 - Setup: Create test records
System.debug('=== Test 1 Setup: Creating test records ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Clean up first
executor.setupTestData();

// Create test records
executor.createTestRecords();

System.debug('Test records created. Wait for sync to complete.');