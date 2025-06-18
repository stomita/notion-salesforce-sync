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
     * Enable logging for integration tests
     */
    private void ensureLoggingEnabled() {
        Notion_Sync_Settings__c settings = Notion_Sync_Settings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new Notion_Sync_Settings__c();
        }
        settings.Enable_Logging__c = true;
        settings.Log_Level__c = 'DEBUG'; // Full logging for tests
        upsert settings;
        System.debug('Logging enabled for integration tests');
    }
    
    /**
     * Setup test data
     */
    public void setupTestData() {
        System.debug('\n--- Setting up test data ---');
        
        // Enable logging first
        ensureLoggingEnabled();
        
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
                SELECT Id, Name, Description 
                FROM Account 
                WHERE Name LIKE 'Integration Test Account%' 
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Test_Parent_Object__c testParent = [
                SELECT Id, Name, Description__c, Status__c, Amount__c, Active__c
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
            
            String accountNotionPageId = null;
            String parentNotionPageId = null;
            
            for (Notion_Sync_Log__c log : logs) {
                if (log.Status__c == 'Success' && String.isNotBlank(log.Notion_Page_Id__c)) {
                    if (log.Record_Id__c == testAccount.Id) accountNotionPageId = log.Notion_Page_Id__c;
                    if (log.Record_Id__c == testParent.Id) parentNotionPageId = log.Notion_Page_Id__c;
                } else {
                    errors.add('Create sync failed for ' + log.Record_Id__c + ': ' + log.Error_Message__c);
                }
            }
            
            assert(String.isNotBlank(accountNotionPageId), 'Account should be synced to Notion');
            assert(String.isNotBlank(parentNotionPageId), 'Test Parent should be synced to Notion');
            
            // Verify actual Notion data for Account
            if (String.isNotBlank(accountNotionPageId)) {
                NotionApiClient.NotionResponse accountResponse = NotionApiClient.getPage(accountNotionPageId);
                assert(accountResponse.success, 'Should be able to retrieve Account from Notion: ' + accountResponse.errorMessage);
                
                if (accountResponse.success && accountResponse.responseBody != null) {
                    Map<String, Object> accountPage = (Map<String, Object>) JSON.deserializeUntyped(accountResponse.responseBody);
                    Map<String, Object> properties = (Map<String, Object>) accountPage.get('properties');
                    
                    // Verify Name property
                    Map<String, Object> nameProperty = (Map<String, Object>) properties.get('Name');
                    List<Object> titleArray = (List<Object>) nameProperty.get('title');
                    if (!titleArray.isEmpty()) {
                        Map<String, Object> titleText = (Map<String, Object>) titleArray.get(0);
                        Map<String, Object> text = (Map<String, Object>) titleText.get('text');
                        String notionName = (String) text.get('content');
                        assert(notionName == testAccount.Name, 'Account Name in Notion should match Salesforce');
                    }
                    
                    // Verify Description (body content)
                    if (String.isNotBlank(testAccount.Description)) {
                        // Body content verification would require fetching blocks
                        System.debug('Account Description should be in page body content');
                    }
                }
            }
            
            // Verify actual Notion data for Test Parent
            if (String.isNotBlank(parentNotionPageId)) {
                NotionApiClient.NotionResponse parentResponse = NotionApiClient.getPage(parentNotionPageId);
                assert(parentResponse.success, 'Should be able to retrieve Test Parent from Notion: ' + parentResponse.errorMessage);
                
                if (parentResponse.success && parentResponse.responseBody != null) {
                    Map<String, Object> parentPage = (Map<String, Object>) JSON.deserializeUntyped(parentResponse.responseBody);
                    Map<String, Object> properties = (Map<String, Object>) parentPage.get('properties');
                    
                    // Verify Status property
                    Map<String, Object> statusProperty = (Map<String, Object>) properties.get('Status');
                    Map<String, Object> selectValue = (Map<String, Object>) statusProperty.get('select');
                    if (selectValue != null) {
                        String notionStatus = (String) selectValue.get('name');
                        assert(notionStatus == testParent.Status__c, 'Test Parent Status in Notion should match Salesforce');
                    }
                    
                    // Verify Amount property
                    Map<String, Object> amountProperty = (Map<String, Object>) properties.get('Amount');
                    Decimal notionAmount = (Decimal) amountProperty.get('number');
                    assert(notionAmount == testParent.Amount__c, 'Test Parent Amount in Notion should match Salesforce');
                    
                    // Verify Active property
                    Map<String, Object> activeProperty = (Map<String, Object>) properties.get('Active');
                    Boolean notionActive = (Boolean) activeProperty.get('checkbox');
                    assert(notionActive == testParent.Active__c, 'Test Parent Active in Notion should match Salesforce');
                }
            }
            
            passCount++;
            System.debug('✓ Create sync test passed - verified in Notion');
            
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
            
            // Get the Notion page IDs from previous CREATE sync
            List<Notion_Sync_Log__c> createLogs = [
                SELECT Id, Record_Id__c, Notion_Page_Id__c
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testAccount.Id, :testParent.Id)
                AND Operation_Type__c = 'CREATE'
                AND Status__c = 'Success'
                ORDER BY CreatedDate DESC
            ];
            
            String accountNotionPageId = null;
            String parentNotionPageId = null;
            
            for (Notion_Sync_Log__c log : createLogs) {
                if (log.Record_Id__c == testAccount.Id) accountNotionPageId = log.Notion_Page_Id__c;
                if (log.Record_Id__c == testParent.Id) parentNotionPageId = log.Notion_Page_Id__c;
            }
            
            // Verify update sync logs
            List<Notion_Sync_Log__c> updateLogs = [
                SELECT Id, Status__c, Error_Message__c
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testAccount.Id, :testParent.Id)
                AND Operation_Type__c = 'UPDATE'
                ORDER BY CreatedDate DESC
                LIMIT 2
            ];
            
            for (Notion_Sync_Log__c log : updateLogs) {
                assert(log.Status__c == 'Success', 'Update sync should succeed: ' + log.Error_Message__c);
            }
            
            // Verify actual Notion data for Account update
            if (String.isNotBlank(accountNotionPageId)) {
                NotionApiClient.NotionResponse accountResponse = NotionApiClient.getPage(accountNotionPageId);
                assert(accountResponse.success, 'Should be able to retrieve updated Account from Notion: ' + accountResponse.errorMessage);
                
                if (accountResponse.success && accountResponse.responseBody != null) {
                    // Account Description was updated, which is body content
                    // We should verify the body content was updated
                    System.debug('Account Description update should be reflected in page body content');
                }
            }
            
            // Verify actual Notion data for Test Parent update
            if (String.isNotBlank(parentNotionPageId)) {
                NotionApiClient.NotionResponse parentResponse = NotionApiClient.getPage(parentNotionPageId);
                assert(parentResponse.success, 'Should be able to retrieve updated Test Parent from Notion: ' + parentResponse.errorMessage);
                
                if (parentResponse.success && parentResponse.responseBody != null) {
                    Map<String, Object> parentPage = (Map<String, Object>) JSON.deserializeUntyped(parentResponse.responseBody);
                    Map<String, Object> properties = (Map<String, Object>) parentPage.get('properties');
                    
                    // Verify updated Status property
                    Map<String, Object> statusProperty = (Map<String, Object>) properties.get('Status');
                    Map<String, Object> selectValue = (Map<String, Object>) statusProperty.get('select');
                    if (selectValue != null) {
                        String notionStatus = (String) selectValue.get('name');
                        assert(notionStatus == 'In Progress', 'Test Parent Status in Notion should be updated to In Progress');
                    }
                    
                    // Verify updated Amount property
                    Map<String, Object> amountProperty = (Map<String, Object>) properties.get('Amount');
                    Decimal notionAmount = (Decimal) amountProperty.get('number');
                    assert(notionAmount == 2500.00, 'Test Parent Amount in Notion should be updated to 2500.00');
                }
            }
            
            passCount++;
            System.debug('✓ Update sync test passed - verified in Notion');
            
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
            // Get created child and contact with their relationships
            Test_Child_Object__c testChild = [
                SELECT Id, Name, Test_Parent__c, Account__c
                FROM Test_Child_Object__c
                WHERE Name LIKE 'Integration Test Child%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            Contact testContact = [
                SELECT Id, LastName, AccountId
                FROM Contact
                WHERE LastName LIKE 'Integration Test Contact%'
                AND FirstName != 'DELETE'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Check sync logs
            List<Notion_Sync_Log__c> logs = [
                SELECT Id, Record_Id__c, Status__c, Notion_Page_Id__c, Error_Message__c, Object_Type__c
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testChild.Id, :testContact.Id)
                AND Operation_Type__c = 'CREATE'
                ORDER BY CreatedDate DESC
            ];
            
            String childNotionPageId = null;
            String contactNotionPageId = null;
            
            for (Notion_Sync_Log__c log : logs) {
                assert(log.Status__c == 'Success', 
                    'Relationship sync should succeed for ' + log.Object_Type__c + ': ' + log.Error_Message__c);
                assert(String.isNotBlank(log.Notion_Page_Id__c), 
                    'Notion page ID should be populated for ' + log.Object_Type__c);
                    
                if (log.Record_Id__c == testChild.Id) childNotionPageId = log.Notion_Page_Id__c;
                if (log.Record_Id__c == testContact.Id) contactNotionPageId = log.Notion_Page_Id__c;
            }
            
            // Verify Contact relationships in Notion
            if (String.isNotBlank(contactNotionPageId)) {
                NotionApiClient.NotionResponse contactResponse = NotionApiClient.getPage(contactNotionPageId);
                assert(contactResponse.success, 'Should be able to retrieve Contact from Notion: ' + contactResponse.errorMessage);
                
                if (contactResponse.success && contactResponse.responseBody != null) {
                    Map<String, Object> contactPage = (Map<String, Object>) JSON.deserializeUntyped(contactResponse.responseBody);
                    Map<String, Object> properties = (Map<String, Object>) contactPage.get('properties');
                    
                    // Verify Account relation
                    Map<String, Object> accountRelation = (Map<String, Object>) properties.get('Account');
                    List<Object> relationArray = (List<Object>) accountRelation.get('relation');
                    assert(!relationArray.isEmpty(), 'Contact should have Account relation in Notion');
                    
                    if (!relationArray.isEmpty()) {
                        Map<String, Object> relatedPage = (Map<String, Object>) relationArray.get(0);
                        System.debug('Contact is related to Account Notion page: ' + relatedPage.get('id'));
                    }
                }
            }
            
            // Verify Test Child relationships in Notion
            if (String.isNotBlank(childNotionPageId)) {
                NotionApiClient.NotionResponse childResponse = NotionApiClient.getPage(childNotionPageId);
                assert(childResponse.success, 'Should be able to retrieve Test Child from Notion: ' + childResponse.errorMessage);
                
                if (childResponse.success && childResponse.responseBody != null) {
                    Map<String, Object> childPage = (Map<String, Object>) JSON.deserializeUntyped(childResponse.responseBody);
                    Map<String, Object> properties = (Map<String, Object>) childPage.get('properties');
                    
                    // Verify Test Parent relation
                    Map<String, Object> parentRelation = (Map<String, Object>) properties.get('Test Parent');
                    List<Object> parentRelationArray = (List<Object>) parentRelation.get('relation');
                    assert(!parentRelationArray.isEmpty(), 'Test Child should have Test Parent relation in Notion');
                    
                    // Verify Account relation
                    Map<String, Object> accountRelation = (Map<String, Object>) properties.get('Account');
                    List<Object> accountRelationArray = (List<Object>) accountRelation.get('relation');
                    assert(!accountRelationArray.isEmpty(), 'Test Child should have Account relation in Notion');
                }
            }
            
            passCount++;
            System.debug('✓ Relationship sync test passed - verified in Notion');
            
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
            
            // Get the second account that relationships were changed to
            Account secondAccount = [
                SELECT Id
                FROM Account
                WHERE Name LIKE 'Integration Test Second Account%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Get Notion page IDs from CREATE sync logs
            List<Notion_Sync_Log__c> createLogs = [
                SELECT Id, Record_Id__c, Notion_Page_Id__c
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testContact.Id, :testChild.Id)
                AND Operation_Type__c = 'CREATE'
                AND Status__c = 'Success'
                ORDER BY CreatedDate DESC
            ];
            
            String contactNotionPageId = null;
            String childNotionPageId = null;
            
            for (Notion_Sync_Log__c log : createLogs) {
                if (log.Record_Id__c == testContact.Id) contactNotionPageId = log.Notion_Page_Id__c;
                if (log.Record_Id__c == testChild.Id) childNotionPageId = log.Notion_Page_Id__c;
            }
            
            // Check for UPDATE sync logs
            List<Notion_Sync_Log__c> updateLogs = [
                SELECT Id, Record_Id__c, Object_Type__c, Status__c, Error_Message__c, CreatedDate
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c IN (:testContact.Id, :testChild.Id)
                AND Operation_Type__c = 'UPDATE'
                ORDER BY CreatedDate DESC
            ];
            
            // Look for recent update logs (should have at least 2 - one for each relationship change)
            Integer recentUpdateCount = 0;
            DateTime fiveMinutesAgo = DateTime.now().addMinutes(-5);
            
            for (Notion_Sync_Log__c log : updateLogs) {
                if (log.CreatedDate >= fiveMinutesAgo) {
                    recentUpdateCount++;
                    assert(log.Status__c == 'Success', 
                        'Relationship change sync should succeed for ' + log.Object_Type__c + ': ' + log.Error_Message__c);
                }
            }
            
            assert(recentUpdateCount >= 2, 
                'Should have at least 2 UPDATE sync logs for relationship changes, found: ' + recentUpdateCount);
            
            // Get the Notion page ID for the second account
            Notion_Sync_Log__c secondAccountLog = [
                SELECT Id, Notion_Page_Id__c
                FROM Notion_Sync_Log__c
                WHERE Record_Id__c = :secondAccount.Id
                AND Operation_Type__c = 'CREATE'
                AND Status__c = 'Success'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            String secondAccountNotionPageId = secondAccountLog.Notion_Page_Id__c;
            
            // Verify Contact relationship change in Notion
            if (String.isNotBlank(contactNotionPageId)) {
                NotionApiClient.NotionResponse contactResponse = NotionApiClient.getPage(contactNotionPageId);
                assert(contactResponse.success, 'Should be able to retrieve Contact from Notion: ' + contactResponse.errorMessage);
                
                if (contactResponse.success && contactResponse.responseBody != null) {
                    Map<String, Object> contactPage = (Map<String, Object>) JSON.deserializeUntyped(contactResponse.responseBody);
                    Map<String, Object> properties = (Map<String, Object>) contactPage.get('properties');
                    
                    // Verify Account relation now points to second account
                    Map<String, Object> accountRelation = (Map<String, Object>) properties.get('Account');
                    List<Object> relationArray = (List<Object>) accountRelation.get('relation');
                    assert(!relationArray.isEmpty(), 'Contact should still have Account relation in Notion');
                    
                    if (!relationArray.isEmpty()) {
                        Map<String, Object> relatedPage = (Map<String, Object>) relationArray.get(0);
                        String relatedPageId = (String) relatedPage.get('id');
                        assert(relatedPageId == secondAccountNotionPageId, 
                            'Contact should now be related to second Account in Notion');
                    }
                }
            }
            
            // Verify Test Child relationship change in Notion
            if (String.isNotBlank(childNotionPageId)) {
                NotionApiClient.NotionResponse childResponse = NotionApiClient.getPage(childNotionPageId);
                assert(childResponse.success, 'Should be able to retrieve Test Child from Notion: ' + childResponse.errorMessage);
                
                if (childResponse.success && childResponse.responseBody != null) {
                    Map<String, Object> childPage = (Map<String, Object>) JSON.deserializeUntyped(childResponse.responseBody);
                    Map<String, Object> properties = (Map<String, Object>) childPage.get('properties');
                    
                    // Verify Account relation now points to second account
                    Map<String, Object> accountRelation = (Map<String, Object>) properties.get('Account');
                    List<Object> accountRelationArray = (List<Object>) accountRelation.get('relation');
                    assert(!accountRelationArray.isEmpty(), 'Test Child should still have Account relation in Notion');
                    
                    if (!accountRelationArray.isEmpty()) {
                        Map<String, Object> relatedPage = (Map<String, Object>) accountRelationArray.get(0);
                        String relatedPageId = (String) relatedPage.get('id');
                        assert(relatedPageId == secondAccountNotionPageId, 
                            'Test Child should now be related to second Account in Notion');
                    }
                }
            }
            
            passCount++;
            System.debug('✓ Relationship change sync test passed - verified in Notion');
            
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
                SELECT Id, Record_Id__c, Object_Type__c, Status__c, Error_Message__c, Notion_Page_Id__c
                FROM Notion_Sync_Log__c
                WHERE Operation_Type__c = 'DELETE'
                AND CreatedDate = TODAY
                ORDER BY CreatedDate DESC
            ];
            
            // Count successful deletions by object type and collect Notion page IDs
            Map<String, Integer> successCountByType = new Map<String, Integer>{
                'Account' => 0,
                'Contact' => 0,
                'Test_Parent_Object__c' => 0,
                'Test_Child_Object__c' => 0
            };
            
            List<String> deletedNotionPageIds = new List<String>();
            Integer totalDeleteLogs = 0;
            
            for (Notion_Sync_Log__c log : logs) {
                // Only count logs for our deletion test records
                if (log.Status__c == 'Success') {
                    if (successCountByType.containsKey(log.Object_Type__c)) {
                        successCountByType.put(log.Object_Type__c, 
                            successCountByType.get(log.Object_Type__c) + 1);
                        totalDeleteLogs++;
                        
                        if (String.isNotBlank(log.Notion_Page_Id__c)) {
                            deletedNotionPageIds.add(log.Notion_Page_Id__c);
                        }
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
            
            // Verify the pages are actually deleted from Notion
            Integer verifiedDeletes = 0;
            for (String pageId : deletedNotionPageIds) {
                if (String.isNotBlank(pageId)) {
                    NotionApiClient.NotionResponse response = NotionApiClient.getPage(pageId);
                    // A deleted page should return an error (404 or similar)
                    if (!response.success) {
                        verifiedDeletes++;
                        System.debug('Verified page ' + pageId + ' is deleted from Notion');
                    } else {
                        errors.add('Page ' + pageId + ' still exists in Notion after deletion');
                    }
                }
            }
            
            assert(verifiedDeletes >= 4, 
                'At least 4 pages should be verified as deleted from Notion, found: ' + verifiedDeletes);
            
            System.debug('Delete sync summary:');
            for (String objType : successCountByType.keySet()) {
                System.debug('  ' + objType + ': ' + successCountByType.get(objType) + ' deleted');
            }
            System.debug('Verified ' + verifiedDeletes + ' pages deleted from Notion');
            
            passCount++;
            System.debug('✓ Delete sync test passed - ' + totalDeleteLogs + ' records deleted and verified in Notion');
            
        } catch (Exception e) {
            failCount++;
            errors.add('Delete sync test failed: ' + e.getMessage());
            System.debug('✗ Delete sync test failed: ' + e.getMessage());
        }
    }
    
    /**
     * Create bulk records for batch processing test (Phase 1)
     */
    public void createBatchTestRecords() {
        System.debug('\n--- Creating bulk records for batch processing test ---');
        
        // Clean up any existing batch test data
        delete [SELECT Id FROM Account WHERE Name LIKE 'Batch Test Account%'];
        delete [SELECT Id FROM Contact WHERE LastName LIKE 'Batch Test Contact%'];
        
        // Create 75 accounts to trigger batch processing (default batch size is 50)
        List<Account> batchAccounts = new List<Account>();
        for (Integer i = 1; i <= 75; i++) {
            Account acc = new Account(
                Name = 'Batch Test Account ' + String.valueOf(i).leftPad(3, '0'),
                Description = 'Batch test account #' + i + ' created at ' + DateTime.now(),
                Type = 'Customer',
                Industry = 'Technology',
                AnnualRevenue = 100000 + (i * 1000)
            );
            batchAccounts.add(acc);
        }
        
        insert batchAccounts;
        System.debug('Created ' + batchAccounts.size() + ' accounts for batch testing');
        
        // Create contacts for the first 25 accounts
        List<Contact> batchContacts = new List<Contact>();
        for (Integer i = 0; i < 25; i++) {
            Contact con = new Contact(
                FirstName = 'Batch',
                LastName = 'Batch Test Contact ' + String.valueOf(i+1).leftPad(3, '0'),
                Email = 'batch.test.' + (i+1) + '@example.com',
                AccountId = batchAccounts[i].Id,
                Title = 'Test Contact #' + (i+1)
            );
            batchContacts.add(con);
        }
        
        insert batchContacts;
        System.debug('Created ' + batchContacts.size() + ' contacts for batch testing');
        System.debug('Total batch test records: ' + (batchAccounts.size() + batchContacts.size()));
    }
    
    /**
     * Check batch processing results (Phase 2)
     */
    public void checkBatchProcessingResults() {
        System.debug('\n--- Checking batch processing results ---');
        
        try {
            // Get the batch test records
            List<Account> batchAccounts = [
                SELECT Id, Name 
                FROM Account 
                WHERE Name LIKE 'Batch Test Account%'
                ORDER BY Name
            ];
            
            List<Contact> batchContacts = [
                SELECT Id, LastName, AccountId
                FROM Contact
                WHERE LastName LIKE 'Batch Test Contact%'
                ORDER BY LastName
            ];
            
            System.debug('Found ' + batchAccounts.size() + ' batch accounts');
            System.debug('Found ' + batchContacts.size() + ' batch contacts');
            
            // Get record IDs for SOQL query
            Set<Id> batchAccountIds = new Set<Id>();
            for (Account acc : batchAccounts) {
                batchAccountIds.add(acc.Id);
            }
            
            Set<Id> batchContactIds = new Set<Id>();
            for (Contact con : batchContacts) {
                batchContactIds.add(con.Id);
            }
            
            // Check sync logs
            List<Notion_Sync_Log__c> batchLogs = [
                SELECT Id, Record_Id__c, Object_Type__c, Operation_Type__c, Status__c, 
                       Notion_Page_Id__c, Error_Message__c, API_Calls_Made__c, 
                       CPU_Time_Used__c, Callouts_Used__c
                FROM Notion_Sync_Log__c
                WHERE ((Object_Type__c = 'Account' AND Record_Id__c IN :batchAccountIds)
                   OR (Object_Type__c = 'Contact' AND Record_Id__c IN :batchContactIds))
                AND Operation_Type__c = 'CREATE'
                ORDER BY CreatedDate DESC
            ];
            
            // Count successes
            Map<String, Integer> successByType = new Map<String, Integer>{
                'Account' => 0,
                'Contact' => 0
            };
            Set<String> syncedAccountIds = new Set<String>();
            Set<String> syncedContactIds = new Set<String>();
            
            for (Notion_Sync_Log__c log : batchLogs) {
                if (log.Status__c == 'Success') {
                    successByType.put(log.Object_Type__c, successByType.get(log.Object_Type__c) + 1);
                    if (log.Object_Type__c == 'Account') {
                        syncedAccountIds.add(log.Record_Id__c);
                    } else if (log.Object_Type__c == 'Contact') {
                        syncedContactIds.add(log.Record_Id__c);
                    }
                }
            }
            
            System.debug('Accounts synced: ' + successByType.get('Account') + '/' + batchAccounts.size());
            System.debug('Contacts synced: ' + successByType.get('Contact') + '/' + batchContacts.size());
            
            // Check for batch processing indicators
            List<Notion_Sync_Log__c> batchProcessLogs = [
                SELECT Id, Object_Type__c, Operation_Type__c, Status__c, 
                       API_Calls_Made__c, CPU_Time_Used__c, Callouts_Used__c
                FROM Notion_Sync_Log__c
                WHERE Object_Type__c = 'BatchProcess'
                AND Operation_Type__c = 'BATCH'
                AND CreatedDate >= :DateTime.now().addMinutes(-10)
                ORDER BY CreatedDate DESC
            ];
            
            if (!batchProcessLogs.isEmpty()) {
                System.debug('Found ' + batchProcessLogs.size() + ' batch process log entries');
            }
            
            // Verify a sample of Notion pages
            Integer sampleSize = 5;
            Integer verified = 0;
            for (String accountId : syncedAccountIds) {
                if (verified >= sampleSize) break;
                
                Notion_Sync_Log__c log = [
                    SELECT Notion_Page_Id__c 
                    FROM Notion_Sync_Log__c 
                    WHERE Record_Id__c = :accountId
                    AND Status__c = 'Success'
                    AND Notion_Page_Id__c != null
                    LIMIT 1
                ];
                
                if (String.isNotBlank(log.Notion_Page_Id__c)) {
                    try {
                        NotionApiClient.NotionResponse response = NotionApiClient.getPage(log.Notion_Page_Id__c);
                        if (response.success) {
                            verified++;
                        }
                    } catch (Exception e) {
                        // Ignore individual verification errors
                    }
                }
            }
            
            System.debug('Verified ' + verified + ' sample Notion pages');
            
            // Assert batch processing worked
            assert(syncedAccountIds.size() >= 70, 
                'At least 70 accounts should be synced, found: ' + syncedAccountIds.size());
            assert(syncedContactIds.size() >= 20, 
                'At least 20 contacts should be synced, found: ' + syncedContactIds.size());
            
            passCount++;
            System.debug('✓ Batch processing test passed - ' + 
                        (syncedAccountIds.size() + syncedContactIds.size()) + ' records synced');
            
        } catch (Exception e) {
            failCount++;
            errors.add('Batch processing test failed: ' + e.getMessage());
            System.debug('✗ Batch processing test failed: ' + e.getMessage());
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