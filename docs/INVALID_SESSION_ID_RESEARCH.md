# INVALID_SESSION_ID Error Research for Metadata API in Lightning Components

## Problem Summary

When calling the Metadata API from Lightning components (specifically in `NotionAdminController.deleteSyncConfiguration`), the following error occurs:

```
Web service callout failed: WebService returned a SOAP Fault: INVALID_SESSION_ID: Invalid Session ID found in SessionHeader: Illegal Session
```

### Root Cause

The error occurs at line 629 in NotionAdminController.cls:
```apex
service.SessionHeader.sessionId = UserInfo.getSessionId();
```

**Why this happens**: In Lightning context, `UserInfo.getSessionId()` returns a session ID that is not valid for API calls. By security policy, sessions created by Lightning components aren't enabled for API access.

## Current Implementation Analysis

### 1. Delete Flow
The delete operation currently follows this path:
- `NotionAdminController.deleteSyncConfiguration()` → Uses MetadataService with SOAP API
- `NotionAdminController.deleteCustomMetadataRecords()` → Direct Metadata API calls with session ID

### 2. Save/Update Flow  
The save operation uses a different approach:
- `NotionAdminController.saveSyncConfiguration()` → `NotionMetadataService.saveSyncConfiguration()`
- Uses `Metadata.Operations.enqueueDeployment()` - Native Apex metadata deployment (no session ID needed)

## Solution Options

### Option 1: Use Native Metadata.Operations API (Recommended)
**Implementation**: Refactor the delete operation to use the same approach as save/update

**Pros**:
- Already proven to work in the codebase (used by NotionMetadataService)
- No session ID required
- Native Salesforce support
- Consistent with existing patterns

**Cons**:
- Requires refactoring the delete logic
- May need to handle soft deletes differently

### Option 2: Create a Named Credential for Metadata API
**Implementation**: Set up a Named Credential configured as "legacy" type

**Pros**:
- Salesforce-recommended approach for external API calls
- Secure and maintainable

**Cons**:
- Additional setup required
- May be overkill for internal Metadata API calls
- Still requires significant refactoring

### Option 3: Visualforce Page Workaround
**Implementation**: Create a VF page that provides `{!$Api.Session_ID}`

**Pros**:
- Can get a valid API session ID

**Cons**:
- Adds complexity with additional VF page
- Not a modern solution
- Introduces dependency on Classic features

## Recommended Solution

**Use Option 1**: Refactor to use `Metadata.Operations` API consistently throughout the application.

### Implementation Steps:

1. **Refactor `deleteSyncConfiguration` method**:
   - Remove direct call to `deleteCustomMetadataRecords`
   - Call `NotionMetadataService.deleteObjectConfiguration` instead

2. **Update `NotionMetadataService.deleteObjectConfiguration`**:
   - Already implements soft delete using `Metadata.Operations.enqueueDeployment`
   - No changes needed - it's already using the correct approach

3. **Remove unused code**:
   - Remove `deleteCustomMetadataRecords` method from NotionAdminController
   - Remove dependency on MetadataService for delete operations

### Code Changes Required:

In `NotionAdminController.cls`, replace:
```apex
@AuraEnabled
public static SaveResult deleteSyncConfiguration(String objectApiName) {
    checkAdminPermission();
    
    SaveResult result = new SaveResult();
    try {
        // Use MetadataService to delete the configuration
        deleteCustomMetadataRecords(objectApiName);
        
        result.success = true;
        result.message = 'Configuration deleted successfully.';
        return result;
    } catch (Exception e) {
        result.success = false;
        result.message = 'Failed to delete configuration: ' + e.getMessage();
        result.errors = new List<String>{ e.getMessage() };
        return result;
    }
}
```

With:
```apex
@AuraEnabled
public static SaveResult deleteSyncConfiguration(String objectApiName) {
    checkAdminPermission();
    
    SaveResult result = new SaveResult();
    try {
        // Use NotionMetadataService for consistent metadata operations
        NotionMetadataService.deleteObjectConfiguration(objectApiName);
        
        result.success = true;
        result.message = 'Configuration deleted successfully.';
        return result;
    } catch (Exception e) {
        result.success = false;
        result.message = 'Failed to delete configuration: ' + e.getMessage();
        result.errors = new List<String>{ e.getMessage() };
        return result;
    }
}
```

Then remove the entire `deleteCustomMetadataRecords` method (lines 611-691).

## Additional Considerations

1. **Soft Delete Implementation**: The current `NotionMetadataService.deleteObjectConfiguration` already implements soft delete by setting `IsDeleted__c = true` rather than physically deleting records.

2. **Asynchronous Nature**: `Metadata.Operations.enqueueDeployment` is asynchronous, so the UI may need to handle the delay between initiating deletion and completion.

3. **Testing**: Ensure all delete-related test scripts are updated to work with the new implementation.

## References

- [Salesforce Known Issue: Session ID in Lightning](https://success.salesforce.com/issues_view?id=a1p3A0000003eJiQAI)
- [Metadata.Operations Documentation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Metadata_Operations.htm)
- [Lightning Component API Access Restrictions](https://developer.salesforce.com/docs/atlas.en-us.lightning.meta/lightning/security_csp.htm)