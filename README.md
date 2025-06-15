# Notion Salesforce Sync

A Salesforce-native integration tool that synchronizes Salesforce data to Notion databases in real-time.

## Features

- 🔄 Real-time synchronization via Flow triggers
- 🔗 Preserves Salesforce object relationships as Notion relations
- ⚡ Asynchronous processing using Queueable Apex
- 🛠️ Configuration-driven through Custom Metadata Types
- 🔒 Secure API integration with Named Credentials
- 📝 Support for Long Text Area fields as Notion page content
- ♻️ Automatic retry mechanism for failed syncs

## Architecture

This tool uses a synchronous Flow-based architecture:

```
[Record Change] → [Flow] → [Invocable Apex] → [Queueable/Future] → [Notion API]
```

The synchronous approach maintains user context throughout the process, ensuring Named Credential access works properly.

## Setup

### Prerequisites

1. Salesforce org with API access
2. Notion workspace with API access
3. Salesforce CLI (sfdx) installed

### Installation

1. Clone the repository:
```bash
git clone https://github.com/stomita/notion-salesforce-sync.git
cd notion-salesforce-sync
```

2. Deploy to your Salesforce org:
```bash
sf project deploy start --source-dir force-app/main
```

Note: Use `sf` (Salesforce CLI v2) instead of `sfdx` for all commands.

3. Configure Named Credentials for Notion API access:

   a. **Get your Notion API token:**
   - Go to [https://www.notion.so/my-integrations](https://www.notion.so/my-integrations)
   - Click "New integration"
   - Give it a name (e.g., "Salesforce Sync")
   - Select the workspace you want to connect
   - Click "Submit"
   - Copy the "Internal Integration Token" (starts with `ntn_` or `secret_`)

   b. **Configure Named Principal Credential in Salesforce:**
   
   The Named Credential and Principal are already deployed with the metadata. You only need to set your API key:
   
   - Go to Setup → Security → Named Credentials
   - Click on "External Credentials" tab
   - Find "Notion Credential" (already deployed)
   - Click on "NotionIntegration" principal (already created)
   - Under Authentication Parameters, click "New"
   - Add Custom Header:
     - Parameter Name: `SecretKey`
     - Parameter Value: Your Notion API token (the one you copied from step a)
   - Save

   c. **Enable System-Wide Access (Important!):**
   - While still in the External Credential page
   - Check "Available for All Users" to enable access for system processes
   - This allows the Invocable Apex (when called from Flows) to access the credential
   - Without this setting, the sync will fail with credential access errors

   d. **Assign Permission Set (Required):**
   - Go to Setup → Permission Sets
   - Find "Notion Integration User" (already deployed)
   - Click "Manage Assignments" → "Add Assignment"
   - Select users who will trigger syncs (typically your user or integration user)
   - Save
   - Note: Even with "Available for All Users" enabled, permission set assignment is required for proper access

   e. **Grant integration access to your Notion databases:**
   - In Notion, go to each database you want to sync
   - Click the "..." menu → "Add connections"
   - Select your integration and click "Confirm"

4. Set up Custom Metadata records for your sync configuration

## Configuration

### Custom Metadata Types

- **NotionSyncObject__mdt**: Define which Salesforce objects to sync
- **NotionSyncField__mdt**: Map Salesforce fields to Notion properties
- **NotionDatabase__mdt**: Store Notion database configurations
- **NotionRelation__mdt**: Define relationship mappings

### Flow Setup

1. Create a Record-Triggered Flow for each object you want to sync
2. Configure triggers for Insert, Update, and Delete
3. Add Action to call the NotionSyncInvocable Apex method
4. Map the required parameters: recordId, objectType, and operationType

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines and architecture documentation.

## Testing

### Unit Tests

Run unit tests to verify core functionality:

```bash
sf apex test run --code-coverage --result-format human
```

### Integration Tests

For comprehensive end-to-end testing with real Notion API calls, see the [Integration Testing Guide](docs/INTEGRATION_TESTING.md).

Quick start:
```bash
./scripts/execute-integration-tests.sh
```

For full setup including metadata configuration and credential setup:
```bash
./scripts/run-integration-tests.sh
```

### CI/CD Setup

This project uses GitHub Actions for continuous integration. The CI workflow automatically:

1. Creates a scratch org
2. Deploys all metadata
3. Runs Apex tests
4. Runs integration tests
5. Deletes the scratch org

#### Required Configuration

##### GitHub Secrets (Sensitive Data):
- `DEVHUB_SFDX_AUTH_URL`: The Salesforce DX auth URL for your Dev Hub org
- `NOTION_API_KEY`: Your Notion integration token

To get your Dev Hub auth URL:
```bash
sf org display -o your-devhub-alias --verbose --json
```
Look for the `sfdxAuthUrl` field in the output.

##### GitHub Variables (Non-Sensitive Configuration):
**Important**: ALL of these must be configured for CI to run successfully.

Configure these as repository variables (Settings → Secrets and variables → Actions → Variables):
- `NOTION_WORKSPACE_ID`: Your Notion workspace ID
- `NOTION_TEST_ACCOUNT_DB`: Test database ID for Accounts
- `NOTION_TEST_CONTACT_DB`: Test database ID for Contacts
- `NOTION_TEST_PARENT_DB`: Test database ID for parent objects
- `NOTION_TEST_CHILD_DB`: Test database ID for child objects

The CI workflow validates all configuration at the start and fails if any are missing.

See the [CI Setup Guide](docs/CI_SETUP.md) for detailed instructions on setting up test databases and obtaining these values.

## CI/CD

### Continuous Integration

This project uses GitHub Actions for automated testing:

- **Automatic CI**: Runs on all pushes to `main` and on all pull requests
- **Manual CI Trigger**: Add the `run-ci` label to a PR to manually trigger CI
- **Direct Workflow Execution**: Use the Actions tab to run CI on any branch

The CI workflow:
1. Validates all required secrets (fails fast if any are missing)
2. Creates a temporary Salesforce scratch org
3. Deploys all metadata
4. Runs all Apex tests with code coverage
5. Runs integration tests against Notion APIs
6. Automatically cleans up the scratch org

### Integration Testing in CI

The CI workflow automatically:
- Validates all required Notion secrets are configured (fails fast if any are missing)
- Configures test metadata with your Notion database IDs
- Sets up Named Credentials programmatically
- Runs end-to-end sync tests against real Notion APIs
- Validates create, update, delete, and relationship operations

### PR Labels

- `run-ci`: Manually triggers the CI workflow on a pull request

## Troubleshooting

### Common Issues

#### "We couldn't access the credential" Error

This error occurs when the Invocable Apex method cannot access the Named Credential.

**Solution:**
1. Verify the Named Principal has your API key configured (Setup → Named Credentials → External Credentials → Notion Credential → NotionIntegration)
2. **Important**: Check "Available for All Users" is enabled in the External Credential settings
3. Ensure you've assigned the "Notion Integration User" permission set to your user
4. Run the diagnostic script to verify configuration:
   ```bash
   sf apex run --file scripts/apex/verify-named-credential.apex
   ```

#### "Unauthorized endpoint" Error

This indicates the Named Principal credential is not configured.

**Solution:**
1. The Named Principal should already exist - just add your API key as described in section 3.b
2. Ensure the `SecretKey` parameter contains your valid Notion API token
3. Verify "Available for All Users" is checked and permission set is assigned

#### Sync Not Triggering

If records aren't syncing to Notion:

1. Check Flow activation:
   ```bash
   sf apex run --file scripts/apex/diagnose-sync-issue.apex
   ```

2. Verify the sync logs for errors:
   - Go to App Launcher → Notion Sync Logs
   - Check the Error Message field for failed syncs

3. Ensure your Notion databases have the required properties configured

#### API Token Issues

If you see 401 errors in sync logs:
- Verify your Notion API token is correct
- Ensure the integration has access to your Notion databases
- Check that the token hasn't expired or been revoked

## License

MIT