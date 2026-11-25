#!/usr/bin/env bash
# Switch to TV mode: only the TV on (no mirroring), audio to the TV, desktop windows closed,
# Steam Big Picture started. Undo with desktop-mode.sh.
set -uo pipefail
. "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/common.sh"

layout_hooked || { log "the Hyprland config doesn't load tvmode-monitors yet, see the README (Setup, step 3)"; exit 1; }

if [[ $(cat "$CACHE/state" 2>/dev/null) != tv ]]; then
  # Remember the desktop audio so desktop mode can put it back
  pactl get-default-sink >"$CACHE/desktop-sink.txt" 2>/dev/null || true
fi

# 1. Screens: TV only
apply_layout tv
for _ in $(seq 1 20); do tv_active && break; sleep 0.5; done
if ! tv_active; then
  # The TV was in standby / on another HDMI input and handed out no EDID: try one more modeset
  sleep 2; hyprctl reload >/dev/null
  for _ in $(seq 1 20); do tv_active && break; sleep 0.5; done
fi
if ! tv_active; then
  log "TV $TV didn't come up; is it on and set to the PC input? Back to the desktop screens."
  apply_layout desktop
  notify "TV not found" "$TV didn't come up. Check the TV is on and set to the PC input."
  exit 1
fi
state tv
[[ $KEEP_AWAKE == true ]] && awake_on

# 2. Audio. HDMI/DP audio is a port on the GPU's audio card, and that card often exposes only one
#    output at a time, so switch the card to the TV's profile instead of just picking a sink.
card="" profile=""
for _ in $(seq 1 20); do
  read -r card profile < <(pactl -f json list cards | jq -r --arg m "$TV_AUDIO_MATCH" '
    first(.[] | .name as $card | .ports | to_entries[]
      | select(.value.availability != "not available")
      | select((.value.properties["device.product.name"] // "") | test($m; "i"))
      | "\($card) \(.value.profiles | map(select(test("stereo"))) | first // .[0])") // empty')
  [[ -n $card ]] && break
  sleep 0.5
done
if [[ -n $card ]]; then
  if [[ ! -f $CACHE/desktop-profile.txt || $(cut -d' ' -f1 "$CACHE/desktop-profile.txt") != "$card" ]]; then
    pactl -f json list cards | jq -r --arg c "$card" '.[] | select(.name == $c) | "\(.name) \(.active_profile)"' >"$CACHE/desktop-profile.txt"
  fi
  pactl set-card-profile "$card" "$profile"
  if sink=$(wait_sink "$card" "$profile"); then
    pactl set-default-sink "$sink"
    move_streams "$sink"
  else
    log "switched $card to $profile but no sink showed up"
  fi
else
  log "no audio port matching '$TV_AUDIO_MATCH'; audio stays where it is"
fi

# 3. Close desktop windows (polite close, so apps can still ask about unsaved work)
if [[ $CLOSE_WINDOWS == true ]]; then
  hyprctl clients -j | jq -r --arg keep "$KEEP_CLASS_REGEX" \
    '.[] | select(.mapped and (.class | test($keep; "i") | not)) | .address' |
  while read -r addr; do
    hyprctl dispatch closewindow "address:$addr" >/dev/null || true
  done
fi

# 4. Steam Big Picture
# A Steam left running inside a gamescope started with other settings (an older version of this
# script, or a TV mode that changed) keeps the old size for games: it is closed and started again.
want=$(steam_command)
gs_pid=$(pgrep -o -x gamescope)
if [[ -n $gs_pid && $want == gamescope* ]] && pgrep -x steam >/dev/null; then
  have=$(tr '\0' ' ' <"/proc/$gs_pid/cmdline" 2>/dev/null); have=${have% }
  if [[ $have != "$want" ]]; then
    log "gamescope runs with other settings ($have); restarting Steam"
    steam -shutdown >/dev/null 2>&1 &
    for _ in $(seq 1 60); do pgrep -x steam >/dev/null || break; sleep 0.5; done
    for _ in $(seq 1 20); do kill -0 "$gs_pid" 2>/dev/null || break; sleep 0.5; done
    kill "$gs_pid" 2>/dev/null || true
  fi
fi
if pgrep -x steam >/dev/null; then
  setsid -f steam steam://open/bigpicture >/dev/null 2>&1
else
  setsid -f sh -c "$want" >/dev/null 2>&1
fi
[[ $want == gamescope* ]] && fullscreen_gamescope

log "TV mode on"
