// Debug flow execution and sync invocation
System.debug('=== Debugging Flow Execution ===');

// Check if flows are active
List<FlowDefinitionView> flows = [
    SELECT ApiName, Label, IsActive, ProcessType
    FROM FlowDefinitionView
    WHERE ApiName LIKE 'NotionSync%'
    ORDER BY ApiName
];
System.debug('Active Notion Sync Flows: ' + flows.size());
for (FlowDefinitionView flow : flows) {
    System.debug('- ' + flow.ApiName + ' (Active: ' + flow.IsActive + ', Type: ' + flow.ProcessType + ')');
}

// Check platform events (if any)
Integer eventCount = [SELECT COUNT() FROM Notion_Sync_Event__e];
System.debug('Platform Events in queue: ' + eventCount);

// Check async apex jobs in detail
List<AsyncApexJob> jobs = [
    SELECT Id, Status, JobType, ApexClass.Name, CreatedDate, CompletedDate, 
           NumberOfErrors, JobItemsProcessed, TotalJobItems, ExtendedStatus
    FROM AsyncApexJob
    WHERE CreatedDate = TODAY
    AND ApexClass.Name IN ('NotionSyncBatchQueueable', 'NotionSyncQueueable', 'NotionDeduplicationQueueable')
    ORDER BY CreatedDate DESC
    LIMIT 20
];
System.debug('Async Jobs Today: ' + jobs.size());
for (AsyncApexJob job : jobs) {
    System.debug('Job: ' + job.ApexClass.Name);
    System.debug('  Status: ' + job.Status);
    System.debug('  Created: ' + job.CreatedDate);
    System.debug('  Completed: ' + job.CompletedDate);
    System.debug('  Items: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
    System.debug('  Errors: ' + job.NumberOfErrors);
    if (job.ExtendedStatus != null) {
        System.debug('  Extended Status: ' + job.ExtendedStatus);
    }
}

// Check if invocable was called
System.debug('Checking if sync is disabled in test mode...');
System.debug('Test.isRunningTest(): ' + Test.isRunningTest());

// Create a test sync request directly through invocable
System.debug('Creating test sync request directly...');
List<NotionSync.Request> testRequests = new List<NotionSync.Request>();
NotionSync.Request req = new NotionSync.Request();
req.recordId = '001000000000000AAA'; // Dummy ID
req.objectType = 'Account';
req.operationType = 'CREATE';
testRequests.add(req);

try {
    List<NotionSync.Result> results = NotionSyncInvocable.syncToNotion(testRequests);
    System.debug('Invocable results: ' + results);
    for (NotionSync.Result result : results) {
        System.debug('- Success: ' + result.success + ', Message: ' + result.message);
    }
} catch (Exception e) {
    System.debug('Invocable error: ' + e.getMessage());
}