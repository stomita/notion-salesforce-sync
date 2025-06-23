// Test 3 - Setup: Ensure prerequisite records exist for relationship test
System.debug('=== Test 3 Setup: Ensuring prerequisite records exist ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Check for existing records and create if needed
executor.setupRelationshipTest();

System.debug('Prerequisite records ready for relationship test.');