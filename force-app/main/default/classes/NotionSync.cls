/**
 * Central class containing shared data structures and types for Notion sync operations
 */
global class NotionSync {
    
    /**
     * Request object for sync operations
     * Used across multiple components to pass sync request details
     */
    global class Request {
        @InvocableVariable(
            required=true 
            label='Record ID' 
            description='ID of the record to sync'
        )
        global String recordId;
        
        @InvocableVariable(
            required=true 
            label='Object Type' 
            description='API name of the object (e.g., Account)'
        )
        global String objectType;
        
        @InvocableVariable(
            required=true 
            label='Operation Type' 
            description='CREATE, UPDATE, or DELETE'
        )
        global String operationType;
        
        global Request() {}
        
        global Request(String recordId, String objectType, String operationType) {
            this.recordId = recordId;
            this.objectType = objectType;
            this.operationType = operationType;
        }
    }
    
    /**
     * Result object for sync operations
     * Used to return sync results
     */
    global class Result {
        @InvocableVariable(label='Success')
        global Boolean success;
        
        @InvocableVariable(label='Message')
        global String message;
        
        global Result() {}
        
        global Result(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
    
    /**
     * Exception class for sync-related errors
     */
    public class SyncException extends Exception {}
    
    /**
     * Operation types
     */
    public static final String OPERATION_CREATE = 'CREATE';
    public static final String OPERATION_UPDATE = 'UPDATE';
    public static final String OPERATION_DELETE = 'DELETE';
    
    /**
     * Status values
     */
    public static final String STATUS_SUCCESS = 'Success';
    public static final String STATUS_FAILED = 'Failed';
    public static final String STATUS_DEFERRED = 'Deferred';
    // Note: Rate limited requests use STATUS_FAILED with Rate_Limited__c = true
}