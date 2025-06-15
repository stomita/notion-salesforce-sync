// Test 4 - Check: Verify delete sync results
System.debug('=== Test 4 Check: Verifying delete sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Check delete sync results
executor.checkDeleteSyncResults();

System.debug('Delete sync check complete.');