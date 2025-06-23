// Test 1 - Check: Verify create sync results
System.debug('=== Test 1 Check: Verifying create sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Check create sync results
    executor.checkCreateSyncResults();
    
    // Report success
    System.debug('✓ Test 1: Create sync check PASSED');
    System.debug('SUCCESS: All create operations synced correctly to Notion');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 1: Create sync check FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}