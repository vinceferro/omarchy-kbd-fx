#!/bin/bash
# First-run setup for vinceferro.kbd-fx. Idempotent and safe to re-run:
# - links the kbd-fx CLI into ~/.local/bin
# - appends keybindings to ~/.config/hypr/bindings.lua once (marker-guarded)
# Called by Service.qml each time the shell starts; exits fast when done.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BINDINGS="$HOME/.config/hypr/bindings.lua"
MARK_BEGIN="-- >>> keyboard-fx (added by vinceferro.kbd-fx plugin)"
MARK_END="-- <<< keyboard-fx"

mkdir -p "$BIN_DIR"
ln -sf "$PLUGIN_DIR/kbd-fx" "$BIN_DIR/kbd-fx"

if [[ -f $BINDINGS ]] && ! grep -q ">>> keyboard-fx" "$BINDINGS"; then
  cat >> "$BINDINGS" <<EOF

$MARK_BEGIN
o.bind("SUPER + B", "Keyboard FX: cycle mode", "kbd-fx cycle")
o.bind("SUPER + BRACKETRIGHT", "Keyboard FX: knob up", "kbd-fx knob up")
o.bind("SUPER + BRACKETLEFT", "Keyboard FX: knob down", "kbd-fx knob down")
$MARK_END
EOF
  hyprctl reload >/dev/null 2>&1 || true
fi
