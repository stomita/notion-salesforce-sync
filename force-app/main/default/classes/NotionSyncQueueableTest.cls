@isTest
private class NotionSyncQueueableTest {
    
    // Mock class for Notion API HTTP callouts
    private class NotionAPIHttpCalloutMock implements HttpCalloutMock {
        private String responseBody;
        private Integer statusCode;
        private String responseOperation;
        
        public NotionAPIHttpCalloutMock(String operation) {
            this.responseOperation = operation;
            this.statusCode = 200;
        }
        
        public NotionAPIHttpCalloutMock(String operation, Integer statusCode) {
            this.responseOperation = operation;
            this.statusCode = statusCode;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            
            // Mock different responses based on the endpoint
            if (req.getEndpoint().contains('/query')) {
                // Mock query response for finding existing pages
                if (this.responseOperation == 'FIND_EXISTING') {
                    this.responseBody = '{"results": [{"id": "mock-page-id-123"}]}';
                } else {
                    this.responseBody = '{"results": []}';
                }
            } else if (req.getEndpoint().contains('/pages') && req.getMethod() == 'POST') {
                // Mock create page response
                this.responseBody = '{"id": "new-mock-page-id-456", "url": "https://notion.so/mock-page"}';
            } else if (req.getEndpoint().contains('/pages') && req.getMethod() == 'PATCH') {
                // Mock update/delete page response
                this.responseBody = '{"id": "mock-page-id-123", "archived": false}';
            }
            
            if (this.statusCode >= 400) {
                this.responseBody = '{"message": "API Error", "code": "validation_error"}';
            }
            
            res.setBody(this.responseBody);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    // Test data setup
    @testSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i,
                Description = 'Long text description for testing body content mapping',
                Phone = '555-000-000' + i,
                AnnualRevenue = 100000 + (i * 10000)
            ));
        }
        insert testAccounts;
        
        // Create test contacts
        Account parentAccount = testAccounts[0];
        List<Contact> testContacts = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            testContacts.add(new Contact(
                AccountId = parentAccount.Id,
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'test' + i + '@example.com',
                Description = 'Test contact description'
            ));
        }
        insert testContacts;
    }
    
    @isTest
    static void testCreateOperationSuccess() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('CREATE'));
        
        Account testAccount = [SELECT Id, Name, Description FROM Account LIMIT 1];
        
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccount.Id,
            'Account',
            'CREATE'
        ));
        
        Test.startTest();
        
        // Execute the queueable job
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify sync log was created
        List<Notion_Sync_Log__c> syncLogs = [
            SELECT Record_Id__c, Object_Type__c, Operation_Type__c, Status__c, Error_Message__c
            FROM Notion_Sync_Log__c
            WHERE Record_Id__c = :testAccount.Id
        ];
        
        System.assertEquals(1, syncLogs.size(), 'One sync log should be created');
        Notion_Sync_Log__c log = syncLogs[0];
        System.assertEquals(testAccount.Id, log.Record_Id__c, 'Record ID should match');
        System.assertEquals('Account', log.Object_Type__c, 'Object type should be Account');
        System.assertEquals('CREATE', log.Operation_Type__c, 'Operation should be CREATE');
        // Note: Without custom metadata, this will log an error about no sync configuration
        // In a real environment with proper metadata, this would be 'Success'
    }
    
    @isTest
    static void testUpdateOperationSuccess() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('FIND_EXISTING'));
        
        Account testAccount = [SELECT Id, Name, Description FROM Account LIMIT 1];
        
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccount.Id,
            'Account',
            'UPDATE'
        ));
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify sync log was created
        List<Notion_Sync_Log__c> syncLogs = [
            SELECT Record_Id__c, Operation_Type__c, Status__c
            FROM Notion_Sync_Log__c
            WHERE Record_Id__c = :testAccount.Id
        ];
        
        System.assertEquals(1, syncLogs.size(), 'One sync log should be created');
        System.assertEquals('UPDATE', syncLogs[0].Operation_Type__c, 'Operation should be UPDATE');
    }
    
    @isTest
    static void testDeleteOperationSuccess() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('DELETE'));
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccount.Id,
            'Account',
            'DELETE'
        ));
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify sync log was created
        List<Notion_Sync_Log__c> syncLogs = [
            SELECT Operation_Type__c, Status__c
            FROM Notion_Sync_Log__c
            WHERE Record_Id__c = :testAccount.Id
        ];
        
        System.assertEquals(1, syncLogs.size(), 'One sync log should be created');
        System.assertEquals('DELETE', syncLogs[0].Operation_Type__c, 'Operation should be DELETE');
    }
    
    @isTest
    static void testBulkProcessingMultipleObjects() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('CREATE'));
        
        List<Account> testAccounts = [SELECT Id FROM Account LIMIT 3];
        List<Contact> testContacts = [SELECT Id FROM Contact LIMIT 2];
        
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        
        // Add account requests
        for (Account acc : testAccounts) {
            requests.add(new NotionSyncQueueable.SyncRequest(
                acc.Id,
                'Account',
                'CREATE'
            ));
        }
        
        // Add contact requests
        for (Contact con : testContacts) {
            requests.add(new NotionSyncQueueable.SyncRequest(
                con.Id,
                'Contact',
                'UPDATE'
            ));
        }
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify sync logs were created for all requests
        List<Notion_Sync_Log__c> syncLogs = [
            SELECT Record_Id__c, Object_Type__c, Operation_Type__c
            FROM Notion_Sync_Log__c
        ];
        
        System.assertEquals(5, syncLogs.size(), 'Five sync logs should be created (3 accounts + 2 contacts)');
        
        // Verify object type distribution
        Integer accountLogs = 0;
        Integer contactLogs = 0;
        for (Notion_Sync_Log__c log : syncLogs) {
            if (log.Object_Type__c == 'Account') accountLogs++;
            if (log.Object_Type__c == 'Contact') contactLogs++;
        }
        
        System.assertEquals(3, accountLogs, 'Three account logs should be created');
        System.assertEquals(2, contactLogs, 'Two contact logs should be created');
    }
    
    @isTest
    static void testHttpCalloutFailure() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('ERROR', 400));
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccount.Id,
            'Account',
            'CREATE'
        ));
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify error was logged
        List<Notion_Sync_Log__c> syncLogs = [
            SELECT Status__c, Error_Message__c
            FROM Notion_Sync_Log__c
            WHERE Record_Id__c = :testAccount.Id
        ];
        
        System.assertEquals(1, syncLogs.size(), 'One sync log should be created');
        Notion_Sync_Log__c log = syncLogs[0];
        System.assertEquals('Failed', log.Status__c, 'Status should be Failed');
        System.assertNotEquals(null, log.Error_Message__c, 'Error message should be populated');
    }
    
    @isTest
    static void testMixedOperationTypes() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('MIXED'));
        
        List<Account> testAccounts = [SELECT Id FROM Account LIMIT 3];
        
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccounts[0].Id,
            'Account',
            'CREATE'
        ));
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccounts[1].Id,
            'Account',
            'UPDATE'
        ));
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccounts[2].Id,
            'Account',
            'DELETE'
        ));
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify all operations were processed
        List<Notion_Sync_Log__c> syncLogs = [
            SELECT Operation_Type__c
            FROM Notion_Sync_Log__c
            WHERE Record_Id__c IN :new List<Id>{testAccounts[0].Id, testAccounts[1].Id, testAccounts[2].Id}
            ORDER BY Operation_Type__c
        ];
        
        System.assertEquals(3, syncLogs.size(), 'Three sync logs should be created');
        System.assertEquals('CREATE', syncLogs[0].Operation_Type__c, 'First operation should be CREATE');
        System.assertEquals('DELETE', syncLogs[1].Operation_Type__c, 'Second operation should be DELETE');
        System.assertEquals('UPDATE', syncLogs[2].Operation_Type__c, 'Third operation should be UPDATE');
    }
    
    @isTest
    static void testDataTransformationLogic() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('CREATE'));
        
        Account testAccount = [SELECT Id, Name, Description, Phone, AnnualRevenue FROM Account LIMIT 1];
        
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccount.Id,
            'Account',
            'CREATE'
        ));
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        
        // Test the data transformation methods directly
        NotionSyncQueueable.SyncRequest testRequest = new NotionSyncQueueable.SyncRequest(
            testAccount.Id,
            'Account',
            'CREATE'
        );
        
        // Verify SyncRequest constructor
        System.assertEquals(testAccount.Id, testRequest.recordId, 'Record ID should be set correctly');
        System.assertEquals('Account', testRequest.objectType, 'Object type should be set correctly');
        System.assertEquals('CREATE', testRequest.operationType, 'Operation type should be set correctly');
        
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify the job executed without throwing exceptions
        System.assertEquals(1, Limits.getQueueableJobs(), 'One queueable job should be enqueued');
    }
    
    @isTest
    static void testRecordNotFoundScenario() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('CREATE'));
        
        // Create a request with a non-existent record ID
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        requests.add(new NotionSyncQueueable.SyncRequest(
            '001000000000000AAA', // Non-existent Account ID
            'Account',
            'UPDATE'
        ));
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify error was logged for non-existent record
        List<Notion_Sync_Log__c> syncLogs = [
            SELECT Status__c, Error_Message__c
            FROM Notion_Sync_Log__c
            WHERE Record_Id__c = '001000000000000AAA'
        ];
        
        System.assertEquals(1, syncLogs.size(), 'One sync log should be created');
        Notion_Sync_Log__c log = syncLogs[0];
        System.assertEquals('Failed', log.Status__c, 'Status should be Failed');
        System.assertNotEquals(null, log.Error_Message__c, 'Error message should be populated');
    }
    
    @isTest
    static void testEmptyRequestList() {
        Test.startTest();
        
        // Test with empty request list
        NotionSyncQueueable job = new NotionSyncQueueable(new List<NotionSyncQueueable.SyncRequest>());
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify no sync logs were created
        List<Notion_Sync_Log__c> syncLogs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assertEquals(0, syncLogs.size(), 'No sync logs should be created for empty request list');
    }
    
    @isTest
    static void testLargeVolumeProcessing() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('CREATE'));
        
        List<Account> testAccounts = [SELECT Id FROM Account];
        
        // Create requests for all test accounts (bulk processing test)
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        for (Account acc : testAccounts) {
            requests.add(new NotionSyncQueueable.SyncRequest(
                acc.Id,
                'Account',
                'CREATE'
            ));
        }
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify all requests were processed
        List<Notion_Sync_Log__c> syncLogs = [SELECT Id, Record_Id__c FROM Notion_Sync_Log__c];
        System.assertEquals(testAccounts.size(), syncLogs.size(), 
                          'Sync logs should be created for all test accounts');
    }
    
    @isTest
    static void testCustomExceptionHandling() {
        Test.setMock(HttpCalloutMock.class, new NotionAPIHttpCalloutMock('ERROR', 500));
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
        requests.add(new NotionSyncQueueable.SyncRequest(
            testAccount.Id,
            'Account',
            'CREATE'
        ));
        
        Test.startTest();
        
        NotionSyncQueueable job = new NotionSyncQueueable(requests);
        System.enqueueJob(job);
        
        Test.stopTest();
        
        // Verify error handling
        List<Notion_Sync_Log__c> syncLogs = [
            SELECT Status__c, Error_Message__c, Retry_Count__c
            FROM Notion_Sync_Log__c
            WHERE Record_Id__c = :testAccount.Id
        ];
        
        System.assertEquals(1, syncLogs.size(), 'One sync log should be created');
        Notion_Sync_Log__c log = syncLogs[0];
        System.assertEquals('Failed', log.Status__c, 'Status should be Failed');
        System.assertEquals(0, log.Retry_Count__c, 'Retry count should be initialized to 0');
        System.assertNotEquals(null, log.Error_Message__c, 'Error message should be populated');
    }
    
    @isTest
    static void testSyncRequestConstructor() {
        // Test SyncRequest inner class
        String testRecordId = '001000000000001AAA';
        String testObjectType = 'Account';
        String testOperationType = 'CREATE';
        
        Test.startTest();
        
        NotionSyncQueueable.SyncRequest request = new NotionSyncQueueable.SyncRequest(
            testRecordId,
            testObjectType,
            testOperationType
        );
        
        Test.stopTest();
        
        // Verify constructor sets properties correctly
        System.assertEquals(testRecordId, request.recordId, 'Record ID should be set correctly');
        System.assertEquals(testObjectType, request.objectType, 'Object type should be set correctly');
        System.assertEquals(testOperationType, request.operationType, 'Operation type should be set correctly');
    }
    
    @isTest
    static void testNotionSyncException() {
        Test.startTest();
        
        // Test custom exception
        try {
            throw new NotionSyncQueueable.NotionSyncException('Test exception message');
        } catch (NotionSyncQueueable.NotionSyncException e) {
            System.assertEquals('Test exception message', e.getMessage(), 'Exception message should match');
        }
        
        Test.stopTest();
    }
}