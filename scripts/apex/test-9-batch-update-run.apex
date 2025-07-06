// Test 9 - Run: Update many records to test batch update processing
System.debug('=== Test 9 Run: Updating bulk records for batch update processing ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Update batch test records
    executor.runBatchUpdateTest();
    
    // Report success
    System.debug('✓ Test 9: Batch update run completed');
    System.debug('SUCCESS: Batch update test records updated successfully');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 9: Batch update run FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}