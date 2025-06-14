// Script to set up Notion API credentials for integration testing
// This script calls the deployed NotionTestCredentialSetup class

// API key will be replaced by the shell script
String apiKey = 'NOTION_API_KEY_PLACEHOLDER';

try {
    // Use the deployed class to set up credentials and permissions
    NotionTestCredentialSetup.setup(apiKey);
    System.debug('Notion API credentials configured successfully');
} catch (Exception e) {
    System.debug('ERROR: Failed to configure Notion credentials: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
    throw e;
}