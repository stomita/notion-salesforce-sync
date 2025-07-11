/**
 * @description Manages rate limiting for Notion API calls to prevent exceeding limits
 * Handles both Notion API rate limits (3 req/sec) and Salesforce governor limits
 */
public with sharing class NotionRateLimiter {
    // Constants
    private static final Integer REQUESTS_PER_SECOND = 3;
    private static final Decimal CALLOUT_BUFFER_PERCENTAGE = 0.9; // Use 90% of limit
    private static final Decimal CPU_BUFFER_PERCENTAGE = 0.8; // Use 80% of CPU limit
    private static final Decimal HEAP_BUFFER_PERCENTAGE = 0.85; // Use 85% of heap limit
    
    // Tracking last request time for rate limiting
    @TestVisible
    private static DateTime lastRequestTime;
    
    // Custom exception for rate limit scenarios
    public class RateLimitException extends Exception {}
    
    /**
     * @description Check if processing should be deferred due to approaching governor limits
     * @return Boolean indicating whether to defer processing
     */
    public static Boolean shouldDeferProcessing() {
        // Check callout limit
        Integer calloutsUsed = Limits.getCallouts();
        Integer calloutLimit = Limits.getLimitCallouts();
        Decimal calloutUsage = calloutLimit > 0 ? 
            Decimal.valueOf(calloutsUsed) / calloutLimit : 0;
        
        // Check CPU time limit
        Integer cpuUsed = Limits.getCpuTime();
        Integer cpuLimit = Limits.getLimitCpuTime();
        Decimal cpuUsage = cpuLimit > 0 ? 
            Decimal.valueOf(cpuUsed) / cpuLimit : 0;
        
        // Check heap size limit
        Integer heapUsed = Limits.getHeapSize();
        Integer heapLimit = Limits.getLimitHeapSize();
        Decimal heapUsage = heapLimit > 0 ? 
            Decimal.valueOf(heapUsed) / heapLimit : 0;
        
        // Log current usage if approaching limits
        if (calloutUsage > 0.7 || cpuUsage > 0.7 || heapUsage > 0.7) {
            System.debug('Governor Limits - Callouts: ' + calloutsUsed + '/' + calloutLimit + 
                        ' (' + (calloutUsage * 100).setScale(1) + '%), ' +
                        'CPU: ' + cpuUsed + '/' + cpuLimit + 
                        ' (' + (cpuUsage * 100).setScale(1) + '%), ' +
                        'Heap: ' + heapUsed + '/' + heapLimit + 
                        ' (' + (heapUsage * 100).setScale(1) + '%)');
        }
        
        return (calloutUsage >= CALLOUT_BUFFER_PERCENTAGE) ||
               (cpuUsage >= CPU_BUFFER_PERCENTAGE) ||
               (heapUsage >= HEAP_BUFFER_PERCENTAGE);
    }
    
    /**
     * @description Check if processing should stop and chain to next queueable
     * Used for runtime checking during record processing
     * @return Boolean indicating whether to stop processing and chain
     */
    public static Boolean shouldStopProcessing() {
        // Check callout limit - leave buffer for at least 2 more records (6 callouts)
        Integer calloutsUsed = Limits.getCallouts();
        Integer calloutLimit = Limits.getLimitCallouts();
        Integer remainingCallouts = calloutLimit - calloutsUsed;
        
        // Check CPU time limit - leave 5 second buffer
        Integer cpuUsed = Limits.getCpuTime();
        Integer cpuLimit = Limits.getLimitCpuTime();
        Integer remainingCpu = cpuLimit - cpuUsed;
        
        // Check heap size limit - leave 15% buffer
        Integer heapUsed = Limits.getHeapSize();
        Integer heapLimit = Limits.getLimitHeapSize();
        Decimal heapUsage = heapLimit > 0 ? 
            Decimal.valueOf(heapUsed) / heapLimit : 0;
        
        // Stop if:
        // - Less than 6 callouts remaining (need ~3 per record)
        // - Less than 5 seconds CPU time remaining
        // - More than 85% heap used
        Boolean shouldStop = (remainingCallouts < 6) || 
                           (remainingCpu < 5000) || 
                           (heapUsage > 0.85);
        
        if (shouldStop) {
            System.debug('Should stop processing - Remaining callouts: ' + remainingCallouts + 
                       ', Remaining CPU: ' + remainingCpu + 'ms, Heap usage: ' + 
                       (heapUsage * 100).setScale(1) + '%');
        }
        
        return shouldStop;
    }
    
    /**
     * @description Enforces rate limiting by waiting if necessary
     * Uses busy wait with CPU time monitoring to maintain 3 req/sec rate limit
     * @throws RateLimitException if unable to wait due to governor limits
     */
    public static void throttleRequest() {
        // First check if we're approaching callout limit
        if (Limits.getCallouts() >= Limits.getLimitCallouts() - 5) {
            throw new RateLimitException(
                String.format('Approaching callout limit ({0}/{1}), defer to next async job',
                    new List<Object>{Limits.getCallouts(), Limits.getLimitCallouts()})
            );
        }
        
        // Check rate limit timing
        if (lastRequestTime != null) {
            Long millisecondsSinceLastRequest = DateTime.now().getTime() - lastRequestTime.getTime();
            Long minimumInterval = 1000 / REQUESTS_PER_SECOND; // 333ms between requests
            
            if (millisecondsSinceLastRequest < minimumInterval) {
                Long waitTime = minimumInterval - millisecondsSinceLastRequest;
                
                // Check if we have enough CPU time to wait
                // Leave 5 second buffer for safety
                Integer currentCpuTime = Limits.getCpuTime();
                Integer cpuLimit = Limits.getLimitCpuTime();
                Integer cpuBuffer = 5000; // 5 seconds
                
                if (currentCpuTime + waitTime > cpuLimit - cpuBuffer) {
                    throw new RateLimitException(
                        String.format('Insufficient CPU time for {0}ms wait. Current: {1}ms, Limit: {2}ms',
                            new List<Object>{waitTime, currentCpuTime, cpuLimit})
                    );
                }
                
                // Perform busy wait to maintain rate limit
                Long startTime = System.currentTimeMillis();
                while (System.currentTimeMillis() - startTime < waitTime) {
                    // Busy wait - this burns CPU but maintains precise rate limiting
                    // Check CPU time periodically to avoid hitting limit
                    if (Limits.getCpuTime() > cpuLimit - cpuBuffer) {
                        throw new RateLimitException('CPU time limit exceeded during rate limit wait');
                    }
                }
                
                System.debug(String.format('Rate limiter waited {0}ms to maintain 3 req/sec limit', 
                    new List<Object>{waitTime}));
            }
        }
        
        // Update last request time
        lastRequestTime = DateTime.now();
    }
    
    /**
     * @description Get current governor limit usage status as structured object
     * @return GovernorLimitStatus containing current usage statistics
     */
    public static GovernorLimitStatus getGovernorLimitStatus() {
        return new GovernorLimitStatus();
    }
    
    /**
     * @description Get current governor limit usage status as Map
     * @return Map containing current usage statistics
     */
    public static Map<String, Object> getGovernorLimitStatusMap() {
        Map<String, Object> status = new Map<String, Object>{
            'calloutsUsed' => Limits.getCallouts(),
            'calloutLimit' => Limits.getLimitCallouts(),
            'calloutPercentage' => calculatePercentage(Limits.getCallouts(), Limits.getLimitCallouts()),
            'cpuTimeUsed' => Limits.getCpuTime(),
            'cpuTimeLimit' => Limits.getLimitCpuTime(),
            'cpuPercentage' => calculatePercentage(Limits.getCpuTime(), Limits.getLimitCpuTime()),
            'heapUsed' => Limits.getHeapSize(),
            'heapLimit' => Limits.getLimitHeapSize(),
            'heapPercentage' => calculatePercentage(Limits.getHeapSize(), Limits.getLimitHeapSize()),
            'queriesUsed' => Limits.getQueries(),
            'queryLimit' => Limits.getLimitQueries(),
            'queryPercentage' => calculatePercentage(Limits.getQueries(), Limits.getLimitQueries()),
            'dmlRowsUsed' => Limits.getDmlRows(),
            'dmlRowsLimit' => Limits.getLimitDmlRows(),
            'dmlRowsPercentage' => calculatePercentage(Limits.getDmlRows(), Limits.getLimitDmlRows())
        };
        
        return status;
    }
    
    /**
     * @description Handle rate limit response from Notion API
     * @param response HTTP response to check for rate limiting
     * @return Boolean indicating if response was rate limited
     */
    public static Boolean handleRateLimit(HttpResponse response) {
        if (response.getStatusCode() == 429) {
            String retryAfter = response.getHeader('Retry-After');
            
            // Log rate limit occurrence
            System.debug('Notion API rate limit hit. Retry-After: ' + retryAfter);
            
            if (String.isNotBlank(retryAfter)) {
                // Parse retry-after seconds for logging
                Integer secondsToWait = Integer.valueOf(retryAfter);
                
                // Return true to indicate rate limiting occurred
                return true;
            }
            
            // No Retry-After header, use default wait
            return true;
        }
        return false;
    }
    
    /**
     * @description Calculate maximum batch size based on current governor limits
     * @param callsPerRecord Average number of API calls per record
     * @return Integer maximum safe batch size
     */
    public static Integer calculateMaxBatchSize(Integer callsPerRecord) {
        if (callsPerRecord == null || callsPerRecord <= 0) {
            callsPerRecord = 3; // Default assumption
        }
        
        // Check callout limit
        Integer remainingCallouts = Limits.getLimitCallouts() - Limits.getCallouts();
        Integer maxByCallouts = (remainingCallouts - 5) / callsPerRecord; // Leave 5 buffer
        
        // Check CPU time (accounting for rate limiting waits)
        Integer remainingCpuTime = Limits.getLimitCpuTime() - Limits.getCpuTime();
        // Each request needs 333ms wait + ~200ms processing
        Integer timePerRequest = 533; 
        Integer maxByCpuTime = (remainingCpuTime - 5000) / (timePerRequest * callsPerRecord);
        
        // Check heap size (rough estimate: 100KB per record)
        Integer remainingHeap = Limits.getLimitHeapSize() - Limits.getHeapSize();
        Integer maxByHeap = remainingHeap / 102400; // 100KB per record
        
        // Return the most restrictive limit
        Integer maxBatchSize = Math.min(Math.min(maxByCallouts, maxByCpuTime), maxByHeap);
        
        System.debug(String.format(
            'Max batch size calculation: Callouts={0}, CPU={1}, Heap={2}, Final={3}',
            new List<Object>{maxByCallouts, maxByCpuTime, maxByHeap, maxBatchSize}
        ));
        
        return Math.max(maxBatchSize, 0); // Never return negative
    }
    
    /**
     * @description Reset the last request time (mainly for testing)
     */
    @TestVisible
    private static void resetLastRequestTime() {
        lastRequestTime = null;
    }
    
    /**
     * @description Calculate percentage usage
     * @param used Current usage
     * @param limit Maximum limit
     * @return Decimal percentage (0-100)
     */
    public static Decimal calculatePercentage(Integer used, Integer limitValue) {
        if (limitValue == null || limitValue == 0) {
            return 0;
        }
        return (Decimal.valueOf(used) / limitValue * 100).setScale(1);
    }
    
    /**
     * @description Check if processing should be deferred based on governor limits
     * @param estimatedRecords Number of records to process
     * @return Boolean indicating if processing should be deferred
     */
    public static Boolean shouldDeferProcessing(Integer estimatedRecords) {
        Map<String, Object> status = getGovernorLimitStatusMap();
        
        // Check if we're approaching CPU limit (70%)
        Decimal cpuPercentage = (Decimal) status.get('cpuPercentage');
        if (cpuPercentage > 70) {
            return true;
        }
        
        // Check if we're approaching heap limit (70%)
        Decimal heapPercentage = (Decimal) status.get('heapPercentage');
        if (heapPercentage > 70) {
            return true;
        }
        
        // Check if we have enough callouts remaining
        Integer calloutsUsed = (Integer) status.get('calloutsUsed');
        Integer calloutLimit = (Integer) status.get('calloutLimit');
        // More accurate estimation: 1 call for create/update, 2 for records with relationships
        Integer estimatedCallouts = estimatedRecords * 2; // Conservative estimate: 2 calls per record
        
        if (calloutsUsed + estimatedCallouts > calloutLimit * 0.9) {
            return true;
        }
        
        return false;
    }
    
    /**
     * @description Governor limit status data structure
     */
    public class GovernorLimitStatus {
        public Integer cpuTimeUsed { get; set; }
        public Integer cpuTimeLimit { get; set; }
        public Integer heapSizeUsed { get; set; }
        public Integer heapSizeLimit { get; set; }
        public Integer calloutsUsed { get; set; }
        public Integer calloutLimit { get; set; }
        
        public GovernorLimitStatus() {
            this.cpuTimeUsed = Limits.getCpuTime();
            this.cpuTimeLimit = Limits.getLimitCpuTime();
            this.heapSizeUsed = Limits.getHeapSize();
            this.heapSizeLimit = Limits.getLimitHeapSize();
            this.calloutsUsed = Limits.getCallouts();
            this.calloutLimit = Limits.getLimitCallouts();
        }
    }
}