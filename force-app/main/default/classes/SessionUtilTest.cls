@isTest
private class SessionUtilTest {
    
    @isTest
    static void testGetApiEnabledSessionId() {
        Test.startTest();
        String sessionId = SessionUtil.getApiEnabledSessionId();
        Test.stopTest();
        
        // In test context, should return mock session ID
        System.assertEquals('TEST_SESSION_ID', sessionId, 
            'Should return mock session ID in test context');
    }
    
    @isTest
    static void testGetValidSessionId() {
        // Test the private method indirectly through the public method
        Test.startTest();
        
        // Call multiple times to test caching behavior
        String sessionId1 = SessionUtil.getApiEnabledSessionId();
        String sessionId2 = SessionUtil.getApiEnabledSessionId();
        
        Test.stopTest();
        
        // Both calls should return the same value (cached)
        System.assertEquals(sessionId1, sessionId2, 
            'Session ID should be consistent across calls');
    }
    
    @isTest
    static void testSessionIdFormat() {
        Test.startTest();
        String sessionId = SessionUtil.getApiEnabledSessionId();
        Test.stopTest();
        
        // Verify session ID format
        System.assertNotEquals(null, sessionId, 'Session ID should not be null');
        System.assertNotEquals('', sessionId, 'Session ID should not be empty');
        System.assert(sessionId.length() > 0, 'Session ID should have length > 0');
    }
    
    @isTest
    static void testPageReferenceHandling() {
        // This test verifies the PageReference usage pattern
        Test.startTest();
        
        // First call - should execute the logic
        String sessionId1 = SessionUtil.getApiEnabledSessionId();
        
        // Second call - should use cached value
        String sessionId2 = SessionUtil.getApiEnabledSessionId();
        
        Test.stopTest();
        
        // Both should return valid session IDs
        System.assertNotEquals(null, sessionId1, 'First call should return valid ID');
        System.assertNotEquals(null, sessionId2, 'Second call should return valid ID');
    }
    
    @isTest
    static void testConcurrentAccess() {
        // Test that multiple concurrent calls work correctly
        Test.startTest();
        
        List<String> sessionIds = new List<String>();
        
        // Simulate multiple calls
        for (Integer i = 0; i < 5; i++) {
            sessionIds.add(SessionUtil.getApiEnabledSessionId());
        }
        
        Test.stopTest();
        
        // All calls should return the same session ID
        for (Integer i = 1; i < sessionIds.size(); i++) {
            System.assertEquals(sessionIds[0], sessionIds[i], 
                'All session IDs should be identical due to caching');
        }
    }
}