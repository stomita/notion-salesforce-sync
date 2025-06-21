// Test 3 - Check: Verify relationship sync results
System.debug('=== Test 3 Check: Verifying relationship sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Check relationship sync results
    executor.checkRelationshipSyncResults();
    
    // Report success
    System.debug('✓ Test 3: Relationship sync check PASSED');
    System.debug('SUCCESS: All relationship operations synced correctly to Notion');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 3: Relationship sync check FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}