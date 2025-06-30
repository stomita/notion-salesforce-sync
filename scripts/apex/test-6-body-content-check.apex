// Test 6: Body Content Update - Check results
NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Check sync results
    executor.checkBodyContentSyncResults();
    
    System.debug('✓ Body content sync verification completed');
} catch (Exception e) {
    System.debug('✗ Body content sync verification failed: ' + e.getMessage());
    System.debug(e.getStackTraceString());
    throw e;
}