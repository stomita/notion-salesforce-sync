/**
 * Queueable implementation for processing Notion sync requests
 * Processes records individually and chains when approaching governor limits
 */
public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<NotionSync.Request> allRequests;
    private Integer startIndex;
    private NotionSyncLogger logger;
    private NotionSyncProcessor processor;
    
    // Track object type and ALL record IDs from the original request for deduplication
    private String currentObjectType;
    private Set<Id> allRecordIds;
    
    /**
     * Constructor for initial processing
     */
    public NotionSyncQueueable(List<NotionSync.Request> requests) {
        this(requests, 0);
    }
    
    /**
     * Constructor with start index for continued processing
     */
    public NotionSyncQueueable(List<NotionSync.Request> requests, Integer startIndex) {
        this.allRequests = requests;
        this.startIndex = startIndex != null ? startIndex : 0;
        this.logger = new NotionSyncLogger();
        this.processor = new NotionSyncProcessor(this.logger);
        
        // Extract ALL record IDs from requests for deduplication
        this.allRecordIds = new Set<Id>();
        for (NotionSync.Request request : requests) {
            if (request.operationType != 'DELETE' && String.isNotBlank(request.recordId)) {
                this.allRecordIds.add(request.recordId);
                if (String.isNotBlank(request.objectType)) {
                    this.currentObjectType = request.objectType;
                }
            }
        }
    }
    
    /**
     * Execute the sync processing
     */
    public void execute(QueueableContext context) {
        Integer currentIndex = startIndex;
        Boolean shouldContinue = true;
        
        try {
            System.debug('NotionSyncQueueable: Starting at index ' + startIndex + 
                       ' with ' + allRequests.size() + ' total requests');
            
            // Process requests one by one
            while (currentIndex < allRequests.size() && shouldContinue) {
                NotionSync.Request request = allRequests[currentIndex];
                
                // Check if we should stop before processing this record
                if (currentIndex > startIndex && NotionRateLimiter.shouldStopProcessing()) {
                    System.debug('Approaching governor limits at index ' + currentIndex + 
                               '. Will chain for remaining ' + (allRequests.size() - currentIndex) + ' records');
                    break;
                }
                
                // Process single request
                processSingleRequest(request);
                
                currentIndex++;
                
                // Check rate limit status after processing
                Map<String, Object> limitStatus = NotionRateLimiter.getGovernorLimitStatusMap();
                System.debug('After processing index ' + (currentIndex - 1) + ': ' +
                           'Callouts: ' + limitStatus.get('calloutsUsed') + '/' + limitStatus.get('calloutLimit') + ', ' +
                           'CPU: ' + limitStatus.get('cpuTimeUsed') + '/' + limitStatus.get('cpuTimeLimit') + 'ms');
            }
            
            // Log batch summary for this execution
            logExecutionSummary(currentIndex - startIndex, currentIndex < allRequests.size());
            
            // Chain if we have more requests
            if (currentIndex < allRequests.size()) {
                System.debug('More requests to process. Current: ' + currentIndex + ', Total: ' + allRequests.size());
                chainNextBatch(currentIndex);
            } else {
                System.debug('All requests processed. Total: ' + allRequests.size());
                // All requests processed - trigger deduplication if needed
                handleDeduplication();
            }
            
        } catch (Exception e) {
            handleExecutionError(e, currentIndex);
        } finally {
            // Always flush logs
            try {
                logger.flush();
            } catch (Exception e) {
                System.debug('Failed to flush logs: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Process a single sync request
     */
    private void processSingleRequest(NotionSync.Request request) {
        try {
            // Use processor to handle the request
            List<NotionSync.Request> singleRequest = new List<NotionSync.Request>{request};
            processor.processSyncRequests(singleRequest);
            
        } catch (NotionRateLimiter.RateLimitException e) {
            // Rate limit hit - log and re-throw to stop processing
            System.debug('Rate limit hit for request at index ' + allRequests.indexOf(request) + ': ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            // Log error but continue with next record
            System.debug('Error processing request at index ' + allRequests.indexOf(request) + ': ' + e.getMessage());
            logger.log(
                new NotionSyncLogger.LogEntry(request.operationType)
                    .withRecord(request.objectType, request.recordId)
                    .withStatus('Failed')
                    .withMessage(e.getMessage())
            );
        }
    }
    
    /**
     * Chain the next batch of requests
     */
    private void chainNextBatch(Integer nextStartIndex) {
        if (!Test.isRunningTest()) {
            System.debug('Chaining next batch starting at index ' + nextStartIndex);
            System.enqueueJob(new NotionSyncQueueable(allRequests, nextStartIndex));
        }
    }
    
    /**
     * Handle deduplication after all requests are processed
     */
    private void handleDeduplication() {
        // Only deduplicate for CREATE/UPDATE operations with all records from the original request
        if (!allRecordIds.isEmpty() && String.isNotBlank(currentObjectType)) {
            try {
                // Get sync configuration to verify it's active
                NotionSyncObject__mdt syncConfig = getSyncConfiguration(currentObjectType);
                if (syncConfig != null && syncConfig.IsActive__c) {
                    queueDeduplication();
                }
            } catch (Exception e) {
                System.debug('Failed to queue deduplication: ' + e.getMessage());
                logger.log(
                    new NotionSyncLogger.LogEntry('DEDUP_SUMMARY')
                        .withStatus('Failed')
                        .withMessage('Failed to queue deduplication: ' + e.getMessage())
                );
            }
        }
    }
    
    /**
     * Queue deduplication for all records in the sync batch
     */
    private void queueDeduplication() {
        if (!Test.isRunningTest() && !allRecordIds.isEmpty()) {
            System.enqueueJob(new NotionDeduplicationQueueable(allRecordIds, currentObjectType));
            System.debug('Queued deduplication for ' + allRecordIds.size() + ' records of type ' + currentObjectType);
            
            logger.log(
                new NotionSyncLogger.LogEntry('DEDUP_SUMMARY')
                    .withSalesforceObject(currentObjectType)
                    .withStatus('Deferred')
                    .withMessage('Deduplication queued for ' + allRecordIds.size() + ' records')
            );
        }
    }
    
    /**
     * Log execution summary
     */
    private void logExecutionSummary(Integer processedCount, Boolean hasMore) {
        Map<String, Object> limitStatus = NotionRateLimiter.getGovernorLimitStatusMap();
        
        String summaryMessage = String.format(
            'Execution Summary - Processed: {0}, Remaining: {1}, Callouts: {2}/{3}, CPU: {4}/{5}ms',
            new List<Object>{
                processedCount,
                hasMore ? allRequests.size() - (startIndex + processedCount) : 0,
                limitStatus.get('calloutsUsed'),
                limitStatus.get('calloutLimit'),
                limitStatus.get('cpuTimeUsed'),
                limitStatus.get('cpuTimeLimit')
            }
        );
        
        logger.log(
            new NotionSyncLogger.LogEntry('BATCH')
                .withStatus(hasMore ? 'Deferred' : 'Success')
                .withMessage(summaryMessage)
                .withMetrics(
                    (Integer)limitStatus.get('calloutsUsed'),
                    (Integer)limitStatus.get('cpuTimeUsed')
                )
        );
    }
    
    /**
     * Handle execution errors
     */
    private void handleExecutionError(Exception e, Integer lastProcessedIndex) {
        System.debug(LoggingLevel.ERROR, 'Sync processing error: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        
        logger.log(
            new NotionSyncLogger.LogEntry('BATCH')
                .withStatus('Failed')
                .withMessage('Processing error after index ' + lastProcessedIndex + ': ' + e.getMessage())
        );
        
        // Try to chain remaining requests if possible
        if (lastProcessedIndex < allRequests.size()) {
            System.debug('Attempting to chain after error. Remaining: ' + (allRequests.size() - lastProcessedIndex));
            try {
                chainNextBatch(lastProcessedIndex);
            } catch (Exception chainEx) {
                System.debug(LoggingLevel.ERROR, 'Failed to chain after error: ' + chainEx.getMessage());
            }
        }
        
        // Don't rethrow - let the job complete
    }
    
    /**
     * Get sync configuration for object type
     */
    private NotionSyncObject__mdt getSyncConfiguration(String objectType) {
        List<NotionSyncObject__mdt> configs = [
            SELECT Id, ObjectApiName__c, NotionDatabaseId__c, IsActive__c, SalesforceIdPropertyName__c
            FROM NotionSyncObject__mdt
            WHERE ObjectApiName__c = :objectType
            LIMIT 1
        ];
        
        return configs.isEmpty() ? null : configs[0];
    }
}