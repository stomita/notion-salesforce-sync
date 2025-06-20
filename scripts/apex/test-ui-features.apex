// Script to demonstrate the new UI features for managing metadata

System.debug('=== NEW UI FEATURES FOR METADATA MANAGEMENT ===');
System.debug('');
System.debug('1. "Manage in Setup" button in header:');
System.debug('   - Opens Custom Metadata Types page in Setup');
System.debug('   - URL: /lightning/setup/CustomMetadata/home');
System.debug('');
System.debug('2. "Manage" button for each configuration:');
System.debug('   - Opens the specific metadata record in Setup');
System.debug('   - Allows viewing/editing/deleting the record directly');
System.debug('');
System.debug('3. Delete options:');
System.debug('   a) Soft delete via "Delete" button (marks as deleted)');
System.debug('   b) Hard delete via "Manage" → Delete in Setup');
System.debug('');
System.debug('4. Current configurations:');

List<NotionSyncObject__mdt> configs = [
    SELECT Id, DeveloperName, ObjectApiName__c, IsActive__c, IsDeleted__c
    FROM NotionSyncObject__mdt
    WHERE IsDeleted__c = false
    ORDER BY ObjectApiName__c
];

for (NotionSyncObject__mdt config : configs) {
    System.debug('   - ' + config.ObjectApiName__c + 
                 ' (ID: ' + config.Id + ')' +
                 ' [Active: ' + config.IsActive__c + ']');
}

System.debug('');
System.debug('To test:');
System.debug('1. Click "Manage in Setup" to see all metadata types');
System.debug('2. Click "Manage" on any row to edit that specific record');
System.debug('3. In Setup, you can perform hard delete using the Delete button');