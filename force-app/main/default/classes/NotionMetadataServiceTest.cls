@isTest
private class NotionMetadataServiceTest {
    
    // Inner mock class for WebServiceMock
    private class MetadataServiceMock implements WebServiceMock {
        private Boolean shouldSucceed;
        
        public MetadataServiceMock(Boolean shouldSucceed) {
            this.shouldSucceed = shouldSucceed;
        }
        
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType
        ) {
            // Create mock response based on the request type
            if (requestName == 'upsertMetadata') {
                MetadataService.upsertMetadataResponse_element responseElement = 
                    new MetadataService.upsertMetadataResponse_element();
                
                // Create successful result
                MetadataService.UpsertResult result = new MetadataService.UpsertResult();
                result.success = shouldSucceed;
                result.fullName = 'TestMetadata';
                
                if (!shouldSucceed) {
                    result.errors = new List<MetadataService.Error>();
                    MetadataService.Error error = new MetadataService.Error();
                    error.message = 'Mock error message';
                    error.statusCode = 'INVALID_STATUS';
                    result.errors.add(error);
                }
                
                responseElement.result = new List<MetadataService.UpsertResult>{result};
                response.put('response_x', responseElement);
            } else if (requestName == 'deleteMetadata') {
                MetadataService.deleteMetadataResponse_element responseElement = 
                    new MetadataService.deleteMetadataResponse_element();
                
                // Create successful delete result
                MetadataService.DeleteResult result = new MetadataService.DeleteResult();
                result.success = true;
                result.fullName = 'TestMetadata';
                
                responseElement.result = new List<MetadataService.DeleteResult>{result};
                response.put('response_x', responseElement);
            }
        }
    }
    
    @isTest
    static void testSaveSyncConfiguration() {
        // Set up the web service mock
        Test.setMock(WebServiceMock.class, new MetadataServiceMock(true));
        
        // Create test configuration
        NotionAdminController.SyncConfiguration config = new NotionAdminController.SyncConfiguration();
        config.objectApiName = 'Account';
        config.notionDatabaseId = 'test-db-id';
        config.isActive = true;
        config.salesforceIdPropertyName = 'Salesforce_ID';
        
        // Add field mappings
        config.fieldMappings = new List<NotionAdminController.FieldMapping>();
        NotionAdminController.FieldMapping fieldMapping = new NotionAdminController.FieldMapping();
        fieldMapping.salesforceFieldApiName = 'Name';
        fieldMapping.notionPropertyName = 'Name';
        fieldMapping.notionPropertyType = 'title';
        fieldMapping.isBodyContent = false;
        config.fieldMappings.add(fieldMapping);
        
        // Add relationship mappings
        config.relationshipMappings = new List<NotionAdminController.RelationshipMapping>();
        NotionAdminController.RelationshipMapping relMapping = new NotionAdminController.RelationshipMapping();
        relMapping.parentObject = 'Contact';
        relMapping.salesforceRelationshipField = 'ParentId';
        relMapping.notionRelationPropertyName = 'Parent';
        config.relationshipMappings.add(relMapping);
        
        Test.startTest();
        // With mock in place, this should succeed
        NotionMetadataService.saveSyncConfiguration(config);
        Test.stopTest();
        
        // If we get here, the mock worked correctly
        System.assert(true, 'Method completed successfully with mock');
    }
    
    @isTest
    static void testDeleteObjectConfiguration() {
        // Set up the web service mock
        Test.setMock(WebServiceMock.class, new MetadataServiceMock(true));
        
        // Note: We cannot insert custom metadata records in test context
        // The method will fail when trying to query for the metadata
        Test.startTest();
        try {
            NotionMetadataService.deleteObjectConfiguration('TestObject');
            // If we get here in a test, it might mean no metadata exists
            System.assert(false, 'Should have thrown exception for missing metadata');
        } catch (System.CalloutException e) {
            // Expected - No sync configuration found (thrown at line 188)
            System.assert(e.getMessage().contains('No sync configuration found'), 
                'Expected CalloutException for missing metadata but got: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSaveSyncConfigurationWithError() {
        // Set up the web service mock to return failure
        Test.setMock(WebServiceMock.class, new MetadataServiceMock(false));
        
        // Create test configuration
        NotionAdminController.SyncConfiguration config = new NotionAdminController.SyncConfiguration();
        config.objectApiName = 'Account';
        config.notionDatabaseId = 'test-db-id';
        config.isActive = true;
        config.salesforceIdPropertyName = 'Salesforce_ID';
        
        Test.startTest();
        try {
            NotionMetadataService.saveSyncConfiguration(config);
            System.assert(false, 'Should have thrown exception for failed metadata save');
        } catch (System.CalloutException e) {
            // Expected - metadata save failed
            System.assert(e.getMessage().contains('Failed to save metadata'), 
                'Expected CalloutException for failed save but got: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSanitizeDeveloperName() {
        // Test various input scenarios
        System.assertEquals('Account', NotionMetadataService.sanitizeDeveloperName('Account'));
        System.assertEquals('Test_Object', NotionMetadataService.sanitizeDeveloperName('Test Object'));
        System.assertEquals('X123Test', NotionMetadataService.sanitizeDeveloperName('123Test'));
        System.assertEquals('Special_chars_removed', NotionMetadataService.sanitizeDeveloperName('Special@#$chars%^&removed'));
        
        // Test double underscore handling
        System.assertEquals('Test_Parent_Object_c', NotionMetadataService.sanitizeDeveloperName('Test_Parent_Object__c'));
        System.assertEquals('Field_c', NotionMetadataService.sanitizeDeveloperName('Field__c'));
        
        // Test trailing underscore removal
        System.assertEquals('Test_Field', NotionMetadataService.sanitizeDeveloperName('Test_Field_'));
        System.assertEquals('Test_Field', NotionMetadataService.sanitizeDeveloperName('Test_Field___'));
        
        // Test truncation
        String longName = 'ThisIsAVeryLongNameThatExceedsTheMaximumAllowedLength';
        String sanitized = NotionMetadataService.sanitizeDeveloperName(longName);
        System.assert(sanitized.length() <= 40, 'Name should be truncated to 40 chars');
        System.assert(!sanitized.endsWith('_'), 'Name should not end with underscore');
    }
    
}