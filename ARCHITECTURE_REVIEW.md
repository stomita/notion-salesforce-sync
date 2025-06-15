# Architecture Review: Salesforce-Notion Sync

## Current Approach Issues

### 1. Transaction Limitations
- Flow-triggered Apex runs in the same transaction as the DML operation
- External API calls (Notion API) within transactions cause:
  - 10-second callout timeout limit
  - Maximum 100 callouts per transaction
  - Transaction lock issues
  - Poor user experience (UI freezes)

### 2. Governor Limits Risk
- Multiple API calls for relationship handling
- Heap size limitations with large data
- CPU time limits when processing complex relationships

### 3. Error Handling Challenges
- API failures would rollback entire transaction
- No built-in retry mechanism
- Difficult to handle partial failures

## Recommended Architecture: Flow-Driven Asynchronous Processing

### Invocable Apex + Queueable/Future Pattern

```
[Record Change] → [Flow] → [Invocable Apex] → [Queueable/Future] → [Notion API]
```

### Benefits:
1. **User Context Preservation**
   - Maintains executing user's permissions
   - Works with Named Credentials via permission set assignment
   - No special UI configuration needed

2. **Decoupled Architecture**
   - UI operations complete immediately
   - Background processing for API calls
   - No transaction blocking

3. **Scalability**
   - Handle bulk operations efficiently
   - Process records in batches
   - Chain Queueable jobs for large datasets

4. **Reliability**
   - Built-in retry mechanism
   - Error isolation
   - Clear execution path

5. **Governor Limit Compliance**
   - Separate transaction contexts
   - Unlimited callout time in async
   - Better resource utilization

### Implementation Components:

1. **Invocable Apex**: `NotionSyncInvocable`
   - Entry point for Flow integration
   - Maintains user context
   - Routes to appropriate async method
   - Single records: @future for immediate processing
   - Bulk/Deletes: Queueable for batch processing

2. **Queueable Apex**: `NotionSyncQueueable`
   - Process records in batches
   - Handle API calls with proper error handling
   - Chain for continuation

3. **Future Method**: For single record operations
   - Immediate processing
   - Maintains user context
   - Ideal for UI-triggered syncs

4. **Error Handling**: `NotionSyncLogger`
   - In-memory log aggregation
   - Bulk insert of logs
   - Tracks sync status and errors

### Alternative Approaches Considered:

1. **Platform Events**
   - Pros: Fully decoupled, scalable
   - Cons: Loses user context (runs as Automated Process user), requires complex credential setup

2. **Change Data Capture (CDC)**
   - Pros: Native Salesforce feature, automatic change tracking
   - Cons: Limited control, requires additional configuration

3. **Direct @future Methods**
   - Pros: Simple implementation
   - Cons: No chaining, limited error handling, 50 calls limit

4. **Batch Apex**
   - Pros: Good for large volumes
   - Cons: Not real-time, minimum 1-minute delay

## Recommendation
Implement Invocable Apex + Async Processing pattern for optimal balance of:
- User context preservation (critical for Named Credentials)
- Real-time processing
- Scalability
- Error handling
- User experience
- Maintainability
- Simplified deployment (no UI configuration required)