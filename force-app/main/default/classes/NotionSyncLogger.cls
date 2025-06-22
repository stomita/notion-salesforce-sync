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
    
    // Synchronous version for testing and Platform Event processing
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
            // In test context, insert logs directly for verification
            if (Test.isRunningTest()) {
                List<String> logJsonList = new List<String>();
                for (LogEntry entry : pendingLogs) {
                    logJsonList.add(JSON.serialize(entry));
                }
                logSync(logJsonList);
            } else {
                // Use Platform Events for logging to avoid transaction conflicts
                List<Notion_Sync_Log_Event__e> events = new List<Notion_Sync_Log_Event__e>();
                
                for (LogEntry entry : pendingLogs) {
                    Notion_Sync_Log_Event__e event = new Notion_Sync_Log_Event__e(
                        Record_Id__c = entry.recordId,
                        Object_Type__c = entry.objectType,
                        Operation_Type__c = entry.operationType,
                        Status__c = entry.status,
                        Error_Message__c = entry.errorMessage,
                        Notion_Page_Id__c = entry.notionPageId,
                        Retry_Count__c = entry.retryCount,
                        Rate_Limited__c = entry.rateLimited,
                        API_Calls_Made__c = entry.apiCallsMade,
                        CPU_Time_Used__c = entry.cpuTimeUsed
                    );
                    
                    events.add(event);
                }
                
                if (!events.isEmpty()) {
                    try {
                        // Publish events - this works in all contexts
                        List<Database.SaveResult> results = EventBus.publish(events);
                        
                        // Check for publish failures
                        for (Database.SaveResult result : results) {
                            if (!result.isSuccess()) {
                                for (Database.Error error : result.getErrors()) {
                                    System.debug('Failed to publish log event: ' + error.getMessage());
                                }
                            }
                        }
                    } catch (Exception e) {
                        System.debug('Failed to publish sync log events: ' + e.getMessage());
                    }
                }
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