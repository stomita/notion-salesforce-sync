# Integration Test Environment

This directory contains test objects, metadata, and flows for integration testing of the Notion-Salesforce sync functionality.

## Structure

- **objects/**: Custom test objects with various field types and relationships
  - `Test_Parent_Object__c`: Parent object with various field types
  - `Test_Child_Object__c`: Child object with Master-Detail and Lookup relationships
  
- **customMetadata/**: Test configurations for Notion sync
  - NotionDatabase records
  - NotionSyncObject records
  - NotionSyncField records
  - NotionRelation records
  
- **flows/**: Automated flows for test objects
  - Create/Update flows
  - Delete flows
  
- **permissionsets/**: Permission set for test object access

## Setup Instructions

1. **Deploy Integration Components**
   ```bash
   sf project deploy start --source-dir force-app/integration
   ```

2. **Create Notion Databases**
   - Create 4 databases in your Notion workspace:
     - Account Test Database
     - Test Parent Database
     - Test Child Database
     - Contact Test Database
   - Each database must have a property named `salesforce_id` (type: Text)
   - Add other properties as needed to match the field mappings

3. **Update Custom Metadata**
   - Replace `REPLACE_WITH_NOTION_DATABASE_ID_*` with actual Notion database IDs
   - Replace `REPLACE_WITH_NOTION_WORKSPACE_ID` with your workspace ID
   - You can find database IDs in the Notion page URL

4. **Assign Permission Set**
   ```apex
   // Run in Anonymous Apex
   PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Notion_Integration_Test_User'];
   PermissionSetAssignment psa = new PermissionSetAssignment(
       AssigneeId = UserInfo.getUserId(),
       PermissionSetId = ps.Id
   );
   insert psa;
   ```

5. **Run Test Scripts**
   ```bash
   # Create test data
   sf apex run -f scripts/integration/setup-test-data.apex
   
   # Run integration test
   sf apex run -f scripts/integration/run-integration-test.apex
   
   # Clean up when done
   sf apex run -f scripts/integration/cleanup-test-data.apex
   ```

## Test Coverage

The integration environment tests:
- Standard object sync (Account, Contact)
- Custom object sync
- Various field types (Text, Long Text, Number, Currency, Date, Checkbox, Picklist)
- Master-Detail relationships
- Lookup relationships
- Body content mapping (Long Text Area → Notion page body)
- Create, Update, and Delete operations
- Relationship preservation in Notion

## Notes

- This directory is not part of the main package (default: false in sfdx-project.json)
- All test objects and metadata are prefixed with "Test" to avoid conflicts
- Flows are set to Active status for immediate testing
- Remember to update Notion database IDs before testing