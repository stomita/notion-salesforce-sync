public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<NotionSync.Request> requests;
    private NotionSyncLogger logger;
    private NotionSyncProcessor processor;
    
    public NotionSyncQueueable(List<NotionSync.Request> requests) {
        this.requests = requests;
        this.logger = new NotionSyncLogger();
        this.processor = new NotionSyncProcessor(this.logger);
    }
    
    public void execute(QueueableContext context) {
        // Process requests using the injected logger
        processor.processSyncRequests(this.requests);
        
        // Flush logs at the end of the transaction
        logger.flush();
    }
}