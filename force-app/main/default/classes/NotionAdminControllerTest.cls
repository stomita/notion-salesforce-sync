@isTest
private class NotionAdminControllerTest {
    
    @TestSetup
    static void makeData() {
        // Create test metadata records
        // Note: Custom metadata cannot be created in tests, so we'll mock the responses
    }
    
    private static User createAdminUser() {
        // Create a user with System Administrator profile
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User u = new User(
            Alias = 'testadm',
            Email = 'testadmin@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testadmin' + DateTime.now().getTime() + '@test.com'
        );
        insert u;
        
        // Note: Custom permissions cannot be assigned in test context
        // The permission check will need to be mocked or bypassed in tests
        return u;
    }
    
    @isTest
    static void testGetDatabases() {
        // Mock the Notion API response
        Test.setMock(HttpCalloutMock.class, new NotionApiMockSuccess());
        
        Test.startTest();
        List<NotionAdminController.NotionDatabase> databases = NotionAdminController.getDatabases();
        Test.stopTest();
        
        System.assertNotEquals(null, databases, 'Databases should not be null');
        System.assert(databases.size() > 0, 'Should return at least one database');
        System.assertNotEquals(null, databases[0].id, 'Database ID should not be null');
        System.assertNotEquals(null, databases[0].title, 'Database title should not be null');
    }
    
    @isTest
    static void testGetDatabasesError() {
        // Mock API error
        Test.setMock(HttpCalloutMock.class, new NotionApiMockError());
        
        Test.startTest();
        try {
            NotionAdminController.getDatabases();
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to fetch databases'), 'Should contain error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetDatabaseSchema() {
        Test.setMock(HttpCalloutMock.class, new NotionApiMockSuccess());
        
        Test.startTest();
        NotionAdminController.DatabaseSchema schema = NotionAdminController.getDatabaseSchema('test-db-id');
        Test.stopTest();
        
        System.assertNotEquals(null, schema, 'Schema should not be null');
        System.assertEquals('test-db-id', schema.databaseId, 'Database ID should match');
        System.assert(schema.properties.size() > 0, 'Should have properties');
    }
    
    @isTest
    static void testGetSalesforceObjects() {
        Test.startTest();
        List<NotionAdminController.SalesforceObject> objects = NotionAdminController.getSalesforceObjects();
        Test.stopTest();
        
        System.assertNotEquals(null, objects, 'Objects should not be null');
        System.assert(objects.size() > 0, 'Should return at least one object');
        
        // Verify Account is in the list
        Boolean foundAccount = false;
        for (NotionAdminController.SalesforceObject obj : objects) {
            if (obj.apiName == 'Account') {
                foundAccount = true;
                break;
            }
        }
        System.assert(foundAccount, 'Should include Account object');
    }
    
    @isTest
    static void testGetObjectFields() {
        Test.startTest();
        List<NotionAdminController.SalesforceField> fields = NotionAdminController.getObjectFields('Account');
        Test.stopTest();
        
        System.assertNotEquals(null, fields, 'Fields should not be null');
        System.assert(fields.size() > 0, 'Should return fields');
        
        // Verify standard fields exist
        Boolean foundName = false;
        for (NotionAdminController.SalesforceField field : fields) {
            if (field.apiName == 'Name') {
                foundName = true;
                System.assertEquals('STRING', field.type, 'Name field should be STRING type');
                break;
            }
        }
        System.assert(foundName, 'Should include Name field');
    }
    
    @isTest
    static void testGetSyncConfiguration() {
        Test.startTest();
        NotionAdminController.SyncConfiguration config = NotionAdminController.getSyncConfiguration('Account');
        Test.stopTest();
        
        // Since we can't create custom metadata in tests, config will be empty
        System.assertNotEquals(null, config, 'Config should not be null');
    }
    
    @isTest
    static void testSaveSyncConfiguration() {
        NotionAdminController.SyncConfiguration config = new NotionAdminController.SyncConfiguration();
        config.objectApiName = 'Account';
        config.notionDatabaseId = 'test-db-id';
        config.isActive = true;
        config.salesforceIdPropertyName = 'Salesforce_ID';
        config.fieldMappings = new List<NotionAdminController.FieldMapping>();
        
        NotionAdminController.FieldMapping mapping = new NotionAdminController.FieldMapping();
        mapping.salesforceFieldApiName = 'Name';
        mapping.notionPropertyName = 'Name';
        mapping.notionPropertyType = 'title';
        mapping.isBodyContent = false;
        config.fieldMappings.add(mapping);
        
        Test.startTest();
        NotionAdminController.SaveResult result = NotionAdminController.saveSyncConfiguration(config);
        Test.stopTest();
        
        // Can't actually save metadata in tests, but verify the method runs
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testValidationException() {
        NotionAdminController.SyncConfiguration config = new NotionAdminController.SyncConfiguration();
        // Missing required fields
        
        Test.startTest();
        NotionAdminController.SaveResult result = NotionAdminController.saveSyncConfiguration(config);
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Should fail validation');
        System.assert(result.errors.size() > 0, 'Should have error messages');
    }
    
    @isTest
    static void testTestConnection() {
        Test.setMock(HttpCalloutMock.class, new NotionApiMockSuccess());
        
        Test.startTest();
        NotionAdminController.TestConnectionResult result = NotionAdminController.testConnection('test-db-id');
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Connection should succeed');
        System.assertNotEquals(null, result.databaseName, 'Should have database name');
    }
    
    // Mock classes for HTTP callouts
    private class NotionApiMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('/search')) {
                res.setBody('{"results":[{"id":"test-db-id","title":[{"plain_text":"Test Database"}],"icon":{"type":"emoji","emoji":"📊"}}]}');
            } else if (req.getEndpoint().contains('/databases/')) {
                res.setBody('{"id":"test-db-id","title":[{"plain_text":"Test Database"}],"properties":{"Name":{"id":"title","type":"title"},"Status":{"id":"status","type":"select"}}}');
            }
            
            return res;
        }
    }
    
    private class NotionApiMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"message":"Bad Request","code":"validation_error"}');
            return res;
        }
    }
}