// Final Report: Show test results
System.debug('=== Final Test Report ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

try {
    // Report final results
    executor.reportResults();
    
    // All tests passed
    System.debug('✓ ALL INTEGRATION TESTS PASSED');
    System.debug('SUCCESS: All Notion sync operations completed successfully');
} catch (Exception e) {
    // Some tests failed
    System.debug('✗ INTEGRATION TESTS FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}