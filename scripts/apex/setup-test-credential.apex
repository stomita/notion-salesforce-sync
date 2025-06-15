// Set up test credential for Notion API
// NOTE: Replace 'your-api-key-here' with a real Notion API key for testing

String apiKey = 'your-api-key-here';  // REPLACE THIS!

if (apiKey == 'your-api-key-here') {
    System.debug('ERROR: You must replace the API key with a real Notion API key');
    System.debug('Get your API key from: https://www.notion.so/my-integrations');
    return;
}

try {
    // First ensure user has permissions
    NotionTestCredentialSetup.ensureUserPermissions();
    
    // Then set up the credential
    NotionTestCredentialSetup.setupCredential(apiKey);
    
    System.debug('✓ Credential setup complete');
    System.debug('Note: Permission set assignment happens asynchronously');
    
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

// Test the credential
System.debug('\n--- Testing Credential ---');
try {
    // Try a simple API call
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Notion_API/v1/users/me');
    req.setMethod('GET');
    req.setHeader('Content-Type', 'application/json');
    req.setHeader('Notion-Version', '2022-06-28');
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    
    if (res.getStatusCode() == 200) {
        System.debug('✓ API call successful!');
        System.debug('Response: ' + res.getBody());
    } else {
        System.debug('✗ API call failed with status: ' + res.getStatusCode());
        System.debug('Response: ' + res.getBody());
    }
} catch (Exception e) {
    System.debug('✗ Test API call failed: ' + e.getMessage());
}