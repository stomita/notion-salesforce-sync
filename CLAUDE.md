# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Salesforce-to-Notion synchronization tool that runs entirely within Salesforce using Apex. The tool synchronizes arbitrary Salesforce data to arbitrary Notion database pages while preserving relationship structures.

### Key Requirements

1. **Apex-only Implementation**: All code runs within Salesforce, no external servers required
2. **Salesforce Authentication**: Uses Salesforce's recommended authentication (External Services, Named Credentials)
3. **Relationship Preservation**: Salesforce object relationships are maintained as Notion relations
4. **Generic Configuration**: Sync targets configurable via Custom Metadata Types
5. **Unique Identification**: Notion databases must have properties to store Salesforce IDs for uniqueness
6. **Long Text Support**: Salesforce Long Text Area fields can be mapped to Notion page body content
7. **Real-time Sync via Flow**: Sync triggered by Flow on record create/update/delete events using Platform Events for asynchronous processing
8. **Deletion Handling**: When Salesforce records are deleted, corresponding Notion pages are also deleted
9. **Asynchronous Processing**: Use Platform Events and Queueable Apex to avoid transaction limitations
10. **Error Resilience**: Automatic retry mechanism and error logging for failed syncs

### Architecture Principles

- **Configuration-Driven**: All sync mappings defined in Custom Metadata
- **Object-Agnostic**: Works with any Salesforce standard or custom objects
- **Relationship-Aware**: Processes and maintains parent-child and lookup relationships
- **Notion-Native**: Creates proper Notion database entries with correct property types
- **Event-Driven**: Uses Platform Events for decoupled, asynchronous processing
- **Transaction-Safe**: External API calls happen outside of DML transactions

### Core Components

1. **Custom Metadata Types**: Define sync configurations (objects, fields, databases, property mappings)
2. **Platform Event**: `Notion_Sync_Event__e` - Carries sync requests from Flow to async processor
3. **Event Subscriber**: Processes platform events and enqueues Queueable jobs
4. **Notion API Client**: Handles authentication and API calls to Notion
5. **Data Transformer**: Converts Salesforce data to Notion format
6. **Relationship Handler**: Manages cross-object relationships
7. **Sync Queueable**: Asynchronous processor for Notion API operations
8. **Error Logger**: Tracks sync status and failures in custom object

## Development Commands

### Scratch Org Setup (Initial or when expired)
- `sf org create scratch -f config/project-scratch-def.json -a my-scratch` - Create scratch org
- `sf org delete scratch -o my-scratch -p` - Delete scratch org

### Daily Development Commands
- `sf project deploy start --source-dir force-app` - Deploy to Salesforce org
- `sf apex test run --code-coverage --result-format human` - Run all Apex tests

### Important: Pre-Push Testing Requirement

**ALWAYS run the following commands before pushing code to ensure code quality:**

1. Deploy all changes to your scratch org:
   ```bash
   sf project deploy start --source-dir force-app
   ```

2. Run all Apex tests to verify functionality:
   ```bash
   sf apex test run --code-coverage --result-format human
   ```

Only push your changes after both commands complete successfully.

## CI/CD

The project includes GitHub Actions workflows for:

1. **CI Testing** (`.github/workflows/ci.yml`):
   - Triggers on push to main and pull requests
   - Creates a scratch org
   - Deploys all metadata
   - Runs Apex tests
   - Cleans up the scratch org

2. **Claude Code Integration** (`.github/workflows/claude-code.yml`):
   - Responds to GitHub issues and comments
   - Generates code using Claude AI

### Setting up CI/CD

1. Enable Dev Hub in your Salesforce org
2. Create a connected app for CI authentication
3. Get the SFDX auth URL:
   ```bash
   sf org display -o your-devhub-alias --verbose --json
   ```
4. Add the auth URL as a GitHub secret named `DEVHUB_SFDX_AUTH_URL`

## Coding Standards

- **Language**: All code, comments, and documentation must be written in English
- **Naming**: Use descriptive English names for classes, methods, variables, and metadata
- **Comments**: All inline comments and method documentation in English

## Implementation Details

### Platform Event Definition
```xml
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <eventType>HighVolume</eventType>
    <label>Notion Sync Event</label>
    <pluralLabel>Notion Sync Events</pluralLabel>
    <fields>
        <fullName>Record_Id__c</fullName>
        <label>Record ID</label>
        <length>18</length>
        <required>true</required>
        <type>Text</type>
    </fields>
    <fields>
        <fullName>Object_Type__c</fullName>
        <label>Object Type</label>
        <length>80</length>
        <required>true</required>
        <type>Text</type>
    </fields>
    <fields>
        <fullName>Operation_Type__c</fullName>
        <label>Operation Type</label>
        <length>20</length>
        <required>true</required>
        <type>Text</type>
    </fields>
</CustomObject>
```

### Flow Integration
1. Create Record-Triggered Flow on desired object (e.g., Account)
2. Set trigger: "When a record is created or updated" or "When a record is deleted"
3. Add Action: "Create Records" → Platform Event
4. Set Field Values:
   - Object: `Notion_Sync_Event__e`
   - Record_Id__c: `{!$Record.Id}`
   - Object_Type__c: 'Account' (or dynamic object API name)
   - Operation_Type__c: 'CREATE', 'UPDATE', or 'DELETE'

### Event Subscriber (Trigger)
```apex
trigger NotionSyncEventTrigger on Notion_Sync_Event__e (after insert) {
    List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
    
    for (Notion_Sync_Event__e event : Trigger.new) {
        requests.add(new NotionSyncQueueable.SyncRequest(
            event.Record_Id__c,
            event.Object_Type__c,
            event.Operation_Type__c
        ));
    }
    
    if (!requests.isEmpty()) {
        System.enqueueJob(new NotionSyncQueueable(requests));
    }
}
```

### Queueable Apex
```apex
public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<SyncRequest> requests;
    
    public NotionSyncQueueable(List<SyncRequest> requests) {
        this.requests = requests;
    }
    
    public void execute(QueueableContext context) {
        // Process sync requests
        // Make Notion API callouts
        // Handle errors and retries
    }
}
```

## Architecture

### Custom Metadata Structure
- **NotionSyncObject__mdt**: Defines which Salesforce objects to sync
  - `ObjectApiName__c`: Salesforce object API name
  - `NotionDatabaseId__c`: Target Notion database ID
  - `IsActive__c`: Enable/disable sync for this object
  - `SalesforceIdPropertyName__c`: Notion property name to store Salesforce ID
  
- **NotionSyncField__mdt**: Maps Salesforce fields to Notion properties
  - `NotionSyncObject__c`: Master-detail to NotionSyncObject__mdt
  - `SalesforceFieldApiName__c`: Salesforce field API name
  - `NotionPropertyName__c`: Notion property name
  - `NotionPropertyType__c`: Notion property type (title, rich_text, number, etc.)
  - `IsBodyContent__c`: Map Long Text Area to page body content
  
- **NotionDatabase__mdt**: Stores Notion database configurations
  - `DatabaseId__c`: Notion database ID
  - `DatabaseName__c`: Friendly name for the database
  - `WorkspaceId__c`: Notion workspace ID
  
- **NotionRelation__mdt**: Defines relationship mappings between objects
  - `ParentObject__c`: Reference to parent NotionSyncObject__mdt
  - `ChildObject__c`: Reference to child NotionSyncObject__mdt
  - `SalesforceRelationshipField__c`: Lookup/Master-detail field name
  - `NotionRelationPropertyName__c`: Notion relation property name

### Flow Integration
- **Record-Triggered Flow**: Configured per object to sync
  - Trigger: After insert, update, or delete
  - Action: Create Platform Event record
  - Event Fields: Record ID, Object Type, Operation Type

### Data Flow
1. Flow triggers on record create/update/delete
2. Flow publishes Platform Event with record details
3. Platform Event Trigger receives the event
4. Trigger enqueues Queueable job for asynchronous processing
5. Queueable job queries Salesforce objects based on metadata configuration
6. Transform data according to field mappings
7. Handle relationships by creating/updating related records first
8. Make API calls to create/update/delete Notion database pages
9. Store Salesforce IDs in designated Notion properties for future sync
10. Log success/failure in Notion_Sync_Log__c custom object

### API Integration
- **Named Credentials**: Store Notion API authentication
  - URL: https://api.notion.com
  - Authentication: Named Principal with API Token
  - Header: Authorization: Bearer {token}
  
### Error Handling
- **Retry Logic**: Automatic retry for transient failures (configurable retry count)
- **Error Logging**: `Notion_Sync_Log__c` custom object to track sync status
- **Partial Success**: Continue sync for other records if one fails
- **Notification**: Email alerts for critical sync failures

### Sync Log Object (`Notion_Sync_Log__c`)
- **Record_Id__c**: Salesforce record ID
- **Object_Type__c**: Salesforce object API name
- **Operation_Type__c**: CREATE/UPDATE/DELETE
- **Status__c**: Success/Failed/Retrying
- **Notion_Page_Id__c**: Resulting Notion page ID
- **Error_Message__c**: Error details if failed
- **Retry_Count__c**: Number of retry attempts
- **Created_Date__c**: Timestamp of sync attempt