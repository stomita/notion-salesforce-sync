import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSalesforceObjects from '@salesforce/apex/NotionAdminController.getSalesforceObjects';
import getSyncConfiguration from '@salesforce/apex/NotionAdminController.getSyncConfiguration';
import saveSyncConfiguration from '@salesforce/apex/NotionAdminController.saveSyncConfiguration';
import testConnection from '@salesforce/apex/NotionAdminController.testConnection';

export default class NotionSyncAdmin extends LightningElement {
    @track selectedObject = null;
    @track salesforceObjects = [];
    @track currentConfiguration = null;
    @track isLoading = false;
    @track hasUnsavedChanges = false;
    @track hasPermission = true;
    @track permissionError = '';
    @track isNewConfiguration = false;

    // View state
    @track showDatabaseBrowser = false;
    @track showFieldMapping = false;
    @track showRelationshipConfig = false;

    connectedCallback() {
        this.checkPermissionAndLoadData();
    }

    async checkPermissionAndLoadData() {
        try {
            await this.loadSalesforceObjects();
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
            
            this.showFieldMapping = true;
        } catch (error) {
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
            salesforceIdPropertyName: 'Salesforce_ID',
            fieldMappings: [],
            relationshipMappings: []
        };
    }

    handleDatabaseSelection(event) {
        const { databaseId, databaseName } = event.detail;
        this.currentConfiguration.notionDatabaseId = databaseId;
        this.currentConfiguration.notionDatabaseName = databaseName;
        this.hasUnsavedChanges = true;
        this.showDatabaseBrowser = false;
        
        this.showSuccess(`Selected database: ${databaseName}`);
    }

    handleFieldMappingChange(event) {
        this.currentConfiguration.fieldMappings = event.detail.mappings;
        this.hasUnsavedChanges = true;
    }

    handleRelationshipChange(event) {
        this.currentConfiguration.relationshipMappings = event.detail.mappings;
        this.hasUnsavedChanges = true;
    }

    handleActiveToggle(event) {
        this.currentConfiguration.isActive = event.target.checked;
        this.hasUnsavedChanges = true;
    }

    handleSalesforceIdPropertyChange(event) {
        this.currentConfiguration.salesforceIdPropertyName = event.target.value;
        this.hasUnsavedChanges = true;
    }

    async handleSave() {
        try {
            this.isLoading = true;
            
            // Validate configuration
            if (!this.validateConfiguration()) {
                return;
            }

            const result = await saveSyncConfiguration({ config: this.currentConfiguration });
            
            if (result.success) {
                this.showSuccess(result.message);
                this.hasUnsavedChanges = false;
                
                // Reload configuration to get updated metadata IDs
                await this.loadObjectConfiguration(this.selectedObject);
            } else {
                this.showError(result.message, result.errors.join(', '));
            }
        } catch (error) {
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
        if (!this.currentConfiguration.objectApiName) {
            this.showError('Please select an object');
            return false;
        }

        if (!this.currentConfiguration.notionDatabaseId) {
            this.showError('Please select a Notion database');
            return false;
        }

        if (!this.currentConfiguration.salesforceIdPropertyName) {
            this.showError('Salesforce ID property name is required');
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
        if (this.currentConfiguration && this.currentConfiguration.notionDatabaseName) {
            return this.currentConfiguration.notionDatabaseName;
        } else if (this.currentConfiguration && this.currentConfiguration.notionDatabaseId) {
            return this.currentConfiguration.notionDatabaseId;
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

    handleEditConfiguration(event) {
        const { objectApiName } = event.detail;
        // Set the selected object
        this.selectedObject = objectApiName;
        this.isNewConfiguration = false;
        // Load the configuration
        this.loadObjectConfiguration(objectApiName);
    }
}