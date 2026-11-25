# TV Mode for Caelestia

One click to move your [Caelestia](https://github.com/caelestia-dots/shell) / Hyprland desktop to the TV (picture, sound and Steam Big Picture), and one click to go back.

- **TV Mode**: only the TV is on (no mirroring), your desktop monitors turn off, audio moves to the TV, desktop windows close, Steam opens in Big Picture, and the PC stays awake (no lock screen, no screen blanking, no suspend).
- **Desktop Mode**: Steam closes, your monitors come back in their normal layout, the TV's output turns off, and audio goes back to where it was.

The logic is in plain bash scripts in `scripts/`, so you can run and debug them from a terminal. The shell part only calls them.

## Requirements

- Hyprland with `hyprctl`. Both the Lua config (`hyprland.lua`, Hyprland 0.5x+) and the classic `hyprland.conf` work.
- PipeWire (with `pipewire-pulse`) or PulseAudio, with `pactl` 16 or newer (it needs `pactl -f json`)
- `jq`
- Steam (optional: without it, everything except the Big Picture step still works)
- `notify-send` (optional, for an error notification when run from a keybind)

## Setup

### 1. Get the files

```bash
git clone https://github.com/martijnhe/tv-mode-caelestia ~/.local/src/tv-mode-caelestia
cd ~/.local/src/tv-mode-caelestia
```

### 2. Find your screen and audio names

Turn the TV on, set it to the PC's input, and run:

```bash
./scripts/detect.sh
```

It lists:

- **Monitors**: the names of your desktop monitors (for example `DP-1`, `DP-2`) and the TV (for example `HDMI-A-1`)
- **Modes**: the modes the TV supports (for example `3840x2160@60`)
- **Audio ports**: the HDMI/DP audio ports, each with the device name its screen reports (for example `SAMSUNG`, `LG TV`, `SONY TV`). The TV's port only shows a name while the TV is on as a screen. If none show up, enable the TV first with the command `detect.sh` prints at the end.

### 3. Hook the layout file into your Hyprland config

The scripts switch screens by writing a small override file and running `hyprctl reload`. Hyprland has to load that file **after** your own monitor rules, so add one line at the end of your config:

**Lua config** (`~/.config/hypr/hyprland.lua`, or Caelestia's `~/.config/caelestia/hypr-user.lua`):

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/caelestia/tvmode-monitors.lua")
```

**Classic config** (`~/.config/hypr/hyprland.conf`):

```ini
source = ~/.config/caelestia/tvmode-monitors.conf
```

Both files are generated on each switch. You don't need to create them first: `pcall` skips a file that doesn't exist yet, and Hyprland only warns about the missing `source` until the first switch.

> Why not `hyprctl keyword monitor`? It's gone in Lua-config Hyprland, and a runtime `hl.monitor()` call doesn't override a monitor rule that's already in your config. A reload with an override file works on both, and TV mode survives a config reload.

### 4. Write your settings

You can also skip this and pick everything from the shell's settings page after step 6.

```bash
mkdir -p ~/.config/caelestia
cp tvmode.example.json ~/.config/caelestia/tvmode.json
$EDITOR ~/.config/caelestia/tvmode.json
```

| key | example | what it does |
|---|---|---|
| `desktopMonitors` | `["DP-1", "DP-2"]` | turned off in TV mode |
| `tv` | `"HDMI-A-1"` | the TV's output |
| `tvMode` | `"3840x2160@60"` | resolution@refresh for the TV (`preferred` also works) |
| `tvScale` | `1` | scale on the TV; `1.5` or `2` makes the UI bigger from the couch |
| `tvAudioMatch` | `"SAMSUNG"` | part of the device name `detect.sh` showed for the TV's audio port (case-insensitive, regex) |
| `closeWindows` | `true` | close desktop windows when entering TV mode |
| `keepClassRegex` | `"caelestia\|quickshell\|steam"` | window classes that stay open (regex, case-insensitive) |
| `tvInDesktop` | `false` | `true` keeps the TV on as an extra screen in desktop mode |
| `keepAwake` | `true` | while in TV mode: turn on the shell's keep-awake (no lock screen or screen blanking) and block suspend with `systemd-inhibit`. Desktop mode undoes both; a keep-awake you'd already turned on yourself stays on |
| `steamCommand` | `"steam -gamepadui"` | how to start Steam if it isn't running. Try `gamescope -f -- steam -gamepadui` for a more console-like session: TV mode adds the TV's resolution and refresh rate (`-W -H -w -h -r`), so games can pick 4K instead of gamescope's default 1280x720. Size flags you add yourself are kept |

Anything you leave out uses the default from `scripts/common.sh`.

### 5. Test from a terminal

Set `"closeWindows": false` for the first try, so your terminal stays open.

```bash
./scripts/tv-mode.sh
```

Check that the monitors go dark, the TV shows the desktop, sound plays from the TV and Big Picture opens. Then:

```bash
./scripts/desktop-mode.sh
```

Check that Steam closes, the monitors come back at their normal positions, the TV goes dark and sound returns.

If the TV doesn't come up within about 20 seconds, `tv-mode.sh` switches back to your monitors by itself and exits with an error. You're never left with no screen.

### 6. Add it to the shell

Pick the option that matches your Caelestia shell:

**Shell with the plugin system** (`manifest.json` plugins, [caelestia-dots/shell#1703](https://github.com/caelestia-dots/shell/pull/1703)):

```bash
./install.sh          # link this folder (edits reload live)
./install.sh --copy   # or copy it
```

This adds a TV icon to the bar. Hover it for the popout with the **TV Mode** / **Desktop Mode** buttons and a ⚙ settings page. Middle-click the icon to toggle. Remove it with `./uninstall.sh`.

**Patched shell without a plugin loader** (widgets added with `// plugin:<name>` marker lines and a `PluginState` service):

```bash
./shell-patch.sh            # adds a "TV" tab to the dashboard
./shell-patch.sh --remove   # takes it out again
```

The ⚙ settings page uses dropdowns filled from your hardware: the TV output, its resolutions (the best 12 it reports, plus `preferred`), scale, which HDMI audio device to switch to (or "Don't switch audio"), switches for which screens go off in TV mode, and how to start Steam. It writes the same `~/.config/caelestia/tvmode.json` the scripts read, so changes apply on the next switch. Turn the TV on before opening the settings, so its audio device name shows up in the list.

### Keybinds (optional)

The scripts work without the shell, so you can bind them directly:

```lua
-- hyprland.lua
hl.bind("SUPER + ALT + T", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/caelestia/plugins/tvmode/scripts/tv-mode.sh"))
hl.bind("SUPER + ALT + D", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/caelestia/plugins/tvmode/scripts/desktop-mode.sh"))
```

```ini
# hyprland.conf
bind = SUPER ALT, T, exec, ~/.config/caelestia/plugins/tvmode/scripts/tv-mode.sh
bind = SUPER ALT, D, exec, ~/.config/caelestia/plugins/tvmode/scripts/desktop-mode.sh
```

(`install.sh` and `shell-patch.sh` create the `~/.config/caelestia/plugins/tvmode` link. Without them, use the path where you cloned the repo.)

## How the audio switch works

HDMI and DisplayPort audio comes from the graphics card's audio device. That device often has one port per connector but plays to **one at a time** (one card profile). So the TV's sink usually doesn't exist until you switch the card to it, and picking a sink with "hdmi" in its name may just pick your monitor's speakers.

`tv-mode.sh` finds the port whose device name matches `tvAudioMatch`, saves the card's current profile and your default sink, switches the card to the TV's profile, makes the new sink the default and moves playing streams to it. `desktop-mode.sh` restores the saved profile and sink. If your TV plays through a separate sound card or a soundbar on USB, any sink works as long as `tvAudioMatch` matches the port's device name. To leave audio alone completely, set `tvAudioMatch` to something no port matches, for example `"none"`.

## Troubleshooting

- **"TV didn't come up"**: the TV is off, in standby, or on another input, so it gives the PC no EDID. Turn it on, switch it to the PC input, and run `tv-mode.sh` again. The same thing can leave the TV dark after login if it was off when Hyprland started.
- **Sound stays on the desktop speakers**: run `detect.sh` while in TV mode and check that `tvAudioMatch` matches the TV's port name.
- **Monitors come back in the wrong place**: desktop mode uses your Hyprland config's monitor rules. Fix the layout there (or with your display settings tool) and it'll come back that way.
- **Names changed**: output names like `HDMI-A-1` depend on the port you use. Run `detect.sh` again after rewiring.
- **HDMI switch / second device**: the scripts only control the PC's outputs. Switch the TV or the HDMI switch to the PC input yourself.
- **Closing windows**: windows get a normal close request, so apps can still ask to save. Add anything you want kept open to `keepClassRegex`, or set `closeWindows` to `false`.
- **Lock screen still shows up**: check `systemd-inhibit --list` shows a "TV Mode" entry and `caelestia shell idleInhibitor isEnabled` says `true` while in TV mode. Other idle daemons (hypridle, swayidle) need to respect Wayland idle inhibitors; hypridle does by default.
- **Logs**: the scripts print `[tv-mode] ...` lines to stderr. State and saved audio are in `~/.cache/tv-mode/`.

## Files

| | |
|---|---|
| `scripts/tv-mode.sh`, `scripts/desktop-mode.sh` | the two actions |
| `scripts/common.sh` | settings loading and helpers |
| `scripts/detect.sh` | prints monitor, mode and audio port names |
| `scripts/hardware.sh` | the same data as JSON, for the settings dropdowns |
| `TvMode.qml` | shell service: runs the scripts, tracks the mode, holds the settings |
| `TvModePopout.qml`, `BarEntry.qml` | popout / dashboard tab and bar icon |
| `TvDropdown.qml`, `TvToggle.qml`, `TvSection.qml` | settings rows used by the popout |
| `manifest.json`, `install.sh`, `uninstall.sh` | plugin-system install |
| `shell-patch.sh` | install for a patched shell without a plugin loader |
| `tvmode.example.json` | example settings |
