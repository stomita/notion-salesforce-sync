// Test synchronous logging in test context
System.debug('=== Testing Synchronous Logging ===');

// Set up settings
Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
if (settings.Id == null) {
    settings = new Notion_Sync_Settings__c();
}
settings.put('Enable_Logging__c', true);
settings.put('Log_Level__c', 'ERROR');
upsert settings;

// Test direct logSync call
List<String> logJsonList = new List<String>();

// Create log entries
NotionSyncLogger.LogEntry entry1 = new NotionSyncLogger.LogEntry(
    '001000000000001', 'Account', 'CREATE', 'Success', null, 0, null
);
NotionSyncLogger.LogEntry entry2 = new NotionSyncLogger.LogEntry(
    '001000000000002', 'Account', 'UPDATE', 'Failed', 'Test error', 1, null
);

logJsonList.add(JSON.serialize(entry1));
logJsonList.add(JSON.serialize(entry2));

System.debug('Calling logSync with ' + logJsonList.size() + ' entries');

// Call logSync directly
NotionSyncLogger.logSync(logJsonList);

// Check results immediately
List<Notion_Sync_Log__c> logs = [
    SELECT Id, Status__c, Record_Id__c
    FROM Notion_Sync_Log__c
    WHERE Record_Id__c IN ('001000000000001', '001000000000002')
];

System.debug('=== Results ===');
System.debug('Logs created: ' + logs.size());
for (Notion_Sync_Log__c log : logs) {
    System.debug('Log: ' + log);
}