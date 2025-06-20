import { createElement } from 'lwc';
import NotionSyncSummary from 'c/notionSyncSummary';
import getAllSyncConfigurations from '@salesforce/apex/NotionAdminController.getAllSyncConfigurations';

// Mock Apex methods
jest.mock(
    '@salesforce/apex/NotionAdminController.getAllSyncConfigurations',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

describe('c-notion-sync-summary', () => {
    afterEach(() => {
        // Clear all mocked data between tests
        jest.clearAllMocks();
    });

    it('renders manage buttons and handles navigation', async () => {
        const mockConfigs = [
            {
                objectApiName: 'Account',
                notionDatabaseId: 'abc123',
                isActive: true,
                objectMetadataId: 'm01234567890ABC',
                fieldMappings: [],
                relationshipMappings: []
            }
        ];

        getAllSyncConfigurations.mockResolvedValue(mockConfigs);

        // Create component
        const element = createElement('c-notion-sync-summary', {
            is: NotionSyncSummary
        });
        document.body.appendChild(element);

        // Wait for async operations
        await Promise.resolve();

        // Check that Manage in Setup button exists
        const manageInSetupButton = element.shadowRoot.querySelector('lightning-button[label="Manage in Setup"]');
        expect(manageInSetupButton).toBeTruthy();

        // Check that individual Manage button exists
        const manageButtons = element.shadowRoot.querySelectorAll('lightning-button[label="Manage"]');
        expect(manageButtons.length).toBe(1);
        expect(manageButtons[0].dataset.metadataId).toBe('m01234567890ABC');

        // Mock window.open
        const mockOpen = jest.fn();
        window.open = mockOpen;

        // Test Manage in Setup button click
        manageInSetupButton.click();
        expect(mockOpen).toHaveBeenCalledWith('/lightning/setup/CustomMetadata/home', '_blank');

        // Test individual Manage button click
        manageButtons[0].click();
        expect(mockOpen).toHaveBeenCalledWith('/lightning/setup/CustomMetadataRecordDetail/page?address=%2Fm01234567890ABC', '_blank');
    });

    it('shows alternative message in delete confirmation modal', async () => {
        const mockConfigs = [
            {
                objectApiName: 'Account',
                notionDatabaseId: 'abc123',
                isActive: true,
                objectMetadataId: 'm01234567890ABC',
                fieldMappings: [],
                relationshipMappings: []
            }
        ];

        getAllSyncConfigurations.mockResolvedValue(mockConfigs);

        // Create component
        const element = createElement('c-notion-sync-summary', {
            is: NotionSyncSummary
        });
        document.body.appendChild(element);

        // Wait for async operations
        await Promise.resolve();

        // Click delete button
        const deleteButton = element.shadowRoot.querySelector('lightning-button[label="Delete"]');
        deleteButton.click();

        // Wait for modal to render
        await Promise.resolve();

        // Check for alternative message in modal
        const modalContent = element.shadowRoot.querySelector('.slds-modal__content');
        expect(modalContent.textContent).toContain('Alternative: You can also manage Custom Metadata records directly in Setup');
    });
});