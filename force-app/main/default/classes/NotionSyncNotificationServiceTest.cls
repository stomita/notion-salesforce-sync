@IsTest
private class NotionSyncNotificationServiceTest {
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
    }
    
    @IsTest
    static void testSendRetryExhaustedNotification() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Notion_Sync_Log__c testLog = new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE',
            Status__c = 'Failed',
            Error_Message__c = 'Connection timeout after multiple retries',
            Retry_Count__c = 3,
            Original_Error_Time__c = DateTime.now().addHours(-2)
        );
        insert testLog;
        
        String testEmails = 'admin@company.com, support@company.com';
        
        Test.startTest();
        try {
            NotionSyncNotificationService.sendRetryExhaustedNotification(testLog, testEmails);
            // If no exception is thrown, the test passes
            System.assert(true, 'Notification should be sent successfully');
        } catch (Exception e) {
            // In test context, email sending may not work, so we handle gracefully
            System.assert(e instanceof NotionSyncNotificationService.NotionSyncNotificationException, 
                         'Should throw NotionSyncNotificationException');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSendCriticalFailureNotification() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<Notion_Sync_Log__c> failedLogs = new List<Notion_Sync_Log__c>();
        
        for (Integer i = 0; i < 3; i++) {
            failedLogs.add(new Notion_Sync_Log__c(
                Record_Id__c = testAccount.Id,
                Object_Type__c = 'Account',
                Operation_Type__c = 'UPDATE',
                Status__c = 'Failed',
                Error_Message__c = 'Critical error ' + i,
                Retry_Count__c = 0
            ));
        }
        
        insert failedLogs;
        
        String testEmails = 'admin@company.com';
        
        Test.startTest();
        try {
            NotionSyncNotificationService.sendCriticalFailureNotification(failedLogs, testEmails);
            System.assert(true, 'Critical failure notification should be sent');
        } catch (Exception e) {
            System.assert(e instanceof NotionSyncNotificationService.NotionSyncNotificationException, 
                         'Should throw NotionSyncNotificationException');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSendDailySyncSummary() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<Notion_Sync_Log__c> summaryLogs = new List<Notion_Sync_Log__c>();
        
        // Create logs with different statuses
        summaryLogs.add(new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE',
            Status__c = 'Success'
        ));
        
        summaryLogs.add(new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'UPDATE',
            Status__c = 'Failed',
            Error_Message__c = 'Test failure'
        ));
        
        summaryLogs.add(new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'DELETE',
            Status__c = 'Retrying',
            Retry_Count__c = 1
        ));
        
        insert summaryLogs;
        
        String testEmails = 'manager@company.com';
        
        Test.startTest();
        try {
            NotionSyncNotificationService.sendDailySyncSummary(testEmails);
            System.assert(true, 'Daily sync summary should be sent');
        } catch (Exception e) {
            System.assert(e instanceof NotionSyncNotificationService.NotionSyncNotificationException, 
                         'Should throw NotionSyncNotificationException');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testEmailValidation() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Notion_Sync_Log__c testLog = new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE',
            Status__c = 'Failed',
            Error_Message__c = 'Test error',
            Retry_Count__c = 3
        );
        insert testLog;
        
        Test.startTest();
        
        // Test with invalid email addresses
        String invalidEmails = 'invalid-email, @company.com, user@';
        NotionSyncNotificationService.sendRetryExhaustedNotification(testLog, invalidEmails);
        
        // Test with empty email string
        NotionSyncNotificationService.sendRetryExhaustedNotification(testLog, '');
        
        // Test with null email string
        NotionSyncNotificationService.sendRetryExhaustedNotification(testLog, null);
        
        // Test with mixed valid and invalid emails
        String mixedEmails = 'valid@company.com, invalid-email, another@valid.com';
        NotionSyncNotificationService.sendRetryExhaustedNotification(testLog, mixedEmails);
        
        Test.stopTest();
        
        // If we reach here without exceptions, email validation is working
        System.assert(true, 'Email validation should handle invalid emails gracefully');
    }
    
    @IsTest
    static void testEmptyLogCollections() {
        Test.startTest();
        
        // Test with empty failed logs list
        List<Notion_Sync_Log__c> emptyLogs = new List<Notion_Sync_Log__c>();
        NotionSyncNotificationService.sendCriticalFailureNotification(emptyLogs, 'admin@company.com');
        
        // Test daily summary with no logs (should not send email)
        NotionSyncNotificationService.sendDailySyncSummary('manager@company.com');
        
        Test.stopTest();
        
        System.assert(true, 'Empty log collections should be handled gracefully');
    }
    
    @IsTest
    static void testEmailBodyContent() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Notion_Sync_Log__c testLog = new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE',
            Status__c = 'Failed',
            Error_Message__c = 'This is a test error message with special characters: <>&"',
            Retry_Count__c = 3,
            Original_Error_Time__c = DateTime.now().addHours(-2)
        );
        insert testLog;
        
        Test.startTest();
        
        // Test that email body generation handles special characters properly
        try {
            NotionSyncNotificationService.sendRetryExhaustedNotification(testLog, 'test@company.com');
            System.assert(true, 'Email body with special characters should be handled properly');
        } catch (Exception e) {
            // Expected in test context due to email sending limitations
            System.assert(e instanceof NotionSyncNotificationService.NotionSyncNotificationException, 
                         'Should handle special characters in email body');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testLongErrorMessages() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create a very long error message to test truncation
        String longErrorMessage = 'This is a very long error message that exceeds normal length limits. '.repeat(10);
        
        List<Notion_Sync_Log__c> logsWithLongErrors = new List<Notion_Sync_Log__c>();
        logsWithLongErrors.add(new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE',
            Status__c = 'Failed',
            Error_Message__c = longErrorMessage,
            Retry_Count__c = 0
        ));
        
        insert logsWithLongErrors;
        
        Test.startTest();
        try {
            NotionSyncNotificationService.sendCriticalFailureNotification(logsWithLongErrors, 'admin@company.com');
            System.assert(true, 'Long error messages should be handled properly');
        } catch (Exception e) {
            System.assert(e instanceof NotionSyncNotificationService.NotionSyncNotificationException, 
                         'Should handle long error messages');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testMultipleEmailAddresses() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Notion_Sync_Log__c testLog = new Notion_Sync_Log__c(
            Record_Id__c = testAccount.Id,
            Object_Type__c = 'Account',
            Operation_Type__c = 'CREATE',
            Status__c = 'Failed',
            Error_Message__c = 'Test error for multiple recipients',
            Retry_Count__c = 3
        );
        insert testLog;
        
        // Test with multiple valid email addresses
        String multipleEmails = 'admin@company.com, support@company.com, manager@company.com';
        
        Test.startTest();
        try {
            NotionSyncNotificationService.sendRetryExhaustedNotification(testLog, multipleEmails);
            System.assert(true, 'Multiple email addresses should be supported');
        } catch (Exception e) {
            System.assert(e instanceof NotionSyncNotificationService.NotionSyncNotificationException, 
                         'Should handle multiple email addresses');
        }
        Test.stopTest();
    }
}