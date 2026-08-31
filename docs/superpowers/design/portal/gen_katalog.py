# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, CARD, HEADROW, PRIMARY, SECONDARY,
                   DESTRUCTIVE, FIELD, BADGE, SEC_TITLE, portal, titel,
                   schreibe, zeile, zurueck)

NOTE = 'font-size: 12px; color: #5c636e;'


def reiter(name, meta, aktiv=False):
    rand = '2px solid #d4ff3f' if aktiv else '2px solid transparent'
    farbe = '#f2f4f7' if aktiv else '#9ba3af'
    meta_html = ''
    if meta:
        meta_html = ('<span style="display: block; font-size: 12px; color: #5c636e; '
                     'margin-top: 2px;">%s</span>' % meta)
    return ('<a href="#" style="padding: 12px 16px; border-bottom: %s; color: %s;">'
            '<span style="display: block; font-weight: 600;">%s</span>%s</a>'
            % (rand, farbe, name, meta_html))


# ---------------------------------------------------------------- Geräte
# Modelle und Geräte sind ein Bildschirm: die Rail listet jetzt nur noch
# "Geräte" -- die einzelnen Geräteinstanzen sitzen unter dem jeweiligen
# Modell (Reiter "Einzelne Geräte" auf Modell.dc.html), nicht mehr auf
# einer eigenen Rail-Ebene.
geraete = titel(
    'Geräte',
    'Ein Modell beschreibt den Gerätetyp. Die einzelnen Geräte im Raum sind Instanzen davon — '
    'zwei Kabelzüge nebeneinander sind ein Modell und zwei Geräte.')
geraete += '<section style="%s margin-top: 32px;">' % CARD
geraete += ('<div style="%s"><h2 style="%s">Alle Gerätemodelle</h2>'
           '<a href="#" style="%s">Modell anlegen</a></div>' % (HEADROW, SEC_TITLE, PRIMARY))
geraete += zeile('Latzug',
                 'Technogym · 2 Geräte, 1 erreichbar · 2 Übungen, 1 mit Video · Foto',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY)
geraete += zeile('Beinpresse',
                 'Gym80 · 2 Geräte, 1 erreichbar · 1 Übung, 1 mit Video · Foto',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY)
geraete += zeile('Brustpresse',
                 '<span style="color: #5c636e;">Ohne Hersteller · noch kein Gerät · keine Übung · kein Foto</span>',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY, letzte=True)
geraete += '</section>'
schreibe('Geraete.dc.html', portal('geraete', 900, geraete))


# ---------------------------------------------------------------- Modell
# Der Editor eines Gerätemodells. Vier Reiter, aber nie mehr als einer
# gleichzeitig sichtbar -- so bleibt es bei genau einer Akzentfläche je
# Bildschirm, auch wenn der Editor mehrere Formulare enthält. Dieser
# Artboard zeigt den Reiter "Einzelne Geräte": die Zählmechanik, mit der
# ein Trainer Geräte im Bestand hoch-, aber nie herunterzählt.
modell = ('<a href="#" style="%s color: #5c636e;">%s</a>'
          '<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.025em; '
          'text-transform: uppercase; margin: 8px 0 0;">Latzug</h1>'
          '<p style="color: #9ba3af; margin: 8px 0 0;">Technogym · Schritt 2,5 kg · ab 5,0 kg bis 100,0 kg</p>'
          % (LABEL, zurueck('Geräte')))

modell += '<div style="display: flex; gap: 4px; margin-top: 24px; border-bottom: 1px solid #2a2e36;">'
modell += reiter('Stammdaten', None)
modell += reiter('Einstellungen', '2 Parameter')
modell += reiter('Übungen', '2 · 1 mit Video')
modell += reiter('Einzelne Geräte', '2 · 1 ohne Tag', aktiv=True)
modell += '</div>'

modell += ('<div style="display: flex; align-items: center; justify-content: space-between; '
          'gap: 16px; margin-top: 24px;">'
          '<div><span style="%s color: #9ba3af;">Anzahl im Studio</span>'
          '<div style="font-size: 34px; font-weight: 800; letter-spacing: -0.03em; line-height: 1; '
          'margin-top: 4px;">2</div></div>'
          '<a href="#" style="%s">Geräte anlegen</a></div>'
          % (LABEL, PRIMARY))

modell += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 16px 0 0; '
          'max-width: 62ch;">Erhöhen legt die fehlenden Geräte an — Nummer und Tag vergibst du danach. '
          'Verringern gibt es nicht: ein Gerät wird stillgelegt, einzeln, mit Namen.</p>')

modell += '<section style="%s margin-top: 20px;">' % CARD
modell += '<div style="%s"><h2 style="%s">Geräte</h2></div>' % (HEADROW, SEC_TITLE)
modell += zeile('13', 'Rückwand mitte · kein aktiver Tag', '', meta_faint=True)
modell += zeile('12', 'Rückwand links · erreichbar', '', letzte=True)
modell += '</section>'
schreibe('Modell.dc.html', portal('geraete', 780, modell))


# ---------------------------------------------------------------- Tags
tags = titel('Tags',
             'Ein Tag klebt am Gerät und wird getippt. Sein Token steht genau einmal beim Anlegen '
             'auf dem Bildschirm — gespeichert wird nur dessen Prüfsumme.')

tags += '<section style="%s margin-top: 32px; border-color: #d4ff3f;">' % CARD
tags += ('<div style="%s border-color: #2a2e36;"><h2 style="%s">Gerade angelegt — nur jetzt sichtbar</h2></div>'
         % (HEADROW, SEC_TITLE))
tags += ('<div style="padding: 20px; display: flex; flex-direction: column; gap: 12px;">'
         '<code style="font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; '
         'font-size: 18px; letter-spacing: 0.08em; background: #0f1114; border: 1px solid #2a2e36; '
         'border-radius: 10px; padding: 16px; display: block;">kQ7mR2xPvL9nD4tYbA</code>'
         '<span style="%s">Schreib ihn auf den NFC-Tag oder drucke den QR-Code. Danach ist er nicht '
         'mehr abrufbar — geht er verloren, legst du einen neuen an und sperrst diesen.</span>'
         '<div style="display: flex; gap: 12px;">'
         '<a href="#" style="%s">QR-Code drucken</a>'
         '<a href="#" style="%s">Kopieren</a>'
         '<a href="#" style="%s">Fertig</a></div></div>'
         % (NOTE, PRIMARY, SECONDARY, SECONDARY))
tags += '</section>'

tags += '<section style="%s margin-top: 24px;">' % CARD
tags += ('<div style="%s"><h2 style="%s">Alle Tags</h2>'
         '<a href="#" style="%s">Tag auf Vorrat</a></div>' % (HEADROW, SEC_TITLE, SECONDARY))
aktiv = '<span style="%s color: #f2f4f7; border-color: #5c636e;">aktiv</span>' % BADGE
vorraetig = '<span style="%s">vorrätig</span>' % BADGE
gesperrt = '<span style="%s color: #ff5a4e; border-color: #ff5a4e;">gesperrt</span>' % BADGE
tags += zeile('%s &nbsp; 12 — Latzug' % aktiv, 'Angelegt Mo., 31. August 2026',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE)
tags += zeile('%s &nbsp; 7 — Beinpresse' % aktiv, 'Angelegt Mo., 31. August 2026',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE)
tags += zeile('%s &nbsp; ohne Gerät' % vorraetig, 'Angelegt Mo., 31. August 2026',
              '<div style="%s width: 200px; justify-content: space-between;">Gerät wählen …</div>'
              '<a href="#" style="%s">Zuweisen</a>' % (FIELD, SECONDARY))
tags += zeile('%s &nbsp; ohne Gerät' % gesperrt,
              'Angelegt Fr., 15. August 2026 · bleibt als Nachweis stehen', '',
              letzte=True, meta_faint=True)
tags += '</section>'
schreibe('Tags.dc.html', portal('tags', 940, tags))
