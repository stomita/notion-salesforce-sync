# Flow Configuration Guide

This guide explains how to configure Salesforce Flows to trigger Notion synchronization when records are created, updated, or deleted.

## Overview

The Notion sync system uses Platform Events (`Notion_Sync_Event__e`) to decouple Flow triggers from the actual sync processing. This ensures that record operations complete quickly while sync processing happens asynchronously.

## Flow Architecture

```
Record Change → Flow Trigger → Platform Event → Event Trigger → Queueable Job → Notion API
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

4. **Set the Object_Type__c value:**
   ```xml
   <inputAssignments>
       <field>Object_Type__c</field>
       <value>
           <stringValue>[ObjectApiName]</stringValue>
       </value>
   </inputAssignments>
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

4. **Set the Object_Type__c value:**
   ```xml
   <inputAssignments>
       <field>Object_Type__c</field>
       <value>
           <stringValue>[ObjectApiName]</stringValue>
       </value>
   </inputAssignments>
   ```

## Example: Contact Object

Here's how to create flows for the Contact object:

### File Names:
- `NotionSync_Contact_CreateUpdate.flow-meta.xml`
- `NotionSync_Contact_Delete.flow-meta.xml`

### Configuration:
- Replace `[ObjectName]` with `Contact`
- Replace `[ObjectApiName]` with `Contact`

### CREATE/UPDATE Flow:
```xml
<label>Notion Sync - Contact Create/Update</label>
<start>
    <object>Contact</object>
    <recordTriggerType>CreateAndUpdate</recordTriggerType>
    <triggerType>RecordAfterSave</triggerType>
</start>
<inputAssignments>
    <field>Object_Type__c</field>
    <value>
        <stringValue>Contact</stringValue>
    </value>
</inputAssignments>
```

### DELETE Flow:
```xml
<label>Notion Sync - Contact Delete</label>
<start>
    <object>Contact</object>
    <recordTriggerType>Delete</recordTriggerType>
    <triggerType>RecordBeforeDelete</triggerType>
</start>
<inputAssignments>
    <field>Object_Type__c</field>
    <value>
        <stringValue>Contact</stringValue>
    </value>
</inputAssignments>
```

## Deployment and Activation

### 1. Deploy the Flows
```bash
sf project deploy start --source-dir force-app/main/default/flows
```

### 2. Activate the Flows

After deployment, activate the flows in your Salesforce org:

1. Go to **Setup** → **Process Automation** → **Flows**
2. Find your newly deployed flows
3. Click on each flow and select **Activate**
4. Choose the appropriate activation options

### 3. Test the Flows

1. **Test CREATE:** Create a new record of your object type
2. **Test UPDATE:** Update an existing record of your object type
3. **Test DELETE:** Delete a record of your object type

Check the Platform Event Monitor or debug logs to verify that `Notion_Sync_Event__e` records are being created.

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

### Platform Event Not Created
1. Check flow debug logs
2. Verify Platform Event permissions
3. Ensure `Notion_Sync_Event__e` object exists

### Sync Not Processing
1. Check the Platform Event Trigger: `NotionSyncEventTrigger`
2. Verify Queueable job execution
3. Review sync logs in `Notion_Sync_Log__c`

## Best Practices

1. **Keep flows simple** - Only create the Platform Event, don't add complex logic
2. **Use consistent naming** - Follow the established naming convention
3. **Test thoroughly** - Verify all trigger scenarios work correctly
4. **Monitor performance** - Watch for any performance impact on record operations
5. **Document customizations** - Keep track of any custom logic added to flows

## Advanced Configuration

### Conditional Sync
To sync only specific records, add entry conditions to your flow:

```xml
<start>
    <object>Account</object>
    <recordTriggerType>CreateAndUpdate</recordTriggerType>
    <triggerType>RecordAfterSave</triggerType>
    <filterLogic>1</filterLogic>
    <filters>
        <field>Type</field>
        <operator>EqualTo</operator>
        <value>
            <stringValue>Customer</stringValue>
        </value>
    </filters>
</start>
```

### Bulk Processing Considerations
The flows are designed to handle bulk operations efficiently by creating individual Platform Events for each record. The asynchronous processing via Queueable jobs ensures good performance even with large data volumes.