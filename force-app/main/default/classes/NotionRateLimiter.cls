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
     * @description Enforces rate limiting by checking time since last request
     * Throws exception if rate limit would be exceeded, allowing caller to defer
     * @throws RateLimitException if request should be deferred
     */
    public static void throttleRequest() {
        // First check if we're approaching governor limits
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
                // Don't busy wait - instead defer to next async job
                // This avoids CPU consumption and allows natural spacing
                throw new RateLimitException(
                    String.format('Rate limit requires {0}ms delay (only {1}ms elapsed), defer to next batch',
                        new List<Object>{minimumInterval, millisecondsSinceLastRequest})
                );
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