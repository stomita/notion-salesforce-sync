// Verify Notion API Authentication
System.debug('=== Verifying Notion API Authentication ===');

try {
    // Verify authentication using the NotionTestCredentialSetup
    Boolean authSuccess = NotionTestCredentialSetup.verifyAuthentication();
    
    if (authSuccess) {
        System.debug('✓ Authentication verification PASSED');
        System.debug('Notion API credentials are properly configured');
    } else {
        System.debug('✗ Authentication verification FAILED');
        throw new CalloutException('Notion API authentication failed');
    }
} catch (Exception e) {
    System.debug('✗ AUTHENTICATION VERIFICATION FAILED');
    System.debug('Error: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString());
    
    // Re-throw to ensure the script fails
    throw new CalloutException('Notion API authentication verification failed: ' + e.getMessage());
}