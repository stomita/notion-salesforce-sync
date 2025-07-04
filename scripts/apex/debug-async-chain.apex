// Debug async processing chain
System.debug('=== Debugging Async Processing Chain ===');

// Get test account
Account testAccount = [
    SELECT Id, Name 
    FROM Account 
    WHERE Name LIKE 'Integration Test%' 
    ORDER BY CreatedDate DESC 
    LIMIT 1
];
System.debug('Test Account: ' + testAccount.Id + ' ' + testAccount.Name);

// Check what happens when we process sync directly
System.debug('Testing direct NotionSyncProcessor execution...');

// Create a logger
NotionSyncLogger testLogger = new NotionSyncLogger();

// Create a sync request
List<NotionSync.Request> requests = new List<NotionSync.Request>();
NotionSync.Request req = new NotionSync.Request();
req.recordId = testAccount.Id;
req.objectType = 'Account';
req.operationType = 'UPDATE'; // Use UPDATE since CREATE might have been done
requests.add(req);

// Process directly
try {
    NotionSyncProcessor processor = new NotionSyncProcessor(testLogger);
    processor.processSyncRequests(requests);
    System.debug('Direct processing completed');
    
    // Check if logger has entries
    System.debug('Logger has pending entries: ' + testLogger.hasPendingEntries());
    
    // Flush logs
    System.debug('Flushing logs...');
    testLogger.flush();
    System.debug('Logs flushed');
    
} catch (Exception e) {
    System.debug('Error during direct processing: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

// Check sync logs again
List<Notion_Sync_Log__c> logsAfter = [
    SELECT Id, Record_Id__c, Operation_Type__c, Status__c, Notion_Page_Id__c, 
           Error_Message__c, CreatedDate
    FROM Notion_Sync_Log__c
    WHERE Record_Id__c = :testAccount.Id
    ORDER BY CreatedDate DESC
];

System.debug('Sync logs after direct processing: ' + logsAfter.size());
for (Notion_Sync_Log__c log : logsAfter) {
    System.debug('- ' + log.Operation_Type__c + ' ' + log.Status__c + 
                 ' PageId=' + log.Notion_Page_Id__c +
                 ' at ' + log.CreatedDate +
                 (log.Error_Message__c != null ? ' Error: ' + log.Error_Message__c : ''));
}