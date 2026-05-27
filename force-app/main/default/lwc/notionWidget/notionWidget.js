import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWidgetData from '@salesforce/apex/NotionWidgetController.getWidgetData';
import getWidgetConfiguration from '@salesforce/apex/NotionWidgetController.getWidgetConfiguration';
import createNotionPage from '@salesforce/apex/NotionWidgetController.createNotionPage';

const RENDER_KIND = {
    TITLE: 'title',
    TEXT: 'text',
    NUMBER: 'number',
    DATE: 'date',
    CHECKBOX: 'checkbox',
    LINK: 'link',
    BADGE: 'badge',
    MULTI_BADGE: 'multi_badge',
    LINK_LIST: 'link_list',
    NAME_LIST: 'name_list',
    FILE_LIST: 'file_list'
};

const TYPE_TO_KIND = {
    title: RENDER_KIND.TITLE,
    rich_text: RENDER_KIND.TEXT,
    number: RENDER_KIND.NUMBER,
    date: RENDER_KIND.DATE,
    created_time: RENDER_KIND.DATE,
    last_edited_time: RENDER_KIND.DATE,
    checkbox: RENDER_KIND.CHECKBOX,
    url: RENDER_KIND.LINK,
    email: RENDER_KIND.LINK,
    phone_number: RENDER_KIND.LINK,
    select: RENDER_KIND.BADGE,
    status: RENDER_KIND.BADGE,
    multi_select: RENDER_KIND.MULTI_BADGE,
    relation: RENDER_KIND.LINK_LIST,
    people: RENDER_KIND.NAME_LIST,
    created_by: RENDER_KIND.TEXT,
    last_edited_by: RENDER_KIND.TEXT,
    files: RENDER_KIND.FILE_LIST,
    formula: RENDER_KIND.TEXT,
    rollup: RENDER_KIND.TEXT
};

const BADGE_COLOR_CLASS = {
    success: 'slds-theme_success',
    error: 'slds-theme_error',
    warning: 'slds-theme_warning',
    info: 'slds-theme_info',
    default: 'slds-badge'
};

export default class NotionWidget extends LightningElement {
    @api recordId;
    @api widgetDeveloperName;

    @track widgetConfig = null;
    @track rows = [];
    @track columnDefs = [];

    @track isLoading = true;
    @track isLoadingMore = false;
    @track isCreating = false;

    @track error = null;
    @track loadMoreError = null;
    @track emptyContextNotice = false;

    @track hasMore = false;
    @track nextCursor = null;

    @track sortProperty = null;
    @track sortDirection = null;

    // Session-only column-width overrides keyed by propertyName.
    // Reset on widget reload; not persisted to metadata.
    @track resizedWidths = {};
    _resizeState = null;

    connectedCallback() {
        this.loadWidget();
    }

    disconnectedCallback() {
        window.removeEventListener('mousemove', this._onResizeMove);
        window.removeEventListener('mouseup', this._onResizeEnd);
    }

    async loadWidget() {
        if (!this.widgetDeveloperName) {
            this.error = 'Widget configuration name is required';
            this.isLoading = false;
            return;
        }
        try {
            this.isLoading = true;
            this.error = null;
            const config = await getWidgetConfiguration({ widgetDeveloperName: this.widgetDeveloperName });
            if (!config) {
                this.error = `Widget configuration "${this.widgetDeveloperName}" not found`;
                this.isLoading = false;
                return;
            }
            this.widgetConfig = config;
            this.sortProperty = config.defaultSortProperty || null;
            this.sortDirection = config.defaultSortDirection || null;
            await this.loadFirstPage();
        } catch (e) {
            this.handleError(e);
        }
    }

    async loadFirstPage() {
        // Reset pagination state but keep the existing rows visible during the
        // fetch. Sort / refresh used to wipe the table to an empty spinner
        // which felt jarring; we now overlay a spinner on top of the previous
        // data and swap it in only when the new page arrives.
        this.nextCursor = null;
        this.hasMore = false;
        this.loadMoreError = null;
        this.emptyContextNotice = false;
        await this.fetchPage(null, false);
    }

    async fetchPage(cursor, isAppend) {
        if (isAppend) {
            this.isLoadingMore = true;
            this.loadMoreError = null;
        } else {
            this.isLoading = true;
            this.error = null;
        }
        try {
            const result = await getWidgetData({
                widgetDeveloperName: this.widgetDeveloperName,
                contextRecordId: this.recordId,
                sortProperty: this.sortProperty,
                sortDirection: this.sortDirection,
                startCursor: cursor,
                pageSize: this.widgetConfig?.pageSize || 25
            });

            this.columnDefs = result.columns || [];

            // Per spec 5.2, when the widget has ContextRelationProperty configured but the
            // context Notion page cannot be resolved, the server returns zero rows. Surface
            // this with a friendly empty-state message rather than the generic "no data".
            this.emptyContextNotice = !!(result.contextResolutionRequired && result.contextResolved === false);

            const transformed = this.transformRows(result.rows || []);
            this.rows = isAppend ? [...this.rows, ...transformed] : transformed;
            this.hasMore = !!result.hasMore;
            this.nextCursor = result.nextCursor || null;
        } catch (e) {
            if (isAppend) {
                // Per spec 5.4, keep existing rows and surface a local retry-capable error
                // rather than blowing the whole widget away.
                this.loadMoreError = this.extractMessage(e);
            } else {
                this.handleError(e);
            }
        } finally {
            this.isLoading = false;
            this.isLoadingMore = false;
        }
    }

    transformRows(rawRows) {
        return rawRows.map((row) => {
            const cells = this.columnDefs.map((col) => this.buildCell(row, col));
            return {
                id: row.id,
                notionUrl: row.notionUrl,
                cells
            };
        });
    }

    buildCell(row, column) {
        const value = row[column.propertyName];
        const kind = TYPE_TO_KIND[column.propertyType] || RENDER_KIND.TEXT;

        const cell = {
            key: column.propertyName,
            propertyType: column.propertyType,
            displayValue: '',
            url: null,
            color: null,
            boolValue: false,
            items: [],
            moreCount: 0,
            isTitle: false,
            isText: false,
            isNumber: false,
            isDate: false,
            isCheckbox: false,
            isLink: false,
            isBadge: false,
            isMultiBadge: false,
            isLinkList: false,
            isNameList: false,
            isFileList: false,
            badgeClass: '',
            linkClass: ''
        };

        if (value && typeof value === 'object') {
            cell.displayValue = value.displayValue || '';
            cell.url = value.url || null;
            cell.color = value.color || null;
            cell.boolValue = value.boolValue === true;
            cell.moreCount = value.moreCount || 0;
            const items = Array.isArray(value.items) ? value.items : [];
            cell.items = items.map((it, idx) => {
                const raw = it.displayValue || '';
                const untitled = raw === '';
                return {
                    key: `${column.propertyName}_${idx}_${it.rawValue || it.displayValue || idx}`,
                    displayValue: untitled ? '(untitled)' : raw,
                    url: it.url || null,
                    badgeClass: this.badgeClassFor(it.color),
                    linkClass: untitled
                        ? 'slds-m-right_xx-small notion-widget-untitled'
                        : 'slds-m-right_xx-small'
                };
            });
        } else if (value != null) {
            cell.displayValue = String(value);
        }

        cell.badgeClass = this.badgeClassFor(cell.color);

        switch (kind) {
            case RENDER_KIND.TITLE:
                cell.isTitle = true;
                if (!cell.url) {
                    cell.url = row.notionUrl;
                }
                if (!cell.displayValue) {
                    cell.displayValue = '(untitled)';
                    cell.linkClass = 'notion-widget-untitled';
                }
                break;
            case RENDER_KIND.TEXT:
                cell.isText = true;
                break;
            case RENDER_KIND.NUMBER:
                cell.isNumber = true;
                break;
            case RENDER_KIND.DATE:
                cell.isDate = true;
                break;
            case RENDER_KIND.CHECKBOX:
                cell.isCheckbox = true;
                break;
            case RENDER_KIND.LINK:
                cell.isLink = true;
                if (!cell.url && column.propertyType === 'email' && cell.displayValue) {
                    cell.url = `mailto:${cell.displayValue}`;
                } else if (!cell.url && column.propertyType === 'phone_number' && cell.displayValue) {
                    cell.url = `tel:${cell.displayValue}`;
                }
                break;
            case RENDER_KIND.BADGE:
                cell.isBadge = true;
                break;
            case RENDER_KIND.MULTI_BADGE:
                cell.isMultiBadge = true;
                break;
            case RENDER_KIND.LINK_LIST:
                cell.isLinkList = true;
                break;
            case RENDER_KIND.NAME_LIST:
                cell.isNameList = true;
                break;
            case RENDER_KIND.FILE_LIST:
                cell.isFileList = true;
                break;
            default:
                cell.isText = true;
        }
        return cell;
    }

    badgeClassFor(color) {
        const themeClass = BADGE_COLOR_CLASS[color] || '';
        return themeClass ? `slds-badge ${themeClass}` : 'slds-badge';
    }

    // ---- Event handlers ----
    handleSortClick(event) {
        const propertyName = event.currentTarget.dataset.property;
        if (!propertyName) return;
        let newDirection = 'ascending';
        if (this.sortProperty === propertyName && this.sortDirection === 'ascending') {
            newDirection = 'descending';
        }
        this.sortProperty = propertyName;
        this.sortDirection = newDirection;
        // Sort change discards accumulated rows; cursors depend on sort.
        this.loadFirstPage();
    }

    handleLoadMore() {
        if (!this.hasMore || this.isLoadingMore || !this.nextCursor) {
            return;
        }
        this.fetchPage(this.nextCursor, true);
    }

    handleRetryLoadMore() {
        this.fetchPage(this.nextCursor, true);
    }

    handleRefresh() {
        this.loadFirstPage();
    }

    // ---- Column resize (session only) ----
    handleResizeStart = (event) => {
        event.preventDefault();
        event.stopPropagation();
        const propertyName = event.currentTarget.dataset.property;
        const th = event.currentTarget.closest('th');
        if (!th) return;
        this._resizeState = {
            propertyName,
            startX: event.clientX,
            startWidth: th.getBoundingClientRect().width
        };
        window.addEventListener('mousemove', this._onResizeMove);
        window.addEventListener('mouseup', this._onResizeEnd);
    };

    _onResizeMove = (event) => {
        if (!this._resizeState) return;
        const delta = event.clientX - this._resizeState.startX;
        const newWidth = Math.max(40, Math.round(this._resizeState.startWidth + delta));
        this.resizedWidths = {
            ...this.resizedWidths,
            [this._resizeState.propertyName]: newWidth
        };
    };

    _onResizeEnd = () => {
        window.removeEventListener('mousemove', this._onResizeMove);
        window.removeEventListener('mouseup', this._onResizeEnd);
        this._resizeState = null;
    };

    async handleCreate() {
        if (this.isCreating) return;
        try {
            this.isCreating = true;
            const result = await createNotionPage({
                widgetDeveloperName: this.widgetDeveloperName,
                contextRecordId: this.recordId || null
            });
            if (result && result.pageUrl) {
                window.open(result.pageUrl, '_blank', 'noopener');
            }
            this.showToast('Page Created', 'New Notion page opened in a new tab', 'success');
            await this.loadFirstPage();
        } catch (e) {
            this.showToast('Create Failed', this.extractMessage(e), 'error');
        } finally {
            this.isCreating = false;
        }
    }

    // ---- Error helpers ----
    handleError(error) {
        // eslint-disable-next-line no-console
        console.error('Widget error:', error);
        this.error = this.extractMessage(error);
        this.isLoading = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: this.error,
            variant: 'error'
        }));
    }

    extractMessage(error) {
        return error?.body?.message || error?.message || 'An unknown error occurred';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ---- Computed properties ----
    get hasError() {
        return !!this.error;
    }

    get hasData() {
        return this.rows && this.rows.length > 0;
    }

    // Full-screen spinner only on the very first load (no rows yet).
    // Subsequent sort / refresh shows an overlay spinner on top of the table.
    get showInitialSpinner() {
        return this.isLoading && !this.hasData;
    }

    get showRefreshOverlay() {
        return this.isLoading && this.hasData;
    }

    get widgetTitle() {
        return this.widgetConfig?.label || '';
    }

    get headerColumns() {
        return this.columnDefs.map((col) => {
            const isSorted = this.sortProperty === col.propertyName;
            const direction = isSorted ? this.sortDirection : null;
            const effectiveWidth = this.resizedWidths[col.propertyName] ?? col.width;
            const ariaSort = col.sortable
                ? (direction === 'ascending' ? 'ascending'
                    : direction === 'descending' ? 'descending' : 'none')
                : null;
            // SLDS data table th classes. Native lightning-datatable applies
            // `slds-is-sorted_asc` even on unsorted-but-sortable columns so
            // that the hover preview of the sort icon points up — matching
            // the direction the first click will take (ascending). Without
            // `slds-is-sorted` the icon stays hidden until hovered (SLDS only
            // promotes it to inline-block on `:hover` or when sorted).
            const classes = ['slds-is-resizable'];
            if (col.sortable) {
                classes.push('slds-is-sortable');
                if (direction !== null) {
                    classes.push('slds-is-sorted');
                }
                classes.push(direction === 'descending'
                    ? 'slds-is-sorted_desc'
                    : 'slds-is-sorted_asc');
            }
            return {
                key: col.propertyName,
                label: col.label || col.propertyName,
                propertyName: col.propertyName,
                isSortable: !!col.sortable,
                width: effectiveWidth ? `width: ${effectiveWidth}px;` : '',
                ariaSort,
                thClass: classes.join(' '),
                // SLDS data-table convention: icon-name stays fixed
                // (`utility:arrowdown`) and SLDS rotates it 180deg via the
                // `slds-is-sorted_asc` class on the <th>. Switching icon-name
                // dynamically here cancels out that rotation.
                sortIcon: 'utility:arrowdown'
            };
        });
    }

    get noDataMessage() {
        if (this.emptyContextNotice) {
            return 'No related Notion page exists for the current record yet.';
        }
        if (this.widgetConfig?.contextObjectApiName && !this.recordId) {
            return 'This widget requires a record context. Place it on a record page.';
        }
        return 'No data found in the configured Notion database.';
    }

    get showLoadMore() {
        return this.hasData && this.hasMore;
    }

    get showLoadMoreError() {
        return !!this.loadMoreError;
    }

    get showNewButton() {
        if (!this.widgetConfig) return false;
        return this.widgetConfig.showNewButton !== false;
    }

    get createDisabled() {
        return this.isCreating || this.isLoading;
    }

    get loadMoreDisabled() {
        return this.isLoadingMore;
    }
}
