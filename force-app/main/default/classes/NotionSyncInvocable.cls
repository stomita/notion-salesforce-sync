/**
 * Invocable class for Notion synchronization
 * Called directly from Flows to maintain user context for Named Credential access
 */
public with sharing class NotionSyncInvocable {
    
    // Test flag to disable processing during unit tests
    @TestVisible
    private static Boolean disableInTest = false;
    
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
        
        // Skip processing in test context to avoid interference with unit tests
        // Tests will directly call NotionSyncQueueable for testing
        if (Test.isRunningTest() && disableInTest) {
            for (SyncRequest request : requests) {
                results.add(new SyncResult(true, 'Skipped in test context'));
            }
            return results;
        }
        
        try {
            // For single record operations (non-delete), use @future for immediate processing
            if (requests.size() == 1 && requests[0].operationType != 'DELETE') {
                SyncRequest request = requests[0];
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
                
                // Batch all requests together
                for (SyncRequest request : requests) {
                    queueableRequests.add(new NotionSyncQueueable.SyncRequest(
                        request.recordId,
                        request.objectType,
                        request.operationType
                    ));
                }
                
                // Enqueue once with all requests
                System.enqueueJob(new NotionSyncQueueable(queueableRequests));
                
                // Return success for all
                for (SyncRequest request : requests) {
                    results.add(new SyncResult(true, 'Sync queued for processing'));
                }
            }
        } catch (Exception e) {
            // If there's an error, return error result for all requests
            for (SyncRequest request : requests) {
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