# Notion Sync Admin UI Architecture

## Overview

The Notion Sync Admin UI is a Lightning Web Component (LWC) based interface that allows Salesforce administrators to configure Notion synchronization mappings without directly editing custom metadata records.

## Component Architecture

### 1. Main Container Component
**Component**: `notionSyncAdmin`
- Manages overall application state and navigation
- Handles object selection and configuration loading
- Tracks new vs. existing configurations with `isNewConfiguration` flag
- Manages unsaved changes and provides confirmation dialogs
- Provides error handling and toast notifications
- Coordinates between configuration view and summary view

### 2. Configuration Summary Component
**Component**: `notionSyncSummary`
- Default landing view showing all configured sync mappings
- Displays summary statistics (configured objects, active syncs, field mappings)
- Provides table view of all configurations with:
  - Object name and API name
  - Notion database ID
  - Active/Inactive status
  - Field and relationship counts
  - Edit actions
- Dispatches edit events to parent component

### 3. Database Browser Component
**Component**: `notionDatabaseBrowser`
- Modal component for database selection
- Fetches and displays available Notion databases
- Allows searching and filtering databases
- Shows database properties and their types
- Dispatches selection events with database ID and name

### 4. Field Mapping Component
**Component**: `notionFieldMapping`
- Embedded within main admin component
- Displays Salesforce fields for selected object
- Shows Notion database properties
- Auto-detects compatible property types
- Manages field mapping array
- Supports body content mapping for Long Text fields

### 5. Relationship Configuration Component
**Component**: `notionRelationshipConfig`
- Embedded within main admin component
- Configures parent-child relationships
- Maps lookup/master-detail fields to Notion relations
- Manages relationship mapping array

## Apex Architecture

### 1. NotionAdminController
Main controller for UI operations with permission checking:
- `checkAdminPermission()`: Validates user has `Notion_Sync_Admin` custom permission
- `getDatabases()`: Fetch Notion databases via API
- `getDatabaseSchema(databaseId)`: Get properties for a specific database
- `getSalesforceObjects()`: Return available SF objects (filtered for syncable objects)
- `getObjectFields(objectApiName)`: Get fields for an object with type information
- `getAllSyncConfigurations()`: Fetch all existing sync configurations
- `getSyncConfiguration(objectApiName)`: Get configuration for specific object
- `saveSyncConfiguration(config)`: Save configuration using Metadata API
- `testConnection(databaseId)`: Verify Notion API connectivity

### 2. NotionMetadataService
Service class for custom metadata operations using Metadata API:
- `saveSyncConfiguration(config)`: Orchestrates saving of all metadata records
- Creates/updates NotionSyncObject__mdt records
- Creates/updates NotionSyncField__mdt records
- Creates/updates NotionRelation__mdt records
- Handles developer name sanitization
- Manages metadata deployment asynchronously

### 3. NotionApiClient
Service for Notion API interactions:
- Uses Named Credentials (`Notion_API`) for authentication
- `searchDatabases()`: Retrieves all accessible databases
- `getDatabase(databaseId)`: Gets specific database schema
- Handles API response parsing and error handling
- Returns standardized NotionResponse wrapper

## Data Flow

1. **Initial Load**:
   - Summary component fetches all sync configurations
   - Displays configuration table with statistics
   - User can create new or edit existing configurations

2. **New Configuration Process**:
   - User clicks "New Sync Configuration"
   - Component sets `isNewConfiguration = true`
   - User selects Salesforce object from dropdown
   - User browses and selects Notion database
   - Initial configuration saved to metadata
   - Field and relationship mappings can be added

3. **Edit Configuration Process**:
   - User clicks "Edit" on existing configuration
   - Component loads configuration details
   - User modifies settings, fields, or relationships
   - Changes tracked with `hasUnsavedChanges` flag
   - Save deploys updates via Metadata API

4. **Validation**:
   - Object selection required
   - Notion database selection required
   - Salesforce ID property name required
   - Field mappings optional (can be added later)
   - API connectivity verified with test button

## UI/UX Design

### Lightning Design System Components
- Lightning Layout for responsive design
- Lightning Datatable for object/field lists
- Lightning Combobox for selections
- Lightning Dual Listbox for field mapping
- Lightning Accordion for section organization
- Lightning Spinner for loading states
- Lightning Toast for notifications

### Layout Structure

#### Main View (Summary)
```
┌─────────────────────────────────────────┐
│         Notion Sync Admin               │
├─────────────────────────────────────────┤
│  Sync Configurations                    │
│  [New Sync Configuration]               │
├─────────────────────────────────────────┤
│  ┌─────┐  ┌─────┐  ┌──────┐           │
│  │  5  │  │  5  │  │  13  │           │
│  └─────┘  └─────┘  └──────┘           │
│  Objects  Active   Mappings            │
├─────────────────────────────────────────┤
│  Configured Objects Table               │
│  ┌─────────────────────────────────┐   │
│  │ Object | Database | Status | ... │   │
│  │ Account| 2125... | Active | Edit │   │
│  │ Contact| 2125... | Active | Edit │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

#### Configuration View
```
┌─────────────────────────────────────────┐
│  [←] Edit Account Configuration         │
├─────────────────────────────────────────┤
│  Basic Configuration                    │
│  ☑ Active                              │
│  Database: [Account DB] [Browse]       │
│  SF ID Property: [Salesforce_ID]       │
├─────────────────────────────────────────┤
│  Field Mappings                         │
│  [Field mapping component]              │
├─────────────────────────────────────────┤
│  Relationship Mappings                  │
│  [Relationship config component]        │
├─────────────────────────────────────────┤
│  [Cancel] [Test Connection] [Save]      │
└─────────────────────────────────────────┘
```

## Implementation Status

### Completed Features
1. ✅ Core Apex controllers with permission checking
2. ✅ Metadata service using Metadata API
3. ✅ Notion API integration with Named Credentials
4. ✅ Main container component with navigation
5. ✅ Summary view with configuration table
6. ✅ Object selection and database mapping
7. ✅ Field mapping component
8. ✅ Relationship configuration component
9. ✅ Database browser modal
10. ✅ Save functionality with validation
11. ✅ Test connection feature
12. ✅ Permission set and custom permission
13. ✅ Lightning App with tabs
14. ✅ Notion Sync Log list view
15. ✅ New configuration creation flow
16. ✅ Edit existing configuration flow
17. ✅ Unsaved changes tracking
18. ✅ Error handling and toast notifications

### Future Enhancements
1. Display Notion database names instead of IDs
2. Bulk field mapping operations
3. Configuration import/export
4. Field mapping templates
5. Sync preview functionality

## Security Considerations

1. **Permission Model**:
   - Custom Permission: `Notion_Sync_Admin` for granular control
   - Permission Set: `Notion_Sync_Administrator` bundles all required permissions
   - All Apex methods check permission using `FeatureManagement.checkPermission()`
   - UI shows clear "Access Denied" message for unauthorized users

2. **API Security**:
   - Named Credentials (`Notion_API`) for secure authentication
   - External Credentials with named principal
   - No API keys stored in code or custom settings
   - Rate limiting enforced by NotionRateLimiter

3. **Data Validation**:
   - Object API names validated against schema
   - Field API names checked for accessibility
   - Notion property names sanitized
   - Database IDs verified before use
   - Developer names sanitized for metadata

## Testing Strategy

1. **Unit Tests**:
   - `NotionAdminControllerTest`: 90%+ coverage
   - `NotionMetadataServiceTest`: Metadata operations
   - Permission checking validation
   - Error handling scenarios

2. **Integration Tests**:
   - End-to-end configuration flow
   - Real Notion API interactions
   - Metadata deployment verification

3. **UI Testing**:
   - Use Playwright MCP in Claude for UI testing
   - Get org URL: `sf org open --url-only -o <org-alias>`
   - Navigate and interact with components
   - Verify configuration creation and editing