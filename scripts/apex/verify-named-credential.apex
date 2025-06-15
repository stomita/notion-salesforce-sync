// Script to verify Named Credential setup
// This helps verify the credential configuration is working properly

System.debug('=== Named Credential Verification ===');

// Check current user permissions
System.debug('\n1. Current User Check:');
System.debug('   User: ' + UserInfo.getUserName());
System.debug('   Profile: ' + UserInfo.getProfileId());

// Check if user has permission set
List<PermissionSetAssignment> psAssignments = [
    SELECT PermissionSet.Name 
    FROM PermissionSetAssignment 
    WHERE AssigneeId = :UserInfo.getUserId()
    AND PermissionSet.Name = 'Notion_Integration_User'
];
System.debug('   Has Notion_Integration_User permission: ' + !psAssignments.isEmpty());

// Test Named Credential access
System.debug('\n2. Testing Named Credential Access:');
try {
    Http http = new Http();
    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:Notion_API/v1/users/me');
    request.setMethod('GET');
    
    HttpResponse response = http.send(request);
    System.debug('   ✅ SUCCESS - Named Credential is accessible');
    System.debug('   Status Code: ' + response.getStatusCode());
    
    if (response.getStatusCode() == 200) {
        System.debug('   ✅ Notion API Key is valid');
    } else if (response.getStatusCode() == 401) {
        System.debug('   ❌ Notion API Key is invalid or not configured');
    }
} catch (Exception e) {
    System.debug('   ❌ FAILED - ' + e.getMessage());
    
    if (e.getMessage().contains('Unauthorized endpoint')) {
        System.debug('\n   SOLUTION: You need to configure the Named Principal credential.');
        System.debug('   Follow these steps:');
        System.debug('   1. Go to Setup → Security → Named Credentials');
        System.debug('   2. Click "External Credentials" tab');
        System.debug('   3. Click "Notion Credential"');
        System.debug('   4. Under Principals, click "New"');
        System.debug('   5. Set Parameter Name: NotionIntegration');
        System.debug('   6. Save, then click the principal');
        System.debug('   7. Add Authentication Parameter:');
        System.debug('      - Parameter Name: SecretKey');
        System.debug('      - Value: Your Notion API key (ntn_...)');
    }
}

// Check if we can create a test sync log (to verify object permissions)
System.debug('\n3. Testing Object Permissions:');
try {
    Notion_Sync_Log__c testLog = new Notion_Sync_Log__c(
        Record_Id__c = 'TEST123',
        Object_Type__c = 'Test',
        Operation_Type__c = 'TEST',
        Status__c = 'Test'
    );
    insert testLog;
    System.debug('   ✅ Can create Notion_Sync_Log__c records');
    delete testLog;
} catch (Exception e) {
    System.debug('   ❌ Cannot create Notion_Sync_Log__c records: ' + e.getMessage());
}

System.debug('\n=== Setup Summary ===');
System.debug('If all checks pass, the Named Principal is properly configured.');
System.debug('If not, follow the setup steps in the SOLUTION section above.');