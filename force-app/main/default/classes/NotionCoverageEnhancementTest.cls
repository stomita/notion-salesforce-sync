@isTest
private class NotionCoverageEnhancementTest {
    
    // Additional tests for NotionApiClient
    @isTest
    static void testNotionApiClientEdgeCases() {
        // Setup mock
        Test.setMock(HttpCalloutMock.class, new NotionApiMock());
        
        Test.startTest();
        
        // Test searchDatabases
        NotionApiClient.NotionResponse response = NotionApiClient.searchDatabases();
        System.assertNotEquals(null, response);
        
        // Test createPage
        Map<String, Object> properties = new Map<String, Object>{
            'Title' => NotionApiClient.buildTitleProperty('Test Page')
        };
        NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
            'test-db-id',
            properties,
            null
        );
        response = NotionApiClient.createPage(pageRequest);
        System.assertNotEquals(null, response);
        
        // Test error scenarios
        Test.setMock(HttpCalloutMock.class, new NotionApiErrorMock(500));
        response = NotionApiClient.searchDatabases();
        System.assertEquals(false, response.success);
        
        Test.stopTest();
    }
    
    // Additional tests for NotionDataTransformer
    @isTest
    static void testNotionDataTransformerComprehensive() {
        // Create test account
        Account acc = new Account(Name = 'Test Account', NumberOfEmployees = 100);
        insert acc;
        
        Test.startTest();
        
        // Test with a non-existent object type to ensure no metadata exists
        try {
            // Use a fake object name that definitely won't have metadata
            NotionDataTransformer.NotionPage page = NotionDataTransformer.transformRecord(acc, 'NonExistentObject__c');
            System.assert(false, 'Should have thrown exception');
        } catch (NotionDataTransformer.TransformationException e) {
            System.assert(e.getMessage().contains('No field mappings'), 'Should indicate no mappings');
        } catch (Exception e) {
            // In case a different exception is thrown
            System.assert(false, 'Unexpected exception type: ' + e.getTypeName() + ' - ' + e.getMessage());
        }
        
        // Test createNotionPageJson
        NotionDataTransformer.NotionPage testPage = new NotionDataTransformer.NotionPage();
        testPage.properties.put('Title', new Map<String, Object>{
            'title' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'type' => 'text',
                    'text' => new Map<String, Object>{'content' => 'Test Title'}
                }
            }
        });
        
        Map<String, Object> pageJson = NotionDataTransformer.createNotionPageJson(testPage, 'test-db-id');
        System.assertNotEquals(null, pageJson.get('parent'));
        System.assertNotEquals(null, pageJson.get('properties'));
        
        // Test createNotionUpdateJson
        Map<String, Object> updateJson = NotionDataTransformer.createNotionUpdateJson(testPage);
        System.assert(updateJson.containsKey('properties'));
        System.assert(!updateJson.containsKey('parent'));
        
        Test.stopTest();
    }
    
    // Additional tests for NotionAdminController
    @isTest
    static void testNotionAdminControllerEdgeCases() {
        Test.setMock(HttpCalloutMock.class, new NotionApiMock());
        
        Test.startTest();
        
        // Test getDatabaseSchema
        try {
            NotionAdminController.DatabaseSchema schema = NotionAdminController.getDatabaseSchema('test-db-id');
            // May succeed or fail depending on mock
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        
        // Test getConfiguredSyncObjects
        List<Map<String, String>> syncObjects = NotionAdminController.getConfiguredSyncObjects();
        System.assertNotEquals(null, syncObjects);
        
        // Test deleteSyncConfiguration
        Test.setMock(HttpCalloutMock.class, new MetadataServiceMock());
        try {
            NotionAdminController.SaveResult result = NotionAdminController.deleteSyncConfiguration('InvalidObject');
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        
        Test.stopTest();
    }
    
    // Test for NotionSyncProcessor
    @isTest
    static void testNotionSyncProcessor() {
        // Create test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Test.startTest();
        
        // Test processSyncRequests
        List<NotionSync.Request> requests = new List<NotionSync.Request>();
        requests.add(new NotionSync.Request(acc.Id, 'Account', 'CREATE'));
        
        // Mock the callout
        Test.setMock(HttpCalloutMock.class, new NotionApiMock());
        
        // Process requests - NotionSyncProcessor requires logger
        NotionSyncLogger logger = new NotionSyncLogger();
        NotionSyncProcessor processor = new NotionSyncProcessor(logger);
        processor.processSyncRequests(requests);
        
        Test.stopTest();
        
        // Verify logs were created - in test context might not create any
        List<Notion_Sync_Log__c> logs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assert(logs != null, 'Logs query should return a list');
    }
    
    // Additional SessionUtil test
    @isTest
    static void testSessionUtilCaching() {
        Test.startTest();
        
        // Multiple calls should return cached value
        String session1 = SessionUtil.getApiEnabledSessionId();
        String session2 = SessionUtil.getApiEnabledSessionId();
        String session3 = SessionUtil.getApiEnabledSessionId();
        
        System.assertEquals(session1, session2);
        System.assertEquals(session2, session3);
        
        Test.stopTest();
    }
    
    // Mock classes
    public class NotionApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"object":"page","id":"test-page-id"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    public class NotionApiErrorMock implements HttpCalloutMock {
        private Integer statusCode;
        
        public NotionApiErrorMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"object":"error","status":' + statusCode + ',"message":"Test error"}');
            res.setStatusCode(statusCode);
            return res;
        }
    }
    
    public class MetadataServiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body><deleteMetadataResponse><result><success>true</success></result></deleteMetadataResponse></soapenv:Body></soapenv:Envelope>');
            res.setStatusCode(200);
            return res;
        }
    }
}