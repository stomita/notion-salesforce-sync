// Test NotionApiClient class
System.debug('=== Testing NotionApiClient ===\n');

// Test 1: Query a database (search for databases first)
try {
    System.debug('Test 1: Query Database');
    
    // First, find a database using search API
    HttpRequest searchReq = new HttpRequest();
    searchReq.setEndpoint('callout:Notion_API/v1/search');
    searchReq.setMethod('POST');
    searchReq.setHeader('Content-Type', 'application/json');
    searchReq.setBody('{"filter": {"property": "object", "value": "database"}, "page_size": 1}');
    
    HttpResponse searchRes = new Http().send(searchReq);
    
    if (searchRes.getStatusCode() == 200) {
        Map<String, Object> searchMap = (Map<String, Object>) JSON.deserializeUntyped(searchRes.getBody());
        List<Object> results = (List<Object>) searchMap.get('results');
        
        if (!results.isEmpty()) {
            Map<String, Object> db = (Map<String, Object>) results[0];
            String databaseId = (String) db.get('id');
            
            // Now query the database
            NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(databaseId, null);
            
            if (response.success) {
                System.debug('✅ Database query successful');
                System.debug('  Status Code: ' + response.statusCode);
            } else {
                System.debug('❌ Database query failed: ' + response.errorMessage);
            }
        } else {
            System.debug('⚠️  No databases found to test');
        }
    }
} catch (Exception e) {
    System.debug('❌ Failed: ' + e.getMessage());
}

// Test 2: Create a page
try {
    System.debug('\nTest 2: Create Page');
    
    // Find a database first
    HttpRequest searchReq = new HttpRequest();
    searchReq.setEndpoint('callout:Notion_API/v1/search');
    searchReq.setMethod('POST');
    searchReq.setHeader('Content-Type', 'application/json');
    searchReq.setBody('{"filter": {"property": "object", "value": "database"}, "page_size": 1}');
    
    HttpResponse searchRes = new Http().send(searchReq);
    
    if (searchRes.getStatusCode() == 200) {
        Map<String, Object> searchMap = (Map<String, Object>) JSON.deserializeUntyped(searchRes.getBody());
        List<Object> results = (List<Object>) searchMap.get('results');
        
        if (!results.isEmpty()) {
            Map<String, Object> db = (Map<String, Object>) results[0];
            String databaseId = (String) db.get('id');
            
            // Build properties using helper methods
            Map<String, Object> properties = new Map<String, Object>{
                'Name' => NotionApiClient.buildTitleProperty('Test Account from Salesforce API Client'),
                'Salesforce ID' => NotionApiClient.buildTextProperty('001TEST' + System.now().millisecond())
            };
            
            // Create page request
            NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(databaseId, properties);
            NotionApiClient.NotionResponse response = NotionApiClient.createPage(pageRequest);
            
            if (response.success) {
                System.debug('✅ Page created successfully');
                System.debug('  Page ID: ' + response.pageId);
                
                // Test 3: Retrieve the created page
                System.debug('\nTest 3: Get Page');
                NotionApiClient.NotionResponse getResponse = NotionApiClient.getPage(response.pageId);
                
                if (getResponse.success) {
                    System.debug('✅ Page retrieved successfully');
                } else {
                    System.debug('❌ Page retrieval failed: ' + getResponse.errorMessage);
                }
            } else {
                System.debug('❌ Page creation failed: ' + response.errorMessage);
            }
        } else {
            System.debug('⚠️  No databases found to test');
        }
    }
} catch (Exception e) {
    System.debug('❌ Failed: ' + e.getMessage());
}

// Test 4: Update a page
try {
    System.debug('\nTest 4: Update Page');
    
    // Find a database and query for existing pages
    HttpRequest searchReq = new HttpRequest();
    searchReq.setEndpoint('callout:Notion_API/v1/search');
    searchReq.setMethod('POST');
    searchReq.setHeader('Content-Type', 'application/json');
    searchReq.setBody('{"filter": {"property": "object", "value": "database"}, "page_size": 1}');
    
    HttpResponse searchRes = new Http().send(searchReq);
    
    if (searchRes.getStatusCode() == 200) {
        Map<String, Object> searchMap = (Map<String, Object>) JSON.deserializeUntyped(searchRes.getBody());
        List<Object> results = (List<Object>) searchMap.get('results');
        
        if (!results.isEmpty()) {
            Map<String, Object> db = (Map<String, Object>) results[0];
            String databaseId = (String) db.get('id');
            
            // Query for existing pages
            NotionApiClient.NotionResponse queryResponse = NotionApiClient.queryDatabase(databaseId, null);
            
            if (queryResponse.success && queryResponse.responseBody != null) {
                Map<String, Object> queryMap = (Map<String, Object>) JSON.deserializeUntyped(queryResponse.responseBody);
                List<Object> pages = (List<Object>) queryMap.get('results');
                
                if (!pages.isEmpty()) {
                    Map<String, Object> firstPage = (Map<String, Object>) pages[0];
                    String pageId = (String) firstPage.get('id');
                    
                    // Update the page
                    Map<String, Object> updateProperties = new Map<String, Object>{
                        'Name' => NotionApiClient.buildTitleProperty('Updated: Test Account ' + DateTime.now())
                    };
                    
                    NotionApiClient.NotionResponse updateResponse = NotionApiClient.updatePage(pageId, updateProperties);
                    
                    if (updateResponse.success) {
                        System.debug('✅ Page updated successfully');
                    } else {
                        System.debug('❌ Page update failed: ' + updateResponse.errorMessage);
                    }
                } else {
                    System.debug('⚠️  No existing pages found to update');
                }
            }
        }
    }
} catch (Exception e) {
    System.debug('❌ Failed: ' + e.getMessage());
}

System.debug('\n=== All Tests Complete ===');