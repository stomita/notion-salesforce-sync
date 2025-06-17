public class NotionDataTransformer {
    
    // Property type constants
    private static final String PROPERTY_TYPE_TITLE = 'title';
    private static final String PROPERTY_TYPE_RICH_TEXT = 'rich_text';
    private static final String PROPERTY_TYPE_NUMBER = 'number';
    private static final String PROPERTY_TYPE_SELECT = 'select';
    private static final String PROPERTY_TYPE_MULTI_SELECT = 'multi_select';
    private static final String PROPERTY_TYPE_DATE = 'date';
    private static final String PROPERTY_TYPE_CHECKBOX = 'checkbox';
    private static final String PROPERTY_TYPE_URL = 'url';
    private static final String PROPERTY_TYPE_EMAIL = 'email';
    private static final String PROPERTY_TYPE_PHONE_NUMBER = 'phone_number';
    private static final String PROPERTY_TYPE_PEOPLE = 'people';
    private static final String PROPERTY_TYPE_FILES = 'files';
    private static final String PROPERTY_TYPE_RELATION = 'relation';
    
    public class NotionPage {
        public Map<String, Object> properties { get; set; }
        public List<Map<String, Object>> children { get; set; }
        
        public NotionPage() {
            this.properties = new Map<String, Object>();
            this.children = new List<Map<String, Object>>();
        }
    }
    
    public class TransformationException extends Exception {}
    
    public static NotionPage transformRecord(SObject record, String objectApiName) {
        System.debug('NotionDataTransformer: Starting transformation for object: ' + objectApiName + ', record ID: ' + record.Id);
        NotionPage notionPage = new NotionPage();
        
        try {
            List<NotionSyncField__mdt> fieldMappings = [
                SELECT Id, SalesforceFieldApiName__c, NotionPropertyName__c, 
                       NotionPropertyType__c, IsBodyContent__c
                FROM NotionSyncField__mdt
                WHERE NotionSyncObject__r.ObjectApiName__c = :objectApiName
                AND NotionSyncObject__r.IsActive__c = true
            ];
            
            if (fieldMappings.isEmpty()) {
                throw new TransformationException('No field mappings found for object: ' + objectApiName);
            }
            
            System.debug('NotionDataTransformer: Found ' + fieldMappings.size() + ' field mappings');
            
            for (NotionSyncField__mdt mapping : fieldMappings) {
                Object fieldValue = record.get(mapping.SalesforceFieldApiName__c);
                
                // For properties that support clearing, we need to process null values
                String propertyType = mapping.NotionPropertyType__c.toLowerCase();
                Boolean supportsClearing = propertyType == 'title' || 
                                         propertyType == 'rich_text' || 
                                         propertyType == 'number' ||
                                         propertyType == 'select' ||
                                         propertyType == 'date' ||
                                         propertyType == 'email';
                
                if (fieldValue == null && !supportsClearing) {
                    continue;
                }
                
                if (mapping.IsBodyContent__c) {
                    addBodyContent(notionPage, fieldValue);
                } else {
                    addProperty(notionPage, mapping, fieldValue);
                }
            }
            
        } catch (Exception e) {
            System.debug('NotionDataTransformer: Error during transformation: ' + e.getMessage());
            throw new TransformationException('Error transforming record: ' + e.getMessage());
        }
        
        System.debug('NotionDataTransformer: Transformation completed successfully with ' + notionPage.properties.size() + ' properties and ' + notionPage.children.size() + ' children');
        return notionPage;
    }
    
    private static void addProperty(NotionPage notionPage, NotionSyncField__mdt mapping, Object fieldValue) {
        String propertyType = mapping.NotionPropertyType__c.toLowerCase();
        System.debug('NotionDataTransformer: Adding property ' + mapping.NotionPropertyName__c + ' of type ' + propertyType + ' for field ' + mapping.SalesforceFieldApiName__c);
        Map<String, Object> propertyValue = new Map<String, Object>();
        
        Boolean shouldAddProperty = true;
        
        switch on propertyType {
            when 'title' {
                String textValue = fieldValue != null ? String.valueOf(fieldValue) : '';
                if (String.isBlank(textValue)) {
                    // Return empty array to clear the property
                    propertyValue.put(PROPERTY_TYPE_TITLE, new List<Object>());
                } else {
                    propertyValue.put(PROPERTY_TYPE_TITLE, createRichTextArray(textValue));
                }
            }
            when 'rich_text' {
                String textValue = fieldValue != null ? String.valueOf(fieldValue) : '';
                if (String.isBlank(textValue)) {
                    // Return empty array to clear the property
                    propertyValue.put(PROPERTY_TYPE_RICH_TEXT, new List<Object>());
                } else {
                    propertyValue.put(PROPERTY_TYPE_RICH_TEXT, createRichTextArray(textValue));
                }
            }
            when 'number' {
                if (fieldValue == null) {
                    // Send null to clear number property
                    propertyValue.put(PROPERTY_TYPE_NUMBER, null);
                } else if (fieldValue instanceof Decimal || fieldValue instanceof Integer || fieldValue instanceof Double) {
                    propertyValue.put(PROPERTY_TYPE_NUMBER, fieldValue);
                } else {
                    try {
                        propertyValue.put(PROPERTY_TYPE_NUMBER, Decimal.valueOf(String.valueOf(fieldValue)));
                    } catch (TypeException e) {
                        throw new TransformationException('Invalid number value for field ' + mapping.SalesforceFieldApiName__c);
                    }
                }
            }
            when 'select' {
                if (fieldValue == null || String.isBlank(String.valueOf(fieldValue))) {
                    // Send null to clear select property
                    propertyValue.put(PROPERTY_TYPE_SELECT, null);
                } else {
                    propertyValue.put(PROPERTY_TYPE_SELECT, new Map<String, Object>{
                        'name' => String.valueOf(fieldValue)
                    });
                }
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
                
                propertyValue.put(PROPERTY_TYPE_MULTI_SELECT, multiSelectValues);
            }
            when 'date' {
                if (fieldValue == null) {
                    // Send null to clear date property
                    propertyValue.put(PROPERTY_TYPE_DATE, null);
                } else if (fieldValue instanceof Date) {
                    Date dateValue = (Date) fieldValue;
                    String formattedDate = String.valueOf(dateValue.year()) + '-' + 
                                         String.valueOf(dateValue.month()).leftPad(2, '0') + '-' + 
                                         String.valueOf(dateValue.day()).leftPad(2, '0');
                    propertyValue.put(PROPERTY_TYPE_DATE, new Map<String, Object>{
                        'start' => formattedDate
                    });
                } else if (fieldValue instanceof DateTime) {
                    DateTime datetimeValue = (DateTime) fieldValue;
                    propertyValue.put(PROPERTY_TYPE_DATE, new Map<String, Object>{
                        'start' => datetimeValue.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                    });
                } else {
                    propertyValue.put(PROPERTY_TYPE_DATE, new Map<String, Object>{
                        'start' => String.valueOf(fieldValue)
                    });
                }
            }
            when 'checkbox' {
                if (fieldValue instanceof Boolean) {
                    propertyValue.put(PROPERTY_TYPE_CHECKBOX, fieldValue);
                } else {
                    String stringValue = String.valueOf(fieldValue).toLowerCase();
                    Boolean boolValue = stringValue == 'true' || stringValue == '1' || stringValue == 'yes';
                    propertyValue.put(PROPERTY_TYPE_CHECKBOX, boolValue);
                }
            }
            when 'url' {
                propertyValue.put(PROPERTY_TYPE_URL, String.valueOf(fieldValue));
            }
            when 'email' {
                // Always include email property - Notion accepts null to clear
                String emailValue = fieldValue != null ? String.valueOf(fieldValue) : '';
                propertyValue.put(PROPERTY_TYPE_EMAIL, String.isBlank(emailValue) ? null : emailValue);
            }
            when 'phone_number' {
                propertyValue.put(PROPERTY_TYPE_PHONE_NUMBER, String.valueOf(fieldValue));
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
                
                propertyValue.put(PROPERTY_TYPE_PEOPLE, peopleArray);
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
                
                propertyValue.put(PROPERTY_TYPE_FILES, filesArray);
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
                
                propertyValue.put(PROPERTY_TYPE_RELATION, relationArray);
            }
            when else {
                propertyValue.put(PROPERTY_TYPE_RICH_TEXT, createRichTextArray(String.valueOf(fieldValue)));
            }
        }
        
        if (shouldAddProperty) {
            notionPage.properties.put(mapping.NotionPropertyName__c, propertyValue);
        }
    }
    
    private static void addBodyContent(NotionPage notionPage, Object fieldValue) {
        String textContent = String.valueOf(fieldValue);
        
        if (String.isNotBlank(textContent)) {
            Map<String, Object> paragraphBlock = new Map<String, Object>{
                'object' => 'block',
                'type' => 'paragraph',
                'paragraph' => new Map<String, Object>{
                    'rich_text' => createRichTextArray(textContent)
                }
            };
            
            notionPage.children.add(paragraphBlock);
        }
    }
    
    private static List<Map<String, Object>> createRichTextArray(String text) {
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
    
    public static Map<String, Object> createNotionPageJson(NotionPage notionPage, String databaseId) {
        Map<String, Object> pageJson = new Map<String, Object>{
            'parent' => new Map<String, Object>{
                'database_id' => databaseId
            },
            'properties' => notionPage.properties
        };
        
        if (!notionPage.children.isEmpty()) {
            pageJson.put('children', notionPage.children);
        }
        
        return pageJson;
    }
    
    public static Map<String, Object> createNotionUpdateJson(NotionPage notionPage) {
        Map<String, Object> updateJson = new Map<String, Object>{
            'properties' => notionPage.properties
        };
        
        return updateJson;
    }
}