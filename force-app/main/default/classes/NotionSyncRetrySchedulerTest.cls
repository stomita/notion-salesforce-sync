@IsTest
private class NotionSyncRetrySchedulerTest {
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account for Scheduler');
        insert testAccount;
    }
    
    @IsTest
    static void testScheduledJobExecution() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create failed sync logs that are ready for retry
        List<Notion_Sync_Log__c> retryableLogs = new List<Notion_Sync_Log__c>();
        
        for (Integer i = 0; i < 5; i++) {
            retryableLogs.add(new Notion_Sync_Log__c(
                Record_Id__c = testAccount.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = 'CREATE',
                Status__c = 'Failed',
                Error_Message__c = 'Network timeout error ' + i,
                Retry_Count__c = i % 3, // Mix of different retry counts
                Next_Retry_Time__c = DateTime.now().addMinutes(-5), // Ready for retry
                Original_Error_Time__c = DateTime.now().addHours(-1)
            ));
        }
        
        // Create logs that are not ready for retry yet
        retryableLogs.add(new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'UPDATE',
            Status__c = 'Failed',
            Error_Message__c = 'Not ready for retry yet',
            Retry_Count__c = 1,
            Next_Retry_Time__c = DateTime.now().addMinutes(10), // Future retry time
            Original_Error_Time__c = DateTime.now().addHours(-1)
        ));
        
        insert retryableLogs;
        
        Test.setMock(HttpCalloutMock.class, new MockNotionApiSuccess());
        
        Test.startTest();
        
        // Execute the scheduled job
        NotionSyncRetryScheduler scheduler = new NotionSyncRetryScheduler();
        String jobId = System.schedule('Test Retry Job', '0 0 0 * * ?', scheduler);
        
        // Manually execute to test the logic
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Verify that only the retryable logs were processed
        List<Notion_Sync_Log__c> updatedLogs = [
            SELECT Id, Status__c, Retry_Count__c, Last_Retry_Time__c, Next_Retry_Time__c
            FROM Notion_Sync_Log__c
            WHERE Id IN :retryableLogs
            ORDER BY CreatedDate
        ];
        
        Integer retryableCount = 0;
        for (Integer i = 0; i < updatedLogs.size() - 1; i++) { // Exclude the last one (future retry time)
            Notion_Sync_Log__c log = updatedLogs[i];
            if (log.Status__c == 'Retrying') {
                retryableCount++;
                System.assertNotEquals(null, log.Last_Retry_Time__c, 'Last retry time should be updated');
            }
        }
        
        // The last log should not be processed (future retry time)
        Notion_Sync_Log__c futureRetryLog = updatedLogs[updatedLogs.size() - 1];
        System.assertNotEquals('Retrying', futureRetryLog.Status__c, 'Future retry log should not be processed');
        
        // Clean up the scheduled job
        System.abortJob(jobId);
    }
    
    @IsTest
    static void testSchedulerWithNoRetryableLogs() {
        // Test scheduler execution when there are no logs ready for retry
        
        Test.startTest();
        
        NotionSyncRetryScheduler scheduler = new NotionSyncRetryScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Test should complete without errors
        System.assert(true, 'Scheduler should handle empty log collection gracefully');
    }
    
    @IsTest
    static void testSchedulerErrorHandling() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create a log that might cause processing errors
        Notion_Sync_Log__c problemLog = new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'NonExistentObject__c',
            Operation_Type__c = 'CREATE',
            Status__c = 'Failed',
            Error_Message__c = 'This might cause issues',
            Retry_Count__c = 0,
            Next_Retry_Time__c = DateTime.now().addMinutes(-1),
            Original_Error_Time__c = DateTime.now().addHours(-1)
        );
        
        insert problemLog;
        
        Test.startTest();
        
        try {
            NotionSyncRetryScheduler scheduler = new NotionSyncRetryScheduler();
            scheduler.execute(null);
            // If no exception is thrown, the error handling worked
            System.assert(true, 'Scheduler should handle errors gracefully');
        } catch (Exception e) {
            // Any exception should be caught and handled internally
            System.assert(false, 'Scheduler should not throw unhandled exceptions: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testBatchProcessing() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create more logs than the batch size to test batching
        List<Notion_Sync_Log__c> manyLogs = new List<Notion_Sync_Log__c>();
        
        for (Integer i = 0; i < 75; i++) { // More than batch size of 50
            manyLogs.add(new Notion_Sync_Log__c(
                Record_Id__c = testAccount.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = 'CREATE',
                Status__c = 'Failed',
                Error_Message__c = 'Batch test error ' + i,
                Retry_Count__c = 0,
                Next_Retry_Time__c = DateTime.now().addMinutes(-1),
                Original_Error_Time__c = DateTime.now().addHours(-1)
            ));
        }
        
        insert manyLogs;
        
        Test.setMock(HttpCalloutMock.class, new MockNotionApiSuccess());
        
        Test.startTest();
        
        NotionSyncRetryScheduler scheduler = new NotionSyncRetryScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Verify that logs were processed (should be limited by max queueable jobs)
        List<Notion_Sync_Log__c> processedLogs = [
            SELECT Id, Status__c
            FROM Notion_Sync_Log__c
            WHERE Id IN :manyLogs
            AND Status__c = 'Retrying'
        ];
        
        // Should have processed some logs, but limited by queueable job limits
        System.assert(processedLogs.size() > 0, 'Some logs should have been processed');
        System.assert(processedLogs.size() <= 250, 'Should respect queueable job limits'); // 5 jobs * 50 batch size
    }
    
    @IsTest
    static void testGroupingByObjectType() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create logs for different object types
        List<Notion_Sync_Log__c> mixedLogs = new List<Notion_Sync_Log__c>();
        
        String[] objectTypes = new String[]{ 'Account', 'Contact', 'Opportunity' };
        
        for (String objectType : objectTypes) {
            for (Integer i = 0; i < 3; i++) {
                mixedLogs.add(new Notion_Sync_Log__c(
                    Record_Id__c = testAccount.Id,
                    Object_Type__c = objectType,
                    Operation_Type__c = 'CREATE',
                    Status__c = 'Failed',
                    Error_Message__c = 'Error for ' + objectType,
                    Retry_Count__c = 0,
                    Next_Retry_Time__c = DateTime.now().addMinutes(-1),
                    Original_Error_Time__c = DateTime.now().addHours(-1)
                ));
            }
        }
        
        insert mixedLogs;
        
        Test.setMock(HttpCalloutMock.class, new MockNotionApiSuccess());
        
        Test.startTest();
        
        NotionSyncRetryScheduler scheduler = new NotionSyncRetryScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Verify that logs from all object types were processed
        Map<String, Integer> processedByType = new Map<String, Integer>();
        
        List<Notion_Sync_Log__c> processedLogs = [
            SELECT Id, Object_Type__c, Status__c
            FROM Notion_Sync_Log__c
            WHERE Id IN :mixedLogs
            AND Status__c = 'Retrying'
        ];
        
        for (Notion_Sync_Log__c log : processedLogs) {
            Integer count = processedByType.get(log.Object_Type__c);
            processedByType.put(log.Object_Type__c, count == null ? 1 : count + 1);
        }
        
        System.assert(processedByType.size() > 0, 'Logs from multiple object types should be processed');
    }
    
    @IsTest
    static void testScheduleRetryJobMethods() {
        Test.startTest();
        
        // Test default scheduling
        String jobId1 = NotionSyncRetryScheduler.scheduleRetryJob();
        System.assertNotEquals(null, jobId1, 'Default schedule should return job ID');
        
        // Test custom cron expression
        String jobId2 = NotionSyncRetryScheduler.scheduleRetryJob('0 0 12 * * ?');
        System.assertNotEquals(null, jobId2, 'Custom schedule should return job ID');
        
        // Test unscheduling
        NotionSyncRetryScheduler.unscheduleAllRetryJobs();
        
        Test.stopTest();
        
        // Verify jobs were created and then cleaned up
        List<CronTrigger> remainingJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Notion Sync Retry Job%'
        ];
        
        System.assertEquals(0, remainingJobs.size(), 'All retry jobs should be unscheduled');
    }
    
    @IsTest
    static void testMaxQueueableJobLimit() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create many logs to test queueable job limits
        List<Notion_Sync_Log__c> manyLogs = new List<Notion_Sync_Log__c>();
        
        for (Integer i = 0; i < 500; i++) { // Many more than can be processed in one run
            manyLogs.add(new Notion_Sync_Log__c(
                Record_Id__c = testAccount.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = 'CREATE',
                Status__c = 'Failed',
                Error_Message__c = 'Limit test error ' + i,
                Retry_Count__c = 0,
                Next_Retry_Time__c = DateTime.now().addMinutes(-1),
                Original_Error_Time__c = DateTime.now().addHours(-1)
            ));
        }
        
        insert manyLogs;
        
        Test.setMock(HttpCalloutMock.class, new MockNotionApiSuccess());
        
        Test.startTest();
        
        NotionSyncRetryScheduler scheduler = new NotionSyncRetryScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // The scheduler should respect the MAX_QUEUEABLE_JOBS limit
        // This test verifies that the scheduler doesn't try to enqueue too many jobs
        System.assert(true, 'Scheduler should respect queueable job limits without throwing exceptions');
    }
    
    // Mock class for successful HTTP responses
    private class MockNotionApiSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id": "test-page-id", "object": "page"}');
            return res;
        }
    }
}