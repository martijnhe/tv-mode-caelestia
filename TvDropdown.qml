pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Label on the left, a dropdown button with the current value on the right
RowLayout {
    id: dropdown

    required property string label
    property string subtext
    property string icon
    property list<string> options
    property var optionLabel: v => v
    property var buttonText: optionLabel // text on the button itself, defaults to the menu label
    property string current
    property alias menuOnTop: button.menuOnTop

    signal picked(value: string)

    Layout.fillWidth: true
    Layout.rightMargin: Tokens.padding.extraSmall
    spacing: Tokens.spacing.medium
    z: button.expanded ? 1 : 0

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: dropdown.label
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: text
            text: dropdown.subtext
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }

    Variants {
        id: items

        model: dropdown.options

        MenuItem {
            required property string modelData

            value: modelData
            text: dropdown.optionLabel(modelData)
            activeText: dropdown.buttonText(modelData)
            icon: modelData === dropdown.current ? "check" : ""
            activeIcon: dropdown.icon
        }
    }

    SplitButton {
        id: button

        Layout.maximumWidth: 170
        type: SplitButton.Tonal
        menuItems: items.instances
        active: items.instances.find(i => i.value === dropdown.current) ?? null
        fallbackIcon: dropdown.icon
        fallbackText: dropdown.current || qsTr("Pick…")
        stateLayer.onClicked: button.expanded = !button.expanded
        menu.onItemSelected: item => dropdown.picked(item.value)
    }
}
