// Debug custom settings issue
Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
System.debug('=== Initial Settings ===');
System.debug('Settings: ' + settings);
System.debug('Settings ID: ' + settings.Id);

// Create/update settings
if (settings.Id == null) {
    settings = new Notion_Sync_Settings__c();
}
settings.put('Enable_Logging__c', true);
settings.put('Log_Level__c', 'ERROR');
upsert settings;

// Retrieve again
settings = Notion_Sync_Settings__c.getOrgDefaults();
System.debug('=== After Upsert ===');
System.debug('Settings: ' + settings);
System.debug('Enable_Logging__c: ' + settings.get('Enable_Logging__c'));
System.debug('Log_Level__c: ' + settings.get('Log_Level__c'));

// Test the logger
NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
NotionSyncLogger.log('001000000000002', 'Account', 'UPDATE', 'Failed', 'Test error', 1);
NotionSyncLogger.log('001000000000003', 'Account', 'DELETE', 'Rate Limited', 'Rate limit hit', 0);

System.debug('=== About to Flush ===');

// Flush
NotionSyncLogger.flush();

// Check result
List<Notion_Sync_Log__c> logs = [SELECT Id, Status__c FROM Notion_Sync_Log__c];
System.debug('=== Result ===');
System.debug('Created logs count: ' + logs.size());
for (Notion_Sync_Log__c log : logs) {
    System.debug('Log: ' + log);
}