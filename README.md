# Notion Salesforce Sync

A Salesforce-native integration tool that synchronizes Salesforce data to Notion databases in real-time.

## Features

- 🔄 Real-time synchronization via Flow triggers
- 🔗 Preserves Salesforce object relationships as Notion relations
- ⚡ Asynchronous processing using Platform Events
- 🛠️ Configuration-driven through Custom Metadata Types
- 🔒 Secure API integration with Named Credentials
- 📝 Support for Long Text Area fields as Notion page content
- ♻️ Automatic retry mechanism for failed syncs

## Architecture

This tool uses an event-driven architecture:

```
[Record Change] → [Flow] → [Platform Event] → [Event Subscriber] → [Queueable Apex] → [Notion API]
```

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
   - Copy the "Internal Integration Token" (starts with `secret_`)

   b. **Configure the External Credential in Salesforce:**
   - Go to Setup → Named Credentials → External Credentials
   - Find "Notion Credential"
   - Click on the principal "NotionIntegration"
   - Add Authentication Parameter:
     - Parameter Name: `SecretKey`
     - Value: Your Notion API token (the one that starts with `secret_`)
   - Save the configuration

   c. **Assign Permission Set:**
   - Go to Setup → Permission Sets
   - Find "Notion Integration User"
   - Click "Manage Assignments"
   - Assign to users who need to sync data to Notion

   d. **Grant integration access to your Notion databases:**
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
3. Add Create Records action to publish Platform Events

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
./scripts/run-integration-tests.sh
```

The script will prompt for any required configuration and run all integration tests.

### CI/CD Setup

This project uses GitHub Actions for continuous integration. The CI workflow automatically:

1. Creates a scratch org
2. Deploys all metadata
3. Runs Apex tests
4. Runs integration tests (if ALL secrets are configured)
5. Deletes the scratch org

#### Required Secrets

##### For Basic CI/CD:
- `DEVHUB_SFDX_AUTH_URL`: The Salesforce DX auth URL for your Dev Hub org

To get your Dev Hub auth URL:
```bash
sf org display -o your-devhub-alias --verbose --json
```
Look for the `sfdxAuthUrl` field in the output.

##### For Integration Testing:
**Important**: Either configure ALL of these secrets or NONE. The CI will fail if only some are configured.

- `NOTION_API_KEY`: Your Notion integration token
- `NOTION_WORKSPACE_ID`: Your Notion workspace ID
- `NOTION_DATABASE_ID_ACCOUNT`: Test database ID for Accounts
- `NOTION_DATABASE_ID_CONTACT`: Test database ID for Contacts
- `NOTION_DATABASE_ID_TEST_PARENT`: Test database ID for parent objects
- `NOTION_DATABASE_ID_TEST_CHILD`: Test database ID for child objects

To skip integration tests in CI, ensure NONE of these secrets are configured.

See the [CI Setup Guide](docs/CI_SETUP.md) for detailed instructions on setting up test databases and obtaining these values.

## CI/CD

### Continuous Integration

This project uses GitHub Actions for automated testing:

- **Automatic CI**: Runs on all pushes to `main` and on all pull requests
- **Manual CI Trigger**: Add the `run-ci` label to a PR to manually trigger CI
- **Direct Workflow Execution**: Use the Actions tab to run CI on any branch

The CI workflow:
1. Validates configuration (fails fast if integration test secrets are partially configured)
2. Creates a temporary Salesforce scratch org
3. Deploys all metadata
4. Runs all Apex tests with code coverage
5. Runs integration tests if all required secrets are configured
6. Automatically cleans up the scratch org

### Integration Testing in CI

When all integration test secrets are configured, the CI will automatically:
- Configure test metadata with your Notion database IDs
- Set up Named Credentials programmatically
- Run end-to-end sync tests against real Notion APIs
- Validate create, update, delete, and relationship operations

### PR Labels

- `run-ci`: Manually triggers the CI workflow on a pull request

## License

MIT