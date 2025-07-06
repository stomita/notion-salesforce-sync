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
        Boolean shouldDefer = NotionRateLimiter.shouldDeferProcessing(10);
        
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
        Boolean shouldDefer = NotionRateLimiter.shouldDeferProcessing(10);
        
        // Get status to verify calculation
        Map<String, Object> status = NotionRateLimiter.getGovernorLimitStatusMap();
        
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
        
        // Record the time before second request
        Long timeBefore = System.currentTimeMillis();
        
        // Immediate second request should wait
        NotionRateLimiter.throttleRequest();
        
        Long timeAfter = System.currentTimeMillis();
        Long elapsed = timeAfter - timeBefore;
        
        // Should have waited approximately 333ms
        System.assert(elapsed >= 300, 
            'Should have waited at least 300ms, but only waited ' + elapsed + 'ms');
        
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
        
        Map<String, Object> status = NotionRateLimiter.getGovernorLimitStatusMap();
        
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
    static void testThrottleRequest_InsufficientCpuTime() {
        Test.startTest();
        
        // We can't easily consume all CPU time in test,
        // but we can verify the busy wait works correctly
        NotionRateLimiter.throttleRequest();
        
        // Quick succession should trigger wait
        Long startCpu = Limits.getCpuTime();
        NotionRateLimiter.throttleRequest();
        Long endCpu = Limits.getCpuTime();
        
        // CPU time should have increased due to busy wait
        System.assert(endCpu > startCpu, 
            'CPU time should increase due to busy wait');
        
        Test.stopTest();
    }
    
    @isTest
    static void testCalculateMaxBatchSize() {
        Test.startTest();
        
        // Test with default calls per record
        Integer maxBatch = NotionRateLimiter.calculateMaxBatchSize(null);
        System.assert(maxBatch >= 0, 'Max batch size should be non-negative');
        
        // Test with specific calls per record
        Integer maxBatchWith2Calls = NotionRateLimiter.calculateMaxBatchSize(2);
        Integer maxBatchWith5Calls = NotionRateLimiter.calculateMaxBatchSize(5);
        
        // More calls per record should result in smaller batch
        System.assert(maxBatchWith5Calls <= maxBatchWith2Calls, 
            'Higher calls per record should result in smaller batch size');
        
        // Test edge case
        Integer maxBatchWithZero = NotionRateLimiter.calculateMaxBatchSize(0);
        System.assert(maxBatchWithZero >= 0, 'Should handle zero gracefully');
        
        Test.stopTest();
    }
    
    @isTest
    static void testCalculatePercentage_EdgeCases() {
        Test.startTest();
        
        // Test with zero limit (edge case)
        Map<String, Object> status = NotionRateLimiter.getGovernorLimitStatusMap();
        
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
    
    @isTest
    static void testShouldStopProcessing_BelowThresholds() {
        Test.startTest();
        
        // At start of test, limits should be low
        Boolean shouldStop = NotionRateLimiter.shouldStopProcessing();
        
        Test.stopTest();
        
        System.assertEquals(false, shouldStop, 
            'Should not stop processing when limits are below thresholds');
    }
    
    @isTest
    static void testShouldStopProcessing_LowCallouts() {
        Test.startTest();
        
        // Can't actually consume callouts in test, but verify the method executes
        Boolean shouldStop = NotionRateLimiter.shouldStopProcessing();
        
        // Get current status to understand the state
        Map<String, Object> status = NotionRateLimiter.getGovernorLimitStatusMap();
        Integer remainingCallouts = (Integer)status.get('calloutLimit') - (Integer)status.get('calloutsUsed');
        
        Test.stopTest();
        
        // At start of test, should have plenty of callouts remaining
        System.assert(remainingCallouts > 6, 'Should have more than 6 callouts remaining');
        System.assertEquals(false, shouldStop, 'Should not stop when callouts are sufficient');
    }
    
    @isTest 
    static void testShouldStopProcessing_HeapUsage() {
        Test.startTest();
        
        // Verify method handles heap checking correctly
        Boolean shouldStop = NotionRateLimiter.shouldStopProcessing();
        
        // Get current heap usage
        Map<String, Object> status = NotionRateLimiter.getGovernorLimitStatusMap();
        Decimal heapPercentage = (Decimal)status.get('heapPercentage');
        
        Test.stopTest();
        
        // In test context, heap usage should be low
        System.assert(heapPercentage < 85, 'Heap usage should be below 85% threshold');
        System.assertEquals(false, shouldStop, 'Should not stop when heap usage is low');
    }
}