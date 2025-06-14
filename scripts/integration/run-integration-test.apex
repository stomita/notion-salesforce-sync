// Run Integration Test Script
// This script performs a full integration test of the Notion sync functionality
// Make sure you have:
// 1. Created Notion databases and updated the custom metadata with their IDs
// 2. Run setup-test-data.apex to create test records
// 3. Configured Named Credential with your Notion API token

System.debug('=== Starting Notion Sync Integration Test ===');

// Test 1: Verify Custom Metadata Configuration
System.debug('\n--- Test 1: Verifying Custom Metadata Configuration ---');
List<NotionSyncObject__mdt> syncObjects = [
    SELECT Id, DeveloperName, ObjectApiName__c, NotionDatabaseId__c, 
           SalesforceIdPropertyName__c, IsActive__c
    FROM NotionSyncObject__mdt
    WHERE DeveloperName IN ('Account_Test_Sync', 'Test_Parent_Sync', 
                          'Test_Child_Sync', 'Contact_Test_Sync')
];
System.debug('Found ' + syncObjects.size() + ' sync object configurations');
for (NotionSyncObject__mdt obj : syncObjects) {
    System.debug('- ' + obj.ObjectApiName__c + ' -> Notion DB: ' + obj.NotionDatabaseId__c);
}

// Test 2: Trigger sync for test records
System.debug('\n--- Test 2: Triggering Sync for Test Records ---');

// Update an Account to trigger sync
Account testAccount = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%' LIMIT 1];
testAccount.Name = testAccount.Name + ' - Updated ' + DateTime.now().format('HH:mm:ss');
update testAccount;
System.debug('Updated Account: ' + testAccount.Id);

// Update a Test Parent to trigger sync
Test_Parent_Object__c testParent = [
    SELECT Id, Name, Status__c 
    FROM Test_Parent_Object__c 
    WHERE Name LIKE 'Test Parent%' 
    LIMIT 1
];
testParent.Status__c = 'In Progress';
testParent.Amount__c = 5555.55;
update testParent;
System.debug('Updated Test Parent: ' + testParent.Id);

// Create a new Test Child to trigger sync
Test_Child_Object__c newChild = new Test_Child_Object__c(
    Name = 'New Test Child - ' + DateTime.now().format('HH:mm:ss'),
    Test_Parent__c = testParent.Id,
    Account__c = testAccount.Id,
    Details__c = 'This is a newly created child record to test CREATE operation',
    Quantity__c = 999,
    Due_Date__c = Date.today().addDays(30)
);
insert newChild;
System.debug('Created new Test Child: ' + newChild.Id);

// Test 3: Check Platform Events
System.debug('\n--- Test 3: Platform Events Should Be Published ---');
System.debug('Platform events are published asynchronously by the flows');
System.debug('Check the Notion_Sync_Event__e events in the Event Bus');

// Test 4: Verify Sync Logs (wait a moment for async processing)
System.debug('\n--- Test 4: Checking Sync Logs ---');
System.debug('Waiting 5 seconds for async processing...');
Long startTime = DateTime.now().getTime();
while (DateTime.now().getTime() - startTime < 5000) {
    // Wait
}

List<Notion_Sync_Log__c> recentLogs = [
    SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, 
           Status__c, Notion_Page_Id__c, Error_Message__c, CreatedDate
    FROM Notion_Sync_Log__c
    WHERE CreatedDate >= :DateTime.now().addMinutes(-5)
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('Recent sync logs: ' + recentLogs.size());
for (Notion_Sync_Log__c log : recentLogs) {
    System.debug('- ' + log.Object_Type__c + ' (' + log.Operation_Type__c + '): ' + 
                log.Status__c + 
                (log.Error_Message__c != null ? ' - Error: ' + log.Error_Message__c : '') +
                (log.Notion_Page_Id__c != null ? ' - Notion Page: ' + log.Notion_Page_Id__c : ''));
}

// Test 5: Test Relationship Sync
System.debug('\n--- Test 5: Testing Relationship Sync ---');
List<Test_Child_Object__c> childrenWithRelations = [
    SELECT Id, Name, Test_Parent__c, Test_Parent__r.Name, 
           Account__c, Account__r.Name
    FROM Test_Child_Object__c
    WHERE Test_Parent__c != null AND Account__c != null
    LIMIT 5
];

System.debug('Child objects with relationships: ' + childrenWithRelations.size());
for (Test_Child_Object__c child : childrenWithRelations) {
    System.debug('- ' + child.Name + ' -> Parent: ' + child.Test_Parent__r.Name + 
                ', Account: ' + child.Account__r.Name);
}

// Test 6: Test Delete Operation
System.debug('\n--- Test 6: Testing Delete Operation ---');
Test_Child_Object__c childToDelete = [
    SELECT Id, Name 
    FROM Test_Child_Object__c 
    WHERE Name LIKE 'Test Child%' 
    ORDER BY CreatedDate DESC 
    LIMIT 1
];
System.debug('Deleting child object: ' + childToDelete.Name);
delete childToDelete;
System.debug('Delete operation triggered');

System.debug('\n=== Integration Test Complete ===');
System.debug('Next steps:');
System.debug('1. Check your Notion workspace for the synced records');
System.debug('2. Verify relationships are properly linked in Notion');
System.debug('3. Check Notion_Sync_Log__c for detailed sync results');
System.debug('4. Run cleanup-test-data.apex when done testing');