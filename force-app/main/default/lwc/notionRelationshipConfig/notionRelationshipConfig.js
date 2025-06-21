import { LightningElement, api, track } from 'lwc';
import getObjectFields from '@salesforce/apex/NotionAdminController.getObjectFields';
import getDatabaseSchema from '@salesforce/apex/NotionAdminController.getDatabaseSchema';
import getConfiguredSyncObjects from '@salesforce/apex/NotionAdminController.getConfiguredSyncObjects';

export default class NotionRelationshipConfig extends LightningElement {
    @api objectApiName;
    @api notionDatabaseId;
    @api existingMappings = [];

    @track relationshipMappings = [];
    @track relationshipFields = [];
    @track notionRelationProperties = [];
    @track configuredSyncObjects = [];
    @track isLoading = false;
    @track showAddMapping = false;
    @track newMapping = {
        salesforceRelationshipField: '',
        notionRelationPropertyName: '',
        parentObject: '',
        salesforceFieldLabel: '',
        parentObjectLabel: ''
    };

    connectedCallback() {
        this.initializeMappings();
        if (this.objectApiName && this.notionDatabaseId) {
            this.loadRelationshipData();
        }
    }

    initializeMappings() {
        if (this.existingMappings && this.existingMappings.length > 0) {
            this.relationshipMappings = this.existingMappings.map(mapping => {
                // Enhance mapping with field labels if not present
                const field = this.relationshipFields.find(f => f.apiName === mapping.salesforceRelationshipField);
                const parentObject = mapping.parentObject || '';
                
                return {
                    ...mapping,
                    salesforceFieldLabel: mapping.salesforceFieldLabel || (field ? field.label : mapping.salesforceRelationshipField),
                    parentObjectLabel: mapping.parentObjectLabel || parentObject,
                    parentObject: parentObject
                };
            });
        }
    }

    async loadRelationshipData() {
        this.isLoading = true;
        try {
            // Load fields, database schema, and configured sync objects
            const [fields, schema, syncObjects] = await Promise.all([
                getObjectFields({ objectApiName: this.objectApiName }),
                getDatabaseSchema({ databaseId: this.notionDatabaseId }),
                getConfiguredSyncObjects()
            ]);

            // Store configured sync objects
            this.configuredSyncObjects = syncObjects;

            // Filter for relationship fields
            this.relationshipFields = fields.filter(field => field.isRelationship);
            
            // Filter for relation properties in Notion
            this.notionRelationProperties = schema.properties.filter(prop => prop.type === 'relation');
            
            // Re-initialize mappings with field labels
            this.initializeMappings();
        } catch (error) {
            console.error('Error loading relationship data:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleShowAddMapping() {
        this.showAddMapping = true;
        this.newMapping = {
            salesforceRelationshipField: '',
            notionRelationPropertyName: '',
            parentObject: '',
            salesforceFieldLabel: '',
            parentObjectLabel: ''
        };
    }

    handleCancelAddMapping() {
        this.showAddMapping = false;
        this.resetNewMapping();
    }

    handleFieldSelection(event) {
        const fieldApiName = event.detail.value;
        const field = this.relationshipFields.find(f => f.apiName === fieldApiName);
        
        if (field) {
            // Get the referenced Salesforce object
            const referencedObject = field.referenceTo && field.referenceTo.length > 0 ? field.referenceTo[0] : '';
            
            // Find the configured sync object that matches this Salesforce object
            const syncObject = this.configuredSyncObjects.find(obj => obj.objectApiName === referencedObject);
            
            if (syncObject) {
                this.newMapping = {
                    ...this.newMapping,
                    salesforceRelationshipField: fieldApiName,
                    salesforceFieldLabel: field.label,
                    parentObject: syncObject.developerName,
                    parentObjectLabel: referencedObject
                };
            } else {
                // If no sync object is configured for this relationship, clear the mapping
                this.newMapping = {
                    ...this.newMapping,
                    salesforceRelationshipField: fieldApiName,
                    salesforceFieldLabel: field.label,
                    parentObject: '',
                    parentObjectLabel: ''
                };
            }
        }
    }

    handlePropertySelection(event) {
        this.newMapping = {
            ...this.newMapping,
            notionRelationPropertyName: event.detail.value
        };
    }

    handleSaveNewMapping() {
        if (this.isNewMappingValid) {
            this.relationshipMappings = [...this.relationshipMappings, {...this.newMapping}];
            this.notifyMappingChange();
            this.showAddMapping = false;
            this.resetNewMapping();
        }
    }

    resetNewMapping() {
        this.newMapping = {
            salesforceRelationshipField: '',
            notionRelationPropertyName: '',
            parentObject: '',
            salesforceFieldLabel: '',
            parentObjectLabel: ''
        };
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

    get availableRelationshipFields() {
        // Filter out already mapped fields
        const mappedFields = this.relationshipMappings.map(m => m.salesforceRelationshipField);
        
        // Only show relationship fields that point to configured sync objects
        return this.relationshipFields
            .filter(field => {
                if (mappedFields.includes(field.apiName)) {
                    return false;
                }
                // Check if the referenced object has a sync configuration
                const referencedObject = field.referenceTo && field.referenceTo.length > 0 ? field.referenceTo[0] : '';
                return this.configuredSyncObjects.some(obj => obj.objectApiName === referencedObject);
            })
            .map(field => {
                const parentObject = field.referenceTo && field.referenceTo.length > 0 ? field.referenceTo[0] : '';
                return {
                    label: `${field.label} (${field.apiName}) → ${parentObject}`,
                    value: field.apiName
                };
            });
    }

    get availableRelationProperties() {
        return this.notionRelationProperties.map(prop => ({
            label: prop.name,
            value: prop.name
        }));
    }

    get isNewMappingValid() {
        return this.newMapping.salesforceRelationshipField && 
               this.newMapping.notionRelationPropertyName;
    }

    get canAddMoreRelationships() {
        return this.availableRelationshipFields.length > 0;
    }

    get disableAddButton() {
        return !this.canAddMoreRelationships || this.showAddMapping;
    }

    get isNotionPropertyDisabled() {
        return !this.newMapping.salesforceRelationshipField;
    }

    get isSaveDisabled() {
        return !this.isNewMappingValid;
    }

    get hasUnmappedRelationshipFields() {
        // Check if there are relationship fields that can't be mapped due to missing sync configs
        const mappedFields = this.relationshipMappings.map(m => m.salesforceRelationshipField);
        
        return this.relationshipFields.some(field => {
            if (mappedFields.includes(field.apiName)) {
                return false;
            }
            // Check if the referenced object doesn't have a sync configuration
            const referencedObject = field.referenceTo && field.referenceTo.length > 0 ? field.referenceTo[0] : '';
            return !this.configuredSyncObjects.some(obj => obj.objectApiName === referencedObject);
        });
    }
}