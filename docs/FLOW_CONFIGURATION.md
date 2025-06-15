# Flow Configuration Guide

This guide explains how to configure Salesforce Flows to trigger Notion synchronization when records are created, updated, or deleted.

## Overview

The Notion sync system uses Invocable Apex methods to process sync requests while maintaining user context. This ensures that record operations complete quickly while sync processing happens asynchronously with proper Named Credential access.

## Flow Architecture

```
Record Change → Flow Trigger → Invocable Apex → @future/Queueable → Notion API
```

## Template Flows

Two template flows are provided:

1. **NotionSync_Template_CreateUpdate.flow-meta.xml** - For create and update operations
2. **NotionSync_Template_Delete.flow-meta.xml** - For delete operations

## Creating Flows for New Objects

### Step 1: Copy Template Files

1. Navigate to `force-app/main/default/flows/`
2. Copy the template flows:
   - `NotionSync_Template_CreateUpdate.flow-meta.xml` → `NotionSync_[ObjectName]_CreateUpdate.flow-meta.xml`
   - `NotionSync_Template_Delete.flow-meta.xml` → `NotionSync_[ObjectName]_Delete.flow-meta.xml`

### Step 2: Configure the CREATE/UPDATE Flow

Edit the copied CREATE/UPDATE flow file:

1. **Update the label:**
   ```xml
   <label>Notion Sync - [ObjectName] Create/Update</label>
   ```

2. **Update the description:**
   ```xml
   <description>Flow for [ObjectName] CREATE/UPDATE operations - triggers Notion sync when [ObjectName] records are created or updated.</description>
   ```

3. **Set the object type in the start element:**
   ```xml
   <start>
       <object>[ObjectApiName]</object>
       <recordTriggerType>CreateAndUpdate</recordTriggerType>
       <triggerType>RecordAfterSave</triggerType>
   </start>
   ```

4. **Update the action call inputs:**
   ```xml
   <inputParameters>
       <name>objectType</name>
       <value>
           <stringValue>[ObjectApiName]</stringValue>
       </value>
   </inputParameters>
   ```

### Step 3: Configure the DELETE Flow

Edit the copied DELETE flow file:

1. **Update the label:**
   ```xml
   <label>Notion Sync - [ObjectName] Delete</label>
   ```

2. **Update the description:**
   ```xml
   <description>Flow for [ObjectName] DELETE operations - triggers Notion sync when [ObjectName] records are deleted.</description>
   ```

3. **Set the object type in the start element:**
   ```xml
   <start>
       <object>[ObjectApiName]</object>
       <recordTriggerType>Delete</recordTriggerType>
       <triggerType>RecordBeforeDelete</triggerType>
   </start>
   ```

4. **Update the action call inputs:**
   ```xml
   <inputParameters>
       <name>objectType</name>
       <value>
           <stringValue>[ObjectApiName]</stringValue>
       </value>
   </inputParameters>
   ```

## Example: Contact Object

Here's how to create flows for the Contact object:

### 1. NotionSync_Contact_CreateUpdate.flow-meta.xml

1. Copy from template
2. Replace `[ObjectName]` with `Contact`
3. Replace `[ObjectApiName]` with `Contact`
4. The flow will trigger when Contact records are created or updated

### 2. NotionSync_Contact_Delete.flow-meta.xml

1. Copy from template
2. Replace `[ObjectName]` with `Contact`
3. Replace `[ObjectApiName]` with `Contact`
4. The flow will trigger when Contact records are deleted

## Deploying Flows

After creating your flow files:

```bash
# Deploy to Salesforce
sf project deploy start --source-dir force-app/main/default/flows

# Activate the flows in Setup → Flows
```

## Testing Flows

To verify your flows are working:

1. **Test CREATE:** Create a new record of your object type
2. **Test UPDATE:** Update an existing record of your object type
3. **Test DELETE:** Delete a record of your object type

Check the sync logs to verify records are being processed:

```bash
sf apex run --file scripts/apex/check-sync-result.apex
```

## Flow Naming Convention

Follow this naming pattern for consistency:

- **CREATE/UPDATE:** `NotionSync_[ObjectName]_CreateUpdate`
- **DELETE:** `NotionSync_[ObjectName]_Delete`

Examples:
- `NotionSync_Account_CreateUpdate`
- `NotionSync_Account_Delete`
- `NotionSync_Contact_CreateUpdate`
- `NotionSync_Contact_Delete`
- `NotionSync_Opportunity_CreateUpdate`
- `NotionSync_Opportunity_Delete`

## Troubleshooting

### Flow Not Triggering
1. Verify the flow is activated
2. Check that the object type matches exactly
3. Ensure the trigger conditions are met
4. Verify user has the `Notion_Integration_User` permission set

### Invocable Method Not Called
1. Check flow debug logs
2. Verify the action name is `NotionSyncInvocable`
3. Ensure all required parameters are mapped

### Sync Not Processing
1. Check Apex debug logs for errors
2. Review sync logs in `Notion_Sync_Log__c`
3. Verify Named Credential configuration

## Best Practices

1. **Keep flows simple** - Only call the Invocable method, don't add complex logic
2. **Use consistent naming** - Follow the established naming convention
3. **Test thoroughly** - Verify all trigger scenarios work correctly
4. **Monitor performance** - Watch for any performance impact on record operations
5. **Document customizations** - Keep track of any custom logic added to flows

## Advanced Configuration

### Conditional Sync
To sync only specific records, add entry conditions to your flow:

```xml
<decisions>
    <name>Should_Sync</name>
    <label>Should Sync?</label>
    <locationX>176</locationX>
    <locationY>134</locationY>
    <defaultConnectorLabel>Don't Sync</defaultConnectorLabel>
    <rules>
        <name>Sync_Record</name>
        <conditionLogic>and</conditionLogic>
        <conditions>
            <leftValueReference>$Record.Status__c</leftValueReference>
            <operator>EqualTo</operator>
            <rightValue>
                <stringValue>Active</stringValue>
            </rightValue>
        </conditions>
        <connector>
            <targetReference>Sync_to_Notion</targetReference>
        </connector>
        <label>Sync Record</label>
    </rules>
</decisions>
```

### Bulk Operations
The flows are designed to handle bulk operations efficiently. The Invocable method automatically:
- Uses @future for single record operations (immediate processing)
- Uses Queueable for bulk operations (batch processing)

This ensures optimal performance regardless of operation size.

## Security Considerations

1. **Permission Sets**: Users must have the `Notion_Integration_User` permission set assigned
2. **Object Access**: Users need appropriate CRUD permissions on objects being synced
3. **Field Access**: Ensure field-level security allows access to synced fields
4. **Named Credentials**: External Credential must have "Available for All Users" checked and API key configured