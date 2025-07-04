// Debug sync settings
System.debug('=== Debugging Sync Settings ===');

// Check sync settings
Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
System.debug('Sync Settings: ' + settings);
if (settings != null && settings.Id != null) {
    System.debug('- Id: ' + settings.Id);
    System.debug('- Enable_Sync_Logging__c: ' + settings.Enable_Sync_Logging__c);
    System.debug('- SetupOwnerId: ' + settings.SetupOwnerId);
} else {
    System.debug('No sync settings found - using defaults');
}

// Check if we can enable logging
if (settings == null || settings.Id == null) {
    System.debug('Creating new sync settings with logging enabled...');
    settings = new Notion_Sync_Settings__c(
        SetupOwnerId = UserInfo.getOrganizationId(),
        Enable_Sync_Logging__c = true
    );
    insert settings;
    System.debug('Created sync settings: ' + settings);
} else if (!settings.Enable_Sync_Logging__c) {
    System.debug('Enabling sync logging...');
    settings.Enable_Sync_Logging__c = true;
    update settings;
    System.debug('Updated sync settings: ' + settings);
}

// Verify the change
Notion_Sync_Settings__c verifySettings = Notion_Sync_Settings__c.getOrgDefaults();
System.debug('Verified settings - Enable_Sync_Logging__c: ' + verifySettings.Enable_Sync_Logging__c);