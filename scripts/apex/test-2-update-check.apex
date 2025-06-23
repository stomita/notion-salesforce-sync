// Test 2 - Check: Verify update sync results
System.debug('=== Test 2 Check: Verifying update sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Check update sync results
    executor.checkUpdateSyncResults();
    
    // Report success
    System.debug('✓ Test 2: Update sync check PASSED');
    System.debug('SUCCESS: All update operations synced correctly to Notion');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 2: Update sync check FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}