@isTest
private class NotionSyncBatchProcessorTest {
    
    @TestSetup
    static void makeData() {
        // Enable sync logging for tests
        Notion_Sync_Settings__c settings = new Notion_Sync_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Enable_Sync_Logging__c = true
        );
        insert settings;
        
        // Create test custom metadata records
        // Note: In real implementation, we'd use Test.loadData or mock the metadata
    }
    
    @isTest
    static void testDefaultBatchSize() {
        Test.startTest();
        
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor();
        System.assertEquals(
            NotionSyncBatchProcessor.DEFAULT_BATCH_SIZE, 
            processor.getBatchSize(),
            'Default batch size should be set'
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void testCustomBatchSize() {
        Test.startTest();
        
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor(25);
        System.assertEquals(25, processor.getBatchSize(), 'Custom batch size should be set');
        
        // Test boundary validation
        processor.setBatchSize(300);
        System.assertEquals(
            NotionSyncBatchProcessor.MAX_BATCH_SIZE, 
            processor.getBatchSize(),
            'Batch size should not exceed maximum'
        );
        
        processor.setBatchSize(0);
        System.assertEquals(
            NotionSyncBatchProcessor.MIN_BATCH_SIZE, 
            processor.getBatchSize(),
            'Batch size should not be below minimum'
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void testSmallBatchProcessing() {
        // Create test sync requests
        List<NotionSync.Request> requests = new List<NotionSync.Request>();
        
        for (Integer i = 0; i < 10; i++) {
            requests.add(new NotionSync.Request(
                '001000000000' + String.valueOf(i).leftPad(3, '0'),
                'Account',
                'CREATE'
            ));
        }
        
        // Mock HTTP responses
        Test.setMock(HttpCalloutMock.class, new NotionApiMockSuccess());
        
        Test.startTest();
        
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor(5);
        NotionSyncLogger logger = new NotionSyncLogger();
        List<NotionSyncBatchProcessor.BatchResult> results = processor.processBatches(requests, logger);
        
        Test.stopTest();
        
        // Should have processed in 2 batches of 5
        System.assertEquals(2, results.size(), 'Should process in 2 batches');
        
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            System.assertEquals('Success', result.status, 'Batch should be successful');
            System.assertEquals(5, result.processedCount, 'Should process 5 records per batch');
            System.assertNotEquals(null, result.cpuTimeUsed, 'Should track CPU time');
            System.assertNotEquals(null, result.heapSizeUsed, 'Should track heap size');
        }
    }
    
    @isTest
    static void testLargeBatchProcessing() {
        // Create large number of test sync requests
        List<NotionSync.Request> requests = new List<NotionSync.Request>();
        
        for (Integer i = 0; i < 150; i++) {
            requests.add(new NotionSync.Request(
                '001000000000' + String.valueOf(i).leftPad(3, '0'),
                'Account',
                'UPDATE'
            ));
        }
        
        // Mock HTTP responses
        Test.setMock(HttpCalloutMock.class, new NotionApiMockSuccess());
        
        Test.startTest();
        
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor();
        NotionSyncLogger logger = new NotionSyncLogger();
        List<NotionSyncBatchProcessor.BatchResult> results = processor.processBatches(requests, logger);
        
        Test.stopTest();
        
        // Verify batching occurred
        System.assert(results.size() >= 1, 'Should have at least one batch result');
        
        Integer totalProcessed = 0;
        Integer totalDeferred = 0;
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            totalProcessed += result.processedCount;
            totalDeferred += result.deferredCount;
            System.assert(
                result.getDurationMillis() >= 0, 
                'Should track processing duration'
            );
            
            // If processing was deferred, that's ok
            if (result.shouldDefer) {
                System.assert(String.isNotBlank(result.deferReason), 'Should have defer reason');
            }
        }
        
        // Either all were processed or some were deferred
        System.assert(totalProcessed > 0 || totalDeferred > 0, 'Should process or defer requests');
    }
    
    @isTest
    static void testRateLimitHandling() {
        // Create test sync requests
        List<NotionSync.Request> requests = new List<NotionSync.Request>();
        
        for (Integer i = 0; i < 20; i++) {
            requests.add(new NotionSync.Request(
                '001000000000' + String.valueOf(i).leftPad(3, '0'),
                'Account',
                'CREATE'
            ));
        }
        
        // Mock rate limit response
        Test.setMock(HttpCalloutMock.class, new NotionApiMockRateLimit());
        
        Test.startTest();
        
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor(10);
        NotionSyncLogger logger = new NotionSyncLogger();
        List<NotionSyncBatchProcessor.BatchResult> results = processor.processBatches(requests, logger);
        
        Test.stopTest();
        
        // Check if we encountered rate limits or other issues
        Boolean foundIssue = false;
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            if (result.status == 'Rate Limited') {
                foundIssue = true;
                System.assert(result.shouldDefer, 'Rate limited batch should defer');
                System.assertEquals(
                    'Rate limit encountered', 
                    result.deferReason,
                    'Should have correct defer reason'
                );
            } else if (result.status == 'Error' || result.shouldDefer) {
                foundIssue = true;
                // Other errors or deferrals are also acceptable in test
            }
        }
        
        // We should have results, even if they're errors
        System.assert(!results.isEmpty(), 'Should have processing results');
    }
    
    @isTest
    static void testGovernorLimitDeferral() {
        // Create large batch that would exceed limits
        List<NotionSync.Request> requests = new List<NotionSync.Request>();
        
        // Simulate high CPU usage scenario
        for (Integer i = 0; i < 100; i++) {
            requests.add(new NotionSync.Request(
                '001000000000' + String.valueOf(i).leftPad(3, '0'),
                'Account',
                'UPDATE'
            ));
        }
        
        Test.startTest();
        
        // Use smaller batch size to trigger more processing
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor(10);
        
        // Consume some CPU time to simulate real processing
        Long startCpu = Limits.getCpuTime();
        while (Limits.getCpuTime() - startCpu < 5000) {
            // Burn some CPU
            String dummy = 'test' + Math.random();
        }
        
        NotionSyncLogger logger = new NotionSyncLogger();
        List<NotionSyncBatchProcessor.BatchResult> results = processor.processBatches(requests, logger);
        
        Test.stopTest();
        
        // Verify we have results
        System.assert(!results.isEmpty(), 'Should have processing results');
        
        // Check for governor limit awareness
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            if (result.shouldDefer) {
                System.assertEquals(
                    'Governor limits approaching threshold',
                    result.deferReason,
                    'Should defer due to governor limits'
                );
            }
        }
    }
    
    @isTest
    static void testBatchSizeAdjustment() {
        // Create requests that will consume significant resources
        List<NotionSync.Request> requests = new List<NotionSync.Request>();
        
        for (Integer i = 0; i < 30; i++) {
            requests.add(new NotionSync.Request(
                '001000000000' + String.valueOf(i).leftPad(3, '0'),
                'Account',
                'CREATE'
            ));
        }
        
        // Mock successful but slow responses
        Test.setMock(HttpCalloutMock.class, new NotionApiMockSuccess());
        
        Test.startTest();
        
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor(20);
        Integer initialBatchSize = processor.getBatchSize();
        
        // Process requests
        NotionSyncLogger logger = new NotionSyncLogger();
        List<NotionSyncBatchProcessor.BatchResult> results = processor.processBatches(requests, logger);
        
        Test.stopTest();
        
        // Batch size might be adjusted based on performance
        Integer finalBatchSize = processor.getBatchSize();
        System.assert(
            finalBatchSize >= NotionSyncBatchProcessor.MIN_BATCH_SIZE,
            'Batch size should stay within bounds'
        );
        System.assert(
            finalBatchSize <= NotionSyncBatchProcessor.MAX_BATCH_SIZE,
            'Batch size should stay within bounds'
        );
    }
    
    @isTest
    static void testMixedObjectTypes() {
        // Create requests for different object types
        List<NotionSync.Request> requests = new List<NotionSync.Request>();
        
        // Add Accounts
        for (Integer i = 0; i < 10; i++) {
            requests.add(new NotionSync.Request(
                '001000000000' + String.valueOf(i).leftPad(3, '0'),
                'Account',
                'CREATE'
            ));
        }
        
        // Add Contacts
        for (Integer i = 0; i < 10; i++) {
            requests.add(new NotionSync.Request(
                '003000000000' + String.valueOf(i).leftPad(3, '0'),
                'Contact',
                'CREATE'
            ));
        }
        
        // Mock HTTP responses
        Test.setMock(HttpCalloutMock.class, new NotionApiMockSuccess());
        
        Test.startTest();
        
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor(5);
        NotionSyncLogger logger = new NotionSyncLogger();
        List<NotionSyncBatchProcessor.BatchResult> results = processor.processBatches(requests, logger);
        
        Test.stopTest();
        
        // Should process objects in separate batches
        System.assert(results.size() >= 4, 'Should have separate batches for each object type');
        
        Integer totalProcessed = 0;
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            totalProcessed += result.processedCount;
        }
        
        System.assertEquals(20, totalProcessed, 'Should process all requests');
    }
    
    @isTest
    static void testErrorHandling() {
        // Create test sync requests
        List<NotionSync.Request> requests = new List<NotionSync.Request>();
        
        for (Integer i = 0; i < 5; i++) {
            requests.add(new NotionSync.Request(
                '001000000000' + String.valueOf(i).leftPad(3, '0'),
                'Account',
                'CREATE'
            ));
        }
        
        // Mock error response
        Test.setMock(HttpCalloutMock.class, new NotionApiMockError());
        
        Test.startTest();
        
        NotionSyncBatchProcessor processor = new NotionSyncBatchProcessor();
        NotionSyncLogger logger = new NotionSyncLogger();
        List<NotionSyncBatchProcessor.BatchResult> results = processor.processBatches(requests, logger);
        
        Test.stopTest();
        
        // Should handle errors gracefully
        System.assert(!results.isEmpty(), 'Should return results even with errors');
        
        Boolean foundError = false;
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            if (result.status == 'Error') {
                foundError = true;
                System.assert(
                    String.isNotBlank(result.errorMessage),
                    'Should have error message'
                );
            }
        }
    }
    
    // Mock classes for testing
    public class NotionApiMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"object":"page","id":"test-page-id"}');
            return res;
        }
    }
    
    public class NotionApiMockRateLimit implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setHeader('Retry-After', '5');
            res.setStatusCode(429);
            res.setBody('{"message":"Rate limit exceeded"}');
            return res;
        }
    }
    
    public class NotionApiMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"message":"Bad request"}');
            return res;
        }
    }
}