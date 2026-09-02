import QtQuick
import Quickshell.Io

// vinceferro.kbd-fx — service plugin (kind: service).
//
// Supervises the bundled `kbd-fx` python daemon, which drives per-frame
// keyboard-backlight effects on /sys/class/leds/kbd_backlight (via
// brightnessctl) and exits quietly on machines without a controllable
// keyboard backlight (so the supervisor never loops).
//
// Shape: probe -> supervise -> setup-shim.
//  - probe: one-shot capability check; the daemon starts only on supported
//    hardware.
//  - supervise: Process + fixed-delay restart Timer. The daemon itself exits
//    code 0 on unsupported hardware (guarded again inside kbd-fx), so the
//    Timer only ever restarts real crashes.
//  - setup-shim: this platform has NO install hooks. First-run work lives in
//    setup.sh (marker-guarded, idempotent), fired from Component.onCompleted
//    on EVERY start so it self-heals across updates.

Item {
  id: root

  // Injected by the omarchy-shell plugin service loader.
  property var shell: null

  // Filesystem path of the bundled CLI, resolved next to this QML file.
  // NOTE: this block form (statements + explicit return) is legal QML. What
  // is NOT legal is an IIFE in a binding: `property string x: { ... }()`
  // silently unmounts the component. Use this shape or ternaries, never a
  // trailing `()`.
  readonly property string cliPath: {
    var url = Qt.resolvedUrl("kbd-fx").toString()
    return decodeURIComponent(url.replace(/^file:\/\//, ""))
  }

  readonly property string setupPath: {
    var url = Qt.resolvedUrl("setup.sh").toString()
    return decodeURIComponent(url.replace(/^file:\/\//, ""))
  }

  Component.onCompleted: {
    probe.running = true
    // First-run setup: PATH symlink + keybindings. Idempotent, no-ops when
    // already configured. Runs on every shell start so it self-heals.
    setup.running = true
  }

  // One-shot capability check before spawning the daemon.
  //   exit 0    -> supported -> daemon starts
  //   exit != 0 -> unsupported -> nothing runs, no restart loop
  Process {
    id: probe
    command: ["sh", "-c",
      "test -d /sys/class/leds/kbd_backlight && command -v brightnessctl >/dev/null"]
    onExited: function(exitCode) {
      if (exitCode === 0)
        daemon.running = true
    }
  }

  Process {
    id: setup
    command: ["bash", root.setupPath]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // The effect daemon. OWNERSHIP DISCIPLINE (the kbd-fx lesson that made
  // the template exist):
  //  - effect modes (breathe, type) drive every frame themselves;
  //  - static/off write ONCE and keep hands off afterwards, so the hardware
  //    and its Fn keys stay the source of truth;
  //  - never poll-and-correct against hardware whose reads lag its writes.
  // The daemon lives in the python CLI itself (`kbd-fx daemon`) per the
  // template's documented variant for python daemons; the internal guard in
  // kbd-fx exits 0 when the LED class is absent.
  Process {
    id: daemon
    command: ["python3", root.cliPath, "daemon"]

    onExited: function(exitCode) {
      // exit 0 = clean shutdown (unsupported hardware or intentional stop):
      // do NOT restart. Nonzero = crash: restart after a fixed delay.
      if (exitCode !== 0)
        restartTimer.start()
    }
  }

  Timer {
    id: restartTimer
    interval: 3000
    onTriggered: daemon.running = true
  }
}
