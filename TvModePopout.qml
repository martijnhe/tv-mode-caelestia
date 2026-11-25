pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
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
    readonly property var settings: TvMode.settings

    width: 340
    implicitWidth: 340
    spacing: Tokens.spacing.small

    Component.onCompleted: TvMode.refreshHardware()
    onShowSettingsChanged: if (showSettings) TvMode.refreshHardware()

    function closePopout(): void {
        if (popoutState)
            popoutState.hasCurrent = false;
    }

    function outputLabel(name: string): string {
        const o = TvMode.outputs.find(m => m.name === name);
        const desc = o?.description?.replace(/\s+\S*\d\S*$/, "") ?? ""; // drop the serial number
        return desc ? `${name} · ${desc}` : name;
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
                text: TvMode.busy ? qsTr("Switching…") : TvMode.tvOn ? qsTr("On · %1").arg(root.settings.tv) : qsTr("Desktop · %1").arg(root.settings.desktopMonitors.join(", "))
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
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
    StyledFlickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(settingsColumn.implicitHeight, 380)
        visible: root.showSettings
        contentHeight: settingsColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: settingsColumn

            width: parent.width
            spacing: Tokens.spacing.small

            TvSection {
                text: qsTr("TV")
            }

            TvDropdown {
                label: qsTr("Output")
                icon: "tv"
                options: TvMode.outputs.map(m => m.name)
                optionLabel: name => root.outputLabel(name)
                buttonText: name => name
                current: root.settings.tv
                onPicked: value => {
                    root.settings.tv = value;
                    root.settings.desktopMonitors = root.settings.desktopMonitors.filter(m => m !== value);
                }
            }

            TvDropdown {
                label: qsTr("Resolution")
                icon: "aspect_ratio"
                options: ["preferred", ...TvMode.modesOf(root.settings.tv).slice(0, 12)]
                current: root.settings.tvMode
                onPicked: value => root.settings.tvMode = value
            }

            TvDropdown {
                label: qsTr("Scale")
                icon: "zoom_in"
                options: ["1", "1.25", "1.5", "1.75", "2"]
                optionLabel: v => `${v}×`
                current: String(root.settings.tvScale)
                onPicked: value => root.settings.tvScale = Number(value)
            }

            TvDropdown {
                label: qsTr("Sound")
                subtext: qsTr("Device name on the HDMI audio port")
                icon: "volume_up"
                options: [...new Set([...TvMode.audioNames, root.settings.tvAudioMatch].filter(s => s && s !== "none")), "none"]
                optionLabel: v => v === "none" ? qsTr("Don't switch audio") : v
                current: root.settings.tvAudioMatch
                onPicked: value => root.settings.tvAudioMatch = value
            }

            TvSection {
                text: qsTr("Turned off in TV mode")
            }

            Repeater {
                model: TvMode.outputs.filter(m => m.name !== root.settings.tv)

                TvToggle {
                    required property var modelData

                    label: root.outputLabel(modelData.name)
                    isOn: root.settings.desktopMonitors.includes(modelData.name)
                    onToggled: value => {
                        const rest = root.settings.desktopMonitors.filter(m => m !== modelData.name);
                        root.settings.desktopMonitors = value ? [...rest, modelData.name] : rest;
                    }
                }
            }

            TvSection {
                text: qsTr("Behaviour")
            }

            TvToggle {
                label: qsTr("Close desktop windows")
                isOn: root.settings.closeWindows
                onToggled: value => root.settings.closeWindows = value
            }

            TvToggle {
                label: qsTr("Keep PC awake in TV mode")
                isOn: root.settings.keepAwake
                onToggled: value => root.settings.keepAwake = value
            }

            TvToggle {
                label: qsTr("Keep TV on in desktop mode")
                isOn: root.settings.tvInDesktop
                onToggled: value => root.settings.tvInDesktop = value
            }

            TvDropdown {
                label: qsTr("Steam")
                icon: "sports_esports"
                options: ["steam -gamepadui", "gamescope -f -- steam -gamepadui", "steam -bigpicture", "true"]
                optionLabel: v => ({
                        "steam -gamepadui": qsTr("Big Picture"),
                        "gamescope -f -- steam -gamepadui": qsTr("Big Picture in gamescope"),
                        "steam -bigpicture": qsTr("Big Picture (old)"),
                        "true": qsTr("Don't start Steam")
                    })[v] ?? v
                current: root.settings.steamCommand
                menuOnTop: true
                onPicked: value => root.settings.steamCommand = value
            }
        }
    }
}
