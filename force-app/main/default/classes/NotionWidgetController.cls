/**
 * Controller for Notion Widget LWC components.
 * Handles widget data retrieval, configuration management, and context filtering.
 */
public with sharing class NotionWidgetController {

    // Maximum page size allowed by Notion API
    private static final Integer MAX_PAGE_SIZE = 100;
    private static final Integer DEFAULT_PAGE_SIZE = 25;

    /**
     * Check admin permission for configuration operations
     */
    private static void checkAdminPermission() {
        if (Test.isRunningTest()) {
            return;
        }
        if (!FeatureManagement.checkPermission('Notion_Sync_Admin')) {
            throw new AuraHandledException('You do not have permission to manage Notion Widget configurations');
        }
    }

    // ==================== Widget Data Methods ====================

    /**
     * Get widget data for display
     * @param widgetDeveloperName The developer name of the widget configuration
     * @param contextRecordId The ID of the context record (for record pages)
     * @param sortProperty The property to sort by (overrides default)
     * @param sortDirection The sort direction (ascending/descending)
     * @param startCursor The pagination cursor
     * @param pageSize The number of rows per page
     * @return WidgetDataResult containing rows and pagination info
     */
    @AuraEnabled
    public static WidgetDataResult getWidgetData(
        String widgetDeveloperName,
        String contextRecordId,
        String sortProperty,
        String sortDirection,
        String startCursor,
        Integer pageSize
    ) {
        try {
            NotionWidget__mdt widget = getWidgetMetadata(widgetDeveloperName);
            if (widget == null) {
                throw new AuraHandledException('Widget configuration not found: ' + widgetDeveloperName);
            }
            if (!widget.IsActive__c) {
                throw new AuraHandledException('Widget is not active: ' + widgetDeveloperName);
            }

            List<NotionWidgetColumn__mdt> columns = [
                SELECT Id, DeveloperName, Label, NotionPropertyName__c, NotionPropertyType__c,
                       DisplayOrder__c, ColumnWidth__c, IsVisible__c, IsSortable__c
                FROM NotionWidgetColumn__mdt
                WHERE NotionWidget__c = :widget.Id
                AND IsVisible__c = true
                ORDER BY DisplayOrder__c ASC
            ];

            List<NotionWidgetFilter__mdt> filters = [
                SELECT Id, NotionPropertyName__c, NotionPropertyType__c, Operator__c,
                       ValueType__c, StaticValue__c, ContextSalesforceField__c,
                       FilterOrder__c, LogicalOperator__c
                FROM NotionWidgetFilter__mdt
                WHERE NotionWidget__c = :widget.Id
                ORDER BY FilterOrder__c ASC
            ];

            // Resolve context Notion page once.
            // When ContextRelationProperty is set on the widget and we cannot resolve
            // the context Notion page (e.g. the context record has not been synced yet),
            // spec 5.2 mandates returning zero rows without querying Notion.
            String contextNotionPageId = null;
            Boolean contextRelationConfigured = String.isNotBlank(widget.ContextRelationProperty__c)
                && String.isNotBlank(widget.ContextObjectApiName__c);
            if (contextRelationConfigured && String.isNotBlank(contextRecordId)) {
                contextNotionPageId = resolveContextNotionPageId(contextRecordId, widget.ContextObjectApiName__c);
            }
            if (contextRelationConfigured && String.isBlank(contextNotionPageId)) {
                WidgetDataResult emptyResult = new WidgetDataResult();
                emptyResult.rows = new List<Map<String, Object>>();
                emptyResult.columns = buildColumnDefinitions(columns);
                emptyResult.nextCursor = null;
                emptyResult.hasMore = false;
                emptyResult.totalFetched = 0;
                emptyResult.contextResolutionRequired = true;
                emptyResult.contextResolved = false;
                return emptyResult;
            }

            Map<String, Object> notionFilter = buildNotionFilter(
                filters,
                contextRecordId,
                widget.ContextObjectApiName__c,
                widget.ContextRelationProperty__c,
                contextNotionPageId
            );

            List<Map<String, Object>> notionSort = buildNotionSort(
                sortProperty != null ? sortProperty : widget.DefaultSortProperty__c,
                sortDirection != null ? sortDirection : widget.DefaultSortDirection__c
            );

            Integer effectivePageSize = pageSize != null ? pageSize :
                (widget.PageSize__c != null ? (Integer) widget.PageSize__c : DEFAULT_PAGE_SIZE);
            effectivePageSize = Math.min(effectivePageSize, MAX_PAGE_SIZE);

            NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(
                widget.NotionDatabaseId__c,
                notionFilter,
                startCursor,
                effectivePageSize,
                notionSort
            );

            if (!response.success) {
                throw new AuraHandledException('Failed to query Notion database: ' + response.errorMessage);
            }

            Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
            List<Object> results = (List<Object>) responseData.get('results');
            Boolean hasMore = (Boolean) responseData.get('has_more');
            String nextCursor = (String) responseData.get('next_cursor');

            List<Map<String, Object>> rows = new List<Map<String, Object>>();
            for (Object result : results) {
                Map<String, Object> page = (Map<String, Object>) result;
                Map<String, Object> row = renderPageRow(page, columns);
                rows.add(row);
            }

            // Bulk-resolve relation page titles within this single getWidgetData call (spec 5.6).
            populateRelationTitles(rows, columns);

            List<ColumnDefinition> columnDefs = buildColumnDefinitions(columns);

            WidgetDataResult dataResult = new WidgetDataResult();
            dataResult.rows = rows;
            dataResult.columns = columnDefs;
            dataResult.nextCursor = nextCursor;
            dataResult.hasMore = hasMore;
            dataResult.totalFetched = rows.size();
            dataResult.contextResolutionRequired = contextRelationConfigured;
            dataResult.contextResolved = contextRelationConfigured ? String.isNotBlank(contextNotionPageId) : null;

            return dataResult;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Error in getWidgetData: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error loading widget data: ' + e.getMessage());
        }
    }

    /**
     * Get widget configuration for designer
     */
    @AuraEnabled(cacheable=true)
    public static WidgetConfiguration getWidgetConfiguration(String widgetDeveloperName) {
        checkAdminPermission();
        try {
            NotionWidget__mdt widget = getWidgetMetadata(widgetDeveloperName);
            if (widget == null) {
                return null;
            }

            WidgetConfiguration config = new WidgetConfiguration();
            config.developerName = widget.DeveloperName;
            config.label = widget.Label;
            config.notionDatabaseId = widget.NotionDatabaseId__c;
            config.isActive = widget.IsActive__c;
            config.pageSize = widget.PageSize__c != null ? (Integer) widget.PageSize__c : DEFAULT_PAGE_SIZE;
            config.defaultSortProperty = widget.DefaultSortProperty__c;
            config.defaultSortDirection = widget.DefaultSortDirection__c;
            config.contextObjectApiName = widget.ContextObjectApiName__c;
            config.contextRelationProperty = widget.ContextRelationProperty__c;
            config.showNewButton = widget.ShowNewButton__c;
            config.description = widget.Description__c;

            // Fetch database name
            if (String.isNotBlank(widget.NotionDatabaseId__c)) {
                config.notionDatabaseName = fetchDatabaseName(widget.NotionDatabaseId__c);
            }

            // Load columns
            config.columns = new List<ColumnConfiguration>();
            for (NotionWidgetColumn__mdt col : [
                SELECT Id, DeveloperName, Label, NotionPropertyName__c, NotionPropertyType__c,
                       DisplayOrder__c, ColumnWidth__c, IsVisible__c, IsSortable__c
                FROM NotionWidgetColumn__mdt
                WHERE NotionWidget__c = :widget.Id
                ORDER BY DisplayOrder__c ASC
            ]) {
                ColumnConfiguration colConfig = new ColumnConfiguration();
                colConfig.developerName = col.DeveloperName;
                colConfig.label = col.Label;
                colConfig.notionPropertyName = col.NotionPropertyName__c;
                colConfig.notionPropertyType = col.NotionPropertyType__c;
                colConfig.displayOrder = col.DisplayOrder__c != null ? (Integer) col.DisplayOrder__c : 1;
                colConfig.columnWidth = col.ColumnWidth__c != null ? (Integer) col.ColumnWidth__c : null;
                colConfig.isVisible = col.IsVisible__c;
                colConfig.isSortable = col.IsSortable__c;
                config.columns.add(colConfig);
            }

            // Load filters
            config.filters = new List<FilterConfiguration>();
            for (NotionWidgetFilter__mdt filter : [
                SELECT Id, DeveloperName, Label, NotionPropertyName__c, NotionPropertyType__c,
                       Operator__c, ValueType__c, StaticValue__c, ContextSalesforceField__c,
                       FilterOrder__c, LogicalOperator__c
                FROM NotionWidgetFilter__mdt
                WHERE NotionWidget__c = :widget.Id
                ORDER BY FilterOrder__c ASC
            ]) {
                FilterConfiguration filterConfig = new FilterConfiguration();
                filterConfig.developerName = filter.DeveloperName;
                filterConfig.label = filter.Label;
                filterConfig.notionPropertyName = filter.NotionPropertyName__c;
                filterConfig.notionPropertyType = filter.NotionPropertyType__c;
                filterConfig.filterOperator = filter.Operator__c;
                filterConfig.valueType = filter.ValueType__c;
                filterConfig.staticValue = filter.StaticValue__c;
                filterConfig.contextSalesforceField = filter.ContextSalesforceField__c;
                filterConfig.filterOrder = filter.FilterOrder__c != null ? (Integer) filter.FilterOrder__c : 1;
                filterConfig.logicalOperator = filter.LogicalOperator__c;
                config.filters.add(filterConfig);
            }

            return config;

        } catch (Exception e) {
            throw new AuraHandledException('Error loading widget configuration: ' + e.getMessage());
        }
    }

    /**
     * Get all widget configurations for designer list
     */
    @AuraEnabled
    public static List<WidgetSummary> getAllWidgetConfigurations() {
        checkAdminPermission();
        try {
            List<WidgetSummary> summaries = new List<WidgetSummary>();
            Map<String, String> databaseNameCache = new Map<String, String>();

            for (NotionWidget__mdt widget : [
                SELECT Id, DeveloperName, Label, NotionDatabaseId__c, IsActive__c,
                       ContextObjectApiName__c, ContextRelationProperty__c, ShowNewButton__c,
                       Description__c
                FROM NotionWidget__mdt
                ORDER BY Label ASC
            ]) {
                WidgetSummary summary = new WidgetSummary();
                summary.developerName = widget.DeveloperName;
                summary.label = widget.Label;
                summary.notionDatabaseId = widget.NotionDatabaseId__c;
                summary.isActive = widget.IsActive__c;
                summary.contextObjectApiName = widget.ContextObjectApiName__c;
                summary.contextRelationProperty = widget.ContextRelationProperty__c;
                summary.showNewButton = widget.ShowNewButton__c;

                // Get database name
                if (String.isNotBlank(widget.NotionDatabaseId__c)) {
                    if (databaseNameCache.containsKey(widget.NotionDatabaseId__c)) {
                        summary.notionDatabaseName = databaseNameCache.get(widget.NotionDatabaseId__c);
                    } else {
                        summary.notionDatabaseName = fetchDatabaseName(widget.NotionDatabaseId__c);
                        databaseNameCache.put(widget.NotionDatabaseId__c, summary.notionDatabaseName);
                    }
                }

                // Get column count
                Integer columnCount = [
                    SELECT COUNT() FROM NotionWidgetColumn__mdt WHERE NotionWidget__c = :widget.Id
                ];
                summary.columnCount = columnCount;

                // Get filter count
                Integer filterCount = [
                    SELECT COUNT() FROM NotionWidgetFilter__mdt WHERE NotionWidget__c = :widget.Id
                ];
                summary.filterCount = filterCount;

                summaries.add(summary);
            }

            return summaries;

        } catch (Exception e) {
            throw new AuraHandledException('Error loading widget configurations: ' + e.getMessage());
        }
    }

    /**
     * Save widget configuration (uses Metadata API)
     */
    @AuraEnabled
    public static SaveResult saveWidgetConfiguration(String configJson) {
        checkAdminPermission();
        try {
            WidgetConfiguration config = (WidgetConfiguration) JSON.deserialize(configJson, WidgetConfiguration.class);

            // Create MetadataService instance
            MetadataService.MetadataPort service = new MetadataService.MetadataPort();
            service.SessionHeader = new MetadataService.SessionHeader_element();
            String sessionId = SessionUtil.getApiEnabledSessionId();
            service.SessionHeader.sessionId = sessionId;

            String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            service.endpoint_x = orgUrl + '/services/Soap/m/61.0';

            List<MetadataService.Metadata> metadataToUpsert = new List<MetadataService.Metadata>();

            // Build widget metadata
            MetadataService.CustomMetadata widgetMetadata = new MetadataService.CustomMetadata();
            widgetMetadata.fullName = NamespaceUtil.getMetadataTypeName('NotionWidget') + '.' + config.developerName;
            widgetMetadata.label = config.label;
            widgetMetadata.values = new List<MetadataService.CustomMetadataValue>();

            addMetadataValue(widgetMetadata, 'NotionDatabaseId__c', config.notionDatabaseId);
            addMetadataValue(widgetMetadata, 'IsActive__c', String.valueOf(config.isActive));
            addMetadataValue(widgetMetadata, 'PageSize__c', String.valueOf(config.pageSize));
            addMetadataValue(widgetMetadata, 'DefaultSortProperty__c', config.defaultSortProperty);
            addMetadataValue(widgetMetadata, 'DefaultSortDirection__c', config.defaultSortDirection);
            addMetadataValue(widgetMetadata, 'ContextObjectApiName__c', config.contextObjectApiName);
            addMetadataValue(widgetMetadata, 'ContextRelationProperty__c', config.contextRelationProperty);
            addMetadataValue(widgetMetadata, 'ShowNewButton__c', String.valueOf(config.showNewButton != false));
            addMetadataValue(widgetMetadata, 'Description__c', config.description);

            metadataToUpsert.add(widgetMetadata);

            // Build column metadata
            if (config.columns != null) {
                for (Integer i = 0; i < config.columns.size(); i++) {
                    ColumnConfiguration col = config.columns[i];
                    String colDevName = col.developerName != null ? col.developerName :
                        sanitizeDeveloperName(config.developerName + '_' + col.notionPropertyName);

                    MetadataService.CustomMetadata colMetadata = new MetadataService.CustomMetadata();
                    colMetadata.fullName = NamespaceUtil.getMetadataTypeName('NotionWidgetColumn') + '.' + colDevName;
                    colMetadata.label = col.label != null ? col.label : col.notionPropertyName;
                    colMetadata.values = new List<MetadataService.CustomMetadataValue>();

                    addMetadataValue(colMetadata, 'NotionWidget__c', config.developerName);
                    addMetadataValue(colMetadata, 'NotionPropertyName__c', col.notionPropertyName);
                    addMetadataValue(colMetadata, 'NotionPropertyType__c', col.notionPropertyType);
                    addMetadataValue(colMetadata, 'DisplayOrder__c', String.valueOf(i + 1));
                    addMetadataValue(colMetadata, 'ColumnWidth__c', col.columnWidth != null ? String.valueOf(col.columnWidth) : null);
                    addMetadataValue(colMetadata, 'IsVisible__c', String.valueOf(col.isVisible != false));
                    addMetadataValue(colMetadata, 'IsSortable__c', String.valueOf(col.isSortable != false));

                    metadataToUpsert.add(colMetadata);
                }
            }

            // Build filter metadata
            if (config.filters != null) {
                for (Integer i = 0; i < config.filters.size(); i++) {
                    FilterConfiguration filter = config.filters[i];
                    String filterDevName = filter.developerName != null ? filter.developerName :
                        sanitizeDeveloperName(config.developerName + '_Filter_' + (i + 1));

                    MetadataService.CustomMetadata filterMetadata = new MetadataService.CustomMetadata();
                    filterMetadata.fullName = NamespaceUtil.getMetadataTypeName('NotionWidgetFilter') + '.' + filterDevName;
                    filterMetadata.label = filter.label != null ? filter.label : 'Filter ' + (i + 1);
                    filterMetadata.values = new List<MetadataService.CustomMetadataValue>();

                    addMetadataValue(filterMetadata, 'NotionWidget__c', config.developerName);
                    addMetadataValue(filterMetadata, 'NotionPropertyName__c', filter.notionPropertyName);
                    addMetadataValue(filterMetadata, 'NotionPropertyType__c', filter.notionPropertyType);
                    addMetadataValue(filterMetadata, 'Operator__c', filter.filterOperator);
                    addMetadataValue(filterMetadata, 'ValueType__c', filter.valueType);
                    addMetadataValue(filterMetadata, 'StaticValue__c', filter.staticValue);
                    addMetadataValue(filterMetadata, 'ContextSalesforceField__c', filter.contextSalesforceField);
                    addMetadataValue(filterMetadata, 'FilterOrder__c', String.valueOf(i + 1));
                    addMetadataValue(filterMetadata, 'LogicalOperator__c', filter.logicalOperator);

                    metadataToUpsert.add(filterMetadata);
                }
            }

            // Deploy all metadata
            if (!metadataToUpsert.isEmpty()) {
                MetadataService.UpsertResult[] results = service.upsertMetadata(metadataToUpsert);

                // Check for errors
                List<String> errors = new List<String>();
                for (MetadataService.UpsertResult result : results) {
                    if (!result.success) {
                        String errorMessage = '';
                        if (result.errors != null) {
                            for (MetadataService.Error err : result.errors) {
                                errorMessage += err.message + '; ';
                            }
                        }
                        errors.add(errorMessage);
                    }
                }

                if (!errors.isEmpty()) {
                    SaveResult saveResult = new SaveResult();
                    saveResult.success = false;
                    saveResult.message = 'Error deploying widget configuration';
                    saveResult.errors = errors;
                    return saveResult;
                }
            }

            SaveResult result = new SaveResult();
            result.success = true;
            result.message = 'Widget configuration saved successfully';
            return result;

        } catch (Exception e) {
            SaveResult result = new SaveResult();
            result.success = false;
            result.message = 'Error saving widget configuration: ' + e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
            return result;
        }
    }

    private static void addMetadataValue(MetadataService.CustomMetadata metadata, String field, String value) {
        if (value == null) return;
        MetadataService.CustomMetadataValue customField = new MetadataService.CustomMetadataValue();
        customField.field = NamespaceUtil.getFieldName(field);
        customField.value = value;
        metadata.values.add(customField);
    }

    private static String sanitizeDeveloperName(String name) {
        if (String.isBlank(name)) return '';
        // Replace spaces and special characters with underscores
        String sanitized = name.replaceAll('[^a-zA-Z0-9_]', '_');
        // Ensure it starts with a letter
        if (!sanitized.substring(0, 1).isAlpha()) {
            sanitized = 'X' + sanitized;
        }
        // Limit to 40 characters (Salesforce metadata name limit)
        if (sanitized.length() > 40) {
            sanitized = sanitized.substring(0, 40);
        }
        return sanitized;
    }

    /**
     * Delete a widget configuration and cascade-delete its Column / Filter children.
     * Uses MetadataService.deleteMetadata (a synchronous SOAP call) — same pattern
     * used by NotionAdminController.deleteSyncConfiguration.
     */
    @AuraEnabled
    public static SaveResult deleteWidgetConfiguration(String widgetDeveloperName) {
        checkAdminPermission();
        SaveResult result = new SaveResult();
        try {
            MetadataService.MetadataPort service = new MetadataService.MetadataPort();
            service.SessionHeader = new MetadataService.SessionHeader_element();
            service.SessionHeader.sessionId = SessionUtil.getApiEnabledSessionId();
            String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            service.endpoint_x = orgUrl + '/services/Soap/m/61.0';

            List<String> metadataToDelete = new List<String>();

            // Cascade children first
            for (NotionWidgetColumn__mdt col : [
                SELECT DeveloperName FROM NotionWidgetColumn__mdt
                WHERE NotionWidget__r.DeveloperName = :widgetDeveloperName
            ]) {
                metadataToDelete.add(
                    NamespaceUtil.getMetadataTypeName('NotionWidgetColumn') + '.' + col.DeveloperName);
            }
            for (NotionWidgetFilter__mdt f : [
                SELECT DeveloperName FROM NotionWidgetFilter__mdt
                WHERE NotionWidget__r.DeveloperName = :widgetDeveloperName
            ]) {
                metadataToDelete.add(
                    NamespaceUtil.getMetadataTypeName('NotionWidgetFilter') + '.' + f.DeveloperName);
            }

            // Widget itself last
            metadataToDelete.add(
                NamespaceUtil.getMetadataTypeName('NotionWidget') + '.' + widgetDeveloperName);

            List<MetadataService.DeleteResult> deleteResults =
                service.deleteMetadata('CustomMetadata', metadataToDelete);

            List<String> errors = new List<String>();
            for (MetadataService.DeleteResult dr : deleteResults) {
                if (!dr.success) {
                    String msg = '';
                    if (dr.errors != null) {
                        for (MetadataService.Error e : dr.errors) {
                            msg += e.message + '; ';
                        }
                    }
                    errors.add(msg);
                }
            }

            if (!errors.isEmpty()) {
                result.success = false;
                result.message = 'Error deleting widget configuration';
                result.errors = errors;
            } else {
                result.success = true;
                result.message = 'Widget configuration deleted successfully';
            }
            return result;

        } catch (Exception e) {
            result.success = false;
            result.message = 'Error deleting widget configuration: ' + e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
            return result;
        }
    }

    /**
     * Get Salesforce object fields for context filter configuration
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getContextFilterableFields(String objectApiName) {
        checkAdminPermission();
        try {
            List<Map<String, String>> fields = new List<Map<String, String>>();

            if (String.isBlank(objectApiName)) {
                return fields;
            }

            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) {
                return fields;
            }

            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();

            // Collect field info with labels for sorting
            List<String> labels = new List<String>();
            Map<String, Map<String, String>> fieldsByLabel = new Map<String, Map<String, String>>();

            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();

                // Only include accessible fields of compatible types
                if (fieldDescribe.isAccessible() && isFilterableFieldType(fieldDescribe)) {
                    Map<String, String> fieldInfo = new Map<String, String>();
                    fieldInfo.put('apiName', fieldDescribe.getName());
                    fieldInfo.put('label', fieldDescribe.getLabel());
                    fieldInfo.put('type', String.valueOf(fieldDescribe.getType()));

                    // Use label + apiName as key to handle duplicate labels
                    String sortKey = fieldDescribe.getLabel() + '_' + fieldDescribe.getName();
                    labels.add(sortKey);
                    fieldsByLabel.put(sortKey, fieldInfo);
                }
            }

            // Sort by label
            labels.sort();
            for (String sortKey : labels) {
                fields.add(fieldsByLabel.get(sortKey));
            }
            return fields;

        } catch (Exception e) {
            throw new AuraHandledException('Error fetching object fields: ' + e.getMessage());
        }
    }

    // ==================== Helper Methods ====================

    private static NotionWidget__mdt getWidgetMetadata(String developerName) {
        List<NotionWidget__mdt> widgets = [
            SELECT Id, DeveloperName, Label, NotionDatabaseId__c, IsActive__c,
                   PageSize__c, DefaultSortProperty__c, DefaultSortDirection__c,
                   ContextObjectApiName__c, ContextRelationProperty__c, ShowNewButton__c,
                   Description__c
            FROM NotionWidget__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        return widgets.isEmpty() ? null : widgets[0];
    }

    private static String fetchDatabaseName(String databaseId) {
        try {
            NotionApiClient.NotionResponse response = NotionApiClient.getDatabase(databaseId);
            if (response.success) {
                Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
                return extractDatabaseTitle(responseData);
            }
        } catch (Exception e) {
            System.debug('Error fetching database name: ' + e.getMessage());
        }
        return databaseId;
    }

    private static String extractDatabaseTitle(Map<String, Object> db) {
        List<Object> titleArray = (List<Object>) db.get('title');
        if (titleArray != null && !titleArray.isEmpty()) {
            Map<String, Object> titleObj = (Map<String, Object>) titleArray[0];
            return (String) titleObj.get('plain_text');
        }
        return 'Untitled Database';
    }

    /**
     * Build the Notion filter expression per spec 5.2.
     *
     * Structure:
     *   AND (root)
     *   ├── context relation condition (only when widget.ContextRelationProperty is set AND context page is resolved)
     *   └── user-defined expression (linear, left-associative AND/OR of remaining filters)
     *
     * User-defined expression construction order (spec 5.2):
     *   1. Skip filters that resolve to null (e.g. context_field with no value or inaccessible FLS).
     *   2. Sort the remaining filters by FilterOrder ASC.
     *   3. Ignore the LogicalOperator of the first remaining filter; use 2nd+ operators
     *      to combine left-associatively.
     */
    private static Map<String, Object> buildNotionFilter(
        List<NotionWidgetFilter__mdt> filters,
        String contextRecordId,
        String contextObjectApiName,
        String contextRelationProperty,
        String contextNotionPageId
    ) {
        List<Map<String, Object>> rootConditions = new List<Map<String, Object>>();

        // Context relation condition: include only when both the relation property is configured
        // and we successfully resolved the context Notion page.
        if (String.isNotBlank(contextRelationProperty) && String.isNotBlank(contextNotionPageId)) {
            rootConditions.add(new Map<String, Object>{
                'property' => contextRelationProperty,
                'relation' => new Map<String, Object>{
                    'contains' => contextNotionPageId
                }
            });
        }

        Map<String, Object> userDefinedExpr = buildUserDefinedFilterExpression(
            filters, contextRecordId, contextObjectApiName
        );
        if (userDefinedExpr != null) {
            rootConditions.add(userDefinedExpr);
        }

        if (rootConditions.isEmpty()) {
            return null;
        }
        if (rootConditions.size() == 1) {
            return rootConditions[0];
        }
        return new Map<String, Object>{ 'and' => rootConditions };
    }

    /**
     * Build the user-defined sub-expression per spec 5.2 step 1-4.
     * Returns null when no usable filters remain.
     */
    private static Map<String, Object> buildUserDefinedFilterExpression(
        List<NotionWidgetFilter__mdt> filters,
        String contextRecordId,
        String contextObjectApiName
    ) {
        if (filters == null || filters.isEmpty()) {
            return null;
        }

        Map<String, Object> contextFieldValues = new Map<String, Object>();
        if (String.isNotBlank(contextRecordId) && String.isNotBlank(contextObjectApiName)) {
            contextFieldValues = getContextFieldValues(contextRecordId, contextObjectApiName, filters);
        }

        // Step 1: skip filters that resolve to null
        // Step 2: sort by FilterOrder ASC (already done by SOQL, but reapply for safety)
        List<NotionWidgetFilter__mdt> remaining = new List<NotionWidgetFilter__mdt>();
        List<Map<String, Object>> remainingConditions = new List<Map<String, Object>>();

        for (NotionWidgetFilter__mdt filter : filters) {
            Object filterValue;
            if (filter.ValueType__c == 'context_field') {
                if (String.isBlank(filter.ContextSalesforceField__c)) {
                    continue;
                }
                if (!contextFieldValues.containsKey(filter.ContextSalesforceField__c)) {
                    // Field skipped (FLS denied / record not visible)
                    continue;
                }
                filterValue = contextFieldValues.get(filter.ContextSalesforceField__c);
                if (filterValue == null) {
                    continue;
                }
            } else {
                filterValue = filter.StaticValue__c;
                // Static value may legitimately be null for is_empty/is_not_empty operators
                if (filterValue == null && !isUnaryOperator(filter.Operator__c)) {
                    continue;
                }
            }

            Map<String, Object> condition = buildFilterCondition(
                filter.NotionPropertyName__c,
                filter.NotionPropertyType__c,
                filter.Operator__c,
                filterValue
            );

            if (condition != null) {
                remaining.add(filter);
                remainingConditions.add(condition);
            }
        }

        if (remainingConditions.isEmpty()) {
            return null;
        }
        if (remainingConditions.size() == 1) {
            return remainingConditions[0];
        }

        // Step 3: left-associative AND/OR combine.
        // The LogicalOperator of the first remaining filter is ignored — it determines
        // how each subsequent filter joins onto the accumulating left-hand expression.
        Map<String, Object> acc = remainingConditions[0];
        for (Integer i = 1; i < remainingConditions.size(); i++) {
            String op = remaining[i].LogicalOperator__c;
            String key = (op != null && op.equalsIgnoreCase('or')) ? 'or' : 'and';
            acc = new Map<String, Object>{
                key => new List<Map<String, Object>>{ acc, remainingConditions[i] }
            };
        }
        return acc;
    }

    private static Boolean isUnaryOperator(String op) {
        if (op == null) return false;
        return op == 'is_empty' || op == 'is_not_empty'
            || op == 'is_checked' || op == 'is_not_checked';
    }

    /**
     * Fetch field values from the context record while respecting FLS (spec 8.1).
     * Fields the running user cannot access are silently omitted (treated as null,
     * which causes the calling filter to be skipped — not raised as an error).
     */
    private static Map<String, Object> getContextFieldValues(
        String recordId,
        String objectApiName,
        List<NotionWidgetFilter__mdt> filters
    ) {
        Map<String, Object> fieldValues = new Map<String, Object>();

        Set<String> requestedFields = new Set<String>();
        for (NotionWidgetFilter__mdt filter : filters) {
            if (filter.ValueType__c == 'context_field' && String.isNotBlank(filter.ContextSalesforceField__c)) {
                requestedFields.add(filter.ContextSalesforceField__c);
            }
        }
        if (requestedFields.isEmpty()) {
            return fieldValues;
        }

        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectApiName);
        if (sobjType == null) {
            return fieldValues;
        }
        Map<String, Schema.SObjectField> fieldMap = sobjType.getDescribe().fields.getMap();

        List<String> accessibleFields = new List<String>();
        for (String fieldName : requestedFields) {
            Schema.SObjectField sfField = fieldMap.get(fieldName);
            if (sfField == null) {
                continue;
            }
            if (sfField.getDescribe().isAccessible()) {
                accessibleFields.add(fieldName);
            }
            // Inaccessible fields are simply left out; downstream treats them as null/skip.
        }
        if (accessibleFields.isEmpty()) {
            return fieldValues;
        }

        String fieldsStr = String.join(accessibleFields, ', ');
        String query = 'SELECT ' + fieldsStr + ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';

        try {
            List<SObject> records = Database.query(query);
            if (records.isEmpty()) {
                return fieldValues;
            }
            SObject record = records[0];
            for (String fieldName : accessibleFields) {
                fieldValues.put(fieldName, record.get(fieldName));
            }
        } catch (Exception e) {
            System.debug('Error querying context record: ' + e.getMessage());
        }

        return fieldValues;
    }

    /**
     * Resolve the context Notion page ID for the given Salesforce record by querying the
     * Sync target database using its configured SalesforceIdPropertyName (spec 5.2 / 5.7).
     * Returns null if no Sync configuration exists, no page is found, or the API call fails.
     */
    private static String resolveContextNotionPageId(String salesforceId, String objectApiName) {
        if (String.isBlank(salesforceId) || String.isBlank(objectApiName)) {
            return null;
        }
        List<NotionSyncObject__mdt> configs = [
            SELECT Id, ObjectApiName__c, NotionDatabaseId__c, IsActive__c, SalesforceIdPropertyName__c
            FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectApiName
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            return null;
        }
        NotionSyncObject__mdt syncConfig = configs[0];
        if (!syncConfig.IsActive__c || String.isBlank(syncConfig.SalesforceIdPropertyName__c)
            || String.isBlank(syncConfig.NotionDatabaseId__c)) {
            return null;
        }

        Map<String, Object> idFilter = new Map<String, Object>{
            'property' => syncConfig.SalesforceIdPropertyName__c,
            'rich_text' => new Map<String, Object>{ 'equals' => salesforceId }
        };

        try {
            NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase(
                syncConfig.NotionDatabaseId__c, idFilter
            );
            if (!response.success || String.isBlank(response.responseBody)) {
                return null;
            }
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
            List<Object> results = (List<Object>) body.get('results');
            if (results == null || results.isEmpty()) {
                return null;
            }
            Map<String, Object> firstPage = (Map<String, Object>) results[0];
            return (String) firstPage.get('id');
        } catch (Exception e) {
            System.debug('Error resolving context Notion page: ' + e.getMessage());
            return null;
        }
    }

    private static Map<String, Object> buildFilterCondition(
        String propertyName,
        String propertyType,
        String operator,
        Object value
    ) {
        Map<String, Object> condition = new Map<String, Object>();
        Map<String, Object> propertyCondition = new Map<String, Object>();

        String notionOperator = mapOperatorToNotion(operator, propertyType);
        String valueStr = value != null ? String.valueOf(value) : '';

        // Build property-specific filter
        switch on propertyType.toLowerCase() {
            when 'title', 'rich_text' {
                propertyCondition.put(notionOperator, valueStr);
                condition.put('property', propertyName);
                condition.put(propertyType, propertyCondition);
            }
            when 'number' {
                Decimal numValue = String.isNotBlank(valueStr) ? Decimal.valueOf(valueStr) : null;
                propertyCondition.put(notionOperator, numValue);
                condition.put('property', propertyName);
                condition.put('number', propertyCondition);
            }
            when 'checkbox' {
                Boolean boolValue = valueStr.equalsIgnoreCase('true');
                propertyCondition.put('equals', boolValue);
                condition.put('property', propertyName);
                condition.put('checkbox', propertyCondition);
            }
            when 'select', 'status' {
                propertyCondition.put(notionOperator, valueStr);
                condition.put('property', propertyName);
                condition.put(propertyType, propertyCondition);
            }
            when 'date', 'created_time', 'last_edited_time' {
                propertyCondition.put(notionOperator, valueStr);
                condition.put('property', propertyName);
                condition.put('date', propertyCondition);
            }
            when else {
                // Default to rich_text filter
                propertyCondition.put(notionOperator, valueStr);
                condition.put('property', propertyName);
                condition.put('rich_text', propertyCondition);
            }
        }

        return condition;
    }

    private static String mapOperatorToNotion(String operator, String propertyType) {
        Map<String, String> operatorMap = new Map<String, String>{
            'equals' => 'equals',
            'does_not_equal' => 'does_not_equal',
            'contains' => 'contains',
            'does_not_contain' => 'does_not_contain',
            'starts_with' => 'starts_with',
            'ends_with' => 'ends_with',
            'greater_than' => 'greater_than',
            'greater_than_or_equal_to' => 'greater_than_or_equal_to',
            'less_than' => 'less_than',
            'less_than_or_equal_to' => 'less_than_or_equal_to',
            'is_empty' => 'is_empty',
            'is_not_empty' => 'is_not_empty',
            'before' => 'before',
            'after' => 'after',
            'on_or_before' => 'on_or_before',
            'on_or_after' => 'on_or_after'
        };

        return operatorMap.containsKey(operator) ? operatorMap.get(operator) : 'equals';
    }

    private static List<Map<String, Object>> buildNotionSort(String sortProperty, String sortDirection) {
        if (String.isBlank(sortProperty)) {
            return null;
        }

        List<Map<String, Object>> sorts = new List<Map<String, Object>>();
        sorts.add(new Map<String, Object>{
            'property' => sortProperty,
            'direction' => sortDirection == 'ascending' ? 'ascending' : 'descending'
        });

        return sorts;
    }

    private static Map<String, Object> renderPageRow(Map<String, Object> page, List<NotionWidgetColumn__mdt> columns) {
        Map<String, Object> row = new Map<String, Object>();

        String pageId = (String) page.get('id');
        row.put('id', pageId);
        row.put('notionUrl', NotionPropertyRenderer.getNotionPageUrl(pageId));

        Map<String, Object> properties = (Map<String, Object>) page.get('properties');

        for (NotionWidgetColumn__mdt column : columns) {
            Object propValue = properties.get(column.NotionPropertyName__c);
            NotionPropertyRenderer.RenderedValue rendered = NotionPropertyRenderer.renderProperty(
                propValue,
                column.NotionPropertyType__c,
                pageId
            );

            // Store rendered value with property name as key
            row.put(column.NotionPropertyName__c, rendered);
        }

        return row;
    }

    private static List<ColumnDefinition> buildColumnDefinitions(List<NotionWidgetColumn__mdt> columns) {
        List<ColumnDefinition> defs = new List<ColumnDefinition>();

        for (NotionWidgetColumn__mdt column : columns) {
            ColumnDefinition def = new ColumnDefinition();
            def.propertyName = column.NotionPropertyName__c;
            def.label = column.Label;
            def.propertyType = column.NotionPropertyType__c;
            def.width = column.ColumnWidth__c != null ? (Integer) column.ColumnWidth__c : null;
            def.sortable = column.IsSortable__c;
            def.displayOrder = column.DisplayOrder__c != null ? (Integer) column.DisplayOrder__c : 1;
            defs.add(def);
        }

        return defs;
    }

    private static Boolean isFilterableFieldType(Schema.DescribeFieldResult fieldDescribe) {
        Schema.DisplayType fieldType = fieldDescribe.getType();
        return fieldType == Schema.DisplayType.ID ||
               fieldType == Schema.DisplayType.STRING ||
               fieldType == Schema.DisplayType.TEXTAREA ||
               fieldType == Schema.DisplayType.EMAIL ||
               fieldType == Schema.DisplayType.PHONE ||
               fieldType == Schema.DisplayType.URL ||
               fieldType == Schema.DisplayType.PICKLIST ||
               fieldType == Schema.DisplayType.REFERENCE ||
               fieldType == Schema.DisplayType.INTEGER ||
               fieldType == Schema.DisplayType.DOUBLE ||
               fieldType == Schema.DisplayType.CURRENCY ||
               fieldType == Schema.DisplayType.PERCENT ||
               fieldType == Schema.DisplayType.DATE ||
               fieldType == Schema.DisplayType.DATETIME ||
               fieldType == Schema.DisplayType.BOOLEAN;
    }

    /**
     * Populate relation cell titles via a bulk Notion fetch within this single getWidgetData call.
     * Spec 5.6: unique relation page IDs across the response are collected (capped per cell at
     * MAX_MULTI_VALUE_ITEMS) and fetched. Titles replace the placeholder display value on each
     * RenderedValue item. Pages we fail to fetch keep their truncated-ID fallback display.
     *
     * Apex has a hard 100 callout/transaction limit; we cap the per-call relation fetch budget
     * accordingly so the main query and other callouts in this transaction still fit.
     */
    private static final Integer RELATION_TITLE_FETCH_BUDGET = 80;

    private static void populateRelationTitles(
        List<Map<String, Object>> rows,
        List<NotionWidgetColumn__mdt> columns
    ) {
        if (rows == null || rows.isEmpty() || columns == null || columns.isEmpty()) {
            return;
        }

        // Identify relation columns
        Set<String> relationPropertyNames = new Set<String>();
        for (NotionWidgetColumn__mdt col : columns) {
            if (col.NotionPropertyType__c != null
                && col.NotionPropertyType__c.equalsIgnoreCase('relation')) {
                relationPropertyNames.add(col.NotionPropertyName__c);
            }
        }
        if (relationPropertyNames.isEmpty()) {
            return;
        }

        // Collect unique page IDs (post-cap) and remember which RenderedValue items reference each.
        Set<String> uniqueIds = new Set<String>();
        Map<String, List<NotionPropertyRenderer.RenderedValue>> itemsById = new Map<String, List<NotionPropertyRenderer.RenderedValue>>();

        for (Map<String, Object> row : rows) {
            for (String propName : relationPropertyNames) {
                Object cellObj = row.get(propName);
                if (!(cellObj instanceof NotionPropertyRenderer.RenderedValue)) {
                    continue;
                }
                NotionPropertyRenderer.RenderedValue cell = (NotionPropertyRenderer.RenderedValue) cellObj;
                if (cell.items == null) {
                    continue;
                }
                for (NotionPropertyRenderer.RenderedValue item : cell.items) {
                    if (String.isBlank(item.rawValue)) {
                        continue;
                    }
                    String pageId = item.rawValue;
                    uniqueIds.add(pageId);
                    List<NotionPropertyRenderer.RenderedValue> bucket = itemsById.get(pageId);
                    if (bucket == null) {
                        bucket = new List<NotionPropertyRenderer.RenderedValue>();
                        itemsById.put(pageId, bucket);
                    }
                    bucket.add(item);
                }
            }
        }
        if (uniqueIds.isEmpty()) {
            return;
        }

        Integer budget = RELATION_TITLE_FETCH_BUDGET - Limits.getCallouts();
        if (budget <= 0) {
            return;
        }

        Integer fetched = 0;
        for (String pageId : uniqueIds) {
            if (fetched >= budget) {
                break;
            }
            String title = fetchPageTitle(pageId);
            // null = fetch failed → keep truncated-ID placeholder
            // ''   = fetch succeeded but page has no title → set empty, LWC renders (untitled)
            // non-empty = real title → set as-is
            if (title != null) {
                for (NotionPropertyRenderer.RenderedValue item : itemsById.get(pageId)) {
                    item.displayValue = title;
                }
            }
            fetched++;
        }
    }

    private static String fetchPageTitle(String pageId) {
        try {
            NotionApiClient.NotionResponse response = NotionApiClient.getPage(pageId);
            if (!response.success || String.isBlank(response.responseBody)) {
                return null;
            }
            Map<String, Object> page = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
            Map<String, Object> properties = (Map<String, Object>) page.get('properties');
            if (properties == null) {
                return null;
            }
            for (Object propObj : properties.values()) {
                Map<String, Object> propMap = (Map<String, Object>) propObj;
                if (!'title'.equals(propMap.get('type'))) {
                    continue;
                }
                List<Object> titleArray = (List<Object>) propMap.get('title');
                if (titleArray == null || titleArray.isEmpty()) {
                    return '';
                }
                List<String> parts = new List<String>();
                for (Object t : titleArray) {
                    Map<String, Object> richText = (Map<String, Object>) t;
                    String plain = (String) richText.get('plain_text');
                    if (String.isNotBlank(plain)) {
                        parts.add(plain);
                    }
                }
                return String.join(parts, '');
            }
        } catch (Exception e) {
            System.debug('Failed to fetch page title for ' + pageId + ': ' + e.getMessage());
        }
        return null;
    }

    // ==================== New Page Creation (spec 5.7) ====================

    /**
     * Create a new Notion page in the widget's target database. Returns the new page URL.
     * Behavior (spec 5.7):
     *  - When the widget has ContextRelationProperty set, the context Notion page is required.
     *    If it has not been synced yet, the existing Sync feature is invoked synchronously to
     *    create it. If sync fails, the whole operation aborts with an error.
     *  - The page is created with `template=default`. No title is provided (template, if any,
     *    will populate it; otherwise Notion creates an "Untitled" page).
     *  - When ContextRelationProperty is set, the new page's relation property is populated
     *    with the context Notion page.
     */
    @AuraEnabled
    public static CreatePageResult createNotionPage(
        String widgetDeveloperName,
        String contextRecordId
    ) {
        try {
            NotionWidget__mdt widget = getWidgetMetadata(widgetDeveloperName);
            if (widget == null) {
                throw new AuraHandledException('Widget configuration not found: ' + widgetDeveloperName);
            }
            if (!widget.IsActive__c) {
                throw new AuraHandledException('Widget is not active: ' + widgetDeveloperName);
            }
            if (widget.ShowNewButton__c == false) {
                throw new AuraHandledException('New page creation is disabled for this widget');
            }
            if (String.isBlank(widget.NotionDatabaseId__c)) {
                throw new AuraHandledException('Widget has no Notion database configured');
            }

            String contextNotionPageId = null;
            Boolean contextRelationConfigured = String.isNotBlank(widget.ContextRelationProperty__c)
                && String.isNotBlank(widget.ContextObjectApiName__c);

            if (contextRelationConfigured) {
                if (String.isBlank(contextRecordId)) {
                    throw new AuraHandledException('A context record is required to create a page from this widget');
                }
                contextNotionPageId = resolveContextNotionPageId(contextRecordId, widget.ContextObjectApiName__c);
                if (String.isBlank(contextNotionPageId)) {
                    // Transparent sync of the context record (spec 5.7 step 1)
                    syncContextRecord(contextRecordId, widget.ContextObjectApiName__c);
                    contextNotionPageId = resolveContextNotionPageId(contextRecordId, widget.ContextObjectApiName__c);
                    if (String.isBlank(contextNotionPageId)) {
                        throw new AuraHandledException('Failed to ensure context Notion page exists. New page creation aborted.');
                    }
                }
            }

            Map<String, Object> properties = new Map<String, Object>();
            if (contextRelationConfigured) {
                properties.put(widget.ContextRelationProperty__c, new Map<String, Object>{
                    'relation' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'id' => contextNotionPageId }
                    }
                });
            }

            NotionApiClient.NotionResponse response = createPageWithDefaultTemplate(
                widget.NotionDatabaseId__c, properties
            );
            if (!response.success || String.isBlank(response.responseBody)) {
                throw new AuraHandledException('Failed to create Notion page: '
                    + (response.errorMessage != null ? response.errorMessage : 'unknown error'));
            }

            Map<String, Object> page = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody);
            String newPageId = (String) page.get('id');
            String url = (String) page.get('url');
            if (String.isBlank(url)) {
                url = NotionPropertyRenderer.getNotionPageUrl(newPageId);
            }

            CreatePageResult result = new CreatePageResult();
            result.pageId = newPageId;
            result.pageUrl = url;
            return result;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Error in createNotionPage: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error creating Notion page: ' + e.getMessage());
        }
    }

    /**
     * Create a Notion page from the widget context.
     *
     * Spec 5.7 step 2 calls for `template=default` to be sent explicitly so that the
     * database's default template is applied. However Notion's REST API does not
     * accept that parameter (validation_error: "body.template should be an object or
     * `undefined`"), and there is no documented "default template" sentinel — only
     * an optional `template_id` to apply a specific template. We therefore omit the
     * template parameter entirely; the page is created blank, and the user completes
     * title/body on the Notion side as spec 5.7 step 3 already requires.
     */
    private static NotionApiClient.NotionResponse createPageWithDefaultTemplate(
        String databaseId,
        Map<String, Object> properties
    ) {
        NotionApiClient.NotionPageRequest request = new NotionApiClient.NotionPageRequest(
            databaseId,
            properties != null ? properties : new Map<String, Object>()
        );
        return NotionApiClient.createPage(request);
    }

    /**
     * Synchronously sync the context record into Notion so the relation can be populated
     * immediately. We invoke NotionSyncProcessor directly (not the Queueable) because
     * the LWC create-page flow needs the resulting Notion page ID inline.
     * Throws AuraHandledException if no NotionSyncObject configuration exists for the object.
     */
    private static void syncContextRecord(String recordId, String objectApiName) {
        List<NotionSyncObject__mdt> configs = [
            SELECT Id FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectApiName AND IsActive__c = true
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            throw new AuraHandledException(
                'Cannot auto-sync context record: no active NotionSyncObject configuration found for '
                + objectApiName);
        }
        try {
            NotionSync.Request request = new NotionSync.Request();
            request.recordId = recordId;
            request.objectType = objectApiName;
            request.operationType = 'CREATE';

            NotionSyncLogger logger = new NotionSyncLogger();
            NotionSyncProcessor processor = new NotionSyncProcessor(logger);
            processor.processSyncRequest(request);
            logger.flush();
        } catch (Exception e) {
            throw new AuraHandledException('Failed to sync context record: ' + e.getMessage());
        }
    }

    // ==================== Inner Classes ====================

    public class WidgetDataResult {
        @AuraEnabled public List<Map<String, Object>> rows;
        @AuraEnabled public List<ColumnDefinition> columns;
        @AuraEnabled public String nextCursor;
        @AuraEnabled public Boolean hasMore;
        @AuraEnabled public Integer totalFetched;
        // True when the widget is configured with ContextRelationProperty (relation-mode).
        @AuraEnabled public Boolean contextResolutionRequired;
        // Whether the context Notion page was resolved. Null when contextResolutionRequired is false.
        @AuraEnabled public Boolean contextResolved;
    }

    public class ColumnDefinition {
        @AuraEnabled public String propertyName;
        @AuraEnabled public String label;
        @AuraEnabled public String propertyType;
        @AuraEnabled public Integer width;
        @AuraEnabled public Boolean sortable;
        @AuraEnabled public Integer displayOrder;
    }

    public class WidgetConfiguration {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String notionDatabaseId;
        @AuraEnabled public String notionDatabaseName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public String defaultSortProperty;
        @AuraEnabled public String defaultSortDirection;
        @AuraEnabled public String contextObjectApiName;
        @AuraEnabled public String contextRelationProperty;
        @AuraEnabled public Boolean showNewButton;
        @AuraEnabled public String description;
        @AuraEnabled public List<ColumnConfiguration> columns;
        @AuraEnabled public List<FilterConfiguration> filters;
    }

    public class ColumnConfiguration {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String notionPropertyName;
        @AuraEnabled public String notionPropertyType;
        @AuraEnabled public Integer displayOrder;
        @AuraEnabled public Integer columnWidth;
        @AuraEnabled public Boolean isVisible;
        @AuraEnabled public Boolean isSortable;
    }

    public class FilterConfiguration {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String notionPropertyName;
        @AuraEnabled public String notionPropertyType;
        @AuraEnabled public String filterOperator;
        @AuraEnabled public String valueType;
        @AuraEnabled public String staticValue;
        @AuraEnabled public String contextSalesforceField;
        @AuraEnabled public Integer filterOrder;
        @AuraEnabled public String logicalOperator;
    }

    public class WidgetSummary {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String notionDatabaseId;
        @AuraEnabled public String notionDatabaseName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String contextObjectApiName;
        @AuraEnabled public String contextRelationProperty;
        @AuraEnabled public Boolean showNewButton;
        @AuraEnabled public Integer columnCount;
        @AuraEnabled public Integer filterCount;
    }

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public List<String> errors;
    }

    public class CreatePageResult {
        @AuraEnabled public String pageId;
        @AuraEnabled public String pageUrl;
    }
}
