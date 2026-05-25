import { LightningElement, api, track } from 'lwc';

/**
 * Sub-component for building widget filters.
 * Supports both static values and context field references.
 */
export default class NotionWidgetFilterBuilder extends LightningElement {
    @api notionProperties = [];
    @api salesforceFields = [];
    @api contextObjectApiName;

    @track filters = [];
    @track isAddingFilter = false;
    @track editingFilterId = null;

    // New filter being created
    @track newFilter = null;

    // Initialize filters from external value
    @api
    get configuredFilters() {
        return this.filters;
    }

    set configuredFilters(value) {
        if (value && Array.isArray(value)) {
            this.filters = value.map((filter, index) => ({
                ...filter,
                id: filter.id || `filter-${index}-${Date.now()}`
            }));
        } else {
            this.filters = [];
        }
    }

    get hasFilters() {
        return this.filters.length > 0;
    }

    get noFilters() {
        return !this.hasFilters;
    }

    get noProperties() {
        return !this.hasProperties;
    }

    get noPropertySelected() {
        return !this.newFilter || !this.newFilter.propertyName;
    }

    get cannotAddFilter() {
        return !this.canAddFilter;
    }

    get filtersWithMetadata() {
        return this.filters.map((filter, index) => ({
            ...filter,
            showLogicalOperator: index > 0,
            propertyTypeLabel: this.getPropertyTypeLabel(filter.propertyType),
            operatorLabel: this.getOperatorLabel(filter.operator),
            valueDisplay: this.getValueDisplay(filter)
        }));
    }

    // Spec 7: user-defined filters are MVP-supported only for these types.
    static USER_FILTERABLE_TYPES = new Set([
        'title', 'rich_text', 'number',
        'select', 'status', 'multi_select',
        'date', 'checkbox',
        'url', 'email', 'phone_number',
        'created_time', 'last_edited_time'
    ]);

    get propertyOptions() {
        return this.notionProperties
            .filter(prop => NotionWidgetFilterBuilder.USER_FILTERABLE_TYPES.has(prop.type))
            .map(prop => ({
                label: `${prop.name} (${this.getPropertyTypeLabel(prop.type)})`,
                value: prop.name,
                type: prop.type
            }));
    }

    get hasProperties() {
        return this.notionProperties.length > 0;
    }

    get valueTypeOptions() {
        return [
            { label: 'Static Value', value: 'static' },
            { label: 'Context Record Field', value: 'context_field' }
        ];
    }

    get logicalOperatorOptions() {
        return [
            { label: 'AND', value: 'and' },
            { label: 'OR', value: 'or' }
        ];
    }

    get contextFieldOptions() {
        if (!this.salesforceFields || this.salesforceFields.length === 0) {
            return [];
        }
        return this.salesforceFields.map(field => ({
            label: `${field.label} (${field.apiName})`,
            value: field.apiName
        }));
    }

    get hasContextFields() {
        return this.contextFieldOptions.length > 0;
    }

    get showContextFieldWarning() {
        return !this.contextObjectApiName || !this.hasContextFields;
    }

    get contextFieldWarningMessage() {
        if (!this.contextObjectApiName) {
            return 'Context Object must be set on the widget to use context field filters.';
        }
        return 'No fields available for the selected context object.';
    }

    // Computed properties for new filter form
    get showNewFilterStaticValue() {
        return this.newFilter && this.newFilter.valueType === 'static';
    }

    get showNewFilterContextField() {
        return this.newFilter && this.newFilter.valueType === 'context_field';
    }

    get newFilterOperatorOptions() {
        if (!this.newFilter || !this.newFilter.propertyType) {
            return this.getDefaultOperatorOptions();
        }
        return this.getOperatorOptionsForType(this.newFilter.propertyType);
    }

    get canAddFilter() {
        if (!this.newFilter) return false;
        if (!this.newFilter.propertyName || !this.newFilter.operator) return false;
        if (this.newFilter.valueType === 'static' && !this.newFilter.staticValue) return false;
        if (this.newFilter.valueType === 'context_field' && !this.newFilter.contextField) return false;
        return true;
    }

    getPropertyTypeLabel(type) {
        const labels = {
            'title': 'Title',
            'rich_text': 'Text',
            'number': 'Number',
            'select': 'Select',
            'multi_select': 'Multi-Select',
            'date': 'Date',
            'checkbox': 'Checkbox',
            'url': 'URL',
            'email': 'Email',
            'phone_number': 'Phone',
            'relation': 'Relation',
            'people': 'People',
            'files': 'Files',
            'formula': 'Formula',
            'rollup': 'Rollup',
            'status': 'Status',
            'created_time': 'Created Time',
            'last_edited_time': 'Last Edited Time',
            'created_by': 'Created By',
            'last_edited_by': 'Last Edited By'
        };
        return labels[type] || type;
    }

    getOperatorLabel(operator) {
        const labels = {
            'equals': 'equals',
            'does_not_equal': 'does not equal',
            'contains': 'contains',
            'does_not_contain': 'does not contain',
            'starts_with': 'starts with',
            'ends_with': 'ends with',
            'is_empty': 'is empty',
            'is_not_empty': 'is not empty',
            'greater_than': 'greater than',
            'greater_than_or_equal_to': 'greater than or equal to',
            'less_than': 'less than',
            'less_than_or_equal_to': 'less than or equal to',
            'before': 'before',
            'after': 'after',
            'on_or_before': 'on or before',
            'on_or_after': 'on or after',
            'is_checked': 'is checked',
            'is_not_checked': 'is not checked'
        };
        return labels[operator] || operator;
    }

    getValueDisplay(filter) {
        if (filter.valueType === 'context_field') {
            const field = this.salesforceFields.find(f => f.apiName === filter.contextField);
            return `{${field ? field.label : filter.contextField}}`;
        }
        if (filter.operator === 'is_empty' || filter.operator === 'is_not_empty' ||
            filter.operator === 'is_checked' || filter.operator === 'is_not_checked') {
            return '';
        }
        return filter.staticValue || '';
    }

    getDefaultOperatorOptions() {
        return [
            { label: 'equals', value: 'equals' },
            { label: 'does not equal', value: 'does_not_equal' },
            { label: 'contains', value: 'contains' },
            { label: 'does not contain', value: 'does_not_contain' },
            { label: 'is empty', value: 'is_empty' },
            { label: 'is not empty', value: 'is_not_empty' }
        ];
    }

    getOperatorOptionsForType(propertyType) {
        // Text-based types
        if (['title', 'rich_text', 'url', 'email', 'phone_number'].includes(propertyType)) {
            return [
                { label: 'equals', value: 'equals' },
                { label: 'does not equal', value: 'does_not_equal' },
                { label: 'contains', value: 'contains' },
                { label: 'does not contain', value: 'does_not_contain' },
                { label: 'starts with', value: 'starts_with' },
                { label: 'ends with', value: 'ends_with' },
                { label: 'is empty', value: 'is_empty' },
                { label: 'is not empty', value: 'is_not_empty' }
            ];
        }

        // Number type
        if (propertyType === 'number') {
            return [
                { label: 'equals', value: 'equals' },
                { label: 'does not equal', value: 'does_not_equal' },
                { label: 'greater than', value: 'greater_than' },
                { label: 'greater than or equal to', value: 'greater_than_or_equal_to' },
                { label: 'less than', value: 'less_than' },
                { label: 'less than or equal to', value: 'less_than_or_equal_to' },
                { label: 'is empty', value: 'is_empty' },
                { label: 'is not empty', value: 'is_not_empty' }
            ];
        }

        // Date types
        if (['date', 'created_time', 'last_edited_time'].includes(propertyType)) {
            return [
                { label: 'equals', value: 'equals' },
                { label: 'before', value: 'before' },
                { label: 'after', value: 'after' },
                { label: 'on or before', value: 'on_or_before' },
                { label: 'on or after', value: 'on_or_after' },
                { label: 'is empty', value: 'is_empty' },
                { label: 'is not empty', value: 'is_not_empty' }
            ];
        }

        // Checkbox type
        if (propertyType === 'checkbox') {
            return [
                { label: 'is checked', value: 'is_checked' },
                { label: 'is not checked', value: 'is_not_checked' }
            ];
        }

        // Select/Status types
        if (['select', 'status'].includes(propertyType)) {
            return [
                { label: 'equals', value: 'equals' },
                { label: 'does not equal', value: 'does_not_equal' },
                { label: 'is empty', value: 'is_empty' },
                { label: 'is not empty', value: 'is_not_empty' }
            ];
        }

        // Multi-select type
        if (propertyType === 'multi_select') {
            return [
                { label: 'contains', value: 'contains' },
                { label: 'does not contain', value: 'does_not_contain' },
                { label: 'is empty', value: 'is_empty' },
                { label: 'is not empty', value: 'is_not_empty' }
            ];
        }

        // Default
        return this.getDefaultOperatorOptions();
    }

    // Event Handlers
    handleShowAddFilter() {
        this.isAddingFilter = true;
        this.newFilter = {
            propertyName: '',
            propertyType: '',
            operator: '',
            valueType: 'static',
            staticValue: '',
            contextField: '',
            logicalOperator: 'and'
        };
    }

    handleCancelAddFilter() {
        this.isAddingFilter = false;
        this.newFilter = null;
    }

    handlePropertyChange(event) {
        const propertyName = event.detail.value;
        const property = this.notionProperties.find(p => p.name === propertyName);

        this.newFilter = {
            ...this.newFilter,
            propertyName: propertyName,
            propertyType: property ? property.type : '',
            operator: '' // Reset operator when property changes
        };
    }

    handleOperatorChange(event) {
        this.newFilter = {
            ...this.newFilter,
            operator: event.detail.value
        };
    }

    handleValueTypeChange(event) {
        this.newFilter = {
            ...this.newFilter,
            valueType: event.detail.value,
            staticValue: '',
            contextField: ''
        };
    }

    handleStaticValueChange(event) {
        this.newFilter = {
            ...this.newFilter,
            staticValue: event.target.value
        };
    }

    handleContextFieldChange(event) {
        this.newFilter = {
            ...this.newFilter,
            contextField: event.detail.value
        };
    }

    handleLogicalOperatorChange(event) {
        this.newFilter = {
            ...this.newFilter,
            logicalOperator: event.detail.value
        };
    }

    handleAddFilter() {
        if (!this.canAddFilter) {
            return;
        }

        const newFilterEntry = {
            id: `filter-${Date.now()}`,
            propertyName: this.newFilter.propertyName,
            propertyType: this.newFilter.propertyType,
            operator: this.newFilter.operator,
            valueType: this.newFilter.valueType,
            staticValue: this.newFilter.valueType === 'static' ? this.newFilter.staticValue : '',
            contextField: this.newFilter.valueType === 'context_field' ? this.newFilter.contextField : '',
            filterOrder: this.filters.length + 1,
            logicalOperator: this.filters.length > 0 ? this.newFilter.logicalOperator : 'and'
        };

        this.filters = [...this.filters, newFilterEntry];
        this.handleCancelAddFilter();
        this.notifyChange();
    }

    handleRemoveFilter(event) {
        const filterId = event.target.dataset.id;
        this.filters = this.filters.filter(f => f.id !== filterId);
        this.reorderFilters();
        this.notifyChange();
    }

    handleFilterLogicalOperatorChange(event) {
        const filterId = event.target.dataset.id;
        const logicalOperator = event.detail.value;
        this.filters = this.filters.map(f => {
            if (f.id === filterId) {
                return { ...f, logicalOperator };
            }
            return f;
        });
        this.notifyChange();
    }

    reorderFilters() {
        this.filters = this.filters.map((filter, index) => ({
            ...filter,
            filterOrder: index + 1
        }));
    }

    notifyChange() {
        this.dispatchEvent(new CustomEvent('filterchange', {
            detail: { filters: this.filters }
        }));
    }

    handleClearAllFilters() {
        this.filters = [];
        this.notifyChange();
    }
}
