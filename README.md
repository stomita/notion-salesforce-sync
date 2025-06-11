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

1. Create a Record-Triggered Flow for each object you want to sync
2. Configure triggers for Insert, Update, and Delete
3. Add Create Records action to publish Platform Events

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines and architecture documentation.

## License

MIT