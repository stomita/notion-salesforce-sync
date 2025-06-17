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
     * @description Get current governor limit usage status
     * @return Map containing current usage statistics
     */
    public static Map<String, Object> getGovernorLimitStatus() {
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
                // Store retry information for later processing
                Integer secondsToWait = Integer.valueOf(retryAfter);
                
                // Create platform event or schedule retry
                // For now, just return true to indicate rate limiting
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
    private static Decimal calculatePercentage(Integer used, Integer limitValue) {
        if (limitValue == null || limitValue == 0) {
            return 0;
        }
        return (Decimal.valueOf(used) / limitValue * 100).setScale(1);
    }
}