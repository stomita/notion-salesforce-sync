public class NotionApiClient {
    
    private static final String NAMED_CREDENTIAL = 'callout:Notion_API';
    private static final String API_VERSION = '2022-06-28';
    
    private static Long lastRequestTime = 0;
    private static Integer requestCount = 0;
    private static final Long RATE_LIMIT_WINDOW = 1000; // 1 second in milliseconds
    
    public class NotionApiException extends Exception {}
    
    public class NotionResponse {
        public Boolean success;
        public String pageId;
        public String errorMessage;
        public Integer statusCode;
        public String responseBody;
        
        public NotionResponse(Boolean success, String pageId, String errorMessage, Integer statusCode, String responseBody) {
            this.success = success;
            this.pageId = pageId;
            this.errorMessage = errorMessage;
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
    }
    
    public class NotionPageRequest {
        public String databaseId;
        public String pageId;
        public Map<String, Object> properties;
        public List<Object> children;
        public String recordId;
        
        public NotionPageRequest(String databaseId, Map<String, Object> properties) {
            this.databaseId = databaseId;
            this.properties = properties;
            this.children = new List<Object>();
        }
        
        public NotionPageRequest(String databaseId, Map<String, Object> properties, List<Object> children) {
            this.databaseId = databaseId;
            this.properties = properties;
            this.children = children;
        }
        
        public NotionPageRequest(String recordId, String pageId, Map<String, Object> properties) {
            this.recordId = recordId;
            this.pageId = pageId;
            this.properties = properties;
            this.children = new List<Object>();
        }
    }
    
    public class BulkNotionResponse {
        public List<NotionResponse> responses;
        public Integer successCount;
        public Integer failureCount;
        public Boolean hasErrors;
        
        public BulkNotionResponse() {
            this.responses = new List<NotionResponse>();
            this.successCount = 0;
            this.failureCount = 0;
            this.hasErrors = false;
        }
        
        public void addResponse(NotionResponse response) {
            this.responses.add(response);
            if (response.success) {
                this.successCount++;
            } else {
                this.failureCount++;
                this.hasErrors = true;
            }
        }
    }
    
    public class BatchOperationResult {
        public String recordId;
        public String operationType;
        public Boolean success;
        public String pageId;
        public String errorMessage;
        
        public BatchOperationResult(String recordId, String operationType, Boolean success, String pageId, String errorMessage) {
            this.recordId = recordId;
            this.operationType = operationType;
            this.success = success;
            this.pageId = pageId;
            this.errorMessage = errorMessage;
        }
    }
    
    public static NotionResponse createPage(NotionPageRequest pageRequest) {
        try {
            HttpRequest request = buildHttpRequest('POST', '/v1/pages');
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'parent' => new Map<String, Object>{
                    'database_id' => pageRequest.databaseId
                },
                'properties' => pageRequest.properties
            };
            
            if (pageRequest.children != null && !pageRequest.children.isEmpty()) {
                requestBody.put('children', pageRequest.children);
            }
            
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (Exception e) {
            return new NotionResponse(false, null, 'Exception during page creation: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse updatePage(String pageId, Map<String, Object> properties) {
        try {
            HttpRequest request = buildHttpRequest('PATCH', '/v1/pages/' + pageId);
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'properties' => properties
            };
            
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (Exception e) {
            return new NotionResponse(false, pageId, 'Exception during page update: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse deletePage(String pageId) {
        try {
            HttpRequest request = buildHttpRequest('PATCH', '/v1/pages/' + pageId);
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'archived' => true
            };
            
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (Exception e) {
            return new NotionResponse(false, pageId, 'Exception during page deletion: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse queryDatabase(String databaseId, Map<String, Object> filter) {
        try {
            HttpRequest request = buildHttpRequest('POST', '/v1/databases/' + databaseId + '/query');
            
            Map<String, Object> requestBody = new Map<String, Object>();
            if (filter != null && !filter.isEmpty()) {
                requestBody.put('filter', filter);
            }
            
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (Exception e) {
            return new NotionResponse(false, null, 'Exception during database query: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse getPage(String pageId) {
        try {
            HttpRequest request = buildHttpRequest('GET', '/v1/pages/' + pageId);
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (Exception e) {
            return new NotionResponse(false, pageId, 'Exception during page retrieval: ' + e.getMessage(), null, null);
        }
    }
    
    public static BulkNotionResponse bulkCreatePages(List<NotionPageRequest> pageRequests) {
        BulkNotionResponse bulkResponse = new BulkNotionResponse();
        
        if (pageRequests == null || pageRequests.isEmpty()) {
            return bulkResponse;
        }
        
        for (NotionPageRequest pageRequest : pageRequests) {
            enforceRateLimit();
            NotionResponse response = createPage(pageRequest);
            bulkResponse.addResponse(response);
        }
        
        return bulkResponse;
    }
    
    public static BulkNotionResponse bulkUpdatePages(List<NotionPageRequest> pageRequests) {
        BulkNotionResponse bulkResponse = new BulkNotionResponse();
        
        if (pageRequests == null || pageRequests.isEmpty()) {
            return bulkResponse;
        }
        
        for (NotionPageRequest pageRequest : pageRequests) {
            enforceRateLimit();
            NotionResponse response = updatePage(pageRequest.pageId, pageRequest.properties);
            bulkResponse.addResponse(response);
        }
        
        return bulkResponse;
    }
    
    public static BulkNotionResponse bulkDeletePages(List<String> pageIds) {
        BulkNotionResponse bulkResponse = new BulkNotionResponse();
        
        if (pageIds == null || pageIds.isEmpty()) {
            return bulkResponse;
        }
        
        for (String pageId : pageIds) {
            enforceRateLimit();
            NotionResponse response = deletePage(pageId);
            bulkResponse.addResponse(response);
        }
        
        return bulkResponse;
    }
    
    public static List<BatchOperationResult> processBatch(List<NotionPageRequest> createRequests, 
                                                         List<NotionPageRequest> updateRequests,
                                                         List<String> deletePageIds) {
        List<BatchOperationResult> results = new List<BatchOperationResult>();
        
        if (createRequests != null && !createRequests.isEmpty()) {
            BulkNotionResponse createResponse = bulkCreatePages(createRequests);
            for (Integer i = 0; i < createRequests.size(); i++) {
                NotionResponse response = createResponse.responses[i];
                results.add(new BatchOperationResult(
                    createRequests[i].recordId,
                    'CREATE',
                    response.success,
                    response.pageId,
                    response.errorMessage
                ));
            }
        }
        
        if (updateRequests != null && !updateRequests.isEmpty()) {
            BulkNotionResponse updateResponse = bulkUpdatePages(updateRequests);
            for (Integer i = 0; i < updateRequests.size(); i++) {
                NotionResponse response = updateResponse.responses[i];
                results.add(new BatchOperationResult(
                    updateRequests[i].recordId,
                    'UPDATE',
                    response.success,
                    response.pageId,
                    response.errorMessage
                ));
            }
        }
        
        if (deletePageIds != null && !deletePageIds.isEmpty()) {
            BulkNotionResponse deleteResponse = bulkDeletePages(deletePageIds);
            for (Integer i = 0; i < deletePageIds.size(); i++) {
                NotionResponse response = deleteResponse.responses[i];
                results.add(new BatchOperationResult(
                    null, // recordId not available for deletes
                    'DELETE',
                    response.success,
                    deletePageIds[i],
                    response.errorMessage
                ));
            }
        }
        
        return results;
    }
    
    private static HttpRequest buildHttpRequest(String method, String endpoint) {
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setEndpoint(NAMED_CREDENTIAL + endpoint);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Notion-Version', API_VERSION);
        request.setTimeout(60000);
        
        return request;
    }
    
    private static NotionResponse processResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        
        if (statusCode >= 200 && statusCode < 300) {
            try {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                String pageId = null;
                
                if (responseMap.containsKey('id')) {
                    pageId = (String) responseMap.get('id');
                }
                
                return new NotionResponse(true, pageId, null, statusCode, responseBody);
                
            } catch (Exception e) {
                return new NotionResponse(false, null, 'Failed to parse successful response: ' + e.getMessage(), statusCode, responseBody);
            }
        } else {
            String errorMessage = 'HTTP ' + statusCode + ': ';
            
            try {
                Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                if (errorResponse.containsKey('message')) {
                    errorMessage += (String) errorResponse.get('message');
                } else {
                    errorMessage += 'Unknown error';
                }
                
                if (errorResponse.containsKey('code')) {
                    errorMessage += ' (Code: ' + errorResponse.get('code') + ')';
                }
                
            } catch (Exception e) {
                errorMessage += responseBody;
            }
            
            return new NotionResponse(false, null, errorMessage, statusCode, responseBody);
        }
    }
    
    public static Map<String, Object> buildTextProperty(String value) {
        return new Map<String, Object>{
            'rich_text' => new List<Object>{
                new Map<String, Object>{
                    'text' => new Map<String, Object>{
                        'content' => value != null ? value : ''
                    }
                }
            }
        };
    }
    
    public static Map<String, Object> buildTitleProperty(String value) {
        return new Map<String, Object>{
            'title' => new List<Object>{
                new Map<String, Object>{
                    'text' => new Map<String, Object>{
                        'content' => value != null ? value : ''
                    }
                }
            }
        };
    }
    
    public static Map<String, Object> buildNumberProperty(Decimal value) {
        return new Map<String, Object>{
            'number' => value
        };
    }
    
    public static Map<String, Object> buildCheckboxProperty(Boolean value) {
        return new Map<String, Object>{
            'checkbox' => value != null ? value : false
        };
    }
    
    public static Map<String, Object> buildDateProperty(Date value) {
        if (value == null) {
            return new Map<String, Object>{
                'date' => null
            };
        }
        
        String formattedDate = String.valueOf(value.year()) + '-' + 
                              String.valueOf(value.month()).leftPad(2, '0') + '-' + 
                              String.valueOf(value.day()).leftPad(2, '0');
        
        return new Map<String, Object>{
            'date' => new Map<String, Object>{
                'start' => formattedDate
            }
        };
    }
    
    public static Map<String, Object> buildDateTimeProperty(DateTime value) {
        if (value == null) {
            return new Map<String, Object>{
                'date' => null
            };
        }
        
        return new Map<String, Object>{
            'date' => new Map<String, Object>{
                'start' => value.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
            }
        };
    }
    
    public static Map<String, Object> buildSelectProperty(String value) {
        if (String.isBlank(value)) {
            return new Map<String, Object>{
                'select' => null
            };
        }
        
        return new Map<String, Object>{
            'select' => new Map<String, Object>{
                'name' => value
            }
        };
    }
    
    public static Map<String, Object> buildMultiSelectProperty(List<String> values) {
        if (values == null || values.isEmpty()) {
            return new Map<String, Object>{
                'multi_select' => new List<Object>()
            };
        }
        
        List<Object> selectOptions = new List<Object>();
        for (String value : values) {
            if (!String.isBlank(value)) {
                selectOptions.add(new Map<String, Object>{
                    'name' => value
                });
            }
        }
        
        return new Map<String, Object>{
            'multi_select' => selectOptions
        };
    }
    
    public static Map<String, Object> buildRelationProperty(List<String> pageIds) {
        if (pageIds == null || pageIds.isEmpty()) {
            return new Map<String, Object>{
                'relation' => new List<Object>()
            };
        }
        
        List<Object> relations = new List<Object>();
        for (String pageId : pageIds) {
            if (!String.isBlank(pageId)) {
                relations.add(new Map<String, Object>{
                    'id' => pageId
                });
            }
        }
        
        return new Map<String, Object>{
            'relation' => relations
        };
    }
    
    private static void enforceRateLimit() {
        try {
            NotionSyncConfig__mdt config = getNotionSyncConfig();
            Integer rateLimitPerSecond = Integer.valueOf(config.RateLimitPerSecond__c);
            
            Long currentTime = System.currentTimeMillis();
            
            if (lastRequestTime == 0 || (currentTime - lastRequestTime) >= RATE_LIMIT_WINDOW) {
                lastRequestTime = currentTime;
                requestCount = 1;
                return;
            }
            
            if (requestCount >= rateLimitPerSecond) {
                Long waitTime = RATE_LIMIT_WINDOW - (currentTime - lastRequestTime);
                if (waitTime > 0) {
                    System.debug('Rate limit reached, waiting ' + waitTime + 'ms');
                }
                lastRequestTime = System.currentTimeMillis();
                requestCount = 1;
            } else {
                requestCount++;
            }
            
        } catch (Exception e) {
            System.debug('Error in rate limiting: ' + e.getMessage());
        }
    }
    
    private static NotionSyncConfig__mdt getNotionSyncConfig() {
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
}