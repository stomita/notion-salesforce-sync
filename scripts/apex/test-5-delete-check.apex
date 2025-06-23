// Test 5 - Check: Verify delete sync results
System.debug('=== Test 5 Check: Verifying delete sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Check delete sync results
    executor.checkDeleteSyncResults();
    
    // Report success
    System.debug('✓ Test 5: Delete sync check PASSED');
    System.debug('SUCCESS: All delete operations synced correctly to Notion');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 5: Delete sync check FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}