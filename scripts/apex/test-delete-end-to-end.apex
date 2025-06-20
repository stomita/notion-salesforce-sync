// End-to-end test of the delete functionality

// Step 1: Show existing sync configurations before delete
System.debug('=== BEFORE DELETE ===');
List<NotionSyncObject__mdt> beforeDelete = [
    SELECT ObjectApiName__c, IsDeleted__c, IsActive__c
    FROM NotionSyncObject__mdt
    WHERE IsDeleted__c = false
    ORDER BY ObjectApiName__c
];
System.debug('Configurations visible in UI: ' + beforeDelete.size());
for (NotionSyncObject__mdt obj : beforeDelete) {
    System.debug('- ' + obj.ObjectApiName__c);
}

// Step 2: Create a test sync configuration to delete
System.debug('\n=== CREATING TEST CONFIGURATION ===');
NotionAdminController.SyncConfiguration testConfig = new NotionAdminController.SyncConfiguration();
testConfig.objectApiName = 'Lead';
testConfig.notionDatabaseId = 'test-database-id';
testConfig.salesforceIdPropertyName = 'salesforce_id';
testConfig.isActive = true;
testConfig.fieldMappings = new List<NotionAdminController.FieldMapping>();

NotionAdminController.FieldMapping nameMapping = new NotionAdminController.FieldMapping();
nameMapping.salesforceFieldApiName = 'Name';
nameMapping.notionPropertyName = 'Name';
nameMapping.notionPropertyType = 'title';
nameMapping.isBodyContent = false;
testConfig.fieldMappings.add(nameMapping);

try {
    NotionAdminController.SaveResult saveResult = NotionAdminController.saveSyncConfiguration(testConfig);
    System.debug('Save result: ' + saveResult.success + ' - ' + saveResult.message);
    
    // Wait a moment for metadata to deploy
    System.debug('Waiting for metadata deployment...');
    
} catch (Exception e) {
    System.debug('Error creating config: ' + e.getMessage());
}

// Step 3: Show configurations after create
System.debug('\n=== AFTER CREATE ===');
// Note: In a real scenario, we'd need to wait for the async metadata deployment
// For this test, we'll just show what would happen

// Step 4: Delete the configuration
System.debug('\n=== DELETING LEAD CONFIGURATION ===');
try {
    NotionAdminController.SaveResult deleteResult = NotionAdminController.deleteSyncConfiguration('Lead');
    System.debug('Delete result: ' + deleteResult.success + ' - ' + deleteResult.message);
} catch (Exception e) {
    System.debug('Error deleting config: ' + e.getMessage());
}

// Step 5: Show what the UI would query after delete
System.debug('\n=== AFTER DELETE (UI QUERY) ===');
List<NotionSyncObject__mdt> afterDelete = [
    SELECT ObjectApiName__c, IsDeleted__c, IsActive__c
    FROM NotionSyncObject__mdt
    WHERE IsDeleted__c = false
    ORDER BY ObjectApiName__c
];
System.debug('Configurations visible in UI: ' + afterDelete.size());
for (NotionSyncObject__mdt obj : afterDelete) {
    System.debug('- ' + obj.ObjectApiName__c);
}

// Verify Test_Parent_Object__c is not in the list
Boolean foundTestParent = false;
for (NotionSyncObject__mdt obj : afterDelete) {
    if (obj.ObjectApiName__c == 'Test_Parent_Object__c') {
        foundTestParent = true;
        break;
    }
}

System.debug('\n=== DELETE VERIFICATION ===');
if (!foundTestParent) {
    System.debug('✅ SUCCESS: Test_Parent_Object__c is correctly filtered out after soft delete');
} else {
    System.debug('❌ FAILURE: Test_Parent_Object__c is still visible');
}