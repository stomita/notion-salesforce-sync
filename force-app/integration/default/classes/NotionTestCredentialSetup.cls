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
        ensureUserPermissions();
    }
}