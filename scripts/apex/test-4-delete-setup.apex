// Test 4 - Setup: Delete test records
System.debug('=== Test 4 Setup: Deleting test records ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Delete test records
executor.deleteTestRecords();

System.debug('Test records deleted. Wait for sync to complete.');