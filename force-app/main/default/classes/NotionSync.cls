/**
 * Central class containing shared data structures and types for Notion sync operations
 */
public class NotionSync {
    
    /**
     * Request object for sync operations
     * Used across multiple components to pass sync request details
     */
    public class Request {
        @InvocableVariable(
            required=true 
            label='Record ID' 
            description='ID of the record to sync'
        )
        public String recordId;
        
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
        
        public Request() {}
        
        public Request(String recordId, String objectType, String operationType) {
            this.recordId = recordId;
            this.objectType = objectType;
            this.operationType = operationType;
        }
    }
    
    /**
     * Result object for sync operations
     * Used to return sync results
     */
    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;
        
        @InvocableVariable(label='Message')
        public String message;
        
        public Result() {}
        
        public Result(Boolean success, String message) {
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
    public static final String STATUS_RATE_LIMITED = 'Rate Limited';
}