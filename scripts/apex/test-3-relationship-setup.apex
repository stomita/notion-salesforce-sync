// Test 3 - Setup: Create related records
System.debug('=== Test 3 Setup: Creating related records ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Create related records
executor.createRelatedRecords();

System.debug('Related records created. Wait for sync to complete.');