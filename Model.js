// Pure helpers: no QML imports here, so every function can be exercised from
// plain node while iterating. That loop is much faster than restarting the
// shell to discover you got a decimal separator wrong.

// Strip what QML's AutoText would parse as rich text. Anything reaching a Text
// element from shell.json goes through here first.
function plainText(value) {
  return String(value === null || value === undefined ? "" : value).replace(/[<>&]/g, "")
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
// not es-AR on most machines — the separators would come out swapped, which is
// exactly the error this widget must never make.
function formatPesos(value, decimals) {
  var n = Number(value)
  if (!isFinite(n)) return "—"
  var d = decimals === undefined ? (n % 1 === 0 ? 0 : 2) : decimals
  var parts = Math.abs(n).toFixed(d).split(".")
  var formatted = groupThousands(parts[0]) + (parts.length > 1 ? "," + parts[1] : "")
  return (n < 0 ? "-" : "") + formatted
}

// dolarapi returns a flat array of markets.
function parseRates(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    if (!Array.isArray(data)) return []
    var out = []
    for (var i = 0; i < data.length; i++) {
      var d = data[i]
      if (!d || typeof d !== "object") continue
      var venta = Number(d.venta)
      // dolarapi names this field `market`; we call it `market`.
      var market = String(d.casa || "")
      if (!market || !isFinite(venta)) continue
      out.push({ market: market, compra: Number(d.compra), venta: venta })
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
