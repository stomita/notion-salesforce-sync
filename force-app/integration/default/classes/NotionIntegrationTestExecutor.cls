/**
 * Integration test executor for Notion sync functionality
 * This is NOT an @isTest class - it's executed via Anonymous Apex
 * to avoid deployment failures when credentials are not configured
 */
public class NotionIntegrationTestExecutor {
    
    private Integer passCount = 0;
    private Integer failCount = 0;
    private List<String> errors = new List<String>();
    
    /**
     * Phase 1: Trigger sync operations by creating/updating/deleting records
     */
    public void runPhase1_TriggerOperations() {
        System.debug('=== Phase 1: Triggering Sync Operations ===');
        
        try {
            // Setup and create test data - this triggers the flows
            setupTestData();
            createTestRecords();
            updateTestRecords();
            createRelatedRecords();
            deleteTestRecords();
            
            System.debug('Phase 1 complete - all operations triggered');
            
        } catch (Exception e) {
            System.debug('FATAL ERROR in Phase 1: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    /**
     * Phase 2: Check sync results after platform events have processed
     */
    public void runPhase2_CheckResults() {
        System.debug('=== Phase 2: Checking Sync Results ===');
        
        try {
            // Check results of all sync operations
            checkCreateSyncResults();
            checkUpdateSyncResults();
            checkRelationshipSyncResults();
            checkDeleteSyncResults();
            
            // Report results
            reportResults();
            
        } catch (Exception e) {
            System.debug('FATAL ERROR in Phase 2: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    /**
     * Setup test data
     */
    public void setupTestData() {
        System.debug('\n--- Setting up test data ---');
        
        // Clean up any existing test data
        delete [SELECT Id FROM Account WHERE Name LIKE 'Integration Test Account%'];
        delete [SELECT Id FROM Contact WHERE LastName LIKE 'Integration Test Contact%'];
        delete [SELECT Id FROM Test_Parent_Object__c WHERE Name LIKE 'Integration Test Parent%'];
        delete [SELECT Id FROM Test_Child_Object__c WHERE Name LIKE 'Integration Test Child%'];
        
        System.debug('Test data cleanup complete');
    }
    
    /**
     * Create test records (Phase 1)
     */
    public void createTestRecords() {
        System.debug('\n--- Creating test records ---');
        
        // Create test account
        Account testAccount = new Account(
            Name = 'Integration Test Account ' + DateTime.now().getTime(),
            Description = 'This account was created by integration test'
        );
        insert testAccount;
        
        // Create test parent object
        Test_Parent_Object__c testParent = new Test_Parent_Object__c(
            Name = 'Integration Test Parent ' + DateTime.now().getTime(),
            Description__c = 'Test parent description',
            Status__c = 'New',
            Amount__c = 1000.00,
            Active__c = true
        );
        insert testParent;
        
        System.debug('Test records created');
    }
    
    /**
     * Check create sync results (Phase 2)
     */
    public void checkCreateSyncResults() {
        System.debug('\n--- Checking create sync results ---');
        
        try {
            // Get the most recent test records
            Account testAccount = [
                SELECT Id, Name 
                FROM Account 
                WHERE Name LIKE 'Integration Test Account%' 
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Test_Parent_Object__c testParent = [
                SELECT Id, Name
                FROM Test_Parent_Object__c
                WHERE Name LIKE 'Integration Test Parent%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Check sync logs
            List<Notion_Sync_Log__c> logs = [
                SELECT Id, Record_Id__c, Status__c, Notion_Page_Id__c, Error_Message__c
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testAccount.Id, :testParent.Id)
                AND Operation_Type__c = 'CREATE'
                ORDER BY CreatedDate DESC
            ];
            
            Boolean accountSynced = false;
            Boolean parentSynced = false;
            
            for (Notion_Sync_Log__c log : logs) {
                if (log.Status__c == 'Success' && String.isNotBlank(log.Notion_Page_Id__c)) {
                    if (log.Record_Id__c == testAccount.Id) accountSynced = true;
                    if (log.Record_Id__c == testParent.Id) parentSynced = true;
                } else {
                    errors.add('Create sync failed for ' + log.Record_Id__c + ': ' + log.Error_Message__c);
                }
            }
            
            assert(accountSynced, 'Account should be synced to Notion');
            assert(parentSynced, 'Test Parent should be synced to Notion');
            
            passCount++;
            System.debug('✓ Create sync test passed');
            
        } catch (Exception e) {
            failCount++;
            errors.add('Create sync test failed: ' + e.getMessage());
            System.debug('✗ Create sync test failed: ' + e.getMessage());
        }
    }
    
    /**
     * Update test records (Phase 1)
     */
    public void updateTestRecords() {
        System.debug('\n--- Updating test records ---');
        
        // Get existing test records
        Account testAccount = [
            SELECT Id, Name, Description 
            FROM Account 
            WHERE Name LIKE 'Integration Test Account%' 
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        Test_Parent_Object__c testParent = [
            SELECT Id, Name, Status__c, Amount__c
            FROM Test_Parent_Object__c
            WHERE Name LIKE 'Integration Test Parent%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        // Update records
        testAccount.Description = 'Updated by integration test at ' + DateTime.now();
        update testAccount;
        
        testParent.Status__c = 'In Progress';
        testParent.Amount__c = 2500.00;
        update testParent;
        
        System.debug('Test records updated');
    }
    
    /**
     * Check update sync results (Phase 2)
     */
    public void checkUpdateSyncResults() {
        System.debug('\n--- Test 2: Update and Sync ---');
        
        try {
            // Get existing test records
            Account testAccount = [
                SELECT Id, Name, Description 
                FROM Account 
                WHERE Name LIKE 'Integration Test Account%' 
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Test_Parent_Object__c testParent = [
                SELECT Id, Name, Status__c, Amount__c
                FROM Test_Parent_Object__c
                WHERE Name LIKE 'Integration Test Parent%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Verify update sync
            List<Notion_Sync_Log__c> logs = [
                SELECT Id, Status__c, Error_Message__c
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testAccount.Id, :testParent.Id)
                AND Operation_Type__c = 'UPDATE'
                ORDER BY CreatedDate DESC
                LIMIT 2
            ];
            
            for (Notion_Sync_Log__c log : logs) {
                assert(log.Status__c == 'Success', 'Update sync should succeed: ' + log.Error_Message__c);
            }
            
            passCount++;
            System.debug('✓ Update sync test passed');
            
        } catch (Exception e) {
            failCount++;
            errors.add('Update sync test failed: ' + e.getMessage());
            System.debug('✗ Update sync test failed: ' + e.getMessage());
        }
    }
    
    /**
     * Create related records (Phase 1)
     */
    public void createRelatedRecords() {
        System.debug('\n--- Creating related records ---');
            // Get test records
            Account testAccount = [
                SELECT Id, Name 
                FROM Account 
                WHERE Name LIKE 'Integration Test Account%' 
                LIMIT 1
            ];
            
            Test_Parent_Object__c testParent = [
                SELECT Id, Name
                FROM Test_Parent_Object__c
                WHERE Name LIKE 'Integration Test Parent%'
                LIMIT 1
            ];
            
            // Create child with relationships
            Test_Child_Object__c testChild = new Test_Child_Object__c(
                Name = 'Integration Test Child ' + DateTime.now().getTime(),
                Test_Parent__c = testParent.Id,
                Account__c = testAccount.Id,
                Details__c = 'Child record with relationships',
                Quantity__c = 10,
                Due_Date__c = Date.today().addDays(30)
            );
            insert testChild;
            
            // Create contact related to account
            Contact testContact = new Contact(
                FirstName = 'Integration',
                LastName = 'Test Contact ' + DateTime.now().getTime(),
                Email = 'integration.test@example.com',
                AccountId = testAccount.Id
            );
            insert testContact;
            
        
        System.debug('Related records created');
    }
    
    /**
     * Check relationship sync results (Phase 2)
     */
    public void checkRelationshipSyncResults() {
        System.debug('\n--- Checking relationship sync results ---');
        
        try {
            // Get created child and contact
            Test_Child_Object__c testChild = [
                SELECT Id, Name
                FROM Test_Child_Object__c
                WHERE Name LIKE 'Integration Test Child%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Contact testContact = [
                SELECT Id, LastName
                FROM Contact
                WHERE LastName LIKE 'Test Contact%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Check sync logs
            List<Notion_Sync_Log__c> logs = [
                SELECT Id, Status__c, Notion_Page_Id__c, Error_Message__c, Object_Type__c
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testChild.Id, :testContact.Id)
                AND Operation_Type__c = 'CREATE'
                ORDER BY CreatedDate DESC
            ];
            
            for (Notion_Sync_Log__c log : logs) {
                assert(log.Status__c == 'Success', 
                    'Relationship sync should succeed for ' + log.Object_Type__c + ': ' + log.Error_Message__c);
                assert(String.isNotBlank(log.Notion_Page_Id__c), 
                    'Notion page ID should be populated for ' + log.Object_Type__c);
            }
            
            passCount++;
            System.debug('✓ Relationship sync test passed');
            
        } catch (Exception e) {
            failCount++;
            errors.add('Relationship sync test failed: ' + e.getMessage());
            System.debug('✗ Relationship sync test failed: ' + e.getMessage());
        }
    }
    
    /**
     * Delete test records (Phase 1)
     */
    public void deleteTestRecords() {
        System.debug('\n--- Deleting test records ---');
        
        // Get child record to delete
        Test_Child_Object__c testChild = [
            SELECT Id, Name
            FROM Test_Child_Object__c
            WHERE Name LIKE 'Integration Test Child%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        // Store the ID for later verification
        String childIdToDelete = testChild.Id;
        
        // Delete the record
        delete testChild;
        
        System.debug('Test child record deleted: ' + childIdToDelete);
    }
    
    /**
     * Check delete sync results (Phase 2)
     */
    public void checkDeleteSyncResults() {
        System.debug('\n--- Checking delete sync results ---');
        
        try {
            // Find the most recent delete sync log
            List<Notion_Sync_Log__c> logs = [
                SELECT Id, Record_Id__c, Status__c, Error_Message__c
                FROM Notion_Sync_Log__c
                WHERE Operation_Type__c = 'DELETE'
                AND Object_Type__c = 'Test_Child_Object__c'
                AND CreatedDate = TODAY
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            assert(!logs.isEmpty(), 'Delete sync log should be created');
            assert(logs[0].Status__c == 'Success', 
                'Delete sync should succeed: ' + logs[0].Error_Message__c);
            
            passCount++;
            System.debug('✓ Delete sync test passed');
            
        } catch (Exception e) {
            failCount++;
            errors.add('Delete sync test failed: ' + e.getMessage());
            System.debug('✗ Delete sync test failed: ' + e.getMessage());
        }
    }
    
    /**
     * Report test results
     */
    public void reportResults() {
        System.debug('\n=== Integration Test Results ===');
        System.debug('Passed: ' + passCount);
        System.debug('Failed: ' + failCount);
        
        if (!errors.isEmpty()) {
            System.debug('\nErrors:');
            for (String error : errors) {
                System.debug('- ' + error);
            }
        }
        
        if (failCount > 0) {
            throw new AssertException('Integration tests failed: ' + failCount + ' test(s) failed');
        }
        
        System.debug('\n✓ All integration tests passed!');
    }
    
    /**
     * Simple assertion method
     */
    private void assert(Boolean condition, String message) {
        if (!condition) {
            throw new AssertException(message);
        }
    }
    
    /**
     * Custom exception for test assertions
     */
    public class AssertException extends Exception {}
}