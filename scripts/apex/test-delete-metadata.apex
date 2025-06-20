// Test the metadata delete operation directly
try {
    System.debug('Testing NotionMetadataService.deleteObjectConfiguration');
    NotionMetadataService.deleteObjectConfiguration('Test_Parent_Object__c');
    System.debug('Delete operation initiated successfully');
} catch (Exception e) {
    System.debug('Error during delete: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}