// Copyright (c) 2017 Ultimaker B.V.
// Cura is released under the terms of the LGPLv3 or higher.
// Copyright (c) 2020 fieldOfView
// The MaterialSettingsPlugin is released under the terms of the AGPLv3 or higher.

import QtQuick 2.7
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.1
import QtQuick.Dialogs 1.2

import UM 1.2 as UM
import Cura 1.0 as Cura
import MaterialSettingsPlugin 1.0 as MaterialSettingsPlugin

TabView
{
    id: base

    property QtObject properties
    property var currentMaterialNode: null

    property bool editingEnabled: false
    property string currency: UM.Preferences.getValue("cura/currency") ? UM.Preferences.getValue("cura/currency") : "€"
    property real firstColumnWidth: (width * 0.50) | 0
    property real secondColumnWidth: (width * 0.40) | 0
    property string containerId: ""
    property var materialPreferenceValues: UM.Preferences.getValue("cura/material_settings") ? JSON.parse(UM.Preferences.getValue("cura/material_settings")) : {}
    property var materialManagementModel:
    {
        if(CuraApplication.getMaterialManagementModel)
        {
            return CuraApplication.getMaterialManagementModel()
        }
        else
        {
            return CuraApplication.getMaterialManager()
        }
    }

    property double spoolLength: calculateSpoolLength()
    property real costPerMeter: calculateCostPerMeter()

    signal resetSelectedMaterial()

    property bool reevaluateLinkedMaterials: false
    property string linkedMaterialNames:
    {
        if (reevaluateLinkedMaterials)
        {
            reevaluateLinkedMaterials = false;
        }
        if (!base.containerId || !base.editingEnabled)
        {
            return ""
        }
        var linkedMaterials = Cura.ContainerManager.getLinkedMaterials(base.currentMaterialNode, true);
        if (linkedMaterials.length == 0)
        {
            return ""
        }
        return linkedMaterials.join(", ");
    }

    function getApproximateDiameter(diameter)
    {
        return Math.round(diameter);
    }

    // This trick makes sure to make all fields lose focus so their onEditingFinished will be triggered
    // and modified values will be saved. This can happen when a user changes a value and then closes the
    // dialog directly.
    //
    // Please note that somehow this callback is ONLY triggered when visible is false.
    onVisibleChanged:
    {
        if (!visible)
        {
            base.focus = false;
        }
    }

    Tab
    {
        title: catalog.i18nc("@title", "Information")

        anchors.margins: UM.Theme.getSize("default_margin").width

        ScrollView
        {
            id: scrollView
            anchors.fill: parent
            horizontalScrollBarPolicy: Qt.ScrollBarAlwaysOff
            flickableItem.flickableDirection: Flickable.VerticalFlick
            frameVisible: true

            property real columnWidth: (viewport.width * 0.5 - UM.Theme.getSize("default_margin").width) | 0

            Flow
            {
                id: containerGrid

                x: UM.Theme.getSize("default_margin").width
                y: UM.Theme.getSize("default_lining").height

                width: base.width
                property real rowHeight: brandTextField.height + UM.Theme.getSize("default_lining").height

                MessageDialog
                {
                    id: confirmDiameterChangeDialog

                    icon: StandardIcon.Question;
                    title: catalog.i18nc("@title:window", "Confirm Diameter Change")
                    text: catalog.i18nc("@label (%1 is a number)", "The new filament diameter is set to %1 mm, which is not compatible with the current extruder. Do you wish to continue?".arg(new_diameter_value))
                    standardButtons: StandardButton.Yes | StandardButton.No
                    modality: Qt.ApplicationModal

                    property var new_diameter_value: null;
                    property var old_diameter_value: null;
                    property var old_approximate_diameter_value: null;

                    onYes:
                    {
                        base.setContainerPropertyValue("material_diameter", properties.diameter, new_diameter_value);
                        base.setMetaDataEntry("approximate_diameter", old_approximate_diameter_value, getApproximateDiameter(new_diameter_value).toString());
                        base.setMetaDataEntry("properties/diameter", properties.diameter, new_diameter_value);
                        // CURA-6868 Make sure to update the extruder to user a diameter-compatible material.
                        Cura.MachineManager.updateMaterialWithVariant()
                        base.resetSelectedMaterial()
                    }

                    onNo:
                    {
                        base.properties.diameter = old_diameter_value;
                        diameterSpinBox.value = Qt.binding(function() { return base.properties.diameter })
                    }

                    onRejected: no()
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Display Name") }
                Cura.ReadOnlyTextField
                {
                    id: displayNameTextField;
                    width: scrollView.columnWidth;
                    text: properties.name;
                    readOnly: !base.editingEnabled;
                    onEditingFinished: base.updateMaterialDisplayName(properties.name, text)
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Brand") }
                Cura.ReadOnlyTextField
                {
                    id: brandTextField;
                    width: scrollView.columnWidth;
                    text: properties.brand;
                    readOnly: !base.editingEnabled;
                    onEditingFinished: base.updateMaterialBrand(properties.brand, text)
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Material Type") }
                Cura.ReadOnlyTextField
                {
                    id: materialTypeField;
                    width: scrollView.columnWidth;
                    text: properties.material;
                    readOnly: !base.editingEnabled;
                    onEditingFinished: base.updateMaterialType(properties.material, text)
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Color") }
                Row
                {
                    width: scrollView.columnWidth
                    height:  parent.rowHeight
                    spacing: Math.round(UM.Theme.getSize("default_margin").width / 2)

                    // color indicator square
                    Rectangle
                    {
                        id: colorSelector
                        color: properties.color_code

                        width: Math.round(colorLabel.height * 0.75)
                        height: Math.round(colorLabel.height * 0.75)
                        border.width: UM.Theme.getSize("default_lining").height

                        anchors.verticalCenter: parent.verticalCenter

                        // open the color selection dialog on click
                        MouseArea
                        {
                            anchors.fill: parent
                            onClicked: colorDialog.open()
                            enabled: base.editingEnabled
                        }
                    }

                    // pretty color name text field
                    Cura.ReadOnlyTextField
                    {
                        id: colorLabel;
                        width: parent.width - colorSelector.width - parent.spacing
                        text: properties.color_name;
                        readOnly: !base.editingEnabled
                        onEditingFinished: base.setMetaDataEntry("color_name", properties.color_name, text)
                    }

                    // popup dialog to select a new color
                    // if successful it sets the properties.color_code value to the new color
                    ColorDialog
                    {
                        id: colorDialog
                        color: properties.color_code
                        onAccepted: base.setMetaDataEntry("color_code", properties.color_code, color)
                    }
                }

                Item { width: parent.width; height: UM.Theme.getSize("default_margin").height }

                Label { width: parent.width; height: parent.rowHeight; font.bold: true; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Properties") }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Density") }
                Cura.ReadOnlySpinBox
                {
                    id: densitySpinBox
                    width: scrollView.columnWidth
                    value: properties.density
                    decimals: 2
                    suffix: " g/cm³"
                    stepSize: 0.01
                    readOnly: !base.editingEnabled

                    onEditingFinished: base.setMetaDataEntry("properties/density", properties.density, value)
                    onValueChanged: updateCostPerMeter()
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Diameter") }
                Cura.ReadOnlySpinBox
                {
                    id: diameterSpinBox
                    width: scrollView.columnWidth
                    value: properties.diameter
                    decimals: 2
                    suffix: " mm"
                    stepSize: 0.01
                    readOnly: !base.editingEnabled

                    onEditingFinished:
                    {
                        // This does not use a SettingPropertyProvider, because we need to make the change to all containers
                        // which derive from the same base_file
                        var old_diameter = Cura.ContainerManager.getContainerMetaDataEntry(base.containerId, "properties/diameter");
                        var old_approximate_diameter = Cura.ContainerManager.getContainerMetaDataEntry(base.containerId, "approximate_diameter");
                        var new_approximate_diameter = getApproximateDiameter(value);
                        if (new_approximate_diameter != Cura.ExtruderManager.getActiveExtruderStack().approximateMaterialDiameter)
                        {
                            confirmDiameterChangeDialog.old_diameter_value = old_diameter;
                            confirmDiameterChangeDialog.new_diameter_value = value;
                            confirmDiameterChangeDialog.old_approximate_diameter_value = old_approximate_diameter;

                            confirmDiameterChangeDialog.open()
                        }
                        else {
                            base.setContainerPropertyValue("material_diameter", properties.diameter, value);
                            base.setMetaDataEntry("approximate_diameter", old_approximate_diameter, getApproximateDiameter(value).toString());
                            base.setMetaDataEntry("properties/diameter", properties.diameter, value);
                        }
                    }
                    onValueChanged: updateCostPerMeter()
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Filament Cost") }
                SpinBox
                {
                    id: spoolCostSpinBox
                    width: scrollView.columnWidth
                    value: base.getMaterialPreferenceValue(properties.guid, "spool_cost")
                    prefix: base.currency + " "
                    decimals: 2
                    maximumValue: 100000000

                    onValueChanged:
                    {
                        base.setMaterialPreferenceValue(properties.guid, "spool_cost", parseFloat(value))
                        updateCostPerMeter()
                    }
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Filament weight") }
                SpinBox
                {
                    id: spoolWeightSpinBox
                    width: scrollView.columnWidth
                    value: base.getMaterialPreferenceValue(properties.guid, "spool_weight", Cura.ContainerManager.getContainerMetaDataEntry(properties.container_id, "properties/weight"))
                    suffix: " g"
                    stepSize: 100
                    decimals: 0
                    maximumValue: 10000

                    onValueChanged:
                    {
                        base.setMaterialPreferenceValue(properties.guid, "spool_weight", parseFloat(value))
                        updateCostPerMeter()
                    }
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Filament length") }
                Label
                {
                    width: scrollView.columnWidth
                    text: "~ %1 m".arg(Math.round(base.spoolLength))
                    verticalAlignment: Qt.AlignVCenter
                    height: parent.rowHeight
                }

                Label { width: scrollView.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Cost per Meter") }
                Label
                {
                    width: scrollView.columnWidth
                    text: "~ %1 %2/m".arg(base.costPerMeter.toFixed(2)).arg(base.currency)
                    verticalAlignment: Qt.AlignVCenter
                    height: parent.rowHeight
                }

                Item { width: parent.width; height: UM.Theme.getSize("default_margin").height; visible: unlinkMaterialButton.visible }
                Label
                {
                    width: 2 * scrollView.columnWidth
                    verticalAlignment: Qt.AlignVCenter
                    text: catalog.i18nc("@label", "This material is linked to %1 and shares some of its properties.").arg(base.linkedMaterialNames)
                    wrapMode: Text.WordWrap
                    visible: unlinkMaterialButton.visible
                }
                Button
                {
                    id: unlinkMaterialButton
                    text: catalog.i18nc("@label", "Unlink Material")
                    visible: base.linkedMaterialNames != ""
                    onClicked:
                    {
                        Cura.ContainerManager.unlinkMaterial(base.currentMaterialNode)
                        base.reevaluateLinkedMaterials = true
                    }
                }

                Item { width: parent.width; height: UM.Theme.getSize("default_margin").height }

                Label { width: parent.width; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Description") }

                Cura.ReadOnlyTextArea
                {
                    text: properties.description;
                    width: 2 * scrollView.columnWidth
                    wrapMode: Text.WordWrap

                    readOnly: !base.editingEnabled;

                    onEditingFinished: base.setMetaDataEntry("description", properties.description, text)
                }

                Label { width: parent.width; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Adhesion Information") }

                Cura.ReadOnlyTextArea
                {
                    text: properties.adhesion_info;
                    width: 2 * scrollView.columnWidth
                    wrapMode: Text.WordWrap

                    readOnly: !base.editingEnabled;

                    onEditingFinished: base.setMetaDataEntry("adhesion_info", properties.adhesion_info, text)
                }

                Item { width: parent.width; height: UM.Theme.getSize("default_margin").height }
            }

            function updateCostPerMeter()
            {
                base.spoolLength = calculateSpoolLength(diameterSpinBox.value, densitySpinBox.value, spoolWeightSpinBox.value);
                base.costPerMeter = calculateCostPerMeter(spoolCostSpinBox.value);
            }
        }
    }

    Tab
    {
        title: catalog.i18nc("@label", "Print settings")

        Component
        {
            id: settingTextField;

            Cura.SettingTextField { }
        }

        Component
        {
            id: settingComboBox;

            Cura.SettingComboBox { }
        }

        Component
        {
            id: settingExtruder;

            Cura.SettingExtruder { }
        }

        Component
        {
            id: settingCheckBox;

            Cura.SettingCheckBox { }
        }

        Component
        {
            id: settingCategory;

            Cura.SettingCategory { }
        }

        Component
        {
            id: settingUnknown;

            Cura.SettingUnknown { }
        }

        property var customStack: MaterialSettingsPlugin.CustomStack
        {
            containerIds: [Cura.MachineManager.activeMachine.definition.id, Cura.MachineManager.activeStack.variant.id, base.containerId]
        }

        Rectangle
        {
            color:
            {
                if(CuraSDKVersion >= "6.0.0")
                {
                    // version 4.0 and newer
                    return UM.Theme.getColor("main_background")
                }
                else
                {
                    // version 3.6 and before
                    return UM.Theme.getColor("sidebar")
                }
            }

            ScrollView
            {
                id: materialSettingsScrollView
                width: parent.width
                anchors
                {
                    leftMargin: UM.Theme.getSize("default_margin").width
                    top: parent.top
                    topMargin: UM.Theme.getSize("default_margin").height
                    bottom: customiseSettingsButton.top
                    bottomMargin: UM.Theme.getSize("default_margin").height
                }

                horizontalScrollBarPolicy: Qt.ScrollBarAlwaysOff
                flickableItem.flickableDirection: Flickable.VerticalFlick

                ListView
                {
                    id: materialSettingsListView
                    width: parent.width
                    spacing: UM.Theme.getSize("default_lining").height

                    model: UM.SettingDefinitionsModel
                    {
                        id: addedSettingsModel
                        containerId: Cura.MachineManager.activeMachine != null ? Cura.MachineManager.activeMachine.definition.id: ""
                        visibilityHandler: Cura.MaterialSettingsVisibilityHandler { }
                        expanded: ["*"]
                    }

                    delegate: Item
                    {
                        height: childrenRect.height
                        width: parent.width

                        UM.TooltipArea
                        {
                            id: settingArea
                            anchors.left: parent.left
                            anchors.right: removeSettingButton.left
                            height: childrenRect.height
                            text: model.description

                            Loader
                            {
                                id: settingLoader
                                height: UM.Theme.getSize("section").height

                                anchors.left: parent.left
                                anchors.leftMargin: UM.Theme.getSize("default_margin").width
                                anchors.right: parent.right

                                property var definition: model
                                property var settingDefinitionsModel: addedSettingsModel
                                property var propertyProvider: provider
                                property var globalPropertyProvider: inheritStackProvider
                                property var externalResetHandler: resetToDefault

                                function resetToDefault()
                                {
                                    customStack.removeInstanceFromTop(model.key)
                                }

                                Component.onCompleted:
                                {
                                    provider.containerStackId = customStack.stackId
                                }

                                Connections
                                {
                                    target: base
                                    onEditingEnabledChanged:
                                    {
                                        settingLoader.item.enabled = base.editingEnabled;
                                    }
                                }


                                //Qt5.4.2 and earlier has a bug where this causes a crash: https://bugreports.qt.io/browse/QTBUG-35989
                                //In addition, while it works for 5.5 and higher, the ordering of the actual combo box drop down changes,
                                //causing nasty issues when selecting different options. So disable asynchronous loading of enum type completely.
                                asynchronous: model.type != "enum" && model.type != "extruder"

                                onLoaded: {
                                    settingLoader.item.showRevertButton = false
                                    settingLoader.item.showInheritButton = false
                                    settingLoader.item.showLinkedSettingIcon = false
                                    settingLoader.item.doDepthIndentation = false
                                    settingLoader.item.doQualityUserSettingEmphasis = false
                                    settingLoader.item.enabled = base.editingEnabled
                                }

                                sourceComponent:
                                {
                                    switch(model.type)
                                    {
                                        case "int":
                                            return settingTextField
                                        case "[int]":
                                            return settingTextField
                                        case "float":
                                            return settingTextField
                                        case "enum":
                                            return settingComboBox
                                        case "extruder":
                                            return settingExtruder
                                        case "optional_extruder":
                                            return settingOptionalExtruder
                                        case "bool":
                                            return settingCheckBox
                                        case "str":
                                            return settingTextField
                                        case "category":
                                            return settingCategory
                                        default:
                                            return settingUnknown
                                    }
                                }

                                UM.SettingPropertyProvider
                                {
                                    id: provider
                                    containerStackId: "" // to be specified when the component loads
                                    key: model.key
                                    storeIndex: 0
                                    watchedProperties: [ "value", "enabled", "state", "validationState" ]
                                }

                                // Specialty provider that only watches global_inherits (we cant filter on what property changed we get events
                                // so we bypass that to make a dedicated provider).
                                UM.SettingPropertyProvider
                                {
                                    id: inheritStackProvider
                                    containerStackId: Cura.MachineManager.activeMachine.id
                                    key: model.key
                                    watchedProperties: [ "limit_to_extruder" ]
                                }
                            }
                        }

                        Button
                        {
                            id: removeSettingButton
                            width: Math.round(UM.Theme.getSize("setting").height / 2)
                            height: UM.Theme.getSize("setting").height

                            anchors.right: parent.right
                            anchors.rightMargin: UM.Theme.getSize("default_margin").width

                            onClicked: addedSettingsModel.visibilityHandler.setSettingVisibility(model.key, false)

                            style: ButtonStyle
                            {
                                background: Item
                                {
                                    UM.RecolorImage
                                    {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: width
                                        sourceSize.height: width
                                        color: control.hovered ? UM.Theme.getColor("setting_control_button_hover") : UM.Theme.getColor("setting_control_button")
                                        source: UM.Theme.getIcon("minus")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Cura.SecondaryButton
            {
                id: customiseSettingsButton

                anchors
                {
                    left: parent.left
                    leftMargin: UM.Theme.getSize("default_margin").width
                    bottom: parent.bottom
                    bottomMargin: UM.Theme.getSize("default_margin").height
                }

                enabled: base.editingEnabled
                text: catalog.i18nc("@action:button", "Select settings")

                onClicked: settingPickDialog.visible = true
            }
        }
    }

    SettingsDialog { id: settingPickDialog }

    function calculateSpoolLength(diameter, density, spoolWeight)
    {
        if(!diameter)
        {
            diameter = properties.diameter;
        }
        if(!density)
        {
            density = properties.density;
        }
        if(!spoolWeight)
        {
            spoolWeight = base.getMaterialPreferenceValue(properties.guid, "spool_weight", Cura.ContainerManager.getContainerMetaDataEntry(properties.container_id, "properties/weight"));
        }

        if (diameter == 0 || density == 0 || spoolWeight == 0)
        {
            return 0;
        }
        var area = Math.PI * Math.pow(diameter / 2, 2); // in mm2
        var volume = (spoolWeight / density); // in cm3
        return volume / area; // in m
    }

    function calculateCostPerMeter(spoolCost)
    {
        if(!spoolCost)
        {
            spoolCost = base.getMaterialPreferenceValue(properties.guid, "spool_cost");
        }

        if (spoolLength == 0)
        {
            return 0;
        }
        return spoolCost / spoolLength;
    }

    // Tiny convenience function to check if a value really changed before trying to set it.
    function setMetaDataEntry(entry_name, old_value, new_value)
    {
        if (old_value != new_value)
        {
            Cura.ContainerManager.setContainerMetaDataEntry(base.currentMaterialNode, entry_name, new_value)
            // make sure the UI properties are updated as well since we don't re-fetch the entire model here
            // When the entry_name is something like properties/diameter, we take the last part of the entry_name
            var list = entry_name.split("/")
            var key = list[list.length - 1]
            properties[key] = new_value
        }
    }

    property var helper: MaterialSettingsPlugin.Helper{}
    function setContainerPropertyValue(key, old_value, new_value)
    {
        if (old_value == new_value)
        {
            return;
        }
        var base_file = Cura.ContainerManager.getContainerMetaDataEntry(base.containerId, "base_file");
        helper.setMaterialContainersPropertyValue(base_file, key, new_value);
    }

    function setMaterialPreferenceValue(material_guid, entry_name, new_value)
    {
        if(!(material_guid in materialPreferenceValues))
        {
            materialPreferenceValues[material_guid] = {};
        }
        if(entry_name in materialPreferenceValues[material_guid] && materialPreferenceValues[material_guid][entry_name] == new_value)
        {
            // value has not changed
            return;
        }
        if (entry_name in materialPreferenceValues[material_guid] && new_value.toString() == 0)
        {
            // no need to store a 0, that's the default, so remove it
            materialPreferenceValues[material_guid].delete(entry_name);
            if (!(materialPreferenceValues[material_guid]))
            {
                // remove empty map
                materialPreferenceValues.delete(material_guid);
            }
        }
        if (new_value.toString() != 0)
        {
            // store new value
            materialPreferenceValues[material_guid][entry_name] = new_value;
        }

        // store preference
        UM.Preferences.setValue("cura/material_settings", JSON.stringify(materialPreferenceValues));
    }

    function getMaterialPreferenceValue(material_guid, entry_name, default_value)
    {
        if(material_guid in materialPreferenceValues && entry_name in materialPreferenceValues[material_guid])
        {
            return materialPreferenceValues[material_guid][entry_name];
        }
        default_value = default_value | 0;
        return default_value;
    }

    // update the display name of the material
    function updateMaterialDisplayName(old_name, new_name)
    {
        // don't change when new name is the same
        if (old_name == new_name)
        {
            return
        }

        // update the values
        base.materialManagementModel.setMaterialName(base.currentMaterialNode, new_name)
        properties.name = new_name
    }

    // update the type of the material
    function updateMaterialType(old_type, new_type)
    {
        base.setMetaDataEntry("material", old_type, new_type)
        properties.material = new_type
    }

    // update the brand of the material
    function updateMaterialBrand(old_brand, new_brand)
    {
        base.setMetaDataEntry("brand", old_brand, new_brand)
        properties.brand = new_brand
    }
}
