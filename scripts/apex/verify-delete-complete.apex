// Verify the soft delete functionality is working correctly

System.debug('=== SOFT DELETE VERIFICATION ===');

// 1. Show all NotionSyncObject__mdt records with their IsDeleted status
System.debug('\n1. All custom metadata records:');
List<NotionSyncObject__mdt> allRecords = [
    SELECT DeveloperName, ObjectApiName__c, IsDeleted__c, IsActive__c
    FROM NotionSyncObject__mdt
    ORDER BY ObjectApiName__c
];

for (NotionSyncObject__mdt record : allRecords) {
    String status = record.IsDeleted__c ? 'DELETED' : 'ACTIVE';
    System.debug('   ' + record.ObjectApiName__c + ' - ' + status + 
                 ' (IsActive: ' + record.IsActive__c + ')');
}

// 2. Show what the UI queries (filtered by IsDeleted__c = false)
System.debug('\n2. Records visible in UI (IsDeleted__c = false):');
List<NotionSyncObject__mdt> visibleRecords = [
    SELECT ObjectApiName__c, IsActive__c
    FROM NotionSyncObject__mdt
    WHERE IsDeleted__c = false
    ORDER BY ObjectApiName__c
];

for (NotionSyncObject__mdt record : visibleRecords) {
    System.debug('   ' + record.ObjectApiName__c + ' (IsActive: ' + record.IsActive__c + ')');
}

// 3. Verify Test_Parent_Object__c is properly soft-deleted
System.debug('\n3. Test_Parent_Object__c verification:');
List<NotionSyncObject__mdt> testParent = [
    SELECT DeveloperName, IsDeleted__c, IsActive__c
    FROM NotionSyncObject__mdt
    WHERE ObjectApiName__c = 'Test_Parent_Object__c'
];

if (!testParent.isEmpty()) {
    NotionSyncObject__mdt tp = testParent[0];
    System.debug('   Found: ' + tp.DeveloperName);
    System.debug('   IsDeleted__c: ' + tp.IsDeleted__c);
    System.debug('   IsActive__c: ' + tp.IsActive__c);
    
    if (tp.IsDeleted__c == true && tp.IsActive__c == false) {
        System.debug('\n✅ SUCCESS: Test_Parent_Object__c is properly soft-deleted');
    } else {
        System.debug('\n❌ FAILURE: Test_Parent_Object__c is not properly soft-deleted');
    }
} else {
    System.debug('   Not found in metadata');
}

// 4. Summary
System.debug('\n=== SUMMARY ===');
System.debug('Total sync configurations: ' + allRecords.size());
System.debug('Visible in UI: ' + visibleRecords.size());
System.debug('Soft-deleted: ' + (allRecords.size() - visibleRecords.size()));