#!/usr/bin/env bash
# Print what you need for ~/.config/caelestia/tvmode.json: monitor names, the TV's modes and
# the HDMI/DP audio ports with the device name from their EDID. Turn the TV on first.
set -uo pipefail

echo "== Monitors (hyprctl monitors all)"
hyprctl monitors all -j | jq -r '.[] |
  "  \(.name)\t\(if .disabled then "off" else "on  \(.width)x\(.height)@\(.refreshRate | floor) at \(.x)x\(.y)" end)\t\(.description)"'

echo
echo "== Modes per monitor (pick one for tvMode, e.g. 3840x2160@60)"
hyprctl monitors all -j | jq -r '.[] | "  \(.name): \(.availableModes[:6] | map(sub("\\.\\d+Hz$"; "") ) | join("  "))"'

echo
echo "== Audio ports on HDMI/DP (use part of the device name as tvAudioMatch)"
pactl -f json list cards | jq -r '.[] | .name as $card | .ports | to_entries[]
  | select(.key | test("hdmi|displayport|^dp"; "i"))
  | "  \($card)  \(.key)  \(.value.availability)  device=\(.value.properties["device.product.name"] // "-")"'

echo
echo "== Current default sink: $(pactl get-default-sink)"
echo
echo "Ports only show a device name while that screen is on and connected."
echo "If the TV shows 'not available', enable it first:"
echo "  hyprctl eval 'hl.monitor({ output = \"<TV>\", mode = \"preferred\", position = \"auto\" })'   # Lua config (Hyprland 0.5x+)"
echo "  hyprctl keyword monitor \"<TV>,preferred,auto,1\"                                        # hyprland.conf"
