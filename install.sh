#!/bin/bash
# Install this plugin with the Caelestia shell plugin system (manifest.json).
# Links this folder into ~/.config/caelestia/plugins, enables it in plugins.json and puts
# its bar entry above the clock in shell.json. Safe to re-run; the shell picks it up live.
#   --copy   copy the files instead of linking (otherwise edits here reload live)
set -euo pipefail

src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
conf=${XDG_CONFIG_HOME:-$HOME/.config}/caelestia
name=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["name"])' "$src/manifest.json")
dest=$conf/plugins/$name

mkdir -p -- "$conf/plugins"
if [[ -L $dest ]]; then
  rm -- "$dest"
elif [[ -e $dest ]]; then
  [[ -f $dest/manifest.json ]] || { echo "$dest exists and isn't a plugin, not touching it" >&2; exit 1; }
  rm -rf -- "$dest"
fi
if [[ ${1:-} == --copy ]]; then
  mkdir -p -- "$dest"
  tar -C "$src" --exclude=.git --exclude=.idea -cf - . | tar -C "$dest" -xf -
else
  ln -s -- "$src" "$dest"
fi

python3 - "$src/manifest.json" "$conf" <<'EOF'
import json, sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
conf = Path(sys.argv[2])
plugin_id = f"{manifest.get('author') or 'unknown'}/{manifest['name']}".lower()


def load(path):
    return json.loads(path.read_text()) if path.exists() else {}


# Enable the plugin
plugins_json = conf / "plugins.json"
plugins = load(plugins_json)
enabled = plugins.setdefault("enabled", [])
if plugin_id not in enabled:
    enabled.append(plugin_id)
plugins.setdefault("path", [])
plugins.setdefault("settings", {})
plugins_json.write_text(json.dumps(plugins, indent=4) + "\n")

# Bar entries go above the clock, quick toggles at the end
DEFAULT_ENTRIES = ["logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "clock", "statusIcons", "power"]
shell_json = conf / "shell.json"
shell = load(shell_json)
changed = False
for ep in manifest.get("entryPoints", []):
    props = ep.get("properties", {})
    if ep["type"] == "bar-entry":
        bar = shell.setdefault("bar", {})
        entries = bar.get("entries") or [{"id": i, "enabled": True} for i in DEFAULT_ENTRIES]
        hit = [e for e in entries if e.get("id") == props["name"]]
        if not hit:
            ids = [e.get("id") for e in entries]
            entries.insert(ids.index("clock") if "clock" in ids else len(entries), {"id": props["name"], "enabled": True})
        for e in hit:
            e["enabled"] = True
        bar["entries"] = entries
        changed = True
    elif ep["type"] == "quick-toggle":
        toggles = shell.setdefault("utilities", {}).setdefault("quickToggles", [])
        if not any(t.get("id") == props["name"] for t in toggles):
            toggles.append({"id": props["name"], "enabled": True})
            changed = True
if changed:
    shell_json.write_text(json.dumps(shell, indent=4) + "\n")

print(f"Enabled {plugin_id}")
EOF

echo "Installed $name to $dest"
