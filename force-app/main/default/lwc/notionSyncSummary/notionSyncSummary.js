import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllSyncConfigurations from '@salesforce/apex/NotionAdminController.getAllSyncConfigurations';
import deleteSyncConfiguration from '@salesforce/apex/NotionAdminController.deleteSyncConfiguration';

export default class NotionSyncSummary extends LightningElement {
    @track configurations = [];
    @track isLoading = false;
    @track showDeleteConfirmation = false;
    @track deleteTargetObject = null;
    @track deleteTargetName = null;

    connectedCallback() {
        this.loadConfigurations();
    }

    async loadConfigurations() {
        this.isLoading = true;
        try {
            const configs = await getAllSyncConfigurations();
            
            // Transform the configurations for display
            this.configurations = configs.map(config => ({
                objectName: this.getObjectLabel(config.objectApiName),
                objectApiName: config.objectApiName,
                notionDatabaseName: config.notionDatabaseName || config.notionDatabaseId,
                notionDatabaseId: config.notionDatabaseId,
                isActive: config.isActive,
                fieldCount: config.fieldMappings ? config.fieldMappings.length : 0,
                relationshipCount: config.relationshipMappings ? config.relationshipMappings.length : 0,
                metadataId: config.objectMetadataId
            }));
        } catch (error) {
            console.error('Error loading configurations:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    getObjectLabel(apiName) {
        // For now, just return the API name with better formatting
        // Remove __c suffix for custom objects
        if (apiName.endsWith('__c')) {
            return apiName.replace(/__c$/, '').replace(/_/g, ' ');
        }
        // Add spaces before capital letters for standard objects
        return apiName.replace(/([A-Z])/g, ' $1').trim();
    }

    get hasConfigurations() {
        return this.configurations.length > 0;
    }

    get activeConfigCount() {
        return this.configurations.filter(c => c.isActive).length;
    }

    get totalFieldMappings() {
        return this.configurations.reduce((sum, config) => sum + config.fieldCount, 0);
    }

    handleActionSelect(event) {
        const action = event.detail.value;
        const objectApiName = event.target.dataset.object;
        const objectName = event.target.dataset.name;
        
        if (action === 'edit') {
            // Dispatch event to parent to switch to Object Configuration tab with selected object
            this.dispatchEvent(new CustomEvent('editconfiguration', {
                detail: { objectApiName }
            }));
        } else if (action === 'delete') {
            this.deleteTargetObject = objectApiName;
            this.deleteTargetName = objectName;
            this.showDeleteConfirmation = true;
        }
    }

    async confirmDelete() {
        this.showDeleteConfirmation = false;
        this.isLoading = true;
        
        try {
            const result = await deleteSyncConfiguration({ objectApiName: this.deleteTargetObject });
            
            if (result.success) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: result.message,
                        variant: 'success'
                    })
                );
                
                // Reload configurations after a delay (metadata deployments take time)
                setTimeout(() => {
                    this.loadConfigurations();
                }, 15000); // 15 seconds
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: result.message,
                        variant: 'error'
                    })
                );
            }
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to delete configuration: ' + error.body.message,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
            this.deleteTargetObject = null;
            this.deleteTargetName = null;
        }
    }

    cancelDelete() {
        this.showDeleteConfirmation = false;
        this.deleteTargetObject = null;
        this.deleteTargetName = null;
    }

    
    handleRefresh() {
        this.loadConfigurations();
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Configuration list refreshed',
                variant: 'success'
            })
        );
    }
    
    handleManageInSetup() {
        // Navigate to Custom Metadata Types in Setup
        // Using relative URL to work in both Classic and Lightning Experience
        const setupUrl = '/lightning/setup/CustomMetadata/home';
        window.open(setupUrl, '_blank');
    }
}