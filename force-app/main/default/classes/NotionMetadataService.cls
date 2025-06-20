public with sharing class NotionMetadataService {
    
    public static void saveSyncConfiguration(NotionAdminController.SyncConfiguration config) {
        // Create MetadataService instance
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        
        // Get API-enabled session ID using SessionUtil
        String sessionId = SessionUtil.getApiEnabledSessionId();
        System.debug('Retrieved API-enabled session ID: ' + sessionId);
        service.SessionHeader.sessionId = sessionId;
        
        // Set the endpoint URL for the current org
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        service.endpoint_x = orgUrl + '/services/Soap/m/61.0';
        
        List<MetadataService.Metadata> metadataToUpsert = new List<MetadataService.Metadata>();
        
        // Create or update NotionSyncObject__mdt
        String objectDeveloperName = sanitizeDeveloperName(config.objectApiName);
        MetadataService.CustomMetadata objectMetadata = new MetadataService.CustomMetadata();
        objectMetadata.fullName = 'NotionSyncObject__mdt.' + objectDeveloperName;
        objectMetadata.label = config.objectApiName + ' Sync Configuration';
        
        // Set field values
        objectMetadata.values = new List<MetadataService.CustomMetadataValue>();
        addMetadataServiceValue(objectMetadata, 'ObjectApiName__c', config.objectApiName);
        addMetadataServiceValue(objectMetadata, 'NotionDatabaseId__c', config.notionDatabaseId);
        addMetadataServiceValue(objectMetadata, 'IsActive__c', String.valueOf(config.isActive));
        addMetadataServiceValue(objectMetadata, 'SalesforceIdPropertyName__c', config.salesforceIdPropertyName);
        
        metadataToUpsert.add(objectMetadata);
        
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
            List<String> metadataToDelete = new List<String>();
            for (NotionSyncField__mdt existingField : existingFields) {
                if (!newFieldKeys.contains(existingField.DeveloperName)) {
                    metadataToDelete.add('NotionSyncField__mdt.' + existingField.DeveloperName);
                }
            }
            
            if (!metadataToDelete.isEmpty()) {
                service.deleteMetadata('CustomMetadata', metadataToDelete);
            }
            
            // Create or update field mappings
            for (NotionAdminController.FieldMapping mapping : config.fieldMappings) {
                String fieldDeveloperName = objectDeveloperName + '_' + sanitizeDeveloperName(mapping.salesforceFieldApiName);
                
                MetadataService.CustomMetadata fieldMetadata = new MetadataService.CustomMetadata();
                fieldMetadata.fullName = 'NotionSyncField__mdt.' + fieldDeveloperName;
                fieldMetadata.label = mapping.salesforceFieldApiName + ' → ' + mapping.notionPropertyName;
                
                // Set field values
                fieldMetadata.values = new List<MetadataService.CustomMetadataValue>();
                addMetadataServiceValue(fieldMetadata, 'NotionSyncObject__c', objectDeveloperName);
                addMetadataServiceValue(fieldMetadata, 'SalesforceFieldApiName__c', mapping.salesforceFieldApiName);
                addMetadataServiceValue(fieldMetadata, 'NotionPropertyName__c', mapping.notionPropertyName);
                addMetadataServiceValue(fieldMetadata, 'NotionPropertyType__c', mapping.notionPropertyType);
                addMetadataServiceValue(fieldMetadata, 'IsBodyContent__c', String.valueOf(mapping.isBodyContent));
                
                metadataToUpsert.add(fieldMetadata);
            }
        }
        
        // Handle relationship mappings
        if (config.relationshipMappings != null) {
            for (NotionAdminController.RelationshipMapping mapping : config.relationshipMappings) {
                // Generate a shorter developer name to fit within 40 character limit
                String fieldName = sanitizeDeveloperName(mapping.salesforceRelationshipField);
                String relationDeveloperName = objectDeveloperName + '_' + fieldName;
                
                // If it's still too long, truncate the object name portion
                if (relationDeveloperName.length() > 40) {
                    Integer maxObjectLength = 40 - fieldName.length() - 1; // -1 for underscore
                    if (maxObjectLength > 0) {
                        String truncatedObjectName = objectDeveloperName.substring(0, Math.min(objectDeveloperName.length(), maxObjectLength));
                        relationDeveloperName = truncatedObjectName + '_' + fieldName;
                    } else {
                        // If field name alone is too long, just use truncated field name
                        relationDeveloperName = fieldName.substring(0, 40);
                    }
                }
                
                MetadataService.CustomMetadata relationMetadata = new MetadataService.CustomMetadata();
                relationMetadata.fullName = 'NotionRelation__mdt.' + relationDeveloperName;
                relationMetadata.label = mapping.salesforceRelationshipField + ' Relation';
                
                // Set field values
                relationMetadata.values = new List<MetadataService.CustomMetadataValue>();
                
                // Both ParentObject__c and ChildObject__c are required fields
                // The childObject field contains the metadata ID, we need to get the developer name
                if (mapping.isParent) {
                    // For parent relationships: current object is parent, mapping.childObject is child
                    addMetadataServiceValue(relationMetadata, 'ParentObject__c', objectDeveloperName);
                    if (String.isNotBlank(mapping.childObject)) {
                        // The childObject contains the metadata ID, extract the developer name
                        // For now, use the ID directly as it should be the developer name
                        addMetadataServiceValue(relationMetadata, 'ChildObject__c', mapping.childObject);
                    } else {
                        // Fallback if childObject is not provided
                        addMetadataServiceValue(relationMetadata, 'ChildObject__c', objectDeveloperName);
                    }
                } else {
                    // For child relationships: mapping.childObject is parent, current object is child
                    if (String.isNotBlank(mapping.childObject)) {
                        addMetadataServiceValue(relationMetadata, 'ParentObject__c', mapping.childObject);
                    } else {
                        // Fallback if childObject is not provided
                        addMetadataServiceValue(relationMetadata, 'ParentObject__c', objectDeveloperName);
                    }
                    addMetadataServiceValue(relationMetadata, 'ChildObject__c', objectDeveloperName);
                }
                addMetadataServiceValue(relationMetadata, 'SalesforceRelationshipField__c', mapping.salesforceRelationshipField);
                addMetadataServiceValue(relationMetadata, 'NotionRelationPropertyName__c', mapping.notionRelationPropertyName);
                
                metadataToUpsert.add(relationMetadata);
            }
        }
        
        // Perform synchronous upsert
        if (!metadataToUpsert.isEmpty()) {
            try {
                // Debug log the metadata being sent
                for (MetadataService.Metadata md : metadataToUpsert) {
                    MetadataService.CustomMetadata cmd = (MetadataService.CustomMetadata) md;
                    System.debug('Upserting metadata: ' + cmd.fullName);
                }
                
                MetadataService.UpsertResult[] results = service.upsertMetadata(metadataToUpsert);
                
                // Check for errors
                for (Integer i = 0; i < results.size(); i++) {
                    MetadataService.UpsertResult result = results[i];
                    if (!result.success) {
                        String errorMessage = 'Failed to save ' + result.fullName + ': ';
                        if (result.errors != null && result.errors.size() > 0) {
                            for (MetadataService.Error err : result.errors) {
                                errorMessage += err.message + ' (Field: ' + err.fields + ', StatusCode: ' + err.statusCode + ') ';
                            }
                        }
                        System.debug('MetadataService Error: ' + errorMessage);
                        throw new CalloutException(errorMessage);
                    }
                }
            } catch (Exception e) {
                System.debug('Exception during metadata upsert: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                throw new CalloutException('Failed to save metadata: ' + e.getMessage());
            }
        }
    }
    
    private static void addMetadataServiceValue(MetadataService.CustomMetadata metadata, String field, String value) {
        MetadataService.CustomMetadataValue customField = new MetadataService.CustomMetadataValue();
        customField.field = field;
        customField.value = value;
        metadata.values.add(customField);
    }
    
    public static void deleteObjectConfiguration(String objectApiName) {
        // First, find the actual DeveloperName for this object
        List<NotionSyncObject__mdt> existingObjects = [
            SELECT DeveloperName, NotionDatabaseId__c, IsActive__c, SalesforceIdPropertyName__c
            FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectApiName
            LIMIT 1
        ];
        
        if (existingObjects.isEmpty()) {
            throw new CalloutException('No sync configuration found for object: ' + objectApiName);
        }
        
        NotionSyncObject__mdt existingObject = existingObjects[0];
        String objectDeveloperName = existingObject.DeveloperName;
        
        // Create MetadataService instance
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        
        // Get API-enabled session ID using SessionUtil
        String sessionId = SessionUtil.getApiEnabledSessionId();
        System.debug('Retrieved API-enabled session ID: ' + sessionId);
        service.SessionHeader.sessionId = sessionId;
        
        // Set the endpoint URL for the current org
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        service.endpoint_x = orgUrl + '/services/Soap/m/61.0';
        
        // Soft delete: Update the object metadata to set IsDeleted__c = true
        MetadataService.CustomMetadata objectMetadata = new MetadataService.CustomMetadata();
        objectMetadata.fullName = 'NotionSyncObject__mdt.' + objectDeveloperName;
        // Truncate label to ensure it fits within 40 character limit
        String label = objectApiName + ' (Deleted)';
        if (label.length() > 40) {
            label = label.substring(0, 37) + '...';
        }
        objectMetadata.label = label;
        
        // Set field values
        objectMetadata.values = new List<MetadataService.CustomMetadataValue>();
        // Mark as deleted
        // Note: Since IsDeleted__c field doesn't exist, we'll just deactivate the configuration
        // Preserve existing field values
        addMetadataServiceValue(objectMetadata, 'ObjectApiName__c', objectApiName);
        addMetadataServiceValue(objectMetadata, 'NotionDatabaseId__c', existingObject.NotionDatabaseId__c);
        addMetadataServiceValue(objectMetadata, 'IsActive__c', 'false'); // Deactivate when deleting
        addMetadataServiceValue(objectMetadata, 'SalesforceIdPropertyName__c', existingObject.SalesforceIdPropertyName__c);
        
        // Note: We don't need to delete field mappings and relationships
        // They will be automatically excluded when we filter by non-deleted parent objects
        
        // Deploy soft deletion synchronously
        System.debug('Deploying metadata for soft delete');
        System.debug('Metadata fullName: ' + objectMetadata.fullName);
        System.debug('IsDeleted value: true');
        
        List<MetadataService.Metadata> metadataToUpsert = new List<MetadataService.Metadata>();
        metadataToUpsert.add(objectMetadata);
        
        MetadataService.UpsertResult[] results = service.upsertMetadata(metadataToUpsert);
        
        // Check for errors
        for (MetadataService.UpsertResult result : results) {
            if (!result.success) {
                String errorMessage = '';
                if (result.errors != null && result.errors.size() > 0) {
                    errorMessage = result.errors[0].message;
                }
                throw new CalloutException('Failed to delete configuration: ' + errorMessage);
            }
        }
        
        System.debug('Configuration deleted successfully');
    }
    
    
    @TestVisible
    private static String sanitizeDeveloperName(String input) {
        // Remove invalid characters and ensure it starts with a letter
        String sanitized = input.replaceAll('[^a-zA-Z0-9_]', '_');
        
        // Replace consecutive underscores with single underscore
        sanitized = sanitized.replaceAll('_{2,}', '_');
        
        // Remove trailing underscores
        sanitized = sanitized.replaceAll('_+$', '');
        
        // Ensure it starts with a letter
        if (sanitized.length() > 0 && !Pattern.matches('[a-zA-Z].*', sanitized)) {
            sanitized = 'X' + sanitized;
        }
        
        // Truncate if too long (max 40 chars for developer name)
        if (sanitized.length() > 40) {
            sanitized = sanitized.substring(0, 40);
        }
        
        // Remove any trailing underscores that might have been created by truncation
        sanitized = sanitized.replaceAll('_+$', '');
        
        return sanitized;
    }
    
}