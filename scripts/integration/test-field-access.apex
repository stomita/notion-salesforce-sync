// Test Field Access Script
// This script tests if we can actually use the custom fields even if they don't show in describe

System.debug('=== Testing Field Access ===');

try {
    // Create a Test Parent record with custom fields
    Test_Parent_Object__c parent = new Test_Parent_Object__c(
        Name = 'Field Test Parent',
        Description__c = 'Testing if custom fields work',
        Status__c = 'New',
        Amount__c = 123.45,
        Active__c = true
    );
    insert parent;
    System.debug('✅ Successfully created Test Parent with custom fields');
    System.debug('Record ID: ' + parent.Id);
    
    // Query it back to verify
    Test_Parent_Object__c queriedParent = [
        SELECT Id, Name, Description__c, Status__c, Amount__c, Active__c
        FROM Test_Parent_Object__c
        WHERE Id = :parent.Id
    ];
    
    System.debug('\nQueried values:');
    System.debug('- Name: ' + queriedParent.Name);
    System.debug('- Description__c: ' + queriedParent.Description__c);
    System.debug('- Status__c: ' + queriedParent.Status__c);
    System.debug('- Amount__c: ' + queriedParent.Amount__c);
    System.debug('- Active__c: ' + queriedParent.Active__c);
    
    // Delete the test record
    delete parent;
    System.debug('\n✅ Custom fields are working correctly!');
    
} catch (Exception e) {
    System.debug('❌ Error: ' + e.getMessage());
    System.debug('Type: ' + e.getTypeName());
    System.debug('Stack trace: ' + e.getStackTraceString());
}