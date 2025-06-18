// Test 6 - Check: Verify batch processing results
System.debug('=== Test 6 Check: Verifying batch processing results ===');

// Get the batch test records
List<Account> batchAccounts = [
    SELECT Id, Name 
    FROM Account 
    WHERE Name LIKE 'Batch Test Account%'
    ORDER BY Name
];

List<Contact> batchContacts = [
    SELECT Id, LastName, AccountId
    FROM Contact
    WHERE LastName LIKE 'Batch Test Contact%'
    ORDER BY LastName
];

System.debug('Found ' + batchAccounts.size() + ' batch accounts');
System.debug('Found ' + batchContacts.size() + ' batch contacts');

// Get record IDs for query
Set<Id> accountIds = new Set<Id>();
for (Account acc : batchAccounts) {
    accountIds.add(acc.Id);
}

Set<Id> contactIds = new Set<Id>();
for (Contact con : batchContacts) {
    contactIds.add(con.Id);
}

// Check sync logs for batch processing indicators
List<Notion_Sync_Log__c> batchLogs = [
    SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, Status__c, 
           Notion_Page_Id__c, Error_Message__c, CreatedDate
    FROM Notion_Sync_Log__c
    WHERE ((Object_Type__c = 'Account' AND Record_Id__c IN :accountIds)
       OR (Object_Type__c = 'Contact' AND Record_Id__c IN :contactIds))
    AND Operation_Type__c = 'CREATE'
    ORDER BY CreatedDate DESC
];

System.debug('Found ' + batchLogs.size() + ' sync logs for batch records');

// Analyze batch processing patterns
Map<String, Integer> successByType = new Map<String, Integer>{
    'Account' => 0,
    'Contact' => 0
};
Map<String, Integer> failureByType = new Map<String, Integer>{
    'Account' => 0,
    'Contact' => 0
};
Set<String> syncedAccountIds = new Set<String>();
Set<String> syncedContactIds = new Set<String>();

for (Notion_Sync_Log__c log : batchLogs) {
    if (log.Status__c == 'Success') {
        successByType.put(log.Object_Type__c, successByType.get(log.Object_Type__c) + 1);
        if (log.Object_Type__c == 'Account') {
            syncedAccountIds.add(log.Record_Id__c);
        } else if (log.Object_Type__c == 'Contact') {
            syncedContactIds.add(log.Record_Id__c);
        }
    } else {
        failureByType.put(log.Object_Type__c, failureByType.get(log.Object_Type__c) + 1);
    }
}

System.debug('\n--- Batch Processing Results ---');
System.debug('Accounts synced successfully: ' + successByType.get('Account') + '/' + batchAccounts.size());
System.debug('Contacts synced successfully: ' + successByType.get('Contact') + '/' + batchContacts.size());
System.debug('Account failures: ' + failureByType.get('Account'));
System.debug('Contact failures: ' + failureByType.get('Contact'));

// Check for batch processing logs (skip enhanced fields if not available)
List<Notion_Sync_Log__c> batchProcessLogs = [
    SELECT Id, Object_Type__c, Operation_Type__c, Status__c, Error_Message__c
    FROM Notion_Sync_Log__c
    WHERE Object_Type__c = 'BatchProcess'
    AND Operation_Type__c = 'BATCH'
    ORDER BY CreatedDate DESC
    LIMIT 10
];

if (!batchProcessLogs.isEmpty()) {
    System.debug('\n--- Batch Process Metrics ---');
    System.debug('Found ' + batchProcessLogs.size() + ' batch process log entries');
    
    for (Notion_Sync_Log__c batchLog : batchProcessLogs) {
        System.debug('Batch Status: ' + batchLog.Status__c);
    }
}

// Verify actual Notion pages for a sample of records
System.debug('\n--- Verifying Sample Notion Pages ---');
Integer sampleSize = 5;
Integer verified = 0;

for (Integer i = 0; i < Math.min(sampleSize, syncedAccountIds.size()); i++) {
    List<Notion_Sync_Log__c> accountLogs = [
        SELECT Notion_Page_Id__c 
        FROM Notion_Sync_Log__c 
        WHERE Record_Id__c IN :syncedAccountIds
        AND Status__c = 'Success'
        AND Notion_Page_Id__c != null
        LIMIT 1
        OFFSET :i
    ];
    
    if (!accountLogs.isEmpty() && String.isNotBlank(accountLogs[0].Notion_Page_Id__c)) {
        try {
            NotionApiClient.NotionResponse response = NotionApiClient.getPage(accountLogs[0].Notion_Page_Id__c);
            if (response.success) {
                verified++;
            } else {
                System.debug('Failed to verify Notion page: ' + response.errorMessage);
            }
        } catch (Exception e) {
            System.debug('Error verifying Notion page: ' + e.getMessage());
        }
    }
}

System.debug('Successfully verified ' + verified + ' out of ' + sampleSize + ' sample Notion pages');

// Summary
System.debug('\n=== Batch Test Summary ===');
if (syncedAccountIds.size() == batchAccounts.size() && 
    syncedContactIds.size() == batchContacts.size()) {
    System.debug('✓ All batch records successfully synced to Notion');
} else {
    System.debug('✗ Some batch records failed to sync');
    System.debug('  Expected ' + batchAccounts.size() + ' accounts, synced ' + syncedAccountIds.size());
    System.debug('  Expected ' + batchContacts.size() + ' contacts, synced ' + syncedContactIds.size());
}

// Summary output
System.debug('Batch processing test completed');