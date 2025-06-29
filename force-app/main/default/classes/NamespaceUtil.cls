/**
 * Utility class for handling namespace-aware operations in both packaged and unpackaged environments.
 * This is essential for 2GP (Second-Generation Package) compatibility.
 */
public with sharing class NamespaceUtil {
    private static String cachedNamespace = null;
    private static Boolean namespaceDetected = false;
    
    /**
     * Gets the current namespace by examining the class name.
     * Returns null if no namespace is present.
     */
    public static String getNamespace() {
        if (!namespaceDetected) {
            String className = NamespaceUtil.class.getName();
            
            // If the class name contains a dot, it has a namespace
            if (className.contains('.')) {
                cachedNamespace = className.substringBefore('.');
            } else {
                cachedNamespace = null;
            }
            
            namespaceDetected = true;
        }
        
        return cachedNamespace;
    }
    
    /**
     * Prefixes a custom object or custom metadata type name with the namespace if present.
     * @param apiName The API name without namespace (e.g., 'NotionSyncObject__mdt')
     * @return The properly namespaced API name
     */
    public static String applyNamespace(String apiName) {
        if (String.isBlank(apiName)) {
            return apiName;
        }
        
        String namespace = getNamespace();
        if (String.isNotBlank(namespace)) {
            // Check if already namespaced
            if (!apiName.startsWith(namespace + '__')) {
                return namespace + '__' + apiName;
            }
        }
        
        return apiName;
    }
    
    /**
     * Removes the namespace prefix from an API name if present.
     * @param apiName The API name that might have a namespace
     * @return The API name without namespace
     */
    public static String removeNamespace(String apiName) {
        if (String.isBlank(apiName)) {
            return apiName;
        }
        
        String namespace = getNamespace();
        if (String.isNotBlank(namespace) && apiName.startsWith(namespace + '__')) {
            return apiName.substring(namespace.length() + 2);
        }
        
        return apiName;
    }
    
    /**
     * Checks if the current environment has a namespace (is packaged).
     * @return True if running in a namespaced environment
     */
    public static Boolean hasNamespace() {
        return String.isNotBlank(getNamespace());
    }
    
    /**
     * Gets the properly namespaced name for a custom metadata type.
     * @param baseName The base metadata type name (e.g., 'NotionSyncObject')
     * @return The fully qualified metadata type name with namespace if applicable
     */
    public static String getMetadataTypeName(String baseName) {
        if (String.isBlank(baseName)) {
            return baseName;
        }
        
        // Remove __mdt suffix if present
        if (baseName.endsWith('__mdt')) {
            baseName = baseName.substring(0, baseName.length() - 5);
        }
        
        // Apply namespace and add __mdt suffix
        return applyNamespace(baseName + '__mdt');
    }
    
    /**
     * Gets the properly namespaced name for a custom object.
     * @param baseName The base object name (e.g., 'Notion_Sync_Log')
     * @return The fully qualified object name with namespace if applicable
     */
    public static String getObjectName(String baseName) {
        if (String.isBlank(baseName)) {
            return baseName;
        }
        
        // Remove __c suffix if present
        if (baseName.endsWith('__c')) {
            baseName = baseName.substring(0, baseName.length() - 3);
        }
        
        // Apply namespace and add __c suffix
        return applyNamespace(baseName + '__c');
    }
    
    /**
     * Gets the properly namespaced name for a custom field.
     * @param baseName The base field name (e.g., 'IsActive')
     * @return The fully qualified field name with namespace if applicable
     */
    public static String getFieldName(String baseName) {
        if (String.isBlank(baseName)) {
            return baseName;
        }
        
        // Remove __c suffix if present
        if (baseName.endsWith('__c')) {
            baseName = baseName.substring(0, baseName.length() - 3);
        }
        
        // Apply namespace and add __c suffix
        return applyNamespace(baseName + '__c');
    }
}