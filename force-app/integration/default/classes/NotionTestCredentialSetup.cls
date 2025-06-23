/**
 * Utility class to set up Notion API credentials for integration testing
 * This class provides programmatic credential configuration using ConnectApi
 */
public with sharing class NotionTestCredentialSetup {
    
    /**
     * Sets up the Notion API credential with the provided API key
     * Handles both creation of new credentials and updating existing ones
     * @param apiKey The Notion API key to configure
     * @throws IllegalArgumentException if apiKey is blank or contains placeholder
     * @throws ConnectApiException if credential configuration fails
     */
    public static void setupCredential(String apiKey) {
        System.debug('=== Setting up Notion API Integration Credentials ===');
        
        // Validate API key
        if (String.isBlank(apiKey) || apiKey.contains('PLACEHOLDER')) {
            throw new IllegalArgumentException('Valid NOTION_API_KEY must be provided');
        }
        
        // Create credential input for the external credential
        ConnectApi.CredentialInput credentialInput = new ConnectApi.CredentialInput();
        credentialInput.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.Custom;
        credentialInput.externalCredential = 'Notion_Credential';
        credentialInput.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
        credentialInput.principalName = 'NotionIntegration';
        
        // Set up the credentials map with the SecretKey
        Map<String, ConnectApi.CredentialValueInput> credentialsMap = new Map<String, ConnectApi.CredentialValueInput>();
        
        ConnectApi.CredentialValueInput secretKeyValue = new ConnectApi.CredentialValueInput();
        secretKeyValue.value = apiKey;
        secretKeyValue.encrypted = true;
        
        credentialsMap.put('SecretKey', secretKeyValue);
        credentialInput.credentials = credentialsMap;
        
        // Try to create or update the credential
        System.debug('Setting up Notion API credential...');
        
        Boolean credentialConfigured = false;
        String lastError = '';
        
        // First, try to create a new credential
        try {
            ConnectApi.Credential result = ConnectApi.NamedCredentials.createCredential(credentialInput);
            System.debug('SUCCESS: Notion API credential created');
            credentialConfigured = true;
        } catch (ConnectApi.ConnectApiException createEx) {
            lastError = createEx.getMessage();
            System.debug('Create failed: ' + lastError);
        }
        
        // If create failed, try to update existing credential
        if (!credentialConfigured) {
            try {
                ConnectApi.Credential result = ConnectApi.NamedCredentials.updateCredential(credentialInput);
                System.debug('SUCCESS: Notion API credential updated');
                credentialConfigured = true;
            } catch (ConnectApi.ConnectApiException updateEx) {
                System.debug('Update also failed: ' + updateEx.getMessage());
                // Both create and update failed - re-throw the update exception with combined message
                throw new CalloutException(
                    'Failed to configure credential. Create error: ' + lastError + 
                    ', Update error: ' + updateEx.getMessage()
                );
            }
        }
        
        System.debug('=== Credential Setup Complete ===');
    }
    
    /**
     * Ensures the current user has the Notion_Integration_User permission set
     * Required for accessing the External Credential
     */
    public static void ensureUserPermissions() {
        System.debug('Ensuring current user has access to External Credential...');
        
        // Get current user
        User currentUser = [SELECT Id, Username FROM User WHERE Id = :UserInfo.getUserId()];
        System.debug('Current user: ' + currentUser.Username);
        
        // Check if permission set assignment already exists
        List<PermissionSetAssignment> existingAssignments = [
            SELECT Id 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :currentUser.Id 
            AND PermissionSet.Name = 'Notion_Integration_User'
            LIMIT 1
        ];
        
        if (existingAssignments.isEmpty()) {
            // Get the permission set
            List<PermissionSet> permSets = [
                SELECT Id 
                FROM PermissionSet 
                WHERE Name = 'Notion_Integration_User' 
                LIMIT 1
            ];
            
            if (!permSets.isEmpty()) {
                // Assign permission set to current user
                PermissionSetAssignment psa = new PermissionSetAssignment(
                    AssigneeId = currentUser.Id,
                    PermissionSetId = permSets[0].Id
                );
                insert psa;
                System.debug('Permission set assigned to user');
            } else {
                System.debug('WARNING: Notion_Integration_User permission set not found');
            }
        } else {
            System.debug('User already has Notion_Integration_User permission set');
        }
    }
    
    /**
     * Combined setup method that configures both credential and permissions
     * @param apiKey The Notion API key to configure
     */
    public static void setup(String apiKey) {
        setupCredential(apiKey);
        // Permission set assignment must be done separately to avoid mixed DML
        ensureUserPermissionsAsync();
    }
    
    /**
     * Asynchronously ensures the current user has the Notion_Integration_User permission set
     * Uses @future to avoid mixed DML operations
     */
    @future
    public static void ensureUserPermissionsAsync() {
        ensureUserPermissions();
    }
    
    /**
     * Verify that the Notion API credentials are properly configured and working
     * This method should be called after credential setup to ensure authentication works
     * @return true if authentication is successful, false otherwise
     * @throws CalloutException if authentication check fails
     */
    public static Boolean verifyAuthentication() {
        System.debug('=== Verifying Notion API Authentication ===');
        
        try {
            // Make a simple API call to verify authentication
            // We'll use the search databases endpoint as it's lightweight
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:Notion_API/v1/users/me');
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(60000);
            
            HttpResponse response = new Http().send(request);
            Integer statusCode = response.getStatusCode();
            String responseBody = response.getBody();
            
            System.debug('Authentication check status code: ' + statusCode);
            
            if (statusCode == 200) {
                System.debug('Authentication verification SUCCESSFUL');
                try {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    String botId = (String) responseMap.get('id');
                    String botName = responseMap.containsKey('name') ? (String) responseMap.get('name') : 'Notion Integration';
                    System.debug('Bot ID: ' + botId);
                    System.debug('Bot Name: ' + botName);
                } catch (Exception e) {
                    // Ignore parsing errors, authentication was successful
                }
                return true;
            } else if (statusCode == 401) {
                System.debug('Authentication verification FAILED - Unauthorized');
                throw new CalloutException('Notion API authentication failed (HTTP 401): Invalid API key or unauthorized access');
            } else {
                System.debug('Authentication verification FAILED');
                String errorMessage = 'Notion API authentication failed (HTTP ' + statusCode + ')';
                try {
                    Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    if (errorResponse.containsKey('message')) {
                        errorMessage += ': ' + (String) errorResponse.get('message');
                    }
                } catch (Exception e) {
                    // Ignore parsing error
                }
                throw new CalloutException(errorMessage);
            }
        } catch (CalloutException e) {
            System.debug('CalloutException during authentication verification: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('Exception during authentication verification: ' + e.getMessage());
            throw new CalloutException('Unexpected error during authentication check: ' + e.getMessage());
        }
    }
}