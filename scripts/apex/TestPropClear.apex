// Test property clearing by updating records with null values
System.debug('Testing property clearing...');

// Test clearing number property
List<Test_Parent_Object__c> parents = [SELECT Id, Name, Amount__c FROM Test_Parent_Object__c WHERE Name LIKE 'Integration Test%' LIMIT 1];
if (!parents.isEmpty()) {
    Test_Parent_Object__c parent = parents[0];
    System.debug('Before: Amount__c = ' + parent.Amount__c);
    parent.Amount__c = null;
    update parent;
    System.debug('Updated parent to clear amount field');
}

// Test clearing select property (Status field)
List<Test_Parent_Object__c> parentsForSelect = [SELECT Id, Name, Status__c FROM Test_Parent_Object__c WHERE Name LIKE 'Integration Test%' AND Status__c != null LIMIT 1];
if (!parentsForSelect.isEmpty()) {
    Test_Parent_Object__c parent = parentsForSelect[0];
    System.debug('Before: Status__c = ' + parent.Status__c);
    parent.Status__c = null;
    update parent;
    System.debug('Updated parent to clear status field');
}

// Test clearing email property
List<Contact> contacts = [SELECT Id, Name, Email FROM Contact WHERE Name LIKE 'Integration Test%' LIMIT 1];
if (!contacts.isEmpty()) {
    Contact contact = contacts[0];
    System.debug('Before: Email = ' + contact.Email);
    contact.Email = null;
    update contact;
    System.debug('Updated contact to clear email field');
}

// Test clearing text property
List<Account> accounts = [SELECT Id, Name, Description FROM Account WHERE Name LIKE 'Integration Test%' LIMIT 1];
if (!accounts.isEmpty()) {
    Account account = accounts[0];
    System.debug('Before: Description = ' + account.Description);
    account.Description = null;
    update account;
    System.debug('Updated account to clear description field');
}

System.debug('Property clearing test complete - check Notion databases to verify');