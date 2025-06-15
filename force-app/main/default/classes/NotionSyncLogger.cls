public with sharing class NotionSyncLogger {
    
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