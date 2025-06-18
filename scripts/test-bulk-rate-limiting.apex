// Test bulk operations with rate limiting
// This simulates a real-world scenario where multiple records are synced

System.debug('=== Testing Bulk Operations with Rate Limiting ===');

// Create test sync requests to simulate bulk processing
List<NotionSyncQueueable.SyncRequest> syncRequests = new List<NotionSyncQueueable.SyncRequest>();

// Simulate 5 test records
for (Integer i = 0; i < 5; i++) {
    String recordId = '001000000000' + String.valueOf(i).leftPad(3, '0');
    NotionSyncQueueable.SyncRequest req = new NotionSyncQueueable.SyncRequest(
        recordId,
        'Account',
        'CREATE'
    );
    syncRequests.add(req);
}

System.debug('Created ' + syncRequests.size() + ' test sync requests');

// Test the rate limiter's behavior with bulk operations
System.debug('\n=== Simulating Bulk API Calls ===');

Long bulkStartTime = System.currentTimeMillis();
Integer apiCallCount = 0;
Integer rateLimitExceptions = 0;

// Simulate making 3 API calls per record (query, create/update, relationships)
for (NotionSyncQueueable.SyncRequest req : syncRequests) {
    System.debug('\nProcessing record: ' + req.recordId);
    
    // Simulate 3 API calls per record
    for (Integer callNum = 1; callNum <= 3; callNum++) {
        try {
            NotionRateLimiter.throttleRequest();
            apiCallCount++;
            Long elapsed = System.currentTimeMillis() - bulkStartTime;
            System.debug('  Call ' + callNum + ' completed at ' + elapsed + 'ms');
        } catch (NotionRateLimiter.RateLimitException e) {
            rateLimitExceptions++;
            System.debug('  Call ' + callNum + ' rate limited: ' + e.getMessage());
            // In real scenario, would defer remaining records
            break;
        }
    }
    
    // Check if we should stop due to limits
    if (NotionRateLimiter.shouldDeferProcessing()) {
        System.debug('Governor limits approaching, would defer remaining records');
        break;
    }
}

Long bulkTotalTime = System.currentTimeMillis() - bulkStartTime;

System.debug('\n=== Bulk Operation Results ===');
System.debug('Total API calls made: ' + apiCallCount);
System.debug('Rate limit exceptions: ' + rateLimitExceptions);
System.debug('Total time: ' + bulkTotalTime + 'ms');
System.debug('Average time per API call: ' + 
    (apiCallCount > 0 ? bulkTotalTime / apiCallCount : 0) + 'ms');

// Check final governor limits
Map<String, Object> finalLimits = NotionRateLimiter.getGovernorLimitStatus();
System.debug('\n=== Final Governor Limits ===');
System.debug('Callouts: ' + finalLimits.get('calloutsUsed') + '/' + 
    finalLimits.get('calloutLimit') + ' (' + finalLimits.get('calloutPercentage') + '%)');
System.debug('CPU Time: ' + finalLimits.get('cpuTimeUsed') + '/' + 
    finalLimits.get('cpuTimeLimit') + ' (' + finalLimits.get('cpuPercentage') + '%)');

// Test batch size calculation with current limits
Integer remainingBatchSize = NotionRateLimiter.calculateMaxBatchSize(3);
System.debug('\nRemaining batch capacity: ' + remainingBatchSize + ' records');

System.debug('\n=== Bulk Rate Limiting Test Complete ===');