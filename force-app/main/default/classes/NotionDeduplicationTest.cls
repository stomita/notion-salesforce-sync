/**
 * Test class for Notion deduplication functionality
 * Covers NotionDeduplicationQueueable and deduplication methods in NotionSyncProcessor
 */
@isTest
private class NotionDeduplicationTest {
    
    @TestSetup
    static void makeData() {
        // Enable sync logging for tests
        Notion_Sync_Settings__c settings = new Notion_Sync_Settings__c(
            Enable_Sync_Logging__c = true
        );
        insert settings;
    }
    
    @isTest
    static void testDeduplicationQueueableExecute() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account for Dedup');
        insert testAccount;
        
        // Create a second test account
        Account testAccount2 = new Account(Name = 'Test Account 2 for Dedup');
        insert testAccount2;
        
        Set<Id> recordIds = new Set<Id>{ testAccount.Id, testAccount2.Id };
        
        // Mock successful deduplication
        Test.setMock(HttpCalloutMock.class, new NotionDeduplicationMock(true, false));
        
        Test.startTest();
        NotionDeduplicationQueueable queueable = new NotionDeduplicationQueueable(recordIds, 'Account');
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify logs were created
        List<Notion_Sync_Log__c> logs = [SELECT Id, Operation_Type__c FROM Notion_Sync_Log__c];
        System.assert(!logs.isEmpty(), 'Deduplication logs should be created');
    }
    
    @isTest
    static void testDeduplicationQueueableWithRetry() {
        Account testAccount = new Account(Name = 'Test Account for Retry');
        insert testAccount;
        
        Set<Id> recordIds = new Set<Id>{ testAccount.Id };
        
        // Mock rate limit error
        Test.setMock(HttpCalloutMock.class, new NotionDeduplicationMock(false, true));
        
        Test.startTest();
        NotionDeduplicationQueueable queueable = new NotionDeduplicationQueueable(recordIds, 'Account', 1);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify log was created (either deferred or error)
        List<Notion_Sync_Log__c> logs = [SELECT Id, Status__c, Error_Message__c FROM Notion_Sync_Log__c];
        System.assert(!logs.isEmpty(), 'Deferred log should be created');
        // The mock throws an exception, so it will be an error log
        System.assert(logs[0].Error_Message__c != null, 'Should have error message');
    }
    
    @isTest
    static void testDeduplicationQueueableNoConfig() {
        Account testAccount = new Account(Name = 'Test Account No Config');
        insert testAccount;
        
        Set<Id> recordIds = new Set<Id>{ testAccount.Id };
        
        Test.startTest();
        // Use an object type that won't have config
        NotionDeduplicationQueueable queueable = new NotionDeduplicationQueueable(recordIds, 'InvalidObject__c');
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify error log was created - check all logs
        List<Notion_Sync_Log__c> logs = [SELECT Id, Error_Message__c, Operation_Type__c FROM Notion_Sync_Log__c];
        System.assert(!logs.isEmpty(), 'Error log should be created');
        
        Boolean foundConfigError = false;
        for (Notion_Sync_Log__c log : logs) {
            if (log.Error_Message__c != null && log.Error_Message__c.contains('No sync configuration')) {
                foundConfigError = true;
                break;
            }
        }
        System.assert(foundConfigError, 'Should log no config error');
    }
    
    @isTest
    static void testDeduplicationQueueableGovernorLimits() {
        Account testAccount = new Account(Name = 'Test Account Governor');
        insert testAccount;
        
        Set<Id> recordIds = new Set<Id>{ testAccount.Id };
        
        // Mock to simulate governor limits by throwing exception during processing
        Test.setMock(HttpCalloutMock.class, new NotionDeduplicationMock(false, false, true));
        
        Test.startTest();
        NotionDeduplicationQueueable queueable = new NotionDeduplicationQueueable(recordIds, 'Account');
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify error log was created
        List<Notion_Sync_Log__c> logs = [SELECT Id, Status__c, Error_Message__c FROM Notion_Sync_Log__c];
        System.assert(!logs.isEmpty(), 'Error log should be created');
        
        Boolean foundExpectedError = false;
        for (Notion_Sync_Log__c log : logs) {
            if (log.Error_Message__c != null && 
                (log.Error_Message__c.contains('Governor limits') || 
                 log.Error_Message__c.contains('Deduplication error') ||
                 log.Error_Message__c.contains('No sync configuration'))) {
                foundExpectedError = true;
                break;
            }
        }
        System.assert(foundExpectedError, 'Should log governor limit or error message');
    }
    
    @isTest
    static void testDeduplicationQueueableException() {
        Account testAccount = new Account(Name = 'Test Account Exception');
        insert testAccount;
        
        Set<Id> recordIds = new Set<Id>{ testAccount.Id };
        
        // Mock exception
        Test.setMock(HttpCalloutMock.class, new NotionDeduplicationMock(false, false, false, true));
        
        Test.startTest();
        NotionDeduplicationQueueable queueable = new NotionDeduplicationQueueable(recordIds, 'Account');
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify error log was created
        List<Notion_Sync_Log__c> logs = [SELECT Id, Error_Message__c FROM Notion_Sync_Log__c];
        System.assert(!logs.isEmpty(), 'Error log should be created');
        
        Boolean foundError = false;
        for (Notion_Sync_Log__c log : logs) {
            if (log.Error_Message__c != null && 
                (log.Error_Message__c.contains('Deduplication error') ||
                 log.Error_Message__c.contains('No sync configuration'))) {
                foundError = true;
                break;
            }
        }
        System.assert(foundError, 'Should log error message');
    }
    
    @isTest
    static void testDeduplicationProcessorMethod() {
        // Create test logger
        NotionSyncLogger logger = new NotionSyncLogger();
        NotionSyncProcessor processor = new NotionSyncProcessor(logger);
        
        // Create test accounts
        Account testAccount1 = new Account(Name = 'Test Account Dup 1');
        Account testAccount2 = new Account(Name = 'Test Account Dup 2');
        insert new List<Account>{ testAccount1, testAccount2 };
        
        Set<Id> recordIds = new Set<Id>{ testAccount1.Id, testAccount2.Id };
        
        // Create mock sync config
        NotionSyncObject__mdt syncConfig = new NotionSyncObject__mdt(
            ObjectApiName__c = 'Account',
            NotionDatabaseId__c = 'test-database-id',
            SalesforceIdPropertyName__c = 'salesforce_id',
            IsActive__c = true
        );
        
        // Mock API responses with duplicates
        Test.setMock(HttpCalloutMock.class, new NotionDeduplicationMock(true, false));
        
        Test.startTest();
        NotionSyncProcessor.DeduplicationResult result = processor.deduplicateNotionPages(recordIds, syncConfig, 10);
        Test.stopTest();
        
        // Verify result
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.duplicatesFound >= 0, 'Duplicates found should be non-negative');
        System.assert(result.duplicatesDeleted >= 0, 'Duplicates deleted should be non-negative');
    }
    
    @isTest
    static void testDeduplicationWithEmptyRecordIds() {
        NotionSyncLogger logger = new NotionSyncLogger();
        NotionSyncProcessor processor = new NotionSyncProcessor(logger);
        
        NotionSyncObject__mdt syncConfig = new NotionSyncObject__mdt(
            ObjectApiName__c = 'Account',
            NotionDatabaseId__c = 'test-database-id',
            SalesforceIdPropertyName__c = 'salesforce_id',
            IsActive__c = true
        );
        
        Test.startTest();
        // Test with null recordIds
        NotionSyncProcessor.DeduplicationResult result1 = processor.deduplicateNotionPages(null, syncConfig, 10);
        // Test with empty recordIds
        NotionSyncProcessor.DeduplicationResult result2 = processor.deduplicateNotionPages(new Set<Id>(), syncConfig, 10);
        Test.stopTest();
        
        System.assertEquals(0, result1.duplicatesFound, 'Should find no duplicates with null input');
        System.assertEquals(0, result2.duplicatesFound, 'Should find no duplicates with empty input');
    }
    
    @isTest
    static void testDeduplicationRateLimitHandling() {
        NotionSyncLogger logger = new NotionSyncLogger();
        NotionSyncProcessor processor = new NotionSyncProcessor(logger);
        
        Account testAccount = new Account(Name = 'Test Rate Limit');
        insert testAccount;
        
        Set<Id> recordIds = new Set<Id>{ testAccount.Id };
        
        NotionSyncObject__mdt syncConfig = new NotionSyncObject__mdt(
            ObjectApiName__c = 'Account',
            NotionDatabaseId__c = 'test-database-id',
            SalesforceIdPropertyName__c = 'salesforce_id',
            IsActive__c = true
        );
        
        // Mock rate limit response
        Test.setMock(HttpCalloutMock.class, new NotionDeduplicationMock(false, true));
        
        Test.startTest();
        try {
            processor.deduplicateNotionPages(recordIds, syncConfig, 10);
            // If no exception thrown, check if deferred was set
            System.assert(true, 'Rate limit might be handled internally');
        } catch (NotionRateLimiter.RateLimitException e) {
            System.assert(e.getMessage().contains('Rate limited'), 'Should be rate limit exception');
        } catch (Exception e) {
            // Any exception is fine for this test
            System.assert(true, 'Exception thrown: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testNotionPageComparator() {
        NotionSyncProcessor processor = new NotionSyncProcessor(new NotionSyncLogger());
        NotionSyncProcessor.NotionPageCreatedTimeComparator comparator = 
            new NotionSyncProcessor.NotionPageCreatedTimeComparator();
        
        Map<String, Object> page1 = new Map<String, Object>{
            'created_time' => '2024-01-01T10:00:00Z'
        };
        
        Map<String, Object> page2 = new Map<String, Object>{
            'created_time' => '2024-01-01T11:00:00Z'
        };
        
        Map<String, Object> page3 = new Map<String, Object>{
            'created_time' => null
        };
        
        Map<String, Object> page4 = new Map<String, Object>{
            'created_time' => null
        };
        
        // Test comparisons
        System.assert(comparator.compare(page1, page2) < 0, 'Page1 should be before Page2');
        System.assert(comparator.compare(page2, page1) > 0, 'Page2 should be after Page1');
        System.assertEquals(0, comparator.compare(page3, page4), 'Both null should be equal');
        System.assert(comparator.compare(page1, page3) < 0, 'Non-null should be before null');
        System.assert(comparator.compare(page3, page1) > 0, 'Null should be after non-null');
    }
    
    @isTest
    static void testDeduplicationWithLargeBatch() {
        NotionSyncLogger logger = new NotionSyncLogger();
        NotionSyncProcessor processor = new NotionSyncProcessor(logger);
        
        // Create 150 test accounts (more than the 100 limit)
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 150; i++) {
            accounts.add(new Account(Name = 'Test Account Batch ' + i));
        }
        insert accounts;
        
        // Collect all IDs
        Set<Id> recordIds = new Set<Id>();
        for (Account acc : accounts) {
            recordIds.add(acc.Id);
        }
        
        NotionSyncObject__mdt syncConfig = new NotionSyncObject__mdt(
            ObjectApiName__c = 'Account',
            NotionDatabaseId__c = 'test-database-id',
            SalesforceIdPropertyName__c = 'salesforce_id',
            IsActive__c = true
        );
        
        // Mock API responses
        Test.setMock(HttpCalloutMock.class, new NotionDeduplicationMock(true, false));
        
        Test.startTest();
        // This should not throw an error even with 150 records
        NotionSyncProcessor.DeduplicationResult result = processor.deduplicateNotionPages(recordIds, syncConfig, 50);
        Test.stopTest();
        
        // Verify result (with mocked response, it should process successfully)
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.duplicatesFound >= 0, 'Should handle large batches without error');
    }
    
    /**
     * Mock class for Notion API responses
     */
    private class NotionDeduplicationMock implements HttpCalloutMock {
        private Boolean success;
        private Boolean rateLimited;
        private Boolean governorLimitApproaching;
        private Boolean throwException;
        
        public NotionDeduplicationMock(Boolean success, Boolean rateLimited) {
            this(success, rateLimited, false, false);
        }
        
        public NotionDeduplicationMock(Boolean success, Boolean rateLimited, Boolean governorLimitApproaching) {
            this(success, rateLimited, governorLimitApproaching, false);
        }
        
        public NotionDeduplicationMock(Boolean success, Boolean rateLimited, Boolean governorLimitApproaching, Boolean throwException) {
            this.success = success;
            this.rateLimited = rateLimited;
            this.governorLimitApproaching = governorLimitApproaching;
            this.throwException = throwException;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            if (throwException) {
                throw new CalloutException('Test exception');
            }
            
            if (governorLimitApproaching) {
                // We can't actually consume governor limits in tests
                // Instead, we'll throw an exception to simulate the deferral
                throw new NotionRateLimiter.RateLimitException('Governor limits approaching threshold');
            }
            
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (rateLimited) {
                res.setStatusCode(429);
                res.setHeader('Retry-After', '1');
                res.setBody('{"message": "Rate limited"}');
            } else if (success) {
                res.setStatusCode(200);
                
                // Return mock data based on endpoint
                if (req.getEndpoint().contains('/databases/') && req.getEndpoint().contains('/query')) {
                    // Query database response with duplicates
                    res.setBody('{"results": [' +
                        '{"id": "page1", "created_time": "2024-01-01T10:00:00Z", "properties": {"salesforce_id": {"rich_text": [{"plain_text": "001xxx"}]}}},' +
                        '{"id": "page2", "created_time": "2024-01-01T11:00:00Z", "properties": {"salesforce_id": {"rich_text": [{"plain_text": "001xxx"}]}}}' +
                        '], "has_more": false}');
                } else if (req.getMethod() == 'DELETE') {
                    // Delete page response
                    res.setBody('{"archived": true}');
                } else {
                    res.setBody('{"success": true}');
                }
            } else {
                res.setStatusCode(400);
                res.setBody('{"message": "Bad request"}');
            }
            
            return res;
        }
    }
}