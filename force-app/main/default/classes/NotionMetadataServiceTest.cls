@isTest
private class NotionMetadataServiceTest {
    
    @isTest
    static void testSaveSyncConfiguration() {
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
        relMapping.salesforceRelationshipField = 'ParentId';
        relMapping.notionRelationPropertyName = 'Parent';
        relMapping.isParent = true;
        config.relationshipMappings.add(relMapping);
        
        Test.startTest();
        // This will create a deployment but won't actually deploy in test context
        NotionMetadataService.saveSyncConfiguration(config);
        Test.stopTest();
        
        // Verify the method completes without error
        System.assert(true, 'Method should complete without error');
    }
    
    @isTest
    static void testDeleteObjectConfiguration() {
        Test.startTest();
        NotionMetadataService.deleteObjectConfiguration('Account');
        Test.stopTest();
        
        // Verify the method completes without error
        System.assert(true, 'Method should complete without error');
    }
    
    @isTest
    static void testSanitizeDeveloperName() {
        // Test various input scenarios
        System.assertEquals('Account', NotionMetadataService.sanitizeDeveloperName('Account'));
        System.assertEquals('Test_Object', NotionMetadataService.sanitizeDeveloperName('Test Object'));
        System.assertEquals('X123Test', NotionMetadataService.sanitizeDeveloperName('123Test'));
        System.assertEquals('Special_chars_removed', NotionMetadataService.sanitizeDeveloperName('Special@#$chars%^&removed'));
        
        // Test truncation
        String longName = 'ThisIsAVeryLongNameThatExceedsTheMaximumAllowedLength';
        String sanitized = NotionMetadataService.sanitizeDeveloperName(longName);
        System.assert(sanitized.length() <= 40, 'Name should be truncated to 40 chars');
    }
    
    @isTest
    static void testGetNotionDatabases() {
        Test.startTest();
        List<NotionDatabase__mdt> databases = NotionMetadataService.getNotionDatabases();
        Test.stopTest();
        
        // In test context, this will return empty list
        System.assertNotEquals(null, databases, 'Should return list');
    }
    
    @isTest
    static void testSaveNotionDatabase() {
        Test.startTest();
        NotionMetadataService.saveNotionDatabase('test-db-id', 'Test Database', 'test-workspace-id');
        Test.stopTest();
        
        // Verify the method completes without error
        System.assert(true, 'Method should complete without error');
    }
    
    @isTest
    static void testMetadataDeployCallback() {
        // Test the callback handler
        NotionMetadataService.MetadataDeployCallback callback = new NotionMetadataService.MetadataDeployCallback();
        
        // Create mock deploy result
        Metadata.DeployResult result = new Metadata.DeployResult();
        result.status = Metadata.DeployStatus.Succeeded;
        
        // Create mock context
        Metadata.DeployCallbackContext context = null;
        
        Test.startTest();
        callback.handleResult(result, context);
        Test.stopTest();
        
        // Verify it handles the result without error
        System.assert(true, 'Callback should handle result without error');
    }
}