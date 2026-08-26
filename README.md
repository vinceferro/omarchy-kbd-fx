# Keyboard FX for Omarchy

Breathing, typing-reactive, and static effects for single-zone keyboard
backlights (e.g. MacBook Pro under Asahi). Ships a small Python daemon that
runs as an Omarchy shell service plugin.

![kind: service](https://img.shields.io/badge/kind-service-blue)

## Install

One command:

```bash
omarchy plugin add https://github.com/vinceferro/omarchy-kbd-fx.git --enable
```

That's it. On first shell start the plugin links its CLI into `~/.local/bin`
and adds the keybindings below to `~/.config/hypr/bindings.lua`
(marker-guarded block, never touches existing bindings).

The service starts with the shell and supervises the daemon automatically.
On machines without a controllable `kbd_backlight` LED it exits quietly.

Requirements: `/sys/class/leds/kbd_backlight`, `brightnessctl` (installed by
default on Omarchy). For the typing-reactive effect your user needs read
access to input devices (default on Omarchy via the `input` group).

## Keybindings

| Keys | Action |
|---|---|
| `SUPER + B` | cycle mode: off → static → breathe → type |
| `SUPER + ]` / `SUPER + [` | context knob (see table below) |

To remove them, delete the `>>> keyboard-fx` marked block in your
`bindings.lua`.

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
