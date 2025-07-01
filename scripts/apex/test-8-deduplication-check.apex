// Test 8: Deduplication - Check Results
System.debug('=== Test 8 Check: Verifying deduplication results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Check deduplication results
    executor.checkDeduplicationResults();
    
    // Report success
    System.debug('✓ Test 8: Deduplication test PASSED');
    System.debug('SUCCESS: Duplicate Notion pages were successfully removed');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 8: Deduplication test FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}