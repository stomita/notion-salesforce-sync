// Enable debug logs for user
System.debug(LoggingLevel.DEBUG, 'Starting delete test');
try {
    NotionMetadataService.deleteObjectConfiguration('Test_Parent_Object__c');
    System.debug('Delete operation completed');
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}