import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Sanitize a string into a valid Salesforce CustomMetadata DeveloperName:
// alphanumerics + underscore only, no consecutive underscores, no leading/trailing
// underscore, must start with a letter, max 40 chars. Matches the server-side
// sanitization in NotionWidgetController.sanitizeDeveloperName.
function sanitizeDevName(s) {
    let out = String(s || '')
        .replace(/[^a-zA-Z0-9_]/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_+|_+$/g, '');
    if (!out || !/^[a-zA-Z]/.test(out)) {
        out = 'X' + out;
    }
    if (out.length > 40) {
        out = out.substring(0, 40).replace(/_+$/, '');
    }
    return out;
}

// Build a stable, collision-free DeveloperName for a child record (column / filter).
// - Prefer the existing DeveloperName when present so renaming/reordering does not
//   orphan previously-saved records.
// - Otherwise use the sanitized property-derived suffix; if that collapses to empty
//   (e.g. property name contains only special characters), fall back to a 1-based
//   index suffix to guarantee uniqueness within the widget.
function buildChildDevName(widgetDev, existingDevName, propBasedSuffix, index, prefix) {
    if (existingDevName) {
        return existingDevName;
    }
    const sanitizedSuffix = sanitizeDevName(propBasedSuffix || '');
    // The 'X' prefix is added by sanitizeDevName when the input is empty/invalid;
    // treat the lone 'X' as "no usable suffix" and fall back to the index.
    const usable = sanitizedSuffix && sanitizedSuffix !== 'X';
    const suffix = usable ? sanitizedSuffix : `${prefix}${index + 1}`;
    return sanitizeDevName(`${widgetDev}_${suffix}`);
}
import getDatabases from '@salesforce/apex/NotionAdminController.getDatabases';
import getDatabaseSchema from '@salesforce/apex/NotionAdminController.getDatabaseSchema';
import getObjectFields from '@salesforce/apex/NotionAdminController.getObjectFields';
import getSalesforceObjects from '@salesforce/apex/NotionAdminController.getSalesforceObjects';
import getAllWidgetConfigurations from '@salesforce/apex/NotionWidgetController.getAllWidgetConfigurations';
import getWidgetConfiguration from '@salesforce/apex/NotionWidgetController.getWidgetConfiguration';
import saveWidgetConfiguration from '@salesforce/apex/NotionWidgetController.saveWidgetConfiguration';
import deleteWidgetConfiguration from '@salesforce/apex/NotionWidgetController.deleteWidgetConfiguration';
import getContextFilterableFields from '@salesforce/apex/NotionWidgetController.getContextFilterableFields';

export default class NotionWidgetDesigner extends LightningElement {
    // View state
    @track currentView = 'list'; // 'list', 'edit', 'selectDatabase'
    @track isLoading = false;
    @track error = null;

    // List view data
    @track widgets = [];

    // Edit view data
    @track isNewWidget = false;
    @track editingWidget = null;
    @track notionProperties = [];
    @track salesforceFields = [];
    @track salesforceObjects = [];

    @wire(getSalesforceObjects)
    wiredObjects({ data }) {
        if (data) {
            this.salesforceObjects = data;
        }
    }

    // Database browser data
    @track databases = [];
    @track filteredDatabases = [];
    @track searchTerm = '';
    @track selectedDatabase = null;

    // Constants
    sortDirectionOptions = [
        { label: 'Ascending', value: 'ascending' },
        { label: 'Descending', value: 'descending' }
    ];

    pageSizeOptions = [
        { label: '10', value: '10' },
        { label: '25', value: '25' },
        { label: '50', value: '50' },
        { label: '100', value: '100' }
    ];

    databaseColumns = [
        { label: 'Database Name', fieldName: 'title', type: 'text' },
        { label: 'Database ID', fieldName: 'id', type: 'text', initialWidth: 300 }
    ];

    connectedCallback() {
        this.loadWidgets();
    }

    // Data loading methods
    async loadWidgets() {
        this.isLoading = true;
        this.error = null;
        try {
            this.widgets = await getAllWidgetConfigurations();
        } catch (error) {
            this.handleError('Error loading widgets', error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadDatabases() {
        this.isLoading = true;
        try {
            const data = await getDatabases();
            this.databases = data.map(db => ({
                ...db,
                iconName: 'standard:dataset'
            }));
            this.filteredDatabases = [...this.databases];
        } catch (error) {
            this.handleError('Error loading databases', error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadDatabaseSchema(databaseId) {
        this.isLoading = true;
        try {
            const schema = await getDatabaseSchema({ databaseId });
            this.notionProperties = schema?.properties || [];
        } catch (error) {
            this.handleError('Error loading database schema', error);
            this.notionProperties = [];
        } finally {
            this.isLoading = false;
        }
    }

    async loadSalesforceFields(objectApiName) {
        if (!objectApiName) {
            this.salesforceFields = [];
            return;
        }

        this.isLoading = true;
        try {
            const fields = await getContextFilterableFields({ objectApiName });
            this.salesforceFields = fields.map(f => ({
                apiName: f.apiName,
                label: f.label,
                type: f.type
            }));
        } catch (error) {
            console.error('Error loading Salesforce fields:', error);
            this.salesforceFields = [];
        } finally {
            this.isLoading = false;
        }
    }

    async loadWidgetForEdit(developerName) {
        this.isLoading = true;
        try {
            const config = await getWidgetConfiguration({ widgetDeveloperName: developerName });
            if (config) {
                this.editingWidget = {
                    developerName: config.developerName,
                    label: config.label,
                    notionDatabaseId: config.notionDatabaseId,
                    notionDatabaseName: config.notionDatabaseName || '',
                    isActive: config.isActive,
                    pageSize: config.pageSize || 25,
                    defaultSortProperty: config.defaultSortProperty || '',
                    defaultSortDirection: config.defaultSortDirection || 'ascending',
                    contextObjectApiName: config.contextObjectApiName || '',
                    contextRelationProperty: config.contextRelationProperty || '',
                    showNewButton: config.showNewButton !== false,
                    description: config.description || '',
                    columns: config.columns || [],
                    filters: config.filters || []
                };

                // Load database schema and SF fields
                if (config.notionDatabaseId) {
                    await this.loadDatabaseSchema(config.notionDatabaseId);
                }
                if (config.contextObjectApiName) {
                    await this.loadSalesforceFields(config.contextObjectApiName);
                }
            }
        } catch (error) {
            this.handleError('Error loading widget configuration', error);
        } finally {
            this.isLoading = false;
        }
    }

    // View computed properties
    get showListView() {
        return this.currentView === 'list';
    }

    get showEditView() {
        // Only show edit view when currentView is 'edit' AND editingWidget is initialized
        return this.currentView === 'edit' && this.editingWidget !== null;
    }

    get showDatabaseSelector() {
        return this.currentView === 'selectDatabase';
    }

    get hasWidgets() {
        return this.widgets && this.widgets.length > 0;
    }

    get widgetsWithMetadata() {
        return this.widgets.map(w => ({
            ...w,
            statusLabel: w.isActive ? 'Active' : 'Inactive',
            statusVariant: w.isActive ? 'success' : 'default',
            contextObjectLabel: w.contextObjectApiName || 'None'
        }));
    }

    get editViewTitle() {
        return this.isNewWidget ? 'Create New Widget' : `Edit Widget: ${this.editingWidget?.label || ''}`;
    }

    get developerNameDisabled() {
        return !this.isNewWidget;
    }

    // Spec 7: types that cannot be used for sorting in MVP.
    SORT_UNSUPPORTED_TYPES = new Set([
        'people', 'created_by', 'last_edited_by',
        'files', 'relation', 'formula', 'rollup', 'multi_select'
    ]);

    get sortPropertyOptions() {
        const options = [{ label: '(none)', value: '' }];
        this.notionProperties
            .filter(p => !this.SORT_UNSUPPORTED_TYPES.has(p.type))
            .forEach(p => options.push({ label: p.name, value: p.name }));
        return options;
    }

    get relationPropertyOptions() {
        const options = [{ label: '(none)', value: '' }];
        this.notionProperties
            .filter(p => p.type === 'relation')
            .forEach(p => options.push({ label: p.name, value: p.name }));
        return options;
    }

    get contextObjectOptions() {
        const options = [{ label: '(none)', value: '' }];
        for (const obj of this.salesforceObjects || []) {
            options.push({
                label: `${obj.label} (${obj.apiName})`,
                value: obj.apiName
            });
        }
        return options;
    }

    get hasRelationProperties() {
        return this.notionProperties.some(p => p.type === 'relation');
    }

    get hasNotionProperties() {
        return this.notionProperties.length > 0;
    }

    get noNotionProperties() {
        return !this.hasNotionProperties;
    }

    get hasDatabases() {
        return this.filteredDatabases.length > 0;
    }

    get databaseSelectionDisabled() {
        return !this.selectedDatabase;
    }

    // Event Handlers - List View
    handleNewWidget() {
        this.isNewWidget = true;
        this.editingWidget = {
            developerName: '',
            label: '',
            notionDatabaseId: '',
            notionDatabaseName: '',
            isActive: true,
            pageSize: 25,
            defaultSortProperty: '',
            defaultSortDirection: 'ascending',
            contextObjectApiName: '',
            contextRelationProperty: '',
            showNewButton: true,
            description: '',
            columns: [],
            filters: []
        };
        this.notionProperties = [];
        this.salesforceFields = [];
        this.currentView = 'edit';
    }

    async handleEditWidget(event) {
        const developerName = event.currentTarget.dataset.name;
        this.isNewWidget = false;
        // Load the widget data first, then switch to edit view
        // This prevents null reference errors in the template
        await this.loadWidgetForEdit(developerName);
        // Only switch to edit view after data is loaded
        if (this.editingWidget) {
            this.currentView = 'edit';
        }
    }

    async handleDeleteWidget(event) {
        const developerName = event.currentTarget.dataset.name;
        const widgetLabel = event.currentTarget.dataset.label;

        if (!confirm(`Are you sure you want to delete the widget "${widgetLabel}"? This action cannot be undone.`)) {
            return;
        }

        this.isLoading = true;
        try {
            const result = await deleteWidgetConfiguration({ widgetDeveloperName: developerName });
            if (result.success) {
                this.showToast('Success', 'Widget deleted successfully', 'success');
                await this.loadWidgets();
            } else {
                this.showToast('Error', result.message || 'Failed to delete widget', 'error');
            }
        } catch (error) {
            this.handleError('Error deleting widget', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRefreshList() {
        this.loadWidgets();
    }

    // Event Handlers - Edit View
    handleBackToList() {
        this.currentView = 'list';
        this.editingWidget = null;
        this.notionProperties = [];
        this.salesforceFields = [];
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        // Handle combobox selection
        if (event.detail && event.detail.value !== undefined) {
            value = event.detail.value;
        }

        this.editingWidget = {
            ...this.editingWidget,
            [field]: value
        };

        // Load SF fields when context object changes
        if (field === 'contextObjectApiName') {
            this.loadSalesforceFields(value);
        }
    }

    handleSelectDatabase() {
        this.loadDatabases();
        this.selectedDatabase = null;
        this.searchTerm = '';
        this.currentView = 'selectDatabase';
    }

    // Event Handlers - Database Selector
    handleDatabaseSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        if (!this.searchTerm) {
            this.filteredDatabases = [...this.databases];
        } else {
            this.filteredDatabases = this.databases.filter(db =>
                db.title.toLowerCase().includes(this.searchTerm) ||
                db.id.toLowerCase().includes(this.searchTerm)
            );
        }
    }

    handleDatabaseRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedDatabase = selectedRows.length > 0 ? selectedRows[0] : null;
    }

    handleConfirmDatabaseSelection() {
        if (this.selectedDatabase) {
            this.editingWidget = {
                ...this.editingWidget,
                notionDatabaseId: this.selectedDatabase.id,
                notionDatabaseName: this.selectedDatabase.title,
                columns: [], // Reset columns when database changes
                filters: [], // Reset filters when database changes
                defaultSortProperty: ''
            };
            this.loadDatabaseSchema(this.selectedDatabase.id);
            this.currentView = 'edit';
        }
    }

    handleCancelDatabaseSelection() {
        this.currentView = 'edit';
    }

    // Event Handlers - Column/Filter Configuration
    handleColumnChange(event) {
        const columns = event.detail.columns;
        this.editingWidget = {
            ...this.editingWidget,
            columns: columns.map(col => ({
                developerName: col.developerName,
                propertyName: col.propertyName,
                propertyType: col.propertyType,
                label: col.label,
                displayOrder: col.displayOrder,
                columnWidth: col.width,
                isVisible: col.isVisible,
                isSortable: col.isSortable
            }))
        };
    }

    handleFilterChange(event) {
        const filters = event.detail.filters;
        this.editingWidget = {
            ...this.editingWidget,
            filters: filters.map(filter => ({
                developerName: filter.developerName,
                propertyName: filter.propertyName,
                propertyType: filter.propertyType,
                operator: filter.operator,
                valueType: filter.valueType,
                staticValue: filter.staticValue,
                contextField: filter.contextField,
                filterOrder: filter.filterOrder,
                logicalOperator: filter.logicalOperator
            }))
        };
    }

    // Save Widget
    async handleSaveWidget() {
        // Validate required fields
        if (!this.editingWidget.developerName || !this.editingWidget.label || !this.editingWidget.notionDatabaseId) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        // Validate developer name format
        if (this.isNewWidget && !/^[a-zA-Z][a-zA-Z0-9_]*$/.test(this.editingWidget.developerName)) {
            this.showToast('Error', 'Developer Name must start with a letter and contain only letters, numbers, and underscores', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const widgetDev = this.editingWidget.developerName;
            // Transform columns to match expected format.
            // Defensive sort by displayOrder: Apex persists DisplayOrder__c from the
            // array index, so the array order is what actually defines the saved order.
            const orderedColumns = [...(this.editingWidget.columns || [])]
                .sort((a, b) => (a.displayOrder || 0) - (b.displayOrder || 0));
            const columnsToSave = orderedColumns.map((col, index) => ({
                developerName: buildChildDevName(widgetDev, col.developerName, col.propertyName, index, 'col'),
                label: col.label || col.propertyName,
                notionPropertyName: col.propertyName,
                notionPropertyType: col.propertyType,
                displayOrder: index + 1,
                columnWidth: col.columnWidth,
                isVisible: col.isVisible !== false,
                isSortable: col.isSortable !== false
            }));

            // Transform filters to match expected format
            const filtersToSave = (this.editingWidget.filters || []).map((filter, index) => ({
                developerName: buildChildDevName(widgetDev, filter.developerName, `filter_${index + 1}`, index, 'filter'),
                label: `Filter ${index + 1}`,
                notionPropertyName: filter.propertyName,
                notionPropertyType: filter.propertyType,
                filterOperator: filter.operator,
                valueType: filter.valueType,
                staticValue: filter.staticValue,
                contextSalesforceField: filter.contextField,
                filterOrder: filter.filterOrder || index + 1,
                logicalOperator: filter.logicalOperator || 'and'
            }));

            const configToSave = {
                developerName: this.editingWidget.developerName,
                label: this.editingWidget.label,
                notionDatabaseId: this.editingWidget.notionDatabaseId,
                isActive: this.editingWidget.isActive,
                pageSize: parseInt(this.editingWidget.pageSize, 10) || 25,
                defaultSortProperty: this.editingWidget.defaultSortProperty,
                defaultSortDirection: this.editingWidget.defaultSortDirection,
                contextObjectApiName: this.editingWidget.contextObjectApiName,
                contextRelationProperty: this.editingWidget.contextRelationProperty,
                showNewButton: this.editingWidget.showNewButton !== false,
                description: this.editingWidget.description,
                columns: columnsToSave,
                filters: filtersToSave
            };

            const result = await saveWidgetConfiguration({
                configJson: JSON.stringify(configToSave)
            });

            if (result.success) {
                this.showToast('Success', 'Widget saved successfully', 'success');
                await this.loadWidgets();
                this.currentView = 'list';
            } else {
                const detail = (result.errors || []).join(' | ');
                this.showToast('Error', `${result.message || 'Failed to save widget'}: ${detail}`, 'error');
            }
        } catch (error) {
            this.handleError('Error saving widget', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Utility methods
    handleError(context, error) {
        console.error(context, error);
        const message = error.body?.message || error.message || 'An unknown error occurred';
        this.error = message;
        this.showToast('Error', message, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    // Column configurator data transformation
    get columnConfiguratorColumns() {
        return (this.editingWidget?.columns || []).map((col, index) => {
            // Handle both propertyName (from UI) and notionPropertyName (from saved config)
            const propertyName = col.propertyName || col.notionPropertyName;
            // Handle both propertyType (from UI) and notionPropertyType (from saved config)
            const propertyType = col.propertyType || col.notionPropertyType;
            return {
                id: `col-${index}`,
                developerName: col.developerName,
                propertyName: propertyName,
                propertyType: propertyType,
                label: col.label || propertyName,
                displayOrder: col.displayOrder || index + 1,
                width: col.columnWidth,
                isVisible: col.isVisible !== false,
                isSortable: col.isSortable !== false
            };
        });
    }

    // Filter builder data transformation
    get filterBuilderFilters() {
        return (this.editingWidget?.filters || []).map((filter, index) => {
            // Handle both propertyName (from UI) and notionPropertyName (from saved config)
            const propertyName = filter.propertyName || filter.notionPropertyName;
            // Handle both propertyType (from UI) and notionPropertyType (from saved config)
            const propertyType = filter.propertyType || filter.notionPropertyType;
            // Handle both operator (from UI) and filterOperator (from saved config)
            const operator = filter.operator || filter.filterOperator;
            // Handle both contextField (from UI) and contextSalesforceField (from saved config)
            const contextField = filter.contextField || filter.contextSalesforceField;
            return {
                id: `filter-${index}`,
                developerName: filter.developerName,
                propertyName: propertyName,
                propertyType: propertyType,
                operator: operator,
                valueType: filter.valueType,
                staticValue: filter.staticValue,
                contextField: contextField,
                filterOrder: filter.filterOrder || index + 1,
                logicalOperator: filter.logicalOperator || 'and'
            };
        });
    }
}
