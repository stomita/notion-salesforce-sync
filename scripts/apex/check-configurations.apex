// Check current sync configurations
System.debug('Current Sync Configurations:');
List<NotionSyncObject__mdt> configs = [
    SELECT Id, ObjectApiName__c, DeveloperName
    FROM NotionSyncObject__mdt
    ORDER BY ObjectApiName__c
];

for (NotionSyncObject__mdt config : configs) {
    // Count fields
    Integer fieldCount = [
        SELECT COUNT() 
        FROM NotionSyncField__mdt 
        WHERE NotionSyncObject__c = :config.Id
    ];
    
    // Count parent relations
    Integer parentRelCount = [
        SELECT COUNT() 
        FROM NotionRelation__mdt 
        WHERE ParentObject__c = :config.Id
    ];
    
    // Count child relations
    Integer childRelCount = [
        SELECT COUNT() 
        FROM NotionRelation__mdt 
        WHERE ChildObject__c = :config.Id
    ];
    
    System.debug('- ' + config.ObjectApiName__c + ' (' + config.DeveloperName + ')');
    System.debug('  Fields: ' + fieldCount);
    System.debug('  Parent Relations: ' + parentRelCount);
    System.debug('  Child Relations: ' + childRelCount);
}