English | [日本語](./README_ja.md)

# Notion Salesforce Sync

A Salesforce-native integration tool that synchronizes Salesforce data to Notion databases in real-time.

## Features

- 🔄 Real-time synchronization via Flow triggers
- 🔗 Preserves Salesforce object relationships as Notion relations
- 📊 Embeddable **Notion Widget** Lightning component that surfaces Notion database rows on record, app, and home pages — with optional related-list behavior
- 🧭 **Notion Navigation** component that opens a record's Notion page from Salesforce
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

The full installation and configuration walkthrough for administrators — package install, Notion integration, credentials, Sync mappings, Widget configuration, Flow setup, and verification — lives in **[docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)**.

Quick links by topic:

- **Install + first-time setup**: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
- **Admin UI reference (Sync and Widget Designer)**: [docs/ADMIN_UI_USAGE.md](docs/ADMIN_UI_USAGE.md)
- **Flow trigger configuration**: [docs/FLOW_CONFIGURATION.md](docs/FLOW_CONFIGURATION.md)
- **Bulk / large data behavior**: [docs/LARGE_DATA_SYNC.md](docs/LARGE_DATA_SYNC.md)
- **Developer scratch org setup**: [docs/SCRATCH_ORG_SETUP.md](docs/SCRATCH_ORG_SETUP.md)
- **Packaging (2GP)**: [docs/PACKAGING.md](docs/PACKAGING.md)

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

This error occurs when the user cannot access the Named Credential.

**Solution:**
1. Verify the Named Principal has your API key configured (Setup → Named Credentials → External Credentials → Notion Credential → NotionIntegration)
2. Ensure you've assigned the "Notion Integration User" permission set to your user
3. The permission set must be assigned to any user who will trigger syncs
4. Run the diagnostic script to verify configuration:
   ```bash
   sf apex run --file scripts/apex/verify-named-credential.apex
   ```

#### "Unauthorized endpoint" Error

This indicates the Named Principal credential is not configured.

**Solution:**
1. The Named Principal should already exist — add your API key as described in [SETUP_GUIDE.md Step 3.1](docs/SETUP_GUIDE.md#31-register-your-notion-api-key)
2. Ensure the `SecretKey` parameter contains your valid Notion API token
3. Verify the "Notion Integration User" permission set is assigned to your user

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