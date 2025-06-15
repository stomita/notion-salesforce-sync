# Synchronous Processing Plan (No Platform Events)

## Overview
Remove Platform Events and use direct Flow → Invocable Apex pattern to maintain user context throughout the sync process.

## Current Architecture (Problems)
```
Flow → Platform Event → Trigger (Automated Process) → Queueable → Notion API
                              ↑
                              ❌ Loses user context
                              ❌ Can't access Named Credentials
```

## New Architecture (Solution)
```
Flow → Invocable Apex → @future or Queueable → Notion API
         ↑
         ✅ Maintains user context
         ✅ Can access Named Credentials
```

## Implementation Plan

### 1. Create Invocable Apex Method
```apex
public class NotionSyncInvocable {
    
    @InvocableMethod(label='Sync to Notion' description='Synchronizes records to Notion')
    public static List<SyncResult> syncToNotion(List<SyncRequest> requests) {
        // Process synchronously or enqueue for async
        List<Id> recordIds = new List<Id>();
        String objectType = null;
        String operationType = null;
        
        for (SyncRequest req : requests) {
            recordIds.add(req.recordId);
            objectType = req.objectType;
            operationType = req.operationType;
        }
        
        // Option A: Process immediately with @future
        if (recordIds.size() == 1) {
            processSyncFuture(recordIds[0], objectType, operationType);
        }
        // Option B: Enqueue for batch processing
        else {
            System.enqueueJob(new NotionSyncQueueable(recordIds, objectType, operationType));
        }
        
        return new List<SyncResult>{new SyncResult(true, 'Sync initiated')};
    }
    
    @future(callout=true)
    private static void processSyncFuture(Id recordId, String objectType, String operationType) {
        // Sync logic here - runs as the user who triggered the Flow
    }
    
    public class SyncRequest {
        @InvocableVariable(required=true label='Record ID')
        public Id recordId;
        
        @InvocableVariable(required=true label='Object Type')
        public String objectType;
        
        @InvocableVariable(required=true label='Operation Type')
        public String operationType;
    }
    
    public class SyncResult {
        @InvocableVariable
        public Boolean success;
        
        @InvocableVariable
        public String message;
        
        public SyncResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
}
```

### 2. Update Flows
Instead of creating Platform Events, Flows will:
1. Call the Invocable Apex action
2. Pass record ID, object type, and operation type
3. Maintain user context throughout

### 3. Benefits
- ✅ No Automated Process user issues
- ✅ Named Credentials work with user permissions
- ✅ Simpler architecture
- ✅ Easier to debug
- ✅ No special UI configuration needed

### 4. Considerations

**Pros:**
- User context maintained
- Works with standard Named Credential permissions
- No Platform Event limits
- Immediate processing possible

**Cons:**
- Subject to synchronous governor limits in Flow
- @future has limitations (can't chain, limited to 50 per transaction)
- Less decoupled than event-driven architecture

### 5. Migration Steps

1. Create new Invocable Apex class
2. Update Flows to use Apex Action instead of Platform Event
3. Remove Platform Event trigger
4. Remove Platform Event object (optional)
5. Test with regular user permissions

### 6. Governor Limits Comparison

| Aspect | Platform Events | Invocable Apex |
|--------|----------------|----------------|
| Callouts | Queueable (100) | @future (100) |
| Async Jobs | Unlimited (via trigger) | 50 @future per transaction |
| User Context | Lost (Automated Process) | Maintained |
| Bulk Processing | Natural batching | Manual batching needed |
| Retries | Built-in with replay | Manual implementation |

## Decision
Given the Named Credential access issues and the requirement for simple deployment without UI configuration, synchronous processing via Invocable Apex is the recommended approach.