import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import martijnhe.tvmode

// Bar entry: TV icon in its own pill. Hover opens the popout, middle click toggles straight away.
StyledRect {
    id: root

    color: TvMode.tvOn ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: icon.implicitHeight + Tokens.padding.medium * 2

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        text: TvMode.busy ? "sync" : TvMode.tvOn ? "tv" : "desktop_windows"
        color: TvMode.tvOn ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3secondary
        fill: TvMode.tvOn ? 1 : 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: TvMode.toggle()
    }
}
