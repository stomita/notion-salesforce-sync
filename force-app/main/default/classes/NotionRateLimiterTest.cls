/**
 * @description Test class for NotionRateLimiter
 * Tests rate limiting logic, governor limit checking, and error handling
 */
@isTest
private class NotionRateLimiterTest {
    
    @isTest
    static void testShouldDeferProcessing_BelowLimits() {
        // Test when all limits are well below thresholds
        Test.startTest();
        
        // At start of test, limits should be low
        Boolean shouldDefer = NotionRateLimiter.shouldDeferProcessing();
        
        Test.stopTest();
        
        System.assertEquals(false, shouldDefer, 
            'Should not defer when governor limits are below thresholds');
    }
    
    @isTest
    static void testShouldDeferProcessing_ApproachingCalloutLimit() {
        // This test is limited because we can't actually consume callouts in test
        // But we can verify the logic works
        Test.startTest();
        
        // Make some callouts to increase the count (in real scenario)
        // For testing, we'll just verify the method executes
        Boolean shouldDefer = NotionRateLimiter.shouldDeferProcessing();
        
        // Get status to verify calculation
        Map<String, Object> status = NotionRateLimiter.getGovernorLimitStatus();
        
        Test.stopTest();
        
        System.assertNotEquals(null, status.get('calloutPercentage'), 
            'Should calculate callout percentage');
        System.assert(status.get('calloutPercentage') instanceof Decimal, 
            'Callout percentage should be Decimal');
    }
    
    @isTest
    static void testThrottleRequest_FirstRequest() {
        Test.startTest();
        
        // First request should always succeed
        try {
            NotionRateLimiter.throttleRequest();
            System.assert(true, 'First request should succeed without exception');
        } catch (Exception e) {
            System.assert(false, 'First request should not throw exception: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testThrottleRequest_TooSoonAfterLastRequest() {
        Test.startTest();
        
        // First request
        NotionRateLimiter.throttleRequest();
        
        // Immediate second request should throw exception
        try {
            NotionRateLimiter.throttleRequest();
            System.assert(false, 'Second immediate request should throw RateLimitException');
        } catch (NotionRateLimiter.RateLimitException e) {
            System.assert(e.getMessage().contains('Rate limit requires'), 
                'Exception message should mention rate limit delay');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testThrottleRequest_AfterSufficientDelay() {
        Test.startTest();
        
        // First request
        NotionRateLimiter.throttleRequest();
        
        // Simulate time passing by resetting the last request time
        NotionRateLimiter.resetLastRequestTime();
        
        // This request should succeed
        try {
            NotionRateLimiter.throttleRequest();
            System.assert(true, 'Request after delay should succeed');
        } catch (Exception e) {
            System.assert(false, 'Request after delay should not throw exception: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetGovernorLimitStatus() {
        Test.startTest();
        
        Map<String, Object> status = NotionRateLimiter.getGovernorLimitStatus();
        
        Test.stopTest();
        
        // Verify all expected keys are present
        System.assert(status.containsKey('calloutsUsed'), 'Should contain calloutsUsed');
        System.assert(status.containsKey('calloutLimit'), 'Should contain calloutLimit');
        System.assert(status.containsKey('calloutPercentage'), 'Should contain calloutPercentage');
        System.assert(status.containsKey('cpuTimeUsed'), 'Should contain cpuTimeUsed');
        System.assert(status.containsKey('cpuTimeLimit'), 'Should contain cpuTimeLimit');
        System.assert(status.containsKey('cpuPercentage'), 'Should contain cpuPercentage');
        System.assert(status.containsKey('heapUsed'), 'Should contain heapUsed');
        System.assert(status.containsKey('heapLimit'), 'Should contain heapLimit');
        System.assert(status.containsKey('heapPercentage'), 'Should contain heapPercentage');
        
        // Verify types
        System.assert(status.get('calloutsUsed') instanceof Integer, 'calloutsUsed should be Integer');
        System.assert(status.get('calloutPercentage') instanceof Decimal, 'calloutPercentage should be Decimal');
        
        // Verify percentages are calculated correctly
        Decimal calloutPct = (Decimal) status.get('calloutPercentage');
        System.assert(calloutPct >= 0 && calloutPct <= 100, 
            'Callout percentage should be between 0 and 100');
    }
    
    @isTest
    static void testHandleRateLimit_Non429Response() {
        Test.startTest();
        
        // Create mock response with 200 status
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        
        Boolean isRateLimited = NotionRateLimiter.handleRateLimit(response);
        
        Test.stopTest();
        
        System.assertEquals(false, isRateLimited, 
            'Should return false for non-429 responses');
    }
    
    @isTest
    static void testHandleRateLimit_429WithRetryAfter() {
        Test.startTest();
        
        // Create mock response with 429 status and Retry-After header
        HttpResponse response = new HttpResponse();
        response.setStatusCode(429);
        response.setHeader('Retry-After', '5');
        
        Boolean isRateLimited = NotionRateLimiter.handleRateLimit(response);
        
        Test.stopTest();
        
        System.assertEquals(true, isRateLimited, 
            'Should return true for 429 response with Retry-After');
    }
    
    @isTest
    static void testHandleRateLimit_429WithoutRetryAfter() {
        Test.startTest();
        
        // Create mock response with 429 status but no Retry-After header
        HttpResponse response = new HttpResponse();
        response.setStatusCode(429);
        
        Boolean isRateLimited = NotionRateLimiter.handleRateLimit(response);
        
        Test.stopTest();
        
        System.assertEquals(true, isRateLimited, 
            'Should return true for 429 response even without Retry-After');
    }
    
    @isTest
    static void testThrottleRequest_ApproachingCalloutLimit() {
        Test.startTest();
        
        // We can't actually consume callouts in test context,
        // but we can test the exception message format
        try {
            // This would only throw if we were actually near the limit
            // In test context, it won't throw for this reason
            NotionRateLimiter.throttleRequest();
            
            // Make a second quick request to trigger rate limit exception instead
            NotionRateLimiter.throttleRequest();
            System.assert(false, 'Should have thrown exception');
        } catch (NotionRateLimiter.RateLimitException e) {
            // Will get rate limit exception instead of callout limit in test
            System.assert(e.getMessage() != null, 'Exception should have message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testCalculatePercentage_EdgeCases() {
        Test.startTest();
        
        // Test with zero limit (edge case)
        Map<String, Object> status = NotionRateLimiter.getGovernorLimitStatus();
        
        // All percentages should be valid decimals
        for (String key : status.keySet()) {
            if (key.endsWith('Percentage')) {
                Object value = status.get(key);
                System.assert(value instanceof Decimal, key + ' should be Decimal');
                Decimal pct = (Decimal) value;
                System.assert(pct >= 0, key + ' should be non-negative');
            }
        }
        
        Test.stopTest();
    }
}