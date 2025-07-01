// Test 8: Deduplication - Setup
NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Setup test data for deduplication
    executor.setupDeduplicationTest();
    
    System.debug('✓ Deduplication test setup completed');
} catch (Exception e) {
    System.debug('✗ Deduplication test setup failed: ' + e.getMessage());
    System.debug(e.getStackTraceString());
    throw e;
}