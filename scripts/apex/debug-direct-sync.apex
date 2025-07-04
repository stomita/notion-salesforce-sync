// Debug direct sync invocation
System.debug('=== Testing Direct Sync Invocation ===');

// Get the test account
List<Account> testAccounts = [
    SELECT Id, Name
    FROM Account
    WHERE Name LIKE 'Integration Test%'
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (testAccounts.isEmpty()) {
    System.debug('No test account found!');
    return;
}

Account testAccount = testAccounts[0];
System.debug('Test account: ' + testAccount.Id + ' ' + testAccount.Name);

// Create sync request directly
NotionSync.Request request = new NotionSync.Request();
request.recordId = testAccount.Id;
request.objectType = 'Account';
request.operationType = 'CREATE';

System.debug('Calling NotionSyncInvocable directly...');
List<NotionSync.Request> requests = new List<NotionSync.Request>{request};
List<NotionSync.Result> results = NotionSyncInvocable.syncToNotion(requests);

System.debug('Invocable results: ' + results);
for (NotionSync.Result result : results) {
    System.debug('- Success: ' + result.success + ', Message: ' + result.message);
}

// Wait a moment for async processing
System.debug('Waiting for async processing...');
// Can't use Test.stopTest() in anonymous apex

// Check for new sync logs
List<Notion_Sync_Log__c> newLogs = [
    SELECT Id, Record_Id__c, Operation_Type__c, Status__c, Notion_Page_Id__c, CreatedDate
    FROM Notion_Sync_Log__c
    WHERE Record_Id__c = :testAccount.Id
    ORDER BY CreatedDate DESC
];

System.debug('Sync logs for test account: ' + newLogs.size());
for (Notion_Sync_Log__c log : newLogs) {
    System.debug('- ' + log.Operation_Type__c + ' ' + log.Status__c + ' at ' + log.CreatedDate);
}