#!/usr/bin/env bash
# First-run setup for vinceferro.kbd-fx.
#
# The platform has NO install hooks. This shim is fired from Service.qml's
# Component.onCompleted on EVERY shell start, so it must be:
#   - idempotent       — running twice is a no-op
#   - marker-guarded   — appends to user configs between BEGIN/END markers,
#                        never blind-appended
#   - fast             — it sits on the shell's startup path; exit early
#                        when there is nothing to do
# It never touches /usr/share/omarchy or anything outside the user's own
# config (plus the symlinks it legitimately owns).
#
# Marker-append hardening (each rule below was a real bug once):
#   1. ALWAYS pass "--" before a variable pattern: `grep -qF -- "$MARK"`.
#      Belt and suspenders with rule 2.
#   2. Marker strings must not start with "-" *where the config syntax
#      allows*. bindings.lua is lua: comments MUST start with "--", so these
#      markers have to. The guard stays safe because rule 1's `--` separator
#      stops grep from parsing them as options — never grep a variable
#      pattern without it.
#   3. Guard on the END marker (the last line written), not BEGIN. An
#      interrupted append leaves BEGIN without END; detect that and heal it
#      — but ONLY strip the partial block when it is still the file's tail
#      (the shipped 1.0.0 shim had no self-heal, so an old partial can have
#      FOREIGN config written below it since; "delete from BEGIN to EOF"
#      would silently eat those lines). See the guard below.
#
# The marker strings below are FIXED HISTORY: the shipped 1.0.0 shim wrote
# exactly these lines into existing users' bindings.lua. Changing them would
# make this shim see "no block" and append a second one on update.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Link the bundled CLI onto PATH ---------------------------------------
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
ln -sf "$PLUGIN_DIR/kbd-fx" "$BIN_DIR/kbd-fx"

# --- Marker-guarded keybinding append --------------------------------------
CONFIG="$HOME/.config/hypr/bindings.lua"
MARK_BEGIN="-- >>> keyboard-fx (added by vinceferro.kbd-fx plugin)"
MARK_END="-- <<< keyboard-fx"
# Last line the shim's block writes before MARK_END — the tail-guard compares
# against this (see the interrupted-append branch below).
LAST_BLOCK_LINE='o.bind("SUPER + BRACKETLEFT", "Keyboard FX: knob down", "kbd-fx knob down")'

if [[ -f $CONFIG ]]; then
  if grep -qF -- "$MARK_BEGIN" "$CONFIG" && ! grep -qF -- "$MARK_END" "$CONFIG"; then
    # Interrupted append (BEGIN without END). Strip it ONLY when the partial
    # block is genuinely the file tail: the last non-blank line must be the
    # last line our block writes before END. The 1.0.0 shim had no self-heal,
    # so an old partial can have foreign config below it since — deleting
    # BEGIN-to-EOF there would eat those lines. If the tail does not match,
    # leave the file untouched and fall through: the append below adds a
    # fresh complete block after it (stale partial + fresh block is ugly but
    # safe; deleting someone's config is not).
    if [[ $(grep -v '^[[:space:]]*$' "$CONFIG" | tail -n 1) == "$LAST_BLOCK_LINE" ]]; then
      sed -i "\|^${MARK_BEGIN}|,\$d" "$CONFIG"
    fi
  fi
  if ! grep -qF -- "$MARK_END" "$CONFIG"; then
    cat >> "$CONFIG" <<EOF

$MARK_BEGIN
o.bind("SUPER + B", "Keyboard FX: cycle mode", "kbd-fx cycle")
o.bind("SUPER + BRACKETRIGHT", "Keyboard FX: knob up", "kbd-fx knob up")
o.bind("SUPER + BRACKETLEFT", "Keyboard FX: knob down", "kbd-fx knob down")
$MARK_END
EOF
    hyprctl reload >/dev/null 2>&1 || true
  fi
fi
