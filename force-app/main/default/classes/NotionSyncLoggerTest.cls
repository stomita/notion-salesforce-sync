@isTest
private class NotionSyncLoggerTest {
    
    @TestSetup
    static void setup() {
        // Enable sync logging for tests
        Notion_Sync_Settings__c settings = new Notion_Sync_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Enable_Sync_Logging__c = true
        );
        insert settings;
    }
    
    @isTest
    static void testBasicLogging() {
        Test.startTest();
        
        // Create logger instance
        NotionSyncLogger logger = new NotionSyncLogger();
        
        // Test basic log entry
        logger.log(
            logger.createLogEntry('001000000000001', 'Account', 'CREATE')
                .withStatus('Success')
                .withNotionPageId('test-page-id')
        );
        
        // Flush logs
        logger.flush();
        
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
        
        // Create logger instance
        NotionSyncLogger logger = new NotionSyncLogger();
        
        // Test rate limit log entry with builder pattern
        NotionSyncLogger.LogEntry entry = logger.createLogEntry(
            '001000000000002', 
            'Contact', 
            'UPDATE'
        )
        .withRateLimit(5)
        .withMetrics(3, 100)
        .withRetryCount(1)
        .withError('Rate limit exceeded. Retry after 5 seconds.');
        
        logger.log(entry);
        
        // Flush logs
        logger.flush();
        
        Test.stopTest();
        
        // Verify log was created with rate limit fields
        List<Notion_Sync_Log__c> logs = [
            SELECT Rate_Limited__c, Rate_Limit_Retry_After__c, API_Calls_Made__c, 
                   CPU_Time_Used__c, Callouts_Used__c, Status__c
            FROM Notion_Sync_Log__c
        ];
        System.assertEquals(1, logs.size(), 'Should have created one log record');
        System.assertEquals(true, logs[0].Rate_Limited__c, 'Should be marked as rate limited');
        System.assertEquals(5, logs[0].Rate_Limit_Retry_After__c, 'Retry after should match');
        System.assertEquals(3, logs[0].API_Calls_Made__c, 'API calls made should match');
        System.assertEquals(100, logs[0].CPU_Time_Used__c, 'CPU time should match');
        System.assertEquals('Rate Limited', logs[0].Status__c, 'Status should be Rate Limited');
        System.assert(logs[0].Callouts_Used__c >= 0, 'Callouts used should be logged');
    }
    
    @isTest
    static void testBulkLogging() {
        Test.startTest();
        
        // Create logger instance
        NotionSyncLogger logger = new NotionSyncLogger();
        
        // Add multiple log entries
        for (Integer i = 0; i < 10; i++) {
            logger.log(
                logger.createLogEntry('00100000000000' + i, 'Account', 'CREATE')
                    .withStatus('Success')
                    .withNotionPageId('page-' + i)
            );
        }
        
        // Flush logs
        logger.flush();
        
        Test.stopTest();
        
        // Verify all logs were created
        List<Notion_Sync_Log__c> logs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assertEquals(10, logs.size(), 'Should have created 10 log records');
    }
    
    @isTest
    static void testErrorLogging() {
        Test.startTest();
        
        // Create logger instance
        NotionSyncLogger logger = new NotionSyncLogger();
        
        // Test error log entry
        logger.log(
            logger.createLogEntry('001000000000003', 'Opportunity', 'DELETE')
                .withError('Record not found in Notion')
                .withRetryCount(2)
        );
        
        logger.flush();
        
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
        
        // Create logger instance
        NotionSyncLogger logger = new NotionSyncLogger();
        
        // Add some logs
        logger.log('001000000000004', 'Lead', 'CREATE');
        logger.log(
            logger.createLogEntry('001000000000005', 'Lead', 'UPDATE')
                .withError('Error')
        );
        
        // Clear logs without saving
        logger.clear();
        
        // After clearing, trying to flush should create no records
        logger.flush();
        
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
        NotionSyncLogger logger = new NotionSyncLogger();
        logger.log('001FUTURE000001', 'Account', 'CREATE');
        logger.flush();
    }
    
    @isTest
    static void testLoggingDisabledByDefault() {
        // Delete the settings created in setup to test default behavior
        delete [SELECT Id FROM Notion_Sync_Settings__c];
        
        Test.startTest();
        
        // Create logger instance
        NotionSyncLogger logger = new NotionSyncLogger();
        
        // Try to log when logging is disabled
        logger.log('001000000000001', 'Account', 'CREATE');
        
        // Try to flush (should do nothing)
        logger.flush();
        
        Test.stopTest();
        
        // Verify no logs were created
        List<Notion_Sync_Log__c> logs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created when logging is disabled');
    }
}