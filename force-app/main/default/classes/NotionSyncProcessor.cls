/**
 * Processor class that handles the core sync logic
 * Accepts a logger instance for dependency injection
 */
public class NotionSyncProcessor {
    private NotionRelationshipHandler relationshipHandler;
    private NotionSyncLogger logger;
    
    public NotionSyncProcessor(NotionSyncLogger logger) {
        this.relationshipHandler = new NotionRelationshipHandler();
        this.logger = logger;
    }
    
    /**
     * Process sync requests
     * @param syncRequests List of sync requests to process
     */
    public void processSyncRequests(List<NotionSync.Request> syncRequests) {
        Map<String, List<NotionSync.Request>> requestsByObjectType = groupRequestsByObjectType(syncRequests);
        
        List<String> processingOrder = relationshipHandler.getProcessingOrder(requestsByObjectType.keySet());
        
        for (String objectType : processingOrder) {
            if (requestsByObjectType.containsKey(objectType)) {
                List<NotionSync.Request> objectRequests = requestsByObjectType.get(objectType);
                processObjectRequests(objectType, objectRequests);
            }
        }
    }
    
    private Map<String, List<NotionSync.Request>> groupRequestsByObjectType(List<NotionSync.Request> syncRequests) {
        Map<String, List<NotionSync.Request>> grouped = new Map<String, List<NotionSync.Request>>();
        
        for (NotionSync.Request request : syncRequests) {
            if (!grouped.containsKey(request.objectType)) {
                grouped.put(request.objectType, new List<NotionSync.Request>());
            }
            grouped.get(request.objectType).add(request);
        }
        
        return grouped;
    }
    
    private void processObjectRequests(String objectType, List<NotionSync.Request> objectRequests) {
        NotionSyncObject__mdt syncConfig = getSyncConfiguration(objectType);
        if (syncConfig == null) {
            logErrorsForRequests(objectRequests, 'No sync configuration found for object type: ' + objectType);
            return;
        }
        
        if (!syncConfig.IsActive__c) {
            logErrorsForRequests(objectRequests, 'Sync is disabled for object type: ' + objectType);
            return;
        }
        
        List<NotionSyncField__mdt> fieldMappings = getFieldMappings(syncConfig.Id);
        Map<Id, SObject> recordsMap = getRecords(objectType, objectRequests);
        
        for (NotionSync.Request request : objectRequests) {
            processSingleRequest(request, syncConfig, fieldMappings, recordsMap.get(request.recordId));
        }
    }
    
    private void logErrorsForRequests(List<NotionSync.Request> requests, String errorMessage) {
        for (NotionSync.Request request : requests) {
            logger.log(
                new NotionSyncLogger.LogEntry(request.operationType)
                    .withRecord(request.objectType, request.recordId)
                    .withError(errorMessage)
            );
        }
    }
    
    private NotionSyncObject__mdt getSyncConfiguration(String objectType) {
        List<NotionSyncObject__mdt> configs = [
            SELECT Id, ObjectApiName__c, NotionDatabaseId__c, IsActive__c, SalesforceIdPropertyName__c
            FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectType
            LIMIT 1
        ];
        
        return configs.isEmpty() ? null : configs[0];
    }
    
    private List<NotionSyncField__mdt> getFieldMappings(Id syncObjectId) {
        return [
            SELECT SalesforceFieldApiName__c, NotionPropertyName__c, NotionPropertyType__c, IsBodyContent__c
            FROM NotionSyncField__mdt
            WHERE NotionSyncObject__c = :syncObjectId
        ];
    }
    
    private Map<Id, SObject> getRecords(String objectType, List<NotionSync.Request> objectRequests) {
        Set<Id> recordIds = new Set<Id>();
        List<NotionSync.Request> nonDeleteRequests = new List<NotionSync.Request>();
        
        for (NotionSync.Request request : objectRequests) {
            if (request.operationType != 'DELETE') {
                recordIds.add(request.recordId);
                nonDeleteRequests.add(request);
            }
        }
        
        if (recordIds.isEmpty()) {
            return new Map<Id, SObject>();
        }
        
        String query = buildDynamicQuery(objectType, recordIds);
        List<SObject> records = Database.query(query);
        
        Map<Id, SObject> recordsMap = new Map<Id, SObject>();
        for (SObject record : records) {
            recordsMap.put(record.Id, record);
        }
        
        return recordsMap;
    }
    
    private String buildDynamicQuery(String objectType, Set<Id> recordIds) {
        String baseQuery = 'SELECT Id';
        
        List<NotionSyncField__mdt> fieldMappings = [
            SELECT SalesforceFieldApiName__c
            FROM NotionSyncField__mdt
            WHERE NotionSyncObject__r.ObjectApiName__c = :objectType
        ];
        
        Set<String> fieldsToQuery = new Set<String>();
        for (NotionSyncField__mdt mapping : fieldMappings) {
            fieldsToQuery.add(mapping.SalesforceFieldApiName__c);
        }
        
        // Also query relationship fields
        List<NotionRelation__mdt> relations = [
            SELECT SalesforceRelationshipField__c
            FROM NotionRelation__mdt
            WHERE ChildObject__r.ObjectApiName__c = :objectType
        ];
        
        for (NotionRelation__mdt relation : relations) {
            if (String.isNotBlank(relation.SalesforceRelationshipField__c)) {
                fieldsToQuery.add(relation.SalesforceRelationshipField__c);
            }
        }
        
        if (!fieldsToQuery.isEmpty()) {
            baseQuery += ', ' + String.join(new List<String>(fieldsToQuery), ', ');
        }
        
        baseQuery += ' FROM ' + objectType + ' WHERE Id IN :recordIds';
        
        return baseQuery;
    }
    
    private void processSingleRequest(NotionSync.Request request, NotionSyncObject__mdt syncConfig, 
                                    List<NotionSyncField__mdt> fieldMappings, SObject record) {
        try {
            String notionPageId = null;
            
            if (request.operationType == 'DELETE') {
                handleDeleteOperation(request, syncConfig);
            } else {
                notionPageId = handleCreateOrUpdateOperation(request, syncConfig, fieldMappings, record);
            }
            
            // Log success
            logger.log(
                new NotionSyncLogger.LogEntry(request.operationType)
                    .withRecord(request.objectType, request.recordId)
                    .withStatus('Success')
                    .withNotionPageId(notionPageId)
            );
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Handle rate limit specifically
            logger.log(
                new NotionSyncLogger.LogEntry(request.operationType)
                    .withRecord(request.objectType, request.recordId)
                    .withError(e.getMessage())
                    .withRateLimit(1)  // Default to 1 second retry
            );
        } catch (Exception e) {
            // Log error
            logger.log(
                new NotionSyncLogger.LogEntry(request.operationType)
                    .withRecord(request.objectType, request.recordId)
                    .withError(e.getMessage())
            );
        }
    }
    
    private void handleDeleteOperation(NotionSync.Request request, NotionSyncObject__mdt syncConfig) {
        String notionPageId = findNotionPageId(request.recordId, syncConfig);
        if (String.isNotBlank(notionPageId)) {
            deleteNotionPage(notionPageId);
        }
    }
    
    private String handleCreateOrUpdateOperation(NotionSync.Request request, NotionSyncObject__mdt syncConfig, 
                                            List<NotionSyncField__mdt> fieldMappings, SObject record) {
        if (record == null) {
            throw new NotionSync.SyncException('Record not found: ' + request.recordId);
        }
        
        Map<String, Object> notionProperties = transformDataToNotionFormat(record, fieldMappings);
        notionProperties = relationshipHandler.enrichNotionPropertiesWithRelations(request.objectType, record, notionProperties);
        
        // For CREATE operations, don't check for existing page - just create
        if (request.operationType == 'CREATE') {
            // Add Salesforce ID as a rich_text property
            notionProperties.put(syncConfig.SalesforceIdPropertyName__c, 
                               NotionApiClient.buildTextProperty(request.recordId));
            return createNotionPage(syncConfig.NotionDatabaseId__c, notionProperties);
        }
        
        // For UPDATE operations, find and update existing page
        String notionPageId = findNotionPageId(request.recordId, syncConfig);
        
        if (String.isNotBlank(notionPageId)) {
            updateNotionPage(notionPageId, notionProperties);
            return notionPageId;
        } else {
            // If UPDATE operation but no page found, create it (handles edge cases)
            notionProperties.put(syncConfig.SalesforceIdPropertyName__c, 
                               NotionApiClient.buildTextProperty(request.recordId));
            return createNotionPage(syncConfig.NotionDatabaseId__c, notionProperties);
        }
    }
    
    private Map<String, Object> transformDataToNotionFormat(SObject record, List<NotionSyncField__mdt> fieldMappings) {
        Map<String, Object> properties = new Map<String, Object>();
        String bodyContent = '';
        
        for (NotionSyncField__mdt mapping : fieldMappings) {
            Object fieldValue = record.get(mapping.SalesforceFieldApiName__c);
            
            if (mapping.IsBodyContent__c) {
                // If this field is marked as body content, add it to body content
                // Important: Include null values to support clearing content
                bodyContent = fieldValue != null ? String.valueOf(fieldValue) : '';
                // Skip adding it to properties - continue to next field
                continue;
            }
            
            // For regular properties (not body content)
            // For properties that support clearing, we need to include null values
            String propertyType = mapping.NotionPropertyType__c.toLowerCase();
            Boolean supportsClearing = propertyType == 'title' || 
                                     propertyType == 'rich_text' || 
                                     propertyType == 'number' ||
                                     propertyType == 'select' ||
                                     propertyType == 'date' ||
                                     propertyType == 'email';
            
            if (fieldValue != null || supportsClearing) {
                properties.put(mapping.NotionPropertyName__c, 
                             formatValueForNotionProperty(fieldValue, mapping.NotionPropertyType__c));
            }
        }
        
        // Always include body content in properties, even if empty
        // This ensures the update method knows when to clear content
        if (bodyContent != null) {
            properties.put('body', bodyContent);
        }
        
        return properties;
    }
    
    private Object formatValueForNotionProperty(Object value, String propertyType) {
        switch on propertyType {
            when 'title' {
                String textValue = value != null ? String.valueOf(value) : '';
                return NotionApiClient.buildTitleProperty(textValue);
            }
            when 'rich_text' {
                String textValue = value != null ? String.valueOf(value) : '';
                return NotionApiClient.buildTextProperty(textValue);
            }
            when 'number' {
                if (value == null) {
                    return NotionApiClient.buildNumberProperty(null);
                }
                Decimal numValue = value instanceof Decimal ? (Decimal)value : Decimal.valueOf(String.valueOf(value));
                return NotionApiClient.buildNumberProperty(numValue);
            }
            when 'checkbox' {
                return NotionApiClient.buildCheckboxProperty(value != null ? Boolean.valueOf(value) : null);
            }
            when 'date' {
                if (value == null) {
                    return NotionApiClient.buildDateProperty(null);
                } else if (value instanceof Date) {
                    return NotionApiClient.buildDateProperty((Date)value);
                } else if (value instanceof DateTime) {
                    return NotionApiClient.buildDateTimeProperty((DateTime)value);
                }
                return null;
            }
            when 'select' {
                String selectValue = value != null ? String.valueOf(value) : null;
                return NotionApiClient.buildSelectProperty(selectValue);
            }
            when 'email' {
                // Always return email property to support clearing (null) in Notion
                String emailValue = value != null ? String.valueOf(value) : '';
                return NotionApiClient.buildEmailProperty(emailValue);
            }
            when else {
                // Default to rich_text for unknown types
                return NotionApiClient.buildTextProperty(String.valueOf(value));
            }
        }
    }
    
    private String findNotionPageId(String salesforceId, NotionSyncObject__mdt syncConfig) {
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
        } else if (response.isRateLimited) {
            throw new NotionRateLimiter.RateLimitException(
                'Rate limited while querying database. Retry after: ' + response.retryAfterSeconds
            );
        } else if (!response.success) {
            throw new NotionSync.SyncException('Failed to query Notion database: ' + response.errorMessage);
        }
        
        return null;
    }
    
    private String createNotionPage(String databaseId, Map<String, Object> properties) {
        // Extract body content before building properties
        String bodyContent = (String) properties.get('body');
        List<Object> children = null;
        
        if (String.isNotBlank(bodyContent)) {
            children = buildNotionChildren(bodyContent);
        }
        
        // Build properties (excluding body)
        Map<String, Object> notionProps = buildNotionProperties(properties);
        
        NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
            databaseId,
            notionProps,
            children
        );
        
        NotionApiClient.NotionResponse response = NotionApiClient.createPage(pageRequest);
        
        if (response.success) {
            return response.pageId;
        } else if (response.isRateLimited) {
            throw new NotionRateLimiter.RateLimitException(
                'Rate limited while creating page. Retry after: ' + response.retryAfterSeconds
            );
        } else {
            throw new NotionSync.SyncException('Failed to create Notion page: ' + response.errorMessage);
        }
    }
    
    private String updateNotionPage(String pageId, Map<String, Object> properties) {
        // Extract body content before building properties
        String bodyContent = (String) properties.get('body');
        
        // Build properties (excluding body)
        Map<String, Object> notionProps = buildNotionProperties(properties);
        
        // Update page properties first
        NotionApiClient.NotionResponse response = NotionApiClient.updatePage(pageId, notionProps);
        
        if (!response.success) {
            if (response.isRateLimited) {
                throw new NotionRateLimiter.RateLimitException(
                    'Rate limited while updating page. Retry after: ' + response.retryAfterSeconds
                );
            } else {
                throw new NotionSync.SyncException('Failed to update Notion page: ' + response.errorMessage);
            }
        }
        
        // Handle body content update - including clearing content when null/empty
        // Get existing blocks to check if content has changed
        NotionApiClient.NotionResponse blocksResponse = NotionApiClient.getPageBlocks(pageId);
        
        Boolean bodyContentChanged = false;
        List<Object> existingBlocks = null;
        
        if (blocksResponse.success && blocksResponse.responseBody != null) {
            Map<String, Object> blockData = (Map<String, Object>) JSON.deserializeUntyped(blocksResponse.responseBody);
            existingBlocks = (List<Object>) blockData.get('results');
            
            // Extract current content from blocks
            String currentContent = extractContentFromBlocks(existingBlocks);
            
            // Normalize content for comparison (treat null and empty string as equivalent)
            String normalizedNewContent = String.isBlank(bodyContent) ? '' : bodyContent;
            String normalizedCurrentContent = String.isBlank(currentContent) ? '' : currentContent;
            
            // Compare normalized content
            bodyContentChanged = !normalizedNewContent.equals(normalizedCurrentContent);
            
            if (bodyContentChanged) {
                System.debug('Body content has changed from "' + currentContent + '" to "' + bodyContent + '"');
            } else {
                System.debug('Body content unchanged, skipping block update for page: ' + pageId);
            }
        } else {
            // If we can't get existing blocks, assume content changed
            System.debug('Could not retrieve existing blocks, assuming content changed');
            bodyContentChanged = true;
        }
        
        // Only update if content has actually changed
        if (bodyContentChanged) {
            // Delete existing blocks if any
            if (existingBlocks != null && !existingBlocks.isEmpty()) {
                System.debug('Deleting ' + existingBlocks.size() + ' existing blocks');
                for (Object blockObj : existingBlocks) {
                    Map<String, Object> block = (Map<String, Object>) blockObj;
                    String blockId = (String) block.get('id');
                    if (blockId != null) {
                        NotionApiClient.deleteBlock(blockId);
                    }
                }
            }
            
            // Only append new content if it's not blank
            if (String.isNotBlank(bodyContent)) {
                System.debug('Appending new body content');
                List<Object> children = buildNotionChildren(bodyContent);
                NotionApiClient.NotionResponse appendResponse = NotionApiClient.appendPageBlocks(pageId, children);
                
                if (!appendResponse.success) {
                    System.debug('Warning: Failed to update body content for page ' + pageId + ': ' + appendResponse.errorMessage);
                }
            } else {
                System.debug('Body content is empty, page will have no blocks');
            }
        }
        
        return response.pageId;
    }
    
    private void deleteNotionPage(String pageId) {
        NotionApiClient.NotionResponse response = NotionApiClient.deletePage(pageId);
        
        if (!response.success) {
            if (response.isRateLimited) {
                throw new NotionRateLimiter.RateLimitException(
                    'Rate limited while deleting page. Retry after: ' + response.retryAfterSeconds
                );
            } else {
                throw new NotionSync.SyncException('Failed to delete Notion page: ' + response.errorMessage);
            }
        }
    }
    
    private Map<String, Object> buildNotionProperties(Map<String, Object> properties) {
        Map<String, Object> notionProps = new Map<String, Object>();
        
        for (String key : properties.keySet()) {
            if (key != 'body') {
                // Include all properties, even null values, to support clearing
                notionProps.put(key, properties.get(key));
            }
        }
        
        return notionProps;
    }
    
    private List<Object> buildNotionChildren(String bodyContent) {
        List<Object> children = new List<Object>();
        children.add(new Map<String, Object>{
            'object' => 'block',
            'type' => 'paragraph',
            'paragraph' => new Map<String, Object>{
                'rich_text' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'text',
                        'text' => new Map<String, Object>{ 'content' => bodyContent }
                    }
                }
            }
        });
        return children;
    }
    
    private String extractContentFromBlocks(List<Object> blocks) {
        if (blocks == null || blocks.isEmpty()) {
            return '';
        }
        
        String extractedContent = '';
        
        for (Object blockObj : blocks) {
            Map<String, Object> block = (Map<String, Object>) blockObj;
            String blockType = (String) block.get('type');
            
            // Currently we only create paragraph blocks, so we'll only extract from those
            if (blockType == 'paragraph') {
                Map<String, Object> paragraph = (Map<String, Object>) block.get('paragraph');
                if (paragraph != null) {
                    List<Object> richTextArray = (List<Object>) paragraph.get('rich_text');
                    if (richTextArray != null && !richTextArray.isEmpty()) {
                        for (Object richTextObj : richTextArray) {
                            Map<String, Object> richText = (Map<String, Object>) richTextObj;
                            String plainText = (String) richText.get('plain_text');
                            if (plainText != null) {
                                extractedContent += plainText;
                            }
                        }
                    }
                }
            }
        }
        
        return extractedContent;
    }
    
    /**
     * Result class for deduplication operations
     */
    public class DeduplicationResult {
        public Integer duplicatesFound = 0;
        public Integer duplicatesDeleted = 0;
        public Boolean deferred = false;
        
        public DeduplicationResult() {}
    }
    
    /**
     * Deduplicate Notion pages for given Salesforce records
     * @param recordIds Set of Salesforce record IDs to check for duplicates
     * @param syncConfig Sync configuration containing database and property mappings
     * @param maxDeletions Maximum number of deletions to perform (for governor limit management)
     * @return DeduplicationResult containing statistics and deferral status
     */
    public DeduplicationResult deduplicateNotionPages(Set<Id> recordIds, NotionSyncObject__mdt syncConfig, Integer maxDeletions) {
        DeduplicationResult result = new DeduplicationResult();
        
        if (recordIds == null || recordIds.isEmpty() || syncConfig == null) {
            return result;
        }
        
        try {
            // Query all pages with these Salesforce IDs
            List<Map<String, Object>> allPages = queryPagesForDeduplication(syncConfig, recordIds);
            
            if (allPages.isEmpty()) {
                return result;
            }
            
            // Group pages by Salesforce ID
            Map<String, List<Map<String, Object>>> pagesBySalesforceId = groupPagesBySalesforceId(
                allPages, 
                syncConfig.SalesforceIdPropertyName__c
            );
            
            // Process duplicates with rate limiting
            Integer deletionCount = 0;
            
            for (String salesforceId : pagesBySalesforceId.keySet()) {
                List<Map<String, Object>> pages = pagesBySalesforceId.get(salesforceId);
                
                if (pages.size() > 1) {
                    result.duplicatesFound += pages.size() - 1;
                    
                    // Sort by created_time (oldest first)
                    pages.sort(new NotionPageCreatedTimeComparator());
                    
                    // Delete all except the oldest
                    for (Integer i = 1; i < pages.size(); i++) {
                        // Check limits before each deletion
                        if (NotionRateLimiter.shouldDeferProcessing() || 
                            (maxDeletions != null && deletionCount >= maxDeletions)) {
                            result.deferred = true;
                            return result;
                        }
                        
                        try {
                            // Apply rate limiting
                            NotionRateLimiter.throttleRequest();
                            
                            String pageId = (String)pages[i].get('id');
                            deleteNotionPage(pageId);
                            
                            result.duplicatesDeleted++;
                            deletionCount++;
                            
                            // Log individual deletion
                            logger.log(
                                new NotionSyncLogger.LogEntry('DEDUP')
                                    .withRecord(syncConfig.ObjectApiName__c, salesforceId)
                                    .withNotionPageId(pageId)
                                    .withStatus('Success')
                                    .withError('Duplicate Notion page deleted')
                            );
                            
                        } catch (NotionRateLimiter.RateLimitException e) {
                            result.deferred = true;
                            String pageId = (String)pages[i].get('id');
                            logger.log(
                                new NotionSyncLogger.LogEntry('DEDUP')
                                    .withRecord(syncConfig.ObjectApiName__c, salesforceId)
                                    .withNotionPageId(pageId)
                                    .withError('Rate limit during deduplication: ' + e.getMessage())
                                    .withRateLimit(1)
                            );
                            return result;
                        } catch (Exception e) {
                            // Log error but continue with other duplicates
                            String pageId = (String)pages[i].get('id');
                            logger.log(
                                new NotionSyncLogger.LogEntry('DEDUP')
                                    .withRecord(syncConfig.ObjectApiName__c, salesforceId)
                                    .withNotionPageId(pageId)
                                    .withError('Failed to delete duplicate: ' + e.getMessage())
                            );
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            logger.log(
                new NotionSyncLogger.LogEntry('DEDUP_SUMMARY')
                    .withSalesforceObject(syncConfig.ObjectApiName__c)
                    .withError('Deduplication error: ' + e.getMessage())
            );
        }
        
        return result;
    }
    
    /**
     * Query Notion pages for deduplication
     * Uses OR filter to query multiple Salesforce IDs efficiently
     */
    private List<Map<String, Object>> queryPagesForDeduplication(NotionSyncObject__mdt syncConfig, Set<Id> recordIds) {
        List<Map<String, Object>> allPages = new List<Map<String, Object>>();
        
        // Build OR filter for all record IDs
        List<Object> orConditions = new List<Object>();
        for (Id recordId : recordIds) {
            orConditions.add(new Map<String, Object>{
                'property' => syncConfig.SalesforceIdPropertyName__c,
                'rich_text' => new Map<String, Object>{
                    'equals' => String.valueOf(recordId)
                }
            });
        }
        
        Map<String, Object> filter = new Map<String, Object>{
            'or' => orConditions
        };
        
        // Query with pagination support
        String startCursor = null;
        Boolean hasMore = true;
        
        while (hasMore) {
            // Check limits before each API call
            if (NotionRateLimiter.shouldDeferProcessing()) {
                break;
            }
            
            NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(
                syncConfig.NotionDatabaseId__c, 
                filter,
                startCursor,
                100 // page size
            );
            
            if (response.success && String.isNotBlank(response.responseBody)) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
                List<Object> results = (List<Object>) responseBody.get('results');
                
                if (results != null) {
                    for (Object result : results) {
                        allPages.add((Map<String, Object>) result);
                    }
                }
                
                // Check for more pages
                hasMore = (Boolean) responseBody.get('has_more');
                if (hasMore) {
                    startCursor = (String) responseBody.get('next_cursor');
                }
            } else {
                hasMore = false;
                
                if (response.isRateLimited) {
                    throw new NotionRateLimiter.RateLimitException(
                        'Rate limited during deduplication query. Retry after: ' + response.retryAfterSeconds
                    );
                } else if (!response.success) {
                    throw new NotionSync.SyncException('Failed to query pages for deduplication: ' + response.errorMessage);
                }
            }
        }
        
        return allPages;
    }
    
    /**
     * Group Notion pages by their Salesforce ID property
     */
    private Map<String, List<Map<String, Object>>> groupPagesBySalesforceId(
        List<Map<String, Object>> pages, 
        String salesforceIdPropertyName
    ) {
        Map<String, List<Map<String, Object>>> grouped = new Map<String, List<Map<String, Object>>>();
        
        for (Map<String, Object> page : pages) {
            Map<String, Object> properties = (Map<String, Object>) page.get('properties');
            if (properties != null) {
                Map<String, Object> idProperty = (Map<String, Object>) properties.get(salesforceIdPropertyName);
                if (idProperty != null) {
                    String salesforceId = extractTextFromProperty(idProperty);
                    if (String.isNotBlank(salesforceId)) {
                        if (!grouped.containsKey(salesforceId)) {
                            grouped.put(salesforceId, new List<Map<String, Object>>());
                        }
                        grouped.get(salesforceId).add(page);
                    }
                }
            }
        }
        
        return grouped;
    }
    
    /**
     * Extract text value from a Notion property
     */
    private String extractTextFromProperty(Map<String, Object> property) {
        // Handle rich_text property type
        List<Object> richTextArray = (List<Object>) property.get('rich_text');
        if (richTextArray != null && !richTextArray.isEmpty()) {
            Map<String, Object> firstText = (Map<String, Object>) richTextArray[0];
            return (String) firstText.get('plain_text');
        }
        
        // Handle title property type
        List<Object> titleArray = (List<Object>) property.get('title');
        if (titleArray != null && !titleArray.isEmpty()) {
            Map<String, Object> firstTitle = (Map<String, Object>) titleArray[0];
            return (String) firstTitle.get('plain_text');
        }
        
        return null;
    }
    
    /**
     * Comparator for sorting Notion pages by created time
     */
    public class NotionPageCreatedTimeComparator implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> page1, Map<String, Object> page2) {
            String time1 = (String) page1.get('created_time');
            String time2 = (String) page2.get('created_time');
            
            if (time1 == null && time2 == null) return 0;
            if (time1 == null) return 1;
            if (time2 == null) return -1;
            
            return time1.compareTo(time2);
        }
    }
}