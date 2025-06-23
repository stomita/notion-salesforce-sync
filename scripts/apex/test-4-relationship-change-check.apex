// Test 4 - Check: Verify relationship change sync results
System.debug('=== Test 4 Check: Verifying relationship change sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Check relationship change sync results
    executor.checkRelationshipChanges();
    
    // Report success
    System.debug('✓ Test 4: Relationship change sync check PASSED');
    System.debug('SUCCESS: All relationship changes synced correctly to Notion');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 4: Relationship change sync check FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}