// Pure helpers for the Dólar widget: parsing dolarapi's payload, Argentine
// number formatting, and the brecha. Nothing here imports QML, so every
// function can be exercised straight from node while iterating.

// Row order for the panel. dolarapi returns its own order; this one leads
// with the rates people actually quote out loud and leaves mayorista — a
// wholesale rate nobody uses in conversation — last.
var MARKET_ORDER = ["blue", "oficial", "tarjeta", "bolsa", "contadoconliqui", "cripto", "mayorista"]

// Short labels. dolarapi's own `nombre` field is wildly uneven in length
// ("Blue" next to "Contado con liquidación") and blows out the panel column,
// so the widely-used abbreviations are hardcoded instead.
// Keys are dolarapi's `market` values verbatim - data, not identifiers.
// Do not anglicise them or the lookup silently falls through.
var MARKET_LABELS = {
  blue: "Blue",
  oficial: "Oficial",
  tarjeta: "Tarjeta",
  bolsa: "MEP",
  contadoconliqui: "CCL",
  cripto: "Cripto",
  mayorista: "Mayorista"
}

function labelForMarket(market) {
  return MARKET_LABELS[market] || String(market || "")
}

// Strip what QML's AutoText would parse as rich text. Every string that
// reaches a Text element from shell.json goes through here first.
function plainText(value) {
  return String(value === null || value === undefined ? "" : value).replace(/[<>&]/g, "")
}

function pad2(n) {
  return (n < 10 ? "0" : "") + n
}

function groupThousands(whole) {
  var s = String(whole)
  var out = ""
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 === 0) out += "."
    out += s.charAt(i)
  }
  return out
}

// 1545 -> "1.545"; 1522.8 -> "1.522,80". Hand-rolled rather than
// toLocaleString because QML's JS locale follows the system locale, which is
// not es-AR on most machines — the separators would come out swapped, which
// is exactly the error this widget must never make.
function formatPesos(value, decimals) {
  var n = Number(value)
  if (!isFinite(n)) return "—"
  var d = decimals === undefined ? (n % 1 === 0 ? 0 : 2) : decimals
  var parts = Math.abs(n).toFixed(d).split(".")
  var formatted = groupThousands(parts[0]) + (parts.length > 1 ? "," + parts[1] : "")
  return (n < 0 ? "-" : "") + formatted
}

// dolarapi returns a flat array of markets. Anything unparseable yields an
// empty list, which the panel treats as "keep showing the last good numbers"
// rather than blanking the bar.
function parseRates(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    if (!Array.isArray(data)) return []
    var out = []
    for (var i = 0; i < data.length; i++) {
      var d = data[i]
      if (!d || typeof d !== "object") continue
      // dolarapi names this field `market`; rows read back from our own cache
      // have already been normalised to `market`. Accept either, or the
      // parse rejects every row.
      var market = String(d.casa || d.market || "")
      var compra = Number(d.compra)
      var venta = Number(d.venta)
      // venta is the side the pill shows by default, so a row without it is
      // useless; compra missing is survivable and renders as an em dash.
      if (!market || !isFinite(venta)) continue
      out.push({
        market: market,
        nombre: labelForMarket(market),
        compra: isFinite(compra) ? compra : null,
        venta: venta,
        fecha: String(d.fechaActualizacion || "")
      })
    }
    return out
  } catch (e) {
    return []
  }
}

function findMarket(rateList, market) {
  for (var i = 0; i < (rateList ? rateList.length : 0); i++)
    if (rateList[i].market === market) return rateList[i]
  return null
}

// `preferred` (the optional `markets` setting) both filters and orders. Without
// it MARKET_ORDER wins, and any market dolarapi adds later lands at the end rather than
// silently disappearing from the panel.
function orderRates(rateList, preferred) {
  var explicit = !!(preferred && preferred.length)
  var order = explicit ? preferred : MARKET_ORDER
  var out = []
  for (var i = 0; i < order.length; i++) {
    var m = findMarket(rateList, String(order[i]))
    if (m) out.push(m)
  }
  if (!explicit) {
    for (var j = 0; j < (rateList ? rateList.length : 0); j++)
      if (order.indexOf(rateList[j].market) === -1) out.push(rateList[j])
  }
  return out
}

// Brecha cambiaria: how far a market sits above the official rate, in percent.
// Quoted off venta because that is the side you actually pay.
function brecha(rateList, market) {
  var a = findMarket(rateList, market || "blue")
  var official = findMarket(rateList, "oficial")
  if (!a || !official || !isFinite(a.venta) || !isFinite(official.venta) || official.venta === 0)
    return null
  return (a.venta / official.venta - 1) * 100
}

function formatBrecha(value) {
  if (value === null || value === undefined || !isFinite(value)) return "—"
  var sign = value > 0 ? "+" : (value < 0 ? "-" : "")
  return sign + formatPesos(Math.abs(value), 1) + " %"
}

// "20:58", local time, from the most recent per-market timestamp in the payload.
// dolarapi stamps each market separately and they drift apart by hours — the
// official stops moving at 18:00 while blue keeps ticking — so the newest one
// is the only honest thing to label the panel with.
function lastUpdated(rateList) {
  var newest = 0
  for (var i = 0; i < (rateList ? rateList.length : 0); i++) {
    var t = Date.parse(rateList[i].fecha)
    if (isFinite(t) && t > newest) newest = t
  }
  if (!newest) return ""
  var d = new Date(newest)
  return pad2(d.getHours()) + ":" + pad2(d.getMinutes())
}

// Bar pill text. `side` picks the side: "venta" (default), "compra", or
// "ambos" for the full "1.525 / 1.545".
function pillValue(entry, side) {
  if (!entry) return ""
  if (side === "ambos" && entry.compra !== null)
    return formatPesos(entry.compra) + " / " + formatPesos(entry.venta)
  if (side === "compra" && entry.compra !== null)
    return formatPesos(entry.compra)
  return formatPesos(entry.venta)
}

// "1.525 / 1.545" for the panel's value column, independent of `side`:
// the panel is the detail view and always shows both sides.
function rowValue(entry) {
  if (!entry) return "—"
  var compra = entry.compra === null ? "—" : formatPesos(entry.compra)
  return compra + " / " + formatPesos(entry.venta)
}

// Bar prefix: the market's own name, so a pill says what it is — or the
// configured glyph, when one is set.
function pillPrefix(icon, entry) {
  if (icon) return icon
  return entry ? entry.nombre : "Dólar"
}

// ---- Persisted selection ----------------------------------------------
//
// The bar entry's `market` is the *declared* identity of an instance; the state
// file records what the user has since clicked. Keying by the declared market is
// what makes this work under allowMultiple — two pills declared `blue` and
// `tarjeta` keep independent selections inside one file.

function parseState(raw) {
  var empty = { version: 1, selection: {} }
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return empty
    var sel = (data.selection && typeof data.selection === "object") ? data.selection : {}
    var clean = {}
    for (var k in sel) if (typeof sel[k] === "string" && sel[k]) clean[k] = sel[k]
    return { version: 1, selection: clean }
  } catch (e) {
    return empty
  }
}

function selectedMarket(persisted, declared) {
  var d = String(declared || "blue")
  if (persisted && persisted.selection && typeof persisted.selection[d] === "string" && persisted.selection[d])
    return persisted.selection[d]
  return d
}

// A new persisted with this instance's selection set. Built by merging into the
// last-loaded object rather than rewriting the file wholesale, so a sibling
// pill's selection survives. Two pills clicked in the same instant could still
// race; the loser self-corrects on its next click, which is proportionate.
function withSelection(persisted, declared, market) {
  var base = parseState(JSON.stringify(persisted || { version: 1, selection: {} }))
  base.selection[String(declared || "blue")] = String(market || "")
  return base
}

// Next market in `order`, wrapping. Positive delta moves down the panel's list,
// matching the direction the rows are read.
function nextMarket(order, current, delta) {
  if (!order || !order.length) return current
  var i = order.indexOf(current)
  if (i === -1) i = 0
  var n = ((i + (delta > 0 ? 1 : -1)) % order.length + order.length) % order.length
  return order[n]
}
