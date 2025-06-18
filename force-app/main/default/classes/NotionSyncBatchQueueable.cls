/**
 * Queueable implementation for batch processing large volumes of sync requests
 * Processes requests in optimized batches with governor limit monitoring
 */
public class NotionSyncBatchQueueable implements Queueable, Database.AllowsCallouts {
    private List<NotionSyncQueueable.SyncRequest> allRequests;
    private NotionSyncBatchProcessor batchProcessor;
    private Integer startIndex;
    
    /**
     * Constructor for initial batch processing
     */
    public NotionSyncBatchQueueable(List<NotionSyncQueueable.SyncRequest> requests) {
        this(requests, 0, null);
    }
    
    /**
     * Constructor for continued batch processing
     */
    public NotionSyncBatchQueueable(List<NotionSyncQueueable.SyncRequest> requests, 
                                   Integer startIndex, 
                                   NotionSyncBatchProcessor processor) {
        this.allRequests = requests;
        this.startIndex = startIndex;
        this.batchProcessor = processor != null ? processor : new NotionSyncBatchProcessor();
    }
    
    /**
     * Execute the batch processing
     */
    public void execute(QueueableContext context) {
        Integer nextStartIndex = startIndex; // Initialize at class level for finally block
        
        try {
            // Get remaining requests to process
            List<NotionSyncQueueable.SyncRequest> remainingRequests = getRemainingRequests();
            
            if (remainingRequests.isEmpty()) {
                return;
            }
            
            // Process batches
            List<NotionSyncBatchProcessor.BatchResult> results = 
                batchProcessor.processBatches(remainingRequests);
            
            // Check if we need to continue processing
            Integer processedCount = getProcessedCount(results);
            nextStartIndex = startIndex + processedCount;
            
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
            
            // Log batch processing results (without flushing)
            logBatchResults(results);
            
        } catch (Exception e) {
            handleBatchError(e);
        } finally {
            // Flush logs after each batch to ensure they're saved
            // This is safe because we've completed all callouts for this batch
            NotionSyncLogger.flush();
        }
    }
    
    /**
     * Get remaining requests to process
     */
    private List<NotionSyncQueueable.SyncRequest> getRemainingRequests() {
        List<NotionSyncQueueable.SyncRequest> remaining = new List<NotionSyncQueueable.SyncRequest>();
        
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
     * Log batch processing results
     */
    private void logBatchResults(List<NotionSyncBatchProcessor.BatchResult> results) {
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
            
            // Create a summary log entry
            NotionSyncLogger.LogEntry logEntry = NotionSyncLogger.logWithRateLimit(
                'BATCH_' + System.now().getTime(),
                'BatchProcess',
                'BATCH',
                result.status,
                result.errorMessage,
                0,
                null,
                result.status == 'Rate Limited',
                result.retryAfterSeconds
            );
            
            // Update metrics
            logEntry.apiCallsMade = result.calloutsUsed;
            logEntry.cpuTimeUsed = result.cpuTimeUsed;
            
            System.debug(LoggingLevel.INFO, message);
        }
        
        // Don't flush here - let the main execute method handle flushing
    }
    
    /**
     * Handle batch processing errors
     */
    private void handleBatchError(Exception e) {
        System.debug(LoggingLevel.ERROR, 'Batch processing error: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        
        // Log error for monitoring
        NotionSyncLogger.log(
            'BATCH_ERROR',
            'BatchProcess',
            'ERROR',
            'Failed',
            'Batch processing error: ' + e.getMessage(),
            0
        );
        
        // Don't flush here - let the main execute method handle flushing
        // Don't rethrow - let the job complete
    }
}