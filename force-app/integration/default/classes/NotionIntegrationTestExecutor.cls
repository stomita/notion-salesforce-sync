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
     * Setup test data
     */
    public void setupTestData() {
        System.debug('\n--- Setting up test data ---');
        
        // Clean up any existing test data including deletion test records
        delete [SELECT Id FROM Account WHERE Name LIKE 'Integration Test%'];
        delete [SELECT Id FROM Contact WHERE LastName LIKE 'Integration Test%'];
        delete [SELECT Id FROM Test_Parent_Object__c WHERE Name LIKE 'Integration Test%'];
        delete [SELECT Id FROM Test_Child_Object__c WHERE Name LIKE 'Integration Test%'];
        
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
                LastName = 'Integration Test Contact ' + DateTime.now().getTime(),
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
                WHERE LastName LIKE 'Integration Test Contact%'
                AND FirstName != 'DELETE'
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
     * Test relationship changes (for separate test scripts)
     */
    public void setupRelationshipChanges() {
        System.debug('\n--- Testing relationship changes ---');
        
        try {
            // Create additional accounts for relationship changes
            Account secondAccount = new Account(
                Name = 'Integration Test Second Account ' + DateTime.now().getTime(),
                Description = 'Account for relationship change testing'
            );
            insert secondAccount;
            
            // Get the first account and test parent
            Account firstAccount = [
                SELECT Id, Name 
                FROM Account 
                WHERE Name LIKE 'Integration Test Account%' 
                AND (NOT Name LIKE '%DELETE%')
                AND (NOT Name LIKE '%Second%')
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Test_Parent_Object__c testParent = [
                SELECT Id
                FROM Test_Parent_Object__c
                WHERE Name LIKE 'Integration Test Parent%'
                AND (NOT Name LIKE '%DELETE%')
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Get existing contact and child
            Contact testContact = [
                SELECT Id, AccountId
                FROM Contact
                WHERE LastName LIKE 'Integration Test Contact%'
                AND FirstName != 'DELETE'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Test_Child_Object__c testChild = [
                SELECT Id, Account__c
                FROM Test_Child_Object__c
                WHERE Name LIKE 'Integration Test Child%'
                AND (NOT Name LIKE '%DELETE%')
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Change relationships
            System.debug('Changing Contact account from ' + testContact.AccountId + ' to ' + secondAccount.Id);
            testContact.AccountId = secondAccount.Id;
            update testContact;
            
            System.debug('Changing Test Child account from ' + testChild.Account__c + ' to ' + secondAccount.Id);
            testChild.Account__c = secondAccount.Id;
            update testChild;
            
            System.debug('Relationship changes completed');
            
        } catch (Exception e) {
            System.debug('Error in relationship change test: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Check relationship change sync results (for separate test scripts)
     */
    public void checkRelationshipChanges() {
        System.debug('\n--- Checking relationship change sync results ---');
        
        try {
            // Get the records that had relationships changed
            Contact testContact = [
                SELECT Id, AccountId
                FROM Contact
                WHERE LastName LIKE 'Integration Test Contact%'
                AND FirstName != 'DELETE'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Test_Child_Object__c testChild = [
                SELECT Id, Account__c
                FROM Test_Child_Object__c
                WHERE Name LIKE 'Integration Test Child%'
                AND (NOT Name LIKE '%DELETE%')
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Check for UPDATE sync logs
            List<Notion_Sync_Log__c> logs = [
                SELECT Id, Record_Id__c, Object_Type__c, Status__c, Error_Message__c, CreatedDate
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testContact.Id, :testChild.Id)
                AND Operation_Type__c = 'UPDATE'
                ORDER BY CreatedDate DESC
            ];
            
            // Look for recent update logs (should have at least 2 - one for each relationship change)
            Integer recentUpdateCount = 0;
            DateTime fiveMinutesAgo = DateTime.now().addMinutes(-5);
            
            for (Notion_Sync_Log__c log : logs) {
                if (log.CreatedDate >= fiveMinutesAgo) {
                    recentUpdateCount++;
                    assert(log.Status__c == 'Success', 
                        'Relationship change sync should succeed for ' + log.Object_Type__c + ': ' + log.Error_Message__c);
                }
            }
            
            assert(recentUpdateCount >= 2, 
                'Should have at least 2 UPDATE sync logs for relationship changes, found: ' + recentUpdateCount);
            
            passCount++;
            System.debug('✓ Relationship change sync test passed');
            
        } catch (Exception e) {
            failCount++;
            errors.add('Relationship change sync test failed: ' + e.getMessage());
            System.debug('✗ Relationship change sync test failed: ' + e.getMessage());
        }
    }
    
    /**
     * Create records specifically for deletion testing (Phase 1)
     */
    public void createDeletionTestRecords() {
        System.debug('\n--- Creating records for deletion test ---');
        
        // Create a separate account for deletion
        Account deleteAccount = new Account(
            Name = 'Integration Test DELETE Account ' + DateTime.now().getTime(),
            Description = 'This account will be deleted to test deletion sync'
        );
        insert deleteAccount;
        
        // Create a separate contact for deletion
        Contact deleteContact = new Contact(
            FirstName = 'DELETE',
            LastName = 'Integration Test Contact DELETE ' + DateTime.now().getTime(),
            Email = 'delete.test@example.com',
            AccountId = deleteAccount.Id
        );
        insert deleteContact;
        
        // Create a separate parent for deletion
        Test_Parent_Object__c deleteParent = new Test_Parent_Object__c(
            Name = 'Integration Test DELETE Parent ' + DateTime.now().getTime(),
            Description__c = 'This parent will be deleted',
            Status__c = 'To Delete',
            Amount__c = 999.99,
            Active__c = false
        );
        insert deleteParent;
        
        // Create a separate child for deletion
        Test_Child_Object__c deleteChild = new Test_Child_Object__c(
            Name = 'Integration Test DELETE Child ' + DateTime.now().getTime(),
            Test_Parent__c = deleteParent.Id,
            Account__c = deleteAccount.Id,
            Details__c = 'This child will be deleted',
            Quantity__c = 999,
            Due_Date__c = Date.today()
        );
        insert deleteChild;
        
        System.debug('Deletion test records created');
    }
    
    /**
     * Delete test records (Phase 1)
     */
    public void deleteTestRecords() {
        System.debug('\n--- Deleting test records ---');
        
        // Get all records created for deletion testing
        List<Account> deleteAccounts = [
            SELECT Id FROM Account 
            WHERE Name LIKE 'Integration Test DELETE Account%'
        ];
        
        List<Contact> deleteContacts = [
            SELECT Id FROM Contact 
            WHERE LastName LIKE 'Integration Test Contact DELETE%'
        ];
        
        List<Test_Parent_Object__c> deleteParents = [
            SELECT Id FROM Test_Parent_Object__c 
            WHERE Name LIKE 'Integration Test DELETE Parent%'
        ];
        
        List<Test_Child_Object__c> deleteChildren = [
            SELECT Id FROM Test_Child_Object__c 
            WHERE Name LIKE 'Integration Test DELETE Child%'
        ];
        
        // Delete in reverse dependency order
        delete deleteChildren;
        delete deleteContacts;
        delete deleteParents;
        delete deleteAccounts;
        
        System.debug('Deleted ' + deleteChildren.size() + ' child records');
        System.debug('Deleted ' + deleteContacts.size() + ' contact records');
        System.debug('Deleted ' + deleteParents.size() + ' parent records');
        System.debug('Deleted ' + deleteAccounts.size() + ' account records');
    }
    
    /**
     * Check delete sync results (Phase 2)
     */
    public void checkDeleteSyncResults() {
        System.debug('\n--- Checking delete sync results ---');
        
        try {
            // Find all delete sync logs from today
            List<Notion_Sync_Log__c> logs = [
                SELECT Id, Record_Id__c, Object_Type__c, Status__c, Error_Message__c
                FROM Notion_Sync_Log__c
                WHERE Operation_Type__c = 'DELETE'
                AND CreatedDate = TODAY
                ORDER BY CreatedDate DESC
            ];
            
            // Count successful deletions by object type
            Map<String, Integer> successCountByType = new Map<String, Integer>{
                'Account' => 0,
                'Contact' => 0,
                'Test_Parent_Object__c' => 0,
                'Test_Child_Object__c' => 0
            };
            
            Integer totalDeleteLogs = 0;
            for (Notion_Sync_Log__c log : logs) {
                // Only count logs for our deletion test records
                if (log.Status__c == 'Success') {
                    if (successCountByType.containsKey(log.Object_Type__c)) {
                        successCountByType.put(log.Object_Type__c, 
                            successCountByType.get(log.Object_Type__c) + 1);
                        totalDeleteLogs++;
                    }
                } else {
                    errors.add('Delete sync failed for ' + log.Object_Type__c + 
                        ' (' + log.Record_Id__c + '): ' + log.Error_Message__c);
                }
            }
            
            // Verify we have at least one successful deletion for each type
            assert(successCountByType.get('Account') >= 1, 
                'At least one Account deletion should succeed');
            assert(successCountByType.get('Contact') >= 1, 
                'At least one Contact deletion should succeed');
            assert(successCountByType.get('Test_Parent_Object__c') >= 1, 
                'At least one Test Parent deletion should succeed');
            assert(successCountByType.get('Test_Child_Object__c') >= 1, 
                'At least one Test Child deletion should succeed');
            
            System.debug('Delete sync summary:');
            for (String objType : successCountByType.keySet()) {
                System.debug('  ' + objType + ': ' + successCountByType.get(objType) + ' deleted');
            }
            
            passCount++;
            System.debug('✓ Delete sync test passed - ' + totalDeleteLogs + ' records deleted');
            
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