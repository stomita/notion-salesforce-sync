// Test 1 - Run: Create test records
System.debug('=== Test 1 Run: Creating test records ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Clean up first
executor.setupTestData();

// Create test records
executor.runCreateTest();

System.debug('Test records created. Wait for sync to complete.');