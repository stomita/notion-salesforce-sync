// Debug sync status and settings
System.debug('=== Debugging Sync Status ===');

// Check sync settings
Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
System.debug('Sync Settings: ' + settings);
if (settings != null) {
    System.debug('- Enable_Sync_Logging__c: ' + settings.Enable_Sync_Logging__c);
}

// Check if there are any async jobs
List<AsyncApexJob> jobs = [
    SELECT Id, Status, JobType, ApexClass.Name, CreatedDate, CompletedDate
    FROM AsyncApexJob
    WHERE JobType IN ('Queueable', 'Future')
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('Recent Async Jobs: ' + jobs.size());
for (AsyncApexJob job : jobs) {
    System.debug('- ' + job.ApexClass.Name + ' ' + job.Status + ' ' + job.JobType + 
                 ' created at ' + job.CreatedDate +
                 (job.CompletedDate != null ? ' completed at ' + job.CompletedDate : ''));
}

// Check flows
List<FlowDefinitionView> flows = [
    SELECT ApiName, Label, IsActive, ProcessType
    FROM FlowDefinitionView
    WHERE ApiName LIKE 'NotionSync%'
];
System.debug('Notion Sync Flows:');
for (FlowDefinitionView flow : flows) {
    System.debug('- ' + flow.ApiName + ' (Active: ' + flow.IsActive + ')');
}

// Force process any pending queueable jobs
System.debug('Forcing async job processing...');
Test.startTest();
Test.stopTest();
System.debug('Async processing complete');

// Re-check sync logs after forcing async processing
List<Notion_Sync_Log__c> logsAfter = [
    SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, Status__c, 
           Notion_Page_Id__c, CreatedDate
    FROM Notion_Sync_Log__c
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('Sync Logs after async processing: ' + logsAfter.size());
for (Notion_Sync_Log__c log : logsAfter) {
    System.debug('- ' + log.Object_Type__c + ' ' + log.Operation_Type__c + ' ' + log.Status__c + 
                 ' RecordId=' + log.Record_Id__c + ' at ' + log.CreatedDate);
}