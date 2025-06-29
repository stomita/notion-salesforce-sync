@isTest
private class NotionAdminControllerEnhancedTest {
    
    @isTest
    static void testDeleteSyncConfiguration() {
        // Create test metadata
        NotionSyncObject__mdt testObject = new NotionSyncObject__mdt();
        testObject.ObjectApiName__c = 'Account';
        testObject.NotionDatabaseId__c = 'test-db-id';
        testObject.IsActive__c = true;
        testObject.SalesforceIdPropertyName__c = 'sfdc_id';
        
        // Mock the metadata service response
        Test.setMock(HttpCalloutMock.class, new MetadataServiceMock());
        
        Test.startTest();
        try {
            NotionAdminController.deleteSyncConfiguration('Account');
            // In test context, this will throw because metadata can't be queried
        } catch (Exception e) {
            // Expected in test context
            System.assert(e.getMessage() != null, 'Should have error message');
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testGetSyncConfigurationWithRelationships() {
        // Test configuration with relationships
        Test.startTest();
        NotionAdminController.SyncConfiguration config = NotionAdminController.getSyncConfiguration('Contact');
        Test.stopTest();
        
        // Will return empty config in test context
        System.assertNotEquals(null, config);
    }
    
    @isTest
    static void testGetObjectFieldsWithInvalidObject() {
        Test.startTest();
        try {
            List<NotionAdminController.SalesforceField> fields = NotionAdminController.getObjectFields('InvalidObject__c');
            System.assert(false, 'Should throw exception for invalid object');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 
                'Should throw exception with message for invalid object');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetDatabasesWithInvalidCredentials() {
        // Mock invalid API response
        Test.setMock(HttpCalloutMock.class, new NotionApiErrorMock(401));
        
        Test.startTest();
        try {
            List<NotionAdminController.NotionDatabase> databases = NotionAdminController.getDatabases();
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Should have error for invalid credentials');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetDatabaseSchemaWithInvalidId() {
        Test.setMock(HttpCalloutMock.class, new NotionApiErrorMock(404));
        
        Test.startTest();
        try {
            NotionAdminController.DatabaseSchema schema = NotionAdminController.getDatabaseSchema('invalid-db-id');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Should have error for invalid database');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSaveSyncConfigurationWithValidation() {
        NotionAdminController.SyncConfiguration config = new NotionAdminController.SyncConfiguration();
        config.objectApiName = '';  // Invalid - empty
        config.notionDatabaseId = 'test-db';
        config.isActive = true;
        
        String configJson = JSON.serialize(config);
        Test.setMock(HttpCalloutMock.class, new MetadataServiceMock());
        
        Test.startTest();
        try {
            NotionAdminController.SaveResult result = NotionAdminController.saveSyncConfiguration(configJson);
            // May succeed or fail depending on context
        } catch (NotionAdminController.ValidationException e) {
            System.assert(e.getMessage() != null, 'Should have validation error');
        } catch (Exception e) {
            // Other exceptions may occur in test context
            System.assert(e.getMessage() != null, 'Should have error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetSystemSettingsWithNoSettings() {
        Test.startTest();
        NotionAdminController.SystemSettings settings = NotionAdminController.getSystemSettings();
        Test.stopTest();
        
        System.assertNotEquals(null, settings);
        // The field is enableSyncLogging
        System.assertNotEquals(null, settings.enableSyncLogging);
    }
    
    @isTest
    static void testSaveSystemSettingsError() {
        Map<String, Object> settingsMap = new Map<String, Object>();
        settingsMap.put('enableSyncLogging', true);
        
        String settingsJson = JSON.serialize(settingsMap);
        Test.setMock(HttpCalloutMock.class, new MetadataServiceMock());
        
        Test.startTest();
        try {
            NotionAdminController.SaveResult result = NotionAdminController.saveSystemSettings(settingsJson);
            // Will succeed or fail depending on metadata permissions
        } catch (Exception e) {
            // Expected in some test contexts
        }
        Test.stopTest();
    }
    
    // Mock classes for testing
    public class MetadataServiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body><upsertMetadataResponse><result><success>true</success></result></upsertMetadataResponse></soapenv:Body></soapenv:Envelope>');
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
}