import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The bar pill. Now that Panel.qml owns the data, this file is only a shell:
// it hosts the panel in a Loader and republishes the handful of members the
// bar identifies a panel by.
BarWidget {
  id: root
  moduleName: "io.github.xymbol.dolar"

  // The prefix is the market's name rather than a currency glyph. In Argentina
  // "$" is the peso sign, and it carries no information here anyway — whereas
  // the name is what makes two pills distinguishable. Set "icon" for a glyph.
  readonly property string value: panelLoader.item ? panelLoader.item.pillText : ""
  readonly property string prefix: panelLoader.item ? panelLoader.item.label : ""
  readonly property string tip: panelLoader.item ? panelLoader.item.tooltipLabel : ""

  // The panel is not wired up automatically; the widget hands it its context.
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleMarket(delta) {
    if (panelLoader.item && panelLoader.item.cycleMarket) panelLoader.item.cycleMarket(delta)
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing: Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root, not on the nested panel.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.value === "" ? root.prefix : root.prefix + " " + root.value
    tooltipText: root.tip

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    onWheelMoved: function(delta) { root.cycleMarket(delta) }
  }
}
