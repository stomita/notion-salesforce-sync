// Test 6: Body Content Update - Setup
NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Setup test data
    executor.setupBodyContentTest();
    
    System.debug('✓ Body content test setup completed');
} catch (Exception e) {
    System.debug('✗ Body content test setup failed: ' + e.getMessage());
    System.debug(e.getStackTraceString());
    throw e;
}