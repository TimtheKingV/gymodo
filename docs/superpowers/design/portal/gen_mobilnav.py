# -*- coding: utf-8 -*-
"""Das Hamburger-Menu -- Befund 45 anders geloest, als die Notiz es vorschlug.

Bisher zeigten zwoelf der siebzehn Telefon-Artboards eine Chipnavigation
(Studioname plus seitlich scrollende Pillenreihe), die es im Schreibtisch-
Code nur unter @media (max-width: 900px) gibt und im Gang durch die Halle
nirgends -- der Gang lag ausserhalb der Schale, die die Pillenreihe traegt.
Die Notiz empfahl: so lassen, weil der Gang mit der Schrittleiste schon
eine Navigation hat und zwei uebereinander auf 390 px schlechter waeren
als eine.

Diese Runde loest den Widerspruch anders: ein Menu ersetzt die Pillenreihe
ueberall, auch am Schreibtisch. telefon() (build.py) zeichnet es jetzt
statt der Chips; dieselbe Schublade (drawer()) deckt beide Seiten ab, und
in der Halle bleibt die Schrittleiste die einzige *sichtbare* Navigation --
das Menu ist eine Ebene darunter, fuer den seltenen Fall, dass jemand
mitten im Gang zu Tags oder Leute muss.

Drei Artboards zeigen das Muster:
- SchreibtischMobil / SchreibtischMobilMenu: der uebliche Fall, den es im
  Code noch gar nicht als Artboard gab -- die mobile Fassung des
  Ueberblicks lief bisher rein aus der CSS-Media-Query der Rail hervor.
- HalleMobilMenu: dieselbe Schublade ueber einem Bildschirm des Gangs
  (Was steht hier?, Schritt 1) -- der Beleg, dass beide Seiten jetzt
  dieselbe Navigation teilen, statt zwei verschiedene zu bauen.
"""
from build import (LABEL, NOTE, PRIMARY_XL, SECONDARY_TEL, FIELD_XL,
                    CARD, drawer, mobilkopf, schreibe, svg, HEAD, FOOT)

H2 = 'font-size: 16px; font-weight: 600;'


def rahmen(hoehe, inhalt, offen=None):
    """Wie telefon() (build.py), nur mit optional geoeffneter Schublade --
    position: relative traegt drawer()s absolute Kinder."""
    koerper = (mobilkopf()
               + '<div style="padding: 20px 16px 40px; display: flex; '
                 'flex-direction: column; gap: 16px;">' + inhalt + '</div>')
    if offen is not None:
        koerper += drawer(offen)
    return (HEAD
            + '<div style="min-height: %dpx; background: #0a0b0d; position: relative;">' % hoehe
            + koerper + '</div>\n' + FOOT)


def abschnitt(titel, zeilen, rechts=''):
    kopf = ('<div style="padding: 14px 16px; border-bottom: 1px solid #2a2e36; display: flex; '
            'align-items: baseline; justify-content: space-between; gap: 12px;">'
            '<h2 style="%s color: #9ba3af; margin: 0;">%s</h2>%s</div>' % (LABEL, titel, rechts))
    return '<section style="%s">%s%s</section>' % (CARD, kopf, ''.join(zeilen))


def tzeile(haupt, meta, rechts='', letzte=False, faint=False):
    rand = '' if letzte else 'border-bottom: 1px solid #2a2e36;'
    farbe = '#5c636e' if faint else '#9ba3af'
    r = ('<div style="flex-shrink: 0;">%s</div>' % rechts) if rechts else ''
    return ('<div style="padding: 12px 16px; %s display: flex; align-items: center; '
            'justify-content: space-between; gap: 12px;"><div style="min-width: 0;">'
            '<div style="font-weight: 600;">%s</div>'
            '<div style="font-size: 12px; color: %s; margin-top: 2px;">%s</div></div>%s</div>'
            % (rand, haupt, farbe, meta, r))


def kachel(zahl, label, warn=False):
    rand = '#ffb020' if warn else '#2a2e36'
    farbe = '#ffb020' if warn else '#f2f4f7'
    labelfarbe = '#ffb020' if warn else '#9ba3af'
    return ('<div style="border: 1px solid %s; border-radius: 12px; background: #14161a; '
            'padding: 16px;"><div style="font-size: 26px; font-weight: 800; letter-spacing: '
            '-0.03em; line-height: 1; color: %s;">%s</div>'
            '<div style="%s color: %s; margin-top: 8px;">%s</div></div>'
            % (rand, farbe, zahl, LABEL, labelfarbe, label))


# --------------------------------------------------- 1/2 Schreibtisch mobil
# Werte aus Main.dc.html (dieselbe Demo-Uebersicht), nur auf zwei Spalten
# umgebrochen -- kein eigener Bestand, damit beide Artboards zueinander
# und zum Main-Artboard passen.
ueberblick = (
    '<div><h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.03em; '
    'text-transform: uppercase; margin: 8px 0 0;">Überblick</h1>'
    '<p style="color: #9ba3af; font-size: 13px; margin: 6px 0 0;">Letzte 30 Tage. Studioweite '
    'Summen — welches Mitglied was trainiert hat, zeigt das Portal nirgends.</p></div>'
    '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px;">'
    + kachel('2 / 4', 'Geräte erreichbar')
    + kachel('23', 'Mitglieder aktiv')
    + kachel('412', 'Sätze erfasst')
    + kachel('7', 'Probleme gemeldet', warn=True)
    + '</div>'
    + abschnitt('Was noch fehlt', [
        tzeile('1 Gerät ohne Tag', 'Für Mitglieder nicht auffindbar',
               '<a href="#" style="%s">Scannen</a>' % SECONDARY_TEL),
        tzeile('1 Übung ohne Video', 'Nutzbar, nur ohne Anleitung',
               '<a href="#" style="%s">Ansehen</a>' % SECONDARY_TEL),
        tzeile('1 Modell unvollständig', 'Brustpresse &middot; kein Foto, keine Parameter',
               '<a href="#" style="%s">Ansehen</a>' % SECONDARY_TEL, letzte=True, faint=True),
    ])
    + '<p style="%s margin: 0;">gymodo misst nichts. Alles hier ist gezählt, was Mitglieder '
      'selbst bestätigt haben.</p>' % NOTE)
schreibe('SchreibtischMobil.dc.html', rahmen(1180, ueberblick))
schreibe('SchreibtischMobilMenu.dc.html', rahmen(1180, ueberblick, offen='ueberblick'))


# ---------------------------------------------------------- 3 Halle mobil
# Derselbe Bildschirm wie TelefonModell.dc.html (Schritt 1), mit offener
# Schublade -- der Beleg, dass der Gang dieselbe Navigation traegt wie der
# Schreibtisch, ohne eine zweite Leiste ueber der Schrittleiste zu brauchen.
schrittleiste_1 = (
    '<div style="display: flex; flex-direction: column; gap: 8px;">'
    '<div style="display: flex; gap: 4px;">'
    '<div style="flex: 1; height: 3px; border-radius: 999px; background: #f2f4f7;"></div>'
    + ''.join('<div style="flex: 1; height: 3px; border-radius: 999px; '
              'background: #2a2e36;"></div>' for _ in range(5))
    + '</div><span style="%s color: #9ba3af;">Schritt 1 von 6 &middot; Modell</span></div>'
    % LABEL)
halle_kopf = (
    '<div><a href="#" style="%s color: #5c636e;"><span style="display: inline-flex; '
    'align-items: center; gap: 6px;">%s Einrichten</span></a>'
    '<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.03em; text-transform: '
    'uppercase; margin: 8px 0 0;">Was steht hier?</h1></div>'
    % (LABEL, svg('arrow-left', 14)))
halle_modell = (
    schrittleiste_1 + halle_kopf
    + '<div style="%s color: #5c636e;">%s Modell suchen …</div>' % (FIELD_XL, svg('search', 18, '#5c636e'))
    + abschnitt('Modelle im Studio', [
        tzeile('Latzug', 'Technogym &middot; 2 Geräte &middot; 2 Übungen &middot; 2 Parameter',
               '<a href="#" style="%s">Wählen</a>' % SECONDARY_TEL),
        tzeile('Beinpresse', 'Gym80 &middot; 2 Geräte &middot; 1 Übung &middot; 3 Parameter',
               '<a href="#" style="%s">Wählen</a>' % SECONDARY_TEL),
        tzeile('Brustpresse', 'Ohne Hersteller &middot; noch kein Gerät &middot; kein Foto',
               '<a href="#" style="%s">Wählen</a>' % SECONDARY_TEL, letzte=True, faint=True),
    ])
    + '<div style="border: 1px dashed #2a2e36; border-radius: 12px; background: #14161a; '
      'padding: 16px; display: flex; flex-direction: column; gap: 12px;">'
      '<div style="display: flex; align-items: center; gap: 12px;">%s'
      '<div style="min-width: 0;"><div style="%s">Noch nicht dabei</div>'
      '<div style="%s margin-top: 2px;">Ein Modell beschreibt den Gerätetyp. Zwei Kabelzüge '
      'nebeneinander sind ein Modell und zwei Geräte.</div></div></div>'
      '<a href="#" style="%s">Neues Modell anlegen</a></div>'
      % (svg('plus', 24, '#5c636e'), H2, NOTE, PRIMARY_XL))
schreibe('HalleMobilMenu.dc.html', rahmen(900, halle_modell, offen=''))
