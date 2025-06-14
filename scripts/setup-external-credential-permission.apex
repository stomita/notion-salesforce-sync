// Script to set up External Credential Principal access for the current user
// This needs to be run by an admin user

// Get current user
User currentUser = [SELECT Id, Username, ProfileId FROM User WHERE Id = :UserInfo.getUserId()];
System.debug('Setting up access for user: ' + currentUser.Username);

// Check if NamedCredential exists
List<NamedCredential> namedCreds = [SELECT Id, DeveloperName, MasterLabel FROM NamedCredential WHERE DeveloperName = 'Notion_API' LIMIT 1];
if (namedCreds.isEmpty()) {
    System.debug('ERROR: Named Credential "Notion_API" not found');
} else {
    System.debug('Found Named Credential: ' + namedCreds[0].MasterLabel);
}

// Note: External Credential Principal assignments typically need to be done through:
// 1. Permission Sets with External Credential Principal Access
// 2. Setup UI manually
// 3. Metadata API

System.debug('To grant access:');
System.debug('1. Go to Setup > Named Credentials > External Credentials');
System.debug('2. Click on "Notion_Credential"');
System.debug('3. Under "Principals", click on "NotionIntegration"');
System.debug('4. Add the current user or profile to the Principal Access');
System.debug('');
System.debug('Alternative: Create a Permission Set with External Credential Principal Access');
System.debug('and assign it to the user');