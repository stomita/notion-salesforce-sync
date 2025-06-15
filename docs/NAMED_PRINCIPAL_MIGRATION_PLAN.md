# Named Principal Authentication Migration Plan

## Overview
This plan outlines how to configure Named Principal authentication for the Notion integration, allowing all users (including Automated Process) to access the Named Credential without requiring individual permission assignments.

## Current State
- External Credential (`Notion_Credential`) is already configured for NamedPrincipal authentication
- Named Credential (`Notion_API`) references the External Credential
- Platform Events run as Automated Process user, which cannot access Per User credentials

## Migration Steps

### 1. Configure Named Principal Credential (Manual Setup Required)
Since Named Principal Credentials contain sensitive data (API keys), they cannot be deployed via metadata. Each org must configure this manually:

1. **Navigate to Setup**
   - Go to Setup → Security → Named Credentials
   - Click on "External Credentials" tab
   - Find "Notion Credential"

2. **Add Principal**
   - Click "New" under Principals section
   - Parameter Name: `NotionIntegration` (must match the XML configuration)
   - Sequence Number: 1

3. **Add Authentication Parameters**
   - Click the newly created Principal
   - Add Custom Header:
     - Parameter Name: `SecretKey`
     - Value: Your Notion API Key (e.g., `ntn_12345...`)
   - Save

### 2. Update Permission Set (Already Complete)
The `Notion_Integration_User` permission set already includes:
```xml
<externalCredentialPrincipalAccesses>
    <enabled>true</enabled>
    <externalCredentialPrincipal>Notion_Credential-NotionIntegration</externalCredentialPrincipal>
</externalCredentialPrincipalAccesses>
```

### 3. Grant System-Wide Access
For Named Principal to work with Automated Process user:

1. **Option A: Enable for All Users**
   - In External Credential setup, check "Available for All Users"
   - This grants access to all users including Automated Process

2. **Option B: Use Custom Permissions**
   - Create a Custom Permission
   - Add it to the External Credential Principal Access
   - Grant via Permission Set that can be assigned system-wide

### 4. Testing
```apex
// Test script to verify Named Principal access
Http http = new Http();
HttpRequest request = new HttpRequest();
request.setEndpoint('callout:Notion_API/v1/users/me');
request.setMethod('GET');

try {
    HttpResponse response = http.send(request);
    System.debug('Success! Status: ' + response.getStatusCode());
    System.debug('Response: ' + response.getBody());
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
```

## Benefits of Named Principal
1. **Single API Key**: One key for the entire org
2. **No Per-User Setup**: Works for all users including system users
3. **Simplified Deployment**: No need for user-specific configurations
4. **Platform Event Compatible**: Works with Automated Process user

## Security Considerations
1. **API Key Protection**: Store securely, rotate regularly
2. **Audit Trail**: All API calls use the same credential
3. **Permission Control**: Use Permission Sets to control who can execute syncs

## Documentation Updates Needed
1. Update README with Named Principal setup instructions
2. Add setup screenshots for credential configuration
3. Update CI/CD documentation for credential setup in scratch orgs
4. Create troubleshooting guide for credential errors

## Implementation Checklist
- [ ] Document Named Principal setup process
- [ ] Create setup automation script for scratch orgs
- [ ] Update integration test documentation
- [ ] Test with Platform Events and Automated Process user
- [ ] Update error messages to guide users to Named Principal setup
- [ ] Create post-install instructions for package users