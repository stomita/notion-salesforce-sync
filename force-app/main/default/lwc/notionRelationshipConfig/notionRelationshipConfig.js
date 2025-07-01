import { LightningElement, api, track } from 'lwc';
import getObjectFields from '@salesforce/apex/NotionAdminController.getObjectFields';
import getDatabaseSchema from '@salesforce/apex/NotionAdminController.getDatabaseSchema';
import getConfiguredSyncObjects from '@salesforce/apex/NotionAdminController.getConfiguredSyncObjects';

export default class NotionRelationshipConfig extends LightningElement {
    _objectApiName;
    _notionDatabaseId;
    @api existingMappings = [];

    @track relationshipMappings = [];
    @track relationshipFields = [];
    @track notionRelationProperties = [];
    @track configuredSyncObjects = [];
    @track isLoading = false;
    @track showAddMapping = false;
    @track availableTargetObjects = []; // For polymorphic fields
    @track newMapping = {
        salesforceRelationshipField: '',
        notionRelationPropertyName: '',
        parentObject: '',
        salesforceFieldLabel: '',
        parentObjectLabel: '',
        parentSyncObjectName: ''
    };

    connectedCallback() {
        this.initializeMappings();
        if (this.objectApiName && this.notionDatabaseId) {
            this.loadRelationshipData();
        }
    }

    @api
    set objectApiName(value) {
        this._objectApiName = value;
        if (this._objectApiName && this._notionDatabaseId) {
            this.loadRelationshipData();
        }
    }

    get objectApiName() {
        return this._objectApiName;
    }

    @api
    set notionDatabaseId(value) {
        this._notionDatabaseId = value;
        if (this._objectApiName && this._notionDatabaseId) {
            this.loadRelationshipData();
        }
    }

    get notionDatabaseId() {
        return this._notionDatabaseId;
    }

    initializeMappings() {
        if (this.existingMappings && this.existingMappings.length > 0) {
            this.relationshipMappings = this.existingMappings.map(mapping => {
                // Enhance mapping with field labels if not present
                const field = this.relationshipFields.find(f => f.apiName === mapping.salesforceRelationshipField);
                const parentObject = mapping.parentObject || '';
                
                // Find the sync object configuration name
                const syncObject = this.configuredSyncObjects.find(obj => obj.developerName === parentObject);
                const parentSyncObjectName = syncObject ? syncObject.objectApiName : parentObject;
                
                return {
                    ...mapping,
                    salesforceFieldLabel: mapping.salesforceFieldLabel || (field ? field.label : mapping.salesforceRelationshipField),
                    parentObjectLabel: mapping.parentObjectLabel || parentObject,
                    parentObject: parentObject,
                    parentSyncObjectName: parentSyncObjectName
                };
            });
        }
    }

    async loadRelationshipData() {
        // Prevent duplicate loading
        if (this.isLoading) {
            return;
        }
        
        this.isLoading = true;
        try {
            // Load fields, database schema, and configured sync objects
            const [fields, schema, syncObjects] = await Promise.all([
                getObjectFields({ objectApiName: this._objectApiName }),
                getDatabaseSchema({ databaseId: this._notionDatabaseId }),
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
            parentObjectLabel: '',
            parentSyncObjectName: ''
        };
    }

    handleCancelAddMapping() {
        this.showAddMapping = false;
        this.resetNewMapping();
    }

    handleFieldSelection(event) {
        const fieldApiName = event.detail.value;
        const field = this.relationshipFields.find(f => f.apiName === fieldApiName);
        
        if (field && field.referenceTo && field.referenceTo.length > 0) {
            // Find all configured sync objects for the referenced objects
            const configuredTargets = [];
            
            for (const refObject of field.referenceTo) {
                const syncObject = this.configuredSyncObjects.find(obj => obj.objectApiName === refObject);
                if (syncObject) {
                    configuredTargets.push({
                        label: refObject,
                        value: syncObject.developerName,
                        objectApiName: syncObject.objectApiName
                    });
                }
            }
            
            // Store available targets for polymorphic fields
            this.availableTargetObjects = configuredTargets;
            
            if (configuredTargets.length > 0) {
                // If only one target is configured, auto-select it
                if (configuredTargets.length === 1) {
                    const target = configuredTargets[0];
                    this.newMapping = {
                        ...this.newMapping,
                        salesforceRelationshipField: fieldApiName,
                        salesforceFieldLabel: field.label,
                        parentObject: target.value,
                        parentObjectLabel: target.label,
                        parentSyncObjectName: target.objectApiName
                    };
                } else {
                    // Multiple targets available - user needs to select one
                    this.newMapping = {
                        ...this.newMapping,
                        salesforceRelationshipField: fieldApiName,
                        salesforceFieldLabel: field.label,
                        parentObject: '', // Clear until user selects
                        parentObjectLabel: '',
                        parentSyncObjectName: ''
                    };
                }
            } else {
                // No sync objects configured for this relationship
                this.availableTargetObjects = [];
                this.newMapping = {
                    ...this.newMapping,
                    salesforceRelationshipField: fieldApiName,
                    salesforceFieldLabel: field.label,
                    parentObject: '',
                    parentObjectLabel: '',
                    parentSyncObjectName: ''
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

    handleTargetObjectSelection(event) {
        const selectedTarget = event.detail.value;
        const target = this.availableTargetObjects.find(t => t.value === selectedTarget);
        
        if (target) {
            this.newMapping = {
                ...this.newMapping,
                parentObject: target.value,
                parentObjectLabel: target.label,
                parentSyncObjectName: target.objectApiName
            };
        }
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
            parentObjectLabel: '',
            parentSyncObjectName: ''
        };
        this.availableTargetObjects = [];
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
                // Check if any of the referenced objects have a sync configuration
                // This supports polymorphic fields like WhoId, WhatId, OwnerId
                if (field.referenceTo && field.referenceTo.length > 0) {
                    return field.referenceTo.some(refObject => 
                        this.configuredSyncObjects.some(obj => obj.objectApiName === refObject)
                    );
                }
                return false;
            })
            .map(field => {
                // Show all target objects for polymorphic fields
                const targetObjects = field.referenceTo && field.referenceTo.length > 0 
                    ? field.referenceTo.join(', ') 
                    : '';
                return {
                    label: `${field.label} (${field.apiName}) → ${targetObjects}`,
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
               this.newMapping.notionRelationPropertyName &&
               this.newMapping.parentObject; // Must have a target object selected
    }

    get showTargetObjectSelector() {
        return this.availableTargetObjects.length > 1;
    }

    get isTargetObjectDisabled() {
        return !this.newMapping.salesforceRelationshipField || this.availableTargetObjects.length <= 1;
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

    // Dynamic column classes for responsive layout
    get fieldColumnClass() {
        return this.showTargetObjectSelector ? 'slds-col slds-size_1-of-3' : 'slds-col slds-size_1-of-2';
    }

    get targetObjectColumnClass() {
        return 'slds-col slds-size_1-of-3';
    }

    get propertyColumnClass() {
        return this.showTargetObjectSelector ? 'slds-col slds-size_1-of-3' : 'slds-col slds-size_1-of-2';
    }
}