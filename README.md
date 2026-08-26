# Keyboard FX for Omarchy

Breathing, typing-reactive, and static effects for single-zone keyboard
backlights (e.g. MacBook Pro under Asahi). Ships a small Python daemon that
runs as an Omarchy shell service plugin.

![kind: service](https://img.shields.io/badge/kind-service-blue)

## Install

```bash
omarchy plugin add https://github.com/vinceferro/omarchy-kbd-fx.git --enable
```

For the typing-reactive effect your user needs read access to input devices
(default on Omarchy via the `input` group): `groups | grep -q input || echo 'add yourself: sudo usermod -aG input $USER'`.

The service starts with the shell and supervises the daemon automatically.
On machines without a controllable `kbd_backlight` LED it exits quietly.

Requirements (checked at startup): `/sys/class/leds/kbd_backlight` and
`brightnessctl` (installed by default on Omarchy).

## Keybindings

Plugins cannot register Hyprland bindings, so add these yourself in
`~/.config/hypr/bindings.lua`:

```lua
-- Make sure the CLI is on PATH first:
--   ln -sf ~/.config/omarchy/plugins/vinceferro.kbd-fx/kbd-fx ~/.local/bin/kbd-fx
o.bind("SUPER + B", "Keyboard FX: cycle mode", "kbd-fx cycle")
o.bind("SUPER + BRACKETRIGHT", "Keyboard FX: knob up", "kbd-fx knob up")
o.bind("SUPER + BRACKETLEFT", "Keyboard FX: knob down", "kbd-fx knob down")
```

Then reload with `hyprctl reload`.

## The dynamic knobs

| Mode (`SUPER + B` cycles) | What you get | `]` / `[` knobs adjust |
|---|---|---|
| `off` | backlight off | hardware brightness |
| `static` | steady glow at your level | hardware brightness (persists) |
| `breathe` | organic breath cycle | tempo: Fast (2s) / Medium (3.5s) / Slow (5s) |
| `type` | pulses to full while typing, decays after | resting glow level |

State (mode, level, tempo) persists across reboots in `~/.cache/kbd-fx/`.

All feedback — mode changes, brightness, tempo — shows as the standard
Omarchy OSD bar.

## CLI reference

```bash
kbd-fx                # cycle mode (OSD)
kbd-fx <mode>         # off | static | breathe | type
kbd-fx knob up|down   # context-sensitive control (see table above)
kbd-fx faster|slower  # breathe tempo directly (snaps between the 3 slots)
kbd-fx status         # current mode / level / period
```

## Customizing

Edit the copy inside `~/.config/omarchy/plugins/vinceferro.kbd-fx/kbd-fx` —
the interesting constants are at the top (breath curve shape is in
`breath_wave()`, decay times, tempo ranges). Changes apply after one
restart: `omarchy-shell shell rescanPlugins` or log out/in.
