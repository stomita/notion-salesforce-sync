# Architecture Review: Salesforce-Notion Sync

## Purpose
This document explains the architectural decisions and rationale for the Salesforce-Notion sync implementation. For handling large data volumes and batch processing, see [LARGE_DATA_SYNC.md](LARGE_DATA_SYNC.md).

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
- Difficult to handle partial failures
- Complex retry logic needed for resilience

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

3. **Scalability Foundation**
   - Handle real-time operations efficiently
   - Extensible to batch processing (see LARGE_DATA_SYNC.md)
   - Clear separation of sync patterns

4. **Error Isolation**
   - API failures don't affect DML transactions
   - Errors logged separately for analysis
   - Clear execution path

5. **Governor Limit Compliance**
   - Separate transaction contexts
   - Unlimited callout time in async
   - Better resource utilization

### Core Implementation Pattern:

The base architecture uses a simple pattern optimized for real-time, event-driven synchronization:

1. **Flow Trigger**: Captures record changes
2. **Invocable Apex**: Routes based on operation type and volume
3. **Async Processing**: @future for single records, Queueable for small batches
4. **Error Logging**: Asynchronous logging to avoid DML-callout conflicts

For detailed implementation including retry mechanisms, batch processing, and large volume handling, refer to [LARGE_DATA_SYNC.md](LARGE_DATA_SYNC.md).

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

The implemented Invocable Apex + Async Processing pattern provides optimal balance for real-time synchronization:

### Strengths:
- User context preservation (critical for Named Credentials)
- Real-time processing capability
- Clean error isolation
- Excellent user experience
- Simple deployment model

### Limitations:
- Limited to ~30-40 records per sync due to API callout limits
- No automatic retry mechanism in base implementation
- Requires enhancement for large data volumes

### Next Steps:
For organizations needing to sync large data volumes or requiring batch processing capabilities, implement the patterns described in [LARGE_DATA_SYNC.md](LARGE_DATA_SYNC.md), which extends this base architecture with:
- Batch Apex for large datasets
- Queueable chaining for medium volumes
- Retry mechanisms
- Progress tracking
- Scheduled sync capabilities