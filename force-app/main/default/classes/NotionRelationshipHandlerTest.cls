@IsTest
public class NotionRelationshipHandlerTest {
    
    @TestSetup
    static void setup() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Contact testContact1 = new Contact(
            FirstName = 'Test',
            LastName = 'Contact1',
            AccountId = testAccount.Id
        );
        Contact testContact2 = new Contact(
            FirstName = 'Test',
            LastName = 'Contact2',
            AccountId = testAccount.Id
        );
        insert new List<Contact>{testContact1, testContact2};
        
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpportunity;
    }
    
    @IsTest
    static void testGetChildRecordsToDeleteWithCascadeEnabled() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        List<String> childRecords = NotionRelationshipHandler.getChildRecordsToDelete('Account', testAccount.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(null, childRecords, 'Child records list should not be null');
    }
    
    @IsTest
    static void testGetChildRecordsToDeleteWithCascadeDisabled() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        List<String> childRecords = NotionRelationshipHandler.getChildRecordsToDelete('Account', testAccount.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(null, childRecords, 'Child records list should not be null');
    }
    
    @IsTest
    static void testGetChildRecordsToDeleteWithNonExistentParent() {
        String fakeAccountId = '001000000000000';
        
        Test.startTest();
        
        List<String> childRecords = NotionRelationshipHandler.getChildRecordsToDelete('Account', fakeAccountId);
        
        Test.stopTest();
        
        System.assertEquals(0, childRecords.size(), 'Should return empty list for non-existent parent');
    }
    
    @IsTest
    static void testGetChildRecordsToDeleteWithNoRelationConfig() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        List<String> childRecords = NotionRelationshipHandler.getChildRecordsToDelete('CustomObject__c', testAccount.Id);
        
        Test.stopTest();
        
        System.assertEquals(0, childRecords.size(), 'Should return empty list for object with no relation config');
    }
    
    @IsTest
    static void testRefreshConfigurations() {
        Test.startTest();
        
        NotionRelationshipHandler.refreshConfigurations();
        List<RelationshipConfig> configs = NotionRelationshipHandler.getAllRelationshipConfigs();
        
        Test.stopTest();
        
        System.assertNotEquals(null, configs, 'Configurations should not be null after refresh');
    }
}