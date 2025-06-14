// Setup Test Data Script
// This script creates test data for integration testing
// Run this after deploying the integration test components

System.debug('=== Starting Test Data Setup ===');

// Create test Accounts
List<Account> accounts = new List<Account>();
for (Integer i = 1; i <= 3; i++) {
    accounts.add(new Account(
        Name = 'Test Account ' + i,
        Description = 'This is a test account for Notion integration testing. ' +
                     'It includes a longer description to test rich text mapping. ' +
                     'Account number ' + i + ' was created on ' + Date.today()
    ));
}
insert accounts;
System.debug('Created ' + accounts.size() + ' test accounts');

// Create Test Parent Objects
List<Test_Parent_Object__c> parents = new List<Test_Parent_Object__c>();
for (Integer i = 1; i <= 5; i++) {
    parents.add(new Test_Parent_Object__c(
        Name = 'Test Parent ' + i,
        Description__c = 'This is test parent object #' + i + '.\n\n' +
                        'It contains multiple lines of text to test long text area mapping.\n' +
                        'This should appear as body content in Notion.',
        Status__c = (i == 1) ? 'New' : ((i == 2) ? 'In Progress' : 'Completed'),
        Amount__c = i * 1000.50,
        Active__c = Math.mod(i, 2) == 1
    ));
}
insert parents;
System.debug('Created ' + parents.size() + ' test parent objects');

// Create Test Child Objects with relationships
List<Test_Child_Object__c> children = new List<Test_Child_Object__c>();
Integer childCount = 0;
for (Test_Parent_Object__c parent : parents) {
    for (Integer i = 1; i <= 2; i++) {
        childCount++;
        children.add(new Test_Child_Object__c(
            Name = 'Test Child ' + childCount,
            Test_Parent__c = parent.Id,
            Account__c = accounts[Math.mod(childCount - 1, accounts.size())].Id,
            Details__c = 'Child object #' + childCount + ' belongs to ' + parent.Name + '.\n' +
                        'This demonstrates master-detail and lookup relationships.\n' +
                        'Account: ' + accounts[Math.mod(childCount - 1, accounts.size())].Name,
            Quantity__c = childCount * 10,
            Due_Date__c = Date.today().addDays(childCount * 7)
        ));
    }
}
insert children;
System.debug('Created ' + children.size() + ' test child objects');

// Create Contacts for Account relationship testing
List<Contact> contacts = new List<Contact>();
for (Account acc : accounts) {
    for (Integer i = 1; i <= 2; i++) {
        contacts.add(new Contact(
            FirstName = 'Test',
            LastName = 'Contact ' + i + ' for ' + acc.Name,
            AccountId = acc.Id,
            Email = 'test.contact.' + acc.Id + '.' + i + '@example.com'
        ));
    }
}
insert contacts;
System.debug('Created ' + contacts.size() + ' test contacts');

System.debug('=== Test Data Setup Complete ===');
System.debug('Summary:');
System.debug('- Accounts: ' + accounts.size());
System.debug('- Test Parent Objects: ' + parents.size());
System.debug('- Test Child Objects: ' + children.size());
System.debug('- Contacts: ' + contacts.size());

// Display sample IDs for reference
System.debug('\nSample Record IDs:');
System.debug('Account ID: ' + accounts[0].Id);
System.debug('Test Parent ID: ' + parents[0].Id);
System.debug('Test Child ID: ' + children[0].Id);
System.debug('Contact ID: ' + contacts[0].Id);