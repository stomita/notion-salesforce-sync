/**
 * Batch job to clean up old Notion sync logs based on retention settings
 * Schedule this job to run daily to maintain database storage
 */
public class NotionSyncLogCleanupBatch implements Database.Batchable<sObject>, Schedulable {
    
    /**
     * Schedulable execute method
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new NotionSyncLogCleanupBatch(), 200);
    }
    
    /**
     * Batch start method - query logs older than retention period
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Get retention days from settings
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
        Integer retentionDays = 7; // Default to 7 days
        
        if (settings != null) {
            try {
                Decimal retentionValue = (Decimal) settings.get('Retention_Days__c');
                if (retentionValue != null && retentionValue > 0) {
                    retentionDays = Integer.valueOf(retentionValue);
                }
            } catch (Exception e) {
                // Use default value
            }
        }
        
        // Calculate cutoff date
        DateTime cutoffDate = DateTime.now().addDays(-retentionDays);
        
        // Query logs older than retention period
        return Database.getQueryLocator([
            SELECT Id 
            FROM Notion_Sync_Log__c 
            WHERE CreatedDate < :cutoffDate
        ]);
    }
    
    /**
     * Batch execute method - delete old logs
     */
    public void execute(Database.BatchableContext bc, List<Notion_Sync_Log__c> logs) {
        if (!logs.isEmpty()) {
            try {
                delete logs;
            } catch (Exception e) {
                System.debug('Error deleting old sync logs: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Batch finish method
     */
    public void finish(Database.BatchableContext bc) {
        // Log completion
        System.debug('Notion sync log cleanup batch completed');
    }
    
    /**
     * Schedule the cleanup job to run daily at 2 AM
     * Run this method once to schedule the job:
     * NotionSyncLogCleanupBatch.scheduleCleanup();
     */
    public static String scheduleCleanup() {
        String cronExp = '0 0 2 * * ?'; // Daily at 2 AM
        String jobName = 'Notion Sync Log Cleanup';
        
        // Check if job already exists
        List<CronTrigger> existingJobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = :jobName
            LIMIT 1
        ];
        
        if (existingJobs.isEmpty()) {
            return System.schedule(jobName, cronExp, new NotionSyncLogCleanupBatch());
        } else {
            System.debug('Cleanup job already scheduled');
            return existingJobs[0].Id;
        }
    }
}