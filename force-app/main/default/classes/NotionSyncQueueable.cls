public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<SyncRequest> requests;
    private NotionRelationshipHandler relationshipHandler;
    
    public NotionSyncQueueable(List<SyncRequest> requests) {
        this.requests = requests;
        this.relationshipHandler = new NotionRelationshipHandler();
    }
    
    public void execute(QueueableContext context) {
        processSyncRequests(this.requests);
    }
    
    /**
     * Process sync requests - can be called from Queueable or directly
     * Made public to support direct invocation from InvocableMethod
     */
    public void processSyncRequests(List<SyncRequest> syncRequests) {
        Map<String, List<SyncRequest>> requestsByObjectType = groupRequestsByObjectType(syncRequests);
        
        List<String> processingOrder = relationshipHandler.getProcessingOrder(requestsByObjectType.keySet());
        
        for (String objectType : processingOrder) {
            if (requestsByObjectType.containsKey(objectType)) {
                List<SyncRequest> objectRequests = requestsByObjectType.get(objectType);
                processObjectRequests(objectType, objectRequests);
            }
        }
        
        // Flush all logs to async logger after all callouts are complete
        NotionSyncLogger.flush();
    }
    
    private Map<String, List<SyncRequest>> groupRequestsByObjectType(List<SyncRequest> syncRequests) {
        Map<String, List<SyncRequest>> grouped = new Map<String, List<SyncRequest>>();
        
        for (SyncRequest request : syncRequests) {
            if (!grouped.containsKey(request.objectType)) {
                grouped.put(request.objectType, new List<SyncRequest>());
            }
            grouped.get(request.objectType).add(request);
        }
        
        return grouped;
    }
    
    private void processObjectRequests(String objectType, List<SyncRequest> objectRequests) {
        NotionSyncObject__mdt syncConfig = getSyncConfiguration(objectType);
        if (syncConfig == null) {
            logError(objectRequests, 'No sync configuration found for object type: ' + objectType);
            return;
        }
        
        if (!syncConfig.IsActive__c) {
            logError(objectRequests, 'Sync is disabled for object type: ' + objectType);
            return;
        }
        
        List<NotionSyncField__mdt> fieldMappings = getFieldMappings(syncConfig.Id);
        Map<Id, SObject> recordsMap = getRecords(objectType, objectRequests);
        
        for (SyncRequest request : objectRequests) {
            processSingleRequest(request, syncConfig, fieldMappings, recordsMap.get(request.recordId));
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
    
    private Map<Id, SObject> getRecords(String objectType, List<SyncRequest> objectRequests) {
        Set<Id> recordIds = new Set<Id>();
        List<SyncRequest> nonDeleteRequests = new List<SyncRequest>();
        
        for (SyncRequest request : objectRequests) {
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
    
    private void processSingleRequest(SyncRequest request, NotionSyncObject__mdt syncConfig, 
                                    List<NotionSyncField__mdt> fieldMappings, SObject record) {
        try {
            String notionPageId = null;
            
            if (request.operationType == 'DELETE') {
                handleDeleteOperation(request, syncConfig);
            } else {
                notionPageId = handleCreateOrUpdateOperation(request, syncConfig, fieldMappings, record);
            }
            
            logSuccess(request, notionPageId);
            
        } catch (Exception e) {
            logError(request, e.getMessage());
        }
    }
    
    private void handleDeleteOperation(SyncRequest request, NotionSyncObject__mdt syncConfig) {
        String notionPageId = findNotionPageId(request.recordId, syncConfig);
        if (String.isNotBlank(notionPageId)) {
            deleteNotionPage(notionPageId);
        }
    }
    
    private String handleCreateOrUpdateOperation(SyncRequest request, NotionSyncObject__mdt syncConfig, 
                                            List<NotionSyncField__mdt> fieldMappings, SObject record) {
        if (record == null) {
            throw new NotionSyncException('Record not found: ' + request.recordId);
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
                // If this field is marked as body content, add it to body content only
                if (fieldValue != null) {
                    bodyContent = String.valueOf(fieldValue);
                }
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
        
        if (String.isNotBlank(bodyContent)) {
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
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/databases/' + syncConfig.NotionDatabaseId__c + '/query');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Notion-Version', '2022-06-28');
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'filter' => new Map<String, Object>{
                'property' => syncConfig.SalesforceIdPropertyName__c,
                'rich_text' => new Map<String, Object>{
                    'equals' => salesforceId
                }
            }
        };
        
        req.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> results = (List<Object>) responseBody.get('results');
            
            if (!results.isEmpty()) {
                Map<String, Object> page = (Map<String, Object>) results[0];
                return (String) page.get('id');
            }
        }
        
        return null;
    }
    
    private String createNotionPage(String databaseId, Map<String, Object> properties) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/pages');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Notion-Version', '2022-06-28');
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'parent' => new Map<String, Object>{ 'database_id' => databaseId },
            'properties' => buildNotionProperties(properties)
        };
        
        String bodyContent = (String) properties.get('body');
        if (String.isNotBlank(bodyContent)) {
            requestBody.put('children', buildNotionChildren(bodyContent));
        }
        
        req.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new NotionSyncException('Failed to create Notion page: ' + res.getBody());
        }
        
        // Parse response to get the created page ID
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) responseBody.get('id');
    }
    
    private void updateNotionPage(String pageId, Map<String, Object> properties) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/pages/' + pageId);
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Notion-Version', '2022-06-28');
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'properties' => buildNotionProperties(properties)
        };
        
        req.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new NotionSyncException('Failed to update Notion page: ' + res.getBody());
        }
        
        // Handle body content update if present
        String bodyContent = (String) properties.get('body');
        if (bodyContent != null) {
            // Notion API doesn't support updating children directly
            // We need to delete existing children and append new ones
            updatePageBodyContent(pageId, bodyContent);
        }
    }
    
    private void updatePageBodyContent(String pageId, String bodyContent) {
        // Get existing children blocks
        List<String> existingBlockIds = getPageChildren(pageId);
        
        if (String.isNotBlank(bodyContent)) {
            if (!existingBlockIds.isEmpty()) {
                try {
                    // Try to update the first block with new content
                    updateBlock(existingBlockIds[0], bodyContent);
                    
                    // Delete any extra blocks beyond the first one
                    for (Integer i = 1; i < existingBlockIds.size(); i++) {
                        deleteBlock(existingBlockIds[i]);
                    }
                } catch (NotionSyncException e) {
                    // If update fails, delete all and recreate
                    for (String blockId : existingBlockIds) {
                        deleteBlock(blockId);
                    }
                    appendBlockChildren(pageId, buildNotionChildren(bodyContent));
                }
            } else {
                // No existing blocks, append new one
                appendBlockChildren(pageId, buildNotionChildren(bodyContent));
            }
        } else {
            // Clear all blocks when body content is null/empty
            for (String blockId : existingBlockIds) {
                deleteBlock(blockId);
            }
        }
    }
    
    private List<String> getPageChildren(String pageId) {
        List<String> blockIds = new List<String>();
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/blocks/' + pageId + '/children');
        req.setMethod('GET');
        req.setHeader('Notion-Version', '2022-06-28');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> results = (List<Object>) responseBody.get('results');
            
            for (Object result : results) {
                Map<String, Object> block = (Map<String, Object>) result;
                blockIds.add((String) block.get('id'));
            }
        }
        
        return blockIds;
    }
    
    private void updateBlock(String blockId, String content) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/blocks/' + blockId);
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Notion-Version', '2022-06-28');
        
        // Build update payload based on block type (assuming paragraph for body content)
        Map<String, Object> requestBody = new Map<String, Object>{
            'paragraph' => new Map<String, Object>{
                'rich_text' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'text',
                        'text' => new Map<String, Object>{ 'content' => content }
                    }
                }
            }
        };
        
        req.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            // If update fails (e.g., block type mismatch), fall back to delete and recreate
            deleteBlock(blockId);
            // The parent method will handle appending new content
            throw new NotionSyncException('Failed to update block: ' + res.getBody());
        }
    }
    
    private void deleteBlock(String blockId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/blocks/' + blockId);
        req.setMethod('DELETE');
        req.setHeader('Notion-Version', '2022-06-28');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Ignore errors when deleting blocks - they might already be deleted
    }
    
    private void appendBlockChildren(String pageId, List<Map<String, Object>> children) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/blocks/' + pageId + '/children');
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Notion-Version', '2022-06-28');
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'children' => children
        };
        
        req.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new NotionSyncException('Failed to append block children: ' + res.getBody());
        }
    }
    
    private void deleteNotionPage(String pageId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/pages/' + pageId);
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Notion-Version', '2022-06-28');
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'archived' => true
        };
        
        req.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new NotionSyncException('Failed to delete Notion page: ' + res.getBody());
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
    
    private List<Map<String, Object>> buildNotionChildren(String bodyContent) {
        List<Map<String, Object>> children = new List<Map<String, Object>>();
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
    
    private void logSuccess(SyncRequest request) {
        logResult(request, 'Success', null, null);
    }
    
    private void logSuccess(SyncRequest request, String notionPageId) {
        logResult(request, 'Success', null, notionPageId);
    }
    
    private void logError(SyncRequest request, String errorMessage) {
        logResult(request, 'Failed', errorMessage);
    }
    
    private void logError(List<SyncRequest> requests, String errorMessage) {
        for (SyncRequest request : requests) {
            logError(request, errorMessage);
        }
    }
    
    private void logResult(SyncRequest request, String status, String errorMessage) {
        logResult(request, status, errorMessage, null);
    }
    
    private void logResult(SyncRequest request, String status, String errorMessage, String notionPageId) {
        if (String.isNotBlank(notionPageId)) {
            NotionSyncLogger.log(
                request.recordId,
                request.objectType,
                request.operationType,
                status,
                errorMessage,
                0,
                notionPageId
            );
        } else {
            NotionSyncLogger.log(
                request.recordId,
                request.objectType,
                request.operationType,
                status,
                errorMessage,
                0
            );
        }
    }
    
    
    public class NotionSyncException extends Exception {}
    
    public class SyncRequest {
        public String recordId;
        public String objectType;
        public String operationType;
        
        public SyncRequest(String recordId, String objectType, String operationType) {
            this.recordId = recordId;
            this.objectType = objectType;
            this.operationType = operationType;
        }
    }
}