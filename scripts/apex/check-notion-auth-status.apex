// Test to check current user permissions and External Credential access
System.debug('Current User: ' + UserInfo.getUserName());
System.debug('User ID: ' + UserInfo.getUserId());
System.debug('Profile: ' + UserInfo.getProfileId());

// Test basic callout without External Credential to see if the issue is with permissions
HttpRequest req = new HttpRequest();
req.setEndpoint('https://api.notion.com/v1/users/me');
req.setMethod('GET');
req.setHeader('Content-Type', 'application/json');
// Manual auth header for testing - this should be removed in production
// req.setHeader('Authorization', 'Bearer YOUR_TOKEN_HERE');
// Notion-Version header is now handled by Named Credential

System.debug('Testing direct API call without Named Credential...');
System.debug('Endpoint: ' + req.getEndpoint());

// Now test with Named Credential
System.debug('\nTesting with Named Credential...');
try {
    HttpRequest namedCredReq = new HttpRequest();
    namedCredReq.setEndpoint('callout:Notion_API/v1/users/me');
    namedCredReq.setMethod('GET');
    namedCredReq.setHeader('Content-Type', 'application/json');
    
    Http http = new Http();
    HttpResponse res = http.send(namedCredReq);
    
    System.debug('Status Code: ' + res.getStatusCode());
    System.debug('Response: ' + res.getBody());
} catch (Exception e) {
    System.debug('Error with Named Credential: ' + e.getMessage());
    System.debug('Error Type: ' + e.getTypeName());
}