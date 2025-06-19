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
7. **Real-time Sync via Flow**: Sync triggered by Flow on record create/update/delete events using Invocable Apex methods
8. **Deletion Handling**: When Salesforce records are deleted, corresponding Notion pages are also deleted
9. **Asynchronous Processing**: Use Queueable and @future methods to avoid transaction limitations
10. **Error Resilience**: Automatic retry mechanism and error logging for failed syncs

### Architecture Principles

- **Configuration-Driven**: All sync mappings defined in Custom Metadata
- **Object-Agnostic**: Works with any Salesforce standard or custom objects
- **Relationship-Aware**: Processes and maintains parent-child and lookup relationships
- **Notion-Native**: Creates proper Notion database entries with correct property types
- **User Context Aware**: Maintains user context for Named Credential access
- **Transaction-Safe**: External API calls happen outside of DML transactions

### Core Components

1. **Custom Metadata Types**: Define sync configurations (objects, fields, databases, property mappings)
2. **Invocable Apex**: `NotionSyncInvocable` - Entry point for Flow-triggered syncs
3. **Notion API Client**: Handles authentication and API calls to Notion
4. **Data Transformer**: Converts Salesforce data to Notion format
5. **Relationship Handler**: Manages cross-object relationships
6. **Queueable Classes**:
   - `NotionSyncQueueable`: Core worker that performs actual sync operations (API calls, data transformation)
   - `NotionSyncBatchQueueable`: Orchestrator for large volumes - splits work into batches and chains jobs
7. **Batch Processor**: `NotionSyncBatchProcessor` - Intelligently sizes batches based on governor limits
8. **Rate Limiter**: `NotionRateLimiter` - Enforces 3 req/sec limit and monitors governor limits
9. **Error Logger**: `NotionSyncLogger` - Tracks sync status and failures in custom object

## Development Commands

### Scratch Org Setup (Initial or when expired)
- `sf org create scratch -f config/project-scratch-def.json -a my-scratch` - Create scratch org
- `sf project deploy start --source-dir force-app` - Deploy all metadata to scratch org
- `sf org assign permset --name Notion_Integration_User` - Assign integration permission set for API access
- `sf org assign permset --name Notion_Sync_Admin` - Assign admin permission set to access Notion Sync Admin UI
- `sf org delete scratch -o my-scratch -p` - Delete scratch org (when done)

### Daily Development Commands
- `sf project deploy start --source-dir force-app` - Deploy to Salesforce org
- `sf apex test run --code-coverage --result-format human` - Run all Apex tests

### UI Testing with Playwright MCP
When testing the UI in Claude, use the Playwright MCP browser control tool:
- Get the org URL: `sf org open --url-only -o <org-alias>`
- Use the URL with Playwright MCP's browser_navigate tool
- This allows interactive UI testing directly within Claude

Example:
```bash
# Get the URL for the scratch org
URL=$(sf org open --url-only -o notion-sync-scratch)
# Then use browser_navigate with the URL in Claude
```

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

3. If you have Notion API credentials configured, run integration tests:
   ```bash
   # If using .env file (recommended)
   nf run ./scripts/run-integration-tests.sh
   
   # Or manually export environment variables
   export $(cat .env | xargs) && ./scripts/run-integration-tests.sh
   ```

Only push your changes after all tests complete successfully.

## CI/CD

The project includes GitHub Actions workflows for:

1. **CI Testing** (`.github/workflows/ci.yml`):
   - Triggers on push to main and pull requests
   - Creates a scratch org
   - Deploys all metadata
   - Runs Apex tests
   - **Runs integration tests with real Notion API** (requires secrets configuration)
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

### Integration Test Configuration

For integration tests to run in CI, configure these GitHub secrets:
- `NOTION_API_KEY` - Your Notion integration token
- `NOTION_WORKSPACE_ID` - Target workspace ID
- `NOTION_TEST_ACCOUNT_DB` - Test database ID for Accounts
- `NOTION_TEST_CONTACT_DB` - Test database ID for Contacts
- `NOTION_TEST_PARENT_DB` - Test database ID for Test Parent
- `NOTION_TEST_CHILD_DB` - Test database ID for Test Child

See `docs/CI_SETUP.md` for detailed setup instructions.

## Coding Standards

- **Language**: All code, comments, and documentation must be written in English
- **Naming**: Use descriptive English names for classes, methods, variables, and metadata
- **Comments**: All inline comments and method documentation in English

## Implementation Details

### Invocable Apex Method
```apex
@InvocableMethod(
    label='Sync Record to Notion' 
    description='Synchronizes a Salesforce record to Notion database'
    category='Notion Integration'
)
public static List<SyncResult> syncToNotion(List<SyncRequest> requests) {
    // Process each sync request
    // For single records: use @future for immediate processing
    // For bulk operations: use Queueable
    // Maintains user context for Named Credential access
}
```

### Flow Integration
1. Create Record-Triggered Flow on desired object (e.g., Account)
2. Set trigger: "When a record is created or updated" or "When a record is deleted"
3. Add Action: Call Apex → NotionSyncInvocable
4. Map Input Values:
   - recordId: `{!$Record.Id}`
   - objectType: 'Account' (or dynamic object API name)
   - operationType: 'CREATE', 'UPDATE', or 'DELETE'

### Queueable Architecture

The system uses two queueable classes for different purposes:

#### NotionSyncQueueable (Core Worker)
- **Purpose**: Performs actual sync operations to Notion
- **Responsibilities**:
  - Makes API calls to create/update/delete Notion pages
  - Transforms Salesforce data to Notion format
  - Handles relationships between objects
  - Manages individual sync requests
- **Used by**: NotionSyncInvocable (for ≤50 records) and NotionSyncBatchQueueable

#### NotionSyncBatchQueueable (Batch Orchestrator)
- **Purpose**: Manages large volume processing
- **Responsibilities**:
  - Splits large record sets into manageable batches
  - Chains multiple queueable jobs together
  - Monitors governor limits between batches
  - Ensures sync logs are flushed after each batch
- **Used by**: NotionSyncInvocable (for >50 records)

```
Flow Trigger → NotionSyncInvocable
                ├─ Small volume (≤50) → NotionSyncQueueable
                └─ Large volume (>50) → NotionSyncBatchQueueable
                                         └─ Multiple NotionSyncQueueable calls
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
  
- **NotionRelation__mdt**: Defines relationship mappings between objects
  - `ParentObject__c`: Reference to parent NotionSyncObject__mdt
  - `ChildObject__c`: Reference to child NotionSyncObject__mdt
  - `SalesforceRelationshipField__c`: Lookup/Master-detail field name
  - `NotionRelationPropertyName__c`: Notion relation property name

### Flow Integration
- **Record-Triggered Flow**: Configured per object to sync
  - Trigger: After insert, update, or delete
  - Action: Call NotionSyncInvocable Apex method
  - Parameters: Record ID, Object Type, Operation Type

### Data Flow
1. Flow triggers on record create/update/delete
2. Flow calls NotionSyncInvocable with record details
3. Invocable method determines processing strategy:
   - Single record: @future for immediate processing
   - Bulk/Delete: Queueable for batch processing
4. Processing maintains user context for Named Credential access
5. Query Salesforce objects based on metadata configuration
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

### Current Limitations

**Important**: The current implementation is optimized for real-time, event-driven sync of individual records or small batches. It has the following limitations for large data volumes:

- **Maximum Records per Sync**: ~30-40 records (due to API callout limits)
- **No Batch Processing**: All records processed in single transaction
- **No Retry Mechanism**: Despite the Retry_Count__c field, automatic retries are not yet implemented
- **Memory Constraints**: All data held in memory simultaneously

For large data sync architecture and planned improvements, see [docs/LARGE_DATA_SYNC.md](docs/LARGE_DATA_SYNC.md).

### Documentation

Additional documentation is available in the `docs/` folder:
- [ARCHITECTURE_REVIEW.md](docs/ARCHITECTURE_REVIEW.md) - Architecture analysis and recommendations
- [CI_SETUP.md](docs/CI_SETUP.md) - CI/CD configuration guide
- [FLOW_CONFIGURATION.md](docs/FLOW_CONFIGURATION.md) - Flow setup instructions
- [INTEGRATION_TESTING.md](docs/INTEGRATION_TESTING.md) - Integration testing guide
- [LARGE_DATA_SYNC.md](docs/LARGE_DATA_SYNC.md) - Large data volume handling architecture