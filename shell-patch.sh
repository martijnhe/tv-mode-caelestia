#!/bin/bash
# Patch TV Mode into a Caelestia shell that has no manifest plugin loader (the patched
# ~/.config/quickshell/caelestia used here): service, popout and a "TV" dashboard tab,
# all marked with `// plugin:tvmode` like the other widgets. Safe to re-run.
#   --remove   take it out again
set -euo pipefail

src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
shell=${CAELESTIA_SHELL:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia}
conf=${XDG_CONFIG_HOME:-$HOME/.config}/caelestia

# Scripts are called through ~/.config/caelestia/plugins/tvmode
mkdir -p "$conf/plugins"
[[ -e $conf/plugins/tvmode ]] || ln -s -- "$src" "$conf/plugins/tvmode"

python3 - "$src" "$shell" "$conf" "${1:-}" <<'EOF'
import json, re, sys, shutil, time
from pathlib import Path

src, shell, conf, mode = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
M = "// plugin:tvmode"
content = shell / "modules/dashboard/Content.qml"
service = shell / "services/TvMode.qml"
popout = shell / "modules/bar/popouts/TvModePopout.qml"

text = content.read_text()
text = "\n".join(l for l in text.split("\n") if M not in l)  # drop any earlier patch

if mode == "--remove":
    content.write_text(text)
    service.unlink(missing_ok=True)
    popout.unlink(missing_ok=True)
    print("Removed TV Mode from the shell")
    sys.exit()

tab = f"""        allTabs.push({{ {M}
            component: tvModeTabComponent, {M}
            iconName: "tv", {M}
            text: qsTr("TV"), {M}
            enabled: PluginState.placementOf("tvmode") === "top" {M}
        }}); {M}
"""
comp = f"""            Component {{ {M}
                id: tvModeTabComponent {M}
{M}
                Item {{ {M}
                    implicitWidth: 840 {M}
                    implicitHeight: 480 {M}
{M}
                    TvModePopout {{ {M}
                        anchors.centerIn: parent {M}
                    }} {M}
                }} {M}
            }} {M}
{M}
"""
a = text.index("        return allTabs.filter(tab => tab.enabled);")
text = text[:a] + tab + text[a:]
b = re.search(r"^            Component \{.*\n\s*id: \w+TabComponent", text, re.M).start()
text = text[:b] + comp + text[b:]

backup = content.with_name(f"Content.qml.pre-tvmode-{time.strftime('%Y%m%d%H%M%S')}")
shutil.copy2(content, backup)
content.write_text(text)

service.write_text(f"{M}: TV mode service, from {src}\n" + (src / "TvMode.qml").read_text())
pop = (src / "TvModePopout.qml").read_text().replace("import martijnhe.tvmode\n", "")
popout.write_text(f"{M}: TV mode tab, from {src}\n" + pop)

toggles = conf / "plugin-toggles.json"
t = json.loads(toggles.read_text()) if toggles.exists() else {}
t.setdefault("placement", {}).setdefault("tvmode", "top")
toggles.write_text(json.dumps(t, indent=4) + "\n")
print(f"Patched TV Mode into {shell} (backup: {backup.name})")
EOF
