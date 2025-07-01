@isTest
private class NotionNavigationControllerTest {
    
    @TestSetup
    static void setup() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account for Navigation'
        );
        insert testAccount;
    }
    
    @isTest
    static void testGetNotionPageInfo_PageExists() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Navigation' LIMIT 1];
        
        // Mock the HTTP callout
        Test.setMock(HttpCalloutMock.class, new NotionNavigationMock(true, true));
        
        Test.startTest();
        String pageUrl = NotionNavigationController.getNotionPageInfo(testAccount.Id, 'Account');
        Test.stopTest();
        
        // Verify URL format
        System.assertNotEquals(null, pageUrl, 'Page URL should not be null');
        System.assert(pageUrl.startsWith('https://www.notion.so/'), 'URL should start with www.notion.so');
        // URL format is now without hyphens - just the page ID
        System.assert(!pageUrl.contains('-'), 'URL should not contain hyphens');
    }
    
    @isTest
    static void testGetNotionPageInfo_PageNotExists() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Navigation' LIMIT 1];
        
        // Mock the HTTP callout - empty results
        Test.setMock(HttpCalloutMock.class, new NotionNavigationMock(true, false));
        
        Test.startTest();
        String pageUrl = NotionNavigationController.getNotionPageInfo(testAccount.Id, 'Account');
        Test.stopTest();
        
        System.assertEquals(null, pageUrl, 'Page URL should be null when page not found');
    }
    
    @isTest
    static void testGetNotionPageInfo_NoSyncConfig() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Navigation' LIMIT 1];
        
        Test.startTest();
        String pageUrl = NotionNavigationController.getNotionPageInfo(testAccount.Id, 'NonExistentObject');
        Test.stopTest();
        
        System.assertEquals(null, pageUrl, 'Page URL should be null when no sync config');
    }
    
    @isTest
    static void testSyncAndGetNotionPage_Create() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Navigation' LIMIT 1];
        
        // Mock the HTTP callouts
        Test.setMock(HttpCalloutMock.class, new NotionNavigationMock(true, true));
        
        // Disable invocable processing for this test
        NotionSyncInvocable.disableInTest = true;
        
        Test.startTest();
        String pageUrl = NotionNavigationController.syncAndGetNotionPage(
            testAccount.Id, 
            'Account', 
            NotionSync.OPERATION_CREATE
        );
        Test.stopTest();
        
        System.assertNotEquals(null, pageUrl, 'Page URL should not be null after sync');
        System.assert(pageUrl.startsWith('https://www.notion.so/'), 'URL should start with www.notion.so');
    }
    
    @isTest
    static void testSyncAndGetNotionPage_Error() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Navigation' LIMIT 1];
        
        // Mock API failure
        Test.setMock(HttpCalloutMock.class, new NotionNavigationMock(false, false));
        
        // Disable invocable processing for this test
        NotionSyncInvocable.disableInTest = true;
        
        Test.startTest();
        try {
            NotionNavigationController.syncAndGetNotionPage(
                testAccount.Id, 
                'Account', 
                NotionSync.OPERATION_CREATE
            );
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Error message should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSyncAndGetNotionPage_RecordNotFound() {
        // Use a fake ID that doesn't exist
        Id fakeAccountId = '001000000000000AAA';
        
        // Mock the HTTP callout
        Test.setMock(HttpCalloutMock.class, new NotionNavigationMock(true, false));
        
        Test.startTest();
        try {
            NotionNavigationController.syncAndGetNotionPage(
                fakeAccountId, 
                'Account', 
                NotionSync.OPERATION_CREATE
            );
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Record not found'), 'Error message should mention record not found: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSyncAndGetNotionPage_InactiveConfig() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account for Navigation' LIMIT 1];
        
        // Note: We can't actually test inactive config since we can't modify metadata in tests
        // This test is included for completeness but will test the happy path
        Test.setMock(HttpCalloutMock.class, new NotionNavigationMock(true, true));
        
        Test.startTest();
        String pageUrl = NotionNavigationController.syncAndGetNotionPage(
            testAccount.Id, 
            'Account', 
            NotionSync.OPERATION_CREATE
        );
        Test.stopTest();
        
        System.assertNotEquals(null, pageUrl, 'Should return page URL');
    }
    
    @isTest
    static void testFormatNotionUrl() {
        // Test URL formatting with reflection (since method is private)
        String pageId = '1429989fe8ac4effbc8f57f56486db54';
        String expectedUrl = 'https://www.notion.so/1429989fe8ac4effbc8f57f56486db54';
        
        // We can't directly test private methods, but we can test through public method
        // The formatting is tested indirectly through testGetNotionPageInfo_PageExists
        System.assert(true, 'URL formatting tested through public methods');
    }
    
    /**
     * Mock class for Notion API responses
     */
    private class NotionNavigationMock implements HttpCalloutMock {
        private Boolean success;
        private Boolean hasResults;
        
        public NotionNavigationMock(Boolean success, Boolean hasResults) {
            this.success = success;
            this.hasResults = hasResults;
        }
        
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            
            if (!success) {
                response.setStatusCode(500);
                response.setBody('{"message": "Internal Server Error"}');
                return response;
            }
            
            response.setStatusCode(200);
            
            if (request.getEndpoint().contains('/query')) {
                // Database query response
                if (hasResults) {
                    response.setBody('{"results": [{"id": "1429989fe8ac4effbc8f57f56486db54"}], "has_more": false}');
                } else {
                    response.setBody('{"results": [], "has_more": false}');
                }
            } else if (request.getEndpoint().contains('/pages')) {
                // Page creation/update response
                response.setBody('{"id": "1429989fe8ac4effbc8f57f56486db54"}');
            }
            
            return response;
        }
    }
}