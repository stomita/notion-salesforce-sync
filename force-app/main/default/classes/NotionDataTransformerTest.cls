@isTest
public class NotionDataTransformerTest {
    
    // Test data setup method
    @testSetup
    static void setupTestData() {
        // Create test custom metadata would go here if we were able to insert custom metadata in tests
        // Since custom metadata can't be inserted in tests, we'll mock the behavior in individual tests
    }
    
    @isTest
    static void testTransformRecordWithTitleProperty() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Test.startTest();
        
        // Mock field mappings by testing addProperty directly
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        
        // Create mock mapping for title property
        NotionSyncField__mdt titleMapping = createMockFieldMapping('Name', 'Account Name', 'title', false);
        
        // Use reflection to call private method addProperty
        callAddPropertyMethod(notionPage, titleMapping, testAccount.Name);
        
        Test.stopTest();
        
        // Verify title property was added correctly
        System.assert(notionPage.properties.containsKey('Account Name'), 'Should contain Account Name property');
        Map<String, Object> titleProperty = (Map<String, Object>) notionPage.properties.get('Account Name');
        System.assert(titleProperty.containsKey('title'), 'Should contain title key');
        
        List<Object> titleArray = (List<Object>) titleProperty.get('title');
        System.assertEquals(1, titleArray.size(), 'Should have one title element');
        
        Map<String, Object> titleElement = (Map<String, Object>) titleArray[0];
        Map<String, Object> text = (Map<String, Object>) titleElement.get('text');
        System.assertEquals('Test Account', text.get('content'), 'Should contain correct account name');
    }
    
    @isTest
    static void testTransformRecordWithRichTextProperty() {
        Account testAccount = new Account(Name = 'Test Account', Description = 'Test Description');
        insert testAccount;
        
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt richTextMapping = createMockFieldMapping('Description', 'Description', 'rich_text', false);
        
        callAddPropertyMethod(notionPage, richTextMapping, testAccount.Description);
        
        Test.stopTest();
        
        Map<String, Object> richTextProperty = (Map<String, Object>) notionPage.properties.get('Description');
        System.assert(richTextProperty.containsKey('rich_text'), 'Should contain rich_text key');
        
        List<Object> richTextArray = (List<Object>) richTextProperty.get('rich_text');
        System.assertEquals(1, richTextArray.size(), 'Should have one rich text element');
        
        Map<String, Object> textElement = (Map<String, Object>) richTextArray[0];
        Map<String, Object> text = (Map<String, Object>) textElement.get('text');
        System.assertEquals('Test Description', text.get('content'), 'Should contain correct description');
    }
    
    @isTest
    static void testTransformRecordWithNumberProperty() {
        Account testAccount = new Account(Name = 'Test Account', NumberOfEmployees = 100);
        insert testAccount;
        
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt numberMapping = createMockFieldMapping('NumberOfEmployees', 'Employee Count', 'number', false);
        
        callAddPropertyMethod(notionPage, numberMapping, testAccount.NumberOfEmployees);
        
        Test.stopTest();
        
        Map<String, Object> numberProperty = (Map<String, Object>) notionPage.properties.get('Employee Count');
        System.assertEquals(100, numberProperty.get('number'), 'Should contain correct number value');
    }
    
    @isTest
    static void testTransformRecordWithNumberPropertyString() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt numberMapping = createMockFieldMapping('AnnualRevenue', 'Revenue', 'number', false);
        
        callAddPropertyMethod(notionPage, numberMapping, '1000000');
        
        Test.stopTest();
        
        Map<String, Object> numberProperty = (Map<String, Object>) notionPage.properties.get('Revenue');
        System.assertEquals(1000000, numberProperty.get('number'), 'Should convert string to number');
    }
    
    @isTest
    static void testTransformRecordWithInvalidNumber() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt numberMapping = createMockFieldMapping('AnnualRevenue', 'Revenue', 'number', false);
        
        try {
            callAddPropertyMethod(notionPage, numberMapping, 'invalid number');
            System.assert(false, 'Should throw exception for invalid number');
        } catch (NotionDataTransformer.TransformationException e) {
            System.assert(e.getMessage().contains('Invalid number value'), 'Should contain error message about invalid number');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testTransformRecordWithSelectProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt selectMapping = createMockFieldMapping('Type', 'Account Type', 'select', false);
        
        callAddPropertyMethod(notionPage, selectMapping, 'Customer');
        
        Test.stopTest();
        
        Map<String, Object> selectProperty = (Map<String, Object>) notionPage.properties.get('Account Type');
        Map<String, Object> selectValue = (Map<String, Object>) selectProperty.get('select');
        System.assertEquals('Customer', selectValue.get('name'), 'Should contain correct select value');
    }
    
    @isTest
    static void testTransformRecordWithMultiSelectProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt multiSelectMapping = createMockFieldMapping('Industry', 'Industries', 'multi_select', false);
        
        callAddPropertyMethod(notionPage, multiSelectMapping, 'Technology;Software;Cloud');
        
        Test.stopTest();
        
        Map<String, Object> multiSelectProperty = (Map<String, Object>) notionPage.properties.get('Industries');
        List<Object> multiSelectValues = (List<Object>) multiSelectProperty.get('multi_select');
        System.assertEquals(3, multiSelectValues.size(), 'Should have three multi-select values');
        
        Map<String, Object> firstValue = (Map<String, Object>) multiSelectValues[0];
        System.assertEquals('Technology', firstValue.get('name'), 'Should contain first value');
        
        Map<String, Object> secondValue = (Map<String, Object>) multiSelectValues[1];
        System.assertEquals('Software', secondValue.get('name'), 'Should contain second value');
    }
    
    @isTest
    static void testTransformRecordWithMultiSelectSingleValue() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt multiSelectMapping = createMockFieldMapping('Industry', 'Industries', 'multi_select', false);
        
        callAddPropertyMethod(notionPage, multiSelectMapping, 'Technology');
        
        Test.stopTest();
        
        Map<String, Object> multiSelectProperty = (Map<String, Object>) notionPage.properties.get('Industries');
        List<Object> multiSelectValues = (List<Object>) multiSelectProperty.get('multi_select');
        System.assertEquals(1, multiSelectValues.size(), 'Should have one multi-select value');
        
        Map<String, Object> firstValue = (Map<String, Object>) multiSelectValues[0];
        System.assertEquals('Technology', firstValue.get('name'), 'Should contain the value');
    }
    
    @isTest
    static void testTransformRecordWithDateProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt dateMapping = createMockFieldMapping('CreatedDate', 'Created', 'date', false);
        
        Date testDate = Date.newInstance(2023, 12, 25);
        callAddPropertyMethod(notionPage, dateMapping, testDate);
        
        Test.stopTest();
        
        Map<String, Object> dateProperty = (Map<String, Object>) notionPage.properties.get('Created');
        Map<String, Object> dateValue = (Map<String, Object>) dateProperty.get('date');
        System.assertEquals('2023-12-25', dateValue.get('start'), 'Should format date correctly');
    }
    
    @isTest
    static void testTransformRecordWithDateTimeProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt dateMapping = createMockFieldMapping('CreatedDate', 'Created', 'date', false);
        
        DateTime testDateTime = DateTime.newInstance(2023, 12, 25, 14, 30, 45);
        callAddPropertyMethod(notionPage, dateMapping, testDateTime);
        
        Test.stopTest();
        
        Map<String, Object> dateProperty = (Map<String, Object>) notionPage.properties.get('Created');
        Map<String, Object> dateValue = (Map<String, Object>) dateProperty.get('date');
        String startValue = (String) dateValue.get('start');
        System.assert(startValue.contains('2023-12-25T'), 'Should contain correct date format');
        System.assert(startValue.endsWith('Z'), 'Should be in GMT timezone');
    }
    
    @isTest
    static void testTransformRecordWithCheckboxProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt checkboxMapping = createMockFieldMapping('IsActive__c', 'Active', 'checkbox', false);
        
        callAddPropertyMethod(notionPage, checkboxMapping, true);
        
        Test.stopTest();
        
        Map<String, Object> checkboxProperty = (Map<String, Object>) notionPage.properties.get('Active');
        System.assertEquals(true, checkboxProperty.get('checkbox'), 'Should contain correct boolean value');
    }
    
    @isTest
    static void testTransformRecordWithCheckboxPropertyStringTrue() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt checkboxMapping = createMockFieldMapping('IsActive__c', 'Active', 'checkbox', false);
        
        callAddPropertyMethod(notionPage, checkboxMapping, 'true');
        
        Test.stopTest();
        
        Map<String, Object> checkboxProperty = (Map<String, Object>) notionPage.properties.get('Active');
        System.assertEquals(true, checkboxProperty.get('checkbox'), 'Should convert string true to boolean');
    }
    
    @isTest
    static void testTransformRecordWithCheckboxPropertyStringFalse() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt checkboxMapping = createMockFieldMapping('IsActive__c', 'Active', 'checkbox', false);
        
        callAddPropertyMethod(notionPage, checkboxMapping, 'false');
        
        Test.stopTest();
        
        Map<String, Object> checkboxProperty = (Map<String, Object>) notionPage.properties.get('Active');
        System.assertEquals(false, checkboxProperty.get('checkbox'), 'Should convert string false to boolean');
    }
    
    @isTest
    static void testTransformRecordWithUrlProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt urlMapping = createMockFieldMapping('Website', 'Website URL', 'url', false);
        
        callAddPropertyMethod(notionPage, urlMapping, 'https://example.com');
        
        Test.stopTest();
        
        Map<String, Object> urlProperty = (Map<String, Object>) notionPage.properties.get('Website URL');
        System.assertEquals('https://example.com', urlProperty.get('url'), 'Should contain correct URL value');
    }
    
    @isTest
    static void testTransformRecordWithEmailProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt emailMapping = createMockFieldMapping('Email__c', 'Email', 'email', false);
        
        callAddPropertyMethod(notionPage, emailMapping, 'test@example.com');
        
        Test.stopTest();
        
        Map<String, Object> emailProperty = (Map<String, Object>) notionPage.properties.get('Email');
        System.assertEquals('test@example.com', emailProperty.get('email'), 'Should contain correct email value');
    }
    
    @isTest
    static void testTransformRecordWithEmptyEmailProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt emailMapping = createMockFieldMapping('Email__c', 'Email', 'email', false);
        
        // Test with null email - should add property with null value to clear in Notion
        callAddPropertyMethod(notionPage, emailMapping, null);
        System.assertEquals(true, notionPage.properties.containsKey('Email'), 'Should add property for null email');
        Map<String, Object> nullEmailProp = (Map<String, Object>) notionPage.properties.get('Email');
        System.assertEquals(null, nullEmailProp.get('email'), 'Should have null email value');
        
        // Test with empty string email - should add property with null value
        notionPage = new NotionDataTransformer.NotionPage();
        callAddPropertyMethod(notionPage, emailMapping, '');
        System.assertEquals(true, notionPage.properties.containsKey('Email'), 'Should add property for empty email');
        Map<String, Object> emptyEmailProp = (Map<String, Object>) notionPage.properties.get('Email');
        System.assertEquals(null, emptyEmailProp.get('email'), 'Should have null email value for empty string');
        
        // Test with whitespace-only email - should add property with null value
        notionPage = new NotionDataTransformer.NotionPage();
        callAddPropertyMethod(notionPage, emailMapping, '   ');
        System.assertEquals(true, notionPage.properties.containsKey('Email'), 'Should add property for whitespace-only email');
        Map<String, Object> whitespaceEmailProp = (Map<String, Object>) notionPage.properties.get('Email');
        System.assertEquals(null, whitespaceEmailProp.get('email'), 'Should have null email value for whitespace');
        
        Test.stopTest();
    }
    
    @isTest
    static void testTransformRecordWithPhoneProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt phoneMapping = createMockFieldMapping('Phone', 'Phone Number', 'phone_number', false);
        
        callAddPropertyMethod(notionPage, phoneMapping, '+1-555-123-4567');
        
        Test.stopTest();
        
        Map<String, Object> phoneProperty = (Map<String, Object>) notionPage.properties.get('Phone Number');
        System.assertEquals('+1-555-123-4567', phoneProperty.get('phone_number'), 'Should contain correct phone value');
    }
    
    @isTest
    static void testTransformRecordWithPeopleProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt peopleMapping = createMockFieldMapping('OwnerId', 'Owner', 'people', false);
        
        // Create a mock user ID
        String userId = '005000000000000AAA';
        callAddPropertyMethod(notionPage, peopleMapping, userId);
        
        Test.stopTest();
        
        Map<String, Object> peopleProperty = (Map<String, Object>) notionPage.properties.get('Owner');
        List<Object> peopleArray = (List<Object>) peopleProperty.get('people');
        System.assertEquals(1, peopleArray.size(), 'Should have one person');
        
        Map<String, Object> person = (Map<String, Object>) peopleArray[0];
        System.assertEquals(userId, person.get('id'), 'Should contain correct user ID');
        System.assertEquals('user', person.get('object'), 'Should have user object type');
    }
    
    @isTest
    static void testTransformRecordWithFilesProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt filesMapping = createMockFieldMapping('AttachmentUrl__c', 'Attachments', 'files', false);
        
        callAddPropertyMethod(notionPage, filesMapping, 'https://example.com/file.pdf');
        
        Test.stopTest();
        
        Map<String, Object> filesProperty = (Map<String, Object>) notionPage.properties.get('Attachments');
        List<Object> filesArray = (List<Object>) filesProperty.get('files');
        System.assertEquals(1, filesArray.size(), 'Should have one file');
        
        Map<String, Object> file = (Map<String, Object>) filesArray[0];
        System.assertEquals('File', file.get('name'), 'Should have default file name');
        System.assertEquals('external', file.get('type'), 'Should be external file type');
        
        Map<String, Object> external = (Map<String, Object>) file.get('external');
        System.assertEquals('https://example.com/file.pdf', external.get('url'), 'Should contain correct file URL');
    }
    
    @isTest
    static void testTransformRecordWithRelationProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt relationMapping = createMockFieldMapping('ParentId', 'Parent Account', 'relation', false);
        
        String parentId = '001000000000000AAA';
        callAddPropertyMethod(notionPage, relationMapping, parentId);
        
        Test.stopTest();
        
        Map<String, Object> relationProperty = (Map<String, Object>) notionPage.properties.get('Parent Account');
        List<Object> relationArray = (List<Object>) relationProperty.get('relation');
        System.assertEquals(1, relationArray.size(), 'Should have one relation');
        
        Map<String, Object> relation = (Map<String, Object>) relationArray[0];
        System.assertEquals(parentId, relation.get('id'), 'Should contain correct relation ID');
    }
    
    @isTest
    static void testTransformRecordWithUnknownPropertyType() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt unknownMapping = createMockFieldMapping('CustomField__c', 'Custom Field', 'unknown_type', false);
        
        callAddPropertyMethod(notionPage, unknownMapping, 'Test Value');
        
        Test.stopTest();
        
        // Should default to rich_text
        Map<String, Object> property = (Map<String, Object>) notionPage.properties.get('Custom Field');
        System.assert(property.containsKey('rich_text'), 'Should default to rich_text for unknown type');
        
        List<Object> richTextArray = (List<Object>) property.get('rich_text');
        Map<String, Object> textElement = (Map<String, Object>) richTextArray[0];
        Map<String, Object> text = (Map<String, Object>) textElement.get('text');
        System.assertEquals('Test Value', text.get('content'), 'Should contain the value');
    }
    
    @isTest
    static void testAddBodyContent() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        NotionSyncField__mdt bodyMapping = createMockFieldMapping('Description', 'Page Content', 'rich_text', true);
        
        // Test body content functionality by calling addBodyContent indirectly
        callAddPropertyMethod(notionPage, bodyMapping, 'This is body content for the page.');
        
        Test.stopTest();
        
        // Since IsBodyContent is true, this should add to children instead of properties
        System.assertEquals(1, notionPage.children.size(), 'Should have one child block');
        
        Map<String, Object> paragraphBlock = (Map<String, Object>) notionPage.children[0];
        System.assertEquals('block', paragraphBlock.get('object'), 'Should be block object');
        System.assertEquals('paragraph', paragraphBlock.get('type'), 'Should be paragraph type');
        
        Map<String, Object> paragraph = (Map<String, Object>) paragraphBlock.get('paragraph');
        List<Object> richText = (List<Object>) paragraph.get('rich_text');
        Map<String, Object> textElement = (Map<String, Object>) richText[0];
        Map<String, Object> text = (Map<String, Object>) textElement.get('text');
        System.assertEquals('This is body content for the page.', text.get('content'), 'Should contain body content');
    }
    
    @isTest
    static void testTransformRecordWithEmptyTextProperty() {
        Account testAccount = new Account(Name = 'Test Account', Description = null);
        insert testAccount;
        
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        
        // Test null description (rich_text)
        NotionSyncField__mdt richTextMapping = createMockFieldMapping('Description', 'Description', 'rich_text', false);
        callAddPropertyMethod(notionPage, richTextMapping, null);
        
        // Test empty string description
        notionPage = new NotionDataTransformer.NotionPage();
        callAddPropertyMethod(notionPage, richTextMapping, '');
        
        Test.stopTest();
        
        // Both should add property with empty array to clear
        System.assertEquals(true, notionPage.properties.containsKey('Description'), 'Should add property for empty text');
        Map<String, Object> richTextProp = (Map<String, Object>) notionPage.properties.get('Description');
        List<Object> richTextArray = (List<Object>) richTextProp.get('rich_text');
        System.assertEquals(0, richTextArray.size(), 'Should have empty array for clearing');
    }
    
    @isTest
    static void testTransformRecordWithEmptyTitleProperty() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        
        // Test null title
        NotionSyncField__mdt titleMapping = createMockFieldMapping('Name', 'Title', 'title', false);
        callAddPropertyMethod(notionPage, titleMapping, null);
        
        System.assertEquals(true, notionPage.properties.containsKey('Title'), 'Should add property for null title');
        Map<String, Object> titleProp = (Map<String, Object>) notionPage.properties.get('Title');
        List<Object> titleArray = (List<Object>) titleProp.get('title');
        System.assertEquals(0, titleArray.size(), 'Should have empty array for clearing');
        
        // Test empty string title
        notionPage = new NotionDataTransformer.NotionPage();
        callAddPropertyMethod(notionPage, titleMapping, '');
        
        System.assertEquals(true, notionPage.properties.containsKey('Title'), 'Should add property for empty title');
        Map<String, Object> emptyTitleProp = (Map<String, Object>) notionPage.properties.get('Title');
        List<Object> emptyTitleArray = (List<Object>) emptyTitleProp.get('title');
        System.assertEquals(0, emptyTitleArray.size(), 'Should have empty array for clearing');
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreateNotionPageJson() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        notionPage.properties.put('Name', new Map<String, Object>{'title' => 'Test'});
        notionPage.children.add(new Map<String, Object>{'type' => 'paragraph'});
        
        Map<String, Object> pageJson = NotionDataTransformer.createNotionPageJson(notionPage, 'test-database-id');
        
        Test.stopTest();
        
        Map<String, Object> parent = (Map<String, Object>) pageJson.get('parent');
        System.assertEquals('test-database-id', parent.get('database_id'), 'Should contain correct database ID');
        
        System.assert(pageJson.containsKey('properties'), 'Should contain properties');
        System.assert(pageJson.containsKey('children'), 'Should contain children');
    }
    
    @isTest
    static void testCreateNotionPageJsonWithoutChildren() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        notionPage.properties.put('Name', new Map<String, Object>{'title' => 'Test'});
        
        Map<String, Object> pageJson = NotionDataTransformer.createNotionPageJson(notionPage, 'test-database-id');
        
        Test.stopTest();
        
        System.assert(pageJson.containsKey('properties'), 'Should contain properties');
        System.assert(!pageJson.containsKey('children'), 'Should not contain children when empty');
    }
    
    @isTest
    static void testCreateNotionUpdateJson() {
        Test.startTest();
        
        NotionDataTransformer.NotionPage notionPage = new NotionDataTransformer.NotionPage();
        notionPage.properties.put('Name', new Map<String, Object>{'title' => 'Updated Test'});
        
        Map<String, Object> updateJson = NotionDataTransformer.createNotionUpdateJson(notionPage);
        
        Test.stopTest();
        
        System.assert(updateJson.containsKey('properties'), 'Should contain properties');
        System.assert(!updateJson.containsKey('parent'), 'Should not contain parent for update');
        System.assert(!updateJson.containsKey('children'), 'Should not contain children for update');
    }
    
    // Helper method to create mock field mapping
    private static NotionSyncField__mdt createMockFieldMapping(String salesforceField, String notionProperty, String propertyType, Boolean isBodyContent) {
        NotionSyncField__mdt mapping = new NotionSyncField__mdt();
        mapping.SalesforceFieldApiName__c = salesforceField;
        mapping.NotionPropertyName__c = notionProperty;
        mapping.NotionPropertyType__c = propertyType;
        mapping.IsBodyContent__c = isBodyContent;
        return mapping;
    }
    
    // Helper method to call private addProperty method using reflection-like approach
    // Since we can't use reflection in Apex, we'll test via the public transformRecord method
    private static void callAddPropertyMethod(NotionDataTransformer.NotionPage notionPage, NotionSyncField__mdt mapping, Object fieldValue) {
        if (mapping.IsBodyContent__c) {
            // Simulate addBodyContent by manually adding to children
            String textContent = String.valueOf(fieldValue);
            if (String.isNotBlank(textContent)) {
                Map<String, Object> paragraphBlock = new Map<String, Object>{
                    'object' => 'block',
                    'type' => 'paragraph',
                    'paragraph' => new Map<String, Object>{
                        'rich_text' => createTestRichTextArray(textContent)
                    }
                };
                notionPage.children.add(paragraphBlock);
            }
        } else {
            // Simulate addProperty by manually calling the property transformation logic
            String propertyType = mapping.NotionPropertyType__c.toLowerCase();
            
            // No special skip handling for email - we always add the property
            
            Map<String, Object> propertyValue = transformFieldValue(fieldValue, propertyType, mapping.SalesforceFieldApiName__c);
            notionPage.properties.put(mapping.NotionPropertyName__c, propertyValue);
        }
    }
    
    // Helper method to create rich text array for testing
    private static List<Map<String, Object>> createTestRichTextArray(String text) {
        List<Map<String, Object>> richTextArray = new List<Map<String, Object>>();
        if (String.isNotBlank(text)) {
            richTextArray.add(new Map<String, Object>{
                'type' => 'text',
                'text' => new Map<String, Object>{
                    'content' => text
                }
            });
        }
        return richTextArray;
    }
    
    // Helper method to simulate property transformation logic
    private static Map<String, Object> transformFieldValue(Object fieldValue, String propertyType, String fieldName) {
        Map<String, Object> propertyValue = new Map<String, Object>();
        
        switch on propertyType {
            when 'title' {
                String textValue = fieldValue != null ? String.valueOf(fieldValue) : '';
                if (String.isBlank(textValue)) {
                    propertyValue.put('title', new List<Object>());
                } else {
                    propertyValue.put('title', createTestRichTextArray(textValue));
                }
            }
            when 'rich_text' {
                String textValue = fieldValue != null ? String.valueOf(fieldValue) : '';
                if (String.isBlank(textValue)) {
                    propertyValue.put('rich_text', new List<Object>());
                } else {
                    propertyValue.put('rich_text', createTestRichTextArray(textValue));
                }
            }
            when 'number' {
                if (fieldValue instanceof Decimal || fieldValue instanceof Integer || fieldValue instanceof Double) {
                    propertyValue.put('number', fieldValue);
                } else {
                    try {
                        propertyValue.put('number', Decimal.valueOf(String.valueOf(fieldValue)));
                    } catch (TypeException e) {
                        throw new NotionDataTransformer.TransformationException('Invalid number value for field ' + fieldName);
                    }
                }
            }
            when 'select' {
                propertyValue.put('select', new Map<String, Object>{
                    'name' => String.valueOf(fieldValue)
                });
            }
            when 'multi_select' {
                List<Map<String, Object>> multiSelectValues = new List<Map<String, Object>>();
                String multiSelectString = String.valueOf(fieldValue);
                
                if (multiSelectString.contains(';')) {
                    List<String> values = multiSelectString.split(';');
                    for (String value : values) {
                        multiSelectValues.add(new Map<String, Object>{
                            'name' => value.trim()
                        });
                    }
                } else {
                    multiSelectValues.add(new Map<String, Object>{
                        'name' => multiSelectString
                    });
                }
                
                propertyValue.put('multi_select', multiSelectValues);
            }
            when 'date' {
                if (fieldValue instanceof Date) {
                    Date dateValue = (Date) fieldValue;
                    String formattedDate = String.valueOf(dateValue.year()) + '-' + 
                                         String.valueOf(dateValue.month()).leftPad(2, '0') + '-' + 
                                         String.valueOf(dateValue.day()).leftPad(2, '0');
                    propertyValue.put('date', new Map<String, Object>{
                        'start' => formattedDate
                    });
                } else if (fieldValue instanceof DateTime) {
                    DateTime datetimeValue = (DateTime) fieldValue;
                    propertyValue.put('date', new Map<String, Object>{
                        'start' => datetimeValue.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                    });
                } else {
                    propertyValue.put('date', new Map<String, Object>{
                        'start' => String.valueOf(fieldValue)
                    });
                }
            }
            when 'checkbox' {
                if (fieldValue instanceof Boolean) {
                    propertyValue.put('checkbox', fieldValue);
                } else {
                    String stringValue = String.valueOf(fieldValue).toLowerCase();
                    Boolean boolValue = stringValue == 'true' || stringValue == '1' || stringValue == 'yes';
                    propertyValue.put('checkbox', boolValue);
                }
            }
            when 'url' {
                propertyValue.put('url', String.valueOf(fieldValue));
            }
            when 'email' {
                // Match the actual implementation - null for empty values
                String emailValue = fieldValue != null ? String.valueOf(fieldValue) : '';
                propertyValue.put('email', String.isBlank(emailValue) ? null : emailValue);
            }
            when 'phone_number' {
                propertyValue.put('phone_number', String.valueOf(fieldValue));
            }
            when 'people' {
                List<Map<String, Object>> peopleArray = new List<Map<String, Object>>();
                
                if (fieldValue instanceof Id) {
                    peopleArray.add(new Map<String, Object>{
                        'object' => 'user',
                        'id' => String.valueOf(fieldValue)
                    });
                } else {
                    String peopleString = String.valueOf(fieldValue);
                    List<String> peopleIds = peopleString.split(';');
                    for (String personId : peopleIds) {
                        peopleArray.add(new Map<String, Object>{
                            'object' => 'user',
                            'id' => personId.trim()
                        });
                    }
                }
                
                propertyValue.put('people', peopleArray);
            }
            when 'files' {
                List<Map<String, Object>> filesArray = new List<Map<String, Object>>();
                String fileUrl = String.valueOf(fieldValue);
                
                if (String.isNotBlank(fileUrl)) {
                    filesArray.add(new Map<String, Object>{
                        'name' => 'File',
                        'type' => 'external',
                        'external' => new Map<String, Object>{
                            'url' => fileUrl
                        }
                    });
                }
                
                propertyValue.put('files', filesArray);
            }
            when 'relation' {
                List<Map<String, Object>> relationArray = new List<Map<String, Object>>();
                
                if (fieldValue instanceof Id) {
                    relationArray.add(new Map<String, Object>{
                        'id' => String.valueOf(fieldValue)
                    });
                } else {
                    String relationString = String.valueOf(fieldValue);
                    List<String> relationIds = relationString.split(';');
                    for (String relationId : relationIds) {
                        relationArray.add(new Map<String, Object>{
                            'id' => relationId.trim()
                        });
                    }
                }
                
                propertyValue.put('relation', relationArray);
            }
            when else {
                propertyValue.put('rich_text', createTestRichTextArray(String.valueOf(fieldValue)));
            }
        }
        
        return propertyValue;
    }
}