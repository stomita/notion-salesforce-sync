@isTest
private class NotionSyncLoggerTest {
    
    @testSetup
    static void setup() {
        // Create org-wide default settings for tests
        Notion_Sync_Settings__c settings = new Notion_Sync_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
        settings.put('Enable_Logging__c', true);
        settings.put('Log_Level__c', 'DEBUG');
        insert settings;
    }
    
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
    static void testLoggingDisabled() {
        // This test verifies behavior when logging is disabled
        
        Test.startTest();
        
        // Call future method
        NotionSyncLoggerTest.testLoggingDisabledAsync();
        
        Test.stopTest();
        
        // Verify no logs were created when logging was disabled
        List<Notion_Sync_Log__c> logs = [SELECT Id FROM Notion_Sync_Log__c WHERE Record_Id__c IN ('001000000000001', '001000000000002')];
        System.assertEquals(0, logs.size(), 'No logs should be created when logging is disabled');
    }
    
    @future
    static void testLoggingDisabledAsync() {
        // Disable logging in async context - get and update existing settings
        List<Notion_Sync_Settings__c> settingsList = [
            SELECT Id FROM Notion_Sync_Settings__c 
            WHERE SetupOwnerId = :UserInfo.getOrganizationId()
        ];
        
        Notion_Sync_Settings__c settings;
        if (!settingsList.isEmpty()) {
            settings = settingsList[0];
        } else {
            settings = new Notion_Sync_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        settings.put('Enable_Logging__c', false);
        upsert settings;
        
        // Add logs
        NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.log('001000000000002', 'Account', 'CREATE', 'Failed', 'Test error', 1);
        
        // Flush - should not create any logs
        NotionSyncLogger.flush();
    }
    
    @isTest
    static void testLogLevelError() {
        // Clean up any existing logs and settings
        delete [SELECT Id FROM Notion_Sync_Log__c];
        delete [SELECT Id FROM Notion_Sync_Settings__c];
        
        // Create new settings with ERROR log level
        Notion_Sync_Settings__c settings = new Notion_Sync_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
        settings.put('Enable_Logging__c', true);
        settings.put('Log_Level__c', 'ERROR');
        insert settings;
        
        Test.startTest();
        
        // Add various logs
        NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.log('001000000000002', 'Account', 'UPDATE', 'Failed', 'Test error', 1);
        NotionSyncLogger.log('001000000000003', 'Account', 'DELETE', 'Rate Limited', 'Rate limit hit', 0);
        
        // Flush logs
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // With ERROR log level, only Failed and Rate Limited logs should be created
        List<Notion_Sync_Log__c> logs = [
            SELECT Status__c FROM Notion_Sync_Log__c 
            WHERE Record_Id__c IN ('001000000000001', '001000000000002', '001000000000003')
            ORDER BY Record_Id__c
        ];
        // Even in test context, log level filtering applies
        System.assertEquals(2, logs.size(), 'Only error logs should be created');
        System.assertEquals('Failed', logs[0].Status__c);
        System.assertEquals('Rate Limited', logs[1].Status__c);
    }
    
    @isTest
    static void testLogLevelInfo() {
        // Clean up any existing logs and settings
        delete [SELECT Id FROM Notion_Sync_Log__c];
        delete [SELECT Id FROM Notion_Sync_Settings__c];
        
        // Create new settings with INFO log level
        Notion_Sync_Settings__c settings = new Notion_Sync_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
        settings.put('Enable_Logging__c', true);
        settings.put('Log_Level__c', 'INFO');
        insert settings;
        
        Test.startTest();
        
        // Add various logs
        NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.log('001000000000002', 'Account', 'UPDATE', 'Failed', 'Test error', 1);
        NotionSyncLogger.log('001000000000003', 'BatchProcess', 'BATCH', 'Success', null, 0);
        NotionSyncLogger.log('001000000000004', 'Account', 'DELETE', 'Deferred', 'Governor limits', 0);
        
        // Flush logs
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // With INFO log level, Success and Failed logs should be created (not Deferred/BatchProcess)
        List<Notion_Sync_Log__c> logs = [
            SELECT Status__c FROM Notion_Sync_Log__c 
            WHERE Record_Id__c IN ('001000000000001', '001000000000002', '001000000000003', '001000000000004')
            ORDER BY Record_Id__c
        ];
        // 2 logs should be created (Success, Failed - excluding BatchProcess and Deferred)
        System.assertEquals(2, logs.size(), 'Info level should exclude Deferred status');
    }
    
    @isTest
    static void testLogLevelDebug() {
        // Clean up any existing logs and settings
        delete [SELECT Id FROM Notion_Sync_Log__c];
        delete [SELECT Id FROM Notion_Sync_Settings__c];
        
        // Create new settings with DEBUG log level
        Notion_Sync_Settings__c settings = new Notion_Sync_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
        settings.put('Enable_Logging__c', true);
        settings.put('Log_Level__c', 'DEBUG');
        insert settings;
        
        Test.startTest();
        
        // Add various logs
        NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.log('001000000000002', 'Account', 'UPDATE', 'Failed', 'Test error', 1);
        NotionSyncLogger.log('001000000000003', 'BatchProcess', 'BATCH', 'Success', null, 0);
        NotionSyncLogger.log('001000000000004', 'Account', 'DELETE', 'Deferred', 'Governor limits', 0);
        
        // Flush logs
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // With DEBUG log level, all logs should be created
        List<Notion_Sync_Log__c> logs = [
            SELECT Status__c FROM Notion_Sync_Log__c 
            WHERE Record_Id__c IN ('001000000000001', '001000000000002', '001000000000003', '001000000000004')
            ORDER BY Record_Id__c
        ];
        System.assertEquals(4, logs.size(), 'Debug level should log everything');
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
        
        // Verify pending logs
        System.assertEquals(1, NotionSyncLogger.pendingLogs.size(), 'Should have one pending log');
        NotionSyncLogger.LogEntry entry = NotionSyncLogger.pendingLogs[0];
        System.assertEquals(true, entry.rateLimited, 'Rate limited flag should be set');
        System.assertEquals(5, entry.rateLimitRetryAfter, 'Retry after should be 5 seconds');
        
        // Flush logs
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // Verify log was created with rate limit info
        List<Notion_Sync_Log__c> logs = [
            SELECT Record_Id__c, Rate_Limited__c, Rate_Limit_Retry_After__c, CPU_Time_Used__c, Callouts_Used__c
            FROM Notion_Sync_Log__c
        ];
        System.assertEquals(1, logs.size(), 'Should have created one log record');
        System.assertEquals(true, logs[0].Rate_Limited__c, 'Rate limited flag should be saved');
        System.assertEquals(5, logs[0].Rate_Limit_Retry_After__c, 'Retry after should be saved');
        System.assertNotEquals(null, logs[0].CPU_Time_Used__c, 'CPU time should be captured');
        System.assertNotEquals(null, logs[0].Callouts_Used__c, 'Callouts used should be captured');
    }
    
    @isTest
    static void testBulkLogging() {
        Test.startTest();
        
        // Add multiple logs
        for (Integer i = 0; i < 50; i++) {
            String status = Math.mod(i, 3) == 0 ? 'Success' : 'Failed';
            NotionSyncLogger.log('00100000000000' + i, 'Account', 'CREATE', status, null, 0);
        }
        
        // Flush logs
        NotionSyncLogger.flush();
        
        Test.stopTest();
        
        // Verify all logs were created
        List<Notion_Sync_Log__c> logs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assertEquals(50, logs.size(), 'All logs should be created');
    }
    
    @isTest
    static void testLogEntrySerialization() {
        NotionSyncLogger.LogEntry entry = new NotionSyncLogger.LogEntry(
            '001000000000001',
            'Account',
            'CREATE',
            'Success',
            null,
            0,
            'test-page-id'
        );
        
        // Test JSON serialization
        String jsonString = JSON.serialize(entry);
        System.assert(jsonString.contains('"recordId":"001000000000001"'), 'JSON should contain recordId');
        
        // Test deserialization
        NotionSyncLogger.LogEntry deserializedEntry = 
            (NotionSyncLogger.LogEntry) JSON.deserialize(jsonString, NotionSyncLogger.LogEntry.class);
        System.assertEquals(entry.recordId, deserializedEntry.recordId, 'Deserialized entry should match');
    }
    
    @isTest
    static void testClearLogs() {
        // Add some logs
        NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.log('001000000000002', 'Contact', 'UPDATE', 'Failed', 'Error', 1);
        
        System.assertEquals(2, NotionSyncLogger.pendingLogs.size(), 'Should have two pending logs');
        
        // Clear logs
        NotionSyncLogger.clear();
        
        System.assertEquals(0, NotionSyncLogger.pendingLogs.size(), 'Pending logs should be cleared');
        
        // Flush should do nothing
        NotionSyncLogger.flush();
        
        // Verify no logs were created
        List<Notion_Sync_Log__c> logs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assertEquals(0, logs.size(), 'No logs should be created after clear');
    }
    
    @isTest
    static void testAsyncContextLogging() {
        Test.startTest();
        
        // Test logging from future context
        testAsyncLogging();
        
        Test.stopTest();
        
        // Verify logs were created
        List<Notion_Sync_Log__c> logs = [SELECT Status__c FROM Notion_Sync_Log__c];
        System.assertEquals(1, logs.size(), 'Log should be created from async context');
        System.assertEquals('Success', logs[0].Status__c);
    }
    
    @future
    static void testAsyncLogging() {
        NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.flush();
    }
}