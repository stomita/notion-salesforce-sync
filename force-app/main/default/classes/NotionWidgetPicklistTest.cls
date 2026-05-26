@IsTest
private class NotionWidgetPicklistTest {

    @IsTest
    static void testGetValuesReturnsRows() {
        Test.startTest();
        NotionWidgetPicklist picklist = new NotionWidgetPicklist();
        VisualEditor.DynamicPickListRows rows = picklist.getValues();
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Picklist should return a non-null rows container');
    }

    @IsTest
    static void testGetDefaultValueIsNull() {
        Test.startTest();
        NotionWidgetPicklist picklist = new NotionWidgetPicklist();
        VisualEditor.DataRow defaultValue = picklist.getDefaultValue();
        Test.stopTest();

        System.assertEquals(null, defaultValue, 'Default value should be null so the admin makes an explicit choice');
    }
}
