// Test 3 - Run: Create related records
System.debug('=== Test 3 Run: Creating related records ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Create related records
executor.runRelationshipTest();

System.debug('Related records created. Wait for sync to complete.');