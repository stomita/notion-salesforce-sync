// Verify Notion API Authentication
System.debug('=== Verifying Notion API Authentication ===');

try {
    // Call the authentication verification method
    NotionIntegrationTestExecutor.verifyAuthentication();
    
    // Report success
    System.debug('✓ Authentication verification PASSED');
    System.debug('SUCCESS: Notion API credentials are properly configured');
} catch (Exception e) {
    // Report failure
    System.debug('✗ Authentication verification FAILED');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('INTEGRATION_TEST_FAILURE_MARKER');
    throw e; // Re-throw to ensure non-zero exit code
}