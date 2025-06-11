public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<SyncRequest> requests;
    
    public NotionSyncQueueable(List<SyncRequest> requests) {
        this.requests = requests;
    }
    
    public void execute(QueueableContext context) {
        // Process sync requests
        // Make Notion API callouts
        // Handle errors and retries
    }
    
    public class SyncRequest {
        public String recordId;
        public String objectType;
        public String operationType;
        
        public SyncRequest(String recordId, String objectType, String operationType) {
            this.recordId = recordId;
            this.objectType = objectType;
            this.operationType = operationType;
        }
    }
}