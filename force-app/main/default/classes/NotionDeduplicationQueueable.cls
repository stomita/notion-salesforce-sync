/**
 * Queueable class for handling Notion page deduplication
 * Processes deduplication asynchronously with rate limit and governor limit awareness
 */
public class NotionDeduplicationQueueable implements Queueable, Database.AllowsCallouts {
    private Set<Id> recordIds;
    private String objectType;
    private Integer retryCount;
    private static final Integer MAX_RETRY_COUNT = 3;
    private static final Integer MAX_DELETIONS_PER_JOB = 50; // Conservative limit
    
    /**
     * Constructor for initial deduplication request
     */
    public NotionDeduplicationQueueable(Set<Id> recordIds, String objectType) {
        this(recordIds, objectType, 0);
    }
    
    /**
     * Constructor with retry count
     */
    public NotionDeduplicationQueueable(Set<Id> recordIds, String objectType, Integer retryCount) {
        this.recordIds = recordIds;
        this.objectType = objectType;
        this.retryCount = retryCount != null ? retryCount : 0;
    }
    
    /**
     * Execute deduplication with governor limit checks
     */
    public void execute(QueueableContext context) {
        NotionSyncLogger logger = new NotionSyncLogger();
        
        try {
            // Check if we should defer due to limits
            if (NotionRateLimiter.shouldDeferProcessing()) {
                handleDeferral(logger, 'Governor limits approaching threshold');
                return;
            }
            
            // Get sync configuration
            NotionSyncObject__mdt syncConfig = getSyncConfiguration(objectType);
            if (syncConfig == null) {
                logger.log(
                    new NotionSyncLogger.LogEntry('DEDUP_SUMMARY')
                        .withSalesforceObject(objectType)
                        .withStatus('Failed')
                        .withMessage('No sync configuration found for object type: ' + objectType)
                );
                return;
            }
            
            // Process deduplication
            NotionSyncProcessor processor = new NotionSyncProcessor(logger);
            NotionSyncProcessor.DeduplicationResult result = processor.deduplicateNotionPages(
                recordIds, 
                syncConfig, 
                MAX_DELETIONS_PER_JOB
            );
            
            // Log results
            logger.log(
                new NotionSyncLogger.LogEntry('DEDUP_SUMMARY')
                    .withSalesforceObject(objectType)
                    .withStatus('Success')
                    .withDeduplication(result.duplicatesFound, result.duplicatesDeleted, result.deferred)
            );
            
            // If deduplication was deferred and we have remaining duplicates, re-queue
            if (result.deferred && result.duplicatesFound > result.duplicatesDeleted) {
                handleDeferral(logger, 'Deduplication partially completed, re-queuing for remaining duplicates');
            }
            
        } catch (Exception e) {
            logger.log(
                new NotionSyncLogger.LogEntry('DEDUP_SUMMARY')
                    .withSalesforceObject(objectType)
                    .withStatus('Failed')
                    .withMessage('Deduplication error: ' + e.getMessage())
            );
            
            // Re-queue if under retry limit
            if (retryCount < MAX_RETRY_COUNT - 1) {
                handleDeferral(logger, 'Error occurred, retrying: ' + e.getMessage());
            }
        } finally {
            // Always flush logs
            try {
                logger.flush();
            } catch (Exception e) {
                System.debug('Failed to flush deduplication logs: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Handle deferral by re-queuing if possible
     */
    private void handleDeferral(NotionSyncLogger logger, String reason) {
        logger.log(
            new NotionSyncLogger.LogEntry('DEDUP_SUMMARY')
                .withSalesforceObject(objectType)
                .withStatus('Deferred')
                .withMessage(reason)
        );
        
        // Re-queue if not in test and under retry limit
        if (!Test.isRunningTest() && retryCount < MAX_RETRY_COUNT - 1) {
            System.enqueueJob(new NotionDeduplicationQueueable(
                recordIds, 
                objectType, 
                retryCount + 1
            ));
        }
    }
    
    /**
     * Get sync configuration for the object type
     */
    private NotionSyncObject__mdt getSyncConfiguration(String objectType) {
        List<NotionSyncObject__mdt> configs = [
            SELECT Id, ObjectApiName__c, NotionDatabaseId__c, IsActive__c, SalesforceIdPropertyName__c
            FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectType
            AND IsActive__c = true
            LIMIT 1
        ];
        
        return configs.isEmpty() ? null : configs[0];
    }
}