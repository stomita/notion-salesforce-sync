public with sharing class NotionSyncLogger {
    private static List<LogEntry> pendingLogs = new List<LogEntry>();
    
    @future
    public static void logAsync(List<String> logJsonList) {
        logSync(logJsonList);
    }
    
    // Synchronous version for testing
    public static void logSync(List<String> logJsonList) {
        List<Notion_Sync_Log__c> logs = new List<Notion_Sync_Log__c>();
        
        for (String logJson : logJsonList) {
            LogEntry entry = (LogEntry) JSON.deserialize(logJson, LogEntry.class);
            
            Notion_Sync_Log__c log = new Notion_Sync_Log__c(
                Record_Id__c = entry.recordId,
                Object_Type__c = entry.objectType,
                Operation_Type__c = entry.operationType,
                Status__c = entry.status,
                Error_Message__c = entry.errorMessage,
                Retry_Count__c = entry.retryCount
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
        pendingLogs.add(new LogEntry(recordId, objectType, operationType, status, errorMessage, retryCount));
    }
    
    // Flush all pending logs
    public static void flush() {
        if (!pendingLogs.isEmpty()) {
            List<String> logJsonList = new List<String>();
            for (LogEntry entry : pendingLogs) {
                logJsonList.add(JSON.serialize(entry));
            }
            
            if (Test.isRunningTest()) {
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
        
        public LogEntry(String recordId, String objectType, String operationType, 
                       String status, String errorMessage, Integer retryCount) {
            this.recordId = recordId;
            this.objectType = objectType;
            this.operationType = operationType;
            this.status = status;
            this.errorMessage = errorMessage;
            this.retryCount = retryCount;
        }
    }
}