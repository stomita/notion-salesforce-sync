public class NotionRelationshipHandler {
    
    private static List<RelationshipConfig> relationshipConfigs;
    
    static {
        loadRelationshipConfigurations();
    }
    
    private static void loadRelationshipConfigurations() {
        relationshipConfigs = new List<RelationshipConfig>();
        
        List<NotionRelation__mdt> relations = [
            SELECT Id, ParentObject__c, ChildObject__c, SalesforceRelationshipField__c,
                   NotionRelationPropertyName__c, EnableCascadeDelete__c,
                   ParentObject__r.ObjectApiName__c, ChildObject__r.ObjectApiName__c
            FROM NotionRelation__mdt
        ];
        
        for (NotionRelation__mdt relation : relations) {
            relationshipConfigs.add(new RelationshipConfig(relation));
        }
    }
    
    public static List<String> getChildRecordsToDelete(String parentObjectType, String parentRecordId) {
        List<String> childRecordIds = new List<String>();
        
        List<RelationshipConfig> applicableRelations = getRelationsForParentObject(parentObjectType);
        
        for (RelationshipConfig config : applicableRelations) {
            if (config.enableCascadeDelete) {
                List<String> childIds = queryChildRecords(config, parentRecordId);
                childRecordIds.addAll(childIds);
            }
        }
        
        return childRecordIds;
    }
    
    private static List<RelationshipConfig> getRelationsForParentObject(String parentObjectType) {
        List<RelationshipConfig> applicableRelations = new List<RelationshipConfig>();
        
        for (RelationshipConfig config : relationshipConfigs) {
            if (config.parentObjectApiName == parentObjectType) {
                applicableRelations.add(config);
            }
        }
        
        return applicableRelations;
    }
    
    private static List<String> queryChildRecords(RelationshipConfig config, String parentRecordId) {
        List<String> childIds = new List<String>();
        
        try {
            String query = 'SELECT Id FROM ' + config.childObjectApiName + 
                          ' WHERE ' + config.salesforceRelationshipField + ' = :parentRecordId';
            
            List<SObject> childRecords = Database.query(query);
            
            for (SObject record : childRecords) {
                childIds.add(record.Id);
            }
        } catch (Exception e) {
            System.debug('Error querying child records for relationship: ' + config.parentObjectApiName + 
                        ' -> ' + config.childObjectApiName + ': ' + e.getMessage());
        }
        
        return childIds;
    }
    
    public static List<RelationshipConfig> getAllRelationshipConfigs() {
        return relationshipConfigs;
    }
    
    public static void refreshConfigurations() {
        loadRelationshipConfigurations();
    }
}