import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

RowLayout {
    id: toggle

    required property string label
    property bool isOn

    signal toggled(value: bool)

    Layout.fillWidth: true
    Layout.rightMargin: Tokens.padding.extraSmall
    spacing: Tokens.spacing.medium

    StyledText {
        Layout.fillWidth: true
        text: toggle.label
        elide: Text.ElideRight
    }

    StyledSwitch {
        checked: toggle.isOn
        onToggled: {
            toggle.toggled(checked);
            checked = Qt.binding(() => toggle.isOn);
        }
    }
}
