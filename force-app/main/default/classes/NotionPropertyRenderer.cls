/**
 * Transforms Notion property values from API responses to display-ready format for LWC widgets.
 * Handles all Notion property types and generates appropriate display values, URLs, and styling hints.
 */
public class NotionPropertyRenderer {

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
    private static final String PROPERTY_TYPE_FORMULA = 'formula';
    private static final String PROPERTY_TYPE_ROLLUP = 'rollup';
    private static final String PROPERTY_TYPE_STATUS = 'status';
    private static final String PROPERTY_TYPE_CREATED_TIME = 'created_time';
    private static final String PROPERTY_TYPE_LAST_EDITED_TIME = 'last_edited_time';
    private static final String PROPERTY_TYPE_CREATED_BY = 'created_by';
    private static final String PROPERTY_TYPE_LAST_EDITED_BY = 'last_edited_by';

    // Notion color to SLDS color mapping
    private static final Map<String, String> NOTION_COLOR_MAP = new Map<String, String>{
        'default' => 'default',
        'gray' => 'default',
        'brown' => 'warning',
        'orange' => 'warning',
        'yellow' => 'warning',
        'green' => 'success',
        'blue' => 'info',
        'purple' => 'info',
        'pink' => 'error',
        'red' => 'error'
    };

    // Per spec 5.6, multi-value cells (relation / multi_select / people / files) cap
    // at 5 rendered items with a "+N more" indicator for the remainder.
    public static final Integer MAX_MULTI_VALUE_ITEMS = 5;

    /**
     * Rendered value wrapper for LWC consumption
     */
    public class RenderedValue {
        @AuraEnabled public String displayValue { get; set; }
        @AuraEnabled public String rawValue { get; set; }
        @AuraEnabled public String url { get; set; }
        @AuraEnabled public String color { get; set; }
        @AuraEnabled public List<RenderedValue> items { get; set; }
        @AuraEnabled public Boolean boolValue { get; set; }
        @AuraEnabled public Decimal numberValue { get; set; }
        @AuraEnabled public String dateValue { get; set; }
        @AuraEnabled public String propertyType { get; set; }
        // Number of items omitted from `items` due to the multi-value cap.
        @AuraEnabled public Integer moreCount { get; set; }

        public RenderedValue() {
            this.items = new List<RenderedValue>();
            this.moreCount = 0;
        }
    }

    /**
     * Truncates a list to MAX_MULTI_VALUE_ITEMS and records the dropped count.
     * Used by multi-value renderers and external callers (e.g. title bulk fetch).
     */
    public static Integer capMultiValueItems(List<RenderedValue> items) {
        if (items == null || items.size() <= MAX_MULTI_VALUE_ITEMS) {
            return 0;
        }
        Integer drop = items.size() - MAX_MULTI_VALUE_ITEMS;
        for (Integer i = items.size() - 1; i >= MAX_MULTI_VALUE_ITEMS; i--) {
            items.remove(i);
        }
        return drop;
    }

    /**
     * Renders a Notion property value to display-ready format
     * @param propertyValue The raw property value from Notion API
     * @param propertyType The Notion property type
     * @param pageId The page ID (used for generating title links)
     * @return RenderedValue object with display-ready data
     */
    public static RenderedValue renderProperty(Object propertyValue, String propertyType, String pageId) {
        RenderedValue rendered = new RenderedValue();
        rendered.propertyType = propertyType;

        if (propertyValue == null) {
            rendered.displayValue = '';
            return rendered;
        }

        // Cast to Map for object properties
        Map<String, Object> propMap;
        try {
            propMap = (Map<String, Object>) propertyValue;
        } catch (Exception e) {
            rendered.displayValue = String.valueOf(propertyValue);
            return rendered;
        }

        String propType = propertyType != null ? propertyType.toLowerCase() :
                          (String) propMap.get('type');

        switch on propType {
            when 'title' {
                rendered = renderTitle(propMap, pageId);
            }
            when 'rich_text' {
                rendered = renderRichText(propMap);
            }
            when 'number' {
                rendered = renderNumber(propMap);
            }
            when 'select' {
                rendered = renderSelect(propMap);
            }
            when 'multi_select' {
                rendered = renderMultiSelect(propMap);
            }
            when 'date' {
                rendered = renderDate(propMap);
            }
            when 'checkbox' {
                rendered = renderCheckbox(propMap);
            }
            when 'url' {
                rendered = renderUrl(propMap);
            }
            when 'email' {
                rendered = renderEmail(propMap);
            }
            when 'phone_number' {
                rendered = renderPhoneNumber(propMap);
            }
            when 'relation' {
                rendered = renderRelation(propMap);
            }
            when 'people' {
                rendered = renderPeople(propMap);
            }
            when 'files' {
                rendered = renderFiles(propMap);
            }
            when 'formula' {
                rendered = renderFormula(propMap, pageId);
            }
            when 'rollup' {
                rendered = renderRollup(propMap, pageId);
            }
            when 'status' {
                rendered = renderStatus(propMap);
            }
            when 'created_time' {
                rendered = renderCreatedTime(propMap);
            }
            when 'last_edited_time' {
                rendered = renderLastEditedTime(propMap);
            }
            when 'created_by' {
                rendered = renderCreatedBy(propMap);
            }
            when 'last_edited_by' {
                rendered = renderLastEditedBy(propMap);
            }
            when else {
                rendered.displayValue = String.valueOf(propertyValue);
            }
        }

        rendered.propertyType = propType;
        return rendered;
    }

    /**
     * Generates a Notion page URL from a page ID
     */
    public static String getNotionPageUrl(String pageId) {
        if (String.isBlank(pageId)) {
            return null;
        }
        // Remove hyphens from page ID for URL
        String cleanId = pageId.replace('-', '');
        return 'https://www.notion.so/' + cleanId;
    }

    // ==================== Private Render Methods ====================

    private static RenderedValue renderTitle(Map<String, Object> propMap, String pageId) {
        RenderedValue rendered = new RenderedValue();
        List<Object> titleArray = (List<Object>) propMap.get('title');

        if (titleArray != null && !titleArray.isEmpty()) {
            rendered.displayValue = extractPlainText(titleArray);
            rendered.rawValue = rendered.displayValue;
        } else {
            rendered.displayValue = '';
        }

        // Title always links to the page
        if (String.isNotBlank(pageId)) {
            rendered.url = getNotionPageUrl(pageId);
        }

        return rendered;
    }

    private static RenderedValue renderRichText(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        List<Object> richTextArray = (List<Object>) propMap.get('rich_text');

        if (richTextArray != null && !richTextArray.isEmpty()) {
            rendered.displayValue = extractPlainText(richTextArray);
            rendered.rawValue = rendered.displayValue;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderNumber(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        Object numberVal = propMap.get('number');

        if (numberVal != null) {
            rendered.numberValue = (Decimal) numberVal;
            rendered.displayValue = String.valueOf(numberVal);
            rendered.rawValue = rendered.displayValue;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderSelect(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        Map<String, Object> selectVal = (Map<String, Object>) propMap.get('select');

        if (selectVal != null) {
            rendered.displayValue = (String) selectVal.get('name');
            rendered.rawValue = rendered.displayValue;
            String notionColor = (String) selectVal.get('color');
            rendered.color = mapNotionColor(notionColor);
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderMultiSelect(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        List<Object> multiSelectArray = (List<Object>) propMap.get('multi_select');

        if (multiSelectArray != null && !multiSelectArray.isEmpty()) {
            List<String> names = new List<String>();

            for (Object item : multiSelectArray) {
                Map<String, Object> selectItem = (Map<String, Object>) item;
                String name = (String) selectItem.get('name');
                names.add(name);

                RenderedValue itemRendered = new RenderedValue();
                itemRendered.displayValue = name;
                itemRendered.rawValue = name;
                String notionColor = (String) selectItem.get('color');
                itemRendered.color = mapNotionColor(notionColor);
                rendered.items.add(itemRendered);
            }

            rendered.displayValue = String.join(names, ', ');
            rendered.rawValue = String.join(names, ';');
            rendered.moreCount = capMultiValueItems(rendered.items);
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderDate(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        Map<String, Object> dateVal = (Map<String, Object>) propMap.get('date');

        if (dateVal != null) {
            String start = (String) dateVal.get('start');
            String endDate = (String) dateVal.get('end');

            rendered.dateValue = start;
            rendered.rawValue = start;

            if (String.isNotBlank(endDate)) {
                rendered.displayValue = formatDateDisplay(start) + ' - ' + formatDateDisplay(endDate);
            } else {
                rendered.displayValue = formatDateDisplay(start);
            }
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderCheckbox(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        Boolean checkboxVal = (Boolean) propMap.get('checkbox');

        rendered.boolValue = checkboxVal == true;
        rendered.displayValue = rendered.boolValue ? 'Yes' : 'No';
        rendered.rawValue = String.valueOf(rendered.boolValue);

        return rendered;
    }

    private static RenderedValue renderUrl(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        String urlVal = (String) propMap.get('url');

        if (String.isNotBlank(urlVal)) {
            rendered.displayValue = urlVal;
            rendered.rawValue = urlVal;
            rendered.url = urlVal;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderEmail(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        String emailVal = (String) propMap.get('email');

        if (String.isNotBlank(emailVal)) {
            rendered.displayValue = emailVal;
            rendered.rawValue = emailVal;
            rendered.url = 'mailto:' + emailVal;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderPhoneNumber(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        String phoneVal = (String) propMap.get('phone_number');

        if (String.isNotBlank(phoneVal)) {
            rendered.displayValue = phoneVal;
            rendered.rawValue = phoneVal;
            rendered.url = 'tel:' + phoneVal;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderRelation(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        List<Object> relationArray = (List<Object>) propMap.get('relation');

        if (relationArray != null && !relationArray.isEmpty()) {
            List<String> ids = new List<String>();

            for (Object item : relationArray) {
                Map<String, Object> relationItem = (Map<String, Object>) item;
                String relPageId = (String) relationItem.get('id');

                if (String.isNotBlank(relPageId)) {
                    ids.add(relPageId);

                    RenderedValue itemRendered = new RenderedValue();
                    itemRendered.rawValue = relPageId;
                    itemRendered.url = getNotionPageUrl(relPageId);
                    // Initial placeholder; replaced with the actual page title by the
                    // controller's bulk title fetch step. Falls back to truncated ID
                    // if the title cannot be resolved.
                    itemRendered.displayValue = truncatedPageId(relPageId);
                    rendered.items.add(itemRendered);
                }
            }

            // Cap to 5 items + record the overflow count BEFORE the bulk title fetch
            // so we only fetch titles for items we are actually going to render.
            rendered.moreCount = capMultiValueItems(rendered.items);
            rendered.displayValue = ids.size() + ' related page' + (ids.size() > 1 ? 's' : '');
            rendered.rawValue = String.join(ids, ';');
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    public static String truncatedPageId(String pageId) {
        if (String.isBlank(pageId)) {
            return '';
        }
        String clean = pageId.replace('-', '');
        return clean.length() > 8 ? clean.substring(0, 8) + '…' : clean;
    }

    private static RenderedValue renderPeople(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        List<Object> peopleArray = (List<Object>) propMap.get('people');

        if (peopleArray != null && !peopleArray.isEmpty()) {
            List<String> names = new List<String>();

            for (Object item : peopleArray) {
                Map<String, Object> person = (Map<String, Object>) item;
                String name = (String) person.get('name');
                if (String.isBlank(name)) {
                    // Try to get from person object
                    Map<String, Object> personObj = (Map<String, Object>) person.get('person');
                    if (personObj != null) {
                        name = (String) personObj.get('email');
                    }
                }

                if (String.isNotBlank(name)) {
                    names.add(name);

                    RenderedValue itemRendered = new RenderedValue();
                    itemRendered.displayValue = name;
                    itemRendered.rawValue = (String) person.get('id');
                    rendered.items.add(itemRendered);
                }
            }

            rendered.displayValue = String.join(names, ', ');
            rendered.rawValue = rendered.displayValue;
            rendered.moreCount = capMultiValueItems(rendered.items);
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderFiles(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        List<Object> filesArray = (List<Object>) propMap.get('files');

        if (filesArray != null && !filesArray.isEmpty()) {
            List<String> fileNames = new List<String>();

            for (Object item : filesArray) {
                Map<String, Object> file = (Map<String, Object>) item;
                String name = (String) file.get('name');
                String fileType = (String) file.get('type');
                String fileUrl;

                if (fileType == 'external') {
                    Map<String, Object> external = (Map<String, Object>) file.get('external');
                    fileUrl = external != null ? (String) external.get('url') : null;
                } else if (fileType == 'file') {
                    Map<String, Object> fileObj = (Map<String, Object>) file.get('file');
                    fileUrl = fileObj != null ? (String) fileObj.get('url') : null;
                }

                if (String.isNotBlank(name)) {
                    fileNames.add(name);

                    RenderedValue itemRendered = new RenderedValue();
                    itemRendered.displayValue = name;
                    itemRendered.url = fileUrl;
                    rendered.items.add(itemRendered);
                }
            }

            rendered.displayValue = String.join(fileNames, ', ');
            rendered.rawValue = rendered.displayValue;
            rendered.moreCount = capMultiValueItems(rendered.items);
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderFormula(Map<String, Object> propMap, String pageId) {
        RenderedValue rendered = new RenderedValue();
        Map<String, Object> formulaVal = (Map<String, Object>) propMap.get('formula');

        if (formulaVal != null) {
            String formulaType = (String) formulaVal.get('type');

            switch on formulaType {
                when 'string' {
                    rendered.displayValue = (String) formulaVal.get('string');
                }
                when 'number' {
                    Object numVal = formulaVal.get('number');
                    rendered.numberValue = numVal != null ? (Decimal) numVal : null;
                    rendered.displayValue = numVal != null ? String.valueOf(numVal) : '';
                }
                when 'boolean' {
                    rendered.boolValue = (Boolean) formulaVal.get('boolean');
                    rendered.displayValue = rendered.boolValue ? 'Yes' : 'No';
                }
                when 'date' {
                    Map<String, Object> dateVal = (Map<String, Object>) formulaVal.get('date');
                    if (dateVal != null) {
                        String start = (String) dateVal.get('start');
                        rendered.dateValue = start;
                        rendered.displayValue = formatDateDisplay(start);
                    }
                }
                when else {
                    rendered.displayValue = '';
                }
            }
            rendered.rawValue = rendered.displayValue;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderRollup(Map<String, Object> propMap, String pageId) {
        RenderedValue rendered = new RenderedValue();
        Map<String, Object> rollupVal = (Map<String, Object>) propMap.get('rollup');

        if (rollupVal != null) {
            String rollupType = (String) rollupVal.get('type');

            switch on rollupType {
                when 'number' {
                    Object numVal = rollupVal.get('number');
                    rendered.numberValue = numVal != null ? (Decimal) numVal : null;
                    rendered.displayValue = numVal != null ? String.valueOf(numVal) : '';
                }
                when 'date' {
                    Map<String, Object> dateVal = (Map<String, Object>) rollupVal.get('date');
                    if (dateVal != null) {
                        String start = (String) dateVal.get('start');
                        rendered.dateValue = start;
                        rendered.displayValue = formatDateDisplay(start);
                    }
                }
                when 'array' {
                    List<Object> arrayVal = (List<Object>) rollupVal.get('array');
                    if (arrayVal != null) {
                        rendered.displayValue = arrayVal.size() + ' items';
                    }
                }
                when else {
                    rendered.displayValue = '';
                }
            }
            rendered.rawValue = rendered.displayValue;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderStatus(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        Map<String, Object> statusVal = (Map<String, Object>) propMap.get('status');

        if (statusVal != null) {
            rendered.displayValue = (String) statusVal.get('name');
            rendered.rawValue = rendered.displayValue;
            String notionColor = (String) statusVal.get('color');
            rendered.color = mapNotionColor(notionColor);
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderCreatedTime(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        String timeVal = (String) propMap.get('created_time');

        if (String.isNotBlank(timeVal)) {
            rendered.dateValue = timeVal;
            rendered.displayValue = formatDateDisplay(timeVal);
            rendered.rawValue = timeVal;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderLastEditedTime(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        String timeVal = (String) propMap.get('last_edited_time');

        if (String.isNotBlank(timeVal)) {
            rendered.dateValue = timeVal;
            rendered.displayValue = formatDateDisplay(timeVal);
            rendered.rawValue = timeVal;
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderCreatedBy(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        Map<String, Object> userVal = (Map<String, Object>) propMap.get('created_by');

        if (userVal != null) {
            rendered.displayValue = (String) userVal.get('name');
            if (String.isBlank(rendered.displayValue)) {
                // Try email from person object
                Map<String, Object> person = (Map<String, Object>) userVal.get('person');
                if (person != null) {
                    rendered.displayValue = (String) person.get('email');
                }
            }
            rendered.rawValue = (String) userVal.get('id');
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    private static RenderedValue renderLastEditedBy(Map<String, Object> propMap) {
        RenderedValue rendered = new RenderedValue();
        Map<String, Object> userVal = (Map<String, Object>) propMap.get('last_edited_by');

        if (userVal != null) {
            rendered.displayValue = (String) userVal.get('name');
            if (String.isBlank(rendered.displayValue)) {
                // Try email from person object
                Map<String, Object> person = (Map<String, Object>) userVal.get('person');
                if (person != null) {
                    rendered.displayValue = (String) person.get('email');
                }
            }
            rendered.rawValue = (String) userVal.get('id');
        } else {
            rendered.displayValue = '';
        }

        return rendered;
    }

    // ==================== Helper Methods ====================

    private static String extractPlainText(List<Object> richTextArray) {
        if (richTextArray == null || richTextArray.isEmpty()) {
            return '';
        }

        List<String> textParts = new List<String>();
        for (Object item : richTextArray) {
            Map<String, Object> richTextItem = (Map<String, Object>) item;
            String plainText = (String) richTextItem.get('plain_text');
            if (String.isNotBlank(plainText)) {
                textParts.add(plainText);
            }
        }

        return String.join(textParts, '');
    }

    private static String mapNotionColor(String notionColor) {
        if (String.isBlank(notionColor)) {
            return 'default';
        }
        return NOTION_COLOR_MAP.containsKey(notionColor) ?
               NOTION_COLOR_MAP.get(notionColor) : 'default';
    }

    private static String formatDateDisplay(String isoDate) {
        if (String.isBlank(isoDate)) {
            return '';
        }

        try {
            // Handle both date-only and datetime formats
            if (isoDate.contains('T')) {
                // DateTime format: 2024-01-15T10:30:00.000Z
                DateTime dt = (DateTime) JSON.deserialize('"' + isoDate + '"', DateTime.class);
                return dt.format('MMM d, yyyy h:mm a');
            } else {
                // Date-only format: 2024-01-15
                List<String> parts = isoDate.split('-');
                if (parts.size() == 3) {
                    Date d = Date.newInstance(
                        Integer.valueOf(parts[0]),
                        Integer.valueOf(parts[1]),
                        Integer.valueOf(parts[2])
                    );
                    DateTime dt = DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
                    return dt.format('MMM d, yyyy');
                }
            }
        } catch (Exception e) {
            // If parsing fails, return the original
            System.debug('Date parsing failed for: ' + isoDate + ', error: ' + e.getMessage());
        }

        return isoDate;
    }
}
