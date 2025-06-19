public with sharing class NotionSyncLogger {
    @TestVisible
    private static List<LogEntry> pendingLogs = new List<LogEntry>();
    
    // Cache the settings to avoid multiple queries
    private static Notion_Sync_Settings__c cachedSettings;
    
    // Check if logging is enabled
    private static Boolean isLoggingEnabled() {
        if (cachedSettings == null) {
            cachedSettings = Notion_Sync_Settings__c.getInstance();
        }
        return cachedSettings != null && cachedSettings.Enable_Sync_Logging__c == true;
    }
    
    @future
    public static void logAsync(List<String> logJsonList) {
        logSync(logJsonList);
    }
    
    // Synchronous version for testing
    public static void logSync(List<String> logJsonList) {
        // Check if logging is enabled before processing
        if (!isLoggingEnabled()) {
            return;
        }
        
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
                insert logs;
            } catch (Exception e) {
                System.debug('Failed to insert sync logs: ' + e.getMessage());
            }
        }
    }
    
    // Add a log entry to the pending collection
    public static void log(String recordId, String objectType, String operationType, 
                          String status, String errorMessage, Integer retryCount) {
        // Only add to pending logs if logging is enabled
        if (isLoggingEnabled()) {
            pendingLogs.add(new LogEntry(recordId, objectType, operationType, status, errorMessage, retryCount, null));
        }
    }
    
    // Add a log entry with Notion page ID
    public static void log(String recordId, String objectType, String operationType, 
                          String status, String errorMessage, Integer retryCount, String notionPageId) {
        // Only add to pending logs if logging is enabled
        if (isLoggingEnabled()) {
            pendingLogs.add(new LogEntry(recordId, objectType, operationType, status, errorMessage, retryCount, notionPageId));
        }
    }
    
    // Add a log entry with rate limit information
    public static LogEntry logWithRateLimit(String recordId, String objectType, String operationType, 
                                       String status, String errorMessage, Integer retryCount, String notionPageId,
                                       Boolean rateLimited, Integer rateLimitRetryAfter) {
        // Only create and add log if logging is enabled
        if (!isLoggingEnabled()) {
            return null;
        }
        
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
        // Check if logging is enabled and we have pending logs
        if (!isLoggingEnabled() || pendingLogs.isEmpty()) {
            pendingLogs.clear();
            return;
        }
        
        if (!pendingLogs.isEmpty()) {
            List<String> logJsonList = new List<String>();
            for (LogEntry entry : pendingLogs) {
                logJsonList.add(JSON.serialize(entry));
            }
            
            // If we're already in a future context, we need to handle this specially
            // We can't call another @future method, and we can't do DML if there are
            // pending callouts. So we'll store the logs and process them separately.
            if (System.isFuture()) {
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
                        System.debug('Failed to insert sync logs from future context: ' + e.getMessage());
                    }
                }
            } else if (Test.isRunningTest()) {
                logSync(logJsonList);
            } else {
                logAsync(logJsonList);
            }
            
            pendingLogs.clear();
        }
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