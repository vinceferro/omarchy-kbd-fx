import QtQuick
import Quickshell.Io

// Keyboard FX service plugin.
//
// Supervises the bundled `kbd-fx` python daemon. The daemon reads/writes
// /sys/class/leds/kbd_backlight through brightnessctl and exits quietly on
// machines without a controllable keyboard backlight (no restart loop).
Item {
  id: root

  // Injected by omarchy-shell (the plugin service loader).
  property var shell: null

  // Filesystem path of the bundled CLI, resolved next to this QML file.
  readonly property string cliPath: {
    var url = Qt.resolvedUrl("kbd-fx").toString()
    return decodeURIComponent(url.replace(/^file:\/\//, ""))
  }

  readonly property bool supported: probe.exitCode === 0

  Component.onCompleted: probe.running = true

  // One-shot capability check before spawning the daemon.
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
    id: daemon
    command: ["python3", root.cliPath, "daemon"]

    onExited: function(exitCode) {
      // Restart with a fixed delay unless it exited cleanly (unsupported hw).
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
