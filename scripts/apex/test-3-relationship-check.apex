// Test 3 - Check: Verify relationship sync results
System.debug('=== Test 3 Check: Verifying relationship sync results ===');

NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();

// Check relationship sync results
executor.checkRelationshipSyncResults();

System.debug('Relationship sync check complete.');