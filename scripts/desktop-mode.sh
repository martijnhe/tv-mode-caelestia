#!/usr/bin/env bash
# Back to desktop: close Steam, desktop monitors back, TV off, audio restored.
# Works even when Steam is already closed or tv-mode.sh never finished.
set -uo pipefail
. "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/common.sh"

# 1. Steam out of the way
if pgrep -x steam >/dev/null; then
  steam -shutdown >/dev/null 2>&1 &
  for _ in $(seq 1 20); do pgrep -x steam >/dev/null || break; sleep 0.5; done
fi

# 2. Screens: your normal config layout, TV off (unless tvInDesktop)
apply_layout desktop
state desktop
awake_off

# 3. Audio: card profile first (that brings the monitor's sink back), then the default sink
if [[ -f $CACHE/desktop-profile.txt ]]; then
  read -r card profile <"$CACHE/desktop-profile.txt"
  pactl set-card-profile "$card" "$profile" 2>/dev/null || log "couldn't restore $card to $profile"
  rm -f "$CACHE/desktop-profile.txt"
fi
if [[ -s $CACHE/desktop-sink.txt ]]; then
  sink=$(cat "$CACHE/desktop-sink.txt")
  for _ in $(seq 1 20); do pactl list short sinks | awk '{print $2}' | grep -qx "$sink" && break; sleep 0.5; done
  if pactl set-default-sink "$sink" 2>/dev/null; then
    move_streams "$sink"
  else
    log "desktop sink $sink isn't there; leaving audio on the default"
  fi
fi

log "desktop mode on"
