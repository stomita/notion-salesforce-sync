// Check the result of Flow-triggered sync
// Run this after creating/updating a test record

System.debug('=== Checking Flow Sync Results ===');

// Get the most recent sync logs
List<Notion_Sync_Log__c> recentLogs = [
    SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, 
           Status__c, Notion_Page_Id__c, Error_Message__c, 
           CreatedDate, CreatedBy.Name
    FROM Notion_Sync_Log__c
    WHERE Object_Type__c = 'Account'
    AND CreatedDate >= :DateTime.now().addMinutes(-5)
    ORDER BY CreatedDate DESC
    LIMIT 10
];

if (recentLogs.isEmpty()) {
    System.debug('❌ No sync logs found in the last 5 minutes');
    System.debug('This could mean:');
    System.debug('1. Flow was not triggered (check Flow is active)');
    System.debug('2. Sync is still in progress (wait a bit longer)');
    System.debug('3. Error occurred before log creation');
} else {
    System.debug('Found ' + recentLogs.size() + ' recent sync log(s):');
    System.debug('────────────────────────────────────────────────────');
    
    for (Notion_Sync_Log__c log : recentLogs) {
        System.debug('\n📄 Sync Log:');
        System.debug('   Record ID: ' + log.Record_Id__c);
        System.debug('   Operation: ' + log.Operation_Type__c);
        System.debug('   Status: ' + log.Status__c);
        System.debug('   Created By: ' + log.CreatedBy.Name);
        System.debug('   Created: ' + log.CreatedDate);
        
        if (log.Status__c == 'Success') {
            System.debug('   ✅ Notion Page ID: ' + log.Notion_Page_Id__c);
            System.debug('   🎉 SYNC SUCCESSFUL! Flow-based sync is working.');
        } else if (log.Status__c == 'Failed') {
            System.debug('   ❌ Error: ' + log.Error_Message__c);
            
            if (log.Error_Message__c != null && log.Error_Message__c.contains('couldn\'t access the credential')) {
                System.debug('\n   ⚠️  CREDENTIAL ACCESS ERROR DETECTED');
                System.debug('   This means "Available for All Users" is not enabled.');
                System.debug('   Please follow the setup instructions to enable it.');
            }
        }
    }
}

// Also check for test accounts created recently
System.debug('\n📊 Recent Test Accounts:');
List<Account> testAccounts = [
    SELECT Id, Name, CreatedDate
    FROM Account
    WHERE Name LIKE 'Flow Sync Test%'
    AND CreatedDate >= :DateTime.now().addMinutes(-5)
    ORDER BY CreatedDate DESC
    LIMIT 5
];

for (Account acc : testAccounts) {
    System.debug('   - ' + acc.Name + ' (Created: ' + acc.CreatedDate + ')');
}