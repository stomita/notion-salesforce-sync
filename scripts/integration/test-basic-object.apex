// Test Basic Object Creation
System.debug('=== Testing Basic Object Creation ===');

try {
    // Create a basic Test Parent record with only Name field
    Test_Parent_Object__c parent = new Test_Parent_Object__c(
        Name = 'Basic Test Parent'
    );
    insert parent;
    System.debug('✅ Successfully created Test Parent record');
    System.debug('Record ID: ' + parent.Id);
    
    // Query it back
    Test_Parent_Object__c queriedParent = [
        SELECT Id, Name
        FROM Test_Parent_Object__c
        WHERE Id = :parent.Id
    ];
    
    System.debug('Queried Name: ' + queriedParent.Name);
    
    // Delete the test record
    delete parent;
    System.debug('✅ Basic object operations work!');
    
} catch (Exception e) {
    System.debug('❌ Error: ' + e.getMessage());
    System.debug('Type: ' + e.getTypeName());
}