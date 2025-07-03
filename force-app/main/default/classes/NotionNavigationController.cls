/**
 * Controller for Notion Navigation Lightning Web Component
 * Handles page lookup and sync operations for navigation
 */
public with sharing class NotionNavigationController {
    
    /**
     * Get Notion page URL for a Salesforce record
     * @param recordId Salesforce record ID
     * @param objectType Object API name
     * @return Notion page URL if exists, null otherwise
     */
    @AuraEnabled(cacheable=true)
    public static String getNotionPageInfo(String recordId, String objectType) {
        try {
            // Get sync configuration
            NotionSyncObject__mdt syncConfig = getSyncConfiguration(objectType);
            if (syncConfig == null || !syncConfig.IsActive__c) {
                return null;
            }
            
            // Find Notion page ID
            String notionPageId = findNotionPageId(recordId, syncConfig);
            if (String.isBlank(notionPageId)) {
                return null;
            }
            
            // Format and return Notion URL
            return formatNotionUrl(notionPageId);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Notion page: ' + e.getMessage());
        }
    }
    
    /**
     * Sync record to Notion and return the page URL
     * @param recordId Salesforce record ID
     * @param objectType Object API name
     * @param operationType CREATE or UPDATE
     * @return Notion page URL after sync
     */
    @AuraEnabled
    public static String syncAndGetNotionPage(String recordId, String objectType, String operationType) {
        try {
            // First check if sync configuration exists
            NotionSyncObject__mdt syncConfig = getSyncConfiguration(objectType);
            if (syncConfig == null) {
                throw new AuraHandledException('No sync configuration found for ' + objectType);
            }
            if (!syncConfig.IsActive__c) {
                throw new AuraHandledException('Sync configuration for ' + objectType + ' is not active');
            }
            
            // Verify the record exists
            String query = 'SELECT Id, Name FROM ' + objectType + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(query);
            if (records.isEmpty()) {
                throw new AuraHandledException('Record not found: ' + recordId);
            }
            
            // Create sync request
            NotionSync.Request syncRequest = new NotionSync.Request(recordId, objectType, operationType);
            List<NotionSync.Request> requests = new List<NotionSync.Request>{ syncRequest };
            
            // Create a logger but DO NOT flush it yet (no DML before callouts)
            NotionSyncLogger logger = new NotionSyncLogger();
            NotionSyncProcessor processor = new NotionSyncProcessor(logger);
            
            // Store the page ID from the sync process
            String createdPageId = null;
            
            try {
                // Process sync - this will make callouts but NOT perform DML
                processor.processSyncRequests(requests);
                
                // Extract the page ID from the logger entries if successful
                List<NotionSyncLogger.LogEntry> entries = logger.getPendingEntries();
                for (NotionSyncLogger.LogEntry entry : entries) {
                    if (entry.recordId == recordId && String.isNotBlank(entry.notionPageId)) {
                        createdPageId = entry.notionPageId;
                        break;
                    }
                }
                
            } catch (Exception syncEx) {
                System.debug('Sync error details: ' + syncEx.getMessage());
                System.debug('Stack trace: ' + syncEx.getStackTraceString());
                // Log the error but don't flush yet
                logger.log(
                    new NotionSyncLogger.LogEntry(operationType)
                        .withRecord(objectType, recordId)
                        .withStatus('Failed')
                        .withMessage('Sync failed: ' + syncEx.getMessage())
                );
                
                // Now we can flush the logs (DML after callout is complete)
                logger.flush();
                
                throw new AuraHandledException('Sync failed: ' + syncEx.getMessage());
            }
            
            // Sync completed successfully - now we can do DML
            logger.flush();
            
            // If we have the page ID from the create operation, format and return it
            if (String.isNotBlank(createdPageId)) {
                return formatNotionUrl(createdPageId);
            }
            
            // Otherwise, query for the page (this is a fallback)
            // Wait a moment for Notion to process
            Long startTime = System.currentTimeMillis();
            while (System.currentTimeMillis() - startTime < 2000) {
                // Brief wait
            }
            
            // Get the page URL after sync
            String pageUrl = getNotionPageInfo(recordId, objectType);
            if (String.isBlank(pageUrl)) {
                throw new AuraHandledException('Sync completed but page URL not found. Please try again.');
            }
            
            return pageUrl;
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as is
            throw e;
        } catch (Exception e) {
            System.debug('Unexpected error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }
    
    /**
     * Get sync configuration for an object type
     */
    private static NotionSyncObject__mdt getSyncConfiguration(String objectType) {
        // Use static SOQL with field references that work in both namespaced and non-namespaced contexts
        List<NotionSyncObject__mdt> configs = [
            SELECT Id, ObjectApiName__c, NotionDatabaseId__c, IsActive__c, SalesforceIdPropertyName__c
            FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectType
            LIMIT 1
        ];
        
        return configs.isEmpty() ? null : configs[0];
    }
    
    /**
     * Find Notion page ID by querying Notion database
     */
    private static String findNotionPageId(String salesforceId, NotionSyncObject__mdt syncConfig) {
        Map<String, Object> filter = new Map<String, Object>{
            'property' => syncConfig.SalesforceIdPropertyName__c,
            'rich_text' => new Map<String, Object>{
                'equals' => salesforceId
            }
        };
        
        NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(
            syncConfig.NotionDatabaseId__c, 
            filter
        );
        
        if (response.success && String.isNotBlank(response.responseBody)) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
            List<Object> results = (List<Object>) responseBody.get('results');
            
            if (!results.isEmpty()) {
                Map<String, Object> page = (Map<String, Object>) results[0];
                return (String) page.get('id');
            }
        }
        
        return null;
    }
    
    /**
     * Format Notion page ID into a proper Notion URL
     * Uses the direct page ID format that Notion supports
     * Converts: 1429989fe8ac4effbc8f57f56486db54
     * To: https://www.notion.so/1429989fe8ac4effbc8f57f56486db54
     * Note: The hyphenated format is not required for navigation
     */
    private static String formatNotionUrl(String pageId) {
        if (String.isBlank(pageId)) {
            return null;
        }
        
        // Remove any existing hyphens for consistency
        String cleanId = pageId.replaceAll('-', '');
        
        // Return the direct URL format
        // This format works without needing the workspace name
        return 'https://www.notion.so/' + cleanId;
    }
}