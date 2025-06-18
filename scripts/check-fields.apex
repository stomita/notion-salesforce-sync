// Check what fields exist on Notion_Sync_Log__c
Schema.DescribeSObjectResult objDescribe = Notion_Sync_Log__c.sObjectType.getDescribe();
Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

System.debug('=== Notion_Sync_Log__c Fields ===');
for(String fieldName : fieldsMap.keySet()) {
    Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
    System.debug(fieldName + ' (' + fieldDescribe.getType() + ')');
}

System.debug('\n=== Looking for Rate Limit Fields ===');
System.debug('Rate_Limited__c exists: ' + fieldsMap.containsKey('rate_limited__c'));
System.debug('Rate_Limit_Retry_After__c exists: ' + fieldsMap.containsKey('rate_limit_retry_after__c'));
System.debug('API_Calls_Made__c exists: ' + fieldsMap.containsKey('api_calls_made__c'));
System.debug('CPU_Time_Used__c exists: ' + fieldsMap.containsKey('cpu_time_used__c'));
System.debug('Callouts_Used__c exists: ' + fieldsMap.containsKey('callouts_used__c'));