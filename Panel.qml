import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Detail view and data owner. The bar pill renders `pillText`; the fetching
// and formatting moved here out of BarWidget.qml.
Panel {
  id: root
  moduleName: "io.github.xymbol.dolar"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel, so everything the bar identifies a panel by has to be that
  // widget.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color fgDim: Qt.darker(fg, 1.5)
  readonly property string fontName: root.bar ? root.bar.fontFamily : Style.font.family

  // The declared identity of this instance. Under allowMultiple this is what
  // separates one pill's persisted selection from another's, so it is read
  // from shell.json and never reassigned.
  readonly property string declaredMarket: Model.plainText(setting("market", "blue"))
  // What the pill actually shows: the clicked selection when there is one,
  // otherwise the declared market.
  readonly property string market: Model.selectedMarket(root.persisted, root.declaredMarket)
  readonly property bool showBrecha: setting("showBrecha", true) === true
  // Which side of the spread the pill shows: "venta" (default), "compra", or
  // "ambos" for both.
  readonly property string showSide: Model.plainText(setting("showSide", "venta"))
  // Optional list restricting and reordering the panel rows.
  readonly property var visibleMarkets: setting("markets", null)
  // Floored at 60s: dolarapi is free and unauthenticated, and the rates do not
  // move fast enough to justify hammering it from every Omarchy bar.
  readonly property int refreshSeconds: Math.max(60, parseInt(setting("refreshSeconds", 300), 10) || 300)

  // ---- Persisted selection ----
  property var persisted: ({ version: 1, selection: {} })
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/settings/dolar.json"

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.persisted = Model.parseState(text())
    onLoadFailed: root.persisted = Model.parseState("")
    // Watching means a sibling pill's write lands here too, so two instances
    // stay consistent without either knowing about the other.
    onFileChanged: reload()
  }

  // setText will not create the directory, and it may not exist on a fresh
  // install. Same guard the notifications service uses.
  Process {
    id: mkdirProc
    running: true
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/omarchy/settings"]
  }

  function selectMarket(nueva) {
    if (!nueva || nueva === root.market) return
    var updated = Model.withSelection(root.persisted, root.declaredMarket, nueva)
    root.persisted = updated
    stateFile.setText(JSON.stringify(updated, null, 2) + "\n")
  }

  // Wheel over the pill steps through the same list the panel shows, so the
  // two affordances never disagree about what comes next.
  function cycleMarket(delta) {
    var order = []
    for (var i = 0; i < root.rows.length; i++) order.push(root.rows[i].market)
    if (!order.length) return
    root.selectMarket(Model.nextMarket(order, root.market, delta))
  }

  // Last good payload, deliberately kept across failed refreshes: a dropped
  // network should leave the previous number on the bar, not blank it.
  property var rates: []
  property int retries: 0
  property bool offline: false

  readonly property var barEntry: Model.findMarket(rates, root.market)
  readonly property string pillText: Model.pillValue(barEntry, root.showSide)
  readonly property var rows: Model.orderRates(rates, root.visibleMarkets)
  readonly property string updatedAt: Model.lastUpdated(rates)
  readonly property var brechaValue: Model.brecha(rates, root.market)
  // Prefix shown on the pill: the market name, or the configured glyph.
  readonly property string label: Model.pillPrefix(Model.plainText(setting("icon", "")), root.barEntry)
  readonly property string tooltipLabel: barEntry
    ? "Dólar " + barEntry.nombre + (updatedAt ? " · " + updatedAt : "")
    : "Dólar"

  function open() { root.controller.show(); root.refresh() }
  function openFromHotkey() { root.controller.show(); root.refresh() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refresh() {
    if (fetchProc.running) return
    fetchProc.running = true
  }

  Process {
    id: fetchProc
    command: ["curl", "-fsS", "--max-time", "8", "https://dolarapi.com/v1/dolares"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseRates(text)
        if (parsed.length) {
          root.rates = parsed
          root.offline = false
          root.retries = 0
        } else {
          root.scheduleRetry()
        }
      }
    }
  }

  // A failed fetch on a laptop is usually a suspended-and-resumed machine whose
  // wifi has not reassociated yet, so retry a few times before falling back to
  // the ordinary refresh interval.
  function scheduleRetry() {
    root.offline = true
    if (root.retries >= 3) return
    root.retries++
    retryTimer.restart()
  }

  Timer {
    id: retryTimer
    interval: 4000
    onTriggered: if (!fetchProc.running) fetchProc.running = true
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // ---- Hero: the market this pill is configured for ----
        Item {
          width: parent.width
          height: heroColumn.implicitHeight

          Column {
            id: heroColumn
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            spacing: Style.space(2)

            Text {
              text: root.barEntry ? "Dólar " + root.barEntry.nombre : "Dólar"
              textFormat: Text.PlainText
              color: root.fgDim
              font.family: root.fontName
              font.pixelSize: Style.font.bodySmall
              renderType: Text.NativeRendering
            }

            Text {
              text: root.pillText === "" ? "—" : root.pillText
              textFormat: Text.PlainText
              color: root.fg
              font.family: root.fontName
              font.pixelSize: Style.font.display
              renderType: Text.NativeRendering
            }
          }

          // Hidden when the pill is the official, where it always reads +0,0 %.
          Column {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(16)
            anchors.bottom: heroColumn.bottom
            spacing: Style.space(2)
            visible: root.showBrecha && root.market !== "oficial" && root.brechaValue !== null

            Text {
              text: "brecha"
              textFormat: Text.PlainText
              color: root.fgDim
              font.family: root.fontName
              font.pixelSize: Style.font.caption
              renderType: Text.NativeRendering
              anchors.right: parent.right
            }

            Text {
              text: Model.formatBrecha(root.brechaValue)
              textFormat: Text.PlainText
              color: Color.accent
              font.family: root.fontName
              font.pixelSize: Style.font.title
              renderType: Text.NativeRendering
              anchors.right: parent.right
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        // ---- Every market dolarapi reports ----
        Repeater {
          model: root.rows

          Item {
            id: row
            required property var modelData
            width: content.width
            height: Style.space(24)

            readonly property bool isActive: modelData.market === root.market

            // Hover fill sits inside the panel's text margins so the highlight
            // reads as a row, not as a full-bleed band.
            Rectangle {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              radius: Style.cornerRadius
              color: rowMouse.containsMouse ? Style.hoverFillFor(root.fg, Color.accent) : "transparent"
            }

            // Declared before the labels so the text paints over the fill;
            // Text takes no input, so the whole row stays clickable.
            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectMarket(row.modelData.market)
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.nombre
              textFormat: Text.PlainText
              color: row.isActive ? Color.accent : root.fgDim
              font.family: root.fontName
              font.pixelSize: Style.font.body
              renderType: Text.NativeRendering
            }

            Text {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              text: Model.rowValue(row.modelData)
              textFormat: Text.PlainText
              color: row.isActive ? Color.accent : root.fg
              font.family: root.fontName
              font.pixelSize: Style.font.body
              renderType: Text.NativeRendering
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        Item {
          width: parent.width
          height: footer.implicitHeight

          Text {
            id: footer
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            text: {
              if (root.rates.length === 0) return root.offline ? "sin conexión" : "cargando…"
              if (root.offline) return "sin conexión · último dato " + root.updatedAt
              return "actualizado " + root.updatedAt
            }
            textFormat: Text.PlainText
            color: root.fgDim
            font.family: root.fontName
            font.pixelSize: Style.font.caption
            renderType: Text.NativeRendering
          }

          // The column hint is decorative; a status message is not. Hide it
          // rather than let the two collide, which they do as soon as the
          // footer says anything longer than "actualizado HH:MM".
          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(16)
            anchors.baseline: footer.baseline
            visible: !root.offline
            text: "compra / venta"
            textFormat: Text.PlainText
            color: root.fgDim
            font.family: root.fontName
            font.pixelSize: Style.font.caption
            renderType: Text.NativeRendering
          }
        }
      }
    }
  }
}
