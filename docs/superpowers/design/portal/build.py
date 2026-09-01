# -*- coding: utf-8 -*-
"""Erzeugt die restlichen Artboards aus einer gemeinsamen Vorlage.

Die Rail steht in jedem Portal-Bildschirm gleich; Artboards teilen zur
Laufzeit nichts, also muss sie in jede Datei hinein. Von Hand waere das
achtmal dieselbe Aenderung bei jeder Korrektur.
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
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700;800&display=swap">
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: #0a0b0d;
      color: #f2f4f7;
      font-family: Archivo, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
      font-size: 14px;
      line-height: 1.5;
      font-variant-numeric: tabular-nums;
    }
    a { color: #f2f4f7; text-decoration: none; }
    a:hover { color: #d4ff3f; }
  </style>
</helmet>
"""

FOOT = """</x-dc>
</body>
</html>
"""

LABEL = ('font-size: 11px; font-weight: 800; letter-spacing: 0.14em; '
         'text-transform: uppercase;')
CARD = 'border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; overflow: hidden;'
HEADROW = 'padding: 16px 20px; border-bottom: 1px solid #2a2e36; display: flex; align-items: baseline; justify-content: space-between; gap: 16px;'
ROW = 'display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 20px; border-bottom: 1px solid #2a2e36;'
ROW_LAST = ROW.replace('border-bottom: 1px solid #2a2e36;', '')
PRIMARY = ('display: inline-flex; align-items: center; justify-content: center; height: 44px; '
           'padding: 0 20px; border-radius: 10px; background: #d4ff3f; color: #0a0b0d; font-weight: 700;')
SECONDARY = ('display: inline-flex; align-items: center; justify-content: center; height: 40px; '
             'padding: 0 16px; border-radius: 10px; background: #1d2026; border: 1px solid #2a2e36; '
             'color: #f2f4f7; font-weight: 600; flex-shrink: 0;')
DESTRUCTIVE = ('display: inline-flex; align-items: center; justify-content: center; height: 40px; '
               'padding: 0 16px; border-radius: 10px; border: 1px solid #ff5a4e; color: #ff5a4e; '
               'font-weight: 600; flex-shrink: 0;')
FIELD = ('background: #0f1114; border: 1px solid #2a2e36; border-radius: 10px; padding: 10px 12px; '
         'min-height: 44px; color: #5c636e; display: flex; align-items: center;')
BADGE = ('display: inline-flex; align-items: center; border: 1px solid #2a2e36; border-radius: 999px; '
         'padding: 2px 10px; font-size: 11px; font-weight: 800; letter-spacing: 0.08em; '
         'text-transform: uppercase; color: #9ba3af;')
SEC_TITLE = '%s color: #9ba3af; margin: 0;' % LABEL


def zeile(haupt, meta, rechts, letzte=False, meta_faint=False):
    stil = ROW_LAST if letzte else ROW
    mc = '#5c636e' if meta_faint else '#9ba3af'
    return ('<div style="%s"><div style="min-width: 0;">'
            '<div style="font-weight: 600;">%s</div>'
            '<div style="font-size: 12px; color: %s; margin-top: 2px;">%s</div></div>'
            '<div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">%s</div></div>'
            % (stil, haupt, mc, meta, rechts))


def nav_item(title, meta, active=False):
    border = '#d4ff3f' if active else 'transparent'
    bg = ' background: #1d2026;' if active else ''
    color = '#f2f4f7' if active else '#9ba3af'
    meta_html = ''
    if meta:
        meta_html = ('<span style="display: block; font-size: 12px; color: #5c636e; '
                     'margin-top: 2px;">%s</span>' % meta)
    return ('<a href="#" style="display: block; padding: 8px 20px; border-left: 2px solid %s;%s '
            'color: %s;"><span style="display: block; font-size: 14px; font-weight: 600;">%s</span>%s</a>'
            % (border, bg, color, title, meta_html))


def rail(active):
    gruppe = lambda name, items: (
        '<div style="display: flex; flex-direction: column; gap: 4px;">'
        '<div style="%s color: #5c636e; padding: 0 20px 8px;">%s</div>%s</div>'
        % (LABEL, name, ''.join(items)))
    return (
        '<nav style="width: 288px; flex: 0 0 288px; background: #14161a; '
        'border-right: 1px solid #2a2e36; padding: 24px 0 24px; display: flex; '
        'flex-direction: column; gap: 24px;">'
        '<div style="padding: 0 20px;">'
        '<div style="font-size: 17px; font-weight: 800; letter-spacing: -0.02em; '
        'text-transform: uppercase;">Kraftwerk Nord</div>'
        '<div style="font-size: 12px; color: #9ba3af; margin-top: 4px;">Trainerportal</div></div>'
        + gruppe('Studio', [
            nav_item('Überblick', None, active == 'ueberblick'),
            nav_item('Kurse', '5 diese Woche', active == 'kurse'),
        ])
        + gruppe('Katalog', [
            nav_item('Geräte', '4 · 2 erreichbar', active == 'geraete'),
            nav_item('Tags', '97 vorrätig', active == 'tags'),
        ])
        + gruppe('Verwaltung', [
            nav_item('Leute', '24 Mitglieder · 4 Mitarbeiter', active == 'leute'),
            nav_item('Einstellungen', None, active == 'einstellungen'),
        ])
        + '<div style="margin-top: auto; padding: 16px 20px 0; border-top: 1px solid #2a2e36; '
          'display: flex; flex-direction: column; gap: 8px;">'
          '<div style="font-size: 12px; color: #9ba3af;">tim@kraftwerk-nord.de</div>'
          '<a href="#" style="font-size: 12px; color: #5c636e;">Abmelden</a></div>'
        '</nav>')


def portal(active, hoehe, inhalt):
    return (HEAD
            + '<div style="display: flex; min-height: %dpx; background: #0a0b0d;">' % hoehe
            + rail(active)
            + '<main style="flex: 1; min-width: 0; padding: 32px 40px 48px; max-width: 1000px;">'
            + inhalt + '</main></div>\n' + FOOT)


def titel(text, lead=None):
    out = ('<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.025em; '
           'text-transform: uppercase; margin: 0;">%s</h1>' % text)
    if lead:
        out += ('<p style="color: #9ba3af; margin: 8px 0 0; max-width: 62ch;">%s</p>' % lead)
    return out


def schreibe(name, inhalt):
    io.open(name, 'w', encoding='utf-8').write(inhalt)
    print('geschrieben: %s' % name)

# Symbole werden gezeichnet, nie als Zeichen gesetzt: ein Pfeilglyph steht in
# Archivo nicht zur Verfuegung und faellt mitten im Text auf eine andere
# Schrift zurueck -- andere Strichstaerke, andere Hoehe.
_SVG_PFADE = {
    'arrow-left': '<path d="M19 12H5"></path><path d="M12 19l-7-7 7-7"></path>',
    'arrow-right': '<path d="M5 12h14"></path><path d="M12 5l7 7-7 7"></path>',
    'arrow-up': '<path d="M12 19V5"></path><path d="M5 12l7-7 7 7"></path>',
    'arrow-down': '<path d="M12 5v14"></path><path d="M19 12l-7 7-7-7"></path>',
    'chevron-down': '<path d="M6 9l6 6 6-6"></path>',
}


def svg(name, groesse=16, farbe='currentColor'):
    return ('<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="%s" '
            'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" '
            'style="flex-shrink: 0;">%s</svg>'
            % (groesse, groesse, farbe, _SVG_PFADE[name]))


def zurueck(text):
    return ('<span style="display: inline-flex; align-items: center; gap: 6px;">%s %s</span>'
            % (svg('arrow-left', 14), text))


def reiter(items, aktiv):
    """items: [(name, meta_oder_None), ...]"""
    aus = []
    for name, meta in items:
        an = name == aktiv
        rand = '#d4ff3f' if an else 'transparent'
        farbe = '#f2f4f7' if an else '#9ba3af'
        m = ('<span style="display: block; font-size: 12px; color: #5c636e; '
             'margin-top: 2px;">%s</span>' % meta) if meta else ''
        aus.append('<a href="#" style="padding: 12px 16px; border-bottom: 2px solid %s; '
                   'color: %s;"><span style="display: block; font-weight: 600;">%s</span>%s</a>'
                   % (rand, farbe, name, m))
    return ('<div style="display: flex; gap: 4px; margin-top: 24px; '
            'border-bottom: 1px solid #2a2e36;">%s</div>' % ''.join(aus))


# ---------------------------------------------------------------- Telefon
# Der Einrichtungsgang laeuft auf dem Trainerhandy, 390 px breit. Die
# Bausteine stehen hier und nicht in gen_telefon.py, weil sie dort dieselbe
# Rolle spielen wie rail() am Schreibtisch: sie stehen auf jedem Bildschirm
# gleich, und von Hand waere jede Korrektur dreizehnmal dieselbe Aenderung.
#
# Eine Konvention, auf der die Pruefung des Designsystems aufsetzt:
#   background: #d4ff3f        -- Aktionsflaeche, hoechstens eine je Artboard
#   background-color: #d4ff3f  -- Akzent als *Wert* (Balken, Punkt, Marke)
# Beides ist dieselbe Farbe; die Schreibweise trennt die beiden Rollen, die
# das Designsystem ohnehin trennt, und macht "genau eine Akzentflaeche je
# Bildschirm" ueberhaupt erst pruefbar.

PHONE_W = 390

NOTE = 'font-size: 12px; color: #5c636e; line-height: 1.4;'
CHIP = ('display: inline-flex; align-items: center; flex: 0 0 auto; padding: 8px 16px; '
        'border-radius: 999px; background: #1d2026; color: #9ba3af; font-weight: 600; '
        'font-size: 13px; white-space: nowrap;')
CHIP_AKTIV = CHIP.replace('color: #9ba3af;', 'color: #f2f4f7;') + ' box-shadow: inset 0 0 0 1px #d4ff3f;'

# Trefferflaechen in der Halle sind groesser als am Schreibtisch: die App
# wird einhaendig bedient, oft mit feuchten Haenden (Designsystem 1).
PRIMARY_XL = PRIMARY.replace('height: 44px;', 'height: 56px;') + ' width: 100%;'
SECONDARY_TEL = SECONDARY.replace('height: 40px;', 'height: 48px;')
SECONDARY_XL = SECONDARY_TEL + ' width: 100%;'
DESTRUCTIVE_XL = DESTRUCTIVE.replace('height: 40px;', 'height: 48px;') + ' width: 100%;'
FIELD_XL = FIELD.replace('min-height: 44px;', 'min-height: 52px;') + ' width: 100%;'

_SVG_PFADE.update({
    'qr': ('<rect x="3" y="3" width="7" height="7" rx="1"></rect>'
           '<rect x="14" y="3" width="7" height="7" rx="1"></rect>'
           '<rect x="3" y="14" width="7" height="7" rx="1"></rect>'
           '<path d="M14 14h3v3h-3z"></path><path d="M20.5 14v3"></path>'
           '<path d="M14 20.5h3"></path><path d="M20.5 20.5h.01"></path>'),
    'camera': ('<path d="M3 8a2 2 0 0 1 2-2h2l1.4-2h7.2L17 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5'
               'a2 2 0 0 1-2-2z"></path><circle cx="12" cy="12.5" r="3.5"></circle>'),
    'video': '<path d="M23 7l-7 5 7 5V7z"></path><rect x="1" y="5" width="15" height="14" rx="2"></rect>',
    'check': '<path d="M20 6L9 17l-5-5"></path>',
    'alert': ('<circle cx="12" cy="12" r="9"></circle><path d="M12 7.5v5.5"></path>'
              '<path d="M12 16.2h.01"></path>'),
    'plus': '<path d="M12 5v14"></path><path d="M5 12h14"></path>',
    'close': '<path d="M6 6l12 12"></path><path d="M18 6L6 18"></path>',
    'grip': ('<path d="M9 6h.01"></path><path d="M15 6h.01"></path><path d="M9 12h.01"></path>'
             '<path d="M15 12h.01"></path><path d="M9 18h.01"></path><path d="M15 18h.01"></path>'),
    'sliders': ('<path d="M4 7h9"></path><path d="M19 7h1"></path>'
                '<circle cx="16" cy="7" r="2.2"></circle>'
                '<path d="M4 17h4"></path><path d="M14 17h6"></path>'
                '<circle cx="11" cy="17" r="2.2"></circle>'),
    'search': '<circle cx="11" cy="11" r="7"></circle><path d="M20 20l-3.6-3.6"></path>',
    'tag': ('<path d="M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0l-7-7A2 2 0 0 1 3 12.2V5a2 2 0 0 1 2-2'
            'h7.2a2 2 0 0 1 1.4.6l7 7a2 2 0 0 1 0 2.8z"></path><path d="M7.6 7.6h.01"></path>'),
    'image': ('<rect x="3" y="4" width="18" height="16" rx="2"></rect>'
              '<circle cx="8.5" cy="9.5" r="1.5"></circle><path d="M21 15.5l-4.5-4.5-9 9"></path>'),
    'offline': ('<path d="M2 2l20 20"></path><path d="M5 12.6a11 11 0 0 1 4-2.6"></path>'
                '<path d="M1.6 8.6a16 16 0 0 1 5-3.2"></path><path d="M17.4 5.4a16 16 0 0 1 5 3.2"></path>'
                '<path d="M15 10a11 11 0 0 1 4 2.6"></path><path d="M8.8 16.3a6 6 0 0 1 6.4 0"></path>'
                '<path d="M12 20h.01"></path>'),
})

_TEL_CHIPS = ('Überblick', 'Kurse', 'Geräte', 'Tags', 'Leute', 'Einstellungen')


def telefon(hoehe, inhalt, aktiv='Geräte'):
    """Rahmen eines Telefon-Artboards: Studiokopf, Chipnavigation, Inhalt."""
    chips = ''.join('<span style="%s">%s</span>' % (CHIP_AKTIV if n == aktiv else CHIP, n)
                    for n in _TEL_CHIPS)
    return (HEAD
            + '<div style="min-height: %dpx; background: #0a0b0d;">' % hoehe
            + '<div style="border-bottom: 1px solid #2a2e36; background: #14161a; padding: 16px 0;">'
              '<div style="padding: 0 16px 12px;"><div style="font-size: 15px; font-weight: 800; '
              'letter-spacing: -0.02em; text-transform: uppercase;">Kraftwerk Nord</div></div>'
              '<div style="display: flex; gap: 8px; overflow-x: auto; padding: 0 16px;">'
            + chips + '</div></div>'
            + '<div style="padding: 20px 16px 40px; display: flex; flex-direction: column; '
              'gap: 16px;">' + inhalt + '</div></div>\n'
            + FOOT)


def telefon_voll(hoehe, inhalt):
    """Rahmen ohne Chipnavigation, fuer Sucher und Sheets, die den ganzen
    Bildschirm einnehmen."""
    return (HEAD
            + '<div style="min-height: %dpx; background: #0a0b0d; position: relative; '
              'overflow: hidden;">' % hoehe
            + inhalt + '</div>\n' + FOOT)


def kopfzeile(titel, unterzeile=None, zurueck_zu=None):
    """Titelblock eines Telefonschritts."""
    aus = ''
    if zurueck_zu:
        aus += '<a href="#" style="%s color: #5c636e;">%s</a>' % (LABEL, zurueck(zurueck_zu))
    aus += ('<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.03em; '
            'text-transform: uppercase; margin: 8px 0 0;">%s</h1>' % titel)
    if unterzeile:
        aus += '<p style="color: #9ba3af; font-size: 13px; margin: 6px 0 0;">%s</p>' % unterzeile
    return '<div>%s</div>' % aus


def schrittleiste(n, titel, von=6):
    """Fortschritt des Einrichtungsgangs. Bewusst ohne Akzent: der gehoert
    auf jedem Bildschirm der einen Hauptaktion, nicht der Wegmarke."""
    segmente = ''.join(
        '<div style="flex: 1; height: 3px; border-radius: 999px; background: %s;"></div>'
        % ('#f2f4f7' if i < n else '#2a2e36') for i in range(von))
    return ('<div style="display: flex; flex-direction: column; gap: 8px;">'
            '<div style="display: flex; gap: 4px;">%s</div>'
            '<span style="%s color: #9ba3af;">Schritt %d von %d &middot; %s</span></div>'
            % (segmente, LABEL, n, von, titel))


def balken(prozent, hoehe=6):
    """Fortschrittsbalken. Akzent als Wert, nicht als Aktionsflaeche --
    daher background-color statt background (Konvention oben)."""
    return ('<div style="height: %dpx; border-radius: 999px; background: #1d2026; overflow: hidden;">'
            '<div style="width: %s%%; height: 100%%; background-color: #d4ff3f;"></div></div>'
            % (hoehe, prozent))


def tkarte(inhalt, rand='#2a2e36', flaeche='#14161a', gestrichelt=False):
    """Karte in Telefonbreite."""
    stil = 'dashed' if gestrichelt else 'solid'
    return ('<div style="border: 1px %s %s; border-radius: 12px; background: %s; padding: 16px; '
            'display: flex; flex-direction: column; gap: 12px;">%s</div>'
            % (stil, rand, flaeche, inhalt))


def antwort(titel, text, aktionen='', rand='#2a2e36', symbol=None, flaeche='#14161a'):
    """Antwortkarte des Zustandsblatts: was ist, und was jetzt gilt."""
    kopf = titel
    if symbol:
        kopf = ('<span style="display: inline-flex; align-items: center; gap: 8px;">%s%s</span>'
                % (symbol, titel))
    unten = ''
    if aktionen:
        unten = ('<div style="display: flex; flex-direction: column; gap: 8px;">%s</div>' % aktionen)
    return ('<div style="border: 1px solid %s; border-radius: 12px; background: %s; padding: 16px; '
            'display: flex; flex-direction: column; gap: 12px;">'
            '<div><div style="font-size: 16px; font-weight: 600;">%s</div>'
            '<div style="%s margin-top: 4px;">%s</div></div>%s</div>'
            % (rand, flaeche, kopf, NOTE, text, unten))


def feld(label, wert, hinweis=None, gefuellt=False):
    """Formularzeile am Telefon: Beschriftung, Feld, optional ein Hinweis."""
    farbe = '#f2f4f7' if gefuellt else '#5c636e'
    h = ('<span style="%s">%s</span>' % (NOTE, hinweis)) if hinweis else ''
    return ('<div style="display: flex; flex-direction: column; gap: 6px;">'
            '<span style="%s color: #9ba3af;">%s</span>'
            '<div style="%s color: %s;">%s</div>%s</div>'
            % (LABEL, label, FIELD_XL, farbe, wert, h))


def sucher(hinweis, titel='Tag scannen'):
    """Kamerasucher mit Eckenrahmen. Muster aus member/TrainingScan.dc.html;
    dort eine CSS-Klasse, hier inline -- Artboards teilen zur Laufzeit nichts."""
    ecke = 'position: absolute; width: 34px; height: 34px; border: 3px solid #d4ff3f;'
    ecken = (
        '<div style="%s top: 0; left: 0; border-right: none; border-bottom: none; '
        'border-radius: 14px 0 0 0;"></div>'
        '<div style="%s top: 0; right: 0; border-left: none; border-bottom: none; '
        'border-radius: 0 14px 0 0;"></div>'
        '<div style="%s bottom: 0; left: 0; border-right: none; border-top: none; '
        'border-radius: 0 0 0 14px;"></div>'
        '<div style="%s bottom: 0; right: 0; border-left: none; border-top: none; '
        'border-radius: 0 0 14px 0;"></div>' % (ecke, ecke, ecke, ecke))
    return (
        '<div style="position: absolute; inset: 0; background: linear-gradient(168deg, '
        '#232730 0%%, #14161a 55%%, #0a0b0d 100%%);"></div>'
        '<div style="position: relative; height: 54px;"></div>'
        '<div style="position: relative; height: 52px; padding: 0 20px; display: flex; '
        'align-items: center; justify-content: space-between;">'
        '<span style="font-size: 17px; font-weight: 800; letter-spacing: -0.01em;">%s</span>'
        '<div style="width: 44px; height: 44px; border-radius: 50%%; background: rgba(10,11,13,.6); '
        'display: flex; align-items: center; justify-content: center;">%s</div></div>'
        '<div style="position: relative; height: 400px; display: flex; align-items: center; '
        'justify-content: center;"><div style="position: relative; width: 236px; height: 236px;">%s'
        '<div style="position: absolute; left: 12px; right: 12px; top: 50%%; height: 2px; '
        'background-color: #d4ff3f; opacity: .55;"></div></div></div>'
        '<div style="position: relative; padding: 0 32px 20px; text-align: center;">'
        '<div style="font-size: 15px; line-height: 1.5; color: #9ba3af;">%s</div></div>'
        % (titel, svg('close', 19, '#f2f4f7'), ecken, hinweis))


def sheet(inhalt, hoehe_dahinter=280):
    """Bottom-Sheet ueber abgedunkeltem Grund. Muster aus
    member/GeraetUebungWechseln.dc.html."""
    return ('<div style="height: %dpx;"></div>'
            '<div style="position: absolute; inset: 0; background: rgba(10,11,13,.74);"></div>'
            '<div style="position: absolute; left: 0; right: 0; bottom: 0; background: #1d2026; '
            'border-top: 1px solid #2a2e36; border-radius: 22px 22px 0 0; padding: 12px 20px 26px; '
            'display: flex; flex-direction: column; gap: 16px;">'
            '<div style="width: 40px; height: 4px; border-radius: 2px; background: #2a2e36; '
            'align-self: center;"></div>%s</div>' % (hoehe_dahinter, inhalt))
