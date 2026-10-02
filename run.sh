#!/usr/bin/env bash
# Launch the game from a terminal. The import pass registers the game's script classes
# (Godot's editor does this on open; plain `godot --path .` on a fresh checkout does not).
cd "$(dirname "$0")" || exit 1
godot --headless --path . --import >/dev/null 2>&1
exec godot --path . "$@"
