// Cleanup Test Data Script
// This script removes all test data created for integration testing
// Run this after completing your integration tests

System.debug('=== Starting Test Data Cleanup ===');

// Delete Test Child Objects first (due to relationships)
List<Test_Child_Object__c> children = [
    SELECT Id, Name 
    FROM Test_Child_Object__c 
    WHERE Name LIKE 'Test Child%' OR Name LIKE 'New Test Child%'
];
if (!children.isEmpty()) {
    delete children;
    System.debug('Deleted ' + children.size() + ' test child objects');
}

// Delete Test Parent Objects
List<Test_Parent_Object__c> parents = [
    SELECT Id, Name 
    FROM Test_Parent_Object__c 
    WHERE Name LIKE 'Test Parent%'
];
if (!parents.isEmpty()) {
    delete parents;
    System.debug('Deleted ' + parents.size() + ' test parent objects');
}

// Delete Test Contacts
List<Contact> contacts = [
    SELECT Id, Name 
    FROM Contact 
    WHERE LastName LIKE 'Contact % for Test Account%'
];
if (!contacts.isEmpty()) {
    delete contacts;
    System.debug('Deleted ' + contacts.size() + ' test contacts');
}

// Delete Test Accounts
List<Account> accounts = [
    SELECT Id, Name 
    FROM Account 
    WHERE Name LIKE 'Test Account%'
];
if (!accounts.isEmpty()) {
    delete accounts;
    System.debug('Deleted ' + accounts.size() + ' test accounts');
}

// Clean up Sync Logs for test records
List<Notion_Sync_Log__c> testLogs = [
    SELECT Id, Object_Type__c, Record_Id__c
    FROM Notion_Sync_Log__c
    WHERE Object_Type__c IN ('Account', 'Contact', 'Test_Parent_Object__c', 'Test_Child_Object__c')
    AND CreatedDate = TODAY
];
if (!testLogs.isEmpty()) {
    delete testLogs;
    System.debug('Deleted ' + testLogs.size() + ' test sync logs');
}

System.debug('\n=== Test Data Cleanup Complete ===');
System.debug('All test records have been removed.');
System.debug('\nNote: Notion pages created during testing need to be manually deleted from Notion.');