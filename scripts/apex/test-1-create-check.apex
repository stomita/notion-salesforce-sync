// Test 1 - Check: Verify create sync results
System.debug('=== Test 1 Check: Verifying create sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Check create sync results
executor.checkCreateSyncResults();

System.debug('Create sync check complete.');