// Test 2 - Run: Update test records
System.debug('=== Test 2 Run: Updating test records ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Update test records
executor.runUpdateTest();

System.debug('Test records updated. Wait for sync to complete.');