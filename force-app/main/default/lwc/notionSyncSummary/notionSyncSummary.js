import { LightningElement, track } from 'lwc';
import getAllSyncConfigurations from '@salesforce/apex/NotionAdminController.getAllSyncConfigurations';

export default class NotionSyncSummary extends LightningElement {
    @track configurations = [];
    @track isLoading = false;

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
                isActive: config.isActive,
                fieldCount: config.fieldMappings ? config.fieldMappings.length : 0,
                relationshipCount: config.relationshipMappings ? config.relationshipMappings.length : 0
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

    handleEdit(event) {
        const objectApiName = event.target.dataset.object;
        // Dispatch event to parent to switch to Object Configuration tab with selected object
        this.dispatchEvent(new CustomEvent('editconfiguration', {
            detail: { objectApiName }
        }));
    }
}