# Large Data Sync Architecture

## Overview

This document describes how the Salesforce-Notion sync handles large-scale data synchronization using runtime governor limit checking and automatic queueable chaining. The architecture processes records individually and automatically chains when approaching limits, eliminating the need for pre-batching.

## Current Implementation Features

The implementation handles large data volumes through intelligent runtime processing:

### 1. Governor Limit Awareness
- **Runtime Checking**: Monitors governor limits during execution
- **Automatic Chaining**: Chains to next queueable when approaching limits
- **Typical Processing**: ~19 records per queueable execution
- **Complete Processing**: All records eventually processed through the chain
- **No Pre-Batching**: System automatically handles record distribution

### 2. Notion API Rate Limit Handling
- **Request Rate**: Respects 3 requests per second limit
- **Rate Limit Detection**: Handles 429 responses appropriately
- **Automatic Spacing**: Built-in delays between requests
- **Governor-Based Throttling**: Natural rate limiting through governor constraints

### 3. Architecture Advantages
- Individual record processing with runtime checks
- Self-chaining queueable pattern
- Automatic deduplication after completion
- No complex batch size calculations needed
- Simple, maintainable code structure

## Architecture for Large Data Sync

The architecture uses runtime governor limit checking to automatically handle any volume of data:

### 1. Runtime Governor Limit Checking

#### Enhanced Rate Limiter with Runtime Checks

```apex
public class NotionRateLimiter {
    private static final Integer REQUESTS_PER_SECOND = 3;
    
    public class RateLimitException extends Exception {}
    
    /**
     * Check if processing should stop based on governor limits
     * Called during record processing to determine when to chain
     */
    public static Boolean shouldStopProcessing() {
        Integer remainingCallouts = Limits.getLimitCallouts() - Limits.getCallouts();
        Integer remainingCpu = Limits.getLimitCpuTime() - Limits.getCpuTime();
        Decimal heapUsage = Limits.getLimitHeapSize() > 0 ? 
            Decimal.valueOf(Limits.getHeapSize()) / Limits.getLimitHeapSize() : 0;
        
        // Stop if approaching any limit threshold
        Boolean shouldStop = (remainingCallouts < 6) || 
                           (remainingCpu < 5000) || 
                           (heapUsage > 0.85);
        
        if (shouldStop) {
            System.debug('Approaching limits - Callouts remaining: ' + remainingCallouts + 
                       ', CPU remaining: ' + remainingCpu + 'ms, Heap usage: ' + 
                       (heapUsage * 100).setScale(1) + '%');
        }
        
        return shouldStop;
    }
    
    public static void throttleRequest() {
        // Check if we're too close to callout limit
        if (Limits.getCallouts() >= Limits.getLimitCallouts() - 2) {
            throw new RateLimitException(
                String.format('Approaching callout limit ({0}/{1})',
                    new List<Object>{Limits.getCallouts(), Limits.getLimitCallouts()})
            );
        }
        
        // Rate limiting logic for 3 req/sec
        DateTime lastRequest = getLastRequestTime();
        if (lastRequest != null) {
            Long millisecondsSinceLastRequest = DateTime.now().getTime() - lastRequest.getTime();
            Long minimumInterval = 1000 / REQUESTS_PER_SECOND; // 333ms between requests
            
            if (millisecondsSinceLastRequest < minimumInterval) {
                throw new RateLimitException('Rate limit requires delay');
            }
        }
        
        setLastRequestTime(DateTime.now());
    }
    
    public static Map<String, Object> getGovernorLimitStatusMap() {
        return new Map<String, Object>{
            'calloutsUsed' => Limits.getCallouts(),
            'calloutLimit' => Limits.getLimitCallouts(),
            'cpuTimeUsed' => Limits.getCpuTime(),
            'cpuTimeLimit' => Limits.getLimitCpuTime(),
            'heapUsed' => Limits.getHeapSize(),
            'heapLimit' => Limits.getLimitHeapSize()
        };
    }
}
```

### 2. Self-Chaining Queueable Implementation

```apex
public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<NotionSync.Request> allRequests;
    private Integer startIndex;
    private NotionSyncLogger logger;
    private NotionSyncProcessor processor;
    private Set<Id> allRecordIds; // Track all records for deduplication
    private String currentObjectType;
    
    public NotionSyncQueueable(List<NotionSync.Request> requests) {
        this(requests, 0);
    }
    
    public NotionSyncQueueable(List<NotionSync.Request> requests, Integer startIndex) {
        this.allRequests = requests;
        this.startIndex = startIndex != null ? startIndex : 0;
        this.logger = new NotionSyncLogger();
        this.processor = new NotionSyncProcessor(this.logger);
        
        // Extract ALL record IDs for deduplication
        this.allRecordIds = new Set<Id>();
        for (NotionSync.Request request : requests) {
            if (request.operationType != 'DELETE' && String.isNotBlank(request.recordId)) {
                this.allRecordIds.add(request.recordId);
                if (String.isNotBlank(request.objectType)) {
                    this.currentObjectType = request.objectType;
                }
            }
        }
    }
    
    public void execute(QueueableContext context) {
        Integer currentIndex = startIndex;
        
        try {
            System.debug('Starting at index ' + startIndex + ' with ' + 
                       allRequests.size() + ' total requests');
            
            // Process records individually with runtime checking
            while (currentIndex < allRequests.size()) {
                // Check limits BEFORE processing (except first record)
                if (currentIndex > startIndex && NotionRateLimiter.shouldStopProcessing()) {
                    System.debug('Approaching limits at index ' + currentIndex);
                    break;
                }
                
                // Process single record
                NotionSync.Request request = allRequests[currentIndex];
                processSingleRequest(request);
                currentIndex++;
                
                // Log progress
                Map<String, Object> limits = NotionRateLimiter.getGovernorLimitStatusMap();
                System.debug('Processed index ' + (currentIndex - 1) + ': ' +
                           'Callouts: ' + limits.get('calloutsUsed') + '/' + 
                           limits.get('calloutLimit'));
            }
            
            // Chain if more records remain
            if (currentIndex < allRequests.size()) {
                chainNextBatch(currentIndex);
            } else {
                // All done - trigger deduplication
                handleDeduplication();
            }
            
        } finally {
            logger.flush();
        }
    }
    
    private void chainNextBatch(Integer nextIndex) {
        if (!Test.isRunningTest()) {
            System.debug('Chaining next batch starting at index ' + nextIndex);
            System.enqueueJob(new NotionSyncQueueable(allRequests, nextIndex));
        }
    }
    
    private void handleDeduplication() {
        if (!allRecordIds.isEmpty() && String.isNotBlank(currentObjectType)) {
            System.enqueueJob(new NotionDeduplicationQueueable(
                allRecordIds, currentObjectType));
        }
    }
}
```

#### Processing Characteristics

With runtime limit checking, the system automatically adapts to:

- **Typical Processing**: ~19 records per queueable execution
- **No Fixed Batch Sizes**: System determines when to chain based on actual usage
- **Complete Processing**: All records eventually processed through the chain
- **Natural Rate Limiting**: Governor limits provide inherent throttling

### 3. Processing Flow Example

Here's how the system handles a large dataset:

```
Example: Processing 75 Account records

1. Flow triggers NotionSyncInvocable with 75 records
2. NotionSyncInvocable enqueues NotionSyncQueueable with all 75 requests
3. First NotionSyncQueueable execution:
   - Processes records 0-18 (19 records)
   - Hits governor limit threshold
   - Chains to next queueable starting at index 19
4. Second NotionSyncQueueable execution:
   - Processes records 19-37 (19 records)
   - Hits governor limit threshold
   - Chains to next queueable starting at index 38
5. Third NotionSyncQueueable execution:
   - Processes records 38-56 (19 records)
   - Hits governor limit threshold
   - Chains to next queueable starting at index 57
6. Fourth NotionSyncQueueable execution:
   - Processes records 57-74 (18 records)
   - All records complete
   - Enqueues NotionDeduplicationQueueable for all 75 records
7. NotionDeduplicationQueueable runs to handle any duplicates

Total: 75 records processed in 4 queueable executions + 1 deduplication
```

### 4. Scheduled Sync Implementation

For regular bulk synchronization:

```apex
public class NotionSyncScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Get configured objects for scheduled sync
        List<NotionSyncObject__mdt> syncObjects = [
            SELECT ObjectApiName__c 
            FROM NotionSyncObject__mdt 
            WHERE IsActive__c = true 
            AND EnableScheduledSync__c = true
        ];
        
        for (NotionSyncObject__mdt syncObject : syncObjects) {
            // Query records to sync
            List<SObject> recordsToSync = Database.query(
                'SELECT Id FROM ' + syncObject.ObjectApiName__c + 
                ' WHERE LastModifiedDate >= :DateTime.now().addDays(-1)'
            );
            
            // Create sync requests
            List<NotionSync.Request> requests = new List<NotionSync.Request>();
            for (SObject record : recordsToSync) {
                requests.add(new NotionSync.Request(
                    record.Id, 
                    syncObject.ObjectApiName__c, 
                    'UPDATE'
                ));
            }
            
            // Enqueue for processing
            if (!requests.isEmpty()) {
                System.enqueueJob(new NotionSyncQueueable(requests));
            }
        }
    }
}
```

### 5. Progress Tracking

The existing `Notion_Sync_Log__c` object tracks individual record sync status. For monitoring large sync operations, you can query aggregated data:

```apex
// Get sync progress for current batch
AggregateResult[] results = [
    SELECT Status__c, COUNT(Id) recordCount
    FROM Notion_Sync_Log__c
    WHERE CreatedDate >= :DateTime.now().addHours(-1)
    GROUP BY Status__c
];

for (AggregateResult ar : results) {
    System.debug(ar.get('Status__c') + ': ' + ar.get('recordCount'));
}
```

### 6. Retry Mechanism

For failed syncs, implement a simple retry mechanism:

```apex
public class NotionSyncRetryScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Query recent failed sync logs
        List<Notion_Sync_Log__c> failedLogs = [
            SELECT Record_Id__c, Object_Type__c, Retry_Count__c
            FROM Notion_Sync_Log__c
            WHERE Status__c = 'Failed'
            AND CreatedDate >= :DateTime.now().addHours(-24)
            AND Retry_Count__c < 3
            LIMIT 200
        ];
        
        if (!failedLogs.isEmpty()) {
            // Group by object type
            Map<String, List<NotionSync.Request>> requestsByType = 
                new Map<String, List<NotionSync.Request>>();
            
            for (Notion_Sync_Log__c log : failedLogs) {
                if (!requestsByType.containsKey(log.Object_Type__c)) {
                    requestsByType.put(log.Object_Type__c, new List<NotionSync.Request>());
                }
                
                requestsByType.get(log.Object_Type__c).add(
                    new NotionSync.Request(
                        log.Record_Id__c,
                        log.Object_Type__c,
                        'UPDATE'
                    )
                );
            }
            
            // Enqueue retries by object type
            for (List<NotionSync.Request> requests : requestsByType.values()) {
                System.enqueueJob(new NotionSyncQueueable(requests));
            }
        }
    }
}
```

## Implementation Benefits

The runtime limit checking approach provides several advantages:

### 1. Simplified Architecture
- Single queueable class handles all volumes
- No complex batch size calculations
- Automatic adaptation to governor limits
- Self-managing process flow

### 2. Consistent Processing
- Same code path for all record volumes
- Predictable behavior
- Easy to test and debug
- No special cases for different volumes

### 3. Optimal Resource Usage
- Processes maximum records per execution
- Natural rate limiting through governor constraints
- Efficient CPU and heap utilization
- Automatic throttling

## Usage Guidelines

### When to Use Each Approach

1. **Real-time Flow Sync** (Base Implementation - see ARCHITECTURE_REVIEW.md)
   - Single record operations
   - Small batches (<50 records)
   - Immediate sync requirement
   - User-triggered changes

2. **Queueable Chain** (Enhancement for medium volumes)
   - Medium datasets (50-1000 records)
   - Near real-time requirement
   - Complex relationship handling needed
   - Bulk Flow operations

3. **Batch Apex** (Enhancement for large volumes)
   - Large datasets (>1000 records)
   - Scheduled/periodic sync
   - Initial data migration
   - Bulk data corrections

4. **Scheduled Sync**
   - Regular synchronization needs
   - Non-critical timing
   - Overnight processing
   - Full database refresh

## Configuration

### New Metadata Fields

Add to `NotionSyncObject__mdt`:
- `EnableScheduledSync__c` (Checkbox)
- `BatchSize__c` (Number, default: 20)
- `ScheduleCron__c` (Text) - Cron expression for scheduling

### Invocable Method Enhancement

Add new parameters to `NotionSyncInvocable`:
- `syncMode`: 'REALTIME' | 'BATCH' | 'SCHEDULED'
- `batchSize`: Number (optional)

## Governor Limit Management

### Runtime Limit Checking

The system automatically monitors and responds to governor limits:

1. **Primary Constraints**:
   - Callout Limit: 100 per transaction
   - CPU Time: 60 seconds for async
   - Heap Size: 12MB for async
   - API Rate: 3 requests/second

2. **Automatic Adaptation**:
   - Checks limits before each record
   - Chains when approaching thresholds
   - Typically processes ~19 records per execution
   - No manual tuning required

3. **Natural Throttling**:
   - Governor limits provide inherent rate limiting
   - No complex delay mechanisms needed
   - System self-regulates processing speed


### Rate Limit Handling

The system handles rate limits through natural governor constraints:

1. **Built-in Throttling**:
   - Processing ~19 records typically takes several seconds
   - Natural spacing between API calls
   - Governor limits prevent overwhelming the API

2. **429 Response Handling**:
   - Detected and logged appropriately
   - Failed records can be retried later
   - Use scheduled retry job for systematic recovery

3. **No Complex Delays Needed**:
   - Queueable chaining provides natural spacing
   - Governor limits enforce reasonable processing rate
   - System self-manages without artificial delays

## Processing Characteristics

### Runtime Behavior

The system exhibits consistent processing patterns:

1. **Records Per Execution**:
   - Typically ~19 records before hitting limits
   - Varies slightly based on record complexity
   - No manual configuration needed

2. **Execution Time**:
   - Each queueable runs for several seconds
   - Natural API rate compliance
   - Efficient resource utilization

3. **Scalability**:
   - Handles any volume through chaining
   - Linear processing time
   - Predictable behavior

## Best Practices

### 1. Simplified Processing

**Automatic Handling**:
- No batch size configuration needed
- Runtime checks handle all volumes
- Natural rate limit compliance
- Self-managing system

### 2. Rate Limit Monitoring

**Custom Object**: `Notion_API_Usage__c`
```
- Request_Time__c (DateTime)
- Request_Type__c (Text)
- Response_Code__c (Number)
- Rate_Limited__c (Checkbox)
- Retry_After__c (Number)
```

**Monitoring Dashboard**:
- Requests per minute/hour trends
- Rate limit hit frequency
- Average response times
- Failed request patterns

### 3. Scheduling Strategy

**Simple Scheduling**:
- Use standard Salesforce schedulable
- Query modified records periodically
- Enqueue for processing
- Let the system handle volume

**Example**:
```apex
// Simple scheduled sync
public void execute(SchedulableContext sc) {
    List<Account> modifiedAccounts = [
        SELECT Id FROM Account 
        WHERE LastModifiedDate >= :DateTime.now().addHours(-1)
    ];
    
    if (!modifiedAccounts.isEmpty()) {
        NotionSyncInvocable.syncRecords(modifiedAccounts);
    }
}
```

### 4. Error Handling Best Practices

**Rate Limit Specific**:
- Always check for 429 status code
- Honor Retry-After header
- Implement exponential backoff
- Track rate limit patterns

**General Error Handling**:
- Log all errors with full context
- Separate transient vs. permanent failures
- Alert on repeated rate limiting
- Automatic pause on excessive 429s

### 5. Performance Optimization

**API Call Reduction**:
- Batch relationship lookups
- Cache frequently accessed data
- Use bulk endpoints where available
- Minimize unnecessary updates

**Processing Optimization**:
- Process parent objects first
- Group records by relationship complexity
- Use parallel processing carefully
- Monitor CPU and heap usage

## Migration Path

For existing implementations:

1. Update to new NotionSyncQueueable with runtime checking
2. Remove any batch size configurations
3. Let the system handle volume automatically
4. Monitor performance through sync logs

## Testing Strategy

1. **Unit Tests**
   - Test runtime limit checking logic
   - Verify queueable chaining behavior
   - Test deduplication after completion

2. **Integration Tests**
   - Test with real Notion API
   - Verify large dataset handling
   - Test interruption and resume

3. **Performance Tests**
   - Measure sync times for various volumes
   - Monitor automatic chaining behavior
   - Verify governor limit detection

## Monitoring and Alerts

1. **Dashboards**
   - Sync performance metrics
   - Error rates and patterns
   - API usage statistics

2. **Alerts**
   - Failed sync operations
   - High error rates
   - Unusual processing patterns

3. **Reports**
   - Daily sync summary
   - Weekly performance trends
   - Monthly volume analysis