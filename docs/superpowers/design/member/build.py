# -*- coding: utf-8 -*-
"""Gemeinsame Bausteine fuer die Member-App-Artboards (Zugang).

Spiegelt die Struktur von docs/superpowers/design/portal/build.py, aber
mit den Massen der Member-App: 393 x 852 Rahmen, 28 pt Seitenrand auf
Login-Screens (20 pt im Content), Hauptaktion 64 pt / radius 16 im
unteren Drittel, Screentitel 32 pt Black Versalien -3% Tracking, alle
Ziffern tabellarisch, genau eine Akzentflaeche je Screen, kein
Scheinrahmen (keine gemalte Statusleiste, keine gemalte Tastatur).

Artboards teilen zur Laufzeit nichts, also muss jeder Baustein in jede
Datei hinein -- wie im Portal-Pendant.
"""
import io

HEAD = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700;800;900&display=swap">
  <style>
    * { box-sizing: border-box; }
    body { margin: 0; background: #0A0B0D; color: #F2F4F7; font-family: Archivo, -apple-system, "Segoe UI", system-ui, sans-serif; -webkit-font-smoothing: antialiased; font-variant-numeric: tabular-nums; }
    a { color: #D4FF3F; text-decoration: none; } a:hover { color: #E8FF8A; }
    .ph { width: 393px; height: 852px; background: #0A0B0D; color: #F2F4F7; display: flex; flex-direction: column; overflow: hidden; }
    .eyebrow { font-size: 11px; font-weight: 800; letter-spacing: .14em; text-transform: uppercase; color: #9BA3AF; }
    .num { font-variant-numeric: tabular-nums; font-weight: 900; letter-spacing: -.03em; }
    .sep { height: 1px; background: #2A2E36; }
    .tabs { flex: none; height: 78px; border-top: 1px solid #2A2E36; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); padding-top: 11px; }
    .tab { display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 10px; font-weight: 700; color: #5C636E; }
    .tab.on { color: #D4FF3F; }
  </style>
</helmet>
"""

FOOT = """</x-dc>
</body>
</html>
"""

NOTE = 'font-size: 13px; line-height: 1.5; color: #9BA3AF;'
NOTE_FAINT = 'font-size: 12px; line-height: 1.5; color: #5C636E;'

# Feld: 58 pt hoch, radius 14 -- "Nebenaktion, Stepper" laut Designsystem
# Abschnitt 4. Der Akzentrand markiert nur den Fokus (ein Strich, keine
# Flaeche) -- das zaehlt nicht gegen "genau eine Akzentflaeche je Screen".
FIELD = ('height: 58px; border-radius: 14px; background: #14161A; border: 1px solid #2A2E36; '
         'padding: 0 17px; display: flex; align-items: center; gap: 2px; font-size: 18px; font-weight: 600;')
FIELD_FOCUS = FIELD.replace('border: 1px solid #2A2E36;', 'border: 1.5px solid #D4FF3F;')

# Hauptaktion: 64 pt, radius 16 -- die eine Akzentflaeche je Screen.
PRIMARY = ('height: 64px; border-radius: 16px; background: #D4FF3F; color: #0A0B0D; '
           'font-size: 19px; font-weight: 800; display: flex; align-items: center; justify-content: center;')
PRIMARY_OFF = PRIMARY.replace('background: #D4FF3F; color: #0A0B0D;', 'background: #1D2026; color: #5C636E;')

# Nebenaktion: 46-52 pt, Umriss statt Flaeche -- kein zweites Volt.
NEBEN = ('height: 52px; border-radius: 14px; border: 1px solid #2A2E36; color: #F2F4F7; '
         'font-size: 16px; font-weight: 600; display: flex; align-items: center; justify-content: center;')


def schreibe(name, inhalt):
    io.open(name, 'w', encoding='utf-8').write(inhalt)
    print('geschrieben: %s' % name)


def chevron_left(groesse=24, farbe='#F2F4F7'):
    return ('<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="%s" '
            'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="m14.5 5-7 7 7 7"/></svg>' % (groesse, groesse, farbe))


def kopf_marke():
    """Wortmarke fuer Wurzel-Screens ohne Zurueck-Moeglichkeit."""
    return ('<div style="flex: none; padding: 28px 28px 0; display: flex; align-items: baseline; gap: 3px;">'
            '<span style="font-size: 27px; font-weight: 900; letter-spacing: -.05em;">gymodo</span>'
            '<span style="width: 7px; height: 7px; border-radius: 50%; background: #D4FF3F; display: inline-block;"></span>'
            '</div>')


def kopf_zurueck(label=None):
    """Zurueck-Chevron. Mit Label (Zieltab) fuer Screens, die per Push aus
    einem Tab kommen und die Tab-Leiste behalten -- ohne Label fuer die
    Einstiegs-Kette, die sich selbst genuegt (Vorbild: LoginCode)."""
    innen = chevron_left()
    if label:
        return ('<div style="flex: none; height: 44px; padding: 0 16px; display: flex; '
                 'align-items: center; gap: 12px;">%s<span class="eyebrow">%s</span></div>' % (innen, label))
    return '<div style="flex: none; height: 44px; padding: 0 20px; display: flex; align-items: center;">%s</div>' % innen


def titel(text, lead=None, top=40, seite=28):
    out = ('<div style="flex: none; padding: %dpx %dpx 0; display: flex; flex-direction: column; gap: 10px;">'
           '<div style="font-size: 32px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1.02;">%s</div>'
           % (top, seite, text))
    if lead:
        out += '<div style="%s">%s</div>' % (NOTE, lead)
    out += '</div>'
    return out


def feld(label, wert, fokus=False, monospace=False, seite=28, top=20, hoehe=None):
    stil = FIELD_FOCUS if fokus else FIELD
    if hoehe:
        stil = stil.replace('height: 58px;', 'height: %dpx;' % hoehe)
    if monospace:
        stil += " font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', monospace; letter-spacing: .08em;"
    return ('<div style="flex: none; padding: 0 %dpx; display: flex; flex-direction: column; gap: 9px; margin-top: %dpx;">'
            '<span class="eyebrow">%s</span>'
            '<div style="%s">%s</div></div>' % (seite, top, label, stil, wert))


_TAB_ICONS = {
    'Home': '<path d="M3 10.5 12 3l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/>',
    'Training': '<path d="M4 9v6M7.5 6.5v11M16.5 6.5v11M20 9v6M7.5 12h9"/>',
    'Kurse': '<rect x="3.5" y="5.2" width="17" height="15.3" rx="2.6"/><path d="M8 3v4M16 3v4M3.5 10.2h17"/>',
    'Profil': '<circle cx="12" cy="8" r="3.4"/><path d="M4.8 20c0-3.5 3.3-5.8 7.2-5.8s7.2 2.3 7.2 5.8"/>',
}
_TAB_ORDER = ['Home', 'Training', 'Kurse', 'Profil']


def tabs(aktiv):
    zellen = []
    for name in _TAB_ORDER:
        an = name == aktiv
        klasse = 'tab on' if an else 'tab'
        breite = '2' if an else '1.8'
        zellen.append('<div class="%s"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" '
                       'stroke="currentColor" stroke-width="%s" stroke-linecap="round" '
                       'stroke-linejoin="round">%s</svg>%s</div>'
                       % (klasse, breite, _TAB_ICONS[name], name))
    return '<div class="tabs">%s</div>' % ''.join(zellen)


def ph(inhalt):
    return HEAD + '<div class="ph">' + inhalt + '</div>' + FOOT


def spacer_top():
    """Freiraum fuer die echte iOS-Statusleiste -- nie gemalt."""
    return '<div style="height: 54px; flex: none;"></div>'


def fuellen():
    return '<div style="flex-grow: 1;"></div>'
