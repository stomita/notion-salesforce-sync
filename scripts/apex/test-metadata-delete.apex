// Test the MetadataService delete functionality
// Note: This test bypasses the permission check since it can't be executed outside of Aura context

System.debug('=== TESTING METADATA SERVICE DELETE ===');

// First, check current configurations
System.debug('\n1. Current configurations:');
List<NotionSyncObject__mdt> configs = [
    SELECT ObjectApiName__c, DeveloperName
    FROM NotionSyncObject__mdt
    ORDER BY ObjectApiName__c
];

for (NotionSyncObject__mdt config : configs) {
    System.debug('   - ' + config.ObjectApiName__c + ' (DeveloperName: ' + config.DeveloperName + ')');
}

// Test the delete functionality directly
System.debug('\n2. Testing delete functionality for Test_Child_Object__c:');
try {
    // Find the sync object configuration
    List<NotionSyncObject__mdt> syncObjects = [
        SELECT DeveloperName
        FROM NotionSyncObject__mdt
        WHERE ObjectApiName__c = 'Test_Child_Object__c'
        LIMIT 1
    ];
    
    if (syncObjects.isEmpty()) {
        System.debug('No sync configuration found for Test_Child_Object__c');
    } else {
        String objectDeveloperName = syncObjects[0].DeveloperName;
        System.debug('Found configuration with DeveloperName: ' + objectDeveloperName);
        
        // Create MetadataService instance
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        
        // Set the endpoint URL for the current org
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        service.endpoint_x = orgUrl + '/services/Soap/m/61.0';
        
        System.debug('Service endpoint: ' + service.endpoint_x);
        System.debug('Session ID (first 15 chars): ' + UserInfo.getSessionId().substring(0, 15) + '...');
        
        // List of metadata to delete
        List<String> metadataToDelete = new List<String>();
        metadataToDelete.add('NotionSyncObject__mdt.' + objectDeveloperName);
        
        // Query field mappings
        List<NotionSyncField__mdt> fieldMappings = [
            SELECT DeveloperName
            FROM NotionSyncField__mdt
            WHERE NotionSyncObject__r.DeveloperName = :objectDeveloperName
        ];
        
        System.debug('Found ' + fieldMappings.size() + ' field mappings to delete');
        for (NotionSyncField__mdt field : fieldMappings) {
            metadataToDelete.add('NotionSyncField__mdt.' + field.DeveloperName);
        }
        
        // Query relationship mappings - need to split into two queries
        List<NotionRelation__mdt> parentRelations = [
            SELECT DeveloperName
            FROM NotionRelation__mdt
            WHERE ParentObject__r.DeveloperName = :objectDeveloperName
        ];
        
        List<NotionRelation__mdt> childRelations = [
            SELECT DeveloperName
            FROM NotionRelation__mdt
            WHERE ChildObject__r.DeveloperName = :objectDeveloperName
        ];
        
        // Combine the results
        List<NotionRelation__mdt> relations = new List<NotionRelation__mdt>();
        relations.addAll(parentRelations);
        relations.addAll(childRelations);
        
        System.debug('Found ' + relations.size() + ' relationship mappings to delete');
        for (NotionRelation__mdt relation : relations) {
            metadataToDelete.add('NotionRelation__mdt.' + relation.DeveloperName);
        }
        
        System.debug('\n3. Metadata to delete:');
        for (String metadata : metadataToDelete) {
            System.debug('   - ' + metadata);
        }
        
        // Perform the deletion
        System.debug('\n4. Calling MetadataService.deleteMetadata...');
        List<MetadataService.DeleteResult> deleteResults = 
            service.deleteMetadata('CustomMetadata', metadataToDelete);
        
        System.debug('\n5. Delete results:');
        for (Integer i = 0; i < deleteResults.size(); i++) {
            MetadataService.DeleteResult result = deleteResults[i];
            System.debug('   ' + metadataToDelete[i] + ':');
            System.debug('      Success: ' + result.success);
            if (!result.success && result.errors != null) {
                for (MetadataService.Error error : result.errors) {
                    System.debug('      Error: ' + error.message);
                }
            }
        }
    }
} catch (Exception e) {
    System.debug('Exception occurred: ' + e.getMessage());
    System.debug('Exception type: ' + e.getTypeName());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

System.debug('\n6. Verifying deletion (may take time to reflect):');
List<NotionSyncObject__mdt> remainingConfigs = [
    SELECT ObjectApiName__c, DeveloperName
    FROM NotionSyncObject__mdt
    ORDER BY ObjectApiName__c
];

System.debug('Remaining configurations:');
for (NotionSyncObject__mdt config : remainingConfigs) {
    System.debug('   - ' + config.ObjectApiName__c + ' (DeveloperName: ' + config.DeveloperName + ')');
}

System.debug('\n=== TEST COMPLETE ===');