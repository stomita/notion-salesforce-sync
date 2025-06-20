public with sharing class SessionUtil {
    /**
     * Gets an API-enabled session ID by retrieving it from a Visualforce page.
     * This is a workaround for the Lightning security restriction where
     * UserInfo.getSessionId() returns a session that's not valid for API calls.
     */
    public static String getApiEnabledSessionId() {
        if (Test.isRunningTest()) {
            // Return a dummy session ID for tests
            return 'TEST_SESSION_ID';
        }
        
        try {
            // Get the content from the Visualforce page
            PageReference sessionPage = Page.GetSessionId;
            String pageContent = sessionPage.getContent().toString();
            
            // Extract the session ID from the page content
            String SESSION_ID_START = 'Start_Of_Session_Id';
            String SESSION_ID_END = 'End_Of_Session_Id';
            
            Integer startIndex = pageContent.indexOf(SESSION_ID_START);
            if (startIndex == -1) {
                throw new CalloutException('Unable to retrieve session ID - start marker not found');
            }
            startIndex += SESSION_ID_START.length();
            
            Integer endIndex = pageContent.indexOf(SESSION_ID_END);
            if (endIndex == -1) {
                throw new CalloutException('Unable to retrieve session ID - end marker not found');
            }
            
            String sessionId = pageContent.substring(startIndex, endIndex);
            
            if (String.isBlank(sessionId)) {
                throw new CalloutException('Retrieved session ID is blank');
            }
            
            return sessionId;
        } catch (Exception e) {
            // If we can't get the session ID from VF page (e.g., in Lightning context),
            // throw a more specific error
            if (e.getMessage().contains('getContent()')) {
                throw new CalloutException('Cannot retrieve session ID in Lightning context. Please use Setup menu for metadata operations.');
            }
            throw new CalloutException('Failed to get API-enabled session ID: ' + e.getMessage());
        }
    }
}