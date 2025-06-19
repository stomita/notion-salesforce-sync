# Notion Sync Admin UI Usage Guide

## Overview

The Notion Sync Admin UI is a Lightning Web Component that allows Salesforce administrators to configure synchronization mappings between Salesforce objects and Notion databases without manually editing custom metadata records.

## Setup Instructions

### 1. Deploy the Components

Deploy all the new components to your Salesforce org:

```bash
sf project deploy start --source-dir force-app
```

### 2. Access the Notion Sync App

The admin UI is available through a dedicated Lightning App:

1. Click the App Launcher (9-dot grid icon)
2. Search for "Notion Sync"
3. Click on the Notion Sync app
4. The app includes two tabs:
   - **Notion Sync Admin**: Main configuration interface
   - **Notion Sync Log**: View sync operation history

Alternative method - Add to existing app:
1. Go to Setup → App Manager
2. Find your preferred app and click Edit
3. Select Navigation Items
4. Add "Notion Sync Admin" and "Notion Sync Log" tabs
5. Save the changes

### 3. Grant Permissions

The Notion Sync Admin UI requires specific permissions. There are two permission sets:

#### Notion Sync Administrator Permission Set
This is the main permission set for admin UI access. Assign this to users who need to:
- Configure sync mappings
- Browse Notion databases
- Manage field mappings
- Test connections

To assign:
1. Go to Setup → Users → Permission Sets
2. Find "Notion Sync Administrator"
3. Click on Manage Assignments
4. Add users who need admin access

This permission set includes:
- Custom permission: Notion_Sync_Admin
- Access to Notion API credentials
- Custom metadata type access
- Required user permissions (CustomizeApplication, ModifyMetadata)
- Read-only access to sync logs

#### Notion Integration User Permission Set
This is for users who only need to trigger syncs via Flow. They don't need admin access.

## Using the Admin UI

### Main View - Sync Configurations

When you open the Notion Sync Admin, you'll see:

1. **Summary Statistics**: 
   - Configured Objects count
   - Active Syncs count
   - Total Field Mappings count

2. **Configured Objects Table**:
   - Lists all existing sync configurations
   - Shows Salesforce object name and API name
   - Displays Notion database ID (database names coming soon)
   - Shows Active/Inactive status
   - Field mappings and relationships count
   - Edit button for each configuration

3. **New Sync Configuration Button**: Click to create a new object mapping

### Creating a New Configuration

1. **Click "New Sync Configuration"**
2. **Select Salesforce Object**: Choose from the dropdown list
3. **Configure Basic Settings**:
   - Set Active status (enabled by default)
   - Click "Browse Databases" to select a Notion database
   - Set the Salesforce ID property name (default: "Salesforce_ID")
4. **Save Initial Configuration**: You can save now and add field mappings later

### Editing an Existing Configuration

1. **Click "Edit"** on any configuration in the main table
2. **Basic Configuration Section**:
   - Toggle Active status
   - Change Notion database if needed
   - Update Salesforce ID property name

3. **Field Mappings Section**:
   - View existing field mappings
   - Add new mappings with the field mapping component
   - Auto-detection suggests compatible Notion property types
   - Long text fields can be mapped to page body content

4. **Relationship Mappings Section**:
   - Configure parent-child relationships
   - Map lookup/master-detail fields to Notion relations

5. **Action Buttons**:
   - **Cancel**: Discard changes (with confirmation if unsaved)
   - **Test Connection**: Verify Notion API connectivity
   - **Save**: Deploy configuration to metadata

### Database Browser Modal

When clicking "Browse Databases":
- Modal window shows all accessible Notion databases
- Search by database name or ID
- Click to select a database
- Shows database properties and their types

### Navigation

- **Back Button**: Return to main configuration list
- **Tab Navigation**: Switch between Notion Sync Admin and Notion Sync Log
- **App Launcher**: Access from the 9-dot grid menu

## Features

### Auto Type Detection

The UI automatically suggests Notion property types based on Salesforce field types:

- STRING → rich_text
- EMAIL → email
- NUMBER/CURRENCY → number
- DATE/DATETIME → date
- BOOLEAN → checkbox
- PICKLIST → select
- REFERENCE → relation

### Field Mapping

- Map any Salesforce field to any Notion property
- Long text areas can be mapped to page body content
- Property types can be manually adjusted if needed

### Test Connection

Use the "Test Connection" button to verify:
- Notion API connectivity
- Database accessibility
- Named Credential configuration

### Notion Sync Log Tab

The Notion Sync Log tab provides visibility into sync operations:

1. **List View**: Shows recent sync attempts sorted by creation date (newest first)
2. **Record Details**: Click on any log entry to see:
   - Record ID and Object Type
   - Operation Type (CREATE/UPDATE/DELETE)
   - Status (Success/Failed/Retrying)
   - Notion Page ID (if successful)
   - Error Message (if failed)
   - Timestamp

The list view uses a formula field to enable descending date sorting, showing the most recent sync operations first.

## Permission Details

When users don't have the required permission set, they will see a clear message in the UI:
- "Access Denied" screen with graphical illustration
- Clear message: "You don't have permission to access the Notion Sync Admin interface"
- Instructions to contact system administrator
- Specific request for "Notion Sync Administrator" permission set

The permission set checks are performed on all Apex methods to ensure security using the custom permission `Notion_Sync_Admin`.

## Troubleshooting

### Cannot See Notion Databases

1. Verify Named Credential is configured correctly
2. Check that the Notion API token has access to databases
3. Use "Test Connection" to diagnose issues

### Metadata Save Fails

1. Ensure user has Customize Application permission
2. Check for duplicate developer names in metadata
3. Review debug logs for specific errors

### Field Mappings Not Working

1. Verify Notion property names match exactly
2. Ensure property types are compatible
3. Check that Salesforce fields are accessible

## Best Practices

1. **Test First**: Always test connection before saving
2. **Map Required Fields**: Ensure all required Notion properties are mapped
3. **Use Title Property**: At least one field should map to a "title" property
4. **Unique Identifiers**: Keep the Salesforce ID property for sync tracking
5. **Start Small**: Begin with a few fields and expand gradually

## Next Steps

After configuring sync mappings:

1. Set up Flow triggers for the objects (see FLOW_CONFIGURATION.md)
2. Test sync with a few records
3. Monitor sync logs for any issues
4. Scale up to production data volumes