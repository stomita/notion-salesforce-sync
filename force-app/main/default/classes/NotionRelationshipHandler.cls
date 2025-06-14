public class NotionRelationshipHandler {
    
    private Map<String, List<RelationshipConfig>> relationshipsByChildObject;
    private Map<String, List<RelationshipConfig>> relationshipsByParentObject;
    private Map<String, Set<String>> dependencyGraph;
    private static Map<String, String> pageIdCache = new Map<String, String>();
    
    public class RelationshipConfig {
        public String parentObjectType { get; set; }
        public String childObjectType { get; set; }
        public String salesforceRelationshipField { get; set; }
        public String notionRelationPropertyName { get; set; }
        public String parentNotionDatabaseId { get; set; }
        public String childNotionDatabaseId { get; set; }
        public String parentSalesforceIdProperty { get; set; }
        public String childSalesforceIdProperty { get; set; }
    }
    
    public class RelationshipHandlerException extends Exception {}
    
    public NotionRelationshipHandler() {
        loadRelationshipConfigurations();
        buildDependencyGraph();
    }
    
    private void loadRelationshipConfigurations() {
        relationshipsByChildObject = new Map<String, List<RelationshipConfig>>();
        relationshipsByParentObject = new Map<String, List<RelationshipConfig>>();
        
        List<NotionRelation__mdt> relations = [
            SELECT Id, ParentObject__r.ObjectApiName__c, ParentObject__r.NotionDatabaseId__c, 
                   ParentObject__r.SalesforceIdPropertyName__c,
                   ChildObject__r.ObjectApiName__c, ChildObject__r.NotionDatabaseId__c,
                   ChildObject__r.SalesforceIdPropertyName__c,
                   SalesforceRelationshipField__c, NotionRelationPropertyName__c
            FROM NotionRelation__mdt
            WHERE IsActive__c = true
            AND ParentObject__r.IsActive__c = true
            AND ChildObject__r.IsActive__c = true
        ];
        
        for (NotionRelation__mdt relation : relations) {
            RelationshipConfig config = new RelationshipConfig();
            config.parentObjectType = relation.ParentObject__r.ObjectApiName__c;
            config.childObjectType = relation.ChildObject__r.ObjectApiName__c;
            config.salesforceRelationshipField = relation.SalesforceRelationshipField__c;
            config.notionRelationPropertyName = relation.NotionRelationPropertyName__c;
            config.parentNotionDatabaseId = relation.ParentObject__r.NotionDatabaseId__c;
            config.childNotionDatabaseId = relation.ChildObject__r.NotionDatabaseId__c;
            config.parentSalesforceIdProperty = relation.ParentObject__r.SalesforceIdPropertyName__c;
            config.childSalesforceIdProperty = relation.ChildObject__r.SalesforceIdPropertyName__c;
            
            if (!relationshipsByChildObject.containsKey(config.childObjectType)) {
                relationshipsByChildObject.put(config.childObjectType, new List<RelationshipConfig>());
            }
            relationshipsByChildObject.get(config.childObjectType).add(config);
            
            if (!relationshipsByParentObject.containsKey(config.parentObjectType)) {
                relationshipsByParentObject.put(config.parentObjectType, new List<RelationshipConfig>());
            }
            relationshipsByParentObject.get(config.parentObjectType).add(config);
        }
        
        System.debug('NotionRelationshipHandler: Loaded ' + relations.size() + ' relationship configurations');
    }
    
    private void buildDependencyGraph() {
        dependencyGraph = new Map<String, Set<String>>();
        
        for (String childObjectType : relationshipsByChildObject.keySet()) {
            if (!dependencyGraph.containsKey(childObjectType)) {
                dependencyGraph.put(childObjectType, new Set<String>());
            }
            
            for (RelationshipConfig config : relationshipsByChildObject.get(childObjectType)) {
                dependencyGraph.get(childObjectType).add(config.parentObjectType);
            }
        }
        
        System.debug('NotionRelationshipHandler: Built dependency graph: ' + dependencyGraph);
    }
    
    public List<String> getProcessingOrder(Set<String> objectTypes) {
        List<String> ordered = new List<String>();
        Set<String> processed = new Set<String>();
        Set<String> visiting = new Set<String>();
        
        for (String objectType : objectTypes) {
            if (!processed.contains(objectType)) {
                visitNode(objectType, ordered, processed, visiting, objectTypes);
            }
        }
        
        System.debug('NotionRelationshipHandler: Processing order: ' + ordered);
        return ordered;
    }
    
    private void visitNode(String objectType, List<String> ordered, Set<String> processed, 
                          Set<String> visiting, Set<String> validObjectTypes) {
        if (visiting.contains(objectType)) {
            throw new RelationshipHandlerException('Circular dependency detected involving: ' + objectType);
        }
        
        if (processed.contains(objectType)) {
            return;
        }
        
        visiting.add(objectType);
        
        if (dependencyGraph.containsKey(objectType)) {
            for (String dependency : dependencyGraph.get(objectType)) {
                if (validObjectTypes.contains(dependency)) {
                    visitNode(dependency, ordered, processed, visiting, validObjectTypes);
                }
            }
        }
        
        visiting.remove(objectType);
        processed.add(objectType);
        ordered.add(objectType);
    }
    
    public Map<String, Object> enrichNotionPropertiesWithRelations(String objectType, SObject record, 
                                                                   Map<String, Object> properties) {
        if (!relationshipsByChildObject.containsKey(objectType)) {
            return properties;
        }
        
        Map<String, Object> enrichedProperties = new Map<String, Object>(properties);
        
        for (RelationshipConfig config : relationshipsByChildObject.get(objectType)) {
            Object relationshipValue = record.get(config.salesforceRelationshipField);
            
            if (relationshipValue != null) {
                String parentId = String.valueOf(relationshipValue);
                String parentNotionPageId = findNotionPageId(parentId, config.parentNotionDatabaseId, 
                                                           config.parentSalesforceIdProperty);
                
                if (String.isNotBlank(parentNotionPageId)) {
                    List<Map<String, Object>> relationArray = new List<Map<String, Object>>{
                        new Map<String, Object>{ 'id' => parentNotionPageId }
                    };
                    
                    enrichedProperties.put(config.notionRelationPropertyName, 
                                         new Map<String, Object>{ 'relation' => relationArray });
                    
                    System.debug('NotionRelationshipHandler: Added relation ' + config.notionRelationPropertyName + 
                               ' with parent page ID: ' + parentNotionPageId);
                }
            }
        }
        
        return enrichedProperties;
    }
    
    
    public Map<Id, String> getRelatedRecordNotionPageIds(String objectType, Set<Id> recordIds) {
        Map<Id, String> recordToPageIdMap = new Map<Id, String>();
        
        if (!relationshipsByChildObject.containsKey(objectType) || recordIds.isEmpty()) {
            return recordToPageIdMap;
        }
        
        Set<String> fieldsToQuery = new Set<String>{'Id'};
        for (RelationshipConfig config : relationshipsByChildObject.get(objectType)) {
            fieldsToQuery.add(config.salesforceRelationshipField);
        }
        
        String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + 
                      ' FROM ' + objectType + ' WHERE Id IN :recordIds';
        
        try {
            List<SObject> records = Database.query(query);
            
            // Collect all parent IDs by database for bulk lookup
            Map<String, Set<String>> parentIdsByDatabase = new Map<String, Set<String>>();
            Map<String, RelationshipConfig> databaseToConfig = new Map<String, RelationshipConfig>();
            
            for (SObject record : records) {
                for (RelationshipConfig config : relationshipsByChildObject.get(objectType)) {
                    Object relationshipValue = record.get(config.salesforceRelationshipField);
                    
                    if (relationshipValue != null) {
                        String parentId = String.valueOf(relationshipValue);
                        String databaseId = config.parentNotionDatabaseId;
                        
                        if (!parentIdsByDatabase.containsKey(databaseId)) {
                            parentIdsByDatabase.put(databaseId, new Set<String>());
                        }
                        parentIdsByDatabase.get(databaseId).add(parentId);
                        databaseToConfig.put(databaseId, config);
                    }
                }
            }
            
            // Perform bulk lookups for each database
            Map<String, String> allParentPageIds = new Map<String, String>();
            for (String databaseId : parentIdsByDatabase.keySet()) {
                RelationshipConfig config = databaseToConfig.get(databaseId);
                Set<String> parentIds = parentIdsByDatabase.get(databaseId);
                
                Map<String, String> databasePageIds = bulkFindNotionPageIds(
                    parentIds, databaseId, config.parentSalesforceIdProperty);
                allParentPageIds.putAll(databasePageIds);
            }
            
            // Map records to their parent page IDs
            for (SObject record : records) {
                for (RelationshipConfig config : relationshipsByChildObject.get(objectType)) {
                    Object relationshipValue = record.get(config.salesforceRelationshipField);
                    
                    if (relationshipValue != null) {
                        String parentId = String.valueOf(relationshipValue);
                        if (allParentPageIds.containsKey(parentId)) {
                            recordToPageIdMap.put(record.Id, allParentPageIds.get(parentId));
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('NotionRelationshipHandler: Error querying related records: ' + e.getMessage());
            throw new RelationshipHandlerException('Failed to get related record page IDs: ' + e.getMessage());
        }
        
        return recordToPageIdMap;
    }
    
    public String findNotionPageId(String salesforceId, String notionDatabaseId, String salesforceIdProperty) {
        // Check cache first
        String cacheKey = notionDatabaseId + ':' + salesforceId;
        if (pageIdCache.containsKey(cacheKey)) {
            return pageIdCache.get(cacheKey);
        }
        
        // Check governor limits
        if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
            throw new RelationshipHandlerException('Callout limit reached');
        }
        
        Map<String, Object> filter = new Map<String, Object>{
            'property' => salesforceIdProperty,
            'rich_text' => new Map<String, Object>{
                'equals' => salesforceId
            }
        };
        
        try {
            NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(notionDatabaseId, filter);
            
            if (response.success) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
                List<Object> results = (List<Object>) responseBody.get('results');
                
                if (!results.isEmpty()) {
                    Map<String, Object> page = (Map<String, Object>) results[0];
                    String pageId = (String) page.get('id');
                    
                    // Cache the result
                    pageIdCache.put(cacheKey, pageId);
                    return pageId;
                }
            } else {
                System.debug('NotionRelationshipHandler: Failed to find Notion page for Salesforce ID ' + 
                           salesforceId + ': ' + response.errorMessage);
            }
            
        } catch (Exception e) {
            System.debug('NotionRelationshipHandler: Error finding Notion page: ' + e.getMessage());
            throw new RelationshipHandlerException('Failed to find Notion page for ID: ' + salesforceId + '. Error: ' + e.getMessage());
        }
        
        return null;
    }
    
    public Map<String, String> bulkFindNotionPageIds(Set<String> salesforceIds, String notionDatabaseId, String salesforceIdProperty) {
        Map<String, String> results = new Map<String, String>();
        Set<String> uncachedIds = new Set<String>();
        
        // Check cache first
        for (String salesforceId : salesforceIds) {
            String cacheKey = notionDatabaseId + ':' + salesforceId;
            if (pageIdCache.containsKey(cacheKey)) {
                results.put(salesforceId, pageIdCache.get(cacheKey));
            } else {
                uncachedIds.add(salesforceId);
            }
        }
        
        // Query for uncached IDs
        if (!uncachedIds.isEmpty()) {
            // Check governor limits
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                throw new RelationshipHandlerException('Callout limit reached during bulk lookup');
            }
            
            // Build OR filter for multiple IDs
            List<Object> orConditions = new List<Object>();
            for (String salesforceId : uncachedIds) {
                orConditions.add(new Map<String, Object>{
                    'property' => salesforceIdProperty,
                    'rich_text' => new Map<String, Object>{
                        'equals' => salesforceId
                    }
                });
            }
            
            Map<String, Object> filter = new Map<String, Object>{
                'or' => orConditions
            };
            
            try {
                NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(notionDatabaseId, filter);
                
                if (response.success) {
                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
                    List<Object> pages = (List<Object>) responseBody.get('results');
                    
                    for (Object pageObj : pages) {
                        Map<String, Object> page = (Map<String, Object>) pageObj;
                        String pageId = (String) page.get('id');
                        
                        // Extract Salesforce ID from properties
                        Map<String, Object> properties = (Map<String, Object>) page.get('properties');
                        if (properties.containsKey(salesforceIdProperty)) {
                            Map<String, Object> idProperty = (Map<String, Object>) properties.get(salesforceIdProperty);
                            List<Object> richText = (List<Object>) idProperty.get('rich_text');
                            if (!richText.isEmpty()) {
                                Map<String, Object> textObj = (Map<String, Object>) richText[0];
                                Map<String, Object> text = (Map<String, Object>) textObj.get('text');
                                String salesforceId = (String) text.get('content');
                                
                                results.put(salesforceId, pageId);
                                
                                // Cache the result
                                String cacheKey = notionDatabaseId + ':' + salesforceId;
                                pageIdCache.put(cacheKey, pageId);
                            }
                        }
                    }
                } else {
                    throw new RelationshipHandlerException('Failed to bulk query Notion pages: ' + response.errorMessage);
                }
                
            } catch (Exception e) {
                System.debug('NotionRelationshipHandler: Error in bulk lookup: ' + e.getMessage());
                throw new RelationshipHandlerException('Failed to bulk find Notion pages. Error: ' + e.getMessage());
            }
        }
        
        return results;
    }
    
    public Boolean hasRelationships(String objectType) {
        return relationshipsByChildObject.containsKey(objectType) || 
               relationshipsByParentObject.containsKey(objectType);
    }
    
    public List<RelationshipConfig> getChildRelationships(String objectType) {
        return relationshipsByChildObject.get(objectType) != null ? 
               relationshipsByChildObject.get(objectType) : new List<RelationshipConfig>();
    }
    
    public List<RelationshipConfig> getParentRelationships(String objectType) {
        return relationshipsByParentObject.get(objectType) != null ? 
               relationshipsByParentObject.get(objectType) : new List<RelationshipConfig>();
    }
}