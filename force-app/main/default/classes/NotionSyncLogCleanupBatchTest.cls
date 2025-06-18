@isTest
private class NotionSyncLogCleanupBatchTest {
    
    @testSetup
    static void setup() {
        // Create custom setting with 7 day retention
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
        settings.put('Enable_Logging__c', true);
        settings.put('Log_Level__c', 'DEBUG');
        settings.put('Retention_Days__c', 7);
        upsert settings;
        
        // Create test logs with various ages
        List<Notion_Sync_Log__c> logs = new List<Notion_Sync_Log__c>();
        
        // Old logs (should be deleted)
        for (Integer i = 0; i < 10; i++) {
            Notion_Sync_Log__c log = new Notion_Sync_Log__c(
                Record_Id__c = '00100000000000' + i,
                Object_Type__c = 'Account',
                Operation_Type__c = 'CREATE',
                Status__c = 'Success'
            );
            logs.add(log);
        }
        
        // Recent logs (should be kept)
        for (Integer i = 10; i < 20; i++) {
            Notion_Sync_Log__c log = new Notion_Sync_Log__c(
                Record_Id__c = '00100000000000' + i,
                Object_Type__c = 'Contact',
                Operation_Type__c = 'UPDATE',
                Status__c = 'Success'
            );
            logs.add(log);
        }
        
        insert logs;
        
        // Update created date for old logs using Test.setCreatedDate
        List<Notion_Sync_Log__c> oldLogs = [
            SELECT Id 
            FROM Notion_Sync_Log__c 
            WHERE Object_Type__c = 'Account'
        ];
        
        for (Notion_Sync_Log__c log : oldLogs) {
            Test.setCreatedDate(log.Id, DateTime.now().addDays(-10));
        }
    }
    
    @isTest
    static void testBatchCleanup() {
        // Verify initial state
        List<Notion_Sync_Log__c> allLogs = [SELECT Id FROM Notion_Sync_Log__c];
        System.assertEquals(20, allLogs.size(), 'Should have 20 logs initially');
        
        Test.startTest();
        
        // Execute batch
        Database.executeBatch(new NotionSyncLogCleanupBatch(), 200);
        
        Test.stopTest();
        
        // Verify old logs were deleted
        List<Notion_Sync_Log__c> remainingLogs = [
            SELECT Object_Type__c 
            FROM Notion_Sync_Log__c
        ];
        System.assertEquals(10, remainingLogs.size(), 'Should have 10 logs after cleanup');
        
        // Verify only recent logs remain
        for (Notion_Sync_Log__c log : remainingLogs) {
            System.assertEquals('Contact', log.Object_Type__c, 'Only Contact logs should remain');
        }
    }
    
    @isTest
    static void testCustomRetentionDays() {
        // Update retention to 5 days
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
        settings.put('Retention_Days__c', 5);
        upsert settings;
        
        // Create a log that's 6 days old (should be deleted with 5 day retention)
        Notion_Sync_Log__c midAgeLog = new Notion_Sync_Log__c(
            Record_Id__c = '001000000000099',
            Object_Type__c = 'Lead',
            Operation_Type__c = 'CREATE',
            Status__c = 'Success'
        );
        insert midAgeLog;
        Test.setCreatedDate(midAgeLog.Id, DateTime.now().addDays(-6));
        
        Test.startTest();
        
        // Execute batch
        Database.executeBatch(new NotionSyncLogCleanupBatch(), 200);
        
        Test.stopTest();
        
        // Verify mid-age log was deleted
        List<Notion_Sync_Log__c> leadLogs = [
            SELECT Id 
            FROM Notion_Sync_Log__c 
            WHERE Object_Type__c = 'Lead'
        ];
        System.assertEquals(0, leadLogs.size(), 'Lead log should be deleted with 5 day retention');
    }
    
    @isTest
    static void testNoRetentionSetting() {
        // Remove custom setting
        delete [SELECT Id FROM Notion_Sync_Settings__c];
        
        Test.startTest();
        
        // Execute batch - should use default 7 days
        Database.executeBatch(new NotionSyncLogCleanupBatch(), 200);
        
        Test.stopTest();
        
        // Verify default behavior (7 day retention)
        List<Notion_Sync_Log__c> remainingLogs = [
            SELECT Object_Type__c 
            FROM Notion_Sync_Log__c
        ];
        System.assertEquals(10, remainingLogs.size(), 'Should use default 7 day retention');
    }
    
    @isTest
    static void testSchedulableExecution() {
        Test.startTest();
        
        // Test schedulable interface
        NotionSyncLogCleanupBatch schedulable = new NotionSyncLogCleanupBatch();
        schedulable.execute(null);
        
        Test.stopTest();
        
        // Verify batch was executed
        List<Notion_Sync_Log__c> remainingLogs = [
            SELECT Object_Type__c 
            FROM Notion_Sync_Log__c
        ];
        System.assertEquals(10, remainingLogs.size(), 'Schedulable should execute batch');
    }
    
    @isTest
    static void testScheduleCleanup() {
        // Delete any existing scheduled jobs
        List<CronTrigger> existingJobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = 'Notion Sync Log Cleanup'
        ];
        if (!existingJobs.isEmpty()) {
            System.abortJob(existingJobs[0].Id);
        }
        
        Test.startTest();
        
        // Schedule the job
        String jobId = NotionSyncLogCleanupBatch.scheduleCleanup();
        
        Test.stopTest();
        
        // Verify job was scheduled
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression 
            FROM CronTrigger 
            WHERE Id = :jobId
        ];
        System.assertEquals(1, scheduledJobs.size(), 'Job should be scheduled');
        System.assertEquals('0 0 2 * * ?', scheduledJobs[0].CronExpression, 'Should run at 2 AM daily');
        
        // Test scheduling again - should not create duplicate
        String jobId2 = NotionSyncLogCleanupBatch.scheduleCleanup();
        // Salesforce may append additional characters to job IDs
        System.assert(jobId2.startsWith(jobId.substring(0, 15)), 'Should return existing job ID with same prefix');
    }
    
    @isTest
    static void testEmptyBatch() {
        // Delete all logs
        delete [SELECT Id FROM Notion_Sync_Log__c];
        
        Test.startTest();
        
        // Execute batch with no logs
        Database.executeBatch(new NotionSyncLogCleanupBatch(), 200);
        
        Test.stopTest();
        
        // Should complete without errors
        System.assertEquals(0, [SELECT COUNT() FROM Notion_Sync_Log__c], 'No logs should exist');
    }
}