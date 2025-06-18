// Helper class to run test scenarios
@isTest
public class TestRunner {
    public static void runLogLevelErrorTest() {
        // Clean up any existing logs
        delete [SELECT Id FROM Notion_Sync_Log__c];
        
        // Set log level to ERROR
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new Notion_Sync_Settings__c();
        }
        settings.put('Enable_Logging__c', true);
        settings.put('Log_Level__c', 'ERROR');
        upsert settings;
        
        System.debug('Test.isRunningTest() = ' + Test.isRunningTest());
        
        // Add various logs
        NotionSyncLogger.log('001000000000001', 'Account', 'CREATE', 'Success', null, 0);
        NotionSyncLogger.log('001000000000002', 'Account', 'UPDATE', 'Failed', 'Test error', 1);
        NotionSyncLogger.log('001000000000003', 'Account', 'DELETE', 'Rate Limited', 'Rate limit hit', 0);
        
        // Flush logs
        NotionSyncLogger.flush();
        
        // With ERROR log level, only Failed and Rate Limited logs should be created
        List<Notion_Sync_Log__c> logs = [
            SELECT Status__c FROM Notion_Sync_Log__c 
            WHERE Record_Id__c IN ('001000000000001', '001000000000002', '001000000000003')
            ORDER BY Record_Id__c
        ];
        
        System.debug('Logs created: ' + logs.size());
        for (Notion_Sync_Log__c log : logs) {
            System.debug('Log status: ' + log.Status__c);
        }
    }
}