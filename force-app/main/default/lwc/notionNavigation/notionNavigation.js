import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getNotionPageInfo from '@salesforce/apex/NotionNavigationController.getNotionPageInfo';
import syncAndGetNotionPage from '@salesforce/apex/NotionNavigationController.syncAndGetNotionPage';

export default class NotionNavigation extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api autoRedirect;
    @api showSyncOption;
    
    notionUrl = null;
    loading = true;
    syncing = false;
    error = null;
    syncBeforeNav = false;
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
            
            // Auto-redirect if enabled and not already redirected
            // Note: autoRedirect will be undefined on record pages, which is intentional
            if (this.autoRedirect === true && !this.hasCheckedAutoRedirect) {
                this.hasCheckedAutoRedirect = true;
                this.redirectToNotion();
            }
        } else if (error) {
            this.error = this.getErrorMessage(error);
            this.notionUrl = null;
        } else {
            // No page found
            this.notionUrl = null;
            this.error = null;
        }
    }
    
    checkNotionPage() {
        this.loading = true;
        this.error = null;
    }
    
    handleSyncCheckbox(event) {
        this.syncBeforeNav = event.target.checked;
    }
    
    async navigateToNotion() {
        try {
            if (this.syncBeforeNav) {
                await this.syncAndNavigate();
            } else {
                this.redirectToNotion();
            }
        } catch (error) {
            this.showError(error);
        }
    }
    
    async createAndNavigate() {
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
            
            // Navigate to the new page
            this.redirectToNotion();
            
        } catch (error) {
            this.syncing = false;
            this.showError(error);
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
            
            // Navigate after sync
            this.redirectToNotion();
            
        } catch (error) {
            this.syncing = false;
            this.showError(error);
        }
    }
    
    redirectToNotion() {
        if (this.notionUrl) {
            window.open(this.notionUrl, '_blank');
        }
    }
    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
    
    showError(error) {
        this.error = this.getErrorMessage(error);
        this.showToast('Error', this.error, 'error');
    }
    
    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        }
        return 'An unexpected error occurred';
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
    
    get showCreateButton() {
        return !this.loading && !this.syncing && this.notionUrl === null && !this.error;
    }
    
    get showNavigateButton() {
        return !this.loading && !this.syncing && this.notionUrl !== null;
    }
    
    get showSyncCheckbox() {
        return this.showSyncOption && this.hasNotionPage && !this.syncing;
    }
}