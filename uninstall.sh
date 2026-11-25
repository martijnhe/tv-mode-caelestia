#!/bin/bash
# Remove this plugin: disables it in plugins.json, drops its bar entry / quick toggle from
# shell.json and removes it from ~/.config/caelestia/plugins. Its settings are kept.
set -euo pipefail

src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
conf=${XDG_CONFIG_HOME:-$HOME/.config}/caelestia
name=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["name"])' "$src/manifest.json")
dest=$conf/plugins/$name

python3 - "$src/manifest.json" "$conf" <<'EOF'
import json, sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
conf = Path(sys.argv[2])
plugin_id = f"{manifest.get('author') or 'unknown'}/{manifest['name']}".lower()

plugins_json = conf / "plugins.json"
if plugins_json.exists():
    plugins = json.loads(plugins_json.read_text())
    plugins["enabled"] = [p for p in plugins.get("enabled", []) if p != plugin_id]
    plugins_json.write_text(json.dumps(plugins, indent=4) + "\n")

shell_json = conf / "shell.json"
if shell_json.exists():
    shell = json.loads(shell_json.read_text())
    for ep in manifest.get("entryPoints", []):
        name = ep.get("properties", {}).get("name")
        if ep["type"] == "bar-entry" and shell.get("bar", {}).get("entries"):
            shell["bar"]["entries"] = [e for e in shell["bar"]["entries"] if e.get("id") != name]
        elif ep["type"] == "quick-toggle" and shell.get("utilities", {}).get("quickToggles"):
            shell["utilities"]["quickToggles"] = [t for t in shell["utilities"]["quickToggles"] if t.get("id") != name]
    shell_json.write_text(json.dumps(shell, indent=4) + "\n")

print(f"Disabled {plugin_id}")
EOF

if [[ -L $dest ]]; then
  rm -- "$dest"
elif [[ -f $dest/manifest.json ]]; then
  rm -rf -- "$dest"
fi

echo "Removed $name"
