# Flow Configuration Guide

This guide explains how to configure Salesforce Flows to trigger Notion synchronization using the provided templates.

## Overview

The Notion sync process uses Record-Triggered Flows to automatically sync Salesforce records to Notion when they are created, updated, or deleted. The Flows publish Platform Events that are processed asynchronously by Apex code.

## Template Flows

This package includes template Flows that you can use as starting points:

### Account Flows (Ready to Use)
- **NotionSync - Account Create/Update**: Triggers on Account create/update
- **NotionSync - Account Delete**: Triggers on Account deletion

### Generic Templates (Require Customization)
- **NotionSync - Template Create/Update**: Generic template for any object
- **NotionSync - Template Delete**: Generic template for deletion

## How to Use Template Flows

### Option 1: Use Account Flows (Pre-configured)
The Account Flows are ready to use once you've configured the Account sync metadata.

1. Ensure you have configured:
   - `NotionSyncObject__mdt` record for Account
   - `NotionSyncField__mdt` records for Account fields
   - Notion database setup

2. Activate the Account Flows:
   - Go to Setup → Flows
   - Find "NotionSync - Account Create/Update" and "NotionSync - Account Delete"
   - Click "Activate" if they're not already active

### Option 2: Create Custom Flows from Templates

1. **Clone the Template Flow**:
   - Go to Setup → Flows
   - Find "NotionSync - Template Create/Update"
   - Click the dropdown → "Save As"
   - Name it for your object (e.g., "NotionSync - Contact Create/Update")

2. **Customize the Flow**:
   - Replace `REPLACE_WITH_OBJECT_API_NAME` with your object's API name (e.g., "Contact")
   - Update the trigger object in the Start element
   - Save and activate the Flow

3. **Repeat for Delete Flow**:
   - Clone "NotionSync - Template Delete"
   - Make the same customizations
   - Save and activate

## Flow Structure

Each Flow follows this pattern:

```
Trigger (Record Create/Update/Delete)
    ↓
Create Platform Event Record
    ↓
Platform Event Published
    ↓
Apex Trigger Processes Event
    ↓
Queueable Job Syncs to Notion
```

## Platform Event Fields

The Flows create `Notion_Sync_Event__e` records with these fields:

- **Record_Id__c**: The Salesforce record ID
- **Object_Type__c**: The Salesforce object API name
- **Operation_Type__c**: "CREATE", "UPDATE", or "DELETE"

## Best Practices

1. **Test in Sandbox**: Always test your Flows in a sandbox environment first
2. **Monitor Platform Events**: Use Event Monitoring to track platform event volume
3. **Error Handling**: The async processing handles errors gracefully with retry logic
4. **Performance**: Platform Events ensure your record saves aren't slowed by external API calls

## Troubleshooting

### Flow Not Triggering
- Check that the Flow is activated
- Verify the trigger conditions match your use case
- Check Flow debug logs

### Sync Not Working
- Verify your `NotionSyncObject__mdt` configuration
- Check the `Notion_Sync_Log__c` records for error details
- Review Apex debug logs

### Platform Event Issues
- Monitor platform event limits in your org
- Check that the trigger is properly handling the events

## Advanced Configuration

### Conditional Sync
You can add decision elements to your Flows to conditionally sync based on field values:

```
Record Trigger
    ↓
Decision: Should Sync?
    ↓ (Yes)
Create Platform Event
    ↓ (No)
End Flow
```

### Multiple Object Types
For objects with different sync requirements, create separate Flows rather than trying to handle multiple objects in one Flow.

## Support

For additional help with Flow configuration, refer to:
- Salesforce Flow documentation
- The project's main README.md
- Platform Event documentation