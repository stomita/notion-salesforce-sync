// Test date property clearing
System.debug('Testing date property clearing...');

// Find a child object with a due date
List<Test_Child_Object__c> children = [
    SELECT Id, Name, Due_Date__c 
    FROM Test_Child_Object__c 
    WHERE Name LIKE 'Integration Test%' 
    AND Due_Date__c != null 
    LIMIT 1
];

if (!children.isEmpty()) {
    Test_Child_Object__c child = children[0];
    System.debug('Before: Due_Date__c = ' + child.Due_Date__c);
    child.Due_Date__c = null;
    update child;
    System.debug('Updated child to clear due date field');
} else {
    System.debug('No test child object found with due date');
}

System.debug('Date clearing test complete - check Notion databases to verify');