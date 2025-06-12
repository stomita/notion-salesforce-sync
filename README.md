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
sfdx force:source:deploy -p force-app/
```

3. Configure Named Credentials for Notion API access

4. Set up Custom Metadata records for your sync configuration

## Configuration

### Custom Metadata Types

- **NotionSyncObject__mdt**: Define which Salesforce objects to sync
- **NotionSyncField__mdt**: Map Salesforce fields to Notion properties
- **NotionDatabase__mdt**: Store Notion database configurations
- **NotionRelation__mdt**: Define relationship mappings

### Flow Setup

#### Using Flow Templates

This repository includes Flow templates to help you set up synchronization quickly:

- **NotionSync_Template_CreateUpdate.flow-meta.xml**: Template for create/update operations
- **NotionSync_Template_Delete.flow-meta.xml**: Template for delete operations  
- **NotionSync_Account_CreateUpdate.flow-meta.xml**: Example Flow for Account object

#### Setting up a New Object Sync

1. **Clone a template Flow**:
   - For create/update sync: Clone `NotionSync_Template_CreateUpdate`
   - For delete sync: Clone `NotionSync_Template_Delete`

2. **Update the object reference**:
   - Change the `<object>` element from `Account` to your desired object API name
   - Example: `<object>Contact</object>` for Contact records

3. **Update the Object_Type__c value**:
   - In the `Object_Type__c` field assignment, change the value from `Account` to your object API name
   - Example: `<stringValue>Contact</stringValue>`

4. **Activate the Flow**:
   - Change `<status>Draft</status>` to `<status>Active</status>`

#### Manual Flow Setup

If you prefer to create Flows manually:

1. Create a Record-Triggered Flow for each object you want to sync
2. Configure triggers for Insert, Update, and Delete
3. Add Create Records action to publish Platform Events

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines and architecture documentation.

### CI/CD Setup

This project uses GitHub Actions for continuous integration. The CI workflow automatically:

1. Creates a scratch org
2. Deploys all metadata
3. Runs Apex tests
4. Deletes the scratch org

#### Required Secrets

To enable CI/CD, add the following secret to your GitHub repository:

- `DEVHUB_SFDX_AUTH_URL`: The Salesforce DX auth URL for your Dev Hub org

To get your Dev Hub auth URL:
```bash
sf org display -o your-devhub-alias --verbose --json
```
Look for the `sfdxAuthUrl` field in the output.

## License

MIT