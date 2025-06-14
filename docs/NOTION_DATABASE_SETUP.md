# Notion Database Setup Quick Reference

This is a quick reference for setting up Notion databases for integration testing.

## Step-by-Step Database Creation

### 1. Create Four Databases in Notion

Create new database pages in your Notion workspace:
1. Account Test Database
2. Contact Test Database  
3. Test Parent Database
4. Test Child Database

### 2. Configure Properties for Each Database

#### Account Test Database
1. Click the `+` next to Properties
2. Add these properties:
   - Property name: `Name` → Type: `Title`
   - Property name: `salesforce_id` → Type: `Text`

#### Contact Test Database
1. Add these properties:
   - Property name: `Name` → Type: `Title`
   - Property name: `Email` → Type: `Email`
   - Property name: `Account` → Type: `Relation` → Select "Account Test Database"
   - Property name: `salesforce_id` → Type: `Text`

#### Test Parent Database
1. Add these properties:
   - Property name: `Name` → Type: `Title`
   - Property name: `Status` → Type: `Select` → Add options: Active, Inactive, In Progress
   - Property name: `Amount` → Type: `Number`
   - Property name: `Active` → Type: `Checkbox`
   - Property name: `salesforce_id` → Type: `Text`

#### Test Child Database
1. Add these properties:
   - Property name: `Name` → Type: `Title`
   - Property name: `Quantity` → Type: `Number`
   - Property name: `Due Date` → Type: `Date`
   - Property name: `Test Parent` → Type: `Relation` → Select "Test Parent Database"
   - Property name: `Account` → Type: `Relation` → Select "Account Test Database"
   - Property name: `salesforce_id` → Type: `Text`

### 3. Grant Integration Access

For each database:
1. Click `Share` button (top right)
2. Click `Invite`
3. Search for your integration name
4. Select your integration
5. Ensure it has edit access

### 4. Get Database IDs

For each database:
1. Click `Share` → `Copy link`
2. The URL format is: `https://www.notion.so/{workspace}/{database-id}?v={view-id}`
3. Copy the database-id portion (32 characters)

### 5. Use Database IDs

Set these as environment variables or GitHub secrets:
- `NOTION_DATABASE_ID_ACCOUNT` = Account database ID
- `NOTION_DATABASE_ID_CONTACT` = Contact database ID
- `NOTION_DATABASE_ID_TEST_PARENT` = Test Parent database ID
- `NOTION_DATABASE_ID_TEST_CHILD` = Test Child database ID

## Common Issues

### "Property not found" errors
- Property names are case-sensitive
- Must match exactly as shown above
- Don't use "Title" - use "Name" for title properties

### "Relation not found" errors
- Create databases in order (Account first, then Contact, etc.)
- Ensure relation properties point to correct databases

### Sync failures
- Verify `salesforce_id` property exists in ALL databases
- Check integration has edit access to all databases
- Ensure all required properties are created

## Body Content Fields

These Salesforce fields are synced to the Notion page body (not properties):
- Account: `Description` field
- Test Parent: `Description__c` field  
- Test Child: `Details__c` field

These will appear as rich text content within the Notion page itself.