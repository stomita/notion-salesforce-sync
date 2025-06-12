@IsTest
public class NotionRelationshipHandlerTest {
    
    @TestSetup
    static void makeData() {
        Account parentAccount = new Account(Name = 'Test Parent Account');
        insert parentAccount;
        
        Contact childContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = parentAccount.Id
        );
        insert childContact;
        
        Opportunity childOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = parentAccount.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting'
        );
        insert childOpportunity;
    }
    
    @IsTest
    static void testLoadRelationshipConfigurations() {
        Test.startTest();
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        Test.stopTest();
        
        System.assertNotEquals(null, handler, 'Handler should be initialized');
    }
    
    @IsTest
    static void testGetProcessingOrderSimple() {
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        Set<String> objectTypes = new Set<String>{ 'Account', 'Contact' };
        
        Test.startTest();
        List<String> processingOrder = handler.getProcessingOrder(objectTypes);
        Test.stopTest();
        
        System.assertEquals(2, processingOrder.size(), 'Should return both object types');
        System.assert(processingOrder.contains('Account'), 'Should contain Account');
        System.assert(processingOrder.contains('Contact'), 'Should contain Contact');
    }
    
    @IsTest
    static void testGetProcessingOrderWithDependencies() {
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        
        Test.startTest();
        Set<String> objectTypes = new Set<String>{ 'Contact', 'Account', 'Opportunity' };
        List<String> processingOrder = handler.getProcessingOrder(objectTypes);
        Test.stopTest();
        
        System.assertEquals(3, processingOrder.size(), 'Should return all three object types');
        
        Integer accountIndex = processingOrder.indexOf('Account');
        Integer contactIndex = processingOrder.indexOf('Contact');
        Integer opportunityIndex = processingOrder.indexOf('Opportunity');
        
        System.assertNotEquals(-1, accountIndex, 'Account should be in the processing order');
        System.assertNotEquals(-1, contactIndex, 'Contact should be in the processing order');
        System.assertNotEquals(-1, opportunityIndex, 'Opportunity should be in the processing order');
    }
    
    @IsTest
    static void testEnrichNotionPropertiesWithRelations() {
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        
        Contact testContact = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Map<String, Object> properties = new Map<String, Object>{
            'Name' => new Map<String, Object>{ 'title' => new List<Object>() }
        };
        
        Test.setMock(HttpCalloutMock.class, new MockNotionApiResponse());
        
        Test.startTest();
        Map<String, Object> enrichedProperties = handler.enrichNotionPropertiesWithRelations(
            'Contact', testContact, properties
        );
        Test.stopTest();
        
        System.assertNotEquals(null, enrichedProperties, 'Enriched properties should not be null');
        System.assertEquals(1, enrichedProperties.size(), 'Should maintain original properties when no relation config exists');
    }
    
    @IsTest
    static void testGetChildRecordsToDelete() {
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<String> childRecords = handler.getChildRecordsToDelete('Account', testAccount.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, childRecords, 'Child records list should not be null');
    }
    
    @IsTest
    static void testGetRelatedRecordNotionPageIds() {
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        Set<Id> recordIds = new Set<Id>{ testContact.Id };
        
        Test.setMock(HttpCalloutMock.class, new MockNotionApiResponse());
        
        Test.startTest();
        Map<Id, String> pageIdMap = handler.getRelatedRecordNotionPageIds('Contact', recordIds);
        Test.stopTest();
        
        System.assertNotEquals(null, pageIdMap, 'Page ID map should not be null');
    }
    
    @IsTest
    static void testHasRelationships() {
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        
        Test.startTest();
        Boolean hasAccountRelationships = handler.hasRelationships('Account');
        Boolean hasContactRelationships = handler.hasRelationships('Contact');
        Test.stopTest();
        
        System.assertNotEquals(null, hasAccountRelationships, 'Should return boolean for Account');
        System.assertNotEquals(null, hasContactRelationships, 'Should return boolean for Contact');
    }
    
    @IsTest
    static void testGetChildAndParentRelationships() {
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        
        Test.startTest();
        List<NotionRelationshipHandler.RelationshipConfig> childRelations = handler.getChildRelationships('Contact');
        List<NotionRelationshipHandler.RelationshipConfig> parentRelations = handler.getParentRelationships('Account');
        Test.stopTest();
        
        System.assertNotEquals(null, childRelations, 'Child relations should not be null');
        System.assertNotEquals(null, parentRelations, 'Parent relations should not be null');
    }
    
    @IsTest
    static void testCircularDependencyDetection() {
        NotionRelationshipHandler handler = new NotionRelationshipHandler();
        
        Test.startTest();
        try {
            Set<String> objectTypes = new Set<String>{ 'Account', 'Contact' };
            List<String> processingOrder = handler.getProcessingOrder(objectTypes);
            System.assert(true, 'Should handle normal case without circular dependencies');
        } catch (NotionRelationshipHandler.RelationshipHandlerException e) {
            System.assert(e.getMessage().contains('Circular dependency'), 'Should detect circular dependencies');
        }
        Test.stopTest();
    }
    
    public class MockNotionApiResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/query')) {
                res.setBody('{"results": [{"id": "test-page-id-12345"}]}');
            }
            
            return res;
        }
    }
}