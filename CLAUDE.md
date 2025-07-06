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
   - `NotionSyncQueueable`: Core worker with runtime limit checking and self-chaining capability
   - `NotionDeduplicationQueueable`: Handles duplicate detection after sync completion
7. **Rate Limiter**: `NotionRateLimiter` - Enforces 3 req/sec limit and monitors governor limits at runtime
8. **Error Logger**: `NotionSyncLogger` - Tracks sync status and failures in custom object
9. **Sync Processor**: `NotionSyncProcessor` - Handles individual record processing

## Development Commands

### Scratch Org Setup - Automated (Recommended)
Use the provided setup script for consistent scratch org initialization:

```bash
# Create and setup a new scratch org with all configurations
./scripts/setup-scratch-org.sh

# Or specify a custom org alias
./scripts/setup-scratch-org.sh my-custom-alias
```

The setup script automatically:
1. Creates a new scratch org with 30-day expiration
2. Deploys all metadata (including integration test objects)
3. Assigns all required permission sets:
   - `Notion_Integration_User` - API access permissions
   - `Notion_Sync_Admin` - Admin UI access
   - `Notion_Integration_Test_User` - Test object permissions
4. Generates a password for UI testing
5. Provides next steps and useful commands

### Scratch Org Setup - Manual (if needed)
If you prefer manual setup or need to customize the process:

```bash
# Create scratch org
sf org create scratch -f config/project-scratch-def.json -a notion-sync-scratch -d -y 7

# Deploy all metadata (including integration folder)
sf project deploy start --source-dir force-app -o notion-sync-scratch

# Assign ALL required permission sets
sf org assign permset --name Notion_Integration_User -o notion-sync-scratch
sf org assign permset --name Notion_Sync_Admin -o notion-sync-scratch
sf org assign permset --name Notion_Integration_Test_User -o notion-sync-scratch

# Generate password (for UI testing)
sf org generate password -o notion-sync-scratch

# Open the org
sf org open -o notion-sync-scratch -p /lightning/n/Notion_Sync_Admin
```

### Daily Development Commands
- `sf project deploy start --source-dir force-app` - Deploy to Salesforce org
- `sf apex test run --code-coverage --result-format human` - Run all Apex tests
- `sf org delete scratch -o notion-sync-scratch -p` - Delete scratch org (when done)

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
   
   **For Human Users:**
   ```bash
   # The script will automatically load .env file if present
   ./scripts/run-integration-tests.sh
   ```
   
   **For Claude Code Sessions:**
   Integration tests require special handling due to their long execution time and extensive output:
   
   ```
   Bash command: ./scripts/run-integration-tests.sh 2>&1 | tee /tmp/integration-test-output.log
   timeout: 600000
   ```
   
   After completion, check results with:
   ```
   Bash command: tail -100 /tmp/integration-test-output.log | grep -E "(✅|❌|All integration tests)"
   ```
   
   **Critical Notes:**
   - Tests take 10+ minutes to complete - use `timeout: 600000` parameter
   - Output MUST be redirected to a file to see complete results
   - NEVER interrupt the command once started - this will terminate the process
   - Wait for natural completion - output truncation is display-only

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

## Claude Code Operational Notes

### Long-Running Bash Commands
**CRITICAL**: When executing any long-running Bash commands (integration tests, deployments, builds, etc.):
- **DO NOT interrupt the command once started** - any interruption will immediately terminate the process
- **DO NOT attempt to monitor or check on the process** - this will kill it
- **Output truncation is display-only** - the process continues running even if output is truncated
- **Wait for the full timeout period** - let the command complete naturally
- **The command will show results when done** - be patient

This is especially important for:
- Integration tests (10+ minutes)
- Package builds
- Large deployments
- Any command with long execution times

### Output Management for Long Commands
**ALWAYS save output to a file** for commands that produce extensive output:
- Long-running commands often produce output that will be truncated in terminal
- Without file output, you cannot verify completion status or results
- Terminal truncation makes it impossible to see the final summary

This is critical for integration tests - see the specific instructions in the "Pre-Push Testing Requirement" section above.

## CRITICAL Git Rules - MUST FOLLOW

1. **NEVER use `git add -A` or `git add -a`** - These commands are PROHIBITED because they can accidentally include files modified by scripts or containing sensitive data
2. **ALWAYS explicitly add files** - Use specific file paths like `git add force-app/main/default/classes/ClassName.cls`
3. **ALWAYS review changes before committing** - Scripts may alter file values (e.g., database IDs in metadata) that should not be committed

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
    // For multiple records: use Queueable with runtime limit checking
    // Queueable automatically chains when approaching governor limits
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

The system uses a single queueable class with self-chaining capability:

#### NotionSyncQueueable (Core Worker)
- **Purpose**: Performs sync operations with runtime governor limit checking
- **Responsibilities**:
  - Processes records individually (not in batches)
  - Makes API calls to create/update/delete Notion pages
  - Transforms Salesforce data to Notion format
  - Handles relationships between objects
  - Monitors governor limits at runtime and chains when approaching thresholds
  - Tracks all record IDs for deduplication after complete processing
- **Processing Pattern**:
  - Processes ~19 records per execution before hitting governor limits
  - Automatically chains to process remaining records
  - Triggers deduplication after all records are processed

```
Flow Trigger → NotionSyncInvocable → NotionSyncQueueable
                                         ↓ (if more records)
                                     NotionSyncQueueable (chained)
                                         ↓ (if more records)
                                     NotionSyncQueueable (chained)
                                         ↓ (when complete)
                                     NotionDeduplicationQueueable
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
   - Multiple records: Queueable with runtime limit checking
4. For queueable processing:
   - Processes records individually with governor limit monitoring
   - When approaching limits (~19 records), chains to next queueable
   - Continues until all records are processed
5. Processing maintains user context for Named Credential access
6. Query Salesforce objects based on metadata configuration
7. Transform data according to field mappings
8. Handle relationships by creating/updating related records first
9. Make API calls to create/update/delete Notion database pages
10. Store Salesforce IDs in designated Notion properties for future sync
11. Log success/failure in Notion_Sync_Log__c custom object
12. After all records complete, run deduplication for CREATE/UPDATE operations

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

### Current Implementation Features

**Important**: The implementation uses runtime governor limit checking to handle any volume of records:

- **Runtime Processing**: Records are processed individually with governor limit checks
- **Automatic Chaining**: When approaching limits (~19 records), automatically chains to next queueable
- **Complete Processing**: All records eventually processed through the queueable chain
- **Deduplication**: After all records complete, deduplication runs for CREATE/UPDATE operations
- **No Pre-Batching**: No need to divide records into batches - system handles this automatically

For additional details on handling large data volumes, see [docs/LARGE_DATA_SYNC.md](docs/LARGE_DATA_SYNC.md).

### Documentation

Additional documentation is available in the `docs/` folder:
- [ARCHITECTURE_REVIEW.md](docs/ARCHITECTURE_REVIEW.md) - Architecture analysis and recommendations
- [CI_SETUP.md](docs/CI_SETUP.md) - CI/CD configuration guide
- [FLOW_CONFIGURATION.md](docs/FLOW_CONFIGURATION.md) - Flow setup instructions
- [INTEGRATION_TESTING.md](docs/INTEGRATION_TESTING.md) - Integration testing guide
- [LARGE_DATA_SYNC.md](docs/LARGE_DATA_SYNC.md) - Large data volume handling architecture