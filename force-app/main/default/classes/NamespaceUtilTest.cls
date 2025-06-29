@isTest
private class NamespaceUtilTest {
    
    @isTest
    static void testGetNamespace() {
        Test.startTest();
        String namespace = NamespaceUtil.getNamespace();
        Test.stopTest();
        
        // In unmanaged context, should return null
        // In managed context, should return the namespace
        System.assert(namespace == null || namespace.length() > 0, 
            'Namespace should be null or a non-empty string');
    }
    
    @isTest
    static void testApplyNamespace() {
        Test.startTest();
        
        // Test with simple name
        String result1 = NamespaceUtil.applyNamespace('TestClass');
        System.assertNotEquals(null, result1, 'Result should not be null');
        System.assert(result1.contains('TestClass'), 'Result should contain original name');
        
        // Test with null
        String result2 = NamespaceUtil.applyNamespace(null);
        System.assertEquals(null, result2, 'Null input should return null');
        
        // Test with empty string
        String result3 = NamespaceUtil.applyNamespace('');
        System.assertEquals('', result3, 'Empty input should return empty string');
        
        // Test with name already containing namespace
        String namespace = NamespaceUtil.getNamespace();
        if (String.isNotBlank(namespace)) {
            String nameWithNamespace = namespace + '__TestClass';
            String result4 = NamespaceUtil.applyNamespace(nameWithNamespace);
            System.assertEquals(nameWithNamespace, result4, 
                'Should not double-apply namespace');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetMetadataTypeName() {
        Test.startTest();
        
        // Test with base name
        String result1 = NamespaceUtil.getMetadataTypeName('NotionSyncObject');
        System.assert(result1.endsWith('__mdt'), 'Should end with __mdt');
        System.assert(result1.contains('NotionSyncObject'), 'Should contain base name');
        
        // Test with name already ending in __mdt
        String result2 = NamespaceUtil.getMetadataTypeName('NotionSyncObject__mdt');
        System.assertEquals(result1, result2, 'Should handle __mdt suffix correctly');
        
        // Test with null
        String result3 = NamespaceUtil.getMetadataTypeName(null);
        System.assertEquals(null, result3, 'Null input should return null');
        
        // Test with empty string
        String result4 = NamespaceUtil.getMetadataTypeName('');
        System.assertEquals('', result4, 'Empty input should return empty string');
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetFieldName() {
        Test.startTest();
        
        // Test with standard field
        String result1 = NamespaceUtil.getFieldName('ObjectApiName__c');
        System.assert(result1.endsWith('__c'), 'Should end with __c');
        System.assert(result1.contains('ObjectApiName'), 'Should contain field name');
        
        // Test with null
        String result2 = NamespaceUtil.getFieldName(null);
        System.assertEquals(null, result2, 'Null input should return null');
        
        // Test with empty string
        String result3 = NamespaceUtil.getFieldName('');
        System.assertEquals('', result3, 'Empty input should return empty string');
        
        // Test with standard field (still gets __c suffix per current implementation)
        String result4 = NamespaceUtil.getFieldName('Name');
        String expected = NamespaceUtil.hasNamespace() ? 'notionsync__Name__c' : 'Name__c';
        System.assertEquals(expected, result4, 'Field name should have __c suffix with namespace if present');
        
        Test.stopTest();
    }
    
    @isTest
    static void testHasNamespace() {
        Test.startTest();
        Boolean hasNamespace = NamespaceUtil.hasNamespace();
        Test.stopTest();
        
        // Should return true only if namespace is detected
        String namespace = NamespaceUtil.getNamespace();
        System.assertEquals(String.isNotBlank(namespace), hasNamespace, 
            'hasNamespace should match namespace detection');
    }
    
    @isTest
    static void testRemoveNamespace() {
        Test.startTest();
        
        // Test with unmanaged class name
        String result1 = NamespaceUtil.removeNamespace('MyClass');
        System.assertEquals('MyClass', result1, 'Should return unchanged for unmanaged');
        
        // Test with managed class name
        String result2 = NamespaceUtil.removeNamespace('ns__MyClass');
        // Result depends on current namespace
        System.assertNotEquals(null, result2, 'Should handle namespaced name');
        
        // Test with multiple underscores
        String result3 = NamespaceUtil.removeNamespace('ns__My_Complex_Class');
        System.assertNotEquals(null, result3, 'Should handle complex names');
        
        // Test with null
        String result4 = NamespaceUtil.removeNamespace(null);
        System.assertEquals(null, result4, 'Should handle null input');
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetObjectName() {
        Test.startTest();
        
        // Test with base name
        String result1 = NamespaceUtil.getObjectName('Notion_Sync_Log');
        System.assert(result1.endsWith('__c'), 'Should end with __c');
        System.assert(result1.contains('Notion_Sync_Log'), 'Should contain base name');
        
        // Test with name already ending in __c
        String result2 = NamespaceUtil.getObjectName('Notion_Sync_Log__c');
        System.assertEquals(result1, result2, 'Should handle __c suffix correctly');
        
        // Test with null
        String result3 = NamespaceUtil.getObjectName(null);
        System.assertEquals(null, result3, 'Null input should return null');
        
        Test.stopTest();
    }
}