pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import martijnhe.tvmode

// Two actions (TV Mode / Desktop Mode) plus the hardware settings the scripts read.
ColumnLayout {
    id: root

    // qmllint disable missing-property
    readonly property var popoutState: {
        let p = parent;
        while (p && p.popouts === undefined)
            p = p.parent;
        return p?.popouts ?? null;
    }
    // qmllint enable missing-property

    property bool showSettings: false

    width: 320
    implicitWidth: 320
    spacing: Tokens.spacing.small

    function closePopout(): void {
        if (popoutState)
            popoutState.hasCurrent = false;
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.medium
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: TvMode.tvOn ? "tv" : "desktop_windows"
            color: Colours.palette.m3primary
            fill: 1
            fontStyle: Tokens.font.icon.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: qsTr("TV Mode")
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            }

            StyledText {
                Layout.fillWidth: true
                text: TvMode.busy ? qsTr("Switching…") : TvMode.tvOn ? qsTr("On · %1").arg(TvMode.settings.tv) : qsTr("Desktop · %1").arg(TvMode.settings.desktopMonitors.join(", "))
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }

        IconButton {
            icon: "settings"
            type: root.showSettings ? IconButton.Filled : IconButton.Text
            onClicked: root.showSettings = !root.showSettings
        }
    }

    // Actions
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        visible: !root.showSettings
        spacing: Tokens.spacing.small

        IconTextButton {
            Layout.fillWidth: true
            inactiveColour: TvMode.tvOn ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3primaryContainer
            inactiveOnColour: TvMode.tvOn ? Colours.palette.m3onSurface : Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            text: qsTr("TV Mode")
            icon: "tv"
            disabled: !!TvMode.busy
            onClicked: {
                TvMode.setMode("tv");
                root.closePopout();
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            inactiveColour: TvMode.tvOn ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
            inactiveOnColour: TvMode.tvOn ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            verticalPadding: Tokens.padding.extraSmall
            text: qsTr("Desktop Mode")
            icon: "desktop_windows"
            disabled: !!TvMode.busy
            onClicked: {
                TvMode.setMode("desktop");
                root.closePopout();
            }
        }
    }

    // Settings
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.showSettings
        spacing: Tokens.spacing.small

        component Field: StyledTextField {
            Layout.fillWidth: true
            topPadding: Tokens.padding.small + filledOffset
            bottomPadding: Tokens.padding.small + supportingTextOffset - filledOffset
        }

        Field {
            placeholderText: qsTr("Desktop monitors (space separated)")
            text: TvMode.settings.desktopMonitors.join(" ")
            onEditingFinished: TvMode.settings.desktopMonitors = text.split(/[\s,]+/).filter(s => s)
        }

        Field {
            placeholderText: qsTr("TV output")
            text: TvMode.settings.tv
            onEditingFinished: TvMode.settings.tv = text.trim()
        }

        Field {
            placeholderText: qsTr("TV mode, e.g. 3840x2160@60")
            text: TvMode.settings.tvMode
            onEditingFinished: TvMode.settings.tvMode = text.trim()
        }

        Field {
            placeholderText: qsTr("TV audio match (name from EDID)")
            text: TvMode.settings.tvAudioMatch
            onEditingFinished: TvMode.settings.tvAudioMatch = text.trim()
        }

        Field {
            placeholderText: qsTr("Windows to keep open (class regex)")
            text: TvMode.settings.keepClassRegex
            onEditingFinished: TvMode.settings.keepClassRegex = text.trim()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.extraSmall

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Close desktop windows")
            }

            StyledSwitch {
                checked: TvMode.settings.closeWindows
                onToggled: TvMode.settings.closeWindows = checked
            }
        }
    }
}
