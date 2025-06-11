public class NotionDataTransformer {
    
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
            
            for (NotionSyncField__mdt mapping : fieldMappings) {
                Object fieldValue = record.get(mapping.SalesforceFieldApiName__c);
                
                if (fieldValue == null) {
                    continue;
                }
                
                if (mapping.IsBodyContent__c) {
                    addBodyContent(notionPage, fieldValue);
                } else {
                    addProperty(notionPage, mapping, fieldValue);
                }
            }
            
        } catch (Exception e) {
            throw new TransformationException('Error transforming record: ' + e.getMessage());
        }
        
        return notionPage;
    }
    
    private static void addProperty(NotionPage notionPage, NotionSyncField__mdt mapping, Object fieldValue) {
        String propertyType = mapping.NotionPropertyType__c.toLowerCase();
        Map<String, Object> propertyValue = new Map<String, Object>();
        
        switch on propertyType {
            when 'title' {
                propertyValue.put('title', createRichTextArray(String.valueOf(fieldValue)));
            }
            when 'rich_text' {
                propertyValue.put('rich_text', createRichTextArray(String.valueOf(fieldValue)));
            }
            when 'number' {
                if (fieldValue instanceof Decimal || fieldValue instanceof Integer || fieldValue instanceof Double) {
                    propertyValue.put('number', fieldValue);
                } else {
                    try {
                        propertyValue.put('number', Decimal.valueOf(String.valueOf(fieldValue)));
                    } catch (TypeException e) {
                        throw new TransformationException('Invalid number value for field ' + mapping.SalesforceFieldApiName__c);
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
                    propertyValue.put('date', new Map<String, Object>{
                        'start' => dateValue.format()
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
                propertyValue.put('email', String.valueOf(fieldValue));
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
                propertyValue.put('rich_text', createRichTextArray(String.valueOf(fieldValue)));
            }
        }
        
        notionPage.properties.put(mapping.NotionPropertyName__c, propertyValue);
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