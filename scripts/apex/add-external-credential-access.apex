// Add external credential access to permission set for CI testing
// This is needed because 2GP packages can't include external credential references

System.debug('=== Adding External Credential Access for CI Testing ===');

try {
    // Get the permission set
    PermissionSet ps = [
        SELECT Id, Name 
        FROM PermissionSet 
        WHERE Name = 'Notion_Integration_User' 
        LIMIT 1
    ];
    
    System.debug('Found permission set: ' + ps.Name);
    
    // Check if external credential principal access already exists
    List<SetupEntityAccess> existingAccess = [
        SELECT Id 
        FROM SetupEntityAccess 
        WHERE ParentId = :ps.Id 
        AND SetupEntityType = 'ExternalCredentialPrincipal'
        LIMIT 1
    ];
    
    if (!existingAccess.isEmpty()) {
        System.debug('External credential access already exists');
    } else {
        // Get the external credential principal
        List<ExternalCredentialPrincipal> principals = [
            SELECT Id, DeveloperName 
            FROM ExternalCredentialPrincipal 
            WHERE DeveloperName = 'NotionIntegration'
            AND ExternalCredentialId IN (
                SELECT Id FROM ExternalCredential WHERE DeveloperName = 'Notion_Credential'
            )
            LIMIT 1
        ];
        
        if (principals.isEmpty()) {
            throw new QueryException('External credential principal not found');
        }
        
        // Create the setup entity access
        SetupEntityAccess sea = new SetupEntityAccess();
        sea.ParentId = ps.Id;
        sea.SetupEntityId = principals[0].Id;
        
        insert sea;
        System.debug('Successfully added external credential access to permission set');
    }
    
    System.debug('=== External Credential Access Configuration Complete ===');
} catch (Exception e) {
    System.debug('ERROR: Failed to add external credential access: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
    throw e;
}