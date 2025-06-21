# 2GP Managed Package Guide

This guide explains how to build and manage the Notion Salesforce Sync as a Second Generation Package (2GP).

## Prerequisites

1. **DevHub with Namespace**: You need a Developer Edition org with:
   - Dev Hub enabled
   - Second-Generation Managed Packages enabled
   - A registered namespace (e.g., `notionsync`)

2. **Salesforce CLI**: Latest version installed

3. **Package Already Created**: The package "Notion Salesforce Sync" is already created with ID: `0HogL0000000FVJSA2`

## Building a Package Version

### Quick Start

```bash
# Build a new package version
./scripts/build-package.sh --namespace notionsync --devhub notion-sync-devhub

# Build with extended wait time
./scripts/build-package.sh --namespace notionsync --devhub notion-sync-devhub --wait 30
```

### Manual Process

If you prefer to run commands manually:

1. **Prepare the project** (adds namespace temporarily):
   ```bash
   ./scripts/prepare-package.sh --namespace notionsync --devhub notion-sync-devhub
   ```

2. **Create package version**:
   ```bash
   sf package version create \
     --package "Notion Salesforce Sync" \
     --target-dev-hub notion-sync-devhub \
     --wait 20 \
     --installation-key-bypass \
     --code-coverage
   ```

3. **Restore original sfdx-project.json**:
   ```bash
   mv sfdx-project.json.backup sfdx-project.json
   ```

## Package Management Commands

### List Package Versions
```bash
sf package version list \
  --package "Notion Salesforce Sync" \
  --target-dev-hub notion-sync-devhub
```

### View Package Details
```bash
sf package version report \
  --package <version-id> \
  --target-dev-hub notion-sync-devhub
```

### Install in Scratch Org (Testing)
```bash
# Create a scratch org for testing
sf org create scratch -f config/project-scratch-def.json -a test-org -d -y 7

# Install the package
sf package install \
  --package <version-id> \
  --target-org test-org \
  --wait 10
```

### Promote to Released
```bash
sf package version promote \
  --package <version-id> \
  --target-dev-hub notion-sync-devhub
```

## CI/CD Considerations

The CI pipeline uses a different DevHub without the namespace, so:

1. **Development**: The main branch should NOT include namespace in `sfdx-project.json`
2. **Package Building**: Use the build script to inject namespace only during package creation
3. **Testing**: CI tests run without namespace in scratch orgs

## Package Installation Instructions

After installing the package, customers need to:

1. **Configure External Credential**:
   - Go to Setup → Named Credentials → External Credentials
   - Find "Notion Credential"
   - Create a new Principal with their Notion API key

2. **Assign Permissions**:
   - Assign the `Notion_Integration_User` permission set to users who need API access
   - Assign the `Notion_Sync_Admin` permission set to administrators

3. **Configure Sync Settings**:
   - Use the Notion Sync Admin app to configure object and field mappings
   - Set up Flows to trigger synchronization

## Troubleshooting

### Namespace Not Found Error
If you get an error about namespace not being found:
- Ensure you're using the correct DevHub with the namespace registered
- Verify namespace is correctly spelled in the command

### Code Coverage Issues
If package creation fails due to code coverage:
- Run `sf apex test run --code-coverage` to check coverage
- Ensure all Apex classes have proper test coverage (75% minimum)

### Package Version Creation Timeout
If creation times out:
- Use `--wait 30` or higher for larger packages
- Check the job status with `sf package version create report`