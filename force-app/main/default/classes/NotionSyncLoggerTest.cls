@isTest
private class NotionSyncLoggerTest {
    
    @isTest
    static void testBasicLogging() {
        Test.startTest();
        
        // Test basic log entry
        NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0, 'test-page-id');
        
        // Verify pending logs
        System.assertEquals(1, NotionSyncLogger.pendingLogs.size(), 'Should have one pending log');
        NotionSyncLogger.LogEntry entry = NotionSyncLogger.pendingLogs[0];
        System.assertEquals('001000000000001', entry.recordId, 'Record ID should match');
        System.assertEquals('Account', entry.objectType, 'Object type should match');
        System.assertEquals('CREATE', entry.operationType, 'Operation type should match');
        System.assertEquals('Success', entry.status, 'Status should match');
        System.assertEquals('test-page-id', entry.notionPageId, 'Notion page ID should match');
        
        // Flush logs
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // Verify log was created
        List<Notion_Sync_Log__c> logs = [
            SELECT Record_Id__c, Object_Type__c, Operation_Type__c, Status__c, Notion_Page_Id__c
            FROM Notion_Sync_Log__c
        ];
        System.assertEquals(1, logs.size(), 'Should have created one log record');
        System.assertEquals('001000000000001', logs[0].Record_Id__c, 'Log record ID should match');
    }
    
    @isTest
    static void testRateLimitLogging() {
        Test.startTest();
        
        // Test rate limit log entry
        NotionSyncLogger.logWithRateLimit(
            '001000000000002', 
            'Contact', 
            'UPDATE', 
            'Failed', 
            'Rate limit exceeded. Retry after 5 seconds.',
            1,
            null,
            true,
            5
        );
        
        // Verify pending log has rate limit info
        System.assertEquals(1, NotionSyncLogger.pendingLogs.size(), 'Should have one pending log');
        NotionSyncLogger.LogEntry entry = NotionSyncLogger.pendingLogs[0];
        System.assertEquals(true, entry.rateLimited, 'Should be marked as rate limited');
        System.assertEquals(5, entry.rateLimitRetryAfter, 'Retry after seconds should match');
        System.assert(entry.cpuTimeUsed >= 0, 'CPU time should be captured');
        System.assert(entry.calloutsUsed >= 0, 'Callouts used should be captured');
        
        // Update API calls made
        entry.apiCallsMade = 3;
        
        // Flush logs
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // Verify log was created with rate limit fields
        List<Notion_Sync_Log__c> logs = [
            SELECT Rate_Limited__c, Rate_Limit_Retry_After__c, API_Calls_Made__c, 
                   CPU_Time_Used__c, Callouts_Used__c
            FROM Notion_Sync_Log__c
        ];
        System.assertEquals(1, logs.size(), 'Should have created one log record');
        System.assertEquals(true, logs[0].Rate_Limited__c, 'Should be marked as rate limited');
        System.assertEquals(5, logs[0].Rate_Limit_Retry_After__c, 'Retry after should match');
        System.assertEquals(3, logs[0].API_Calls_Made__c, 'API calls made should match');
        System.assert(logs[0].CPU_Time_Used__c >= 0, 'CPU time should be logged');
        System.assert(logs[0].Callouts_Used__c >= 0, 'Callouts used should be logged');
    }
    
    @isTest
    static void testBulkLogging() {
        Test.startTest();
        
        // Add multiple log entries
        for (Integer i = 0; i < 10; i++) {
            NotionSyncLogger.log(
                '00100000000000' + i, 
                'Account', 
                'CREATE', 
                'Success', 
                null, 
                0,
                'page-' + i
            );
        }
        
        System.assertEquals(10, NotionSyncLogger.pendingLogs.size(), 'Should have 10 pending logs');
        
        // Flush logs
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // Verify all logs were created
        List<Notion_Sync_Log__c> logs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assertEquals(10, logs.size(), 'Should have created 10 log records');
    }
    
    @isTest
    static void testErrorLogging() {
        Test.startTest();
        
        // Test error log entry
        NotionSyncLogger.log(
            '001000000000003', 
            'Opportunity', 
            'DELETE', 
            'Failed', 
            'Record not found in Notion',
            2
        );
        
        // Verify error details
        NotionSyncLogger.LogEntry entry = NotionSyncLogger.pendingLogs[0];
        System.assertEquals('Failed', entry.status, 'Status should be Failed');
        System.assertEquals('Record not found in Notion', entry.errorMessage, 'Error message should match');
        System.assertEquals(2, entry.retryCount, 'Retry count should match');
        
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // Verify error was logged
        List<Notion_Sync_Log__c> logs = [
            SELECT Status__c, Error_Message__c, Retry_Count__c
            FROM Notion_Sync_Log__c
        ];
        System.assertEquals('Failed', logs[0].Status__c, 'Status should be Failed');
        System.assertEquals('Record not found in Notion', logs[0].Error_Message__c, 'Error message should match');
        System.assertEquals(2, logs[0].Retry_Count__c, 'Retry count should match');
    }
    
    @isTest
    static void testClearLogs() {
        Test.startTest();
        
        // Add some logs
        NotionSyncLogger.log('001000000000004', 'Lead', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.log('001000000000005', 'Lead', 'UPDATE', 'Failed', 'Error', 0);
        
        System.assertEquals(2, NotionSyncLogger.pendingLogs.size(), 'Should have 2 pending logs');
        
        // Clear logs without saving
        NotionSyncLogger.clear();
        
        System.assertEquals(0, NotionSyncLogger.pendingLogs.size(), 'Pending logs should be cleared');
        
        Test.stopTest();
        
        // Verify no logs were created
        List<Notion_Sync_Log__c> logs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assertEquals(0, logs.size(), 'No logs should have been created');
    }
    
    @isTest
    static void testFutureContextLogging() {
        // This test simulates logging from a future context
        Test.startTest();
        
        // Call a method that would simulate future context behavior
        NotionSyncLoggerTest.simulateFutureLogging();
        
        Test.stopTest();
        
        // Verify log was created
        List<Notion_Sync_Log__c> logs = [SELECT Record_Id__c FROM Notion_Sync_Log__c];
        System.assertEquals(1, logs.size(), 'Should have created one log record');
        System.assertEquals('001FUTURE000001', logs[0].Record_Id__c, 'Log should be from future context');
    }
    
    @future
    static void simulateFutureLogging() {
        NotionSyncLogger.log('001FUTURE000001', 'Account', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.flush();
    }
}