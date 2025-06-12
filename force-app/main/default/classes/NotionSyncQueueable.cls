public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<SyncRequest> requests;
    private Integer chainCount;
    
    public NotionSyncQueueable(List<SyncRequest> requests) {
        this.requests = requests;
        this.chainCount = 0;
    }
    
    public NotionSyncQueueable(List<SyncRequest> requests, Integer chainCount) {
        this.requests = requests;
        this.chainCount = chainCount != null ? chainCount : 0;
    }
    
    public void execute(QueueableContext context) {
        NotionSyncConfig__mdt config = getNotionSyncConfig();
        
        if (!config.EnableBulkProcessing__c) {
            processRequestsSequentially();
            return;
        }
        
        processBatchRequests(config);
    }
    
    private void processBatchRequests(NotionSyncConfig__mdt config) {
        Integer batchSize = Integer.valueOf(config.BatchSize__c);
        Map<String, List<SyncRequest>> requestsByObjectType = groupRequestsByObjectType();
        
        List<SyncRequest> remainingRequests = new List<SyncRequest>();
        Integer processedCount = 0;
        
        for (String objectType : requestsByObjectType.keySet()) {
            List<SyncRequest> objectRequests = requestsByObjectType.get(objectType);
            
            if (processedCount + objectRequests.size() <= batchSize) {
                processBatchedObjectRequests(objectType, objectRequests);
                processedCount += objectRequests.size();
            } else {
                Integer remainingSlots = batchSize - processedCount;
                if (remainingSlots > 0) {
                    List<SyncRequest> currentBatch = new List<SyncRequest>();
                    for (Integer i = 0; i < remainingSlots && i < objectRequests.size(); i++) {
                        currentBatch.add(objectRequests[i]);
                    }
                    processBatchedObjectRequests(objectType, currentBatch);
                    
                    for (Integer i = remainingSlots; i < objectRequests.size(); i++) {
                        remainingRequests.add(objectRequests[i]);
                    }
                } else {
                    remainingRequests.addAll(objectRequests);
                }
                break;
            }
        }
        
        chainNextBatch(remainingRequests, config);
    }
    
    private void processBatchedObjectRequests(String objectType, List<SyncRequest> objectRequests) {
        try {
            NotionSyncObject__mdt syncConfig = getSyncConfiguration(objectType);
            if (syncConfig == null || !syncConfig.IsActive__c) {
                logBatchError(objectRequests, 'Sync configuration not found or inactive for: ' + objectType);
                return;
            }
            
            List<NotionSyncField__mdt> fieldMappings = getFieldMappings(syncConfig.Id);
            Map<String, List<SyncRequest>> requestsByOperation = groupRequestsByOperation(objectRequests);
            
            if (requestsByOperation.containsKey('CREATE') || requestsByOperation.containsKey('UPDATE')) {
                processBatchedCreateAndUpdateRequests(syncConfig, fieldMappings, requestsByOperation);
            }
            
            if (requestsByOperation.containsKey('DELETE')) {
                processBatchedDeleteRequests(syncConfig, requestsByOperation.get('DELETE'));
            }
            
        } catch (Exception e) {
            System.debug('Error processing batched requests for ' + objectType + ': ' + e.getMessage());
            logBatchError(objectRequests, 'Batch processing error: ' + e.getMessage());
        }
    }
    
    private void processBatchedCreateAndUpdateRequests(NotionSyncObject__mdt syncConfig, 
                                                     List<NotionSyncField__mdt> fieldMappings,
                                                     Map<String, List<SyncRequest>> requestsByOperation) {
        
        List<SyncRequest> createRequests = requestsByOperation.get('CREATE');
        List<SyncRequest> updateRequests = requestsByOperation.get('UPDATE');
        
        Map<Id, SObject> recordsMap = getBulkRecords(syncConfig.ObjectApiName__c, createRequests, updateRequests);
        
        List<NotionApiClient.NotionPageRequest> createPageRequests = new List<NotionApiClient.NotionPageRequest>();
        List<NotionApiClient.NotionPageRequest> updatePageRequests = new List<NotionApiClient.NotionPageRequest>();
        
        if (createRequests != null) {
            createPageRequests = buildCreateRequests(createRequests, syncConfig, fieldMappings, recordsMap);
        }
        
        if (updateRequests != null) {
            updatePageRequests = buildUpdateRequests(updateRequests, syncConfig, fieldMappings, recordsMap);
        }
        
        List<NotionApiClient.BatchOperationResult> results = NotionApiClient.processBatch(
            createPageRequests, 
            updatePageRequests, 
            null
        );
        
        processBatchResults(results, createRequests, updateRequests, null);
    }
    
    private void processBatchedDeleteRequests(NotionSyncObject__mdt syncConfig, List<SyncRequest> deleteRequests) {
        List<String> pageIdsToDelete = new List<String>();
        Map<String, String> pageIdToRecordId = new Map<String, String>();
        
        for (SyncRequest request : deleteRequests) {
            String notionPageId = findNotionPageId(request.recordId, syncConfig);
            if (String.isNotBlank(notionPageId)) {
                pageIdsToDelete.add(notionPageId);
                pageIdToRecordId.put(notionPageId, request.recordId);
            }
        }
        
        if (!pageIdsToDelete.isEmpty()) {
            List<NotionApiClient.BatchOperationResult> results = NotionApiClient.processBatch(null, null, pageIdsToDelete);
            processBatchResults(results, null, null, deleteRequests);
        }
    }
    
    private List<NotionApiClient.NotionPageRequest> buildCreateRequests(List<SyncRequest> createRequests,
                                                                       NotionSyncObject__mdt syncConfig,
                                                                       List<NotionSyncField__mdt> fieldMappings,
                                                                       Map<Id, SObject> recordsMap) {
        List<NotionApiClient.NotionPageRequest> pageRequests = new List<NotionApiClient.NotionPageRequest>();
        
        for (SyncRequest request : createRequests) {
            SObject record = recordsMap.get(request.recordId);
            if (record != null) {
                try {
                    NotionDataTransformer.NotionPage notionPage = NotionDataTransformer.transformRecord(record, syncConfig.ObjectApiName__c);
                    
                    notionPage.properties.put(syncConfig.SalesforceIdPropertyName__c, 
                                            NotionApiClient.buildTextProperty(request.recordId));
                    
                    NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
                        syncConfig.NotionDatabaseId__c, 
                        notionPage.properties,
                        notionPage.children
                    );
                    pageRequest.recordId = request.recordId;
                    pageRequests.add(pageRequest);
                    
                } catch (Exception e) {
                    logError(request, 'Error building create request: ' + e.getMessage());
                }
            } else {
                logError(request, 'Record not found for create operation');
            }
        }
        
        return pageRequests;
    }
    
    private List<NotionApiClient.NotionPageRequest> buildUpdateRequests(List<SyncRequest> updateRequests,
                                                                       NotionSyncObject__mdt syncConfig,
                                                                       List<NotionSyncField__mdt> fieldMappings,
                                                                       Map<Id, SObject> recordsMap) {
        List<NotionApiClient.NotionPageRequest> pageRequests = new List<NotionApiClient.NotionPageRequest>();
        
        for (SyncRequest request : updateRequests) {
            SObject record = recordsMap.get(request.recordId);
            if (record != null) {
                try {
                    String notionPageId = findNotionPageId(request.recordId, syncConfig);
                    if (String.isNotBlank(notionPageId)) {
                        NotionDataTransformer.NotionPage notionPage = NotionDataTransformer.transformRecord(record, syncConfig.ObjectApiName__c);
                        
                        NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
                            request.recordId,
                            notionPageId,
                            notionPage.properties
                        );
                        pageRequests.add(pageRequest);
                    } else {
                        logError(request, 'Notion page not found for update operation');
                    }
                    
                } catch (Exception e) {
                    logError(request, 'Error building update request: ' + e.getMessage());
                }
            } else {
                logError(request, 'Record not found for update operation');
            }
        }
        
        return pageRequests;
    }
    
    private void processBatchResults(List<NotionApiClient.BatchOperationResult> results,
                                   List<SyncRequest> createRequests,
                                   List<SyncRequest> updateRequests,
                                   List<SyncRequest> deleteRequests) {
        
        for (NotionApiClient.BatchOperationResult result : results) {
            SyncRequest correspondingRequest = findCorrespondingRequest(result, createRequests, updateRequests, deleteRequests);
            
            if (correspondingRequest != null) {
                if (result.success) {
                    logSuccess(correspondingRequest, result.pageId);
                } else {
                    logError(correspondingRequest, result.errorMessage);
                }
            }
        }
    }
    
    private SyncRequest findCorrespondingRequest(NotionApiClient.BatchOperationResult result,
                                               List<SyncRequest> createRequests,
                                               List<SyncRequest> updateRequests,
                                               List<SyncRequest> deleteRequests) {
        
        if (result.operationType == 'CREATE' && createRequests != null) {
            for (SyncRequest request : createRequests) {
                if (request.recordId == result.recordId) {
                    return request;
                }
            }
        } else if (result.operationType == 'UPDATE' && updateRequests != null) {
            for (SyncRequest request : updateRequests) {
                if (request.recordId == result.recordId) {
                    return request;
                }
            }
        } else if (result.operationType == 'DELETE' && deleteRequests != null) {
            for (SyncRequest request : deleteRequests) {
                String pageId = findNotionPageId(request.recordId, getSyncConfiguration(request.objectType));
                if (pageId == result.pageId) {
                    return request;
                }
            }
        }
        
        return null;
    }
    
    private Map<String, List<SyncRequest>> groupRequestsByOperation(List<SyncRequest> requests) {
        Map<String, List<SyncRequest>> grouped = new Map<String, List<SyncRequest>>();
        
        for (SyncRequest request : requests) {
            if (!grouped.containsKey(request.operationType)) {
                grouped.put(request.operationType, new List<SyncRequest>());
            }
            grouped.get(request.operationType).add(request);
        }
        
        return grouped;
    }
    
    private Map<Id, SObject> getBulkRecords(String objectType, List<SyncRequest> createRequests, List<SyncRequest> updateRequests) {
        Set<Id> recordIds = new Set<Id>();
        
        if (createRequests != null) {
            for (SyncRequest request : createRequests) {
                recordIds.add(request.recordId);
            }
        }
        
        if (updateRequests != null) {
            for (SyncRequest request : updateRequests) {
                recordIds.add(request.recordId);
            }
        }
        
        if (recordIds.isEmpty()) {
            return new Map<Id, SObject>();
        }
        
        String query = buildOptimizedQuery(objectType, recordIds);
        List<SObject> records = Database.query(query);
        
        Map<Id, SObject> recordsMap = new Map<Id, SObject>();
        for (SObject record : records) {
            recordsMap.put(record.Id, record);
        }
        
        return recordsMap;
    }
    
    private String buildOptimizedQuery(String objectType, Set<Id> recordIds) {
        String baseQuery = 'SELECT Id';
        
        List<NotionSyncField__mdt> fieldMappings = [
            SELECT SalesforceFieldApiName__c
            FROM NotionSyncField__mdt
            WHERE NotionSyncObject__r.ObjectApiName__c = :objectType
            AND NotionSyncObject__r.IsActive__c = true
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
    
    private void chainNextBatch(List<SyncRequest> remainingRequests, NotionSyncConfig__mdt config) {
        if (remainingRequests.isEmpty()) {
            return;
        }
        
        Integer chainLimit = Integer.valueOf(config.QueueableChainLimit__c);
        if (chainCount >= chainLimit) {
            System.debug('Queueable chain limit reached. ' + remainingRequests.size() + ' requests will be lost.');
            logBatchError(remainingRequests, 'Queueable chain limit exceeded');
            return;
        }
        
        try {
            System.enqueueJob(new NotionSyncQueueable(remainingRequests, chainCount + 1));
        } catch (Exception e) {
            System.debug('Failed to enqueue next batch: ' + e.getMessage());
            logBatchError(remainingRequests, 'Failed to chain next batch: ' + e.getMessage());
        }
    }
    
    private void processRequestsSequentially() {
        Map<String, List<SyncRequest>> requestsByObjectType = groupRequestsByObjectType();
        
        for (String objectType : requestsByObjectType.keySet()) {
            List<SyncRequest> objectRequests = requestsByObjectType.get(objectType);
            processObjectRequestsSequentially(objectType, objectRequests);
        }
    }
    
    private void processObjectRequestsSequentially(String objectType, List<SyncRequest> objectRequests) {
        NotionSyncObject__mdt syncConfig = getSyncConfiguration(objectType);
        if (syncConfig == null) {
            logBatchError(objectRequests, 'No sync configuration found for object type: ' + objectType);
            return;
        }
        
        if (!syncConfig.IsActive__c) {
            logBatchError(objectRequests, 'Sync is disabled for object type: ' + objectType);
            return;
        }
        
        List<NotionSyncField__mdt> fieldMappings = getFieldMappings(syncConfig.Id);
        Map<Id, SObject> recordsMap = getRecords(objectType, objectRequests);
        
        for (SyncRequest request : objectRequests) {
            processSingleRequest(request, syncConfig, fieldMappings, recordsMap.get(request.recordId));
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
        
        for (SyncRequest request : objectRequests) {
            if (request.operationType != 'DELETE') {
                recordIds.add(request.recordId);
            }
        }
        
        if (recordIds.isEmpty()) {
            return new Map<Id, SObject>();
        }
        
        String query = buildOptimizedQuery(objectType, recordIds);
        List<SObject> records = Database.query(query);
        
        Map<Id, SObject> recordsMap = new Map<Id, SObject>();
        for (SObject record : records) {
            recordsMap.put(record.Id, record);
        }
        
        return recordsMap;
    }
    
    private void processSingleRequest(SyncRequest request, NotionSyncObject__mdt syncConfig, 
                                    List<NotionSyncField__mdt> fieldMappings, SObject record) {
        try {
            if (request.operationType == 'DELETE') {
                handleDeleteOperation(request, syncConfig);
            } else {
                handleCreateOrUpdateOperation(request, syncConfig, fieldMappings, record);
            }
            
            logSuccess(request, null);
            
        } catch (Exception e) {
            logError(request, e.getMessage());
        }
    }
    
    private void handleDeleteOperation(SyncRequest request, NotionSyncObject__mdt syncConfig) {
        String notionPageId = findNotionPageId(request.recordId, syncConfig);
        if (String.isNotBlank(notionPageId)) {
            NotionApiClient.NotionResponse response = NotionApiClient.deletePage(notionPageId);
            if (!response.success) {
                throw new NotionSyncException('Failed to delete Notion page: ' + response.errorMessage);
            }
        }
    }
    
    private void handleCreateOrUpdateOperation(SyncRequest request, NotionSyncObject__mdt syncConfig, 
                                            List<NotionSyncField__mdt> fieldMappings, SObject record) {
        if (record == null) {
            throw new NotionSyncException('Record not found: ' + request.recordId);
        }
        
        NotionDataTransformer.NotionPage notionPage = NotionDataTransformer.transformRecord(record, syncConfig.ObjectApiName__c);
        String notionPageId = findNotionPageId(request.recordId, syncConfig);
        
        if (String.isNotBlank(notionPageId)) {
            NotionApiClient.NotionResponse response = NotionApiClient.updatePage(notionPageId, notionPage.properties);
            if (!response.success) {
                throw new NotionSyncException('Failed to update Notion page: ' + response.errorMessage);
            }
        } else {
            notionPage.properties.put(syncConfig.SalesforceIdPropertyName__c, 
                                    NotionApiClient.buildTextProperty(request.recordId));
            
            NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
                syncConfig.NotionDatabaseId__c, 
                notionPage.properties,
                notionPage.children
            );
            
            NotionApiClient.NotionResponse response = NotionApiClient.createPage(pageRequest);
            if (!response.success) {
                throw new NotionSyncException('Failed to create Notion page: ' + response.errorMessage);
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
        
        NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(syncConfig.NotionDatabaseId__c, filter);
        
        if (response.success && String.isNotBlank(response.responseBody)) {
            try {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
                List<Object> results = (List<Object>) responseBody.get('results');
                
                if (!results.isEmpty()) {
                    Map<String, Object> page = (Map<String, Object>) results[0];
                    return (String) page.get('id');
                }
            } catch (Exception e) {
                System.debug('Error parsing query response: ' + e.getMessage());
            }
        }
        
        return null;
    }
    
    private void logSuccess(SyncRequest request, String pageId) {
        logResult(request, 'Success', null, pageId);
    }
    
    private void logError(SyncRequest request, String errorMessage) {
        logResult(request, 'Failed', errorMessage, null);
    }
    
    private void logBatchError(List<SyncRequest> requests, String errorMessage) {
        for (SyncRequest request : requests) {
            logError(request, errorMessage);
        }
    }
    
    private void logResult(SyncRequest request, String status, String errorMessage, String pageId) {
        Notion_Sync_Log__c log = new Notion_Sync_Log__c(
            Record_Id__c = request.recordId,
            Object_Type__c = request.objectType,
            Operation_Type__c = request.operationType,
            Status__c = status,
            Error_Message__c = errorMessage,
            Notion_Page_Id__c = pageId,
            Retry_Count__c = 0
        );
        
        try {
            insert log;
        } catch (Exception e) {
            System.debug('Failed to insert sync log: ' + e.getMessage());
        }
    }
    
    private NotionSyncConfig__mdt getNotionSyncConfig() {
        List<NotionSyncConfig__mdt> configs = [
            SELECT BatchSize__c, RateLimitPerSecond__c, MaxRetryAttempts__c, 
                   EnableBulkProcessing__c, QueueableChainLimit__c
            FROM NotionSyncConfig__mdt
            LIMIT 1
        ];
        
        if (configs.isEmpty()) {
            NotionSyncConfig__mdt defaultConfig = new NotionSyncConfig__mdt();
            defaultConfig.BatchSize__c = 10;
            defaultConfig.RateLimitPerSecond__c = 3;
            defaultConfig.MaxRetryAttempts__c = 3;
            defaultConfig.EnableBulkProcessing__c = true;
            defaultConfig.QueueableChainLimit__c = 5;
            return defaultConfig;
        }
        
        return configs[0];
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