public class NotionRelationshipHandler {
    
    private Map<String, List<RelationshipConfig>> relationshipsByChildObject;
    private Map<String, List<RelationshipConfig>> relationshipsByParentObject;
    private Map<String, Set<String>> dependencyGraph;
    
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
    
    public List<String> getChildRecordsToDelete(String parentObjectType, String parentRecordId) {
        List<String> childRecordsToDelete = new List<String>();
        
        if (!relationshipsByParentObject.containsKey(parentObjectType)) {
            return childRecordsToDelete;
        }
        
        for (RelationshipConfig config : relationshipsByParentObject.get(parentObjectType)) {
            String query = 'SELECT Id FROM ' + config.childObjectType + 
                          ' WHERE ' + config.salesforceRelationshipField + ' = :parentRecordId';
            
            try {
                List<SObject> childRecords = Database.query(query);
                for (SObject childRecord : childRecords) {
                    childRecordsToDelete.add(String.valueOf(childRecord.Id));
                }
                
                System.debug('NotionRelationshipHandler: Found ' + childRecords.size() + 
                           ' child records of type ' + config.childObjectType + 
                           ' for parent ' + parentRecordId);
                           
            } catch (Exception e) {
                System.debug('NotionRelationshipHandler: Error querying child records: ' + e.getMessage());
            }
        }
        
        return childRecordsToDelete;
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
            
            for (SObject record : records) {
                for (RelationshipConfig config : relationshipsByChildObject.get(objectType)) {
                    Object relationshipValue = record.get(config.salesforceRelationshipField);
                    
                    if (relationshipValue != null) {
                        String parentId = String.valueOf(relationshipValue);
                        String parentNotionPageId = findNotionPageId(parentId, config.parentNotionDatabaseId, 
                                                                   config.parentSalesforceIdProperty);
                        
                        if (String.isNotBlank(parentNotionPageId)) {
                            recordToPageIdMap.put(record.Id, parentNotionPageId);
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('NotionRelationshipHandler: Error querying related records: ' + e.getMessage());
        }
        
        return recordToPageIdMap;
    }
    
    private String findNotionPageId(String salesforceId, String notionDatabaseId, String salesforceIdProperty) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Notion_API/v1/databases/' + notionDatabaseId + '/query');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Notion-Version', '2022-06-28');
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'filter' => new Map<String, Object>{
                'property' => salesforceIdProperty,
                'rich_text' => new Map<String, Object>{
                    'equals' => salesforceId
                }
            }
        };
        
        req.setBody(JSON.serialize(requestBody));
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> results = (List<Object>) responseBody.get('results');
                
                if (!results.isEmpty()) {
                    Map<String, Object> page = (Map<String, Object>) results[0];
                    return (String) page.get('id');
                }
            } else {
                System.debug('NotionRelationshipHandler: Failed to find Notion page for Salesforce ID ' + 
                           salesforceId + ': ' + res.getBody());
            }
            
        } catch (Exception e) {
            System.debug('NotionRelationshipHandler: Error finding Notion page: ' + e.getMessage());
        }
        
        return null;
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