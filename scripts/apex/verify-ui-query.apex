// This script simulates what the UI queries when loading configurations
// It should match the query in NotionAdminController.getAllSyncConfigurations

System.debug('Simulating UI query for sync configurations...');

// Query from NotionAdminController
List<NotionSyncObject__mdt> syncObjects = [
    SELECT DeveloperName, ObjectApiName__c, NotionDatabaseId__c, IsActive__c, 
           SalesforceIdPropertyName__c
    FROM NotionSyncObject__mdt
    WHERE IsDeleted__c = false
    ORDER BY ObjectApiName__c
];

System.debug('Number of configurations visible in UI: ' + syncObjects.size());
for (NotionSyncObject__mdt obj : syncObjects) {
    System.debug('- ' + obj.ObjectApiName__c + ' (Active: ' + obj.IsActive__c + ')');
}

// Check if Test_Parent_Object__c is in the results
Boolean foundTestParent = false;
for (NotionSyncObject__mdt obj : syncObjects) {
    if (obj.ObjectApiName__c == 'Test_Parent_Object__c') {
        foundTestParent = true;
        break;
    }
}

if (!foundTestParent) {
    System.debug('\n✅ SUCCESS: Test_Parent_Object__c is NOT in the query results (correctly filtered out)');
} else {
    System.debug('\n❌ FAILURE: Test_Parent_Object__c is still in the query results');
}