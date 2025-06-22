/**
 * Platform Event trigger to process Notion Sync Log events
 * Converts Platform Events into Notion_Sync_Log__c records
 */
trigger NotionSyncLogEventTrigger on Notion_Sync_Log_Event__e (after insert) {
    
    List<Notion_Sync_Log__c> logsToInsert = new List<Notion_Sync_Log__c>();
    
    for (Notion_Sync_Log_Event__e event : Trigger.new) {
        Notion_Sync_Log__c log = new Notion_Sync_Log__c(
            Record_Id__c = event.Record_Id__c,
            Object_Type__c = event.Object_Type__c,
            Operation_Type__c = event.Operation_Type__c,
            Status__c = event.Status__c,
            Error_Message__c = event.Error_Message__c,
            Notion_Page_Id__c = event.Notion_Page_Id__c,
            Retry_Count__c = event.Retry_Count__c != null ? event.Retry_Count__c.intValue() : 0,
            Rate_Limited__c = event.Rate_Limited__c,
            API_Calls_Made__c = event.API_Calls_Made__c != null ? event.API_Calls_Made__c.intValue() : null,
            CPU_Time_Used__c = event.CPU_Time_Used__c != null ? event.CPU_Time_Used__c.intValue() : null
        );
        
        logsToInsert.add(log);
    }
    
    if (!logsToInsert.isEmpty()) {
        try {
            insert logsToInsert;
        } catch (Exception e) {
            // Log the error but don't fail the Platform Event processing
            System.debug(LoggingLevel.ERROR, 'Failed to insert Notion sync logs: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
}