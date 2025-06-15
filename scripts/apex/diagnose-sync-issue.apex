// Diagnose why Notion pages aren't being created during integration tests

System.debug('=== DIAGNOSING NOTION SYNC ISSUE ===');

// 1. Check recent sync logs
System.debug('\n--- Recent Sync Logs ---');
List<Notion_Sync_Log__c> syncLogs = [
    SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, 
           Status__c, Notion_Page_Id__c, Error_Message__c, 
           Retry_Count__c, CreatedDate
    FROM Notion_Sync_Log__c
    WHERE CreatedDate >= :DateTime.now().addHours(-1)
    ORDER BY CreatedDate DESC
    LIMIT 20
];

if (syncLogs.isEmpty()) {
    System.debug('⚠️ NO SYNC LOGS FOUND in the last hour');
    System.debug('This indicates that the sync process is not being triggered at all');
} else {
    System.debug('Found ' + syncLogs.size() + ' sync logs:');
    for (Notion_Sync_Log__c log : syncLogs) {
        System.debug('  - ' + log.Object_Type__c + ' (' + log.Operation_Type__c + '): ' + 
                    log.Status__c + 
                    (log.Status__c == 'Failed' ? ' - Error: ' + log.Error_Message__c : '') +
                    (String.isNotBlank(log.Notion_Page_Id__c) ? ' - Notion ID: ' + log.Notion_Page_Id__c : ''));
    }
}

// 2. Check if flows are active
System.debug('\n--- Checking Flow Status ---');
List<FlowDefinitionView> flows = [
    SELECT Label, ActiveVersionId, IsActive
    FROM FlowDefinitionView
    WHERE Label LIKE '%Notion%'
    ORDER BY Label
];

if (flows.isEmpty()) {
    System.debug('⚠️ NO NOTION FLOWS FOUND');
} else {
    for (FlowDefinitionView flow : flows) {
        System.debug('  - ' + flow.Label + ': ' + 
                    (flow.IsActive ? '✓ Active' : '✗ INACTIVE'));
    }
}

// 3. Check test records created recently
System.debug('\n--- Recent Test Records ---');
List<Account> testAccounts = [
    SELECT Id, Name, CreatedDate, LastModifiedDate
    FROM Account
    WHERE Name LIKE 'Integration Test Account%'
    AND CreatedDate >= :DateTime.now().addHours(-1)
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('Test Accounts: ' + testAccounts.size());
for (Account acc : testAccounts) {
    System.debug('  - ' + acc.Name + ' (Created: ' + acc.CreatedDate + ')');
}

// 4. Check if Flows are configured correctly
System.debug('\n--- Flow Configuration ---');
System.debug('If no sync logs exist, it likely means:');
System.debug('  1. Flows are not active/deployed');
System.debug('  2. Invocable Apex is not being called');
System.debug('  3. Queueable/Future job is failing before creating logs');

// 5. Check Custom Metadata configuration
System.debug('\n--- Custom Metadata Configuration ---');
List<NotionSyncObject__mdt> syncObjects = [
    SELECT ObjectApiName__c, NotionDatabaseId__c, IsActive__c
    FROM NotionSyncObject__mdt
    WHERE IsActive__c = true
];

for (NotionSyncObject__mdt obj : syncObjects) {
    System.debug('  - ' + obj.ObjectApiName__c + ' → ' + obj.NotionDatabaseId__c);
}

// 6. Check Named Credential
System.debug('\n--- Named Credential Check ---');
// Named Credentials are not directly queryable in Apex
System.debug('Named Credentials cannot be queried directly in Apex');
System.debug('Check Setup > Named Credentials to verify "Notion_API" exists');

System.debug('\n=== DIAGNOSIS COMPLETE ===');
System.debug('Next steps based on findings:');
System.debug('1. If no sync logs: Check flows are active and platform event trigger is deployed');
System.debug('2. If sync logs show failures: Check the error messages for API issues');
System.debug('3. If everything looks configured: Run a manual sync test');