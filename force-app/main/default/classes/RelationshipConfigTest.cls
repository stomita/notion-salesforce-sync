@IsTest
public class RelationshipConfigTest {
    
    @IsTest
    static void testRelationshipConfigConstruction() {
        NotionSyncObject__mdt parentObj = new NotionSyncObject__mdt();
        parentObj.ObjectApiName__c = 'Account';
        
        NotionSyncObject__mdt childObj = new NotionSyncObject__mdt();
        childObj.ObjectApiName__c = 'Contact';
        
        NotionRelation__mdt relation = new NotionRelation__mdt();
        relation.SalesforceRelationshipField__c = 'AccountId';
        relation.NotionRelationPropertyName__c = 'Account_Relation';
        relation.EnableCascadeDelete__c = true;
        
        Test.startTest();
        RelationshipConfig config = new RelationshipConfig(relation);
        Test.stopTest();
        
        System.assertEquals('AccountId', config.salesforceRelationshipField, 'Salesforce relationship field should match');
        System.assertEquals('Account_Relation', config.notionRelationPropertyName, 'Notion relation property should match');
        System.assertEquals(true, config.enableCascadeDelete, 'Cascade delete should be enabled');
    }
    
    @IsTest
    static void testRelationshipConfigWithCascadeDeleteDisabled() {
        NotionSyncObject__mdt parentObj = new NotionSyncObject__mdt();
        parentObj.ObjectApiName__c = 'Account';
        
        NotionSyncObject__mdt childObj = new NotionSyncObject__mdt();
        childObj.ObjectApiName__c = 'Opportunity';
        
        NotionRelation__mdt relation = new NotionRelation__mdt();
        relation.SalesforceRelationshipField__c = 'AccountId';
        relation.NotionRelationPropertyName__c = 'Account_Relation';
        relation.EnableCascadeDelete__c = false;
        
        Test.startTest();
        RelationshipConfig config = new RelationshipConfig(relation);
        Test.stopTest();
        
        System.assertEquals(false, config.enableCascadeDelete, 'Cascade delete should be disabled');
    }
}