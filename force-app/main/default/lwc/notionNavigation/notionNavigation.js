import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import notionLogo from '@salesforce/resourceUrl/NotionLogo';
import getNotionPageInfo from '@salesforce/apex/NotionNavigationController.getNotionPageInfo';
import syncAndGetNotionPage from '@salesforce/apex/NotionNavigationController.syncAndGetNotionPage';

const NAV_STYLE_LINK = 'link';
const ALIGN_CENTER = 'center';
const ALIGN_RIGHT = 'right';

export default class NotionNavigation extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api autoRedirect;

    // Designer-configurable presentation. Defaults match the
    // pre-customisation behaviour so an existing page picks up the new
    // properties without any visual change.
    // LWC forbids Boolean @api defaults of `true`, so for the three
    // checkboxes that should default to "on" we leave the @api
    // undefined and treat `undefined` as the default in the matching
    // getters below (titleVisible / actionLabelVisible /
    // syncOptionVisible).
    @api cardTitle = 'Notion Navigation';
    @api showTitle;
    @api navigationStyle = 'button';
    @api actionLabel = 'Open in Notion';
    @api showActionLabel;
    @api actionAlignment = 'left';
    @api syncBeforeNavigate = false;
    @api showSyncOption;

    notionUrl = null;
    loading = true;
    syncing = false;
    error = null;
    hasCheckedAutoRedirect = false;

    connectedCallback() {
        this.checkNotionPage();
    }

    @wire(getNotionPageInfo, { recordId: '$recordId', objectType: '$objectApiName' })
    wiredNotionPage({ error, data }) {
        this.loading = false;

        if (data) {
            this.notionUrl = data;
            this.error = null;

            // Auto-redirect (flow-screen only) — autoRedirect is undefined on
            // record pages, so this stays false there.
            if (this.autoRedirect === true && !this.hasCheckedAutoRedirect) {
                this.hasCheckedAutoRedirect = true;
                this.redirectToNotion();
            }
        } else if (error) {
            this.error = this.getErrorMessage(error);
            this.notionUrl = null;
        } else {
            this.notionUrl = null;
            this.error = null;
        }
    }

    checkNotionPage() {
        this.loading = true;
        this.error = null;
    }

    async navigateToNotion(event) {
        // Stop the anchor's default `#` navigation when in link style.
        if (event && event.preventDefault) {
            event.preventDefault();
        }
        try {
            // The main action follows the designer-configured default.
            if (this.syncBeforeNavigate) {
                await this.syncAndNavigate();
            } else {
                this.redirectToNotion();
            }
        } catch (e) {
            this.showError(e);
        }
    }

    // Dropdown menu attached to the main navigate button. The single
    // entry in the menu is always the *opposite* action — if the
    // designer-configured default is "navigate only", the menu offers
    // "Sync, then open"; if the default is "Sync, then open", the menu
    // offers "Open without syncing".
    async handleSyncMenuSelect(event) {
        if (event?.detail?.value !== 'alternate') return;
        try {
            if (this.syncBeforeNavigate) {
                // Default is sync — alternate is plain navigate.
                this.redirectToNotion();
            } else {
                // Default is plain navigate — alternate is sync-then-navigate.
                await this.syncAndNavigate();
            }
        } catch (e) {
            this.showError(e);
        }
    }

    async createAndNavigate(event) {
        if (event && event.preventDefault) {
            event.preventDefault();
        }
        try {
            this.syncing = true;
            this.error = null;

            const pageUrl = await syncAndGetNotionPage({
                recordId: this.recordId,
                objectType: this.objectApiName,
                operationType: 'CREATE'
            });

            this.notionUrl = pageUrl;
            this.syncing = false;

            this.showToast('Success', 'Notion page created successfully', 'success');

            this.redirectToNotion();

        } catch (e) {
            this.syncing = false;
            this.showError(e);
        }
    }

    async syncAndNavigate() {
        try {
            this.syncing = true;
            this.error = null;

            const pageUrl = await syncAndGetNotionPage({
                recordId: this.recordId,
                objectType: this.objectApiName,
                operationType: 'UPDATE'
            });

            this.notionUrl = pageUrl;
            this.syncing = false;

            this.showToast('Success', 'Record synced successfully', 'success');

            this.redirectToNotion();

        } catch (e) {
            this.syncing = false;
            this.showError(e);
        }
    }

    redirectToNotion() {
        if (this.notionUrl) {
            window.open(this.notionUrl, '_blank');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(e) {
        this.error = this.getErrorMessage(e);
        this.showToast('Error', this.error, 'error');
    }

    getErrorMessage(e) {
        if (e?.body?.message) return e.body.message;
        if (e?.message) return e.message;
        return 'An unexpected error occurred';
    }

    // ---- Computed presentation ----

    get notionLogoUrl() {
        return notionLogo;
    }

    get isLoading() {
        return this.loading || this.syncing;
    }

    get loadingMessage() {
        return this.syncing ? 'Syncing record...' : 'Checking Notion page...';
    }

    get hasNotionPage() {
        return !this.loading && this.notionUrl !== null;
    }

    get showCreateAction() {
        return !this.loading && !this.syncing && this.notionUrl === null && !this.error;
    }

    get showNavigateAction() {
        return !this.loading && !this.syncing && this.notionUrl !== null;
    }

    // The three "show ..." flags below collapse the LWC convention of
    // Boolean @api defaulting to false into the actually-desired
    // default-true behaviour by treating `undefined` (App Builder
    // hasn't written a value) as `true`.
    get titleVisible() {
        return this.showTitle !== false;
    }

    get actionLabelVisible() {
        return this.showActionLabel !== false;
    }

    get syncOptionVisible() {
        return this.showSyncOption !== false;
    }

    // When the sync option is enabled, the navigate button gets a
    // chevron dropdown next to it offering the opposite-of-default
    // action. Hidden in link style and icon-only button style (neither
    // layout pairs naturally with a chevron dropdown), and only when a
    // Notion page is known to exist.
    get showSyncDropdown() {
        return this.syncOptionVisible
            && this.showButtonWithLabel
            && this.showNavigateAction;
    }

    // Label shown on the dropdown menu item — always the alternate of
    // the designer-configured default. e.g. when `syncBeforeNavigate`
    // is true the main button syncs and the dropdown says
    // "<actionLabel> (Without Sync)"; when false it's
    // "<actionLabel> (With Sync)".
    get alternateSyncLabel() {
        const suffix = this.syncBeforeNavigate
            ? '(Without Sync)'
            : '(With Sync)';
        return `${this.actionLabel} ${suffix}`;
    }

    get isLinkStyle() {
        return this.navigationStyle === NAV_STYLE_LINK;
    }

    get isButtonStyle() {
        return !this.isLinkStyle;
    }

    // When the label is hidden in button style we fall back to
    // `lightning-button-icon` for a compact icon-only affordance.
    get showButtonWithLabel() {
        return this.isButtonStyle && this.actionLabelVisible;
    }

    get showButtonIconOnly() {
        return this.isButtonStyle && !this.actionLabelVisible;
    }

    get createLabel() {
        return 'Create Page in Notion';
    }

    get actionContainerClass() {
        const align = (this.actionAlignment || '').toLowerCase();
        let alignClass = 'slds-text-align_left';
        if (align === ALIGN_CENTER) {
            alignClass = 'slds-text-align_center';
        } else if (align === ALIGN_RIGHT) {
            alignClass = 'slds-text-align_right';
        }
        return `slds-p-vertical_small ${alignClass}`;
    }

    // For the card-less variant we drop the inner horizontal padding so
    // an embedded button / link sits flush with the parent container.
    get rootContainerClass() {
        return this.titleVisible ? 'slds-p-horizontal_medium' : '';
    }

    // LWC templates don't accept `lwc:else` against an `if:true` branch,
    // so we need an explicit inverse getter for the no-card branch.
    get isTitleHidden() {
        return !this.titleVisible;
    }
}
