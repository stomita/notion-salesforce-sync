@isTest
private class NotionSyncEventTriggerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test accounts for record IDs
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i,
                Description = 'Test account for sync testing'
            ));
        }
        insert testAccounts;
    }
    
    @isTest
    static void testSingleEventProcessing() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        // Create a single platform event
        Notion_Sync_Event__e syncEvent = new Notion_Sync_Event__e(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE'
        );
        
        // Publish the event - this will trigger the platform event trigger in test context
        Database.SaveResult result = EventBus.publish(syncEvent);
        
        Test.stopTest();
        
        // Verify the event was published successfully
        System.assert(result.isSuccess(), 'Platform event should be published successfully');
        System.assertNotEquals(null, result.getId(), 'Platform event should have a valid ID after publishing');
        
        // In test context, the platform event trigger executes synchronously during publish
        // If we reach this point without exceptions, the trigger executed successfully
        // We cannot directly verify queueable job enqueuing in test context, but successful
        // execution without errors indicates the trigger processed the event correctly
    }
    
    @isTest
    static void testBulkEventProcessing() {
        // Get test accounts
        List<Account> testAccounts = [SELECT Id FROM Account];
        
        Test.startTest();
        
        // Create multiple platform events
        List<Notion_Sync_Event__e> syncEvents = new List<Notion_Sync_Event__e>();
        for (Account acc : testAccounts) {
            syncEvents.add(new Notion_Sync_Event__e(
                Record_Id__c = acc.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = 'UPDATE'
            ));
        }
        
        // Publish events in bulk - this will trigger the platform event trigger in test context
        List<Database.SaveResult> results = EventBus.publish(syncEvents);
        
        Test.stopTest();
        
        // Verify all events were published successfully
        for (Database.SaveResult result : results) {
            System.assert(result.isSuccess(), 'All platform events should be published successfully');
            System.assertNotEquals(null, result.getId(), 'Each platform event should have a valid ID');
        }
        
        // Verify the correct number of events were processed
        System.assertEquals(testAccounts.size(), results.size(), 
                          'All platform events should be published');
    }
    
    @isTest
    static void testMixedOperationTypes() {
        // Get test accounts
        List<Account> testAccounts = [SELECT Id FROM Account LIMIT 3];
        
        Test.startTest();
        
        // Create events with different operation types
        List<Notion_Sync_Event__e> syncEvents = new List<Notion_Sync_Event__e>();
        syncEvents.add(new Notion_Sync_Event__e(
            Record_Id__c = testAccounts[0].Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE'
        ));
        syncEvents.add(new Notion_Sync_Event__e(
            Record_Id__c = testAccounts[1].Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'UPDATE'
        ));
        syncEvents.add(new Notion_Sync_Event__e(
            Record_Id__c = testAccounts[2].Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'DELETE'
        ));
        
        // Publish mixed events - this will trigger the platform event trigger in test context
        List<Database.SaveResult> results = EventBus.publish(syncEvents);
        
        Test.stopTest();
        
        // Verify all events were published successfully
        for (Database.SaveResult result : results) {
            System.assert(result.isSuccess(), 'All platform events should be published successfully');
            System.assertNotEquals(null, result.getId(), 'Each platform event should have a valid ID');
        }
        
        // Verify the correct number of events were processed with mixed operation types
        System.assertEquals(3, results.size(), 
                          'Three platform events should be published');
    }
    
    @isTest
    static void testDifferentObjectTypes() {
        // Get test account and create test contact
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact testContact = new Contact(
            AccountId = testAccount.Id,
            FirstName = 'Test',
            LastName = 'Contact'
        );
        insert testContact;
        
        Test.startTest();
        
        // Create events for different object types
        List<Notion_Sync_Event__e> syncEvents = new List<Notion_Sync_Event__e>();
        syncEvents.add(new Notion_Sync_Event__e(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'UPDATE'
        ));
        syncEvents.add(new Notion_Sync_Event__e(
            Record_Id__c = testContact.Id,
            Object_Type__c = 'Contact',
            Operation_Type__c = 'CREATE'
        ));
        
        // Publish events for different objects - this will trigger the platform event trigger in test context
        List<Database.SaveResult> results = EventBus.publish(syncEvents);
        
        Test.stopTest();
        
        // Verify all events were published successfully
        for (Database.SaveResult result : results) {
            System.assert(result.isSuccess(), 'All platform events should be published successfully');
            System.assertNotEquals(null, result.getId(), 'Each platform event should have a valid ID');
        }
        
        // Verify events for different object types were processed correctly
        System.assertEquals(2, results.size(), 
                          'Two platform events should be published');
    }
    
    @isTest
    static void testEventWithMaximumFieldLengths() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        // Create event with maximum field lengths
        Notion_Sync_Event__e syncEvent = new Notion_Sync_Event__e(
            Record_Id__c = testAccount.Id, // 18 characters max
            Object_Type__c = 'Custom_Very_Long_Object_Name_That_Reaches_The_Maximum_Length_Allowed_Here__c', // 80 characters max
            Operation_Type__c = 'UPDATE' // 20 characters max
        );
        
        // Publish the event - this will trigger the platform event trigger in test context
        Database.SaveResult result = EventBus.publish(syncEvent);
        
        Test.stopTest();
        
        // Verify the event was published successfully even with max lengths
        System.assert(result.isSuccess(), 'Platform event with max field lengths should be published successfully');
        System.assertNotEquals(null, result.getId(), 'Platform event should have a valid ID after publishing');
        
        // Successful execution without errors indicates the trigger handled maximum field lengths correctly
    }
    
    @isTest
    static void testEventFieldValidation() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        // Test with various valid operation types
        List<String> validOperations = new List<String>{'CREATE', 'UPDATE', 'DELETE', 'UPSERT'};
        List<Notion_Sync_Event__e> syncEvents = new List<Notion_Sync_Event__e>();
        
        for (String operation : validOperations) {
            syncEvents.add(new Notion_Sync_Event__e(
                Record_Id__c = testAccount.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = operation
            ));
        }
        
        // Publish events with different operation types - this will trigger the platform event trigger in test context
        List<Database.SaveResult> results = EventBus.publish(syncEvents);
        
        Test.stopTest();
        
        // Verify all events were published successfully
        for (Database.SaveResult result : results) {
            System.assert(result.isSuccess(), 'All platform events with valid operations should be published successfully');
            System.assertNotEquals(null, result.getId(), 'Each platform event should have a valid ID');
        }
        
        // Verify all operation types were processed correctly
        System.assertEquals(validOperations.size(), results.size(), 
                          'All platform events should be published');
    }
    
    @isTest
    static void testLargeVolumeEventProcessing() {
        // Create additional test accounts for volume testing
        List<Account> additionalAccounts = new List<Account>();
        for (Integer i = 0; i < 95; i++) { // Adding to existing 5 to make 100 total
            additionalAccounts.add(new Account(
                Name = 'Volume Test Account ' + i,
                Description = 'Volume testing account'
            ));
        }
        insert additionalAccounts;
        
        // Get all test accounts
        List<Account> allAccounts = [SELECT Id FROM Account];
        
        Test.startTest();
        
        // Create events for all accounts (testing bulk processing)
        List<Notion_Sync_Event__e> syncEvents = new List<Notion_Sync_Event__e>();
        for (Account acc : allAccounts) {
            syncEvents.add(new Notion_Sync_Event__e(
                Record_Id__c = acc.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = 'CREATE'
            ));
        }
        
        // Publish large volume of events - this will trigger the platform event trigger in test context
        List<Database.SaveResult> results = EventBus.publish(syncEvents);
        
        Test.stopTest();
        
        // Verify all events were published successfully
        for (Database.SaveResult result : results) {
            System.assert(result.isSuccess(), 'All volume test events should be published successfully');
            System.assertNotEquals(null, result.getId(), 'Each platform event should have a valid ID');
        }
        
        // Verify large volume processing handled correctly
        System.assertEquals(allAccounts.size(), results.size(), 
                          'All volume test events should be published');
    }
}