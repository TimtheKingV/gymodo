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
            nav_item('Kurse', '9 diese Woche', active == 'kurse'),
        ])
        + gruppe('Katalog', [
            nav_item('Geräte', '16 · 14 erreichbar', active == 'geraete'),
            nav_item('Tags', '2 vorrätig', active == 'tags'),
        ])
        + gruppe('Verwaltung', [
            nav_item('Leute', '24 Mitglieder · 2 Trainer', active == 'leute'),
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
