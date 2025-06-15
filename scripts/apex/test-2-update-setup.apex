// Test 2 - Setup: Update test records
System.debug('=== Test 2 Setup: Updating test records ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Update test records
executor.updateTestRecords();

System.debug('Test records updated. Wait for sync to complete.');