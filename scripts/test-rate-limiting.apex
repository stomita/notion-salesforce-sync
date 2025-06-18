// Test script to verify rate limiting functionality
// This script will attempt to make multiple rapid API calls to test the rate limiter

// First, let's test the rate limiter's timing functionality
System.debug('=== Testing NotionRateLimiter Timing ===');

// Test 1: Verify rate limiting enforces delays
Long startTime = System.currentTimeMillis();
for (Integer i = 0; i < 3; i++) {
    try {
        NotionRateLimiter.throttleRequest();
        System.debug('Request ' + (i + 1) + ' completed at ' + 
            (System.currentTimeMillis() - startTime) + 'ms');
    } catch (NotionRateLimiter.RateLimitException e) {
        System.debug('Rate limit exception: ' + e.getMessage());
    }
}
Long totalTime = System.currentTimeMillis() - startTime;
System.debug('Total time for 3 requests: ' + totalTime + 'ms (expected ~666ms)');

// Test 2: Check governor limit status
System.debug('\n=== Testing Governor Limit Status ===');
Map<String, Object> limitStatus = NotionRateLimiter.getGovernorLimitStatus();
System.debug('Current governor limits:');
System.debug('- Callouts: ' + limitStatus.get('calloutsUsed') + '/' + 
    limitStatus.get('calloutLimit') + ' (' + limitStatus.get('calloutPercentage') + '%)');
System.debug('- CPU Time: ' + limitStatus.get('cpuTimeUsed') + '/' + 
    limitStatus.get('cpuTimeLimit') + ' (' + limitStatus.get('cpuPercentage') + '%)');
System.debug('- Heap: ' + limitStatus.get('heapUsed') + '/' + 
    limitStatus.get('heapLimit') + ' (' + limitStatus.get('heapPercentage') + '%)');

// Test 3: Calculate max batch size
System.debug('\n=== Testing Batch Size Calculation ===');
Integer maxBatchSize = NotionRateLimiter.calculateMaxBatchSize(3);
System.debug('Max batch size with 3 calls per record: ' + maxBatchSize);

// Test 4: Test actual API call with rate limiting (if credentials are configured)
System.debug('\n=== Testing API Call with Rate Limiting ===');
try {
    // Create a simple test properties map
    Map<String, Object> properties = new Map<String, Object>();
    properties.put('Name', NotionApiClient.buildTitleProperty('Rate Limit Test ' + DateTime.now()));
    
    // Attempt to create a page (this will fail if no credentials configured)
    NotionApiClient.NotionPageRequest request = new NotionApiClient.NotionPageRequest(
        'test-database-id', // This will fail but we're testing rate limiting
        properties
    );
    
    NotionApiClient.NotionResponse response = NotionApiClient.createPage(request);
    
    if (response.isRateLimited) {
        System.debug('API call was rate limited!');
        System.debug('Retry after seconds: ' + response.retryAfterSeconds);
    } else if (!response.success) {
        System.debug('API call failed (expected if no credentials): ' + response.errorMessage);
    } else {
        System.debug('API call succeeded: ' + response.pageId);
    }
} catch (Exception e) {
    System.debug('Exception during API test: ' + e.getMessage());
}

// Test 5: Simulate rapid requests to test rate limiting
System.debug('\n=== Testing Rapid Request Handling ===');
Integer successCount = 0;
Integer rateLimitCount = 0;
Long rapidStartTime = System.currentTimeMillis();

for (Integer i = 0; i < 10; i++) {
    try {
        NotionRateLimiter.throttleRequest();
        successCount++;
    } catch (NotionRateLimiter.RateLimitException e) {
        rateLimitCount++;
        System.debug('Request ' + (i + 1) + ' hit rate limit: ' + e.getMessage());
        break; // Stop on first rate limit exception
    }
}

Long rapidTotalTime = System.currentTimeMillis() - rapidStartTime;
System.debug('Rapid test results:');
System.debug('- Successful requests: ' + successCount);
System.debug('- Rate limited requests: ' + rateLimitCount);
System.debug('- Total time: ' + rapidTotalTime + 'ms');
System.debug('- Average time per request: ' + 
    (successCount > 0 ? rapidTotalTime / successCount : 0) + 'ms');

System.debug('\n=== Rate Limiting Test Complete ===');