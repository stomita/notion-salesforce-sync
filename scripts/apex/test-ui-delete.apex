// Test the UI delete functionality by calling the controller method
// This simulates what happens when the Delete button is clicked in the UI

System.debug('=== Testing UI Delete Functionality ===');

// Test deleting Test_Parent_Object__c which has field mappings
System.debug('\n1. Attempting to delete Test_Parent_Object__c (has 5 field mappings):');
try {
    NotionAdminController.SaveResult result = 
        NotionAdminController.deleteSyncConfiguration('Test_Parent_Object__c');
    
    System.debug('Result:');
    System.debug('  Success: ' + result.success);
    System.debug('  Message: ' + result.message);
    if (result.errors != null) {
        for (String error : result.errors) {
            System.debug('  Error: ' + error);
        }
    }
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
}

// Wait a moment
System.debug('\n2. Waiting for metadata deployment...');

// Check remaining configurations
System.debug('\n3. Checking remaining configurations:');
List<NotionSyncObject__mdt> remainingConfigs = [
    SELECT ObjectApiName__c, DeveloperName
    FROM NotionSyncObject__mdt
    ORDER BY ObjectApiName__c
];

for (NotionSyncObject__mdt config : remainingConfigs) {
    System.debug('  - ' + config.ObjectApiName__c);
}

System.debug('\n=== Test Complete ===');
System.debug('Note: Metadata changes may take 10-30 seconds to fully reflect in the org.');