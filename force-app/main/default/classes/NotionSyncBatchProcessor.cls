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
    
    public NotionSyncBatchProcessor() {
        this(DEFAULT_BATCH_SIZE);
    }
    
    public NotionSyncBatchProcessor(Integer batchSize) {
        this.batchSize = Math.max(MIN_BATCH_SIZE, Math.min(batchSize, MAX_BATCH_SIZE));
    }
    
    /**
     * Process sync requests in optimized batches
     * @param allRequests All sync requests to process
     * @param logger Logger instance to use for logging
     * @return List of BatchResult containing processing results
     */
    public List<BatchResult> processBatches(List<NotionSync.Request> allRequests, NotionSyncLogger logger) {
        List<BatchResult> results = new List<BatchResult>();
        List<List<NotionSync.Request>> batches = createBatches(allRequests);
        
        System.debug('NotionSyncBatchProcessor: Created ' + batches.size() + ' batches from ' + allRequests.size() + ' requests');
        
        for (List<NotionSync.Request> batch : batches) {
            BatchResult result = processSingleBatch(batch, logger);
            results.add(result);
            
            // Check if we should defer remaining batches
            if (result.shouldDefer) {
                // Calculate deferred requests including current batch if not processed
                List<NotionSync.Request> deferredRequests = new List<NotionSync.Request>();
                
                // If current batch wasn't processed, include it
                if (result.processedCount == 0) {
                    deferredRequests.addAll(batch);
                }
                
                // Add remaining batches
                for (Integer i = batches.indexOf(batch) + 1; i < batches.size(); i++) {
                    deferredRequests.addAll(batches[i]);
                }
                
                if (!deferredRequests.isEmpty()) {
                    result.deferredCount = deferredRequests.size();
                    // Queue the deferred requests for later processing
                    queueRemainingRequests(deferredRequests);
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
    private List<List<NotionSync.Request>> createBatches(List<NotionSync.Request> requests) {
        List<List<NotionSync.Request>> batches = new List<List<NotionSync.Request>>();
        
        // Group by object type for better processing efficiency
        Map<String, List<NotionSync.Request>> requestsByType = groupByObjectType(requests);
        
        // Create batches for each object type
        for (String objectType : requestsByType.keySet()) {
            List<NotionSync.Request> typeRequests = requestsByType.get(objectType);
            
            // Calculate optimal batch size based on governor limits
            // Start with configured batch size and adjust down if needed
            Integer effectiveBatchSize = batchSize;
            
            // For callout limits, ensure batch size doesn't exceed what we can handle
            // Assuming 2 callouts per record, and keeping 10% buffer
            Integer maxBatchForCallouts = (Integer)((Limits.getLimitCallouts() - Limits.getCallouts()) * 0.9 / 2);
            effectiveBatchSize = Math.min(effectiveBatchSize, Math.max(MIN_BATCH_SIZE, maxBatchForCallouts));
            
            // No need to further check shouldDeferProcessing since we've already sized appropriately
            
            System.debug('Using effective batch size: ' + effectiveBatchSize + ' for ' + objectType);
            
            for (Integer i = 0; i < typeRequests.size(); i += effectiveBatchSize) {
                Integer endIndex = Math.min(i + effectiveBatchSize, typeRequests.size());
                List<NotionSync.Request> batch = new List<NotionSync.Request>();
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
    private Map<String, List<NotionSync.Request>> groupByObjectType(List<NotionSync.Request> requests) {
        Map<String, List<NotionSync.Request>> grouped = new Map<String, List<NotionSync.Request>>();
        
        for (NotionSync.Request request : requests) {
            if (!grouped.containsKey(request.objectType)) {
                grouped.put(request.objectType, new List<NotionSync.Request>());
            }
            grouped.get(request.objectType).add(request);
        }
        
        return grouped;
    }
    
    /**
     * Process a single batch with governor limit monitoring
     */
    private BatchResult processSingleBatch(List<NotionSync.Request> batch, NotionSyncLogger logger) {
        BatchResult result = new BatchResult();
        result.objectType = batch[0].objectType;
        result.batchSize = batch.size();
        result.startTime = System.now();
        
        // Check initial governor limits
        NotionRateLimiter.GovernorLimitStatus initialStatus = NotionRateLimiter.getGovernorLimitStatus();
        result.initialCpuTime = initialStatus.cpuTimeUsed;
        result.initialHeapSize = initialStatus.heapSizeUsed;
        result.initialCallouts = initialStatus.calloutsUsed;
        
        try {
            // Check CPU and heap limits only (callout limits already handled in batch sizing)
            if (NotionRateLimiter.shouldDeferProcessing()) {
                result.shouldDefer = true;
                result.deferReason = 'CPU or heap limits approaching threshold';
                // Important: Set processed count to 0 since we didn't process this batch
                result.processedCount = 0;
                result.failedCount = 0;
                return result;
            }
            
            // Create processor with the logger and process the batch
            NotionSyncProcessor processor = new NotionSyncProcessor(logger);
            processor.processSyncRequests(batch);
            
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
     * Queue remaining requests for asynchronous processing
     */
    private void queueRemainingRequests(List<NotionSync.Request> requests) {
        if (System.isFuture() || System.isQueueable() || System.isBatch()) {
            System.debug('WARNING: Cannot queue remaining requests - already in async context');
        } else {
            System.enqueueJob(new NotionSyncQueueable(requests));
        }
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
        public String objectType { get; set; }
        public Integer batchSize { get; set; }
        public Integer processedCount { get; set; }
        public Integer failedCount { get; set; }
        public Integer deferredCount { get; set; }
        public String status { get; set; }
        public String errorMessage { get; set; }
        public Boolean shouldDefer { get; set; }
        public String deferReason { get; set; }
        public Integer retryAfterSeconds { get; set; }
        
        // Deduplication metrics
        public Integer duplicatesFound { get; set; }
        public Integer duplicatesDeleted { get; set; }
        public Boolean deduplicationDeferred { get; set; }
        
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
            duplicatesFound = 0;
            duplicatesDeleted = 0;
            shouldDefer = false;
            deduplicationDeferred = false;
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