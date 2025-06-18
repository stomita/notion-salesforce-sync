/**
 * Batch processor for handling large volumes of Notion sync requests
 * Implements intelligent batching based on:
 * - Governor limits (CPU time, heap, callouts)
 * - Rate limit status
 * - Configurable batch sizes
 */
public class NotionSyncBatchProcessor {
    // Default batch sizes
    public static final Integer DEFAULT_BATCH_SIZE = 50;
    public static final Integer MIN_BATCH_SIZE = 1;
    public static final Integer MAX_BATCH_SIZE = 200;
    
    // Governor limit thresholds for safe processing
    private static final Decimal CPU_TIME_THRESHOLD = 0.7; // 70% of limit
    private static final Decimal HEAP_SIZE_THRESHOLD = 0.7; // 70% of limit
    private static final Decimal CALLOUT_THRESHOLD = 0.8; // 80% of limit
    
    private Integer batchSize;
    private NotionSyncQueueable queueable;
    
    public NotionSyncBatchProcessor() {
        this(DEFAULT_BATCH_SIZE);
    }
    
    public NotionSyncBatchProcessor(Integer batchSize) {
        this.batchSize = Math.max(MIN_BATCH_SIZE, Math.min(batchSize, MAX_BATCH_SIZE));
        this.queueable = new NotionSyncQueueable(new List<NotionSyncQueueable.SyncRequest>());
    }
    
    /**
     * Process sync requests in optimized batches
     * @param allRequests All sync requests to process
     * @return List of BatchResult containing processing results
     */
    public List<BatchResult> processBatches(List<NotionSyncQueueable.SyncRequest> allRequests) {
        List<BatchResult> results = new List<BatchResult>();
        List<List<NotionSyncQueueable.SyncRequest>> batches = createBatches(allRequests);
        
        for (List<NotionSyncQueueable.SyncRequest> batch : batches) {
            BatchResult result = processSingleBatch(batch);
            results.add(result);
            
            // Check if we should defer remaining batches
            if (result.shouldDefer) {
                // Queue remaining batches for async processing
                List<NotionSyncQueueable.SyncRequest> remainingRequests = new List<NotionSyncQueueable.SyncRequest>();
                for (Integer i = batches.indexOf(batch) + 1; i < batches.size(); i++) {
                    remainingRequests.addAll(batches[i]);
                }
                
                if (!remainingRequests.isEmpty()) {
                    queueRemainingRequests(remainingRequests);
                    result.deferredCount = remainingRequests.size();
                }
                break;
            }
        }
        
        // Don't flush logs here - let the calling context handle it
        // This prevents DML before callouts in subsequent batches
        
        return results;
    }
    
    /**
     * Create optimized batches based on current batch size
     */
    private List<List<NotionSyncQueueable.SyncRequest>> createBatches(List<NotionSyncQueueable.SyncRequest> requests) {
        List<List<NotionSyncQueueable.SyncRequest>> batches = new List<List<NotionSyncQueueable.SyncRequest>>();
        
        // Group by object type for better processing efficiency
        Map<String, List<NotionSyncQueueable.SyncRequest>> requestsByType = groupByObjectType(requests);
        
        // Create batches for each object type
        for (String objectType : requestsByType.keySet()) {
            List<NotionSyncQueueable.SyncRequest> typeRequests = requestsByType.get(objectType);
            
            // Calculate optimal batch size based on governor limits
            // Start with configured batch size and adjust down if needed
            Integer effectiveBatchSize = batchSize;
            while (effectiveBatchSize > MIN_BATCH_SIZE && NotionRateLimiter.shouldDeferProcessing(effectiveBatchSize)) {
                effectiveBatchSize = Math.max(MIN_BATCH_SIZE, effectiveBatchSize / 2);
            }
            
            System.debug('Using effective batch size: ' + effectiveBatchSize + ' for ' + objectType);
            
            for (Integer i = 0; i < typeRequests.size(); i += effectiveBatchSize) {
                Integer endIndex = Math.min(i + effectiveBatchSize, typeRequests.size());
                List<NotionSyncQueueable.SyncRequest> batch = new List<NotionSyncQueueable.SyncRequest>();
                for (Integer j = i; j < endIndex; j++) {
                    batch.add(typeRequests[j]);
                }
                batches.add(batch);
            }
        }
        
        return batches;
    }
    
    /**
     * Group requests by object type for efficient processing
     */
    private Map<String, List<NotionSyncQueueable.SyncRequest>> groupByObjectType(List<NotionSyncQueueable.SyncRequest> requests) {
        Map<String, List<NotionSyncQueueable.SyncRequest>> grouped = new Map<String, List<NotionSyncQueueable.SyncRequest>>();
        
        for (NotionSyncQueueable.SyncRequest request : requests) {
            if (!grouped.containsKey(request.objectType)) {
                grouped.put(request.objectType, new List<NotionSyncQueueable.SyncRequest>());
            }
            grouped.get(request.objectType).add(request);
        }
        
        return grouped;
    }
    
    /**
     * Process a single batch with governor limit monitoring
     */
    private BatchResult processSingleBatch(List<NotionSyncQueueable.SyncRequest> batch) {
        BatchResult result = new BatchResult();
        result.batchSize = batch.size();
        result.startTime = System.now();
        
        // Check initial governor limits
        NotionRateLimiter.GovernorLimitStatus initialStatus = NotionRateLimiter.getGovernorLimitStatus();
        result.initialCpuTime = initialStatus.cpuTimeUsed;
        result.initialHeapSize = initialStatus.heapSizeUsed;
        result.initialCallouts = initialStatus.calloutsUsed;
        
        try {
            // Check if we should defer based on current limits
            if (NotionRateLimiter.shouldDeferProcessing(batch.size())) {
                result.shouldDefer = true;
                result.deferReason = 'Governor limits approaching threshold';
                return result;
            }
            
            // Process the batch without auto-flushing logs to avoid DML before callouts
            queueable.processSyncRequests(batch, false);
            
            result.processedCount = batch.size();
            result.status = 'Success';
            
        } catch (NotionRateLimiter.RateLimitException e) {
            result.status = 'Rate Limited';
            result.errorMessage = e.getMessage();
            result.shouldDefer = true;
            result.deferReason = 'Rate limit encountered';
            
            // Extract retry after if available
            if (e.getMessage().contains('Retry after:')) {
                String retryStr = e.getMessage().substringAfter('Retry after:').trim();
                if (retryStr.length() > 0) {
                    result.retryAfterSeconds = Integer.valueOf(retryStr.split(' ')[0]);
                }
            }
            
        } catch (Exception e) {
            result.status = 'Error';
            result.errorMessage = e.getMessage();
            result.failedCount = batch.size() - result.processedCount;
        }
        
        // Capture final governor limits
        NotionRateLimiter.GovernorLimitStatus finalStatus = NotionRateLimiter.getGovernorLimitStatus();
        result.cpuTimeUsed = finalStatus.cpuTimeUsed - result.initialCpuTime;
        result.heapSizeUsed = finalStatus.heapSizeUsed - result.initialHeapSize;
        result.calloutsUsed = finalStatus.calloutsUsed - result.initialCallouts;
        result.endTime = System.now();
        
        // Adjust batch size based on performance
        adjustBatchSize(result);
        
        return result;
    }
    
    /**
     * Dynamically adjust batch size based on processing performance
     */
    private void adjustBatchSize(BatchResult result) {
        // Calculate resource usage percentages
        Decimal cpuUsagePercent = NotionRateLimiter.calculatePercentage(
            result.cpuTimeUsed, 
            Limits.getLimitCpuTime()
        );
        
        Decimal heapUsagePercent = NotionRateLimiter.calculatePercentage(
            result.heapSizeUsed,
            Limits.getLimitHeapSize()
        );
        
        // If we're using too much CPU or heap per batch, reduce batch size
        if (cpuUsagePercent > 50 || heapUsagePercent > 50) {
            batchSize = Math.max(MIN_BATCH_SIZE, (Integer)(batchSize * 0.75));
        }
        // If we're using very little resources, increase batch size
        else if (cpuUsagePercent < 20 && heapUsagePercent < 20 && result.status == 'Success') {
            batchSize = Math.min(MAX_BATCH_SIZE, (Integer)(batchSize * 1.25));
        }
    }
    
    /**
     * Queue remaining requests for async processing
     */
    private void queueRemainingRequests(List<NotionSyncQueueable.SyncRequest> requests) {
        // Check if we're already in an async context
        if (System.isFuture() || System.isQueueable() || System.isBatch()) {
            // Store for later processing or handle differently
            logDeferredRequests(requests);
        } else {
            // Queue for async processing
            System.enqueueJob(new NotionSyncQueueable(requests));
        }
    }
    
    /**
     * Log deferred requests for monitoring
     */
    private void logDeferredRequests(List<NotionSyncQueueable.SyncRequest> requests) {
        for (NotionSyncQueueable.SyncRequest request : requests) {
            NotionSyncLogger.log(
                request.recordId,
                request.objectType,
                request.operationType,
                'Deferred',
                'Batch processing deferred due to governor limits',
                0
            );
        }
        // Don't flush here - let the calling context handle it
    }
    
    /**
     * Get current batch size
     */
    public Integer getBatchSize() {
        return batchSize;
    }
    
    /**
     * Set batch size with validation
     */
    public void setBatchSize(Integer newSize) {
        this.batchSize = Math.max(MIN_BATCH_SIZE, Math.min(newSize, MAX_BATCH_SIZE));
    }
    
    /**
     * Result of processing a single batch
     */
    public class BatchResult {
        public Integer batchSize { get; set; }
        public Integer processedCount { get; set; }
        public Integer failedCount { get; set; }
        public Integer deferredCount { get; set; }
        public String status { get; set; }
        public String errorMessage { get; set; }
        public Boolean shouldDefer { get; set; }
        public String deferReason { get; set; }
        public Integer retryAfterSeconds { get; set; }
        
        // Performance metrics
        public DateTime startTime { get; set; }
        public DateTime endTime { get; set; }
        public Integer initialCpuTime { get; set; }
        public Integer cpuTimeUsed { get; set; }
        public Integer initialHeapSize { get; set; }
        public Integer heapSizeUsed { get; set; }
        public Integer initialCallouts { get; set; }
        public Integer calloutsUsed { get; set; }
        
        public BatchResult() {
            processedCount = 0;
            failedCount = 0;
            deferredCount = 0;
            shouldDefer = false;
        }
        
        /**
         * Get processing duration in milliseconds
         */
        public Long getDurationMillis() {
            if (startTime != null && endTime != null) {
                return endTime.getTime() - startTime.getTime();
            }
            return 0;
        }
    }
}