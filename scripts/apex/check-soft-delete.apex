// Check if the IsDeleted field exists and what values it has
List<NotionSyncObject__mdt> allRecords = [
    SELECT DeveloperName, ObjectApiName__c, IsDeleted__c 
    FROM NotionSyncObject__mdt
];

System.debug('All NotionSyncObject__mdt records:');
for (NotionSyncObject__mdt rec : allRecords) {
    System.debug('DeveloperName: ' + rec.DeveloperName + 
                ', ObjectApiName__c: ' + rec.ObjectApiName__c + 
                ', IsDeleted__c: ' + rec.IsDeleted__c);
}

// Check for Test_Parent_Sync specifically
List<NotionSyncObject__mdt> testParent = [
    SELECT DeveloperName, ObjectApiName__c, IsDeleted__c, IsActive__c
    FROM NotionSyncObject__mdt
    WHERE DeveloperName = 'Test_Parent_Sync'
];

if (!testParent.isEmpty()) {
    System.debug('\nTest_Parent_Sync details:');
    System.debug('IsDeleted__c: ' + testParent[0].IsDeleted__c);
    System.debug('IsActive__c: ' + testParent[0].IsActive__c);
}