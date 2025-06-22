// Test 6 - Setup: Create many records to test batch processing
System.debug('=== Test 6 Setup: Creating bulk records for batch processing ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Create batch test records
    executor.createBatchTestRecords();
    
    // Report success
    System.debug('✓ Test 6: Batch setup completed');
    System.debug('SUCCESS: Batch test records created successfully');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Test 6: Batch setup FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}