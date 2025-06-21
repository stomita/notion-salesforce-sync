import { LightningElement, api, track, wire } from 'lwc';
import getObjectFields from '@salesforce/apex/NotionAdminController.getObjectFields';
import getDatabaseSchema from '@salesforce/apex/NotionAdminController.getDatabaseSchema';

export default class NotionFieldMapping extends LightningElement {
    @api objectApiName;
    @api notionDatabaseId;
    @api existingMappings = [];

    @track salesforceFields = [];
    @track notionProperties = [];
    @track fieldMappings = [];
    @track isLoading = false;
    @track showAddMapping = false;

    // For new mapping - Initialize with null to ensure proper initial state
    @track newMapping = null;

    connectedCallback() {
        this.initializeMappings();
        if (this.objectApiName && this.notionDatabaseId) {
            this.loadData();
        }
    }

    @api
    get mappings() {
        return this.fieldMappings;
    }

    initializeMappings() {
        if (this.existingMappings && this.existingMappings.length > 0) {
            this.fieldMappings = [...this.existingMappings];
        }
    }

    async loadData() {
        this.isLoading = true;
        try {
            // Load Salesforce fields and Notion properties in parallel
            const [fields, schema] = await Promise.all([
                getObjectFields({ objectApiName: this.objectApiName }),
                getDatabaseSchema({ databaseId: this.notionDatabaseId })
            ]);

            this.salesforceFields = fields;
            this.notionProperties = schema.properties;
            
            // Auto-detect types for existing mappings
            this.updateMappingTypes();
        } catch (error) {
            console.error('Error loading data:', error);
        } finally {
            this.isLoading = false;
        }
    }

    updateMappingTypes() {
        this.fieldMappings = this.fieldMappings.map(mapping => {
            const suggestedType = this.getSuggestedNotionType(mapping.salesforceFieldApiName);
            return {
                ...mapping,
                notionPropertyType: mapping.notionPropertyType || suggestedType
            };
        });
    }

    getSuggestedNotionType(fieldApiName) {
        const field = this.salesforceFields.find(f => f.apiName === fieldApiName);
        if (!field) return 'rich_text';

        // Map Salesforce field types to Notion property types
        const typeMapping = {
            'STRING': 'rich_text',
            'TEXTAREA': 'rich_text',
            'EMAIL': 'email',
            'PHONE': 'phone_number',
            'URL': 'url',
            'INTEGER': 'number',
            'DOUBLE': 'number',
            'PERCENT': 'number',
            'CURRENCY': 'number',
            'DATE': 'date',
            'DATETIME': 'date',
            'BOOLEAN': 'checkbox',
            'PICKLIST': 'select',
            'MULTIPICKLIST': 'multi_select',
            'REFERENCE': 'relation'
        };

        return typeMapping[field.type] || 'rich_text';
    }

    handleShowAddMapping() {
        this.showAddMapping = true;
        // Initialize newMapping when showing the form
        this.newMapping = {
            salesforceFieldApiName: '',
            notionPropertyName: '',
            notionPropertyType: '',
            isBodyContent: false
        };
    }

    handleCancelAdd() {
        this.showAddMapping = false;
        // Reset to null when canceling
        this.newMapping = null;
    }

    handleFieldSelection(event) {
        // Create a new object to ensure reactivity
        this.newMapping = {
            ...this.newMapping,
            salesforceFieldApiName: event.detail.value,
            notionPropertyType: this.getSuggestedNotionType(event.detail.value),
            isBodyContent: false
        };
    }

    handlePropertySelection(event) {
        const property = this.notionProperties.find(p => p.name === event.detail.value);
        
        // Create a new object to ensure reactivity
        this.newMapping = {
            ...this.newMapping,
            notionPropertyName: event.detail.value,
            notionPropertyType: property ? property.type : this.newMapping.notionPropertyType
        };
    }


    handleBodyContentChange(event) {
        const isChecked = event.target.checked;
        
        // Create a new object to ensure reactivity
        this.newMapping = {
            ...this.newMapping,
            isBodyContent: isChecked,
            notionPropertyName: isChecked ? '__body__' : '',
            notionPropertyType: isChecked ? 'rich_text' : this.newMapping.notionPropertyType
        };
    }

    handleAddMapping() {
        // Validate the new mapping
        if (!this.newMapping.salesforceFieldApiName || 
            (!this.newMapping.notionPropertyName && !this.newMapping.isBodyContent)) {
            return;
        }

        // Check for duplicates
        const isDuplicate = this.fieldMappings.some(
            m => m.salesforceFieldApiName === this.newMapping.salesforceFieldApiName
        );

        if (isDuplicate) {
            // Show error
            return;
        }

        // Add the mapping
        this.fieldMappings = [...this.fieldMappings, { ...this.newMapping }];
        this.handleCancelAdd();
        this.notifyMappingChange();
    }

    handleRemoveMapping(event) {
        const index = event.target.dataset.index;
        this.fieldMappings = this.fieldMappings.filter((_, i) => i !== parseInt(index));
        this.notifyMappingChange();
    }


    notifyMappingChange() {
        this.dispatchEvent(new CustomEvent('mappingchange', {
            detail: { mappings: this.fieldMappings }
        }));
    }

    // Computed properties
    get availableFields() {
        const mappedFields = new Set(this.fieldMappings.map(m => m.salesforceFieldApiName));
        return this.salesforceFields
            .filter(field => !mappedFields.has(field.apiName))
            .map(field => ({
                label: `${field.label} - ${field.apiName} (${field.type})`,
                value: field.apiName
            }));
    }

    get availableProperties() {
        const mappedProps = new Set(
            this.fieldMappings
                .filter(m => !m.isBodyContent)
                .map(m => m.notionPropertyName)
        );
        
        return this.notionProperties
            .filter(prop => !mappedProps.has(prop.name))
            .map(prop => ({
                label: `${prop.name} (${prop.type})`,
                value: prop.name
            }));
    }

    get notionTypeOptions() {
        return [
            { label: 'Text', value: 'rich_text' },
            { label: 'Title', value: 'title' },
            { label: 'Number', value: 'number' },
            { label: 'Select', value: 'select' },
            { label: 'Multi-select', value: 'multi_select' },
            { label: 'Date', value: 'date' },
            { label: 'Checkbox', value: 'checkbox' },
            { label: 'Email', value: 'email' },
            { label: 'Phone', value: 'phone_number' },
            { label: 'URL', value: 'url' },
            { label: 'Relation', value: 'relation' }
        ];
    }

    get hasMappings() {
        return this.fieldMappings.length > 0;
    }

    get canAddMapping() {
        return this.availableFields.length > 0;
    }

    get disableAddButton() {
        return !this.canAddMapping;
    }

    get showBodyContentOption() {
        // Ensure we have a field selected
        if (!this.newMapping || !this.newMapping.salesforceFieldApiName) {
            return false;
        }
        
        // Find the selected field
        const field = this.salesforceFields.find(f => f.apiName === this.newMapping.salesforceFieldApiName);
        if (!field) {
            return false;
        }
        
        // Show for TEXTAREA, LONGTEXTAREA, and RICHTEXTAREA field types
        const textAreaTypes = ['TEXTAREA', 'LONGTEXTAREA', 'RICHTEXTAREA'];
        return textAreaTypes.includes(field.type);
    }

    get mappingsWithMetadata() {
        return this.fieldMappings.map((mapping, index) => ({
            ...mapping,
            id: `mapping-${index}`,
            fieldLabel: this.getFieldLabel(mapping.salesforceFieldApiName),
            fieldType: this.getFieldType(mapping.salesforceFieldApiName),
            propertyType: this.getPropertyType(mapping.notionPropertyName)
        }));
    }

    getFieldLabel(apiName) {
        const field = this.salesforceFields.find(f => f.apiName === apiName);
        return field ? field.label : apiName;
    }

    getFieldType(apiName) {
        const field = this.salesforceFields.find(f => f.apiName === apiName);
        return field ? field.type : 'Unknown';
    }

    getPropertyType(propName) {
        const prop = this.notionProperties.find(p => p.name === propName);
        return prop ? prop.type : 'Unknown';
    }
}