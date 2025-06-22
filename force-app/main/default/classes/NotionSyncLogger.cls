public with sharing class NotionSyncLogger {
    // Instance variables
    private List<LogEntry> logs;
    private Boolean loggingEnabled;
    
    // Constructor
    public NotionSyncLogger() {
        this.logs = new List<LogEntry>();
        // Check settings once during construction
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getInstance();
        this.loggingEnabled = (settings != null && settings.Enable_Sync_Logging__c == true);
    }
    
    
    // Factory method to create a log entry
    public LogEntry createLogEntry(String recordId, String objectType, String operationType) {
        return new LogEntry(recordId, objectType, operationType);
    }
    
    // Simple log method - creates and logs a basic success entry
    public void log(String recordId, String objectType, String operationType) {
        log(createLogEntry(recordId, objectType, operationType));
    }
    
    // Log with a LogEntry object
    public void log(LogEntry entry) {
        if (!loggingEnabled) {
            return;
        }
        
        // Set callouts used at the time of logging
        entry.calloutsUsed = Limits.getCallouts();
        
        logs.add(entry);
    }
    
    // Flush all logs to database
    public void flush() {
        if (!loggingEnabled || logs.isEmpty()) {
            return;
        }
        
        // Create log records
        List<Notion_Sync_Log__c> logRecords = new List<Notion_Sync_Log__c>();
        
        for (LogEntry entry : logs) {
            Notion_Sync_Log__c logRecord = new Notion_Sync_Log__c(
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
            
            logRecords.add(logRecord);
        }
        
        if (!logRecords.isEmpty()) {
            try {
                insert logRecords;
                // Clear logs after successful insert
                logs.clear();
            } catch (Exception e) {
                System.debug('Failed to insert sync logs: ' + e.getMessage());
            }
        }
    }
    
    
    // Clear logs without saving (for error scenarios)
    public void clear() {
        logs.clear();
    }
    
    // Get pending log entries for deferred flushing
    public List<LogEntry> getPendingEntries() {
        return logs.clone();
    }
    
    // Check if there are pending entries
    public Boolean hasPendingEntries() {
        return !logs.isEmpty();
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
        
        // Simple constructor with only required fields
        public LogEntry(String recordId, String objectType, String operationType) {
            this.recordId = recordId;
            this.objectType = objectType;
            this.operationType = operationType;
            this.status = 'Success';
            this.errorMessage = null;
            this.retryCount = 0;
            this.notionPageId = null;
            this.rateLimited = false;
            this.rateLimitRetryAfter = null;
            this.apiCallsMade = 0;
            this.cpuTimeUsed = 0;
            this.calloutsUsed = 0;
        }
        
        // Builder pattern methods for fluent API
        public LogEntry withStatus(String status) {
            this.status = status;
            return this;
        }
        
        public LogEntry withError(String errorMessage) {
            this.errorMessage = errorMessage;
            this.status = 'Failed';
            return this;
        }
        
        public LogEntry withNotionPageId(String notionPageId) {
            this.notionPageId = notionPageId;
            return this;
        }
        
        public LogEntry withRetryCount(Integer retryCount) {
            this.retryCount = retryCount;
            return this;
        }
        
        public LogEntry withRateLimit(Integer retryAfterSeconds) {
            this.rateLimited = true;
            this.rateLimitRetryAfter = retryAfterSeconds;
            this.status = 'Rate Limited';
            return this;
        }
        
        public LogEntry withMetrics(Integer apiCallsMade, Integer cpuTimeUsed) {
            this.apiCallsMade = apiCallsMade;
            this.cpuTimeUsed = cpuTimeUsed;
            return this;
        }
    }
}