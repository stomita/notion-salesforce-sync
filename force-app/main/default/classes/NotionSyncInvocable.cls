/**
 * Invocable class for Notion synchronization
 * Called directly from Flows to maintain user context for Named Credential access
 */
global with sharing class NotionSyncInvocable {
    
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
    global static List<NotionSync.Result> syncToNotion(List<NotionSync.Request> requests) {
        List<NotionSync.Result> results = new List<NotionSync.Result>();
        
        // Skip processing in test context to avoid interference with unit tests
        // Tests will directly call NotionSyncQueueable for testing
        if (Test.isRunningTest() && disableInTest) {
            for (NotionSync.Request request : requests) {
                results.add(new NotionSync.Result(true, 'Skipped in test context'));
            }
            return results;
        }
        
        try {
            // Always enqueue to separate the sync transaction from the Flow transaction
            // This prevents sync failures from affecting the Flow
            System.enqueueJob(new NotionSyncBatchQueueable(requests));
            
            // Return success for all
            for (NotionSync.Request request : requests) {
                results.add(new NotionSync.Result(true, 'Sync initiated successfully'));
            }
            
        } catch (Exception e) {
            // If there's an error, return error result for all requests
            for (NotionSync.Request request : requests) {
                results.add(new NotionSync.Result(false, 'Error: ' + e.getMessage()));
            }
        }
        
        return results;
    }
    
}