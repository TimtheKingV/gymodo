# -*- coding: utf-8 -*-
"""Erzeugt die vier Zustands-Artboards des Serien-Streifens aus einer
Vorlage. Nur der Kopfbereich, nicht der ganze Screen: die Screens
darunter sind in allen vier Zustaenden identisch, und ein viermal
wiederholter Uebungsfortschritt liest sich wie vier verschiedene
Entwuerfe."""
import io

STIL = '''  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700;800;900&display=swap">
  <style>
    body { margin: 0; background: #0A0B0D; font-family: Archivo, -apple-system, "Segoe UI", system-ui, sans-serif; -webkit-font-smoothing: antialiased; }
    a { color: #D4FF3F; } a:hover { color: #E8FF8A; }
    .ph { width: 393px; height: 300px; background: #0A0B0D; color: #F2F4F7; display: flex; flex-direction: column; overflow: hidden; }
    .eyebrow { font-size: 11px; font-weight: 800; letter-spacing: .14em; text-transform: uppercase; color: #9BA3AF; }
    .serie { display: flex; align-items: center; gap: 12px; }
    .flamme { flex: none; width: 56px; display: flex; flex-direction: column; align-items: center; gap: 3px; }
    .flamme-reihe { display: flex; align-items: center; gap: 4px; }
    .flamme-zahl { font-size: 27px; line-height: 1; font-weight: 900; font-variant-numeric: tabular-nums; letter-spacing: -.04em; color: #D4FF3F; }
    .flamme-label { font-size: 10px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; color: #D4FF3F; }
    .flamme.ruht .flamme-zahl { color: #9BA3AF; }
    .flamme.ruht .flamme-label { color: #5C636E; }
    .woche { flex-grow: 1; display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 4px; }
    .tagbox { height: 44px; border-radius: 12px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px; }
    .kuerzel { font-size: 10px; font-weight: 800; letter-spacing: .08em; color: #5C636E; }
    .tagnr { font-size: 16px; font-weight: 900; font-variant-numeric: tabular-nums; letter-spacing: -.03em; color: #5C636E; }
    .tagbox.trainiert { background: #1D2026; }
    .tagbox.trainiert .kuerzel { color: #9BA3AF; }
    .tagbox.heute { box-shadow: inset 0 0 0 1.5px #2A2E36; }
    .tagbox.heute .kuerzel, .tagbox.heute .tagnr { color: #9BA3AF; }
    .serie-fuss { font-size: 12px; font-weight: 600; color: #5C636E; font-variant-numeric: tabular-nums; }
  </style>'''

FLAMME = ('<svg width="21" height="25" viewBox="0 0 21 25" fill="{farbe}" style="flex: none">'
          '<path d="M11.2.4c.9 4-.7 6.1-2.9 8.3C5.6 11.2 3.4 13.8 3.4 17.3a7.6 7.6 0 0 0 15.2.2c0-2.9-1.1-5.1-2.7-6.9-.3 1.8-1.3 2.9-2.5 3.2 1.2-4.3-.1-9.1-2.2-13.4Z"/></svg>')

HANTEL = ('<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="#F2F4F7" stroke-width="2" '
          'stroke-linecap="round"><path d="M4 9v6M7.5 6.5v11M16.5 6.5v11M20 9v6M7.5 12h9"/></svg>')

TAGE = [("MO", 8), ("DI", 9), ("MI", 10), ("DO", 11), ("FR", 12), ("SA", 13), ("SO", 14)]


def streifen(trainiert, heute="MI"):
    out = ['      <div class="woche">']
    for kuerzel, nummer in TAGE:
        klassen = "tagbox"
        if kuerzel in trainiert:
            klassen += " trainiert"
        if kuerzel == heute:
            klassen += " heute"
        inhalt = HANTEL if kuerzel in trainiert else '<span class="tagnr">%d</span>' % nummer
        out.append('        <div class="%s">' % klassen)
        out.append('          <span class="kuerzel">%s</span>' % kuerzel)
        out.append('          %s' % inhalt)
        out.append('        </div>')
    out.append('      </div>')
    return "\n".join(out)


def flammenblock(zahl, label, ruht=False):
    return ('      <div class="flamme%s">\n'
            '        <div class="flamme-reihe">\n'
            '          %s\n'
            '          <span class="flamme-zahl">%s</span>\n'
            '        </div>\n'
            '        <span class="flamme-label">%s</span>\n'
            '      </div>') % (
        " ruht" if ruht else "",
        FLAMME.format(farbe="#5C636E" if ruht else "#D4FF3F"),
        zahl, label)


def abschnitt(block, fuss):
    """Der Serien-Abschnitt -- oder gar nichts, wenn es keine Serie gibt."""
    if not block:
        return ""
    return ('\n  <div style="flex: none; padding: 24px 20px 0; display: flex; '
            'flex-direction: column; gap: 12px">\n'
            '    <div class="eyebrow">Deine Serie</div>\n'
            '%s\n'
            '    <div class="serie-fuss">%s</div>\n'
            '  </div>') % (block, fuss)


def seite(datei, kommentar, block, fuss, kopf_extra=""):
    inhalt = '''<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
%s
</helmet>

<div class="ph">
  <div style="height: 54px; flex: none"></div>

  <div style="flex: none; padding: 14px 20px 0; display: flex; align-items: baseline; justify-content: space-between">
    <div style="font-size: 32px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1">Hallo Lena</div>
    <div class="eyebrow">Kraftwerk Nord</div>
  </div>

  <!-- %s -->%s%s
%s
</div>
</x-dc>
</body>
</html>
''' % (STIL, kommentar, abschnitt(block, fuss), '', kopf_extra)
    io.open(datei, "w", encoding="utf-8").write(inhalt)
    print("geschrieben: %s" % datei)


# 02 - Erste Woche. Einzahl im Label, damit "1 Wochen" gar nicht erst
# entstehen kann.
seite("ErsteWoche.dc.html",
      "Erste Woche: eine Einheit, die Serie beginnt bei 1. Label in der Einzahl.",
      '    <div class="serie">\n%s\n%s\n    </div>' % (
          flammenblock("1", "Woche"), streifen({"DI"})),
      "1 Einheit gesamt · zuletzt vor 1 Tag")

# 03 - Woche laeuft noch, aber leer. Die Flamme bleibt GRUEN und zeigt
# weiter die Zahl der Wochen, in denen tatsaechlich trainiert wurde: die
# Serie ist nicht gerissen, die Woche ist nur noch offen. Die erste
# Einheit dieser Woche laesst die Zahl um eins steigen.
seite("OffeneWoche.dc.html",
      "Diese Woche noch keine Einheit. Die Serie steht -- Flamme gruen, Zahl unveraendert. Die erste Einheit dieser Woche macht daraus eine 7.",
      '    <div class="serie">\n%s\n%s\n    </div>' % (
          flammenblock("6", "Wochen"), streifen(set())),
      "Noch keine Einheit diese Woche · 34 gesamt")

# 04 - Serie gerissen: graue Flamme mit einer Null. Sie steht da, weil
# "wie lange schon" eine Antwort hat, und "0" ist eine -- die Farbe sagt,
# dass gerade nichts laeuft.
seite("Gerissen.dc.html",
      "Serie unterbrochen: graue Flamme, Null. Weder diese noch die vorige Woche traegt eine Einheit.",
      '    <div class="serie">\n%s\n%s\n    </div>' % (
          flammenblock("0", "Wochen", ruht=True), streifen(set())),
      "Keine laufende Serie · 34 Einheiten gesamt")

# 05 - Kein Verlauf. DIESELBE Darstellung wie 04: der Streifen steht auch
# hier, mit grauer Flamme und Null. Der Screen hat damit in jedem Zustand
# dieselbe Silhouette, und der Leerzustand darunter erklaert weiter den
# ersten Schritt.
seite("OhneVerlauf.dc.html",
      "Noch nie trainiert: dieselbe Darstellung wie eine unterbrochene Serie. Der Leerzustand darunter bleibt unveraendert.",
      '    <div class="serie">\n%s\n%s\n    </div>' % (
          flammenblock("0", "Wochen", ruht=True), streifen(set())),
      "Noch keine Einheit erfasst",
      '''
  <div style="flex: none; padding: 24px 20px 0; display: flex; flex-direction: column; gap: 8px">
    <div style="font-size: 17px; font-weight: 700">Hier wird dein Verlauf stehen.</div>
    <div style="font-size: 15px; line-height: 1.45; color: #9BA3AF">Noch ist nichts da — das ändert sich mit deinem ersten Satz.</div>
  </div>''')
