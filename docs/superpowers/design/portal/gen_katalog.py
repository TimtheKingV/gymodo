# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, CARD, HEADROW, PRIMARY, SECONDARY,
                   DESTRUCTIVE, FIELD, BADGE, SEC_TITLE, portal, titel,
                   schreibe, zeile, zurueck, reiter)

NOTE = 'font-size: 12px; color: #5c636e;'


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

modell += reiter([
    ('Stammdaten', None),
    ('Einstellungen', '2 Parameter'),
    ('Übungen', '2 · 1 mit Video'),
    ('Einzelne Geräte', '2 · 1 ohne Tag'),
], 'Einzelne Geräte')

modell += ('<div style="display: flex; align-items: center; justify-content: space-between; '
          'gap: 16px; margin-top: 24px;">'
          '<div><span style="%s color: #9ba3af;">Anzahl im Studio</span>'
          '<div style="font-size: 34px; font-weight: 800; letter-spacing: -0.03em; line-height: 1; '
          'margin-top: 4px;">2</div></div>'
          '<a href="#" style="%s">Geräte anlegen</a></div>'
          % (LABEL, PRIMARY))

modell += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 16px 0 0; '
          'max-width: 62ch;">Erhöhen legt die fehlenden Geräte an — Nummer, Standort und Tag '
          'vergibst du danach am Gerät, mit dem Telefon. Verringern gibt es nicht: ein Gerät wird '
          'stillgelegt, einzeln, mit Namen.</p>')

modell += '<section style="%s margin-top: 20px;">' % CARD
modell += '<div style="%s"><h2 style="%s">Geräte</h2></div>' % (HEADROW, SEC_TITLE)
modell += zeile('13', 'Rückwand mitte · kein aktiver Tag',
                '<a href="#" style="%s">Tag scannen</a>' % SECONDARY, meta_faint=True)
modell += zeile('12', 'Rückwand links · erreichbar',
                '<a href="#" style="%s">Tag ersetzen</a>' % SECONDARY, letzte=True)
modell += '</section>'
schreibe('Modell.dc.html', portal('geraete', 800, modell))


# ---------------------------------------------------------------- Tags
# Das Studio erzeugt keine Tags mehr. Sie sind ein physisches Erzeugnis --
# NFC-Chip und aufgedruckter QR auf derselben /t/<token>-Adresse -- und
# kommen chargenweise vom Betreiber. Die Seite ist damit eine Auskunft und
# kein Formular: sie hat bewusst keine Akzentflaeche, weil sie nichts anlegt.
tags = titel('Tags',
             'Ein Tag klebt am Gerät und wird gescannt oder angetippt. Das Studio erzeugt keine — '
             'Tags kommen als Lieferung. Welcher Tag an welchem Gerät hängt, entscheidet der Scan '
             'am Gerät.')

tags += '<section style="%s margin-top: 32px;">' % CARD
tags += '<div style="%s"><h2 style="%s">Lieferungen</h2></div>' % (HEADROW, SEC_TITLE)
tags += zeile('Charge 7',
              'Mi., 12. August 2026 · 100 Gerätetags · <strong>87 vorrätig</strong>, 12 geklebt, '
              '1 gesperrt', '')
tags += zeile('Charge 8',
              'Mi., 12. August 2026 · 5 Aushangschilder · <strong>4 vorrätig</strong>, 1 hängt',
              '', letzte=True)
tags += '</section>'
tags += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 16px 0 0; '
         'max-width: 62ch;">Der Vorrat steht als Zahl. Ein vorrätiger Tag lässt sich keinem '
         'Aufkleber in der Packung zuordnen — 87 gleichlautende Zeilen wären keine Auskunft, '
         'sondern Lärm. Benennbar wird ein Tag erst durch den Scan.</p>')

aktiv = '<span style="%s color: #f2f4f7; border-color: #5c636e;">aktiv</span>' % BADGE
gesperrt = '<span style="%s color: #ff5a4e; border-color: #ff5a4e;">gesperrt</span>' % BADGE

tags += '<section style="%s margin-top: 24px;">' % CARD
tags += ('<div style="%s"><h2 style="%s">Geklebte Geräte-Tags</h2>'
         '<span style="color: #5c636e; font-size: 12px;">12 von 100</span></div>'
         % (HEADROW, SEC_TITLE))
tags += zeile('%s &nbsp; 12 — Latzug' % aktiv, 'Charge 7 · verbunden Mo., 31. August 2026',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE)
tags += zeile('%s &nbsp; 7 — Beinpresse' % aktiv, 'Charge 7 · verbunden Mo., 31. August 2026',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE)
tags += zeile('%s &nbsp; 8 — Beinpresse' % gesperrt,
              'Charge 7 · gesperrt Sa., 15. August 2026 · bleibt als Nachweis stehen', '',
              letzte=True, meta_faint=True)
tags += '</section>'
tags += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 16px 0 0; '
         'max-width: 62ch;">Ein Gerät ohne Tag ist für Mitglieder nicht auffindbar. Verbunden wird '
         'am Gerät, mit dem Telefon — ein zerkratzter Tag wird dort auch ersetzt.</p>')

tags += '<section style="%s margin-top: 24px;">' % CARD
tags += '<div style="%s"><h2 style="%s">Aushang</h2></div>' % (HEADROW, SEC_TITLE)
tags += zeile('%s &nbsp; Eingang' % aktiv,
              'Charge 8 · hängt seit Sa., 15. August 2026 · Beitritt durch Scannen',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE, letzte=True)
tags += '</section>'
tags += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 16px 0 0; '
         'max-width: 62ch;">Ein Aushang hängt an keinem Gerät — wer ihn scannt, wird Mitglied. '
         'Sperren macht genau dieses Schild ungültig; häng eins aus der Lieferung nach.</p>')
schreibe('Tags.dc.html', portal('tags', 1020, tags))
