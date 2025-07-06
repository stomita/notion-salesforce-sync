// Test 9 - Setup: Create records for batch update test
System.debug('=== Test 9 Setup: Creating records for batch update test ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Create records that will be updated in bulk
executor.setupBatchUpdateTest();

System.debug('Batch update test environment ready.');