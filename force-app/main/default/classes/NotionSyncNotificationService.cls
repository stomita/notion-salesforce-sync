public class NotionSyncNotificationService {
    
    public static void sendRetryExhaustedNotification(Notion_Sync_Log__c log, String emailAddresses) {
        if (String.isBlank(emailAddresses)) {
            return;
        }
        
        List<String> emails = parseEmailAddresses(emailAddresses);
        if (emails.isEmpty()) {
            return;
        }
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(emails);
        email.setSubject('Notion Sync Failed - Retry Attempts Exhausted');
        email.setHtmlBody(buildRetryExhaustedEmailBody(log));
        email.setPlainTextBody(buildRetryExhaustedPlainTextBody(log));
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception e) {
            System.debug('Failed to send retry exhausted notification: ' + e.getMessage());
            throw new NotionSyncNotificationException('Failed to send notification email: ' + e.getMessage());
        }
    }
    
    public static void sendCriticalFailureNotification(List<Notion_Sync_Log__c> failedLogs, String emailAddresses) {
        if (String.isBlank(emailAddresses) || failedLogs.isEmpty()) {
            return;
        }
        
        List<String> emails = parseEmailAddresses(emailAddresses);
        if (emails.isEmpty()) {
            return;
        }
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(emails);
        email.setSubject('Critical Notion Sync Failures Detected');
        email.setHtmlBody(buildCriticalFailureEmailBody(failedLogs));
        email.setPlainTextBody(buildCriticalFailurePlainTextBody(failedLogs));
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception e) {
            System.debug('Failed to send critical failure notification: ' + e.getMessage());
            throw new NotionSyncNotificationException('Failed to send notification email: ' + e.getMessage());
        }
    }
    
    public static void sendDailySyncSummary(String emailAddresses) {
        if (String.isBlank(emailAddresses)) {
            return;
        }
        
        SyncSummary summary = generateDailySyncSummary();
        if (!summary.hasActivity()) {
            return;
        }
        
        List<String> emails = parseEmailAddresses(emailAddresses);
        if (emails.isEmpty()) {
            return;
        }
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(emails);
        email.setSubject('Daily Notion Sync Summary - ' + Date.today().format());
        email.setHtmlBody(buildSyncSummaryEmailBody(summary));
        email.setPlainTextBody(buildSyncSummaryPlainTextBody(summary));
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception e) {
            System.debug('Failed to send daily sync summary: ' + e.getMessage());
            throw new NotionSyncNotificationException('Failed to send notification email: ' + e.getMessage());
        }
    }
    
    private static List<String> parseEmailAddresses(String emailAddresses) {
        List<String> emails = new List<String>();
        
        if (String.isBlank(emailAddresses)) {
            return emails;
        }
        
        for (String email : emailAddresses.split(',')) {
            String trimmedEmail = email.trim();
            if (String.isNotBlank(trimmedEmail) && isValidEmail(trimmedEmail)) {
                emails.add(trimmedEmail);
            }
        }
        
        return emails;
    }
    
    private static Boolean isValidEmail(String email) {
        String emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        Pattern emailPattern = Pattern.compile(emailRegex);
        return emailPattern.matcher(email).matches();
    }
    
    private static String buildRetryExhaustedEmailBody(Notion_Sync_Log__c log) {
        String body = '<html><body>';
        body += '<h2>Notion Sync Failure - Retry Attempts Exhausted</h2>';
        body += '<p>A Notion synchronization operation has failed after all retry attempts have been exhausted.</p>';
        body += '<table border="1" cellpadding="5" cellspacing="0">';
        body += '<tr><td><strong>Salesforce Record ID:</strong></td><td>' + log.Record_Id__c + '</td></tr>';
        body += '<tr><td><strong>Object Type:</strong></td><td>' + log.Object_Type__c + '</td></tr>';
        body += '<tr><td><strong>Operation:</strong></td><td>' + log.Operation_Type__c + '</td></tr>';
        body += '<tr><td><strong>Retry Count:</strong></td><td>' + log.Retry_Count__c + '</td></tr>';
        body += '<tr><td><strong>Original Error Time:</strong></td><td>' + (log.Original_Error_Time__c != null ? log.Original_Error_Time__c.format() : log.CreatedDate.format()) + '</td></tr>';
        body += '<tr><td><strong>Last Error Message:</strong></td><td>' + (String.isNotBlank(log.Error_Message__c) ? log.Error_Message__c : 'No error message available') + '</td></tr>';
        body += '</table>';
        body += '<p>Please investigate this failure and take appropriate action.</p>';
        body += '</body></html>';
        return body;
    }
    
    private static String buildRetryExhaustedPlainTextBody(Notion_Sync_Log__c log) {
        String body = 'Notion Sync Failure - Retry Attempts Exhausted\n\n';
        body += 'A Notion synchronization operation has failed after all retry attempts have been exhausted.\n\n';
        body += 'Details:\n';
        body += 'Salesforce Record ID: ' + log.Record_Id__c + '\n';
        body += 'Object Type: ' + log.Object_Type__c + '\n';
        body += 'Operation: ' + log.Operation_Type__c + '\n';
        body += 'Retry Count: ' + log.Retry_Count__c + '\n';
        body += 'Original Error Time: ' + (log.Original_Error_Time__c != null ? log.Original_Error_Time__c.format() : log.CreatedDate.format()) + '\n';
        body += 'Last Error Message: ' + (String.isNotBlank(log.Error_Message__c) ? log.Error_Message__c : 'No error message available') + '\n\n';
        body += 'Please investigate this failure and take appropriate action.';
        return body;
    }
    
    private static String buildCriticalFailureEmailBody(List<Notion_Sync_Log__c> failedLogs) {
        String body = '<html><body>';
        body += '<h2>Critical Notion Sync Failures Detected</h2>';
        body += '<p>Multiple critical Notion synchronization failures have been detected:</p>';
        body += '<table border="1" cellpadding="5" cellspacing="0">';
        body += '<tr><th>Record ID</th><th>Object Type</th><th>Operation</th><th>Error Message</th><th>Failure Time</th></tr>';
        
        for (Notion_Sync_Log__c log : failedLogs) {
            body += '<tr>';
            body += '<td>' + log.Record_Id__c + '</td>';
            body += '<td>' + log.Object_Type__c + '</td>';
            body += '<td>' + log.Operation_Type__c + '</td>';
            body += '<td>' + (String.isNotBlank(log.Error_Message__c) ? log.Error_Message__c.left(100) : 'No error message') + '</td>';
            body += '<td>' + log.CreatedDate.format() + '</td>';
            body += '</tr>';
        }
        
        body += '</table>';
        body += '<p>Please investigate these failures immediately.</p>';
        body += '</body></html>';
        return body;
    }
    
    private static String buildCriticalFailurePlainTextBody(List<Notion_Sync_Log__c> failedLogs) {
        String body = 'Critical Notion Sync Failures Detected\n\n';
        body += 'Multiple critical Notion synchronization failures have been detected:\n\n';
        
        for (Notion_Sync_Log__c log : failedLogs) {
            body += 'Record ID: ' + log.Record_Id__c + '\n';
            body += 'Object Type: ' + log.Object_Type__c + '\n';
            body += 'Operation: ' + log.Operation_Type__c + '\n';
            body += 'Error Message: ' + (String.isNotBlank(log.Error_Message__c) ? log.Error_Message__c.left(100) : 'No error message') + '\n';
            body += 'Failure Time: ' + log.CreatedDate.format() + '\n\n';
        }
        
        body += 'Please investigate these failures immediately.';
        return body;
    }
    
    private static SyncSummary generateDailySyncSummary() {
        DateTime startOfDay = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        DateTime endOfDay = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(0, 0, 0, 0));
        
        AggregateResult[] results = [
            SELECT Status__c, COUNT(Id) total
            FROM Notion_Sync_Log__c
            WHERE CreatedDate >= :startOfDay AND CreatedDate < :endOfDay
            GROUP BY Status__c
        ];
        
        SyncSummary summary = new SyncSummary();
        
        for (AggregateResult result : results) {
            String status = (String) result.get('Status__c');
            Integer count = (Integer) result.get('total');
            
            if (status == 'Success') {
                summary.successCount = count;
            } else if (status == 'Failed') {
                summary.failedCount = count;
            } else if (status == 'Retrying') {
                summary.retryingCount = count;
            }
        }
        
        return summary;
    }
    
    private static String buildSyncSummaryEmailBody(SyncSummary summary) {
        String body = '<html><body>';
        body += '<h2>Daily Notion Sync Summary - ' + Date.today().format() + '</h2>';
        body += '<table border="1" cellpadding="5" cellspacing="0">';
        body += '<tr><td><strong>Successful Syncs:</strong></td><td>' + summary.successCount + '</td></tr>';
        body += '<tr><td><strong>Failed Syncs:</strong></td><td>' + summary.failedCount + '</td></tr>';
        body += '<tr><td><strong>Retrying Syncs:</strong></td><td>' + summary.retryingCount + '</td></tr>';
        body += '<tr><td><strong>Total Syncs:</strong></td><td>' + summary.getTotalCount() + '</td></tr>';
        body += '</table>';
        
        if (summary.failedCount > 0) {
            body += '<p><strong>Note:</strong> There were ' + summary.failedCount + ' failed sync operations. Please review the sync logs for details.</p>';
        }
        
        body += '</body></html>';
        return body;
    }
    
    private static String buildSyncSummaryPlainTextBody(SyncSummary summary) {
        String body = 'Daily Notion Sync Summary - ' + Date.today().format() + '\n\n';
        body += 'Successful Syncs: ' + summary.successCount + '\n';
        body += 'Failed Syncs: ' + summary.failedCount + '\n';
        body += 'Retrying Syncs: ' + summary.retryingCount + '\n';
        body += 'Total Syncs: ' + summary.getTotalCount() + '\n\n';
        
        if (summary.failedCount > 0) {
            body += 'Note: There were ' + summary.failedCount + ' failed sync operations. Please review the sync logs for details.';
        }
        
        return body;
    }
    
    private class SyncSummary {
        public Integer successCount = 0;
        public Integer failedCount = 0;
        public Integer retryingCount = 0;
        
        public Integer getTotalCount() {
            return successCount + failedCount + retryingCount;
        }
        
        public Boolean hasActivity() {
            return getTotalCount() > 0;
        }
    }
    
    public class NotionSyncNotificationException extends Exception {}
}