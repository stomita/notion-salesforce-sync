public with sharing class NotionSyncLogger {
    @TestVisible
    private static List<LogEntry> pendingLogs = new List<LogEntry>();
    
    // Log level constants
    public static final String LOG_LEVEL_ERROR = 'ERROR';
    public static final String LOG_LEVEL_INFO = 'INFO';
    public static final String LOG_LEVEL_DEBUG = 'DEBUG';
    
    // Check if logging is enabled
    private static Boolean isLoggingEnabled() {
        // Check custom setting - always get fresh instance to avoid caching issues
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            return false;
        }
        try {
            // Re-query to ensure we have the latest values
            if (Test.isRunningTest()) {
                settings = [SELECT Enable_Logging__c FROM Notion_Sync_Settings__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() LIMIT 1];
            }
            return (Boolean) settings.get('Enable_Logging__c') == true;
        } catch (Exception e) {
            return false;
        }
    }
    
    // Determine if we should log based on status and settings
    private static Boolean shouldLog(String status) {
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
        
        // If logging is disabled, don't log
        if (settings == null || settings.Id == null) {
            return false;
        }
        
        try {
            // Re-query to ensure we have the latest values in test context
            if (Test.isRunningTest()) {
                settings = [SELECT Enable_Logging__c, Log_Level__c FROM Notion_Sync_Settings__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() LIMIT 1];
            }
            
            System.debug('NotionSyncLogger.shouldLog - status: ' + status + ', settings: ' + settings);
            
            Boolean isEnabled = (Boolean) settings.get('Enable_Logging__c');
            if (isEnabled != true) {
                return false;
            }
        } catch (Exception e) {
            return false;
        }
        
        String logLevel = LOG_LEVEL_ERROR;
        try {
            logLevel = (String) settings.get('Log_Level__c');
            if (logLevel == null) {
                logLevel = LOG_LEVEL_ERROR;
            }
        } catch (Exception e) {
            logLevel = LOG_LEVEL_ERROR;
        }
        
        // Determine based on log level
        switch on logLevel {
            when 'ERROR' {
                // Only log failures
                return status == 'Failed' || status == 'Rate Limited';
            }
            when 'INFO' {
                // Log failures and successes, but not BatchProcess logs
                return status != 'Deferred' && status != 'BatchProcess';
            }
            when 'DEBUG' {
                // Log everything including BatchProcess
                return true;
            }
            when else {
                return false;
            }
        }
    }
    
    @future
    public static void logAsync(List<String> logJsonList) {
        logSync(logJsonList);
    }
    
    // Synchronous version for testing
    @TestVisible
    private static void logSync(List<String> logJsonList) {
        System.debug('NotionSyncLogger.logSync - Processing ' + logJsonList.size() + ' log entries');
        List<Notion_Sync_Log__c> logs = new List<Notion_Sync_Log__c>();
        
        for (String logJson : logJsonList) {
            LogEntry entry = (LogEntry) JSON.deserialize(logJson, LogEntry.class);
            
            Notion_Sync_Log__c log = new Notion_Sync_Log__c(
                Record_Id__c = entry.recordId,
                Object_Type__c = entry.objectType,
                Operation_Type__c = entry.operationType,
                Status__c = entry.status,
                Error_Message__c = entry.errorMessage,
                Retry_Count__c = entry.retryCount,
                Notion_Page_Id__c = entry.notionPageId,
                Rate_Limited__c = entry.rateLimited,
                Rate_Limit_Retry_After__c = entry.rateLimitRetryAfter,
                API_Calls_Made__c = entry.apiCallsMade,
                CPU_Time_Used__c = entry.cpuTimeUsed,
                Callouts_Used__c = entry.calloutsUsed
            );
            
            logs.add(log);
        }
        
        if (!logs.isEmpty()) {
            try {
                System.debug('NotionSyncLogger.logSync - Inserting ' + logs.size() + ' log records');
                insert logs;
                System.debug('NotionSyncLogger.logSync - Successfully inserted logs');
            } catch (Exception e) {
                System.debug('Failed to insert sync logs: ' + e.getMessage());
            }
        } else {
            System.debug('NotionSyncLogger.logSync - No logs to insert');
        }
    }
    
    // Add a log entry to the pending collection
    public static void log(String recordId, String objectType, String operationType, 
                          String status, String errorMessage, Integer retryCount) {
        pendingLogs.add(new LogEntry(recordId, objectType, operationType, status, errorMessage, retryCount, null));
    }
    
    // Add a log entry with Notion page ID
    public static void log(String recordId, String objectType, String operationType, 
                          String status, String errorMessage, Integer retryCount, String notionPageId) {
        pendingLogs.add(new LogEntry(recordId, objectType, operationType, status, errorMessage, retryCount, notionPageId));
    }
    
    // Add a log entry with rate limit information
    public static LogEntry logWithRateLimit(String recordId, String objectType, String operationType, 
                                       String status, String errorMessage, Integer retryCount, String notionPageId,
                                       Boolean rateLimited, Integer rateLimitRetryAfter) {
        LogEntry entry = new LogEntry(recordId, objectType, operationType, status, errorMessage, retryCount, notionPageId);
        entry.rateLimited = rateLimited;
        entry.rateLimitRetryAfter = rateLimitRetryAfter;
        
        // Capture current governor limits
        entry.apiCallsMade = 1; // Will be updated by caller if different
        entry.cpuTimeUsed = Limits.getCpuTime();
        entry.calloutsUsed = Limits.getCallouts();
        
        pendingLogs.add(entry);
        return entry; // Return the entry so caller can update fields
    }
    
    // Flush all pending logs
    public static void flush() {
        if (pendingLogs.isEmpty()) {
            return;
        }
        
        // Check if logging is enabled
        if (!isLoggingEnabled()) {
            pendingLogs.clear();
            return;
        }
        
        // Filter logs based on current settings
        List<LogEntry> logsToSave = new List<LogEntry>();
        for (LogEntry entry : pendingLogs) {
            if (shouldLog(entry.status)) {
                logsToSave.add(entry);
            }
        }
        
        System.debug('NotionSyncLogger.flush - pendingLogs size: ' + pendingLogs.size());
        System.debug('NotionSyncLogger.flush - logsToSave size: ' + logsToSave.size());
        
        if (!logsToSave.isEmpty()) {
            List<String> logJsonList = new List<String>();
            for (LogEntry entry : logsToSave) {
                logJsonList.add(JSON.serialize(entry));
            }
            
            // If we're already in a future context, we need to handle this specially
            // We can't call another @future method, and we can't do DML if there are
            // pending callouts. So we'll store the logs and process them separately.
            if (System.isFuture() || System.isBatch() || System.isQueueable()) {
                // Convert back to logs and insert directly
                // This should only be called AFTER all callouts are complete
                List<Notion_Sync_Log__c> logs = new List<Notion_Sync_Log__c>();
                for (String logJson : logJsonList) {
                    LogEntry entry = (LogEntry) JSON.deserialize(logJson, LogEntry.class);
                    logs.add(new Notion_Sync_Log__c(
                        Record_Id__c = entry.recordId,
                        Object_Type__c = entry.objectType,
                        Operation_Type__c = entry.operationType,
                        Status__c = entry.status,
                        Error_Message__c = entry.errorMessage,
                        Retry_Count__c = entry.retryCount,
                        Notion_Page_Id__c = entry.notionPageId,
                        Rate_Limited__c = entry.rateLimited,
                        Rate_Limit_Retry_After__c = entry.rateLimitRetryAfter,
                        API_Calls_Made__c = entry.apiCallsMade,
                        CPU_Time_Used__c = entry.cpuTimeUsed,
                        Callouts_Used__c = entry.calloutsUsed
                    ));
                }
                
                if (!logs.isEmpty()) {
                    try {
                        insert logs;
                    } catch (Exception e) {
                        System.debug('Failed to insert sync logs from async context: ' + e.getMessage());
                    }
                }
            } else if (Test.isRunningTest()) {
                System.debug('NotionSyncLogger.flush - Using synchronous logging in test context');
                // In test context, insert logs directly without @future
                List<Notion_Sync_Log__c> logs = new List<Notion_Sync_Log__c>();
                for (String logJson : logJsonList) {
                    LogEntry entry = (LogEntry) JSON.deserialize(logJson, LogEntry.class);
                    logs.add(new Notion_Sync_Log__c(
                        Record_Id__c = entry.recordId,
                        Object_Type__c = entry.objectType,
                        Operation_Type__c = entry.operationType,
                        Status__c = entry.status,
                        Error_Message__c = entry.errorMessage,
                        Retry_Count__c = entry.retryCount,
                        Notion_Page_Id__c = entry.notionPageId,
                        Rate_Limited__c = entry.rateLimited,
                        Rate_Limit_Retry_After__c = entry.rateLimitRetryAfter,
                        API_Calls_Made__c = entry.apiCallsMade,
                        CPU_Time_Used__c = entry.cpuTimeUsed,
                        Callouts_Used__c = entry.calloutsUsed
                    ));
                }
                
                if (!logs.isEmpty()) {
                    try {
                        insert logs;
                        System.debug('NotionSyncLogger.flush - Inserted ' + logs.size() + ' logs in test context');
                    } catch (Exception e) {
                        System.debug('Failed to insert sync logs in test context: ' + e.getMessage());
                    }
                }
            } else {
                System.debug('NotionSyncLogger.flush - Using asynchronous logging');
                logAsync(logJsonList);
            }
            
        }
        
        pendingLogs.clear();
    }
    
    // Clear pending logs without saving (for error scenarios)
    public static void clear() {
        pendingLogs.clear();
    }
    
    public class LogEntry {
        public String recordId;
        public String objectType;
        public String operationType;
        public String status;
        public String errorMessage;
        public Integer retryCount;
        public String notionPageId;
        public Boolean rateLimited;
        public Integer rateLimitRetryAfter;
        public Integer apiCallsMade;
        public Integer cpuTimeUsed;
        public Integer calloutsUsed;
        
        public LogEntry(String recordId, String objectType, String operationType, 
                       String status, String errorMessage, Integer retryCount, String notionPageId) {
            this.recordId = recordId;
            this.objectType = objectType;
            this.operationType = operationType;
            this.status = status;
            this.errorMessage = errorMessage;
            this.retryCount = retryCount;
            this.notionPageId = notionPageId;
            this.rateLimited = false;
            this.rateLimitRetryAfter = null;
            this.apiCallsMade = 0;
            this.cpuTimeUsed = 0;
            this.calloutsUsed = 0;
        }
    }
}