public class NotionApiClient {
    
    private static final String NAMED_CREDENTIAL = 'callout:' + getNamespacedName('Notion_API');
    private static final String API_VERSION = '2022-06-28';
    
    /**
     * Get the properly namespaced name for a Named Credential
     * This handles both namespaced (managed package) and non-namespaced scenarios
     */
    private static String getNamespacedName(String baseName) {
        // Get the namespace by examining the class name
        String className = NotionApiClient.class.getName();
        
        // If the class name contains a dot, it has a namespace
        if (className.contains('.')) {
            String namespace = className.substringBefore('.');
            return namespace + '__' + baseName;
        }
        
        // No namespace, return the base name as-is
        return baseName;
    }
    
    public class NotionApiException extends Exception {}
    
    public class NotionResponse {
        public Boolean success;
        public String pageId;
        public String errorMessage;
        public Integer statusCode;
        public String responseBody;
        public Boolean isRateLimited;
        public Integer retryAfterSeconds;
        
        public NotionResponse(Boolean success, String pageId, String errorMessage, Integer statusCode, String responseBody) {
            this.success = success;
            this.pageId = pageId;
            this.errorMessage = errorMessage;
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.isRateLimited = false;
            this.retryAfterSeconds = null;
        }
        
        public NotionResponse(Boolean success, String pageId, String errorMessage, Integer statusCode, String responseBody, Boolean isRateLimited, Integer retryAfterSeconds) {
            this.success = success;
            this.pageId = pageId;
            this.errorMessage = errorMessage;
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.isRateLimited = isRateLimited;
            this.retryAfterSeconds = retryAfterSeconds;
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
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
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
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, null, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (Exception e) {
            return new NotionResponse(false, null, 'Exception during page creation: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse updatePage(String pageId, Map<String, Object> properties) {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('PATCH', '/v1/pages/' + pageId);
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'properties' => properties
            };
            
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, pageId, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (CalloutException e) {
            // Handle timeout specifically
            if (e.getMessage().contains('maximum time allotted for callout')) {
                return new NotionResponse(false, pageId, 'Update timeout: Response took longer than 110 seconds. The page may be too large or Notion is responding slowly.', null, null);
            }
            return new NotionResponse(false, pageId, 'Callout exception during page update: ' + e.getMessage(), null, null);
        } catch (Exception e) {
            return new NotionResponse(false, pageId, 'Exception during page update: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse deletePage(String pageId) {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('PATCH', '/v1/pages/' + pageId);
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'archived' => true
            };
            
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, pageId, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (Exception e) {
            return new NotionResponse(false, pageId, 'Exception during page deletion: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse queryDatabase(String databaseId, Map<String, Object> filter) {
        return queryDatabase(databaseId, filter, null, null);
    }
    
    public static NotionResponse queryDatabase(String databaseId, Map<String, Object> filter, String startCursor, Integer pageSize) {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('POST', '/v1/databases/' + databaseId + '/query');
            
            Map<String, Object> requestBody = new Map<String, Object>();
            if (filter != null && !filter.isEmpty()) {
                requestBody.put('filter', filter);
            }
            
            if (String.isNotBlank(startCursor)) {
                requestBody.put('start_cursor', startCursor);
            }
            
            if (pageSize != null && pageSize > 0) {
                requestBody.put('page_size', Math.min(pageSize, 100)); // Notion max is 100
            }
            
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, null, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (CalloutException e) {
            // Handle timeout specifically
            if (e.getMessage().contains('maximum time allotted for callout')) {
                return new NotionResponse(false, null, 'Query timeout: Response took longer than 110 seconds. Try reducing the query scope.', null, null);
            }
            return new NotionResponse(false, null, 'Callout exception during database query: ' + e.getMessage(), null, null);
        } catch (Exception e) {
            return new NotionResponse(false, null, 'Exception during database query: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse getPage(String pageId) {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('GET', '/v1/pages/' + pageId);
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, pageId, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (Exception e) {
            return new NotionResponse(false, pageId, 'Exception during page retrieval: ' + e.getMessage(), null, null);
        }
    }
    
    // Method to get all blocks (children) of a page
    public static NotionResponse getPageBlocks(String pageId) {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('GET', '/v1/blocks/' + pageId + '/children');
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, pageId, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (Exception e) {
            return new NotionResponse(false, pageId, 'Exception during blocks retrieval: ' + e.getMessage(), null, null);
        }
    }
    
    // Method to append blocks to a page (for updating body content)
    public static NotionResponse appendPageBlocks(String pageId, List<Object> children) {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('PATCH', '/v1/blocks/' + pageId + '/children');
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'children' => children
            };
            
            String jsonBody = JSON.serialize(requestBody);
            request.setBody(jsonBody);
            
            // Debug logging
            System.debug('NotionApiClient.appendPageBlocks: Appending blocks to page ' + pageId);
            System.debug('Request Body: ' + jsonBody);
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, pageId, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (Exception e) {
            return new NotionResponse(false, pageId, 'Exception during blocks append: ' + e.getMessage(), null, null);
        }
    }
    
    // Method to delete a block
    public static NotionResponse deleteBlock(String blockId) {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('DELETE', '/v1/blocks/' + blockId);
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, blockId, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (Exception e) {
            return new NotionResponse(false, blockId, 'Exception during block deletion: ' + e.getMessage(), null, null);
        }
    }
    
    private static HttpRequest buildHttpRequest(String method, String endpoint) {
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setEndpoint(NAMED_CREDENTIAL + endpoint);
        request.setHeader('Content-Type', 'application/json');
        // Notion-Version header is handled by Named Credential
        // Authorization header is handled by External Credential
        // Set timeout to 110 seconds (just under Salesforce's 120 second limit)
        // This gives us time to handle the timeout gracefully
        request.setTimeout(110000);
        
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
        
        // Handle rate limiting (429 status code)
        if (statusCode == 429) {
            Boolean isRateLimited = NotionRateLimiter.handleRateLimit(response);
            String retryAfterHeader = response.getHeader('Retry-After');
            Integer retryAfterSeconds = null;
            
            if (String.isNotBlank(retryAfterHeader)) {
                try {
                    retryAfterSeconds = Integer.valueOf(retryAfterHeader);
                } catch (Exception e) {
                    System.debug('Failed to parse Retry-After header: ' + retryAfterHeader);
                }
            }
            
            String errorMessage = 'Rate limit exceeded. ';
            if (retryAfterSeconds != null) {
                errorMessage += 'Retry after ' + retryAfterSeconds + ' seconds.';
            } else {
                errorMessage += 'Please retry later.';
            }
            
            return new NotionResponse(false, null, errorMessage, statusCode, responseBody, true, retryAfterSeconds);
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
        // If value is blank, return empty array to clear the property
        if (String.isBlank(value)) {
            return new Map<String, Object>{
                'rich_text' => new List<Object>()
            };
        }
        
        return new Map<String, Object>{
            'rich_text' => new List<Object>{
                new Map<String, Object>{
                    'text' => new Map<String, Object>{
                        'content' => value
                    }
                }
            }
        };
    }
    
    public static Map<String, Object> buildTitleProperty(String value) {
        // If value is blank, return empty array to clear the property
        if (String.isBlank(value)) {
            return new Map<String, Object>{
                'title' => new List<Object>()
            };
        }
        
        return new Map<String, Object>{
            'title' => new List<Object>{
                new Map<String, Object>{
                    'text' => new Map<String, Object>{
                        'content' => value
                    }
                }
            }
        };
    }
    
    public static Map<String, Object> buildNumberProperty(Decimal value) {
        // Notion accepts null to clear number properties
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
        // Notion accepts null to clear email, but not empty string
        return new Map<String, Object>{
            'email' => String.isBlank(value) ? null : value
        };
    }
    
    public static Map<String, Object> buildPhoneProperty(String value) {
        // Notion accepts null to clear phone, but not empty string
        return new Map<String, Object>{
            'phone_number' => String.isBlank(value) ? null : value
        };
    }
    
    public static Map<String, Object> buildUrlProperty(String value) {
        // Notion accepts null to clear URL, but not empty string
        return new Map<String, Object>{
            'url' => String.isBlank(value) ? null : value
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
    
    public static NotionResponse searchDatabases() {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('POST', '/v1/search');
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'filter' => new Map<String, Object>{
                    'value' => 'database',
                    'property' => 'object'
                },
                'page_size' => 100
            };
            
            request.setBody(JSON.serialize(requestBody));
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, null, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (Exception e) {
            return new NotionResponse(false, null, 'Exception during database search: ' + e.getMessage(), null, null);
        }
    }
    
    public static NotionResponse getDatabase(String databaseId) {
        try {
            // Apply rate limiting before making the request
            NotionRateLimiter.throttleRequest();
            
            HttpRequest request = buildHttpRequest('GET', '/v1/databases/' + databaseId);
            
            HttpResponse response = new Http().send(request);
            return processResponse(response);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Return rate limit error
            return new NotionResponse(false, databaseId, 'Rate limit exceeded: ' + e.getMessage(), null, null, true, null);
        } catch (Exception e) {
            return new NotionResponse(false, databaseId, 'Exception during database retrieval: ' + e.getMessage(), null, null);
        }
    }
    
    /**
     * Verify Notion API authentication by making a simple API call
     * This method is used to check if the credentials are properly configured
     * @return NotionResponse with success status and user information if authenticated
     */
    public static NotionResponse verifyAuthentication() {
        try {
            // Use the users/me endpoint to verify authentication
            // This is a lightweight endpoint that returns current bot user info
            HttpRequest request = buildHttpRequest('GET', '/v1/users/me');
            
            HttpResponse response = new Http().send(request);
            
            // Process the response
            Integer statusCode = response.getStatusCode();
            String responseBody = response.getBody();
            
            System.debug('NotionApiClient.verifyAuthentication: Status Code: ' + statusCode);
            
            if (statusCode == 200) {
                try {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    String botId = (String) responseMap.get('id');
                    String botName = responseMap.containsKey('name') ? (String) responseMap.get('name') : 'Notion Integration';
                    
                    return new NotionResponse(
                        true, 
                        botId, 
                        'Authentication successful. Bot: ' + botName, 
                        statusCode, 
                        responseBody
                    );
                } catch (Exception e) {
                    return new NotionResponse(
                        false, 
                        null, 
                        'Authentication succeeded but failed to parse response: ' + e.getMessage(), 
                        statusCode, 
                        responseBody
                    );
                }
            } else if (statusCode == 401) {
                return new NotionResponse(
                    false, 
                    null, 
                    'Authentication failed: Invalid API key or unauthorized access', 
                    statusCode, 
                    responseBody
                );
            } else {
                String errorMessage = 'Authentication check failed with HTTP ' + statusCode;
                try {
                    Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    if (errorResponse.containsKey('message')) {
                        errorMessage += ': ' + (String) errorResponse.get('message');
                    }
                } catch (Exception e) {
                    // Ignore parsing error
                }
                
                return new NotionResponse(false, null, errorMessage, statusCode, responseBody);
            }
            
        } catch (CalloutException e) {
            // Handle specific callout exceptions
            String errorMessage = e.getMessage();
            if (errorMessage.contains('Unauthorized endpoint')) {
                return new NotionResponse(
                    false, 
                    null, 
                    'Authentication failed: Named Credential not configured or unauthorized', 
                    401, 
                    null
                );
            }
            return new NotionResponse(
                false, 
                null, 
                'Authentication check failed: ' + errorMessage, 
                null, 
                null
            );
        } catch (Exception e) {
            return new NotionResponse(
                false, 
                null, 
                'Unexpected error during authentication check: ' + e.getMessage(), 
                null, 
                null
            );
        }
    }
}