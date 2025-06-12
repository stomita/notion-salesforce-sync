# CI/CD Setup Guide

This guide explains how to set up continuous integration for the Notion Salesforce Sync project.

## Prerequisites

- Salesforce org with Dev Hub enabled
- GitHub repository with Actions enabled
- Admin access to both Salesforce and GitHub

## Step 1: Enable Dev Hub

1. Log in to your Salesforce org (Production or Developer Edition)
2. Navigate to Setup → Development → Dev Hub
3. Enable Dev Hub
4. Enable "Unlocked Packages and Second-Generation Managed Packages"

## Step 2: Create Connected App for CI

1. In Setup, go to App Manager
2. Click "New Connected App"
3. Fill in the required fields:
   - Connected App Name: `GitHub Actions CI`
   - API Name: `GitHub_Actions_CI`
   - Contact Email: your email
4. Enable OAuth Settings:
   - Callback URL: `http://localhost:1717/OauthRedirect`
   - Selected OAuth Scopes:
     - Access and manage your data (api)
     - Perform requests on your behalf at any time (refresh_token, offline_access)
     - Provide access to your data via the Web (web)
5. Save and note the Consumer Key

## Step 3: Authenticate and Get SFDX Auth URL

1. Install Salesforce CLI if not already installed:
   ```bash
   npm install -g @salesforce/cli
   ```

2. Authenticate to your Dev Hub:
   ```bash
   sf org login web -a devhub -d
   ```

3. Get the SFDX auth URL:
   ```bash
   sf org display -o devhub --verbose --json
   ```

4. Look for the `sfdxAuthUrl` field in the JSON output. It will look like:
   ```
   force://PlatformCLI::5AxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxJ@your-domain.my.salesforce.com
   ```

## Step 4: Add GitHub Secret

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `DEVHUB_SFDX_AUTH_URL`
5. Value: Paste the SFDX auth URL from step 3
6. Click "Add secret"

## Step 5: Verify CI Setup

1. Create a pull request or push to main branch
2. Check the Actions tab in GitHub
3. The CI workflow should:
   - Create a scratch org
   - Deploy metadata
   - Run tests
   - Clean up

## Troubleshooting

### "Invalid grant" error
- The auth URL may have expired. Re-authenticate and update the secret.

### "No Dev Hub org found"
- Ensure Dev Hub is enabled in your org
- Verify the auth URL is from a Dev Hub-enabled org

### Scratch org creation fails
- Check your Dev Hub org has remaining scratch org capacity
- Verify the `config/project-scratch-def.json` file is valid

## CI Workflow Details

The CI workflow (`.github/workflows/ci.yml`) performs these steps:

1. **Install Salesforce CLI**: Installs the latest version
2. **Authenticate Dev Hub**: Uses the stored auth URL
3. **Create Scratch Org**: Creates a temporary org for testing
4. **Deploy Source**: Deploys all metadata from `force-app/`
5. **Run Tests**: Executes all Apex tests with code coverage
6. **Cleanup**: Deletes the scratch org (even on failure)

## Best Practices

1. **Protect main branch**: Require CI to pass before merging PRs
2. **Code Coverage**: Maintain at least 75% code coverage
3. **Regular Auth Refresh**: Update the auth URL periodically
4. **Monitor Usage**: Track scratch org consumption in Dev Hub

## Additional Configuration

### Custom Scratch Org Settings

Edit `config/project-scratch-def.json` to customize:
- Org edition
- Features
- Settings
- Duration (max 30 days, CI uses 1 day)

### Test Configuration

Create `force-app/main/default/testSuites/` for test suite configuration.

### Deployment Options

Modify the deploy command in CI workflow for specific needs:
```bash
# Deploy with tests
sf project deploy start --source-dir force-app --test-level RunLocalTests

# Deploy specific metadata types
sf project deploy start --metadata CustomObject,CustomField

# Validate only (no deployment)
sf project deploy validate --source-dir force-app
```