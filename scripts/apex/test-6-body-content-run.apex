// Test 6: Body Content Update - Run comprehensive test
NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Run the comprehensive body content update test
    executor.runBodyContentUpdateTest();
    
    System.debug('✓ Body content update test execution completed');
} catch (Exception e) {
    System.debug('✗ Body content update test failed: ' + e.getMessage());
    System.debug(e.getStackTraceString());
    throw e;
}