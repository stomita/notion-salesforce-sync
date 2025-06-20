// Verify the deletion from our previous test
System.debug('=== Verifying Previous Deletion ===');

// Check if Test_Child_Object__c still exists
List<NotionSyncObject__mdt> testChildConfigs = [
    SELECT ObjectApiName__c, DeveloperName
    FROM NotionSyncObject__mdt
    WHERE ObjectApiName__c = 'Test_Child_Object__c'
];

if (testChildConfigs.isEmpty()) {
    System.debug('SUCCESS: Test_Child_Object__c configuration has been deleted!');
} else {
    System.debug('Test_Child_Object__c still exists with DeveloperName: ' + testChildConfigs[0].DeveloperName);
    
    // Check if its fields were deleted
    Integer fieldCount = [
        SELECT COUNT() 
        FROM NotionSyncField__mdt 
        WHERE NotionSyncObject__c = :testChildConfigs[0].Id
    ];
    
    Integer parentRelCount = [
        SELECT COUNT() 
        FROM NotionRelation__mdt 
        WHERE ParentObject__c = :testChildConfigs[0].Id
    ];
    
    Integer childRelCount = [
        SELECT COUNT() 
        FROM NotionRelation__mdt 
        WHERE ChildObject__c = :testChildConfigs[0].Id
    ];
    
    Integer relationCount = parentRelCount + childRelCount;
    
    System.debug('  Field mappings: ' + fieldCount);
    System.debug('  Relationship mappings: ' + relationCount);
    
    if (fieldCount == 0 && relationCount == 0) {
        System.debug('  Note: All child records have been deleted, parent can now be deleted.');
    }
}

System.debug('\nAll current configurations:');
List<NotionSyncObject__mdt> allConfigs = [
    SELECT ObjectApiName__c, DeveloperName
    FROM NotionSyncObject__mdt
    ORDER BY ObjectApiName__c
];

for (NotionSyncObject__mdt config : allConfigs) {
    System.debug('  - ' + config.ObjectApiName__c + ' (' + config.DeveloperName + ')');
}