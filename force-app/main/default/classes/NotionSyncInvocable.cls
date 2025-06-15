/**
 * Invocable class for Notion synchronization
 * Called directly from Flows to maintain user context for Named Credential access
 */
public with sharing class NotionSyncInvocable {
    
    /**
     * Invocable method to sync records to Notion
     * Maintains user context throughout the process
     */
    @InvocableMethod(
        label='Sync Record to Notion' 
        description='Synchronizes a Salesforce record to Notion database'
        category='Notion Integration'
    )
    public static List<SyncResult> syncToNotion(List<SyncRequest> requests) {
        List<SyncResult> results = new List<SyncResult>();
        
        // Process each request
        for (SyncRequest request : requests) {
            try {
                // For single record operations, use @future for immediate processing
                if (requests.size() == 1 && request.operationType != 'DELETE') {
                    processSyncFuture(
                        request.recordId, 
                        request.objectType, 
                        request.operationType
                    );
                    results.add(new SyncResult(true, 'Sync initiated successfully'));
                }
                // For bulk operations or deletes, use Queueable
                else {
                    List<NotionSyncQueueable.SyncRequest> queueableRequests = 
                        new List<NotionSyncQueueable.SyncRequest>();
                    
                    queueableRequests.add(new NotionSyncQueueable.SyncRequest(
                        request.recordId,
                        request.objectType,
                        request.operationType
                    ));
                    
                    System.enqueueJob(new NotionSyncQueueable(queueableRequests));
                    results.add(new SyncResult(true, 'Sync queued for processing'));
                }
            } catch (Exception e) {
                results.add(new SyncResult(false, 'Error: ' + e.getMessage()));
            }
        }
        
        return results;
    }
    
    /**
     * Future method for immediate single-record sync
     * Runs in user context, maintaining Named Credential access
     */
    @future(callout=true)
    private static void processSyncFuture(Id recordId, String objectType, String operationType) {
        try {
            // Create sync request
            NotionSyncQueueable.SyncRequest request = new NotionSyncQueueable.SyncRequest(
                recordId,
                objectType,
                operationType
            );
            
            // Process sync immediately
            NotionSyncQueueable queueable = new NotionSyncQueueable(
                new List<NotionSyncQueueable.SyncRequest>{request}
            );
            
            // Execute sync logic directly (not as job)
            queueable.processSyncRequests(new List<NotionSyncQueueable.SyncRequest>{request});
            
        } catch (Exception e) {
            // Log error
            NotionSyncLogger.log(
                recordId, 
                objectType, 
                operationType, 
                'Failed',
                'Future method error: ' + e.getMessage(),
                0
            );
            NotionSyncLogger.flush();
        }
    }
    
    /**
     * Request wrapper for Flow inputs
     */
    public class SyncRequest {
        @InvocableVariable(
            required=true 
            label='Record ID' 
            description='ID of the record to sync'
        )
        public Id recordId;
        
        @InvocableVariable(
            required=true 
            label='Object Type' 
            description='API name of the object (e.g., Account)'
        )
        public String objectType;
        
        @InvocableVariable(
            required=true 
            label='Operation Type' 
            description='CREATE, UPDATE, or DELETE'
        )
        public String operationType;
    }
    
    /**
     * Result wrapper for Flow outputs
     */
    public class SyncResult {
        @InvocableVariable(label='Success')
        public Boolean success;
        
        @InvocableVariable(label='Message')
        public String message;
        
        public SyncResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
}