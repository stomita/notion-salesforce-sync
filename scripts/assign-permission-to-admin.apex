// Since Permission Sets with External Credential Principal Access have limitations,
// let's check if we can use a different approach for testing

// Get current user info
User currentUser = [SELECT Id, Username, ProfileId, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
System.debug('Current User: ' + currentUser.Username);
System.debug('Profile: ' + currentUser.Profile.Name);

// For testing in scratch orgs, System Administrator should have access
// Let's verify the user is System Administrator
if (currentUser.Profile.Name == 'System Administrator' || currentUser.Profile.Name == 'システム管理者') {
    System.debug('User is System Administrator - should have full access');
    System.debug('If you still get permission errors, you may need to:');
    System.debug('1. Open Setup > Named Credentials > External Credentials > Notion_Credential');
    System.debug('2. Click on the NotionIntegration principal');
    System.debug('3. Manually add System Administrator profile or your user');
} else {
    System.debug('User is not System Administrator. Profile: ' + currentUser.Profile.Name);
}

// Alternative: Let's try to test without External Credential first
System.debug('\nTesting direct API call with manual headers...');
System.debug('This is for testing only - production code should use Named Credentials');