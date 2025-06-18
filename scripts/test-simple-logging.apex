// Simple test to verify enhanced logging works without querying new fields

System.debug('=== Testing Enhanced Logging ===');

// Create a test sync request
NotionSyncQueueable.SyncRequest testRequest = new NotionSyncQueueable.SyncRequest(
    '001TEST000000001',
    'Account',
    'CREATE'
);

// Test 1: Log with rate limit information
System.debug('\n=== Test 1: Rate Limited Log Entry ===');
NotionSyncLogger.LogEntry rateLimitEntry = NotionSyncLogger.logWithRateLimit(
    testRequest.recordId,
    testRequest.objectType,
    testRequest.operationType,
    'Failed',
    'Rate limit exceeded. Retry after 5 seconds.',
    0,
    null,
    true,  // rateLimited
    5      // retryAfter seconds
);

System.debug('Created rate limited log entry');
System.debug('Rate Limited: ' + rateLimitEntry.rateLimited);
System.debug('Retry After: ' + rateLimitEntry.rateLimitRetryAfter);
System.debug('CPU Time: ' + rateLimitEntry.cpuTimeUsed);
System.debug('Callouts: ' + rateLimitEntry.calloutsUsed);

// Test 2: Log success with metrics
System.debug('\n=== Test 2: Success Log Entry with Metrics ===');
NotionSyncLogger.LogEntry successEntry = NotionSyncLogger.logWithRateLimit(
    '001TEST000000002',
    'Account',
    'UPDATE',
    'Success',
    null,
    0,
    'test-notion-page-id',
    false,
    null
);

// Simulate API calls made
successEntry.apiCallsMade = 3;
System.debug('Created success log entry');
System.debug('API Calls Made: ' + successEntry.apiCallsMade);
System.debug('CPU Time: ' + successEntry.cpuTimeUsed);

// Test 3: Flush logs
System.debug('\n=== Test 3: Flushing Logs ===');
System.debug('Pending logs before flush: ' + NotionSyncLogger.pendingLogs.size());

// Since we're in an anonymous context, use logSync to test
List<String> logJsonList = new List<String>();
for (NotionSyncLogger.LogEntry entry : NotionSyncLogger.pendingLogs) {
    logJsonList.add(JSON.serialize(entry));
}

// Clear pending logs
NotionSyncLogger.clear();

// Test deserialization
System.debug('\n=== Test 4: Deserialization ===');
for (String logJson : logJsonList) {
    NotionSyncLogger.LogEntry deserializedEntry = 
        (NotionSyncLogger.LogEntry) JSON.deserialize(logJson, NotionSyncLogger.LogEntry.class);
    System.debug('Deserialized entry - Record ID: ' + deserializedEntry.recordId + 
                 ', Rate Limited: ' + deserializedEntry.rateLimited);
}

System.debug('\n=== Enhanced Logging Test Complete ===');