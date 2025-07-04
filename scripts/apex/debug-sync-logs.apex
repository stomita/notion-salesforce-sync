// Debug sync logs in CI
System.debug('=== Debugging Sync Logs ===');

// Get test records
List<Account> testAccounts = [
    SELECT Id, Name, CreatedDate
    FROM Account
    WHERE Name LIKE 'Integration Test%'
    ORDER BY CreatedDate DESC
];
System.debug('Test Accounts found: ' + testAccounts.size());
for (Account acc : testAccounts) {
    System.debug('- ' + acc.Id + ' ' + acc.Name + ' created at ' + acc.CreatedDate);
}

// Check ALL sync logs
List<Notion_Sync_Log__c> allLogs = [
    SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, Status__c, 
           Notion_Page_Id__c, Error_Message__c, CreatedDate
    FROM Notion_Sync_Log__c
    ORDER BY CreatedDate DESC
    LIMIT 20
];
System.debug('All Sync Logs: ' + allLogs.size());
for (Notion_Sync_Log__c log : allLogs) {
    System.debug('- ' + log.Object_Type__c + ' ' + log.Operation_Type__c + ' ' + log.Status__c + 
                 ' RecordId=' + log.Record_Id__c + 
                 ' PageId=' + log.Notion_Page_Id__c +
                 ' at ' + log.CreatedDate +
                 (log.Error_Message__c != null ? ' Error: ' + log.Error_Message__c : ''));
}

// Check sync logs for test accounts specifically
if (!testAccounts.isEmpty()) {
    Set<Id> testAccountIds = new Set<Id>();
    for (Account acc : testAccounts) {
        testAccountIds.add(acc.Id);
    }
    
    List<Notion_Sync_Log__c> testLogs = [
        SELECT Id, Record_Id__c, Operation_Type__c, Status__c, Notion_Page_Id__c
        FROM Notion_Sync_Log__c
        WHERE Record_Id__c IN :testAccountIds
    ];
    System.debug('Sync logs for test accounts: ' + testLogs.size());
    for (Notion_Sync_Log__c log : testLogs) {
        System.debug('- RecordId=' + log.Record_Id__c + 
                     ' Op=' + log.Operation_Type__c + 
                     ' Status=' + log.Status__c + 
                     ' PageId=' + log.Notion_Page_Id__c);
    }
}