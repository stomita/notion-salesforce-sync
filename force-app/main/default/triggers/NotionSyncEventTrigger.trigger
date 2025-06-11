trigger NotionSyncEventTrigger on Notion_Sync_Event__e (after insert) {
    List<NotionSyncQueueable.SyncRequest> requests = new List<NotionSyncQueueable.SyncRequest>();
    
    for (Notion_Sync_Event__e event : Trigger.new) {
        requests.add(new NotionSyncQueueable.SyncRequest(
            event.Record_Id__c,
            event.Object_Type__c,
            event.Operation_Type__c
        ));
    }
    
    if (!requests.isEmpty()) {
        System.enqueueJob(new NotionSyncQueueable(requests));
    }
}