public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<SyncRequest> requests;
    
    public NotionSyncQueueable(List<SyncRequest> requests) {
        this.requests = requests;
    }
    
    public void execute(QueueableContext context) {
        Map<String, List<SyncRequest>> requestsByObjectType = groupRequestsByObjectType();
        
        for (String objectType : requestsByObjectType.keySet()) {
            List<SyncRequest> objectRequests = requestsByObjectType.get(objectType);
            processObjectRequests(objectType, objectRequests);
        }
    }
    
    private Map<String, List<SyncRequest>> groupRequestsByObjectType() {
        Map<String, List<SyncRequest>> grouped = new Map<String, List<SyncRequest>>();
        
        for (SyncRequest request : requests) {
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
        
        if (!fieldsToQuery.isEmpty()) {
            baseQuery += ', ' + String.join(new List<String>(fieldsToQuery), ', ');
        }
        
        baseQuery += ' FROM ' + objectType + ' WHERE Id IN :recordIds';
        
        return baseQuery;
    }
    
    private void processSingleRequest(SyncRequest request, NotionSyncObject__mdt syncConfig, 
                                    List<NotionSyncField__mdt> fieldMappings, SObject record) {
        try {
            if (request.operationType == 'DELETE') {
                handleDeleteOperation(request, syncConfig);
            } else {
                handleCreateOrUpdateOperation(request, syncConfig, fieldMappings, record);
            }
            
            logSuccess(request);
            
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
    
    private void handleCreateOrUpdateOperation(SyncRequest request, NotionSyncObject__mdt syncConfig, 
                                            List<NotionSyncField__mdt> fieldMappings, SObject record) {
        if (record == null) {
            throw new NotionSyncException('Record not found: ' + request.recordId);
        }
        
        Map<String, Object> notionProperties = transformDataToNotionFormat(record, fieldMappings);
        String notionPageId = findNotionPageId(request.recordId, syncConfig);
        
        if (String.isNotBlank(notionPageId)) {
            updateNotionPage(notionPageId, notionProperties);
        } else {
            notionProperties.put(syncConfig.SalesforceIdPropertyName__c, request.recordId);
            createNotionPage(syncConfig.NotionDatabaseId__c, notionProperties);
        }
    }
    
    private Map<String, Object> transformDataToNotionFormat(SObject record, List<NotionSyncField__mdt> fieldMappings) {
        Map<String, Object> properties = new Map<String, Object>();
        String bodyContent = '';
        
        for (NotionSyncField__mdt mapping : fieldMappings) {
            Object fieldValue = record.get(mapping.SalesforceFieldApiName__c);
            
            if (mapping.IsBodyContent__c && fieldValue != null) {
                bodyContent = String.valueOf(fieldValue);
            } else if (fieldValue != null) {
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
        if (value == null) return null;
        
        switch on propertyType {
            when 'title', 'rich_text' {
                return new Map<String, Object>{ 'type' => 'text', 'text' => new Map<String, Object>{ 'content' => String.valueOf(value) } };
            }
            when 'number' {
                return value instanceof Decimal ? value : Decimal.valueOf(String.valueOf(value));
            }
            when 'checkbox' {
                return Boolean.valueOf(value);
            }
            when 'date' {
                if (value instanceof Date) {
                    Date dateValue = (Date)value;
                    String formattedDate = dateValue.year() + '-' + 
                                         String.valueOf(dateValue.month()).leftPad(2, '0') + '-' + 
                                         String.valueOf(dateValue.day()).leftPad(2, '0');
                    return new Map<String, Object>{ 'start' => formattedDate };
                } else if (value instanceof DateTime) {
                    return new Map<String, Object>{ 'start' => ((DateTime)value).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') };
                }
                return null;
            }
            when else {
                return String.valueOf(value);
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
    
    private void createNotionPage(String databaseId, Map<String, Object> properties) {
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
                Object value = properties.get(key);
                if (value != null) {
                    notionProps.put(key, value);
                }
            }
        }
        
        return notionProps;
    }
    
    private List<Object> buildNotionChildren(String bodyContent) {
        return new List<Object>{
            new Map<String, Object>{
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
            }
        };
    }
    
    private void logSuccess(SyncRequest request) {
        logResult(request, 'Success', null);
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
        Notion_Sync_Log__c log = new Notion_Sync_Log__c(
            Record_Id__c = request.recordId,
            Object_Type__c = request.objectType,
            Operation_Type__c = request.operationType,
            Status__c = status,
            Error_Message__c = errorMessage,
            Retry_Count__c = 0
        );
        
        try {
            insert log;
        } catch (Exception e) {
            System.debug('Failed to insert sync log: ' + e.getMessage());
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