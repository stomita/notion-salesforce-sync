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
        // First, find the actual DeveloperName for this object
        List<NotionSyncObject__mdt> existingObjects = [
            SELECT DeveloperName, NotionDatabaseId__c, IsActive__c, SalesforceIdPropertyName__c
            FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectApiName
            AND (IsDeleted__c = false OR IsDeleted__c = null)
            LIMIT 1
        ];
        
        if (existingObjects.isEmpty()) {
            throw new AuraHandledException('No sync configuration found for object: ' + objectApiName);
        }
        
        NotionSyncObject__mdt existing = existingObjects[0];
        String objectDeveloperName = existing.DeveloperName;
        
        Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
        
        // Soft delete: Update the object metadata to set IsDeleted__c = true
        Metadata.CustomMetadata objectMetadata = new Metadata.CustomMetadata();
        objectMetadata.fullName = 'NotionSyncObject__mdt.' + objectDeveloperName;
        // Truncate label to ensure it fits within 40 character limit
        String label = objectApiName + ' (Deleted)';
        if (label.length() > 40) {
            label = label.substring(0, 37) + '...';
        }
        objectMetadata.label = label;
        
        // Mark as deleted
        addCustomMetadataValue(objectMetadata, 'IsDeleted__c', true);
        // Preserve existing field values
        addCustomMetadataValue(objectMetadata, 'ObjectApiName__c', objectApiName);
        addCustomMetadataValue(objectMetadata, 'NotionDatabaseId__c', existing.NotionDatabaseId__c);
        addCustomMetadataValue(objectMetadata, 'IsActive__c', false); // Deactivate when deleting
        addCustomMetadataValue(objectMetadata, 'SalesforceIdPropertyName__c', existing.SalesforceIdPropertyName__c);
        
        deployContainer.addMetadata(objectMetadata);
        
        // Note: We don't need to delete field mappings and relationships
        // They will be automatically excluded when we filter by non-deleted parent objects
        
        // Deploy soft deletion
        System.debug('Enqueuing metadata deployment for soft delete');
        System.debug('Metadata fullName: ' + objectMetadata.fullName);
        System.debug('IsDeleted value: ' + true);
        
        Id deploymentId = Metadata.Operations.enqueueDeployment(deployContainer, new MetadataDeployCallback());
        System.debug('Deployment enqueued with ID: ' + deploymentId);
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
            System.debug('MetadataDeployCallback.handleResult called');
            System.debug('Deployment status: ' + result.status);
            System.debug('Deploy ID: ' + result.id);
            
            if (result.status == Metadata.DeployStatus.Succeeded) {
                System.debug('Metadata deployment succeeded');
                System.debug('Number of components deployed: ' + result.numberComponentsDeployed);
                System.debug('Number of components total: ' + result.numberComponentsTotal);
            } else if (result.status == Metadata.DeployStatus.Failed) {
                System.debug('Metadata deployment failed');
                System.debug('Error message: ' + result.errorMessage);
                if (result.details != null && result.details.componentFailures != null) {
                    for (Metadata.DeployMessage message : result.details.componentFailures) {
                        System.debug('Component error: ' + message.fullName + ' - ' + message.problem);
                    }
                }
            } else if (result.status == Metadata.DeployStatus.InProgress) {
                System.debug('Metadata deployment is still in progress');
            } else if (result.status == Metadata.DeployStatus.Pending) {
                System.debug('Metadata deployment is pending');
            }
        }
    }
}