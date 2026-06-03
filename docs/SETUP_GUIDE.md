# Setup Guide

This guide walks a Salesforce administrator through installing the **Notion Salesforce Sync** package and configuring it for synchronization, the Notion Widget, or both.

The shared steps (1–3) are required for any use of the package. After Step 3, jump to the path you need:

- **Path A — Configure Sync**: push Salesforce records to Notion databases via Flow triggers.
- **Path B — Configure a Widget**: embed a Notion database view inside a Lightning page.

---

## Prerequisites

- A Salesforce org you have **System Administrator** access to (Production, Sandbox, or Developer Edition).
- A Notion workspace where you can create an **integration** and grant it access to databases.
- A modern browser. CLI access is optional — every step below has a UI alternative.

---

## Step 1 — Install the package

The package is distributed as a managed 2GP under the `notionsync` namespace.

### Install URL (latest released version)

Open the following URL while logged into your target org. Choose **Install for Admins Only** unless you have a specific reason to expand access.

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000GJhpQAG
```

For a Sandbox, replace `login.salesforce.com` with `test.salesforce.com`.

### CLI alternative

```bash
sf package install \
  --package 04tgL000000GJhpQAG \
  --target-org <your-org-alias> \
  --wait 20
```

After installation, you should see the **Notion Sync** app available in the App Launcher.

---

## Step 2 — Prepare Notion

### 2.1 Create an internal integration

1. Sign in to Notion as a workspace owner and open <https://www.notion.so/my-integrations>.
2. Click **New integration**.
3. Set a name (for example, `Salesforce Sync`) and pick the workspace you want to connect.
4. Submit and copy the **Internal Integration Token** (starts with `ntn_` or `secret_`). Treat this like a password — you'll register it in Salesforce in Step 3.

### 2.2 Grant the integration access to your databases

For **every** Notion database the package will read or write:

1. Open the database page in Notion.
2. Click the `•••` menu at the top right → **Connections** → **Add connections**.
3. Select your integration and click **Confirm**.

### 2.3 Add a Salesforce ID property (Sync only)

If you plan to use Path A (Sync), each Notion database that will receive synced records needs a property to store the Salesforce record ID. The package uses this property to detect existing pages and prevent duplicates.

1. Open the target Notion database.
2. Add a new property (recommended name: `Salesforce ID`, type: **Text**).
3. Repeat for every database you'll sync to.

You'll select this property by name when you configure the sync in Step 6.

> Widget-only setups (Path B) don't require this — the widget reads any Notion database your integration can access.

---

## Step 3 — Configure Salesforce credentials and permissions

### 3.1 Register your Notion API key

The package ships with an **External Credential** named `Notion Credential` and a **Named Principal** named `NotionIntegration`. You only need to attach your API token.

1. Setup → **Named Credentials** → **External Credentials** tab → **Notion Credential**.
2. Under **Principals**, click the row for `NotionIntegration`.
3. Under **Authentication Parameters**, click **New**.
4. Add:
   - **Name**: `SecretKey`
   - **Value**: the Notion integration token from Step 2.1
5. Save.

### 3.2 Assign permission sets

The package includes three permission sets. Assign each to the users who need it.

| Permission Set | Label | Who needs it |
|---|---|---|
| `Notion_Sync_Admin` | Notion Sync Administrator | Admins who configure mappings, widgets, and credentials via the Admin UI. |
| `Notion_Integration_User` | Notion Integration User | Any user whose record changes should trigger a sync (i.e., users whose actions fire the Flow). |
| `Notion_Widget_User` | Notion Widget User | End users who only view embedded Notion widgets on Lightning pages. |

To assign:

1. Setup → **Permission Sets** → click the permission set name.
2. **Manage Assignments** → **Add Assignment** → select users → **Assign**.

> A user can have multiple permission sets. An admin who also triggers syncs needs both Sync Administrator and Integration User.

### 3.3 Verify the connection

1. Open the App Launcher → **Notion Sync**.
2. On the **Notion Sync Admin** tab, click **Test Connection** (top-right).
3. You should see a success message listing accessible databases. If not, see [Troubleshooting](#troubleshooting).

At this point, the package is installed and authenticated. Continue to **Path A**, **Path B**, or both.

---

## Path A — Configure Sync

Goal: have a Salesforce record automatically create, update, or delete a corresponding Notion page.

### A.1 Create a sync configuration

1. Open the **Notion Sync** app → **Notion Sync Admin** tab.
2. Switch to the **Sync** sub-tab.
3. Click **New Sync Configuration**.
4. Pick the Salesforce object (e.g., `Account`).
5. Click **Browse Databases** and select the Notion database prepared in Step 2.3.
6. For **Salesforce ID Property Name**, pick the property you added in Step 2.3 (e.g., `Salesforce ID`).
7. Save.

### A.2 Map fields

In the saved configuration:

1. Open the **Field Mappings** section.
2. For each Salesforce field, add a mapping to a Notion property. The UI auto-suggests a compatible Notion property type.
3. Make sure at least one mapping targets a Notion **Title** property.
4. (Optional) Map a Long Text Area to the page body using the **Body Content** flag.
5. (Optional) Configure **Relationship Mappings** to translate lookups/master-details into Notion relations between databases.
6. Save. The UI deploys the change as custom metadata.

For details on the Admin UI, see [Admin UI Usage](./ADMIN_UI_USAGE.md).

### A.3 Create the Flow trigger

The package includes template flows you can copy per object. The full procedure is in [Flow Configuration](./FLOW_CONFIGURATION.md). Summary:

1. Copy `NotionSync_Template_CreateUpdate.flow-meta.xml` and `NotionSync_Template_Delete.flow-meta.xml` and rename them for your object.
2. Replace `[ObjectApiName]` placeholders with your object's API name (e.g., `Account`).
3. Deploy the flows and **activate** both in Setup → **Flows**.

### A.4 Verify the sync

1. Create a new record of your synced object (e.g., a new Account).
2. Open the matching Notion database — the page should appear within a few seconds.
3. Update the record, then delete it, and confirm Notion reflects each change.
4. If something is missing, open **Notion Sync Logs** (tab in the Notion Sync app) and check the **Status** and **Error Message** columns.

---

## Path B — Configure a Widget

Goal: embed a list of Notion pages on a Salesforce record, app, or home page. The widget can also act as a related list: filtered to pages that relate to the current Salesforce record's Notion counterpart.

### B.1 Create a widget configuration

1. Open the **Notion Sync** app → **Notion Sync Admin** tab.
2. Switch to the **Widgets** sub-tab.
3. Click **New Widget**.
4. Fill in:
   - **Label** and **Developer Name** — the developer name is what you'll select in App Builder.
   - **Notion Database** — click **Browse** and pick the source database.
   - **Context Object** (optional) — set this if the widget will live on a record page and you want it to filter by the related record's Notion page.
   - **Context Relation Property** (optional) — name of the Notion relation property used to link to the context record's Notion page. When set, the widget behaves like a related list: rows are filtered, and the **New** button creates pages with this relation pre-filled.
   - **Default Sort**, **Page Size**, **Show New Button** — optional behavior tweaks.
5. **Columns** — pick which Notion properties to display and order them.
6. **Filters** — add optional fixed filters on top of the context filter.
7. Save.

### B.2 Place the widget on a Lightning page

1. Open the Lightning page where the widget should appear (App Builder → **Edit Page** from the record page, app page, or home page).
2. From the **Custom** components panel on the left, drag **Notion Widget** onto the canvas.
3. With the widget selected, set **Widget Configuration** to the developer name from B.1 (the field is a picklist).
4. Save and activate the page.

### B.3 Verify the widget

1. Open the Lightning page where you placed the widget.
2. Confirm the widget renders rows from your Notion database. If the widget is context-bound (B.1), only rows that link back to the current record's Notion page should appear.
3. If a **New** button is shown, clicking it should open a draft modal that pre-fills the relation property.

> **Tip — also for navigation**: the package includes a **Notion Navigation** component (record-page or Flow screen) that opens a record's Notion page directly. The labelled-button variant renders as a split-button with a dropdown that lets the end user pick the opposite sync mode (e.g., *Open in Notion (With Sync)*) on each click. Drag it from the same App Builder panel and configure its label, alignment, default sync behavior, and whether the alternate action is offered in the right pane.

---

## Troubleshooting

### "We couldn't access the credential"
The current user can't read the Named Credential.
- Confirm the `SecretKey` parameter is set on the `NotionIntegration` principal (Step 3.1).
- Assign the **Notion Integration User** permission set to the user triggering the sync (or the **Notion Sync Administrator** set for admin actions).

### "Unauthorized endpoint" or 401 from Notion
The token is missing, wrong, or revoked.
- Re-paste the token from <https://www.notion.so/my-integrations>.
- Confirm the integration still has access to the database (`•••` → **Connections** in Notion).

### Sync doesn't run
- In Setup → **Flows**, confirm both the CreateUpdate and Delete flows for the object are **Active**.
- Check **Notion Sync Logs** for failures — the Error Message column tells you whether it failed at validation, mapping, or the Notion API.
- Confirm the user who edited the record has the **Notion Integration User** permission set.

### Widget shows "Access Denied" or an empty list
- Assign **Notion Widget User** (or **Notion Sync Administrator**) to the viewer.
- Confirm the Notion database is shared with the integration (Step 2.2).
- For context-bound widgets, the current record must already have a synced Notion page so the widget has something to filter against.

### The widget picklist in App Builder is empty
- At least one widget configuration must have **Is Active = true**.
- The admin set may need to be re-saved if the metadata was just deployed.

---

## Reference

- [Admin UI Usage](./ADMIN_UI_USAGE.md) — full walkthrough of the Sync configuration UI and Widget Designer.
- [Flow Configuration](./FLOW_CONFIGURATION.md) — template flows and per-object setup.
- [Large Data Sync](./LARGE_DATA_SYNC.md) — how the queueable architecture handles bulk loads.
- [Integration Testing](./INTEGRATION_TESTING.md) — running the end-to-end Notion test suite.
