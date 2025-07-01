// Test 8: Deduplication - Create Duplicates
NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Create duplicate pages in Notion
    executor.runDeduplicationTest();
    
    System.debug('✓ Duplicate pages created successfully');
} catch (Exception e) {
    System.debug('✗ Failed to create duplicate pages: ' + e.getMessage());
    System.debug(e.getStackTraceString());
    throw e;
}