// Test 6 - Setup: Create many records to test batch processing
System.debug('=== Test 6 Setup: Creating bulk records for batch processing ===');

// First clean up any existing bulk test data
delete [SELECT Id FROM Account WHERE Name LIKE 'Batch Test Account%'];
delete [SELECT Id FROM Contact WHERE LastName LIKE 'Batch Test Contact%'];

// Create 75 accounts to trigger batch processing (default batch size is 50)
List<Account> batchAccounts = new List<Account>();
for (Integer i = 1; i <= 75; i++) {
    Account acc = new Account(
        Name = 'Batch Test Account ' + String.valueOf(i).leftPad(3, '0'),
        Description = 'Batch test account #' + i + ' created at ' + DateTime.now(),
        Type = 'Customer',
        Industry = 'Technology',
        AnnualRevenue = 100000 + (i * 1000)
    );
    batchAccounts.add(acc);
}

System.debug('Inserting ' + batchAccounts.size() + ' accounts for batch testing...');
insert batchAccounts;

// Create contacts for the first 25 accounts to test mixed batch processing
List<Contact> batchContacts = new List<Contact>();
for (Integer i = 0; i < 25; i++) {
    Contact con = new Contact(
        FirstName = 'Batch',
        LastName = 'Batch Test Contact ' + String.valueOf(i+1).leftPad(3, '0'),
        Email = 'batch.test.' + (i+1) + '@example.com',
        AccountId = batchAccounts[i].Id,
        Title = 'Test Contact #' + (i+1)
    );
    batchContacts.add(con);
}

System.debug('Inserting ' + batchContacts.size() + ' contacts for batch testing...');
insert batchContacts;

System.debug('Bulk records created. Total records: ' + (batchAccounts.size() + batchContacts.size()));
System.debug('Expected behavior: These should be processed in batches due to volume');
System.debug('Wait for batch sync to complete...');