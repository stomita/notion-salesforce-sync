// Test script to verify enhanced logging with rate limit information

System.debug('=== Testing Enhanced Logging with Rate Limit Information ===');

// Create a test sync request
NotionSyncQueueable.SyncRequest testRequest = new NotionSyncQueueable.SyncRequest(
    '001TEST000000001',
    'Account',
    'CREATE'
);

// Test 1: Simulate a successful sync with metrics
System.debug('\n=== Test 1: Successful Sync with Metrics ===');
Integer startCpu = Limits.getCpuTime();
Integer startCallouts = Limits.getCallouts();

// Log a successful sync
NotionSyncLogger.LogEntry successEntry = NotionSyncLogger.logWithRateLimit(
    testRequest.recordId,
    testRequest.objectType,
    testRequest.operationType,
    'Success',
    null,
    0,
    'test-notion-page-id',
    false,
    null
);

// Update metrics
successEntry.apiCallsMade = 3;
System.debug('Logged success with ' + successEntry.apiCallsMade + ' API calls');

// Test 2: Simulate a rate limited sync
System.debug('\n=== Test 2: Rate Limited Sync ===');
NotionSyncLogger.LogEntry rateLimitEntry = NotionSyncLogger.logWithRateLimit(
    '001TEST000000002',
    'Account',
    'UPDATE',
    'Failed',
    'Rate limit exceeded. Retry after 5 seconds.',
    0,
    null,
    true,
    5
);

rateLimitEntry.apiCallsMade = 1;
System.debug('Logged rate limit with retry after ' + rateLimitEntry.rateLimitRetryAfter + ' seconds');

// Test 3: Check governor limit tracking
System.debug('\n=== Test 3: Governor Limit Tracking ===');
System.debug('CPU Time captured: ' + rateLimitEntry.cpuTimeUsed + 'ms');
System.debug('Callouts captured: ' + rateLimitEntry.calloutsUsed);

// Flush logs
System.debug('\n=== Flushing Logs ===');
NotionSyncLogger.flush();

// Query the created logs
System.debug('\n=== Verifying Created Logs ===');
List<Notion_Sync_Log__c> logs = [
    SELECT Record_Id__c, Status__c, Rate_Limited__c, Rate_Limit_Retry_After__c, 
           API_Calls_Made__c, CPU_Time_Used__c, Callouts_Used__c
    FROM Notion_Sync_Log__c
    WHERE CreatedDate >= :DateTime.now().addMinutes(-1)
    ORDER BY CreatedDate DESC
    LIMIT 2
];

for (Notion_Sync_Log__c log : logs) {
    System.debug('Log: ' + log.Record_Id__c + 
                 ', Status: ' + log.Status__c +
                 ', Rate Limited: ' + log.Rate_Limited__c +
                 ', API Calls: ' + log.API_Calls_Made__c +
                 ', CPU Time: ' + log.CPU_Time_Used__c + 'ms');
}

// Test 4: Test rate limiter with actual API simulation
System.debug('\n=== Test 4: Rate Limiter with API Simulation ===');
try {
    // Make multiple rapid requests to test rate limiting
    for (Integer i = 0; i < 3; i++) {
        NotionRateLimiter.throttleRequest();
        System.debug('Request ' + (i + 1) + ' completed');
        
        // Simulate API response check
        HttpResponse mockResponse = new HttpResponse();
        if (i == 2) {
            // Simulate rate limit on third request
            mockResponse.setStatusCode(429);
            mockResponse.setHeader('Retry-After', '10');
            Boolean isRateLimited = NotionRateLimiter.handleRateLimit(mockResponse);
            System.debug('Rate limit detected: ' + isRateLimited);
        } else {
            mockResponse.setStatusCode(200);
        }
    }
} catch (NotionRateLimiter.RateLimitException e) {
    System.debug('Rate limit exception: ' + e.getMessage());
}

System.debug('\n=== Enhanced Logging Test Complete ===');