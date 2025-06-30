// Test 6 - Setup: Clean up any existing batch test data
System.debug('=== Test 6 Setup: Cleaning up existing batch test data ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Clean up any existing batch test data
executor.setupBatchTest();

System.debug('Batch test environment ready.');