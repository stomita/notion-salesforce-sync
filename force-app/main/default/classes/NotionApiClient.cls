public class NotionApiClient {
    
    private static final String NAMED_CREDENTIAL = 'callout:Notion_API';
    private static final String API_VERSION = '2022-06-28';
    
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
        public Map<String, Object> properties;
        public List<Object> children;
        
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
            
            String jsonBody = JSON.serialize(requestBody);
            request.setBody(jsonBody);
            
            // Debug logging
            System.debug('NotionApiClient.createPage: Sending request to Notion');
            System.debug('Request Body: ' + jsonBody);
            
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
    
    private static HttpRequest buildHttpRequest(String method, String endpoint) {
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setEndpoint(NAMED_CREDENTIAL + endpoint);
        request.setHeader('Content-Type', 'application/json');
        // Notion-Version header is handled by Named Credential
        // Authorization header is handled by External Credential
        request.setTimeout(60000);
        
        return request;
    }
    
    private static NotionResponse processResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        
        // Debug logging
        System.debug('NotionApiClient: Response Status Code: ' + statusCode);
        if (statusCode != 200) {
            System.debug('NotionApiClient: Error Response Body: ' + responseBody);
        }
        
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
    
    public static Map<String, Object> buildEmailProperty(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        
        return new Map<String, Object>{
            'email' => value
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
}