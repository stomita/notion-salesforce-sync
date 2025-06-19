public with sharing class NotionMetadataService {
    
    public static void saveSyncConfiguration(NotionAdminController.SyncConfiguration config) {
        // Prepare metadata deployment
        Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
        
        // Create or update NotionSyncObject__mdt
        String objectDeveloperName = sanitizeDeveloperName(config.objectApiName);
        Metadata.CustomMetadata objectMetadata = new Metadata.CustomMetadata();
        objectMetadata.fullName = 'NotionSyncObject__mdt.' + objectDeveloperName;
        objectMetadata.label = config.objectApiName + ' Sync Configuration';
        
        // Set field values
        addCustomMetadataValue(objectMetadata, 'ObjectApiName__c', config.objectApiName);
        addCustomMetadataValue(objectMetadata, 'NotionDatabaseId__c', config.notionDatabaseId);
        addCustomMetadataValue(objectMetadata, 'IsActive__c', config.isActive);
        addCustomMetadataValue(objectMetadata, 'SalesforceIdPropertyName__c', config.salesforceIdPropertyName);
        
        deployContainer.addMetadata(objectMetadata);
        
        // Handle field mappings
        if (config.fieldMappings != null) {
            // First, mark existing field mappings for deletion if not in the new config
            Set<String> newFieldKeys = new Set<String>();
            for (NotionAdminController.FieldMapping mapping : config.fieldMappings) {
                String key = objectDeveloperName + '_' + sanitizeDeveloperName(mapping.salesforceFieldApiName);
                newFieldKeys.add(key);
            }
            
            // Query existing field mappings
            List<NotionSyncField__mdt> existingFields = [
                SELECT Id, DeveloperName
                FROM NotionSyncField__mdt
                WHERE NotionSyncObject__r.DeveloperName = :objectDeveloperName
            ];
            
            // Delete removed field mappings
            for (NotionSyncField__mdt existingField : existingFields) {
                if (!newFieldKeys.contains(existingField.DeveloperName)) {
                    Metadata.CustomMetadata deleteMetadata = new Metadata.CustomMetadata();
                    deleteMetadata.fullName = 'NotionSyncField__mdt.' + existingField.DeveloperName;
                    deployContainer.addMetadata(deleteMetadata);
                }
            }
            
            // Create or update field mappings
            for (NotionAdminController.FieldMapping mapping : config.fieldMappings) {
                String fieldDeveloperName = objectDeveloperName + '_' + sanitizeDeveloperName(mapping.salesforceFieldApiName);
                
                Metadata.CustomMetadata fieldMetadata = new Metadata.CustomMetadata();
                fieldMetadata.fullName = 'NotionSyncField__mdt.' + fieldDeveloperName;
                fieldMetadata.label = mapping.salesforceFieldApiName + ' → ' + mapping.notionPropertyName;
                
                // Set field values
                addCustomMetadataValue(fieldMetadata, 'NotionSyncObject__c', objectDeveloperName);
                addCustomMetadataValue(fieldMetadata, 'SalesforceFieldApiName__c', mapping.salesforceFieldApiName);
                addCustomMetadataValue(fieldMetadata, 'NotionPropertyName__c', mapping.notionPropertyName);
                addCustomMetadataValue(fieldMetadata, 'NotionPropertyType__c', mapping.notionPropertyType);
                addCustomMetadataValue(fieldMetadata, 'IsBodyContent__c', mapping.isBodyContent);
                
                deployContainer.addMetadata(fieldMetadata);
            }
        }
        
        // Handle relationship mappings
        if (config.relationshipMappings != null) {
            for (NotionAdminController.RelationshipMapping mapping : config.relationshipMappings) {
                String relationDeveloperName = objectDeveloperName + '_' + 
                    sanitizeDeveloperName(mapping.salesforceRelationshipField) + '_Relation';
                
                Metadata.CustomMetadata relationMetadata = new Metadata.CustomMetadata();
                relationMetadata.fullName = 'NotionRelation__mdt.' + relationDeveloperName;
                relationMetadata.label = mapping.salesforceRelationshipField + ' Relation';
                
                // Set field values
                if (mapping.isParent) {
                    addCustomMetadataValue(relationMetadata, 'ParentObject__c', objectDeveloperName);
                } else {
                    addCustomMetadataValue(relationMetadata, 'ChildObject__c', objectDeveloperName);
                }
                addCustomMetadataValue(relationMetadata, 'SalesforceRelationshipField__c', mapping.salesforceRelationshipField);
                addCustomMetadataValue(relationMetadata, 'NotionRelationPropertyName__c', mapping.notionRelationPropertyName);
                
                deployContainer.addMetadata(relationMetadata);
            }
        }
        
        // Deploy metadata
        Metadata.Operations.enqueueDeployment(deployContainer, new MetadataDeployCallback());
    }
    
    public static void deleteObjectConfiguration(String objectApiName) {
        String objectDeveloperName = sanitizeDeveloperName(objectApiName);
        
        Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
        
        // Delete object metadata
        Metadata.CustomMetadata objectMetadata = new Metadata.CustomMetadata();
        objectMetadata.fullName = 'NotionSyncObject__mdt.' + objectDeveloperName;
        deployContainer.addMetadata(objectMetadata);
        
        // Query and delete all related field mappings
        List<NotionSyncField__mdt> fields = [
            SELECT DeveloperName
            FROM NotionSyncField__mdt
            WHERE NotionSyncObject__r.DeveloperName = :objectDeveloperName
        ];
        
        for (NotionSyncField__mdt field : fields) {
            Metadata.CustomMetadata fieldMetadata = new Metadata.CustomMetadata();
            fieldMetadata.fullName = 'NotionSyncField__mdt.' + field.DeveloperName;
            deployContainer.addMetadata(fieldMetadata);
        }
        
        // Query and delete all related relationships
        // Custom Metadata doesn't support OR in WHERE clause, so we need two queries
        List<NotionRelation__mdt> parentRelations = [
            SELECT DeveloperName
            FROM NotionRelation__mdt
            WHERE ParentObject__r.DeveloperName = :objectDeveloperName
        ];
        
        List<NotionRelation__mdt> childRelations = [
            SELECT DeveloperName
            FROM NotionRelation__mdt
            WHERE ChildObject__r.DeveloperName = :objectDeveloperName
        ];
        
        // Combine the results
        List<NotionRelation__mdt> relations = new List<NotionRelation__mdt>();
        relations.addAll(parentRelations);
        relations.addAll(childRelations);
        
        for (NotionRelation__mdt relation : relations) {
            Metadata.CustomMetadata relationMetadata = new Metadata.CustomMetadata();
            relationMetadata.fullName = 'NotionRelation__mdt.' + relation.DeveloperName;
            deployContainer.addMetadata(relationMetadata);
        }
        
        // Deploy deletion
        Metadata.Operations.enqueueDeployment(deployContainer, new MetadataDeployCallback());
    }
    
    private static void addCustomMetadataValue(Metadata.CustomMetadata metadata, String field, Object value) {
        Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
        customField.field = field;
        customField.value = value;
        metadata.values.add(customField);
    }
    
    @TestVisible
    private static String sanitizeDeveloperName(String input) {
        // Remove invalid characters and ensure it starts with a letter
        String sanitized = input.replaceAll('[^a-zA-Z0-9_]', '_');
        
        // Ensure it starts with a letter
        if (sanitized.length() > 0 && !Pattern.matches('[a-zA-Z].*', sanitized)) {
            sanitized = 'X' + sanitized;
        }
        
        // Truncate if too long (max 40 chars for developer name)
        if (sanitized.length() > 40) {
            sanitized = sanitized.substring(0, 40);
        }
        
        return sanitized;
    }
    
    public class MetadataDeployCallback implements Metadata.DeployCallback {
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
            if (result.status == Metadata.DeployStatus.Succeeded) {
                System.debug('Metadata deployment succeeded');
            } else {
                System.debug('Metadata deployment failed');
                for (Metadata.DeployMessage message : result.details.componentFailures) {
                    System.debug('Error: ' + message.fullName + ' - ' + message.problem);
                }
            }
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<NotionDatabase__mdt> getNotionDatabases() {
        return [
            SELECT Id, DeveloperName, DatabaseId__c, DatabaseName__c, WorkspaceId__c
            FROM NotionDatabase__mdt
            ORDER BY DatabaseName__c
        ];
    }
    
    @AuraEnabled
    public static void saveNotionDatabase(String databaseId, String databaseName, String workspaceId) {
        String developerName = sanitizeDeveloperName(databaseName);
        
        Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
        
        Metadata.CustomMetadata databaseMetadata = new Metadata.CustomMetadata();
        databaseMetadata.fullName = 'NotionDatabase__mdt.' + developerName;
        databaseMetadata.label = databaseName;
        
        addCustomMetadataValue(databaseMetadata, 'DatabaseId__c', databaseId);
        addCustomMetadataValue(databaseMetadata, 'DatabaseName__c', databaseName);
        addCustomMetadataValue(databaseMetadata, 'WorkspaceId__c', workspaceId);
        
        deployContainer.addMetadata(databaseMetadata);
        
        Metadata.Operations.enqueueDeployment(deployContainer, new MetadataDeployCallback());
    }
}