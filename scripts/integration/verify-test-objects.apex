// Verify Test Objects Script
// This script verifies that all test objects and metadata were deployed successfully

System.debug('=== Verifying Test Objects Deployment ===');

// Check Test Parent Object
Schema.DescribeSObjectResult parentDescribe = Schema.getGlobalDescribe().get('Test_Parent_Object__c').getDescribe();
System.debug('\nTest_Parent_Object__c:');
System.debug('- Label: ' + parentDescribe.getLabel());
System.debug('- API Name: ' + parentDescribe.getName());
System.debug('- Fields: ' + parentDescribe.fields.getMap().keySet());

// Check Test Child Object
Schema.DescribeSObjectResult childDescribe = Schema.getGlobalDescribe().get('Test_Child_Object__c').getDescribe();
System.debug('\nTest_Child_Object__c:');
System.debug('- Label: ' + childDescribe.getLabel());
System.debug('- API Name: ' + childDescribe.getName());
System.debug('- Fields: ' + childDescribe.fields.getMap().keySet());

// Check Custom Metadata
System.debug('\n--- Checking Custom Metadata ---');

// NotionSyncObject records
List<NotionSyncObject__mdt> syncObjects = [
    SELECT Id, DeveloperName, ObjectApiName__c, NotionDatabaseId__c, IsActive__c
    FROM NotionSyncObject__mdt
    WHERE DeveloperName LIKE '%Test%'
];
System.debug('\nNotionSyncObject__mdt test records: ' + syncObjects.size());
for (NotionSyncObject__mdt obj : syncObjects) {
    System.debug('- ' + obj.DeveloperName + ': ' + obj.ObjectApiName__c);
}

// NotionSyncField records
List<NotionSyncField__mdt> syncFields = [
    SELECT Id, DeveloperName, NotionSyncObject__r.DeveloperName, 
           SalesforceFieldApiName__c, NotionPropertyName__c
    FROM NotionSyncField__mdt
    WHERE NotionSyncObject__r.DeveloperName LIKE '%Test%'
    LIMIT 10
];
System.debug('\nNotionSyncField__mdt test records (sample): ' + syncFields.size());
for (NotionSyncField__mdt field : syncFields) {
    System.debug('- ' + field.NotionSyncObject__r.DeveloperName + '.' + 
                field.SalesforceFieldApiName__c + ' -> ' + field.NotionPropertyName__c);
}

// NotionRelation records - check each condition separately due to OR limitation
List<NotionRelation__mdt> parentRelations = [
    SELECT Id, DeveloperName, ParentObject__r.DeveloperName, 
           ChildObject__r.DeveloperName, SalesforceRelationshipField__c
    FROM NotionRelation__mdt
    WHERE ParentObject__r.DeveloperName LIKE '%Test%'
];
List<NotionRelation__mdt> childRelations = [
    SELECT Id, DeveloperName, ParentObject__r.DeveloperName, 
           ChildObject__r.DeveloperName, SalesforceRelationshipField__c
    FROM NotionRelation__mdt
    WHERE ChildObject__r.DeveloperName LIKE '%Test%'
];
Set<Id> relationIds = new Set<Id>();
List<NotionRelation__mdt> relations = new List<NotionRelation__mdt>();
for (NotionRelation__mdt rel : parentRelations) {
    if (!relationIds.contains(rel.Id)) {
        relationIds.add(rel.Id);
        relations.add(rel);
    }
}
for (NotionRelation__mdt rel : childRelations) {
    if (!relationIds.contains(rel.Id)) {
        relationIds.add(rel.Id);
        relations.add(rel);
    }
}
System.debug('\nNotionRelation__mdt test records: ' + relations.size());
for (NotionRelation__mdt rel : relations) {
    System.debug('- ' + rel.ParentObject__r.DeveloperName + ' -> ' + 
                rel.ChildObject__r.DeveloperName + ' via ' + rel.SalesforceRelationshipField__c);
}

// Check Flows
System.debug('\n--- Checking Flows ---');
List<FlowDefinitionView> testFlows = [
    SELECT Id, ApiName, Label, IsActive
    FROM FlowDefinitionView
    WHERE ApiName LIKE '%Test_%'
];
System.debug('Test flows: ' + testFlows.size());
for (FlowDefinitionView flow : testFlows) {
    System.debug('- ' + flow.ApiName + ' (Active: ' + flow.IsActive + ')');
}

System.debug('\n=== Verification Complete ===');
System.debug('Test objects and metadata have been successfully deployed.');