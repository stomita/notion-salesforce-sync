// Test 2 - Check: Verify update sync results
System.debug('=== Test 2 Check: Verifying update sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Check update sync results
executor.checkUpdateSyncResults();

System.debug('Update sync check complete.');