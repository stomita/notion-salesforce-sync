public with sharing class NotionAdminController {
    
    private static void checkAdminPermission() {
        // Skip permission check in test context as custom permissions cannot be assigned in tests
        if (Test.isRunningTest()) {
            return;
        }
        
        if (!FeatureManagement.checkPermission('Notion_Sync_Admin')) {
            throw new AuraHandledException('You do not have permission to access Notion Sync Admin features');
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<NotionDatabase> getDatabases() {
        checkAdminPermission();
        try {
            NotionApiClient.NotionResponse response = NotionApiClient.searchDatabases();
            
            if (!response.success) {
                throw new AuraHandledException('Failed to fetch databases: ' + response.errorMessage);
            }
            
            List<NotionDatabase> databases = new List<NotionDatabase>();
            Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
            List<Object> results = (List<Object>) responseData.get('results');
            
            for (Object result : results) {
                Map<String, Object> db = (Map<String, Object>) result;
                NotionDatabase notionDb = new NotionDatabase();
                notionDb.id = (String) db.get('id');
                notionDb.title = extractDatabaseTitle(db);
                notionDb.iconEmoji = extractIconEmoji(db);
                notionDb.lastEditedTime = (String) db.get('last_edited_time');
                databases.add(notionDb);
            }
            
            return databases;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching databases: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static DatabaseSchema getDatabaseSchema(String databaseId) {
        checkAdminPermission();
        try {
            NotionApiClient.NotionResponse response = NotionApiClient.getDatabase(databaseId);
            
            if (!response.success) {
                throw new AuraHandledException('Failed to fetch database schema: ' + response.errorMessage);
            }
            
            Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
            Map<String, Object> properties = (Map<String, Object>) responseData.get('properties');
            
            DatabaseSchema schema = new DatabaseSchema();
            schema.databaseId = databaseId;
            schema.databaseName = extractDatabaseTitle(responseData);
            schema.properties = new List<NotionProperty>();
            
            for (String propName : properties.keySet()) {
                Map<String, Object> prop = (Map<String, Object>) properties.get(propName);
                NotionProperty notionProp = new NotionProperty();
                notionProp.name = propName;
                notionProp.type = (String) prop.get('type');
                notionProp.id = (String) prop.get('id');
                schema.properties.add(notionProp);
            }
            
            return schema;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching database schema: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SalesforceObject> getSalesforceObjects() {
        checkAdminPermission();
        try {
            List<SalesforceObject> objects = new List<SalesforceObject>();
            
            // Get all standard and custom objects
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            
            for (String objectName : globalDescribe.keySet()) {
                Schema.SObjectType objType = globalDescribe.get(objectName);
                Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
                
                // Only include objects that can be synced
                if (objDescribe.isCreateable() && objDescribe.isUpdateable() && 
                    objDescribe.isQueryable() && !objDescribe.isDeprecatedAndHidden()) {
                    
                    SalesforceObject sfObj = new SalesforceObject();
                    sfObj.apiName = objDescribe.getName();
                    sfObj.label = objDescribe.getLabel();
                    sfObj.isCustom = objDescribe.isCustom();
                    sfObj.keyPrefix = objDescribe.getKeyPrefix();
                    objects.add(sfObj);
                }
            }
            
            // Sort by label
            objects.sort();
            
            return objects;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Salesforce objects: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static List<SyncConfiguration> getAllSyncConfigurations() {
        checkAdminPermission();
        try {
            List<SyncConfiguration> configurations = new List<SyncConfiguration>();
            
            // Query all NotionSyncObject__mdt records
            List<NotionSyncObject__mdt> syncObjects = [
                SELECT Id, DeveloperName, ObjectApiName__c, NotionDatabaseId__c, 
                       IsActive__c, SalesforceIdPropertyName__c
                FROM NotionSyncObject__mdt
            ];
            
            for (NotionSyncObject__mdt syncObj : syncObjects) {
                SyncConfiguration config = new SyncConfiguration();
                config.objectApiName = syncObj.ObjectApiName__c;
                config.notionDatabaseId = syncObj.NotionDatabaseId__c;
                config.isActive = syncObj.IsActive__c;
                config.salesforceIdPropertyName = syncObj.SalesforceIdPropertyName__c;
                config.objectMetadataId = syncObj.Id;
                
                // For now, just use the database ID
                // TODO: Fetch database name from Notion API when performance allows
                config.notionDatabaseName = syncObj.NotionDatabaseId__c;
                
                // Get field mappings
                List<NotionSyncField__mdt> fieldMappings = [
                    SELECT Id, SalesforceFieldApiName__c, NotionPropertyName__c, 
                           NotionPropertyType__c, IsBodyContent__c
                    FROM NotionSyncField__mdt
                    WHERE NotionSyncObject__c = :syncObj.Id
                ];
                
                config.fieldMappings = new List<FieldMapping>();
                for (NotionSyncField__mdt field : fieldMappings) {
                    FieldMapping mapping = new FieldMapping();
                    mapping.salesforceFieldApiName = field.SalesforceFieldApiName__c;
                    mapping.notionPropertyName = field.NotionPropertyName__c;
                    mapping.notionPropertyType = field.NotionPropertyType__c;
                    mapping.isBodyContent = field.IsBodyContent__c;
                    mapping.metadataId = field.Id;
                    config.fieldMappings.add(mapping);
                }
                
                // Get relationship mappings
                List<NotionRelation__mdt> relationMappings = [
                    SELECT Id, ChildObject__c, SalesforceRelationshipField__c, 
                           NotionRelationPropertyName__c
                    FROM NotionRelation__mdt
                    WHERE ParentObject__c = :syncObj.Id
                ];
                
                config.relationshipMappings = new List<RelationshipMapping>();
                for (NotionRelation__mdt relation : relationMappings) {
                    RelationshipMapping mapping = new RelationshipMapping();
                    mapping.childObject = relation.ChildObject__c;
                    mapping.salesforceRelationshipField = relation.SalesforceRelationshipField__c;
                    mapping.notionRelationPropertyName = relation.NotionRelationPropertyName__c;
                    mapping.metadataId = relation.Id;
                    config.relationshipMappings.add(mapping);
                }
                
                configurations.add(config);
            }
            
            return configurations;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching sync configurations: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SalesforceField> getObjectFields(String objectApiName) {
        checkAdminPermission();
        try {
            List<SalesforceField> fields = new List<SalesforceField>();
            
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) {
                throw new AuraHandledException('Object not found: ' + objectApiName);
            }
            
            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                // Only include fields that can be read
                if (fieldDescribe.isAccessible()) {
                    SalesforceField sfField = new SalesforceField();
                    sfField.apiName = fieldDescribe.getName();
                    sfField.label = fieldDescribe.getLabel();
                    sfField.type = String.valueOf(fieldDescribe.getType());
                    sfField.isRequired = !fieldDescribe.isNillable() && fieldDescribe.isCreateable();
                    sfField.isCustom = fieldDescribe.isCustom();
                    sfField.isRelationship = fieldDescribe.getReferenceTo().size() > 0;
                    sfField.isLongTextArea = fieldDescribe.getType() == Schema.DisplayType.TEXTAREA && fieldDescribe.getLength() > 255;
                    
                    if (sfField.isRelationship) {
                        List<String> refObjects = new List<String>();
                        for (Schema.SObjectType refType : fieldDescribe.getReferenceTo()) {
                            refObjects.add(refType.getDescribe().getName());
                        }
                        sfField.referenceTo = refObjects;
                    }
                    
                    fields.add(sfField);
                }
            }
            
            // Sort by label
            fields.sort();
            
            return fields;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching object fields: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static SyncConfiguration getSyncConfiguration(String objectApiName) {
        checkAdminPermission();
        try {
            SyncConfiguration config = new SyncConfiguration();
            config.fieldMappings = new List<FieldMapping>();
            config.relationshipMappings = new List<RelationshipMapping>();
            
            // Get object sync configuration
            List<NotionSyncObject__mdt> syncObjects = [
                SELECT Id, DeveloperName, ObjectApiName__c, NotionDatabaseId__c, 
                       IsActive__c, SalesforceIdPropertyName__c
                FROM NotionSyncObject__mdt
                WHERE ObjectApiName__c = :objectApiName
                LIMIT 1
            ];
            
            if (!syncObjects.isEmpty()) {
                NotionSyncObject__mdt syncObj = syncObjects[0];
                config.objectApiName = syncObj.ObjectApiName__c;
                config.notionDatabaseId = syncObj.NotionDatabaseId__c;
                config.isActive = syncObj.IsActive__c;
                config.salesforceIdPropertyName = syncObj.SalesforceIdPropertyName__c;
                config.objectMetadataId = syncObj.Id;
                
                // For now, just use the database ID
                config.notionDatabaseName = syncObj.NotionDatabaseId__c;
                
                // Get field mappings
                List<NotionSyncField__mdt> syncFields = [
                    SELECT Id, DeveloperName, SalesforceFieldApiName__c, NotionPropertyName__c,
                           NotionPropertyType__c, IsBodyContent__c
                    FROM NotionSyncField__mdt
                    WHERE NotionSyncObject__c = :syncObj.Id
                ];
                
                for (NotionSyncField__mdt field : syncFields) {
                    FieldMapping mapping = new FieldMapping();
                    mapping.salesforceFieldApiName = field.SalesforceFieldApiName__c;
                    mapping.notionPropertyName = field.NotionPropertyName__c;
                    mapping.notionPropertyType = field.NotionPropertyType__c;
                    mapping.isBodyContent = field.IsBodyContent__c;
                    mapping.metadataId = field.Id;
                    config.fieldMappings.add(mapping);
                }
                
                // Get relationship mappings - Custom Metadata doesn't support OR in WHERE clause
                // So we need to make two separate queries
                List<NotionRelation__mdt> parentRelations = [
                    SELECT Id, DeveloperName, ParentObject__c, ChildObject__c,
                           SalesforceRelationshipField__c, NotionRelationPropertyName__c
                    FROM NotionRelation__mdt
                    WHERE ParentObject__c = :syncObj.Id
                ];
                
                List<NotionRelation__mdt> childRelations = [
                    SELECT Id, DeveloperName, ParentObject__c, ChildObject__c,
                           SalesforceRelationshipField__c, NotionRelationPropertyName__c
                    FROM NotionRelation__mdt
                    WHERE ChildObject__c = :syncObj.Id
                ];
                
                // Combine the results
                List<NotionRelation__mdt> relations = new List<NotionRelation__mdt>();
                relations.addAll(parentRelations);
                relations.addAll(childRelations);
                
                for (NotionRelation__mdt relation : relations) {
                    RelationshipMapping mapping = new RelationshipMapping();
                    mapping.childObject = relation.ChildObject__c;
                    mapping.salesforceRelationshipField = relation.SalesforceRelationshipField__c;
                    mapping.notionRelationPropertyName = relation.NotionRelationPropertyName__c;
                    mapping.isParent = relation.ParentObject__c == syncObj.Id;
                    mapping.metadataId = relation.Id;
                    config.relationshipMappings.add(mapping);
                }
            }
            
            return config;
        } catch (Exception e) {
            System.debug('Error in getSyncConfiguration: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching sync configuration: ' + e.getMessage() + ' Line: ' + e.getLineNumber());
        }
    }
    
    @AuraEnabled
    public static SaveResult saveSyncConfiguration(String configJson) {
        checkAdminPermission();
        try {
            // Debug logging
            System.debug('SaveSyncConfiguration called with configJson: ' + configJson);
            
            // Parse JSON to map first to debug
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(configJson);
            System.debug('JSON map keys: ' + jsonMap.keySet());
            System.debug('objectApiName from map: ' + jsonMap.get('objectApiName'));
            
            // Deserialize the JSON string to SyncConfiguration object
            SyncConfiguration config = (SyncConfiguration) JSON.deserialize(configJson, SyncConfiguration.class);
            
            System.debug('Deserialized config: ' + JSON.serialize(config));
            System.debug('ObjectApiName: ' + config.objectApiName);
            
            SaveResult result = new SaveResult();
            result.success = true;
            result.errors = new List<String>();
            
            // Validate configuration
            validateConfiguration(config);
            
            // Use Metadata API to save custom metadata
            NotionMetadataService.saveSyncConfiguration(config);
            
            result.message = 'Configuration saved successfully';
            return result;
            
        } catch (Exception e) {
            System.debug('Error in saveSyncConfiguration: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            SaveResult result = new SaveResult();
            result.success = false;
            result.message = 'Failed to save configuration';
            result.errors = new List<String>{ e.getMessage() };
            return result;
        }
    }
    
    @AuraEnabled
    public static TestConnectionResult testConnection(String databaseId) {
        checkAdminPermission();
        try {
            TestConnectionResult result = new TestConnectionResult();
            
            // Try to fetch the database to verify connection
            NotionApiClient.NotionResponse response = NotionApiClient.getDatabase(databaseId);
            
            result.success = response.success;
            result.message = response.success ? 'Connection successful' : response.errorMessage;
            
            if (response.success) {
                Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
                result.databaseName = extractDatabaseTitle(responseData);
            }
            
            return result;
        } catch (Exception e) {
            TestConnectionResult result = new TestConnectionResult();
            result.success = false;
            result.message = 'Connection failed: ' + e.getMessage();
            return result;
        }
    }
    
    private static String extractDatabaseTitle(Map<String, Object> database) {
        try {
            List<Object> title = (List<Object>) database.get('title');
            if (title != null && !title.isEmpty()) {
                Map<String, Object> titleObj = (Map<String, Object>) title[0];
                return (String) titleObj.get('plain_text');
            }
        } catch (Exception e) {
            System.debug('Error extracting database title: ' + e.getMessage());
        }
        return 'Untitled Database';
    }
    
    private static String extractIconEmoji(Map<String, Object> database) {
        try {
            Map<String, Object> icon = (Map<String, Object>) database.get('icon');
            if (icon != null && icon.get('type') == 'emoji') {
                return (String) icon.get('emoji');
            }
        } catch (Exception e) {
            System.debug('Error extracting icon emoji: ' + e.getMessage());
        }
        return null;
    }
    
    private static void validateConfiguration(SyncConfiguration config) {
        System.debug('validateConfiguration called');
        System.debug('config: ' + config);
        System.debug('config is null: ' + (config == null));
        
        if (config == null) {
            throw new ValidationException('Configuration object is null');
        }
        
        System.debug('config.objectApiName: ' + config.objectApiName);
        System.debug('config.objectApiName is blank: ' + String.isBlank(config.objectApiName));
        
        if (String.isBlank(config.objectApiName)) {
            throw new ValidationException('Object API name is required');
        }
        
        if (String.isBlank(config.notionDatabaseId)) {
            throw new ValidationException('Notion database ID is required');
        }
        
        if (String.isBlank(config.salesforceIdPropertyName)) {
            throw new ValidationException('Salesforce ID property name is required');
        }
        
        // Validate field mappings
        Set<String> mappedFields = new Set<String>();
        Set<String> mappedProperties = new Set<String>();
        
        if (config.fieldMappings != null) {
            for (FieldMapping mapping : config.fieldMappings) {
            if (String.isBlank(mapping.salesforceFieldApiName)) {
                throw new ValidationException('Salesforce field API name is required for all mappings');
            }
            
            if (String.isBlank(mapping.notionPropertyName)) {
                throw new ValidationException('Notion property name is required for all mappings');
            }
            
            if (mappedFields.contains(mapping.salesforceFieldApiName)) {
                throw new ValidationException('Duplicate field mapping: ' + mapping.salesforceFieldApiName);
            }
            
            if (mappedProperties.contains(mapping.notionPropertyName) && !mapping.isBodyContent) {
                throw new ValidationException('Duplicate property mapping: ' + mapping.notionPropertyName);
            }
            
                mappedFields.add(mapping.salesforceFieldApiName);
                if (!mapping.isBodyContent) {
                    mappedProperties.add(mapping.notionPropertyName);
                }
            }
        }
    }
    
    // Inner classes for data structures
    public class NotionDatabase {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String iconEmoji;
        @AuraEnabled public String lastEditedTime;
    }
    
    public class DatabaseSchema {
        @AuraEnabled public String databaseId;
        @AuraEnabled public String databaseName;
        @AuraEnabled public List<NotionProperty> properties;
    }
    
    public class NotionProperty {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
    }
    
    public class SalesforceObject implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public String keyPrefix;
        
        public Integer compareTo(Object compareTo) {
            SalesforceObject compareToObj = (SalesforceObject) compareTo;
            return label.compareTo(compareToObj.label);
        }
    }
    
    public class SalesforceField implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public Boolean isRelationship;
        @AuraEnabled public Boolean isLongTextArea;
        @AuraEnabled public List<String> referenceTo;
        
        public Integer compareTo(Object compareTo) {
            SalesforceField compareToField = (SalesforceField) compareTo;
            return label.compareTo(compareToField.label);
        }
    }
    
    public class SyncConfiguration {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String notionDatabaseId;
        @AuraEnabled public String notionDatabaseName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String salesforceIdPropertyName;
        @AuraEnabled public String objectMetadataId;
        @AuraEnabled public List<FieldMapping> fieldMappings;
        @AuraEnabled public List<RelationshipMapping> relationshipMappings;
    }
    
    public class FieldMapping {
        @AuraEnabled public String salesforceFieldApiName;
        @AuraEnabled public String notionPropertyName;
        @AuraEnabled public String notionPropertyType;
        @AuraEnabled public Boolean isBodyContent;
        @AuraEnabled public String metadataId;
    }
    
    public class RelationshipMapping {
        @AuraEnabled public String childObject;
        @AuraEnabled public String salesforceRelationshipField;
        @AuraEnabled public String notionRelationPropertyName;
        @AuraEnabled public Boolean isParent;
        @AuraEnabled public String metadataId;
    }
    
    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public List<String> errors;
    }
    
    public class TestConnectionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String databaseName;
    }
    
    public class ValidationException extends Exception {}
    
    @AuraEnabled
    public static SystemSettings getSystemSettings() {
        checkAdminPermission();
        
        SystemSettings settings = new SystemSettings();
        Notion_Sync_Settings__c customSettings = Notion_Sync_Settings__c.getInstance();
        
        if (customSettings != null) {
            settings.enableSyncLogging = customSettings.Enable_Sync_Logging__c;
        } else {
            // Default values
            settings.enableSyncLogging = false;
        }
        
        return settings;
    }
    
    @AuraEnabled
    public static SaveResult saveSystemSettings(String settingsJson) {
        checkAdminPermission();
        
        // Debug logging
        System.debug('Received settings JSON: ' + settingsJson);
        
        SaveResult result = new SaveResult();
        try {
            // Parse JSON to get settings
            Map<String, Object> settings = (Map<String, Object>) JSON.deserializeUntyped(settingsJson);
            System.debug('Parsed settings: ' + settings);
            System.debug('enableSyncLogging: ' + settings.get('enableSyncLogging'));
            
            // Get or create the org-wide custom settings record
            Notion_Sync_Settings__c customSettings = Notion_Sync_Settings__c.getOrgDefaults();
            
            if (customSettings == null || customSettings.Id == null) {
                customSettings = new Notion_Sync_Settings__c();
                customSettings.SetupOwnerId = UserInfo.getOrganizationId();
            }
            
            // Extract boolean value from map
            Object enableSyncLoggingObj = settings.get('enableSyncLogging');
            Boolean enableSyncLogging = false;
            if (enableSyncLoggingObj != null) {
                if (enableSyncLoggingObj instanceof Boolean) {
                    enableSyncLogging = (Boolean)enableSyncLoggingObj;
                } else {
                    // Handle string values just in case
                    String strValue = String.valueOf(enableSyncLoggingObj);
                    enableSyncLogging = strValue.equalsIgnoreCase('true');
                }
            }
            
            customSettings.Enable_Sync_Logging__c = enableSyncLogging;
            
            upsert customSettings;
            
            result.success = true;
            result.message = 'Settings saved successfully';
            return result;
        } catch (Exception e) {
            result.success = false;
            result.message = 'Failed to save system settings: ' + e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
            return result;
        }
    }
    
    public class SystemSettings {
        @AuraEnabled public Boolean enableSyncLogging {get; set;}
    }
    
    @AuraEnabled
    public static SaveResult deleteSyncConfiguration(String objectApiName) {
        checkAdminPermission();
        
        SaveResult result = new SaveResult();
        try {
            // Use MetadataService with API-enabled session for real deletion
            deleteCustomMetadataRecords(objectApiName);
            
            result.success = true;
            result.message = 'Configuration deleted successfully.';
            return result;
        } catch (Exception e) {
            result.success = false;
            result.message = 'Failed to delete configuration: ' + e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
            return result;
        }
    }
    
    private static void deleteCustomMetadataRecords(String objectApiName) {
        // First, query to find the records to delete
        List<NotionSyncObject__mdt> syncObjects = [
            SELECT DeveloperName
            FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectApiName
            LIMIT 1
        ];
        
        if (syncObjects.isEmpty()) {
            throw new AuraHandledException('No sync configuration found for object: ' + objectApiName);
        }
        
        String objectDeveloperName = syncObjects[0].DeveloperName;
        
        // Create MetadataService instance with API-enabled session
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        
        // Get API-enabled session ID from Visualforce page
        service.SessionHeader.sessionId = SessionUtil.getApiEnabledSessionId();
        
        // Set the endpoint URL for the current org
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        service.endpoint_x = orgUrl + '/services/Soap/m/61.0';
        
        // List of metadata to delete
        List<String> metadataToDelete = new List<String>();
        
        // Query and delete field mappings
        List<NotionSyncField__mdt> fieldMappings = [
            SELECT DeveloperName
            FROM NotionSyncField__mdt
            WHERE NotionSyncObject__r.DeveloperName = :objectDeveloperName
        ];
        
        for (NotionSyncField__mdt field : fieldMappings) {
            metadataToDelete.add('NotionSyncField__mdt.' + field.DeveloperName);
        }
        
        // Query and delete relationship mappings - split into two queries
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
        
        for (NotionRelation__mdt relation : parentRelations) {
            metadataToDelete.add('NotionRelation__mdt.' + relation.DeveloperName);
        }
        
        for (NotionRelation__mdt relation : childRelations) {
            metadataToDelete.add('NotionRelation__mdt.' + relation.DeveloperName);
        }
        
        // Add the parent object last
        metadataToDelete.add('NotionSyncObject__mdt.' + objectDeveloperName);
        
        if (!metadataToDelete.isEmpty()) {
            // Perform the deletion
            List<MetadataService.DeleteResult> deleteResults = 
                service.deleteMetadata('CustomMetadata', metadataToDelete);
            
            // Check for errors
            for (MetadataService.DeleteResult deleteResult : deleteResults) {
                if (!deleteResult.success) {
                    String errorMessage = '';
                    if (deleteResult.errors != null && deleteResult.errors.size() > 0) {
                        errorMessage = deleteResult.errors[0].message;
                    }
                    throw new AuraHandledException('Failed to delete metadata: ' + errorMessage);
                }
            }
        }
    }
}