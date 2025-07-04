// Debug CI sync issue
System.debug('=== Debugging CI Sync Issue ===');

// Check sync settings
Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getInstance();
System.debug('getInstance() settings: ' + settings);
System.debug('Logging enabled (getInstance): ' + (settings != null ? settings.Enable_Sync_Logging__c : 'null settings'));

// Check org defaults
Notion_Sync_Settings__c orgDefaults = Notion_Sync_Settings__c.getOrgDefaults();
System.debug('getOrgDefaults() settings: ' + orgDefaults);
System.debug('Logging enabled (getOrgDefaults): ' + (orgDefaults != null ? orgDefaults.Enable_Sync_Logging__c : 'null settings'));

// Check if there are any sync logs at all
Integer logCount = [SELECT COUNT() FROM Notion_Sync_Log__c];
System.debug('Total sync logs in org: ' + logCount);

// Check recent logs
List<Notion_Sync_Log__c> recentLogs = [
    SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, Status__c, Error_Message__c, CreatedDate
    FROM Notion_Sync_Log__c
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('Recent logs count: ' + recentLogs.size());
for (Notion_Sync_Log__c log : recentLogs) {
    System.debug('Log: ' + log.Object_Type__c + ' - ' + log.Operation_Type__c + ' - ' + log.Status__c + ' - ' + log.CreatedDate);
}

// Check for test records
List<Account> testAccounts = [
    SELECT Id, Name, CreatedDate
    FROM Account
    WHERE Name LIKE 'Integration Test Account%'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('Test accounts found: ' + testAccounts.size());
for (Account acc : testAccounts) {
    System.debug('Account: ' + acc.Id + ' - ' + acc.Name + ' - ' + acc.CreatedDate);
}