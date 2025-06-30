// Test 6 - Check: Verify batch processing results
System.debug('=== Test 6 Check: Verifying batch processing results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Check batch processing results
    executor.checkBatchProcessingResults();
    
    // Report success
    System.debug('✓ Test 6: Batch processing check PASSED');
    System.debug('SUCCESS: All batch operations processed correctly');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 6: Batch processing check FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}