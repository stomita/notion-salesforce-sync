# Large Data Sync Architecture

## Overview

This document extends the base architecture described in [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md) to handle large-scale data synchronization between Salesforce and Notion. While the base architecture excels at real-time, event-driven sync, this document addresses volume-based processing needs.

## Current Implementation Limitations

The base implementation (see ARCHITECTURE_REVIEW.md) is optimized for real-time synchronization but has the following limitations for large data volumes:

### 1. Governor Limits
- **Callout Limit**: 100 callouts per transaction
- **Callout Time**: 120 seconds per callout, 120 seconds total per transaction
- **CPU Time**: 10 seconds for synchronous, 60 seconds for asynchronous
- **Practical Record Limit**: ~30-40 records per sync (considering relationship lookups)
- **Heap Size**: 12MB for asynchronous transactions
- **Query Rows**: 50,000 records

### 2. Notion API Rate Limits
- **Request Rate**: 3 requests per second average (with some burst allowance)
- **No Rate Limit Handling**: Current implementation doesn't handle 429 errors
- **No Retry Logic**: Missing Retry-After header handling
- **Risk of API Blocking**: Large syncs could exceed rate limits

### 3. Architectural Constraints
- No chunking mechanism for large datasets
- All records processed in single transaction
- No progress tracking or resume capability
- No automatic retry mechanism in base implementation
- Memory constraints with large data volumes
- No request throttling or queuing

## Enhanced Architecture for Large Data Sync

Building upon the base Invocable + Async pattern, the following enhancements support large-scale synchronization with proper rate limit handling:

### 1. Rate Limit Aware Processing

#### API Rate Limiter Component

```apex
public class NotionRateLimiter {
    private static final Integer REQUESTS_PER_SECOND = 3;
    private static final Decimal CALLOUT_BUFFER_PERCENTAGE = 0.9; // Use 90% of limit
    private static Map<String, DateTime> requestTimestamps = new Map<String, DateTime>();
    
    public class RateLimitException extends Exception {}
    
    public static Boolean shouldDeferProcessing() {
        // Dynamically check governor limits
        Integer calloutsUsed = Limits.getCallouts();
        Integer calloutLimit = Limits.getLimitCallouts();
        
        // Also check CPU time
        Integer cpuUsed = Limits.getCpuTime();
        Integer cpuLimit = Limits.getLimitCpuTime();
        
        return (calloutsUsed >= calloutLimit * CALLOUT_BUFFER_PERCENTAGE) ||
               (cpuUsed >= cpuLimit * CALLOUT_BUFFER_PERCENTAGE);
    }
    
    public static void throttleRequest() {
        // Check callout limit first
        if (Limits.getCallouts() >= Limits.getLimitCallouts() - 5) {
            throw new RateLimitException(
                String.format('Approaching callout limit ({0}/{1}), defer to next async job',
                    new List<Object>{Limits.getCallouts(), Limits.getLimitCallouts()})
            );
        }
        
        DateTime lastRequest = getLastRequestTime();
        if (lastRequest != null) {
            Long millisecondsSinceLastRequest = DateTime.now().getTime() - lastRequest.getTime();
            Long minimumInterval = 1000 / REQUESTS_PER_SECOND; // 333ms between requests
            
            if (millisecondsSinceLastRequest < minimumInterval) {
                // Don't busy wait - instead defer to next async job
                // This avoids CPU consumption and allows natural spacing
                throw new RateLimitException('Rate limit requires delay, defer to next batch');
            }
        }
        
        setLastRequestTime(DateTime.now());
    }
    
    public static Map<String, Integer> getGovernorLimitStatus() {
        return new Map<String, Integer>{
            'calloutsUsed' => Limits.getCallouts(),
            'calloutLimit' => Limits.getLimitCallouts(),
            'cpuTimeUsed' => Limits.getCpuTime(),
            'cpuTimeLimit' => Limits.getLimitCpuTime(),
            'heapUsed' => Limits.getHeapSize(),
            'heapLimit' => Limits.getLimitHeapSize()
        };
    }
    
    public static Boolean handleRateLimit(HttpResponse response) {
        if (response.getStatusCode() == 429) {
            String retryAfter = response.getHeader('Retry-After');
            if (String.isNotBlank(retryAfter)) {
                // Store retry information for later processing
                Integer secondsToWait = Integer.valueOf(retryAfter);
                // Always defer to next async job for rate limit retries
                return true;
            }
        }
        return false;
    }
}
```

#### Enhanced API Client with Rate Limit Handling

```apex
public static NotionResponse createPageWithRateLimit(NotionPageRequest pageRequest) {
    NotionRateLimiter.throttleRequest();
    
    HttpResponse response = sendRequest(pageRequest);
    
    if (NotionRateLimiter.handleRateLimit(response)) {
        // For batch processing, add to retry queue
        // For queueable, chain with delay
        return new NotionResponse(false, null, 'Rate limited - will retry', 429, null);
    }
    
    return processResponse(response);
}
```

### 2. Batch Apex Implementation with Rate Limiting

```apex
public class NotionSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private String objectType;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private Integer rateLimitCount = 0;
    private List<String> errors = new List<String>();
    private static final Integer MAX_BATCH_SIZE = 10; // Stay well under rate limit
    
    public NotionSyncBatch(String objectType) {
        this.objectType = objectType;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Store batch job ID for monitoring
        Notion_Batch_Sync__c batchSync = new Notion_Batch_Sync__c(
            Object_Type__c = objectType,
            Status__c = 'In Progress',
            Start_Time__c = DateTime.now(),
            Batch_Job_Id__c = bc.getJobId()
        );
        insert batchSync;
        
        return Database.getQueryLocator(buildQuery());
    }
    
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        // Track processed records for this execution
        List<Id> unprocessedIds = new List<Id>();
        Integer processedInBatch = 0;
        
        for (SObject record : scope) {
            // Check CPU time before each record
            if (NotionRateLimiter.shouldDeferProcessing()) {
                // Add remaining records to unprocessed list
                unprocessedIds.add(record.Id);
                continue;
            }
            
            try {
                // Throttle to stay under 3 requests/second
                NotionRateLimiter.throttleRequest();
                
                NotionResponse response = syncRecord(record);
                processedInBatch++;
                
                if (response.statusCode == 429) {
                    rateLimitCount++;
                    // Add to retry queue for later processing
                    scheduleRetry(record.Id);
                } else if (response.success) {
                    successCount++;
                } else {
                    errorCount++;
                    errors.add(record.Id + ': ' + response.errorMessage);
                }
                
            } catch (NotionRateLimiter.RateLimitException e) {
                // Defer remaining records to next batch
                unprocessedIds.add(record.Id);
                for (Integer i = scope.indexOf(record) + 1; i < scope.size(); i++) {
                    unprocessedIds.add(scope[i].Id);
                }
                break;
            } catch (Exception e) {
                errorCount++;
                errors.add(record.Id + ': ' + e.getMessage());
            }
        }
        
        // If we have unprocessed records due to CPU limits, create new batch
        if (!unprocessedIds.isEmpty()) {
            // Store unprocessed IDs for next batch
            createDeferredBatch(unprocessedIds);
        }
        
        System.debug('Processed ' + processedInBatch + ' records in this batch execution');
        System.debug('CPU Time Used: ' + Limits.getCpuTime() + 'ms');
    }
    
    public void finish(Database.BatchableContext bc) {
        // Update batch sync record
        updateBatchSyncRecord(bc.getJobId());
        
        // Schedule retry job if needed
        if (rateLimitCount > 0) {
            // Schedule retry after delay
            DateTime retryTime = DateTime.now().addMinutes(5);
            System.scheduleBatch(new NotionSyncRetryBatch(objectType), 
                'Notion Retry ' + objectType, 5);
        }
    }
}
```

#### Optimal Batch Sizes Based on Rate Limits

Given Notion's 3 requests/second limit, recommended batch sizes:

- **Simple objects (no relationships)**: 10 records per batch
- **Objects with 1-2 lookups**: 5-7 records per batch  
- **Complex objects (many relationships)**: 3-5 records per batch

This ensures processing stays under rate limits even with relationship lookups.

### 3. Queueable Chain with Rate Limit Management

For medium-sized datasets that exceed single transaction limits:

```apex
public class NotionSyncQueueableChain implements Queueable, Database.AllowsCallouts {
    private List<Id> recordIds;
    private Integer batchSize = 5; // Reduced for rate limit compliance
    private Integer currentIndex = 0;
    private String objectType;
    private DateTime lastRequestTime;
    private Integer retryDelaySeconds = 0;
    
    public void execute(QueueableContext context) {
        // Check if we're in a retry delay
        if (retryDelaySeconds > 0) {
            // Re-enqueue with delay
            enqueueWithDelay(retryDelaySeconds);
            return;
        }
        
        // Process current batch with rate limiting and CPU monitoring
        List<Id> currentBatch = getBatch();
        Boolean hitRateLimit = false;
        Integer processedCount = 0;
        
        for (Id recordId : currentBatch) {
            // Check CPU time before processing each record
            if (NotionRateLimiter.shouldDeferProcessing()) {
                System.debug('CPU limit approaching after ' + processedCount + ' records');
                // Immediately chain to next queueable
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new NotionSyncQueueableChain(
                        recordIds, currentIndex + processedCount, objectType
                    ));
                }
                return;
            }
            
            try {
                // Enforce rate limit
                enforceRateLimit();
                
                NotionResponse response = syncRecord(recordId);
                processedCount++;
                
                if (response.statusCode == 429) {
                    hitRateLimit = true;
                    String retryAfter = response.getHeader('Retry-After');
                    retryDelaySeconds = String.isNotBlank(retryAfter) ? 
                        Integer.valueOf(retryAfter) : 60;
                    break;
                }
            } catch (NotionRateLimiter.RateLimitException e) {
                // CPU limit hit during rate limiting
                System.debug('CPU limit hit during rate limiting');
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new NotionSyncQueueableChain(
                        recordIds, currentIndex + processedCount, objectType
                    ));
                }
                return;
            }
        }
        
        // Update index for next batch
        currentIndex += processedCount;
        
        // Chain next batch if needed
        if (hasMoreRecords() || hitRateLimit) {
            if (!Test.isRunningTest()) {
                if (hitRateLimit) {
                    enqueueWithDelay(retryDelaySeconds);
                } else {
                    // Immediate chaining for CPU efficiency
                    System.enqueueJob(new NotionSyncQueueableChain(
                        recordIds, currentIndex, objectType
                    ));
                }
            }
        }
    }
    
    private void enforceRateLimit() {
        if (lastRequestTime != null) {
            Long millisecondsSince = DateTime.now().getTime() - lastRequestTime.getTime();
            if (millisecondsSince < 334) { // ~3 requests per second
                // Wait remaining time
                Long waitTime = 334 - millisecondsSince;
                sleepMilliseconds(waitTime);
            }
        }
        lastRequestTime = DateTime.now();
    }
    
    private void enqueueWithDelay(Integer delaySeconds) {
        // Platform Events or Scheduled Jobs for delay
        // Or use Flow Wait element for delays
    }
}
```

### 3. Scheduled Sync Implementation

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
            Database.executeBatch(
                new NotionSyncBatch(syncObject.ObjectApiName__c),
                20 // Batch size
            );
        }
    }
}
```

### 4. Progress Tracking

Create a new custom object `Notion_Batch_Sync__c`:

```
Fields:
- Object_Type__c (Text)
- Status__c (Picklist: Pending, In Progress, Completed, Failed)
- Total_Records__c (Number)
- Processed_Records__c (Number)
- Success_Count__c (Number)
- Error_Count__c (Number)
- Start_Time__c (DateTime)
- End_Time__c (DateTime)
- Last_Processed_Id__c (Text) - For resume capability
- Error_Summary__c (Long Text Area)
```

### 5. Retry Mechanism with Rate Limit Awareness

Add automatic retry capability with exponential backoff and rate limit handling:

```apex
public class NotionSyncRetryBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    private static final Integer BATCH_SIZE = 5; // Small batch for retries
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query failed sync logs, prioritizing rate-limited failures
        return Database.getQueryLocator([
            SELECT Record_Id__c, Object_Type__c, Retry_Count__c, 
                   Error_Message__c, Last_Retry_Time__c
            FROM Notion_Sync_Log__c
            WHERE Status__c IN ('Failed', 'Rate Limited')
            AND Retry_Count__c < 3
            AND (Last_Retry_Time__c = null OR 
                 Last_Retry_Time__c < :DateTime.now().addMinutes(-5))
            ORDER BY 
                CASE WHEN Error_Message__c LIKE '%429%' THEN 0 ELSE 1 END,
                Retry_Count__c ASC,
                CreatedDate DESC
            LIMIT 10000
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Notion_Sync_Log__c> scope) {
        for (Notion_Sync_Log__c log : scope) {
            // Exponential backoff: 1min, 2min, 4min
            Integer delayMinutes = Integer.valueOf(Math.pow(2, log.Retry_Count__c));
            
            // Extra delay for rate-limited requests
            if (log.Error_Message__c != null && log.Error_Message__c.contains('429')) {
                delayMinutes = Math.max(delayMinutes, 5);
            }
            
            // Check if enough time has passed
            if (log.Last_Retry_Time__c != null) {
                Integer minutesSinceLastRetry = 
                    (DateTime.now().getTime() - log.Last_Retry_Time__c.getTime()) / 60000;
                if (minutesSinceLastRetry < delayMinutes) {
                    continue; // Skip this retry
                }
            }
            
            // Retry with rate limiting
            retrySync(log);
        }
    }
}
```

**Note**: This enhancement adds rate limit aware retry logic with exponential backoff to prevent overwhelming the API.

## Implementation Strategy

### Phase 1: Foundation (Week 1-2)
1. Create `NotionRateLimiter` class with CPU monitoring
2. Update `NotionApiClient` to handle 429 responses
3. Create `NotionSyncBatch` class with CPU-aware processing
4. Add batch size configuration to metadata (reduced sizes)
5. Implement progress tracking object

### Phase 2: Enhanced Processing (Week 3-4)
1. Implement queueable chaining for medium datasets
2. Add scheduled sync capability
3. Create admin UI for monitoring batch jobs
4. Implement resume capability for interrupted syncs

### Phase 3: Optimization (Week 5-6)
1. Add intelligent batching based on relationship complexity
2. Implement parallel processing for independent objects
3. Add data volume estimation before sync
4. Create performance monitoring dashboard

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

### CPU Time Optimization

Given the 60-second CPU time limit for async operations, most time will be spent waiting for API callouts rather than CPU processing. The real constraints are:

1. **API Rate Limit**: 3 requests/second (333ms minimum between requests)
2. **Callout Limit**: 100 callouts per transaction
3. **Callout Time**: 120 seconds total

Since HTTP callout time doesn't count against CPU time, the main CPU usage comes from:
- Data transformation and serialization
- Relationship processing
- Rate limit calculations

#### Recommended Processing Limits per Execution

| Object Complexity | Max Records per Execute | Limiting Factor |
|------------------|------------------------|-----------------|
| Simple (no relationships) | 30-40 | Callout limit (100 max) |
| Medium (1-2 lookups) | 20-25 | Additional API calls for lookups |
| Complex (many relations) | 10-15 | Multiple API calls per record |

**Note**: While CPU time is rarely the bottleneck, the 100 callout limit and 3 req/sec rate limit are the primary constraints.

#### CPU Time Monitoring Strategy

```apex
public class GovernorLimitManager {
    private static final Decimal SAFE_THRESHOLD = 0.8; // 80% of limit
    private static final Decimal WARNING_THRESHOLD = 0.7; // 70% of limit
    
    public static ProcessingStatus checkGovernorStatus() {
        // Check all relevant governor limits dynamically
        Decimal cpuPercentage = Decimal.valueOf(Limits.getCpuTime()) / Limits.getLimitCpuTime();
        Decimal calloutPercentage = Decimal.valueOf(Limits.getCallouts()) / Limits.getLimitCallouts();
        Decimal heapPercentage = Decimal.valueOf(Limits.getHeapSize()) / Limits.getLimitHeapSize();
        
        // Find the highest usage percentage
        Decimal maxUsage = Math.max(cpuPercentage, Math.max(calloutPercentage, heapPercentage));
        
        if (maxUsage > SAFE_THRESHOLD) {
            System.debug('Governor limit approaching: CPU=' + (cpuPercentage*100).setScale(1) + 
                        '%, Callouts=' + (calloutPercentage*100).setScale(1) + 
                        '%, Heap=' + (heapPercentage*100).setScale(1) + '%');
            return ProcessingStatus.DEFER_IMMEDIATELY;
        } else if (maxUsage > WARNING_THRESHOLD) {
            return ProcessingStatus.COMPLETE_CURRENT_ONLY;
        } else {
            return ProcessingStatus.CONTINUE_PROCESSING;
        }
    }
    
    public static void logCurrentUsage() {
        System.debug('Governor Limits - CPU: ' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime() + 
                    ', Callouts: ' + Limits.getCallouts() + '/' + Limits.getLimitCallouts() + 
                    ', Heap: ' + Limits.getHeapSize() + '/' + Limits.getLimitHeapSize());
    }
    
    public enum ProcessingStatus {
        CONTINUE_PROCESSING,    // Safe to continue
        COMPLETE_CURRENT_ONLY,  // Complete current, then defer
        DEFER_IMMEDIATELY       // Stop and defer now
    }
}
```

#### Async Job Chaining Strategy

1. **Immediate Chaining**: When CPU limit approaching
2. **Delayed Chaining**: When rate limited (use Platform Events)
3. **Batch Splitting**: Reduce batch size dynamically based on CPU usage

### Handling Rate Limit Delays

Since we can't pause execution in Apex, use these approaches for rate limit compliance:

#### 1. Platform Events for Delayed Processing

```apex
public class NotionSyncDelayedEvent__e {
    @InvocableVariable public String recordIds;
    @InvocableVariable public String objectType;
    @InvocableVariable public Integer delaySeconds;
}

// Publish event for delayed processing
NotionSyncDelayedEvent__e event = new NotionSyncDelayedEvent__e(
    recordIds__c = String.join(recordIds, ','),
    objectType__c = objectType,
    delaySeconds__c = 5
);
EventBus.publish(event);
```

#### 2. Scheduled Jobs for Rate Limit Compliance

```apex
public class NotionSyncScheduler implements Schedulable {
    private List<Id> recordIds;
    private String objectType;
    
    public void execute(SchedulableContext context) {
        // Process next batch
        System.enqueueJob(new NotionSyncQueueableChain(recordIds, objectType));
        
        // Cancel this scheduled job
        System.abortJob(context.getTriggerId());
    }
}

// Schedule with delay
DateTime runTime = DateTime.now().addSeconds(2);
String cronExp = runTime.second() + ' ' + runTime.minute() + ' ' + 
                runTime.hour() + ' ' + runTime.day() + ' ' + 
                runTime.month() + ' ? ' + runTime.year();
System.schedule('Notion Sync Delay ' + DateTime.now(), cronExp, 
                new NotionSyncScheduler(recordIds, objectType));
```

#### 3. Flow-Based Delays

Use Flow's Wait element for precise timing:
- Create a Platform Event triggered Flow
- Add Wait element for rate limit compliance
- Resume processing after delay

## Dynamic Batch Size Optimization

### Adaptive Batch Sizing

Instead of fixed batch sizes, dynamically adjust based on actual governor limit usage:

```apex
public class DynamicBatchSizer {
    private static Integer lastBatchSize = 10;
    private static Map<String, Integer> governorUsageHistory = new Map<String, Integer>();
    
    public static Integer calculateOptimalBatchSize(String objectType) {
        // Get previous execution metrics
        Integer previousCpuUsage = governorUsageHistory.get(objectType + '_cpu');
        Integer previousCalloutUsage = governorUsageHistory.get(objectType + '_callouts');
        
        if (previousCpuUsage != null && previousCalloutUsage != null) {
            // Calculate usage per record
            Decimal cpuPerRecord = Decimal.valueOf(previousCpuUsage) / lastBatchSize;
            Decimal calloutsPerRecord = Decimal.valueOf(previousCalloutUsage) / lastBatchSize;
            
            // Calculate max records based on limits (with 80% safety margin)
            Integer maxByCpu = Integer.valueOf((Limits.getLimitCpuTime() * 0.8) / cpuPerRecord);
            Integer maxByCallouts = Integer.valueOf((Limits.getLimitCallouts() * 0.8) / calloutsPerRecord);
            
            // Also consider rate limit (3 req/sec over expected execution time)
            Integer maxByRateLimit = Integer.valueOf(3 * (Limits.getLimitCpuTime() / 1000) * 0.5);
            
            // Return the most restrictive limit
            return Math.min(Math.min(maxByCpu, maxByCallouts), maxByRateLimit);
        }
        
        // Default starting batch size
        return 10;
    }
    
    public static void recordExecutionMetrics(String objectType, Integer batchSize) {
        governorUsageHistory.put(objectType + '_cpu', Limits.getCpuTime());
        governorUsageHistory.put(objectType + '_callouts', Limits.getCallouts());
        lastBatchSize = batchSize;
    }
}
```

## Best Practices

### 1. Rate Limit Compliance

**Dynamic Batch Size Guidelines**:
- Start with conservative batch sizes (10 records)
- Monitor actual governor limit usage
- Adjust batch size based on measured performance
- Always respect the 3 requests/second rate limit

**Request Spacing**:
- Minimum 334ms between API requests
- Add 1-second delays between queueable chains
- Use Platform Events for precise timing control

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

**Optimal Scheduling**:
- Spread large syncs across 24 hours
- Use multiple small batches vs. single large batch
- Implement "slow start" - gradually increase rate
- Monitor and adjust based on 429 responses

**Example Schedule**:
```apex
// Schedule batches with delays to respect rate limits
for (Integer i = 0; i < objectList.size(); i++) {
    Integer delayMinutes = i * 10; // 10 minutes between object types
    System.scheduleBatch(
        new NotionSyncBatch(objectList[i]),
        'Notion Sync ' + objectList[i] + ' ' + DateTime.now().addMinutes(delayMinutes),
        delayMinutes
    );
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

1. Continue using current real-time sync for ongoing operations
2. Use batch sync for initial data migration
3. Gradually introduce scheduled sync for regular updates
4. Monitor and adjust batch sizes based on performance

## Testing Strategy

1. **Unit Tests**
   - Test batch processing with various data volumes
   - Verify chunking logic
   - Test retry mechanisms

2. **Integration Tests**
   - Test with real Notion API
   - Verify large dataset handling
   - Test interruption and resume

3. **Performance Tests**
   - Measure sync times for different batch sizes
   - Monitor resource usage
   - Test governor limit boundaries

## Monitoring and Alerts

1. **Dashboards**
   - Sync performance metrics
   - Error rates and patterns
   - API usage statistics

2. **Alerts**
   - Failed batch jobs
   - High error rates
   - API limit approaching

3. **Reports**
   - Daily sync summary
   - Weekly performance trends
   - Monthly volume analysis