@IsTest
private class NotionPropertyRendererTest {

    @IsTest
    static void testRenderTitle() {
        Map<String, Object> titleProp = new Map<String, Object>{
            'title' => new List<Object>{
                new Map<String, Object>{
                    'plain_text' => 'Test Page Title'
                }
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            titleProp, 'title', 'abc123-def456'
        );
        Test.stopTest();

        System.assertEquals('Test Page Title', result.displayValue);
        System.assertEquals('title', result.propertyType);
        System.assertNotEquals(null, result.url);
        System.assert(result.url.contains('notion.so'));
    }

    @IsTest
    static void testRenderRichText() {
        Map<String, Object> richTextProp = new Map<String, Object>{
            'rich_text' => new List<Object>{
                new Map<String, Object>{
                    'plain_text' => 'Hello '
                },
                new Map<String, Object>{
                    'plain_text' => 'World'
                }
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            richTextProp, 'rich_text', null
        );
        Test.stopTest();

        System.assertEquals('Hello World', result.displayValue);
    }

    @IsTest
    static void testRenderNumber() {
        Map<String, Object> numberProp = new Map<String, Object>{
            'number' => 42.5
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            numberProp, 'number', null
        );
        Test.stopTest();

        System.assertEquals('42.5', result.displayValue);
        System.assertEquals(42.5, result.numberValue);
    }

    @IsTest
    static void testRenderSelect() {
        Map<String, Object> selectProp = new Map<String, Object>{
            'select' => new Map<String, Object>{
                'name' => 'Option A',
                'color' => 'green'
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            selectProp, 'select', null
        );
        Test.stopTest();

        System.assertEquals('Option A', result.displayValue);
        System.assertEquals('success', result.color);
    }

    @IsTest
    static void testRenderMultiSelect() {
        Map<String, Object> multiSelectProp = new Map<String, Object>{
            'multi_select' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'Tag1',
                    'color' => 'blue'
                },
                new Map<String, Object>{
                    'name' => 'Tag2',
                    'color' => 'red'
                }
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            multiSelectProp, 'multi_select', null
        );
        Test.stopTest();

        System.assertEquals('Tag1, Tag2', result.displayValue);
        System.assertEquals(2, result.items.size());
        System.assertEquals('Tag1', result.items[0].displayValue);
        System.assertEquals('info', result.items[0].color);
    }

    @IsTest
    static void testRenderDate() {
        Map<String, Object> dateProp = new Map<String, Object>{
            'date' => new Map<String, Object>{
                'start' => '2024-01-15'
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            dateProp, 'date', null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.displayValue);
        System.assertEquals('2024-01-15', result.dateValue);
    }

    @IsTest
    static void testRenderDateRange() {
        Map<String, Object> dateProp = new Map<String, Object>{
            'date' => new Map<String, Object>{
                'start' => '2024-01-15',
                'end' => '2024-01-20'
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            dateProp, 'date', null
        );
        Test.stopTest();

        System.assert(result.displayValue.contains('-'));
    }

    @IsTest
    static void testRenderCheckbox() {
        Map<String, Object> checkboxProp = new Map<String, Object>{
            'checkbox' => true
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            checkboxProp, 'checkbox', null
        );
        Test.stopTest();

        System.assertEquals('Yes', result.displayValue);
        System.assertEquals(true, result.boolValue);
    }

    @IsTest
    static void testRenderCheckboxFalse() {
        Map<String, Object> checkboxProp = new Map<String, Object>{
            'checkbox' => false
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            checkboxProp, 'checkbox', null
        );
        Test.stopTest();

        System.assertEquals('No', result.displayValue);
        System.assertEquals(false, result.boolValue);
    }

    @IsTest
    static void testRenderUrl() {
        Map<String, Object> urlProp = new Map<String, Object>{
            'url' => 'https://example.com'
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            urlProp, 'url', null
        );
        Test.stopTest();

        System.assertEquals('https://example.com', result.displayValue);
        System.assertEquals('https://example.com', result.url);
    }

    @IsTest
    static void testRenderEmail() {
        Map<String, Object> emailProp = new Map<String, Object>{
            'email' => 'test@example.com'
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            emailProp, 'email', null
        );
        Test.stopTest();

        System.assertEquals('test@example.com', result.displayValue);
        System.assertEquals('mailto:test@example.com', result.url);
    }

    @IsTest
    static void testRenderPhoneNumber() {
        Map<String, Object> phoneProp = new Map<String, Object>{
            'phone_number' => '+1-555-1234'
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            phoneProp, 'phone_number', null
        );
        Test.stopTest();

        System.assertEquals('+1-555-1234', result.displayValue);
        System.assertEquals('tel:+1-555-1234', result.url);
    }

    @IsTest
    static void testRenderRelation() {
        Map<String, Object> relationProp = new Map<String, Object>{
            'relation' => new List<Object>{
                new Map<String, Object>{
                    'id' => 'page-id-1'
                },
                new Map<String, Object>{
                    'id' => 'page-id-2'
                }
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            relationProp, 'relation', null
        );
        Test.stopTest();

        System.assertEquals('2 related pages', result.displayValue);
        System.assertEquals(2, result.items.size());
        System.assertNotEquals(null, result.items[0].url);
    }

    @IsTest
    static void testRenderStatus() {
        Map<String, Object> statusProp = new Map<String, Object>{
            'status' => new Map<String, Object>{
                'name' => 'In Progress',
                'color' => 'blue'
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            statusProp, 'status', null
        );
        Test.stopTest();

        System.assertEquals('In Progress', result.displayValue);
        System.assertEquals('info', result.color);
    }

    @IsTest
    static void testRenderFormula() {
        Map<String, Object> formulaProp = new Map<String, Object>{
            'formula' => new Map<String, Object>{
                'type' => 'string',
                'string' => 'Calculated Value'
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            formulaProp, 'formula', null
        );
        Test.stopTest();

        System.assertEquals('Calculated Value', result.displayValue);
    }

    @IsTest
    static void testRenderFormulaNumber() {
        Map<String, Object> formulaProp = new Map<String, Object>{
            'formula' => new Map<String, Object>{
                'type' => 'number',
                'number' => 100
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            formulaProp, 'formula', null
        );
        Test.stopTest();

        System.assertEquals('100', result.displayValue);
        System.assertEquals(100, result.numberValue);
    }

    @IsTest
    static void testRenderCreatedTime() {
        Map<String, Object> createdTimeProp = new Map<String, Object>{
            'created_time' => '2024-01-15T10:30:00.000Z'
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            createdTimeProp, 'created_time', null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.displayValue);
        System.assertEquals('2024-01-15T10:30:00.000Z', result.dateValue);
    }

    @IsTest
    static void testRenderCreatedBy() {
        Map<String, Object> createdByProp = new Map<String, Object>{
            'created_by' => new Map<String, Object>{
                'id' => 'user-123',
                'name' => 'John Doe'
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            createdByProp, 'created_by', null
        );
        Test.stopTest();

        System.assertEquals('John Doe', result.displayValue);
        System.assertEquals('user-123', result.rawValue);
    }

    @IsTest
    static void testRenderPeople() {
        Map<String, Object> peopleProp = new Map<String, Object>{
            'people' => new List<Object>{
                new Map<String, Object>{
                    'id' => 'user-1',
                    'name' => 'Alice'
                },
                new Map<String, Object>{
                    'id' => 'user-2',
                    'name' => 'Bob'
                }
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            peopleProp, 'people', null
        );
        Test.stopTest();

        System.assertEquals('Alice, Bob', result.displayValue);
        System.assertEquals(2, result.items.size());
    }

    @IsTest
    static void testRenderFiles() {
        Map<String, Object> filesProp = new Map<String, Object>{
            'files' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'document.pdf',
                    'type' => 'external',
                    'external' => new Map<String, Object>{
                        'url' => 'https://example.com/doc.pdf'
                    }
                }
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            filesProp, 'files', null
        );
        Test.stopTest();

        System.assertEquals('document.pdf', result.displayValue);
        System.assertEquals(1, result.items.size());
        System.assertEquals('https://example.com/doc.pdf', result.items[0].url);
    }

    @IsTest
    static void testRenderNullProperty() {
        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            null, 'title', null
        );
        Test.stopTest();

        System.assertEquals('', result.displayValue);
    }

    @IsTest
    static void testRenderEmptyTitle() {
        Map<String, Object> titleProp = new Map<String, Object>{
            'title' => new List<Object>()
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            titleProp, 'title', null
        );
        Test.stopTest();

        System.assertEquals('', result.displayValue);
    }

    @IsTest
    static void testGetNotionPageUrl() {
        Test.startTest();
        String url = NotionPropertyRenderer.getNotionPageUrl('abc-123-def-456');
        Test.stopTest();

        System.assertEquals('https://www.notion.so/abc123def456', url);
    }

    @IsTest
    static void testGetNotionPageUrlNull() {
        Test.startTest();
        String url = NotionPropertyRenderer.getNotionPageUrl(null);
        Test.stopTest();

        System.assertEquals(null, url);
    }

    @IsTest
    static void testRenderRollup() {
        Map<String, Object> rollupProp = new Map<String, Object>{
            'rollup' => new Map<String, Object>{
                'type' => 'number',
                'number' => 150
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            rollupProp, 'rollup', null
        );
        Test.stopTest();

        System.assertEquals('150', result.displayValue);
        System.assertEquals(150, result.numberValue);
    }

    @IsTest
    static void testRenderLastEditedTime() {
        Map<String, Object> lastEditedProp = new Map<String, Object>{
            'last_edited_time' => '2024-06-20T15:45:00.000Z'
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            lastEditedProp, 'last_edited_time', null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.displayValue);
        System.assertEquals('2024-06-20T15:45:00.000Z', result.dateValue);
    }

    @IsTest
    static void testRenderLastEditedBy() {
        Map<String, Object> lastEditedByProp = new Map<String, Object>{
            'last_edited_by' => new Map<String, Object>{
                'id' => 'user-456',
                'name' => 'Jane Smith'
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue result = NotionPropertyRenderer.renderProperty(
            lastEditedByProp, 'last_edited_by', null
        );
        Test.stopTest();

        System.assertEquals('Jane Smith', result.displayValue);
        System.assertEquals('user-456', result.rawValue);
    }

    @IsTest
    static void testColorMapping() {
        // Test various Notion colors map correctly
        Map<String, Object> greenSelect = new Map<String, Object>{
            'select' => new Map<String, Object>{
                'name' => 'Green',
                'color' => 'green'
            }
        };
        Map<String, Object> redSelect = new Map<String, Object>{
            'select' => new Map<String, Object>{
                'name' => 'Red',
                'color' => 'red'
            }
        };
        Map<String, Object> blueSelect = new Map<String, Object>{
            'select' => new Map<String, Object>{
                'name' => 'Blue',
                'color' => 'blue'
            }
        };

        Test.startTest();
        NotionPropertyRenderer.RenderedValue greenResult = NotionPropertyRenderer.renderProperty(greenSelect, 'select', null);
        NotionPropertyRenderer.RenderedValue redResult = NotionPropertyRenderer.renderProperty(redSelect, 'select', null);
        NotionPropertyRenderer.RenderedValue blueResult = NotionPropertyRenderer.renderProperty(blueSelect, 'select', null);
        Test.stopTest();

        System.assertEquals('success', greenResult.color);
        System.assertEquals('error', redResult.color);
        System.assertEquals('info', blueResult.color);
    }
}
