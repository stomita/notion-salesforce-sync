// Anonymous Apex script to run Notion integration tests
// This executes the NotionIntegrationTestExecutor class

System.debug('=== Running Notion Integration Tests ===');
System.debug('Start time: ' + DateTime.now());

try {
    // Create test executor instance
    NotionIntegrationTestExecutor testExecutor = new NotionIntegrationTestExecutor();
    
    // Run all tests
    testExecutor.runAllTests();
    
    System.debug('End time: ' + DateTime.now());
    System.debug('=== Integration Tests Completed Successfully ===');
    
} catch (Exception e) {
    System.debug('=== Integration Tests FAILED ===');
    System.debug('Error: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
    
    // Re-throw to ensure non-zero exit code
    throw e;
}