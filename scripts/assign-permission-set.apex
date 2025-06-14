// Assign the Notion Integration permission set to current user
try {
    // Get current user
    String userId = UserInfo.getUserId();
    
    // Check if permission set exists
    List<PermissionSet> permSets = [
        SELECT Id, Name 
        FROM PermissionSet 
        WHERE Name = 'Notion_Integration_User' 
        LIMIT 1
    ];
    
    if (permSets.isEmpty()) {
        System.debug('ERROR: Permission Set "Notion_Integration_User" not found');
        return;
    }
    
    PermissionSet ps = permSets[0];
    System.debug('Found Permission Set: ' + ps.Name + ' (Id: ' + ps.Id + ')');
    
    // Check if already assigned
    List<PermissionSetAssignment> existingAssignments = [
        SELECT Id 
        FROM PermissionSetAssignment 
        WHERE AssigneeId = :userId 
        AND PermissionSetId = :ps.Id
        LIMIT 1
    ];
    
    if (!existingAssignments.isEmpty()) {
        System.debug('Permission set already assigned to user');
    } else {
        // Assign permission set
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = ps.Id
        );
        insert psa;
        System.debug('✅ Successfully assigned permission set to user');
    }
    
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}