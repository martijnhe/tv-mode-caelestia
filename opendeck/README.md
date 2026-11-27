# TV Mode for OpenDeck

An [OpenDeck](https://github.com/nekename/OpenDeck) plugin for TV Mode, so a Stream Deck key can switch to the TV and back.

## Actions

- **Toggle TV Mode**: press to switch to TV mode, press again to go back to desktop. The key shows the current mode (blue = desktop, orange = TV) and `…` while switching. A failed switch shows the alert icon; the reason is in OpenDeck's plugin log.
- **TV Mode Status**: shows only the current mode, as an icon plus "Desktop" / "TV".

Both keys follow `~/.cache/tv-mode/state`, so switching from the Caelestia shell or a terminal updates the deck too.

## Settings

Select either key in OpenDeck to get the TV mode settings: TV output and resolution, scale, TV audio device, which monitors make up the desktop, what to launch, and which windows to keep. They're saved straight to `~/.config/caelestia/tvmode.json`, the same file the Caelestia shell's TV mode settings use, so both always agree. **Rescan** reloads the monitor and audio lists (the TV only shows up while it's connected).

## Install

Requires Node 22 or newer (no npm packages needed) and TV Mode set up as in the [main README](../README.md) (steps 1 to 6).

```sh
./opendeck/install.sh
```

Then restart OpenDeck and drag the actions from the "TV Mode" category onto your keys.

The plugin looks for `tv-mode.sh` and `desktop-mode.sh` in `~/.config/caelestia/plugins/tvmode/scripts` (the link `install.sh` / `shell-patch.sh` make), then `~/.local/src/tv-mode-caelestia/scripts`. Set `TVMODE_SCRIPTS` to use another folder.
