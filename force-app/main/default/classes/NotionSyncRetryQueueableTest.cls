@IsTest
private class NotionSyncRetryQueueableTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test data for Account object
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create a sync configuration
        // Note: In real org, this would be Custom Metadata - this is for test isolation
    }
    
    @IsTest
    static void testRetryableLogsAreProcessed() {
        // Create test sync logs that are ready for retry
        List<Notion_Sync_Log__c> testLogs = new List<Notion_Sync_Log__c>();
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        for (Integer i = 0; i < 3; i++) {
            testLogs.add(new Notion_Sync_Log__c(
                Record_Id__c = testAccount.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = 'CREATE',
                Status__c = 'Failed',
                Error_Message__c = 'Network timeout error',
                Retry_Count__c = i,
                Next_Retry_Time__c = DateTime.now().addMinutes(-1),
                Original_Error_Time__c = DateTime.now().addHours(-1)
            ));
        }
        
        insert testLogs;
        
        List<Id> logIds = new List<Id>();
        for (Notion_Sync_Log__c log : testLogs) {
            logIds.add(log.Id);
        }
        
        Test.setMock(HttpCalloutMock.class, new MockNotionApiSuccess());
        
        Test.startTest();
        NotionSyncRetryQueueable retryJob = new NotionSyncRetryQueueable(logIds);
        System.enqueueJob(retryJob);
        Test.stopTest();
        
        // Verify that logs were updated with retry information
        List<Notion_Sync_Log__c> updatedLogs = [
            SELECT Id, Status__c, Retry_Count__c, Last_Retry_Time__c, Next_Retry_Time__c
            FROM Notion_Sync_Log__c
            WHERE Id IN :logIds
        ];
        
        for (Notion_Sync_Log__c log : updatedLogs) {
            System.assertEquals('Retrying', log.Status__c, 'Log status should be updated to Retrying');
            System.assertNotEquals(null, log.Last_Retry_Time__c, 'Last retry time should be set');
            System.assertNotEquals(null, log.Next_Retry_Time__c, 'Next retry time should be calculated');
        }
    }
    
    @IsTest
    static void testRetryExhaustedLogs() {
        // Create test sync logs that have exceeded max retry attempts
        List<Notion_Sync_Log__c> testLogs = new List<Notion_Sync_Log__c>();
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        testLogs.add(new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE',
            Status__c = 'Failed',
            Error_Message__c = 'Network timeout error',
            Retry_Count__c = 3, // Max retries exceeded
            Next_Retry_Time__c = DateTime.now().addMinutes(-1),
            Original_Error_Time__c = DateTime.now().addHours(-1)
        ));
        
        insert testLogs;
        
        List<Id> logIds = new List<Id>();
        for (Notion_Sync_Log__c log : testLogs) {
            logIds.add(log.Id);
        }
        
        Test.startTest();
        NotionSyncRetryQueueable retryJob = new NotionSyncRetryQueueable(logIds);
        System.enqueueJob(retryJob);
        Test.stopTest();
        
        // Verify that logs status remains Failed and no retry time is set
        List<Notion_Sync_Log__c> updatedLogs = [
            SELECT Id, Status__c, Retry_Count__c, Next_Retry_Time__c
            FROM Notion_Sync_Log__c
            WHERE Id IN :logIds
        ];
        
        for (Notion_Sync_Log__c log : updatedLogs) {
            System.assertEquals('Failed', log.Status__c, 'Log status should remain Failed when retries exhausted');
            System.assertEquals(null, log.Next_Retry_Time__c, 'Next retry time should be null when retries exhausted');
        }
    }
    
    @IsTest
    static void testNonRetryableErrors() {
        // Create test sync logs with non-retryable errors
        List<Notion_Sync_Log__c> testLogs = new List<Notion_Sync_Log__c>();
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<String> nonRetryableErrors = new List<String>{
            'Unauthorized access - invalid token',
            'Authentication failed',
            'Validation error in request',
            'Invalid database ID provided'
        };
        
        for (String errorMessage : nonRetryableErrors) {
            testLogs.add(new Notion_Sync_Log__c(
                Record_Id__c = testAccount.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = 'CREATE',
                Status__c = 'Failed',
                Error_Message__c = errorMessage,
                Retry_Count__c = 0,
                Next_Retry_Time__c = DateTime.now().addMinutes(-1),
                Original_Error_Time__c = DateTime.now().addHours(-1)
            ));
        }
        
        insert testLogs;
        
        List<Id> logIds = new List<Id>();
        for (Notion_Sync_Log__c log : testLogs) {
            logIds.add(log.Id);
        }
        
        Test.startTest();
        NotionSyncRetryQueueable retryJob = new NotionSyncRetryQueueable(logIds);
        System.enqueueJob(retryJob);
        Test.stopTest();
        
        // Verify that logs with non-retryable errors are not retried
        List<Notion_Sync_Log__c> updatedLogs = [
            SELECT Id, Status__c, Retry_Count__c, Next_Retry_Time__c
            FROM Notion_Sync_Log__c
            WHERE Id IN :logIds
        ];
        
        for (Notion_Sync_Log__c log : updatedLogs) {
            System.assertEquals('Failed', log.Status__c, 'Log status should remain Failed for non-retryable errors');
            System.assertEquals(null, log.Next_Retry_Time__c, 'Next retry time should be null for non-retryable errors');
        }
    }
    
    @IsTest
    static void testExponentialBackoffCalculation() {
        // Create test sync log to test exponential backoff
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Notion_Sync_Log__c testLog = new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE',
            Status__c = 'Failed',
            Error_Message__c = 'Network timeout error',
            Retry_Count__c = 1,
            Next_Retry_Time__c = DateTime.now().addMinutes(-1),
            Original_Error_Time__c = DateTime.now().addHours(-1)
        );
        
        insert testLog;
        
        DateTime testStartTime = DateTime.now();
        
        Test.startTest();
        NotionSyncRetryQueueable retryJob = new NotionSyncRetryQueueable(new List<Id>{ testLog.Id });
        System.enqueueJob(retryJob);
        Test.stopTest();
        
        // Verify exponential backoff calculation
        Notion_Sync_Log__c updatedLog = [
            SELECT Id, Status__c, Retry_Count__c, Next_Retry_Time__c
            FROM Notion_Sync_Log__c
            WHERE Id = :testLog.Id
        ];
        
        System.assertEquals('Retrying', updatedLog.Status__c, 'Log status should be Retrying');
        System.assertEquals(2, updatedLog.Retry_Count__c, 'Retry count should be incremented');
        
        // With retry count 2, exponential backoff should be 5 * 2^2 = 20 minutes
        DateTime expectedNextRetry = testStartTime.addMinutes(20);
        Long timeDiffMinutes = (updatedLog.Next_Retry_Time__c.getTime() - expectedNextRetry.getTime()) / (1000 * 60);
        System.assert(Math.abs(timeDiffMinutes) <= 1, 'Next retry time should follow exponential backoff pattern');
    }
    
    @IsTest
    static void testEmptyLogList() {
        Test.startTest();
        NotionSyncRetryQueueable retryJob = new NotionSyncRetryQueueable(new List<Id>());
        System.enqueueJob(retryJob);
        Test.stopTest();
        
        // Test should complete without errors
        System.assert(true, 'Empty log list should be handled gracefully');
    }
    
    @IsTest
    static void testCustomRetryConfiguration() {
        // This test would verify custom retry configuration behavior
        // In a real implementation, you would create Custom Metadata records
        // For unit testing, we focus on the logic assuming default configuration
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Notion_Sync_Log__c testLog = new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'CustomObject__c',
            Operation_Type__c = 'UPDATE',
            Status__c = 'Failed',
            Error_Message__c = 'Temporary service unavailable',
            Retry_Count__c = 0,
            Next_Retry_Time__c = DateTime.now().addMinutes(-1),
            Original_Error_Time__c = DateTime.now().addHours(-1)
        );
        
        insert testLog;
        
        Test.startTest();
        NotionSyncRetryQueueable retryJob = new NotionSyncRetryQueueable(new List<Id>{ testLog.Id });
        System.enqueueJob(retryJob);
        Test.stopTest();
        
        // Verify default configuration is applied
        Notion_Sync_Log__c updatedLog = [
            SELECT Id, Status__c, Retry_Count__c, Next_Retry_Time__c
            FROM Notion_Sync_Log__c
            WHERE Id = :testLog.Id
        ];
        
        System.assertEquals('Retrying', updatedLog.Status__c, 'Log status should be updated to Retrying');
        System.assertEquals(1, updatedLog.Retry_Count__c, 'Retry count should be incremented');
        System.assertNotEquals(null, updatedLog.Next_Retry_Time__c, 'Next retry time should be calculated');
    }
    
    // Mock classes for HTTP callouts
    private class MockNotionApiSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id": "test-page-id", "object": "page"}');
            return res;
        }
    }
    
    private class MockNotionApiError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"object": "error", "status": 500, "message": "Internal server error"}');
            return res;
        }
    }
}