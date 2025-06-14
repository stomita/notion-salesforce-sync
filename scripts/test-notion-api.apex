// Test Script for Notion API Integration
// Before running, make sure to:
// 1. Set up the Named Credential authentication in Setup
// 2. Replace YOUR_DATABASE_ID with an actual Notion database ID
// 3. Grant the integration access to the database in Notion

// Test 1: Basic connection test - Query a database
System.debug('=== Test 1: Basic Database Query ===');
try {
    // Replace with your actual Notion database ID
    String databaseId = 'YOUR_DATABASE_ID';
    
    NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(databaseId, null);
    System.debug('Success: ' + response.success);
    System.debug('Status Code: ' + response.statusCode);
    if (!response.success) {
        System.debug('Error Message: ' + response.errorMessage);
    }
    System.debug('Response Body (first 500 chars): ' + 
        (response.responseBody != null && response.responseBody.length() > 500 
            ? response.responseBody.substring(0, 500) + '...' 
            : response.responseBody));
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString());
}

// Test 2: Create a test page
System.debug('\n=== Test 2: Create Test Page ===');
try {
    // Replace with your actual Notion database ID
    String databaseId = 'YOUR_DATABASE_ID';
    
    Map<String, Object> properties = new Map<String, Object>();
    // Add a title property - adjust the property name based on your database schema
    properties.put('Name', NotionApiClient.buildTitleProperty('Test Page from Salesforce - ' + DateTime.now().format()));
    
    // Add other properties as needed based on your database schema
    // properties.put('Status', NotionApiClient.buildSelectProperty('Active'));
    // properties.put('Description', NotionApiClient.buildTextProperty('This is a test page created from Salesforce'));
    
    NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
        databaseId,
        properties
    );
    
    NotionApiClient.NotionResponse createResponse = NotionApiClient.createPage(pageRequest);
    System.debug('Create Success: ' + createResponse.success);
    System.debug('Status Code: ' + createResponse.statusCode);
    if (createResponse.success) {
        System.debug('Created Page ID: ' + createResponse.pageId);
    } else {
        System.debug('Error Message: ' + createResponse.errorMessage);
    }
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString());
}

// Test 3: Test error handling with invalid database ID
System.debug('\n=== Test 3: Error Handling Test ===');
try {
    NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase('invalid-database-id', null);
    System.debug('Success: ' + response.success);
    System.debug('Status Code: ' + response.statusCode);
    System.debug('Error Message: ' + response.errorMessage);
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
}

// Test 4: Check Named Credential endpoint
System.debug('\n=== Test 4: Named Credential Check ===');
System.debug('Named Credential Endpoint: callout:Notion_API');
System.debug('This should resolve to: https://api.notion.com');