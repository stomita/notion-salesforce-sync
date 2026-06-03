# Notion Sync Admin UI Usage Guide

## Overview

The Notion Sync Admin UI is a Lightning Web Component that lets Salesforce administrators configure two features of the package without editing custom metadata directly:

- **Sync**: map Salesforce objects and fields to Notion databases.
- **Widgets**: configure Notion-database-backed widgets that can be embedded on Lightning pages.

Both features share the same Admin tab inside the **Notion Sync** app, split into sub-tabs.

> For end-to-end installation and first-time setup, see [SETUP_GUIDE.md](./SETUP_GUIDE.md). This document is the reference for what each control in the Admin UI does.

## Accessing the Admin UI

1. Click the App Launcher (9-dot grid icon).
2. Search for **Notion Sync** and open the app.
3. The app includes two top-level tabs:
   - **Notion Sync Admin** — main configuration interface (Sync / Widgets / Settings sub-tabs).
   - **Notion Sync Log** — recent sync attempts and their status.

To expose the same tabs in another app, edit it in Setup → **App Manager** → **Navigation Items** and add `Notion Sync Admin` and `Notion Sync Log`.

## Permission Sets

The package ships with three permission sets. Assign each to the users who need it.

| Permission Set | Label | Who needs it |
|---|---|---|
| `Notion_Sync_Admin` | Notion Sync Administrator | Admins configuring sync mappings and widgets. |
| `Notion_Integration_User` | Notion Integration User | Users whose record changes should trigger a sync via Flow. |
| `Notion_Widget_User` | Notion Widget User | End users who only view embedded widgets on Lightning pages. |

To assign:

1. Setup → **Permission Sets** → click the permission set name.
2. **Manage Assignments** → **Add Assignment** → pick users → **Assign**.

The Notion Sync Administrator set includes the custom permission `Notion_Sync_Admin`, access to the Notion External Credential, read access to all custom metadata types in this package, the user permissions required to deploy metadata (Customize Application, Modify Metadata), and read-only access to sync logs.

A user can hold more than one set — an admin who also edits records and triggers syncs typically needs both Administrator and Integration User.

## Admin UI Layout

The **Notion Sync Admin** tab is organized into three sub-tabs:

| Sub-tab | Purpose |
|---|---|
| **Sync** | Configure object-to-database mappings, field mappings, and relationships. |
| **Widgets** | Configure Notion-database-backed widgets that can be embedded on Lightning pages. |
| **Settings** | Test the Notion connection and view package-level options. |

The **Test Connection** action available at the top of the page works in any sub-tab and verifies Named Credential access plus database visibility.

## Sync Sub-tab

### Sync configuration list

The Sync sub-tab shows the existing sync configurations along with summary statistics: configured objects, active syncs, and total field mappings. Each row shows the Salesforce object, the linked Notion database, active state, and counts of field and relationship mappings, with an **Edit** action per row.

Click **New Sync Configuration** to create a new mapping.

### Creating a sync configuration

1. Click **New Sync Configuration**.
2. Pick a Salesforce object from the dropdown.
3. Toggle **Active** (enabled by default).
4. Click **Browse Databases** to pick the target Notion database. The database must have already been shared with the integration in Notion.
5. Pick the **Salesforce ID Property Name** — the Notion text property where the package will store the Salesforce record ID. The property must already exist on the Notion database, so add it first if it's missing.
6. Save. You can return later to add field mappings.

### Editing a sync configuration

Opening an existing configuration exposes three sections:

- **Basic Configuration** — toggle active state, change the Notion database, or change the Salesforce ID property name.
- **Field Mappings** — add mappings between Salesforce fields and Notion properties. The UI auto-suggests a compatible Notion property type per Salesforce field type (see [Auto Type Detection](#auto-type-detection)). Long text areas can be flagged as page body content instead of a property.
- **Relationship Mappings** — map Salesforce lookup or master-detail fields to Notion relation properties so parent–child structure is preserved on the Notion side.

Action buttons:

- **Cancel** — discard changes (with confirmation if there are unsaved edits).
- **Test Connection** — verify Notion API connectivity.
- **Save** — deploy the configuration as custom metadata.

### Database Browser modal

Clicking **Browse Databases** opens a modal listing every Notion database the integration can see. Search by database name or ID, and select one to populate the field. The modal also previews the database's properties and their types.

### Auto Type Detection

The UI suggests Notion property types from the chosen Salesforce field's type:

- STRING → rich_text
- EMAIL → email
- NUMBER / CURRENCY → number
- DATE / DATETIME → date
- BOOLEAN → checkbox
- PICKLIST → select
- REFERENCE → relation

You can override the suggestion if your Notion schema differs.

### Sync best practices

- Always run **Test Connection** before saving.
- Ensure at least one Salesforce field maps to a Notion **title** property — every page needs a title.
- Keep the Salesforce ID property pointing to a text property used only by the package.
- Start with a handful of fields, verify the sync end-to-end, then expand.

## Widgets Sub-tab

The Widgets sub-tab lets administrators create and manage widgets backed by `NotionWidget__mdt`. Each widget can be embedded into a Lightning page using the **Notion Widget** Lightning component in App Builder.

### Widget list

The list shows the developer name, target Notion database, optional context object, active status, and column/filter counts for every configured widget. Use **Edit** to open a widget, or the trash icon to delete it. Click **New Widget** to create one.

### Creating a widget

1. Click **New Widget**.
2. Enter a **Label** and **Developer Name**. The developer name is what you'll pick in Lightning App Builder.
3. **Notion Database** — click **Browse** and select the source database. The integration must have access to it (Notion `•••` → **Connections**).
4. **Context Object** *(optional)* — the Salesforce object the widget will live on (for record pages). Setting this lets the widget filter to pages related to that record.
5. **Context Relation Property** *(optional)* — the name of the Notion relation property on the target database that links to the context record's Notion page. When set, the widget behaves like a Salesforce related list:
   - rows are filtered to those whose relation includes the context Notion page;
   - clicking **New** opens a draft modal with that relation pre-populated.
6. **Default Sort Property** / **Default Sort Direction** *(optional)* — initial sort applied to the table.
7. **Page Size** — number of rows per page (default 25, max 100).
8. **Show New Button** — toggle the inline "New" button that creates Notion pages straight from the widget.
9. **Is Active** — only active widgets are selectable in App Builder.
10. **Columns** — pick which Notion properties to display, set their order, and choose their column widths. Reordering persists on save.
11. **Filters** — add fixed filters (Notion property comparisons) layered on top of the context filter, if any.
12. Save.

### Embedding a widget on a Lightning page

1. Open the target page in App Builder (record page, app page, or home page).
2. From the **Custom** component panel, drag **Notion Widget** onto the page.
3. With the widget selected, set the **Widget Configuration** property to the developer name of the widget you created. The field is a picklist sourced from active `NotionWidget__mdt` records.
4. Save and activate the page.

### Widget best practices

- Use a clear, descriptive developer name — admins editing Lightning pages see this in the picklist.
- For context-bound (related-list-style) widgets, make sure the parent record already has a synced Notion page; otherwise the widget has nothing to anchor against.
- If the picklist in App Builder is empty, confirm at least one widget has **Is Active = true**.

## Notion Navigation Component

In addition to the Widget, the package ships a **Notion Navigation** Lightning component that opens a record's Notion page directly. It supports record pages and Flow screens and is configured per-instance in App Builder / Flow Builder — not in the Admin UI.

Notable properties:

- **Card Title** / **Show Title** — wrap the action in a Lightning card with a Notion-branded header, or render the action bare.
- **Navigation Style** — `button` (labelled button) or `link` (inline text link). With `button` you can also hide the label to get an icon-only button.
- **Action Label** / **Show Action Label** / **Action Alignment** — text shown on the button or link, whether to show it, and its alignment in the card.
- **Sync Before Navigate** — default sync behavior for the main click: when on, the package syncs the record to Notion before opening; when off, it opens the existing page directly.
- **Show Sync Option** — when on (and the variant is the labelled button), a chevron dropdown is attached next to the main button. The dropdown offers the **opposite** sync mode (e.g., *Open in Notion (With Sync)* when the default is without-sync), so end users can pick the alternate behavior per click without first toggling state. Turn this off to lock in the designer default and hide the alternate entirely.

The split-button dropdown is only shown alongside the labelled-button variant; the link style and icon-only button render the main action alone.

## Notion Sync Log Tab

The **Notion Sync Log** tab shows recent sync attempts sorted newest first. Click any log row to see:

- Record ID and Object Type
- Operation Type (CREATE / UPDATE / DELETE)
- Status (Success / Failed / Retrying)
- Notion Page ID (on success)
- Error Message (on failure)
- Timestamp

The list view uses a formula field to enable descending date sorting.

## Permission Failures

If a user without `Notion_Sync_Admin` opens the Admin UI, they see an "Access Denied" screen instructing them to contact their administrator and request the **Notion Sync Administrator** permission set. The same check is enforced on every Apex method behind the UI using the `Notion_Sync_Admin` custom permission, so the UI cannot be bypassed.

## Troubleshooting

### Cannot see Notion databases

- Confirm the Named Credential is configured with a valid API token.
- Confirm the integration is connected to the database (Notion `•••` → **Connections**).
- Run **Test Connection** for a precise error.

### Metadata save fails

- The user needs Customize Application + Modify Metadata permissions (included in the Notion Sync Administrator set).
- Developer names must be unique — pick a different one if the save reports a conflict.
- Check the debug log if the error is unclear.

### Field mappings don't sync

- Notion property names are case- and whitespace-sensitive — verify they match exactly.
- Confirm Notion property types are compatible with the Salesforce field types.
- Confirm field-level security allows the integration user to read the field.

### Widget config picklist is empty in App Builder

- At least one widget must be **Is Active = true**.
- Re-saving the widget refreshes the picklist if the change isn't visible yet.

## Reference

- [SETUP_GUIDE.md](./SETUP_GUIDE.md) — end-to-end install and configuration walkthrough.
- [FLOW_CONFIGURATION.md](./FLOW_CONFIGURATION.md) — per-object Flow setup for triggering syncs.