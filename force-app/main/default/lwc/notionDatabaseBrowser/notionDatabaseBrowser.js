import { LightningElement, api, track, wire } from 'lwc';
import getDatabases from '@salesforce/apex/NotionAdminController.getDatabases';
import getDatabaseSchema from '@salesforce/apex/NotionAdminController.getDatabaseSchema';

export default class NotionDatabaseBrowser extends LightningElement {
    @api showSelectionOnly = false;
    
    @track databases = [];
    @track filteredDatabases = [];
    @track selectedDatabase = null;
    @track databaseSchema = null;
    @track isLoading = false;
    @track error = null;
    @track searchTerm = '';
    @track showSchema = false;

    columns = [
        { 
            label: 'Database Name', 
            fieldName: 'title', 
            type: 'text',
            cellAttributes: { 
                iconName: { fieldName: 'iconName' },
                iconPosition: 'left'
            }
        },
        { 
            label: 'Database ID', 
            fieldName: 'id', 
            type: 'text',
            initialWidth: 300
        },
        { 
            label: 'Last Modified', 
            fieldName: 'lastEditedTime', 
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }
        }
    ];

    connectedCallback() {
        this.loadDatabases();
    }

    async loadDatabases() {
        this.isLoading = true;
        this.error = null;
        
        try {
            const data = await getDatabases();
            this.databases = data.map(db => ({
                ...db,
                iconName: db.iconEmoji ? null : 'standard:dataset'
            }));
            this.filteredDatabases = [...this.databases];
        } catch (error) {
            this.error = error.body ? error.body.message : error.message;
            console.error('Error loading databases:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filterDatabases();
    }

    filterDatabases() {
        if (!this.searchTerm) {
            this.filteredDatabases = [...this.databases];
        } else {
            this.filteredDatabases = this.databases.filter(db => 
                db.title.toLowerCase().includes(this.searchTerm) ||
                db.id.toLowerCase().includes(this.searchTerm)
            );
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            this.selectedDatabase = selectedRows[0];
            if (!this.showSelectionOnly) {
                this.loadDatabaseSchema(this.selectedDatabase.id);
            }
        } else {
            this.selectedDatabase = null;
            this.databaseSchema = null;
            this.showSchema = false;
        }
    }

    async loadDatabaseSchema(databaseId) {
        this.isLoading = true;
        try {
            const schema = await getDatabaseSchema({ databaseId });
            this.databaseSchema = schema;
            this.showSchema = true;
        } catch (error) {
            console.error('Error loading database schema:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectDatabase() {
        if (this.selectedDatabase) {
            this.dispatchEvent(new CustomEvent('databaseselect', {
                detail: {
                    databaseId: this.selectedDatabase.id,
                    databaseName: this.selectedDatabase.title
                }
            }));
        }
    }

    handleRefresh() {
        this.loadDatabases();
    }

    handleCloseSchema() {
        this.showSchema = false;
    }

    // Computed properties
    get hasData() {
        return this.filteredDatabases.length > 0;
    }

    get noDataMessage() {
        if (this.searchTerm) {
            return `No databases found matching "${this.searchTerm}"`;
        }
        return 'No databases found in your Notion workspace';
    }

    get selectionDisabled() {
        return !this.selectedDatabase;
    }

    get hideCheckboxColumn() {
        // Only hide checkbox column when NOT in selection mode
        return !this.showSelectionOnly;
    }

    get schemaProperties() {
        if (!this.databaseSchema || !this.databaseSchema.properties) {
            return [];
        }
        
        return this.databaseSchema.properties.map(prop => ({
            ...prop,
            typeLabel: this.getPropertyTypeLabel(prop.type),
            typeIcon: this.getPropertyTypeIcon(prop.type)
        }));
    }

    getPropertyTypeLabel(type) {
        const typeLabels = {
            'title': 'Title',
            'rich_text': 'Text',
            'number': 'Number',
            'select': 'Select',
            'multi_select': 'Multi-select',
            'date': 'Date',
            'checkbox': 'Checkbox',
            'email': 'Email',
            'phone_number': 'Phone',
            'url': 'URL',
            'relation': 'Relation',
            'people': 'Person',
            'files': 'Files & media',
            'formula': 'Formula',
            'rollup': 'Rollup'
        };
        return typeLabels[type] || type;
    }

    getPropertyTypeIcon(type) {
        const typeIcons = {
            'title': 'utility:text',
            'rich_text': 'utility:textarea',
            'number': 'utility:number_input',
            'select': 'utility:picklist_type',
            'multi_select': 'utility:multi_picklist',
            'date': 'utility:date_input',
            'checkbox': 'utility:check',
            'email': 'utility:email',
            'phone_number': 'utility:call',
            'url': 'utility:link',
            'relation': 'utility:merge',
            'people': 'utility:user',
            'files': 'utility:attach',
            'formula': 'utility:formula',
            'rollup': 'utility:summary'
        };
        return typeIcons[type] || 'utility:question';
    }
}