/**
 * Lightning App Builder dynamic pick list for selecting a registered
 * NotionWidget__mdt configuration. Surfaces a dropdown of widget developer
 * names on the Notion Widget component's property panel so admins no longer
 * have to type the developer name by hand.
 */
global class NotionWidgetPicklist extends VisualEditor.DynamicPickList {

    global override VisualEditor.DataRow getDefaultValue() {
        return null;
    }

    global override VisualEditor.DynamicPickListRows getValues() {
        VisualEditor.DynamicPickListRows rows = new VisualEditor.DynamicPickListRows();
        for (NotionWidget__mdt widget : [
            SELECT DeveloperName, MasterLabel, IsActive__c
            FROM NotionWidget__mdt
            ORDER BY MasterLabel ASC
        ]) {
            String label = widget.MasterLabel + ' (' + widget.DeveloperName + ')';
            if (widget.IsActive__c == false) {
                label += ' [Inactive]';
            }
            rows.addRow(new VisualEditor.DataRow(label, widget.DeveloperName));
        }
        return rows;
    }
}
