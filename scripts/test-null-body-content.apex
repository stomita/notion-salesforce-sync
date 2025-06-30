// Test script to verify null body content handling
System.debug('=== Testing Null Body Content Sync ===');

// Create a test account with body content
Account testAccount = new Account(
    Name = 'Null Body Test ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss'),
    Description = 'Initial description that will be cleared.'
);
insert testAccount;

System.debug('Created test account: ' + testAccount.Id + ' - ' + testAccount.Name);
System.debug('Initial description: ' + testAccount.Description);

// Wait a moment for initial sync
System.debug('Waiting 3 seconds for initial sync...');
Long startTime = System.currentTimeMillis();
while (System.currentTimeMillis() - startTime < 3000) {
    // Wait
}

// Now clear the description (set to null)
testAccount.Description = null;
update testAccount;

System.debug('Cleared description (set to null)');
System.debug('Check Notion to verify page content was cleared.');

// Wait and then set to empty string
System.debug('Waiting 3 seconds...');
startTime = System.currentTimeMillis();
while (System.currentTimeMillis() - startTime < 3000) {
    // Wait
}

// Test with empty string
testAccount.Description = '';
update testAccount;

System.debug('Set description to empty string');
System.debug('Check Notion to verify page content remains cleared.');

// Test with whitespace only
testAccount.Description = '   ';
update testAccount;

System.debug('Set description to whitespace only');
System.debug('Check Notion - page content should still be empty.');