// Simple test - create test scenario and use LogEntry directly
delete [SELECT Id FROM Notion_Sync_Log__c];

// Direct test of filtering in flush method
NotionSyncLogger.clear();

// Set up custom settings
Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
if (settings.Id == null) {
    settings = new Notion_Sync_Settings__c();
}
settings.put('Enable_Logging__c', true);
settings.put('Log_Level__c', 'ERROR');
upsert settings;

// Create log entries directly
List<NotionSyncLogger.LogEntry> testEntries = new List<NotionSyncLogger.LogEntry>();
testEntries.add(new NotionSyncLogger.LogEntry('001', 'Account', 'CREATE', 'Success', null, 0, null));
testEntries.add(new NotionSyncLogger.LogEntry('002', 'Account', 'UPDATE', 'Failed', 'Error', 1, null));
testEntries.add(new NotionSyncLogger.LogEntry('003', 'Account', 'DELETE', 'Rate Limited', 'Rate limit', 0, null));

// Filter based on shouldLog
Integer expectedCount = 0;
for (NotionSyncLogger.LogEntry entry : testEntries) {
    // Manually call private method via reflection won't work, so just count what we expect
    if (entry.status == 'Failed' || entry.status == 'Rate Limited') {
        expectedCount++;
    }
}

System.debug('Expected filtered count: ' + expectedCount);

// Now test the actual flow
NotionSyncLogger.log('001', 'Account', 'CREATE', 'Success', null, 0);
NotionSyncLogger.log('002', 'Account', 'UPDATE', 'Failed', 'Error', 1);
NotionSyncLogger.log('003', 'Account', 'DELETE', 'Rate Limited', 'Rate limit', 0);

// Call flush synchronously
NotionSyncLogger.flush();

// Query the results - should match expected count
List<Notion_Sync_Log__c> logs = [
    SELECT Id, Status__c
    FROM Notion_Sync_Log__c
    WHERE Record_Id__c IN ('001', '002', '003')
];

System.debug('Actual logs created: ' + logs.size());
System.debug('Expected: ' + expectedCount + ', Actual: ' + logs.size());

for (Notion_Sync_Log__c log : logs) {
    System.debug('Log status: ' + log.Status__c);
}