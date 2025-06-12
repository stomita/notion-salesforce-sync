public class NotionSyncRetryScheduler implements Schedulable {
    
    private static final Integer MAX_QUEUEABLE_JOBS = 5;
    private static final Integer BATCH_SIZE = 50;
    
    public void execute(SchedulableContext context) {
        try {
            processRetryableSyncLogs();
        } catch (Exception e) {
            System.debug('Error in NotionSyncRetryScheduler: ' + e.getMessage());
            
            NotionSyncRetryConfig__mdt config = getDefaultRetryConfig();
            if (config != null && String.isNotBlank(config.NotificationEmails__c)) {
                sendSchedulerErrorNotification(e, config.NotificationEmails__c);
            }
        }
    }
    
    private void processRetryableSyncLogs() {
        List<Notion_Sync_Log__c> retryableLogs = getRetryableSyncLogs();
        
        if (retryableLogs.isEmpty()) {
            return;
        }
        
        System.debug('Found ' + retryableLogs.size() + ' logs ready for retry');
        
        Map<String, List<Notion_Sync_Log__c>> logsByObjectType = groupLogsByObjectType(retryableLogs);
        
        Integer jobsEnqueued = 0;
        for (String objectType : logsByObjectType.keySet()) {
            List<Notion_Sync_Log__c> objectLogs = logsByObjectType.get(objectType);
            
            List<List<Id>> batches = createBatches(extractLogIds(objectLogs), BATCH_SIZE);
            
            for (List<Id> batch : batches) {
                if (jobsEnqueued >= MAX_QUEUEABLE_JOBS) {
                    System.debug('Maximum queueable jobs limit reached. Remaining logs will be processed in the next run.');
                    break;
                }
                
                System.enqueueJob(new NotionSyncRetryQueueable(batch));
                jobsEnqueued++;
            }
            
            if (jobsEnqueued >= MAX_QUEUEABLE_JOBS) {
                break;
            }
        }
        
        System.debug('Enqueued ' + jobsEnqueued + ' retry jobs');
    }
    
    private List<Notion_Sync_Log__c> getRetryableSyncLogs() {
        DateTime now = DateTime.now();
        
        return [
            SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, Status__c,
                   Retry_Count__c, Error_Message__c, Next_Retry_Time__c, Last_Retry_Time__c,
                   Original_Error_Time__c, CreatedDate
            FROM Notion_Sync_Log__c
            WHERE Status__c IN ('Failed', 'Retrying')
            AND (Next_Retry_Time__c = null OR Next_Retry_Time__c <= :now)
            ORDER BY CreatedDate ASC
            LIMIT 1000
        ];
    }
    
    private Map<String, List<Notion_Sync_Log__c>> groupLogsByObjectType(List<Notion_Sync_Log__c> logs) {
        Map<String, List<Notion_Sync_Log__c>> grouped = new Map<String, List<Notion_Sync_Log__c>>();
        
        for (Notion_Sync_Log__c log : logs) {
            if (!grouped.containsKey(log.Object_Type__c)) {
                grouped.put(log.Object_Type__c, new List<Notion_Sync_Log__c>());
            }
            grouped.get(log.Object_Type__c).add(log);
        }
        
        return grouped;
    }
    
    private List<Id> extractLogIds(List<Notion_Sync_Log__c> logs) {
        List<Id> ids = new List<Id>();
        for (Notion_Sync_Log__c log : logs) {
            ids.add(log.Id);
        }
        return ids;
    }
    
    private List<List<Id>> createBatches(List<Id> items, Integer batchSize) {
        List<List<Id>> batches = new List<List<Id>>();
        List<Id> currentBatch = new List<Id>();
        
        for (Id item : items) {
            currentBatch.add(item);
            
            if (currentBatch.size() >= batchSize) {
                batches.add(currentBatch);
                currentBatch = new List<Id>();
            }
        }
        
        if (!currentBatch.isEmpty()) {
            batches.add(currentBatch);
        }
        
        return batches;
    }
    
    private NotionSyncRetryConfig__mdt getDefaultRetryConfig() {
        List<NotionSyncRetryConfig__mdt> configs = [
            SELECT MasterLabel, ObjectApiName__c, MaxRetryAttempts__c, RetryDelayMinutes__c,
                   ExponentialBackoff__c, NotificationEmails__c
            FROM NotionSyncRetryConfig__mdt
            WHERE ObjectApiName__c = null
            LIMIT 1
        ];
        
        return configs.isEmpty() ? null : configs[0];
    }
    
    private void sendSchedulerErrorNotification(Exception e, String emailAddresses) {
        try {
            List<String> emails = parseEmailAddresses(emailAddresses);
            if (emails.isEmpty()) {
                return;
            }
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(emails);
            email.setSubject('Notion Sync Retry Scheduler Error');
            email.setPlainTextBody(buildSchedulerErrorBody(e));
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception emailException) {
            System.debug('Failed to send scheduler error notification: ' + emailException.getMessage());
        }
    }
    
    private List<String> parseEmailAddresses(String emailAddresses) {
        List<String> emails = new List<String>();
        
        if (String.isBlank(emailAddresses)) {
            return emails;
        }
        
        for (String email : emailAddresses.split(',')) {
            String trimmedEmail = email.trim();
            if (String.isNotBlank(trimmedEmail)) {
                emails.add(trimmedEmail);
            }
        }
        
        return emails;
    }
    
    private String buildSchedulerErrorBody(Exception e) {
        String body = 'Notion Sync Retry Scheduler Error\n\n';
        body += 'An error occurred while processing retry operations:\n\n';
        body += 'Error Type: ' + e.getTypeName() + '\n';
        body += 'Error Message: ' + e.getMessage() + '\n';
        body += 'Stack Trace: ' + e.getStackTraceString() + '\n\n';
        body += 'Timestamp: ' + DateTime.now().format() + '\n\n';
        body += 'Please investigate this error to ensure retry operations continue functioning properly.';
        return body;
    }
    
    public static String scheduleRetryJob() {
        return scheduleRetryJob('0 */5 * * * ?');
    }
    
    public static String scheduleRetryJob(String cronExpression) {
        NotionSyncRetryScheduler scheduler = new NotionSyncRetryScheduler();
        String jobName = 'Notion Sync Retry Job - ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss');
        return System.schedule(jobName, cronExpression, scheduler);
    }
    
    public static void unscheduleAllRetryJobs() {
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Notion Sync Retry Job%'
        ];
        
        for (CronTrigger job : scheduledJobs) {
            System.abortJob(job.Id);
        }
    }
}