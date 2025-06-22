/**
 * Queueable implementation for batch processing large volumes of sync requests
 * Processes requests in optimized batches with governor limit monitoring
 */
public class NotionSyncBatchQueueable implements Queueable, Database.AllowsCallouts {
    private List<NotionSync.Request> allRequests;
    private NotionSyncBatchProcessor batchProcessor;
    private Integer startIndex;
    private NotionSyncLogger logger;
    
    /**
     * Constructor for initial batch processing
     */
    public NotionSyncBatchQueueable(List<NotionSync.Request> requests) {
        this(requests, 0, null);
    }
    
    /**
     * Constructor for continued batch processing
     */
    public NotionSyncBatchQueueable(List<NotionSync.Request> requests, 
                                   Integer startIndex, 
                                   NotionSyncBatchProcessor processor) {
        this.allRequests = requests;
        this.startIndex = startIndex;
        this.batchProcessor = processor != null ? processor : new NotionSyncBatchProcessor();
        this.logger = new NotionSyncLogger();
    }
    
    /**
     * Execute the batch processing
     */
    public void execute(QueueableContext context) {
        Integer nextStartIndex = startIndex; // Initialize at class level for finally block
        
        try {
            // Get remaining requests to process
            List<NotionSync.Request> remainingRequests = getRemainingRequests();
            
            if (remainingRequests.isEmpty()) {
                return;
            }
            
            System.debug('NotionSyncBatchQueueable: Processing batch starting at index ' + startIndex + 
                       ' with ' + remainingRequests.size() + ' remaining requests out of ' + allRequests.size() + ' total');
            
            // Process batches - pass the logger instance
            List<NotionSyncBatchProcessor.BatchResult> results = 
                batchProcessor.processBatches(remainingRequests, logger);
            
            // Check if we need to continue processing
            Integer processedCount = getProcessedCount(results);
            nextStartIndex = startIndex + processedCount;
            
            System.debug('NotionSyncBatchQueueable: Processed ' + processedCount + ' records. Next start index: ' + nextStartIndex);
            
            // If we have more requests, continue processing
            // Even if deferred, we should chain another job to process remaining records
            if (nextStartIndex < allRequests.size()) {
                // Chain another queueable job
                if (!Test.isRunningTest()) {
                    // If deferred due to limits, wait a bit before chaining
                    if (wasDeferred(results)) {
                        // Schedule the next batch with a delay by using a platform event or scheduled apex
                        // For now, chain immediately - the next execution will have fresh limits
                        System.debug('Batch was deferred due to limits. Chaining next batch for remaining ' + 
                                   (allRequests.size() - nextStartIndex) + ' records');
                    }
                    
                    System.enqueueJob(new NotionSyncBatchQueueable(
                        allRequests, 
                        nextStartIndex, 
                        batchProcessor
                    ));
                }
            }
            
            // Add batch-level summary logs
            addBatchSummaryLogs(results);
            
        } catch (Exception e) {
            handleBatchError(e);
        } finally {
            // Flush logs directly - DML after callout is fine
            try {
                logger.flush();
            } catch (Exception e) {
                System.debug('Failed to flush logs: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Get remaining requests to process
     */
    private List<NotionSync.Request> getRemainingRequests() {
        List<NotionSync.Request> remaining = new List<NotionSync.Request>();
        
        for (Integer i = startIndex; i < allRequests.size(); i++) {
            remaining.add(allRequests[i]);
        }
        
        return remaining;
    }
    
    /**
     * Calculate total processed count from batch results
     */
    private Integer getProcessedCount(List<NotionSyncBatchProcessor.BatchResult> results) {
        Integer count = 0;
        
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            count += result.processedCount;
            count += result.failedCount;
        }
        
        return count;
    }
    
    /**
     * Check if any batch was deferred
     */
    private Boolean wasDeferred(List<NotionSyncBatchProcessor.BatchResult> results) {
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            if (result.shouldDefer) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Add batch-level summary logs
     */
    private void addBatchSummaryLogs(List<NotionSyncBatchProcessor.BatchResult> results) {
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            // Log batch-level metrics
            String message = String.format(
                'Batch processed: {0} items, Status: {1}, CPU: {2}ms, Heap: {3}KB, Callouts: {4}',
                new List<Object>{
                    result.batchSize,
                    result.status,
                    result.cpuTimeUsed,
                    result.heapSizeUsed / 1024,
                    result.calloutsUsed
                }
            );
            
            // Log batch summary using cleaner API
            NotionSyncLogger.LogEntry entry = logger.createLogEntry(
                'BATCH_' + System.now().getTime(),
                'BatchProcess',
                'BATCH'
            )
            .withStatus(result.status)
            .withMetrics(result.calloutsUsed, result.cpuTimeUsed);
            
            if (result.status == 'Rate Limited') {
                entry.withRateLimit(result.retryAfterSeconds);
            }
            
            if (result.errorMessage != null) {
                entry.withError(result.errorMessage);
            }
            
            logger.log(entry);
            
            System.debug(LoggingLevel.INFO, message);
        }
    }
    
    /**
     * Handle batch processing errors
     */
    private void handleBatchError(Exception e) {
        System.debug(LoggingLevel.ERROR, 'Batch processing error: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        
        // Log error using instance logger
        logger.log(
            logger.createLogEntry('BATCH_ERROR', 'BatchProcess', 'ERROR')
                .withError('Batch processing error: ' + e.getMessage())
        );
        
        // Don't rethrow - let the job complete
    }
}