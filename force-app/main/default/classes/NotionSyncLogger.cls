public with sharing class NotionSyncLogger {
    // Instance variables
    private List<LogEntry> logs;
    private Boolean loggingEnabled;
    
    // Constructor
    public NotionSyncLogger() {
        this.logs = new List<LogEntry>();
        // Check settings once during construction
        // Use getOrgDefaults() to match how settings are saved in NotionAdminController
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
        this.loggingEnabled = (settings != null && settings.Enable_Sync_Logging__c == true);
    }
    
    
    // Log with a LogEntry object
    public void log(LogEntry entry) {
        if (!loggingEnabled) {
            return;
        }
        
        // Set callouts used at the time of logging
        entry.calloutsUsed = Limits.getCallouts();
        
        // Capture the actual event timestamp
        entry.eventTimestamp = DateTime.now();
        
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
                Error_Message__c = entry.message,
                Retry_Count__c = entry.retryCount,
                Notion_Page_Id__c = entry.notionPageId,
                Rate_Limited__c = entry.rateLimited,
                Rate_Limit_Retry_After__c = entry.rateLimitRetryAfter,
                API_Calls_Made__c = entry.apiCallsMade,
                CPU_Time_Used__c = entry.cpuTimeUsed,
                Callouts_Used__c = entry.calloutsUsed,
                Duplicates_Found__c = entry.duplicatesFound,
                Duplicates_Deleted__c = entry.duplicatesDeleted,
                Deduplication_Deferred__c = entry.deduplicationDeferred,
                Event_Timestamp__c = entry.eventTimestamp
            );
            
            logRecords.add(logRecord);
        }
        
        if (!logRecords.isEmpty()) {
            try {
                insert logRecords;
                // Clear logs after successful insert
                logs.clear();
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to insert sync logs: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
                
                // Create a minimal error log entry that might succeed
                try {
                    Notion_Sync_Log__c errorLog = new Notion_Sync_Log__c(
                        Object_Type__c = 'System',
                        Operation_Type__c = 'LOGGING_ERROR',
                        Status__c = 'Failed',
                        Error_Message__c = 'Logger Error: ' + e.getMessage().left(250),
                        Event_Timestamp__c = DateTime.now()
                    );
                    insert errorLog;
                } catch (Exception innerEx) {
                    // Last resort - log to debug
                    System.debug(LoggingLevel.ERROR, 'Could not create error log: ' + innerEx.getMessage());
                }
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
        public String message;
        public Integer retryCount;
        public String notionPageId;
        public Boolean rateLimited;
        public Integer rateLimitRetryAfter;
        public Integer apiCallsMade;
        public Integer cpuTimeUsed;
        public Integer calloutsUsed;
        // Deduplication fields
        public Integer duplicatesFound;
        public Integer duplicatesDeleted;
        public Boolean deduplicationDeferred;
        public DateTime eventTimestamp;
        
        // Constructor with only operationType - all other fields are optional
        public LogEntry(String operationType) {
            this.operationType = operationType;
            this.status = 'Success';
            this.message = null;
            this.retryCount = 0;
            this.notionPageId = null;
            this.rateLimited = false;
            this.rateLimitRetryAfter = null;
            this.apiCallsMade = 0;
            this.cpuTimeUsed = 0;
            this.calloutsUsed = 0;
            // Initialize deduplication fields
            this.duplicatesFound = 0;
            this.duplicatesDeleted = 0;
            this.deduplicationDeferred = false;
        }
        
        // Method to set record information (objectType and recordId)
        public LogEntry withRecord(String objectType, String recordId) {
            this.objectType = objectType;
            this.recordId = recordId;
            return this;
        }
        
        // Method to set Salesforce object type only
        public LogEntry withSalesforceObject(String objectType) {
            this.objectType = objectType;
            return this;
        }
        
        // Builder pattern methods for fluent API
        public LogEntry withStatus(String status) {
            this.status = status;
            return this;
        }
        
        public LogEntry withMessage(String message) {
            this.message = message;
            // Does NOT change status - leaves it as is
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
            this.status = 'Failed';  // Use 'Failed' since 'Rate Limited' is not a valid picklist value
            return this;
        }
        
        public LogEntry withMetrics(Integer apiCallsMade, Integer cpuTimeUsed) {
            this.apiCallsMade = apiCallsMade;
            this.cpuTimeUsed = cpuTimeUsed;
            return this;
        }
        
        public LogEntry withDeduplication(Integer duplicatesFound, Integer duplicatesDeleted, Boolean deduplicationDeferred) {
            this.duplicatesFound = duplicatesFound;
            this.duplicatesDeleted = duplicatesDeleted;
            this.deduplicationDeferred = deduplicationDeferred;
            return this;
        }
    }
}