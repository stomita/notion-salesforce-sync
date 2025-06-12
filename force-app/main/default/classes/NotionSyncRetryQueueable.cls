public class NotionSyncRetryQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> syncLogIds;
    
    public NotionSyncRetryQueueable(List<Id> syncLogIds) {
        this.syncLogIds = syncLogIds;
    }
    
    public void execute(QueueableContext context) {
        List<Notion_Sync_Log__c> logsToRetry = getSyncLogsForRetry();
        
        if (logsToRetry.isEmpty()) {
            return;
        }
        
        Map<String, NotionSyncRetryConfig__mdt> retryConfigs = getRetryConfigurations();
        List<NotionSyncQueueable.SyncRequest> retryRequests = new List<NotionSyncQueueable.SyncRequest>();
        List<Notion_Sync_Log__c> logsToUpdate = new List<Notion_Sync_Log__c>();
        
        for (Notion_Sync_Log__c log : logsToRetry) {
            NotionSyncRetryConfig__mdt config = getRetryConfigForObject(log.Object_Type__c, retryConfigs);
            
            if (shouldRetry(log, config)) {
                retryRequests.add(new NotionSyncQueueable.SyncRequest(
                    log.Record_Id__c,
                    log.Object_Type__c,
                    log.Operation_Type__c
                ));
                
                log.Retry_Count__c = log.Retry_Count__c + 1;
                log.Last_Retry_Time__c = DateTime.now();
                log.Status__c = 'Retrying';
                log.Next_Retry_Time__c = calculateNextRetryTime(log, config);
                logsToUpdate.add(log);
            } else {
                log.Status__c = 'Failed';
                log.Next_Retry_Time__c = null;
                logsToUpdate.add(log);
                
                sendFailureNotification(log, config);
            }
        }
        
        if (!logsToUpdate.isEmpty()) {
            try {
                update logsToUpdate;
            } catch (Exception e) {
                System.debug('Failed to update sync logs during retry: ' + e.getMessage());
            }
        }
        
        if (!retryRequests.isEmpty()) {
            NotionSyncQueueable retryJob = new NotionSyncQueueable(retryRequests);
            System.enqueueJob(retryJob);
        }
    }
    
    private List<Notion_Sync_Log__c> getSyncLogsForRetry() {
        return [
            SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, Status__c,
                   Retry_Count__c, Error_Message__c, Next_Retry_Time__c, Last_Retry_Time__c,
                   Original_Error_Time__c, CreatedDate
            FROM Notion_Sync_Log__c
            WHERE Id IN :syncLogIds
            AND Status__c IN ('Failed', 'Retrying')
            AND (Next_Retry_Time__c = null OR Next_Retry_Time__c <= :DateTime.now())
        ];
    }
    
    private Map<String, NotionSyncRetryConfig__mdt> getRetryConfigurations() {
        Map<String, NotionSyncRetryConfig__mdt> configs = new Map<String, NotionSyncRetryConfig__mdt>();
        
        List<NotionSyncRetryConfig__mdt> retryConfigs = [
            SELECT MasterLabel, ObjectApiName__c, MaxRetryAttempts__c, RetryDelayMinutes__c,
                   ExponentialBackoff__c, NotificationEmails__c
            FROM NotionSyncRetryConfig__mdt
        ];
        
        NotionSyncRetryConfig__mdt defaultConfig = null;
        
        for (NotionSyncRetryConfig__mdt config : retryConfigs) {
            if (String.isBlank(config.ObjectApiName__c)) {
                defaultConfig = config;
            } else {
                configs.put(config.ObjectApiName__c, config);
            }
        }
        
        if (defaultConfig != null) {
            configs.put('DEFAULT', defaultConfig);
        }
        
        return configs;
    }
    
    private NotionSyncRetryConfig__mdt getRetryConfigForObject(String objectType, Map<String, NotionSyncRetryConfig__mdt> configs) {
        NotionSyncRetryConfig__mdt config = configs.get(objectType);
        if (config == null) {
            config = configs.get('DEFAULT');
        }
        
        if (config == null) {
            config = createDefaultRetryConfig();
        }
        
        return config;
    }
    
    private NotionSyncRetryConfig__mdt createDefaultRetryConfig() {
        NotionSyncRetryConfig__mdt defaultConfig = new NotionSyncRetryConfig__mdt();
        defaultConfig.MaxRetryAttempts__c = 3;
        defaultConfig.RetryDelayMinutes__c = 5;
        defaultConfig.ExponentialBackoff__c = true;
        return defaultConfig;
    }
    
    private Boolean shouldRetry(Notion_Sync_Log__c log, NotionSyncRetryConfig__mdt config) {
        Integer maxRetries = config.MaxRetryAttempts__c != null ? Integer.valueOf(config.MaxRetryAttempts__c) : 3;
        Integer currentRetries = log.Retry_Count__c != null ? Integer.valueOf(log.Retry_Count__c) : 0;
        
        if (currentRetries >= maxRetries) {
            return false;
        }
        
        if (isNonRetryableError(log.Error_Message__c)) {
            return false;
        }
        
        return true;
    }
    
    private Boolean isNonRetryableError(String errorMessage) {
        if (String.isBlank(errorMessage)) {
            return false;
        }
        
        String lowerErrorMessage = errorMessage.toLowerCase();
        
        List<String> nonRetryablePatterns = new List<String>{
            'unauthorized',
            'authentication',
            'invalid_token',
            'validation_error',
            'invalid_request_url',
            'invalid_json',
            'object_not_found',
            'invalid_database_id'
        };
        
        for (String pattern : nonRetryablePatterns) {
            if (lowerErrorMessage.contains(pattern)) {
                return true;
            }
        }
        
        return false;
    }
    
    private DateTime calculateNextRetryTime(Notion_Sync_Log__c log, NotionSyncRetryConfig__mdt config) {
        Integer baseDelayMinutes = config.RetryDelayMinutes__c != null ? Integer.valueOf(config.RetryDelayMinutes__c) : 5;
        Integer retryCount = log.Retry_Count__c != null ? Integer.valueOf(log.Retry_Count__c) : 0;
        
        Integer delayMinutes = baseDelayMinutes;
        
        if (config.ExponentialBackoff__c) {
            delayMinutes = Integer.valueOf(baseDelayMinutes * Math.pow(2, retryCount));
        }
        
        delayMinutes = Math.min(delayMinutes, 1440);
        
        return DateTime.now().addMinutes(delayMinutes);
    }
    
    private void sendFailureNotification(Notion_Sync_Log__c log, NotionSyncRetryConfig__mdt config) {
        if (String.isBlank(config.NotificationEmails__c)) {
            return;
        }
        
        try {
            NotionSyncNotificationService.sendRetryExhaustedNotification(log, config.NotificationEmails__c);
        } catch (Exception e) {
            System.debug('Failed to send failure notification: ' + e.getMessage());
        }
    }
    
}