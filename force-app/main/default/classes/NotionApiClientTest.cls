@isTest
public class NotionApiClientTest {
    
    @isTest
    static void testCreatePageSuccess() {
        Test.setMock(HttpCalloutMock.class, new NotionApiSuccessMock());
        
        Map<String, Object> properties = new Map<String, Object>();
        properties.put('Name', NotionApiClient.buildTitleProperty('Test Page'));
        
        NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
            'test-database-id', 
            properties
        );
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.createPage(pageRequest);
        Test.stopTest();
        
        System.assert(response.success, 'Page creation should succeed');
        System.assertEquals('test-page-id', response.pageId, 'Should return page ID');
        System.assertEquals(200, response.statusCode, 'Should return success status code');
        System.assertNotEquals(null, response.responseBody, 'Should have response body');
    }
    
    @isTest
    static void testCreatePageWithChildren() {
        Test.setMock(HttpCalloutMock.class, new NotionApiSuccessMock());
        
        Map<String, Object> properties = new Map<String, Object>();
        properties.put('Name', NotionApiClient.buildTitleProperty('Test Page'));
        
        List<Object> children = new List<Object>();
        children.add(new Map<String, Object>{
            'object' => 'block',
            'type' => 'paragraph',
            'paragraph' => new Map<String, Object>{
                'rich_text' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'text',
                        'text' => new Map<String, Object>{'content' => 'Test content'}
                    }
                }
            }
        });
        
        NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
            'test-database-id', 
            properties,
            children
        );
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.createPage(pageRequest);
        Test.stopTest();
        
        System.assert(response.success, 'Page creation with children should succeed');
        System.assertEquals('test-page-id', response.pageId, 'Should return page ID');
    }
    
    @isTest
    static void testCreatePageError() {
        Test.setMock(HttpCalloutMock.class, new NotionApiErrorMock());
        
        Map<String, Object> properties = new Map<String, Object>();
        NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
            'invalid-database-id', 
            properties
        );
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.createPage(pageRequest);
        Test.stopTest();
        
        System.assert(!response.success, 'Page creation should fail with invalid data');
        System.assertEquals(400, response.statusCode, 'Should return error status code');
        System.assert(response.errorMessage.contains('Invalid database ID'), 'Should contain error message');
    }
    
    @isTest
    static void testCreatePageException() {
        Test.setMock(HttpCalloutMock.class, new NotionApiExceptionMock());
        
        Map<String, Object> properties = new Map<String, Object>();
        NotionApiClient.NotionPageRequest pageRequest = new NotionApiClient.NotionPageRequest(
            'test-database-id', 
            properties
        );
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.createPage(pageRequest);
        Test.stopTest();
        
        System.assert(!response.success, 'Page creation should fail with exception');
        System.assert(response.errorMessage.contains('Exception during page creation'), 'Should contain exception message');
    }
    
    @isTest
    static void testUpdatePageSuccess() {
        Test.setMock(HttpCalloutMock.class, new NotionApiSuccessMock());
        
        Map<String, Object> properties = new Map<String, Object>();
        properties.put('Name', NotionApiClient.buildTitleProperty('Updated Page'));
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.updatePage('test-page-id', properties);
        Test.stopTest();
        
        System.assert(response.success, 'Page update should succeed');
        System.assertEquals('test-page-id', response.pageId, 'Should return page ID');
        System.assertEquals(200, response.statusCode, 'Should return success status code');
    }
    
    @isTest
    static void testUpdatePageError() {
        Test.setMock(HttpCalloutMock.class, new NotionApiErrorMock());
        
        Map<String, Object> properties = new Map<String, Object>();
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.updatePage('invalid-page-id', properties);
        Test.stopTest();
        
        System.assert(!response.success, 'Page update should fail with invalid page ID');
        System.assertEquals(400, response.statusCode, 'Should return error status code');
    }
    
    @isTest
    static void testDeletePageSuccess() {
        Test.setMock(HttpCalloutMock.class, new NotionApiSuccessMock());
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.deletePage('test-page-id');
        Test.stopTest();
        
        System.assert(response.success, 'Page deletion should succeed');
        System.assertEquals('test-page-id', response.pageId, 'Should return page ID');
        System.assertEquals(200, response.statusCode, 'Should return success status code');
    }
    
    @isTest
    static void testDeletePageError() {
        Test.setMock(HttpCalloutMock.class, new NotionApiErrorMock());
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.deletePage('invalid-page-id');
        Test.stopTest();
        
        System.assert(!response.success, 'Page deletion should fail with invalid page ID');
        System.assertEquals(400, response.statusCode, 'Should return error status code');
    }
    
    @isTest
    static void testQueryDatabaseSuccess() {
        Test.setMock(HttpCalloutMock.class, new NotionApiSuccessMock());
        
        Map<String, Object> filter = new Map<String, Object>{
            'property' => 'Status',
            'select' => new Map<String, Object>{'equals' => 'Active'}
        };
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase('test-database-id', filter);
        Test.stopTest();
        
        System.assert(response.success, 'Database query should succeed');
        System.assertEquals(200, response.statusCode, 'Should return success status code');
    }
    
    @isTest
    static void testQueryDatabaseWithoutFilter() {
        Test.setMock(HttpCalloutMock.class, new NotionApiSuccessMock());
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.queryDatabase('test-database-id', null);
        Test.stopTest();
        
        System.assert(response.success, 'Database query without filter should succeed');
    }
    
    @isTest
    static void testGetPageSuccess() {
        Test.setMock(HttpCalloutMock.class, new NotionApiSuccessMock());
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.getPage('test-page-id');
        Test.stopTest();
        
        System.assert(response.success, 'Get page should succeed');
        System.assertEquals('test-page-id', response.pageId, 'Should return page ID');
        System.assertEquals(200, response.statusCode, 'Should return success status code');
    }
    
    @isTest
    static void testGetPageError() {
        Test.setMock(HttpCalloutMock.class, new NotionApiErrorMock());
        
        Test.startTest();
        NotionApiClient.NotionResponse response = NotionApiClient.getPage('invalid-page-id');
        Test.stopTest();
        
        System.assert(!response.success, 'Get page should fail with invalid page ID');
        System.assertEquals(400, response.statusCode, 'Should return error status code');
    }
    
    @isTest
    static void testBuildTextProperty() {
        Map<String, Object> property = NotionApiClient.buildTextProperty('Test content');
        System.assert(property.containsKey('rich_text'), 'Should contain rich_text key');
        
        List<Object> richText = (List<Object>) property.get('rich_text');
        System.assertEquals(1, richText.size(), 'Should have one rich text element');
        
        Map<String, Object> textElement = (Map<String, Object>) richText[0];
        Map<String, Object> text = (Map<String, Object>) textElement.get('text');
        System.assertEquals('Test content', text.get('content'), 'Should contain correct content');
    }
    
    @isTest
    static void testBuildTextPropertyNull() {
        // Test null value - should return empty array to clear
        Map<String, Object> property = NotionApiClient.buildTextProperty(null);
        List<Object> richText = (List<Object>) property.get('rich_text');
        System.assertEquals(0, richText.size(), 'Should return empty array for null value');
        
        // Test empty string - should return empty array to clear
        Map<String, Object> emptyProperty = NotionApiClient.buildTextProperty('');
        List<Object> emptyRichText = (List<Object>) emptyProperty.get('rich_text');
        System.assertEquals(0, emptyRichText.size(), 'Should return empty array for empty string');
        
        // Test whitespace - should return empty array to clear
        Map<String, Object> whitespaceProperty = NotionApiClient.buildTextProperty('   ');
        List<Object> whitespaceRichText = (List<Object>) whitespaceProperty.get('rich_text');
        System.assertEquals(0, whitespaceRichText.size(), 'Should return empty array for whitespace');
    }
    
    @isTest
    static void testBuildTitleProperty() {
        Map<String, Object> property = NotionApiClient.buildTitleProperty('Test Title');
        System.assert(property.containsKey('title'), 'Should contain title key');
        
        List<Object> title = (List<Object>) property.get('title');
        System.assertEquals(1, title.size(), 'Should have one title element');
        
        Map<String, Object> titleElement = (Map<String, Object>) title[0];
        Map<String, Object> text = (Map<String, Object>) titleElement.get('text');
        System.assertEquals('Test Title', text.get('content'), 'Should contain correct content');
    }
    
    @isTest
    static void testBuildTitlePropertyNull() {
        // Test null value - should return empty array to clear
        Map<String, Object> property = NotionApiClient.buildTitleProperty(null);
        List<Object> title = (List<Object>) property.get('title');
        System.assertEquals(0, title.size(), 'Should return empty array for null value');
        
        // Test empty string - should return empty array to clear
        Map<String, Object> emptyProperty = NotionApiClient.buildTitleProperty('');
        List<Object> emptyTitle = (List<Object>) emptyProperty.get('title');
        System.assertEquals(0, emptyTitle.size(), 'Should return empty array for empty string');
        
        // Test whitespace - should return empty array to clear
        Map<String, Object> whitespaceProperty = NotionApiClient.buildTitleProperty('   ');
        List<Object> whitespaceTitle = (List<Object>) whitespaceProperty.get('title');
        System.assertEquals(0, whitespaceTitle.size(), 'Should return empty array for whitespace');
    }
    
    @isTest
    static void testBuildNumberProperty() {
        Map<String, Object> property = NotionApiClient.buildNumberProperty(42.5);
        System.assertEquals(42.5, property.get('number'), 'Should contain correct number value');
    }
    
    @isTest
    static void testBuildCheckboxProperty() {
        Map<String, Object> propertyTrue = NotionApiClient.buildCheckboxProperty(true);
        System.assertEquals(true, propertyTrue.get('checkbox'), 'Should handle true value');
        
        Map<String, Object> propertyFalse = NotionApiClient.buildCheckboxProperty(false);
        System.assertEquals(false, propertyFalse.get('checkbox'), 'Should handle false value');
        
        Map<String, Object> propertyNull = NotionApiClient.buildCheckboxProperty(null);
        System.assertEquals(false, propertyNull.get('checkbox'), 'Should default to false for null');
    }
    
    @isTest
    static void testBuildDateProperty() {
        Date testDate = Date.newInstance(2023, 12, 25);
        Map<String, Object> property = NotionApiClient.buildDateProperty(testDate);
        
        Map<String, Object> dateObj = (Map<String, Object>) property.get('date');
        System.assertEquals('2023-12-25', dateObj.get('start'), 'Should format date correctly');
    }
    
    @isTest
    static void testBuildDatePropertyNull() {
        Map<String, Object> property = NotionApiClient.buildDateProperty(null);
        System.assertEquals(null, property.get('date'), 'Should handle null date');
    }
    
    @isTest
    static void testBuildDateTimeProperty() {
        DateTime testDateTime = DateTime.newInstance(2023, 12, 25, 14, 30, 45);
        Map<String, Object> property = NotionApiClient.buildDateTimeProperty(testDateTime);
        
        Map<String, Object> dateObj = (Map<String, Object>) property.get('date');
        String startValue = (String) dateObj.get('start');
        System.assert(startValue.contains('2023-12-25T'), 'Should contain correct date format');
        System.assert(startValue.endsWith('Z'), 'Should be in GMT timezone');
    }
    
    @isTest
    static void testBuildDateTimePropertyNull() {
        Map<String, Object> property = NotionApiClient.buildDateTimeProperty(null);
        System.assertEquals(null, property.get('date'), 'Should handle null datetime');
    }
    
    @isTest
    static void testBuildSelectProperty() {
        Map<String, Object> property = NotionApiClient.buildSelectProperty('Option A');
        Map<String, Object> selectMap = (Map<String, Object>) property.get('select');
        System.assertEquals('Option A', selectMap.get('name'), 'Should contain correct option name');
    }
    
    @isTest
    static void testBuildSelectPropertyBlank() {
        Map<String, Object> property = NotionApiClient.buildSelectProperty('');
        System.assertEquals(null, property.get('select'), 'Should handle blank value');
        
        Map<String, Object> propertyNull = NotionApiClient.buildSelectProperty(null);
        System.assertEquals(null, propertyNull.get('select'), 'Should handle null value');
    }
    
    @isTest
    static void testBuildMultiSelectProperty() {
        List<String> values = new List<String>{'Option A', 'Option B', 'Option C'};
        Map<String, Object> property = NotionApiClient.buildMultiSelectProperty(values);
        
        List<Object> multiSelect = (List<Object>) property.get('multi_select');
        System.assertEquals(3, multiSelect.size(), 'Should contain correct number of options');
        
        Map<String, Object> firstOption = (Map<String, Object>) multiSelect[0];
        System.assertEquals('Option A', firstOption.get('name'), 'Should contain first option');
    }
    
    @isTest
    static void testBuildMultiSelectPropertyEmpty() {
        Map<String, Object> property = NotionApiClient.buildMultiSelectProperty(null);
        List<Object> multiSelect = (List<Object>) property.get('multi_select');
        System.assertEquals(0, multiSelect.size(), 'Should handle null list');
        
        Map<String, Object> propertyEmpty = NotionApiClient.buildMultiSelectProperty(new List<String>());
        List<Object> multiSelectEmpty = (List<Object>) propertyEmpty.get('multi_select');
        System.assertEquals(0, multiSelectEmpty.size(), 'Should handle empty list');
    }
    
    @isTest
    static void testBuildRelationProperty() {
        List<String> pageIds = new List<String>{'page-id-1', 'page-id-2'};
        Map<String, Object> property = NotionApiClient.buildRelationProperty(pageIds);
        
        List<Object> relation = (List<Object>) property.get('relation');
        System.assertEquals(2, relation.size(), 'Should contain correct number of relations');
        
        Map<String, Object> firstRelation = (Map<String, Object>) relation[0];
        System.assertEquals('page-id-1', firstRelation.get('id'), 'Should contain first page ID');
    }
    
    @isTest
    static void testBuildEmailProperty() {
        // Test valid email
        Map<String, Object> property = NotionApiClient.buildEmailProperty('test@example.com');
        System.assertEquals('test@example.com', property.get('email'), 'Should contain email value');
        
        // Test empty email - should return property with null value
        Map<String, Object> emptyProperty = NotionApiClient.buildEmailProperty('');
        System.assertNotEquals(null, emptyProperty, 'Should return property for empty email');
        System.assertEquals(null, emptyProperty.get('email'), 'Should have null email value for empty string');
        
        // Test null email - should return property with null value
        Map<String, Object> nullProperty = NotionApiClient.buildEmailProperty(null);
        System.assertNotEquals(null, nullProperty, 'Should return property for null email');
        System.assertEquals(null, nullProperty.get('email'), 'Should have null email value');
    }
    
    @isTest
    static void testBuildRelationPropertyEmpty() {
        Map<String, Object> property = NotionApiClient.buildRelationProperty(null);
        List<Object> relation = (List<Object>) property.get('relation');
        System.assertEquals(0, relation.size(), 'Should handle null list');
        
        Map<String, Object> propertyEmpty = NotionApiClient.buildRelationProperty(new List<String>());
        List<Object> relationEmpty = (List<Object>) propertyEmpty.get('relation');
        System.assertEquals(0, relationEmpty.size(), 'Should handle empty list');
    }
    
    private class NotionApiSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            
            Map<String, Object> responseBody = new Map<String, Object>{
                'id' => 'test-page-id',
                'object' => 'page',
                'created_time' => '2023-01-01T00:00:00.000Z',
                'last_edited_time' => '2023-01-01T00:00:00.000Z'
            };
            
            response.setBody(JSON.serialize(responseBody));
            return response;
        }
    }
    
    private class NotionApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(400);
            response.setHeader('Content-Type', 'application/json');
            
            Map<String, Object> errorResponse = new Map<String, Object>{
                'object' => 'error',
                'status' => 400,
                'code' => 'validation_error',
                'message' => 'Invalid database ID'
            };
            
            response.setBody(JSON.serialize(errorResponse));
            return response;
        }
    }
    
    private class NotionApiExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            throw new CalloutException('Mock callout exception');
        }
    }
}