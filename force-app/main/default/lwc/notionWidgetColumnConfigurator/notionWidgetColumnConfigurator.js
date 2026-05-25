import { LightningElement, api, track } from 'lwc';

/**
 * Sub-component for configuring widget columns.
 * Allows adding/removing columns, reordering, and configuring display settings.
 */
export default class NotionWidgetColumnConfigurator extends LightningElement {
    @api notionDatabaseId;
    @api notionProperties = [];

    @track columns = [];
    @track isAddingColumn = false;
    @track selectedPropertyForAdd = '';

    // Initialize columns from external value
    @api
    get configuredColumns() {
        return this.columns;
    }

    set configuredColumns(value) {
        if (value && Array.isArray(value)) {
            this.columns = value.map((col, index) => ({
                ...col,
                id: col.id || `col-${index}-${Date.now()}`,
                displayOrder: col.displayOrder ?? index + 1
            }));
        } else {
            this.columns = [];
        }
    }

    // Get available properties (not already added as columns)
    get availableProperties() {
        const usedProperties = new Set(this.columns.map(c => c.propertyName));
        return this.notionProperties
            .filter(prop => !usedProperties.has(prop.name))
            .map(prop => ({
                label: `${prop.name} (${prop.type})`,
                value: prop.name,
                type: prop.type
            }));
    }

    get hasAvailableProperties() {
        return this.availableProperties.length > 0;
    }

    get noAvailableProperties() {
        return !this.hasAvailableProperties;
    }

    get hasColumns() {
        return this.columns.length > 0;
    }

    get noColumns() {
        return !this.hasColumns;
    }

    get noSelectedPropertyForAdd() {
        return !this.selectedPropertyForAdd;
    }

    get sortedColumns() {
        return [...this.columns].sort((a, b) => a.displayOrder - b.displayOrder);
    }

    get columnsWithMetadata() {
        return this.sortedColumns.map((col, index) => ({
            ...col,
            isFirst: index === 0,
            isLast: index === this.columns.length - 1,
            propertyTypeLabel: this.getPropertyTypeLabel(col.propertyType)
        }));
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

    // Event Handlers
    handleShowAddColumn() {
        this.isAddingColumn = true;
        this.selectedPropertyForAdd = '';
    }

    handleCancelAddColumn() {
        this.isAddingColumn = false;
        this.selectedPropertyForAdd = '';
    }

    handlePropertySelection(event) {
        this.selectedPropertyForAdd = event.detail.value;
    }

    handleAddColumn() {
        if (!this.selectedPropertyForAdd) {
            return;
        }

        const property = this.notionProperties.find(p => p.name === this.selectedPropertyForAdd);
        if (!property) {
            return;
        }

        const newColumn = {
            id: `col-${Date.now()}`,
            propertyName: property.name,
            propertyType: property.type,
            label: property.name,
            displayOrder: this.columns.length + 1,
            width: null,
            isVisible: true,
            isSortable: this.isSortableType(property.type)
        };

        this.columns = [...this.columns, newColumn];
        this.handleCancelAddColumn();
        this.notifyChange();
    }

    isSortableType(propertyType) {
        // Most Notion property types support sorting
        const sortableTypes = [
            'title', 'rich_text', 'number', 'select', 'date',
            'checkbox', 'url', 'email', 'phone_number', 'status',
            'created_time', 'last_edited_time'
        ];
        return sortableTypes.includes(propertyType);
    }

    handleRemoveColumn(event) {
        const columnId = event.target.dataset.id;
        this.columns = this.columns.filter(col => col.id !== columnId);
        this.reorderColumns();
        this.notifyChange();
    }

    handleMoveUp(event) {
        const columnId = event.target.dataset.id;
        const index = this.sortedColumns.findIndex(col => col.id === columnId);
        if (index > 0) {
            this.swapColumns(index, index - 1);
        }
    }

    handleMoveDown(event) {
        const columnId = event.target.dataset.id;
        const index = this.sortedColumns.findIndex(col => col.id === columnId);
        if (index < this.columns.length - 1) {
            this.swapColumns(index, index + 1);
        }
    }

    swapColumns(index1, index2) {
        const sorted = this.sortedColumns;
        const order1 = sorted[index1].displayOrder;
        const order2 = sorted[index2].displayOrder;

        this.columns = this.columns.map(col => {
            if (col.id === sorted[index1].id) {
                return { ...col, displayOrder: order2 };
            }
            if (col.id === sorted[index2].id) {
                return { ...col, displayOrder: order1 };
            }
            return col;
        });
        this.notifyChange();
    }

    reorderColumns() {
        // Reassign display orders to be sequential
        const sorted = this.sortedColumns;
        this.columns = this.columns.map(col => {
            const newOrder = sorted.findIndex(s => s.id === col.id) + 1;
            return { ...col, displayOrder: newOrder };
        });
    }

    handleLabelChange(event) {
        const columnId = event.target.dataset.id;
        const newLabel = event.target.value;
        this.updateColumn(columnId, { label: newLabel });
    }

    handleWidthChange(event) {
        const columnId = event.target.dataset.id;
        const newWidth = event.target.value ? parseInt(event.target.value, 10) : null;
        this.updateColumn(columnId, { width: newWidth });
    }

    handleSortableChange(event) {
        const columnId = event.target.dataset.id;
        const isSortable = event.target.checked;
        this.updateColumn(columnId, { isSortable });
    }

    handleVisibleChange(event) {
        const columnId = event.target.dataset.id;
        const isVisible = event.target.checked;
        this.updateColumn(columnId, { isVisible });
    }

    updateColumn(columnId, updates) {
        this.columns = this.columns.map(col => {
            if (col.id === columnId) {
                return { ...col, ...updates };
            }
            return col;
        });
        this.notifyChange();
    }

    notifyChange() {
        this.dispatchEvent(new CustomEvent('columnchange', {
            detail: { columns: this.columns }
        }));
    }

    // Quick actions
    handleAddAllColumns() {
        const newColumns = this.availableProperties.map((prop, index) => {
            const property = this.notionProperties.find(p => p.name === prop.value);
            return {
                id: `col-${Date.now()}-${index}`,
                propertyName: prop.value,
                propertyType: property?.type || 'rich_text',
                label: prop.value,
                displayOrder: this.columns.length + index + 1,
                width: null,
                isVisible: true,
                isSortable: this.isSortableType(property?.type)
            };
        });

        this.columns = [...this.columns, ...newColumns];
        this.notifyChange();
    }

    handleClearAllColumns() {
        this.columns = [];
        this.notifyChange();
    }
}
