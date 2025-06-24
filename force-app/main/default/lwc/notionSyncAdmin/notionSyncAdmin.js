import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSalesforceObjects from '@salesforce/apex/NotionAdminController.getSalesforceObjects';
import getSyncConfiguration from '@salesforce/apex/NotionAdminController.getSyncConfiguration';
import saveSyncConfiguration from '@salesforce/apex/NotionAdminController.saveSyncConfiguration';
import testConnection from '@salesforce/apex/NotionAdminController.testConnection';
import getSystemSettings from '@salesforce/apex/NotionAdminController.getSystemSettings';
import saveSystemSettings from '@salesforce/apex/NotionAdminController.saveSystemSettings';
import getDatabaseSchema from '@salesforce/apex/NotionAdminController.getDatabaseSchema';

export default class NotionSyncAdmin extends LightningElement {
    @track selectedObject = null;
    @track salesforceObjects = [];
    @track currentConfiguration = null;
    @track isLoading = false;
    @track hasUnsavedChanges = false;
    @track hasPermission = true;
    @track permissionError = '';
    @track isNewConfiguration = false;
    @track databaseProperties = [];
    
    // System settings
    @track enableSyncLogging = false;

    // View state
    @track showDatabaseBrowser = false;
    @track showFieldMapping = false;
    @track showRelationshipConfig = false;
    @track activeTab = 'configurations';

    connectedCallback() {
        this.checkPermissionAndLoadData();
    }

    get isActive() {
        return this.currentConfiguration ? this.currentConfiguration.isActive : false;
    }

    async checkPermissionAndLoadData() {
        try {
            await this.loadSalesforceObjects();
            await this.loadSystemSettings();
        } catch (error) {
            // Check if it's a permission error
            if (error.body && error.body.message && error.body.message.includes('do not have permission')) {
                this.hasPermission = false;
                this.permissionError = error.body.message;
            } else {
                // Re-throw if it's not a permission error
                throw error;
            }
        }
    }
    
    async loadSystemSettings() {
        try {
            const settings = await getSystemSettings();
            this.enableSyncLogging = settings.enableSyncLogging || false;
        } catch (error) {
            console.error('Failed to load system settings:', error);
            // Don't show error toast as this is not critical
        }
    }

    @wire(getSalesforceObjects)
    wiredObjects({ error, data }) {
        if (data) {
            this.salesforceObjects = data;
        } else if (error) {
            this.showError('Failed to load Salesforce objects', error);
        }
    }

    async loadSalesforceObjects() {
        try {
            this.isLoading = true;
            const objects = await getSalesforceObjects();
            this.salesforceObjects = objects;
        } catch (error) {
            this.showError('Failed to load Salesforce objects', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleObjectSelection(event) {
        const objectApiName = event.detail.value;
        if (objectApiName && objectApiName !== 'new') {
            this.selectedObject = objectApiName;
            // Don't reset isNewConfiguration here - preserve it
            await this.loadObjectConfiguration(objectApiName);
        }
    }

    async loadObjectConfiguration(objectApiName) {
        try {
            this.isLoading = true;
            this.selectedObject = objectApiName;
            
            // If this is a new configuration, don't try to load existing config
            if (this.isNewConfiguration) {
                this.currentConfiguration = this.createNewConfiguration(objectApiName);
            } else {
                const config = await getSyncConfiguration({ objectApiName });
                this.currentConfiguration = config || this.createNewConfiguration(objectApiName);
            }
            
            // If we have a database ID, load its properties
            if (this.currentConfiguration.notionDatabaseId) {
                await this.loadDatabaseProperties(this.currentConfiguration.notionDatabaseId);
            }
            
            this.showFieldMapping = true;
        } catch (error) {
            console.error('Error in loadObjectConfiguration:', error);
            this.showError('Failed to load object configuration', error);
        } finally {
            this.isLoading = false;
        }
    }

    createNewConfiguration(objectApiName) {
        return {
            objectApiName: objectApiName,
            notionDatabaseId: '',
            notionDatabaseName: '',
            isActive: true,
            salesforceIdPropertyName: '',
            fieldMappings: [],
            relationshipMappings: []
        };
    }
    
    // Helper method to update configuration while preserving objectApiName
    updateConfiguration(updates) {
        
        // Create new configuration object with updates
        this.currentConfiguration = {
            ...this.currentConfiguration,
            ...updates,
        };
        
        this.hasUnsavedChanges = true;
    }

    async handleDatabaseSelection(event) {
        const { databaseId, databaseName } = event.detail;
        this.updateConfiguration({
            notionDatabaseId: databaseId,
            notionDatabaseName: databaseName
        });
        this.showDatabaseBrowser = false;
        
        // Fetch database properties for Salesforce ID property selection
        await this.loadDatabaseProperties(databaseId);
        
        this.showSuccess(`Selected database: ${databaseName}`);
    }

    handleFieldMappingChange(event) {
        // Update only the field mappings, don't recreate the entire object
        this.updateConfiguration({
            fieldMappings: event.detail.mappings
        });
    }

    handleRelationshipChange(event) {
        // Update only the relationship mappings, don't recreate the entire object
        this.updateConfiguration({
            relationshipMappings: event.detail.mappings
        });
    }

    handleActiveToggle(event) {
        this.updateConfiguration({
            isActive: event.target.checked
        });
    }

    handleSalesforceIdPropertyChange(event) {
        this.updateConfiguration({
            salesforceIdPropertyName: event.detail.value
        });
    }
    
    async loadDatabaseProperties(databaseId) {
        try {
            this.isLoading = true;
            const schema = await getDatabaseSchema({ databaseId });
            this.databaseProperties = schema.properties || [];
            
            // Check if current salesforceIdPropertyName is still valid
            const validPropertyNames = this.databaseProperties.map(prop => prop.name);
            if (this.currentConfiguration.salesforceIdPropertyName && 
                !validPropertyNames.includes(this.currentConfiguration.salesforceIdPropertyName)) {
                // Reset if the current property doesn't exist in the new database
                this.updateConfiguration({
                    salesforceIdPropertyName: ''
                });
            }
        } catch (error) {
            console.error('Failed to load database properties:', error);
            this.showError('Failed to load database properties', error);
            this.databaseProperties = [];
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave() {
        try {
            this.isLoading = true;
            
            // Debug logging
            console.log('[SAVE] Starting save operation...');
            console.log('[SAVE] selectedObject:', this.selectedObject);
            console.log('[SAVE] currentConfiguration.objectApiName:', this.currentConfiguration?.objectApiName);
            
            // Validate configuration
            if (!this.validateConfiguration()) {
                return;
            }

            const result = await saveSyncConfiguration({ configJson: JSON.stringify(this.currentConfiguration) });
            
            if (result.success) {
                this.showSuccess(result.message);
                this.hasUnsavedChanges = false;
                
                // Reload configuration to get updated metadata IDs
                await this.loadObjectConfiguration(this.selectedObject);
            } else {
                this.showError(result.message, result.errors.join(', '));
            }
        } catch (error) {
            console.error('[SAVE] Error:', error);
            this.showError('Failed to save configuration', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleTestConnection() {
        if (!this.currentConfiguration.notionDatabaseId) {
            this.showError('Please select a Notion database first');
            return;
        }

        try {
            this.isLoading = true;
            const result = await testConnection({ databaseId: this.currentConfiguration.notionDatabaseId });
            
            if (result.success) {
                this.showSuccess(`Connection successful! Database: ${result.databaseName}`);
            } else {
                this.showError('Connection failed', result.message);
            }
        } catch (error) {
            this.showError('Connection test failed', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        if (this.hasUnsavedChanges) {
            if (confirm('You have unsaved changes. Are you sure you want to cancel?')) {
                this.resetState();
            }
        } else {
            this.resetState();
        }
    }

    handleShowDatabaseBrowser() {
        this.showDatabaseBrowser = true;
    }

    handleCloseDatabaseBrowser() {
        this.showDatabaseBrowser = false;
    }

    handleShowRelationships() {
        this.showRelationshipConfig = true;
    }

    handleCloseRelationships() {
        this.showRelationshipConfig = false;
    }

    handleBack() {
        if (this.hasUnsavedChanges) {
            if (confirm('You have unsaved changes. Are you sure you want to go back?')) {
                this.resetState();
            }
        } else {
            this.resetState();
        }
    }

    handleNewConfiguration() {
        this.isNewConfiguration = true;
        this.selectedObject = 'new';
        this.currentConfiguration = null;
        this.hasUnsavedChanges = false;
    }

    validateConfiguration() {
        if (!this.currentConfiguration) {
            this.showError('No configuration loaded');
            return false;
        }
        
        if (!this.currentConfiguration.objectApiName) {
            this.showError('Please select an object');
            return false;
        }

        if (!this.currentConfiguration.notionDatabaseId) {
            this.showError('Please select a Notion database');
            return false;
        }

        if (!this.currentConfiguration.salesforceIdPropertyName) {
            this.showError('Please select a Notion property to store Salesforce IDs');
            return false;
        }

        // Temporarily skip field mapping validation for new configurations
        // Field mappings can be added after initial setup
        /* if (this.currentConfiguration.fieldMappings.length === 0) {
            this.showError('Please map at least one field');
            return false;
        } */

        return true;
    }

    resetState() {
        this.selectedObject = null;
        this.currentConfiguration = null;
        this.hasUnsavedChanges = false;
        this.showFieldMapping = false;
        this.showRelationshipConfig = false;
        this.isNewConfiguration = false;
    }

    showSuccess(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: message,
                variant: 'success'
            })
        );
    }

    showError(title, detail) {
        const message = detail ? 
            (typeof detail === 'object' ? JSON.stringify(detail) : detail) : 
            title;
            
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'error',
                mode: 'sticky'
            })
        );
    }

    // Computed properties
    get objectOptions() {
        return this.salesforceObjects.map(obj => ({
            label: `${obj.label} (${obj.apiName})`,
            value: obj.apiName
        }));
    }

    get isConfigurationLoaded() {
        return this.currentConfiguration !== null;
    }

    get saveDisabled() {
        return !this.hasUnsavedChanges || this.isLoading;
    }

    get notionDatabaseDisplay() {
        if (this.currentConfiguration) {
            if (this.currentConfiguration.notionDatabaseName && this.currentConfiguration.notionDatabaseId) {
                // Show both name and ID in parentheses
                return `${this.currentConfiguration.notionDatabaseName} (${this.currentConfiguration.notionDatabaseId})`;
            } else if (this.currentConfiguration.notionDatabaseId) {
                // Fallback to just ID if name is not available
                return this.currentConfiguration.notionDatabaseId;
            }
        }
        return '';
    }

    get configurationTitle() {
        if (this.isNewConfiguration) {
            return 'New Sync Configuration';
        } else if (this.currentConfiguration) {
            const obj = this.salesforceObjects.find(o => o.apiName === this.selectedObject);
            return `Edit ${obj ? obj.label : this.selectedObject} Configuration`;
        }
        return 'Configuration';
    }
    
    get selectedObjectLabel() {
        if (this.selectedObject && this.salesforceObjects) {
            const obj = this.salesforceObjects.find(o => o.apiName === this.selectedObject);
            return obj ? obj.label : this.selectedObject;
        }
        return '';
    }
    
    get salesforceIdPropertyOptions() {
        if (!this.databaseProperties || this.databaseProperties.length === 0) {
            return [];
        }
        
        // Filter properties that can store text (Salesforce IDs are text)
        const textPropertyTypes = ['title', 'rich_text', 'url', 'email', 'phone_number'];
        
        return this.databaseProperties
            .filter(prop => textPropertyTypes.includes(prop.type))
            .map(prop => ({
                label: `${prop.name} (${prop.type})`,
                value: prop.name
            }));
    }
    
    get isSalesforceIdPropertyDisabled() {
        return !this.currentConfiguration || !this.currentConfiguration.notionDatabaseId;
    }

    handleEditConfiguration(event) {
        const { objectApiName } = event.detail;
        
        console.log('[EDIT] Starting edit for object:', objectApiName);
        
        this.selectedObject = objectApiName;
        this.isNewConfiguration = false;
        this.hasUnsavedChanges = false;
        this.showFieldMapping = false;
        this.showRelationshipConfig = false;
        
        // Force a fresh load of the configuration
        this.currentConfiguration = null;
        
        // Switch to configurations tab to show the edit form
        this.activeTab = 'configurations';
        
        // Load the configuration
        this.loadObjectConfiguration(objectApiName);
    }
    
    async handleEnableSyncLoggingChange(event) {
        const isEnabled = event.target.checked;
        this.isLoading = true;
        
        try {
            // Create a plain object to avoid Proxy issues
            const plainSettings = {
                enableSyncLogging: isEnabled
            };
            
            const result = await saveSystemSettings({ settingsJson: JSON.stringify(plainSettings) });
            
            if (result && result.success) {
                this.enableSyncLogging = isEnabled;
                this.showSuccess(
                    isEnabled ? 'Sync logging enabled' : 'Sync logging disabled',
                    isEnabled 
                        ? 'All sync operations will now be logged to the Notion Sync Log object.' 
                        : 'Sync operations will no longer be logged.'
                );
            } else {
                // Revert the checkbox
                this.enableSyncLogging = !isEnabled;
                const errorMessage = result && result.message ? result.message : 'Unknown error occurred';
                this.showError('Failed to update system settings', errorMessage);
            }
        } catch (error) {
            // Revert the checkbox
            this.enableSyncLogging = !isEnabled;
            console.error('Error in handleEnableSyncLoggingChange:', error);
            this.showError('Failed to update system settings', error);
        } finally {
            this.isLoading = false;
        }
    }
}