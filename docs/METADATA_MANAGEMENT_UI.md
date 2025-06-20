# Metadata Management UI Enhancement

## Overview

The Notion Sync Summary component has been enhanced to provide direct links to Salesforce Setup for managing Custom Metadata records. This provides users with an alternative to programmatic deletion via Apex.

## New Features

### 1. Manage in Setup Button
- Added a global "Manage in Setup" button in the configuration list header
- Opens the Custom Metadata Types page in Salesforce Setup
- Allows users to browse all Custom Metadata Type definitions

### 2. Individual Record Management
- Added a "Manage" button for each sync configuration in the Actions column
- Opens the specific Custom Metadata record in Setup for viewing/editing
- Provides direct access to the record detail page

### 3. Enhanced Delete Modal
- Updated the delete confirmation modal to mention the alternative approach
- Informs users they can manage records directly in Setup instead of using the Delete button

## Implementation Details

### Component Changes

#### notionSyncSummary.html
- Added "Manage in Setup" button in the header section
- Added "Manage" button in the actions column for each configuration
- Updated delete confirmation modal with alternative message

#### notionSyncSummary.js
- Added `handleManageInSetup()` method to navigate to Custom Metadata Types page
- Added `handleManageRecord()` method to navigate to specific record pages
- Updated configuration mapping to include `objectMetadataId`

### Navigation URLs

1. **Custom Metadata Types Home**: `/lightning/setup/CustomMetadata/home`
2. **Specific Record**: `/lightning/setup/CustomMetadataRecordDetail/page?address=%2F{recordId}`

These URLs work in both Lightning Experience and Classic (with automatic redirection).

## Benefits

1. **Direct Access**: Users can quickly access Setup without navigating through menus
2. **Alternative to Deletion**: Provides a standard UI option instead of programmatic soft-delete
3. **Full Control**: Users can manage all aspects of Custom Metadata records in Setup
4. **Transparency**: Shows users where the configuration data is actually stored

## Usage

1. Click "Manage in Setup" to view all Custom Metadata Types
2. Click "Manage" on a specific row to view/edit that configuration record
3. In Setup, users can:
   - View all field values
   - Edit records directly
   - Delete records (hard delete)
   - Clone records
   - View related records

## Notes

- The programmatic delete functionality (soft delete) is still available
- Managing in Setup provides hard delete capability vs. the soft delete in the UI
- Changes made in Setup may take a few moments to reflect in the UI due to metadata deployment timing