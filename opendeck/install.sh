#!/bin/sh
# Copy the plugin into OpenDeck's plugin folder. Restart OpenDeck afterwards.
set -e
src="$(cd "$(dirname "$0")" && pwd)/com.martijnhe.tvmode.sdPlugin"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/opendeck/plugins/com.martijnhe.tvmode.sdPlugin"
rm -rf "$dest"
cp -r "$src" "$dest"
echo "Installed to $dest - restart OpenDeck to load it."
