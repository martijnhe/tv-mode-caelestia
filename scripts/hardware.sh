#!/usr/bin/env bash
# Two JSON lines for the settings dropdowns:
#   1. every output (on or off): [{ name, description, modes: ["3840x2160@60", ...] }]
#   2. device names on HDMI/DP audio ports (from EDID; only while that screen is on)
set -uo pipefail

hyprctl monitors all -j 2>/dev/null | jq -c '[.[] | { name, description,
  modes: (reduce (.availableModes[] | sub("\\.\\d+Hz$"; "") | sub("Hz$"; "")) as $m
    ([]; if any(.[]; . == $m) then . else . + [$m] end)) }]' || echo '[]'

pactl -f json list cards 2>/dev/null | jq -c '[.[] | .ports | to_entries[]
  | select(.key | test("hdmi|displayport|^dp"; "i"))
  | .value.properties["device.product.name"] // empty] | unique' || echo '[]'
