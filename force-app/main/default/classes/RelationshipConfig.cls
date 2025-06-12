public class RelationshipConfig {
    public String parentObjectApiName;
    public String childObjectApiName;
    public String salesforceRelationshipField;
    public String notionRelationPropertyName;
    public Boolean enableCascadeDelete;
    
    public RelationshipConfig(NotionRelation__mdt relationMetadata) {
        this.parentObjectApiName = relationMetadata.ParentObject__r.ObjectApiName__c;
        this.childObjectApiName = relationMetadata.ChildObject__r.ObjectApiName__c;
        this.salesforceRelationshipField = relationMetadata.SalesforceRelationshipField__c;
        this.notionRelationPropertyName = relationMetadata.NotionRelationPropertyName__c;
        this.enableCascadeDelete = relationMetadata.EnableCascadeDelete__c;
    }
}