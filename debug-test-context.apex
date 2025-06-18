// Test in simulated test context
System.debug('=== Simulating Test Context ===');

// Clean up
delete [SELECT Id FROM Notion_Sync_Log__c];
delete [SELECT Id FROM Notion_Sync_Settings__c];

// Set up settings like in test
Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
if (settings.Id == null) {
    settings = new Notion_Sync_Settings__c();
}
settings.put('Enable_Logging__c', true);
settings.put('Log_Level__c', 'ERROR');
upsert settings;

// Verify settings
settings = Notion_Sync_Settings__c.getOrgDefaults();
System.debug('Settings after setup: ' + settings);
System.debug('Enable_Logging__c: ' + settings.get('Enable_Logging__c'));
System.debug('Log_Level__c: ' + settings.get('Log_Level__c'));

// Add logs like in test
NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
NotionSyncLogger.log('001000000000002', 'Account', 'UPDATE', 'Failed', 'Test error', 1);
NotionSyncLogger.log('001000000000003', 'Account', 'DELETE', 'Rate Limited', 'Rate limit hit', 0);

// Can't access private variable directly

// Flush - this should filter and create only 2 logs
NotionSyncLogger.flush();

// Query immediately
List<Notion_Sync_Log__c> logs = [
    SELECT Status__c FROM Notion_Sync_Log__c 
    WHERE Record_Id__c IN ('001000000000001', '001000000000002', '001000000000003')
    ORDER BY Record_Id__c
];

System.debug('=== Results ===');
System.debug('Logs created: ' + logs.size());
for (Notion_Sync_Log__c log : logs) {
    System.debug('Status: ' + log.Status__c);
}