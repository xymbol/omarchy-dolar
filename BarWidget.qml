import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The whole plugin, v1: fetch the rates, show one number. Everything lives in
// the bar widget for now — the panel gets extracted in the next step.
BarWidget {
  id: root
  moduleName: "io.github.xymbol.dolar"

  property var rates: []
  readonly property var entry: Model.findMarket(root.rates, "blue")
  readonly property string value: root.entry ? Model.formatPesos(root.entry.venta) : ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Shelling out to curl is the house pattern — the built-in weather widget
  // fetches exactly this way.
  Process {
    id: fetchProc
    command: ["curl", "-fsS", "--max-time", "8", "https://dolarapi.com/v1/dolares"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.rates = Model.parseRates(text)
    }
  }

  Timer {
    interval: 300000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!fetchProc.running) fetchProc.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.value === "" ? "" : "" + "  " + root.value
    tooltipText: "Dólar blue"
  }
}
