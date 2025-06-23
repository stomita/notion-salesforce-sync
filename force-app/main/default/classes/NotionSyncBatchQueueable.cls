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
            
            // Log batch metrics and results
            logBatchMetrics(results);
            
            // Log overall batch summary
            logBatchSummary(results, nextStartIndex);
            
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
     * Log batch metrics to both debug log and database
     */
    private void logBatchMetrics(List<NotionSyncBatchProcessor.BatchResult> results) {
        if (results == null || results.isEmpty()) {
            return;
        }
        
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            if (result == null) {
                continue;
            }
            
            // Log batch-level metrics to debug log
            String message = String.format(
                'Batch processed: {0} items, Status: {1}, CPU: {2}ms, Heap: {3}KB, Callouts: {4}',
                new List<Object>{
                    result.batchSize != null ? result.batchSize : 0,
                    result.status != null ? result.status : 'Unknown',
                    result.cpuTimeUsed != null ? result.cpuTimeUsed : 0,
                    result.heapSizeUsed != null ? result.heapSizeUsed / 1024 : 0,
                    result.calloutsUsed != null ? result.calloutsUsed : 0
                }
            );
            
            System.debug(LoggingLevel.INFO, message);
            
            // Create a sync log entry for the batch result
            NotionSyncLogger.LogEntry batchLog = new NotionSyncLogger.LogEntry('BATCH')
                .withSalesforceObject(result.objectType)
                .withMetrics(result.calloutsUsed, result.cpuTimeUsed);
            
            // Build detailed message with batch statistics
            String batchDetails = String.format(
                'Batch Size: {0}, Processed: {1}, Failed: {2}, Deferred: {3}',
                new List<Object>{
                    result.batchSize != null ? result.batchSize : 0,
                    result.processedCount != null ? result.processedCount : 0,
                    result.failedCount != null ? result.failedCount : 0,
                    result.deferredCount != null ? result.deferredCount : 0
                }
            );
            
            // Set status based on batch result
            if (result.status == 'Success') {
                batchLog.withStatus('Success');
                // Add batch details to error message field for successful batches
                batchLog.errorMessage = batchDetails;
            } else if (result.status == 'Rate Limited') {
                batchLog.withRateLimit(result.retryAfterSeconds != null ? result.retryAfterSeconds : 1);
                String errorMsg = batchDetails;
                if (result.errorMessage != null) {
                    errorMsg += ' | Error: ' + result.errorMessage;
                }
                batchLog.withError(errorMsg);
            } else if (result.status == 'Error' || result.errorMessage != null) {
                String errorMsg = batchDetails;
                if (result.errorMessage != null) {
                    errorMsg += ' | Error: ' + result.errorMessage;
                }
                batchLog.withError(errorMsg);
            }
            
            // Log the batch result
            logger.log(batchLog);
            
            if (result.status == 'Rate Limited' && result.retryAfterSeconds != null) {
                System.debug('Batch was rate limited, retry after: ' + result.retryAfterSeconds + ' seconds');
            }
            
            if (result.errorMessage != null) {
                System.debug('Batch error: ' + result.errorMessage);
            }
        }
    }
    
    /**
     * Log overall batch job summary
     */
    private void logBatchSummary(List<NotionSyncBatchProcessor.BatchResult> results, Integer nextStartIndex) {
        if (results == null || results.isEmpty()) {
            return;
        }
        
        // Calculate totals
        Integer totalProcessed = 0;
        Integer totalFailed = 0;
        Integer totalDeferred = 0;
        Integer totalCallouts = 0;
        Integer totalCpuTime = 0;
        
        for (NotionSyncBatchProcessor.BatchResult result : results) {
            if (result != null) {
                totalProcessed += result.processedCount != null ? result.processedCount : 0;
                totalFailed += result.failedCount != null ? result.failedCount : 0;
                totalDeferred += result.deferredCount != null ? result.deferredCount : 0;
                totalCallouts += result.calloutsUsed != null ? result.calloutsUsed : 0;
                totalCpuTime += result.cpuTimeUsed != null ? result.cpuTimeUsed : 0;
            }
        }
        
        // Create summary log
        String summaryMessage = String.format(
            'Batch Job Summary - Total Requests: {0}, Processed: {1}, Failed: {2}, Deferred: {3}, Remaining: {4}, Batches: {5}, Callouts: {6}, CPU: {7}ms',
            new List<Object>{
                allRequests.size(),
                totalProcessed,
                totalFailed,
                totalDeferred,
                allRequests.size() - nextStartIndex,
                results.size(),
                totalCallouts,
                totalCpuTime
            }
        );
        
        NotionSyncLogger.LogEntry summaryLog = new NotionSyncLogger.LogEntry('BATCH_SUMMARY')
            .withMetrics(totalCallouts, totalCpuTime);
        
        // Set status based on overall results
        if (totalFailed > 0 || totalDeferred > 0) {
            summaryLog.withError(summaryMessage);
        } else {
            summaryLog.withStatus('Success');
            summaryLog.errorMessage = summaryMessage;
        }
        
        logger.log(summaryLog);
    }
    
    /**
     * Handle batch processing errors
     */
    private void handleBatchError(Exception e) {
        System.debug(LoggingLevel.ERROR, 'Batch processing error: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        
        // Log error using instance logger - use CREATE as operation type
        logger.log(
            new NotionSyncLogger.LogEntry('BATCH')
                .withError('Batch processing error: ' + e.getMessage())
        );
        
        // Don't rethrow - let the job complete
    }
}
