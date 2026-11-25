pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia

// TV mode state and actions. The real work is in scripts/tv-mode.sh and
// scripts/desktop-mode.sh, which also run fine from a terminal; this only calls them.
// Settings are shared with the scripts through ~/.config/caelestia/tvmode.json.
Singleton {
    id: root

    // Through the plugin link (install.sh), so this works both as a manifest plugin and patched into the shell
    readonly property string scriptDir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/caelestia/plugins/tvmode/scripts`
    readonly property string cacheDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/tv-mode`

    property string mode: "desktop" // desktop | tv
    readonly property bool tvOn: mode === "tv"
    property string busy: "" // "tv" | "desktop" while a script runs
    property alias settings: settingsAdapter

    function setMode(target: string): void {
        if (busy)
            return;
        busy = target;
        runner.output = "";
        runner.command = [`${scriptDir}/${target === "tv" ? "tv-mode.sh" : "desktop-mode.sh"}`];
        runner.running = true;
    }

    function toggle(): void {
        setMode(tvOn ? "desktop" : "tv");
    }

    // Hardware lists for the settings dropdowns: every output (on or off) with its modes,
    // and the device names on the HDMI/DP audio ports (from EDID, only while that screen is on).
    property var outputs: [] // [{ name, description, modes: ["3840x2160@60", ...] }]
    property list<string> audioNames: []

    function refreshHardware(): void {
        hardware.running = true;
    }

    function modesOf(output: string): list<string> {
        const o = outputs.find(m => m.name === output);
        return o ? o.modes : [];
    }

    Process {
        id: hardware

        command: [`${root.scriptDir}/hardware.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                try {
                    root.outputs = JSON.parse(lines[0] || "[]");
                } catch (e) {
                    root.outputs = [];
                }
                try {
                    root.audioNames = JSON.parse(lines[1] || "[]");
                } catch (e) {
                    root.audioNames = [];
                }
            }
        }
    }

    Process {
        id: runner

        property string output

        stderr: SplitParser {
            onRead: line => runner.output = line
        }
        onExited: code => {
            const target = root.busy;
            root.busy = "";
            stateFile.reload();
            if (code !== 0)
                Toaster.toast(qsTr("TV Mode"), runner.output.replace(/^\[tv-mode\] /, "") || qsTr("Switching failed"), "tv_off", Toast.Error);
            else
                Toaster.toast(qsTr("TV Mode"), target === "tv" ? qsTr("TV mode on") : qsTr("Back to desktop"), target === "tv" ? "tv" : "desktop_windows", Toast.Info);
        }
    }

    FileView {
        id: stateFile

        path: `${root.cacheDir}/state`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.mode = text().trim() === "tv" ? "tv" : "desktop"
    }

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/caelestia/tvmode.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settingsAdapter

            property list<string> desktopMonitors: ["DP-1", "DP-3"]
            property string tv: "HDMI-A-1"
            property string tvMode: "3840x2160@60"
            property real tvScale: 1
            property string tvAudioMatch: "SAMSUNG"
            property bool closeWindows: true
            property string keepClassRegex: "caelestia|quickshell|steam"
            property bool tvInDesktop: false
            property string steamCommand: "steam -gamepadui"
        }
    }
}
