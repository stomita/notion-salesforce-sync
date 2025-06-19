import { LightningElement, api, track } from 'lwc';
import getObjectFields from '@salesforce/apex/NotionAdminController.getObjectFields';
import getDatabaseSchema from '@salesforce/apex/NotionAdminController.getDatabaseSchema';

export default class NotionRelationshipConfig extends LightningElement {
    @api objectApiName;
    @api notionDatabaseId;
    @api existingMappings = [];

    @track relationshipMappings = [];
    @track relationshipFields = [];
    @track notionRelationProperties = [];
    @track isLoading = false;

    connectedCallback() {
        this.initializeMappings();
        if (this.objectApiName && this.notionDatabaseId) {
            this.loadRelationshipData();
        }
    }

    initializeMappings() {
        if (this.existingMappings && this.existingMappings.length > 0) {
            this.relationshipMappings = [...this.existingMappings];
        }
    }

    async loadRelationshipData() {
        this.isLoading = true;
        try {
            // Load fields and database schema
            const [fields, schema] = await Promise.all([
                getObjectFields({ objectApiName: this.objectApiName }),
                getDatabaseSchema({ databaseId: this.notionDatabaseId })
            ]);

            // Filter for relationship fields
            this.relationshipFields = fields.filter(field => field.isRelationship);
            
            // Filter for relation properties in Notion
            this.notionRelationProperties = schema.properties.filter(prop => prop.type === 'relation');
        } catch (error) {
            console.error('Error loading relationship data:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleAddRelationship(event) {
        // Implementation for adding relationships
        const newMapping = {
            salesforceRelationshipField: '',
            notionRelationPropertyName: '',
            isParent: true
        };
        
        this.relationshipMappings = [...this.relationshipMappings, newMapping];
        this.notifyMappingChange();
    }

    handleRemoveRelationship(event) {
        const index = parseInt(event.target.dataset.index);
        this.relationshipMappings = this.relationshipMappings.filter((_, i) => i !== index);
        this.notifyMappingChange();
    }

    notifyMappingChange() {
        this.dispatchEvent(new CustomEvent('mappingchange', {
            detail: { mappings: this.relationshipMappings }
        }));
    }

    get hasRelationshipFields() {
        return this.relationshipFields.length > 0;
    }

    get hasRelationProperties() {
        return this.notionRelationProperties.length > 0;
    }

    get canConfigureRelationships() {
        return this.hasRelationshipFields && this.hasRelationProperties;
    }
}