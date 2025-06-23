// Test 6 - Run: Create many records to test batch processing
System.debug('=== Test 6 Run: Creating bulk records for batch processing ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Create batch test records
    executor.runBatchTest();
    
    // Report success
    System.debug('✓ Test 6: Batch run completed');
    System.debug('SUCCESS: Batch test records created successfully');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 6: Batch run FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}