# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, CARD, HEADROW, PRIMARY, SECONDARY,
                   DESTRUCTIVE, FIELD, BADGE, SEC_TITLE, portal, titel,
                   schreibe, svg, zeile, zurueck, reiter)

NOTE = 'font-size: 12px; color: #5c636e;'


def modell_kopf(aktiv):
    """Kopf und Reiterleiste, geteilt von allen vier Modell-Reitern --
    Rueckweg, Titel und Reiterleiste stehen im echten Code im Layout
    (geraete/[modelId]/layout.tsx), nicht in den einzelnen Reiterseiten,
    darum hier einmal statt viermal hingeschrieben."""
    out = ('<a href="#" style="%s color: #5c636e;">%s</a>'
           '<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.025em; '
           'text-transform: uppercase; margin: 8px 0 0;">Latzug</h1>'
           '<p style="color: #9ba3af; margin: 8px 0 0;">Technogym · Schritt 2,5 kg · ab 5,0 kg bis 100,0 kg</p>'
           % (LABEL, zurueck('Geräte')))
    out += reiter([
        ('Stammdaten', None),
        ('Einstellungen', '2 Parameter'),
        ('Übungen', '2 · 1 mit Video'),
        ('Einzelne Geräte', '2 · 1 ohne Tag'),
    ], aktiv)
    return out


# Feld/Abschnitt fuer den Schreibtisch -- dieselbe Form wie kopf()/feld()/
# abschnitt() in gen_studio.py, hier noch einmal statt importiert: die
# Generator-Dateien teilen zur Laufzeit nichts miteinander, nur mit build.py
# (Konvention aus gen_telefon.py/build.py: tzeile() dort ist ebenfalls eine
# eigene, schmalere Fassung von zeile() hier, nicht ein Import).
def feld(label, wert, auswahl=False):
    innen = FIELD
    if auswahl:
        innen += ' justify-content: space-between;'
    chevron = svg('chevron-down', 18, '#5c636e') if auswahl else ''
    return ('<div style="display: flex; flex-direction: column; gap: 8px;">'
            '<span style="%s color: #9ba3af;">%s</span>'
            '<div style="%s">%s%s</div></div>' % (LABEL, label, innen, wert, chevron))


def abschnitt(titel_text, inhalt):
    return ('<section style="%s margin-top: 24px;">'
            '<div style="%s"><h2 style="%s">%s</h2></div>%s</section>'
            % (CARD, HEADROW, SEC_TITLE, titel_text, inhalt))


# Vorgabe-Zeile: eine Zeile der Scrollliste unter "Parameter anlegen". Ring
# statt Flaeche fuer den gewaehlten Zustand -- dieselbe Konvention wie der
# aktive Chip in gen_telefon.py (box-shadow inset), nicht eine zweite
# Akzentflaeche neben dem Absendeknopf.
def vorgabe_zeile(name, meta, aktiv=False, letzte=False):
    rand = '' if letzte else 'border-bottom: 1px solid #2a2e36;'
    ring = ' box-shadow: inset 0 0 0 1px #d4ff3f;' if aktiv else ''
    haken = svg('check', 18, '#d4ff3f') if aktiv else ''
    return (
        '<button type="button" style="width: 100%%; text-align: left; background: none; border: none; '
        'display: flex; align-items: center; justify-content: space-between; gap: 12px; '
        'padding: 12px 16px; %s color: #f2f4f7; cursor: pointer;%s">'
        '<div style="min-width: 0;"><div style="font-weight: 600;">%s</div>'
        '<div style="font-size: 12px; color: #9ba3af; margin-top: 2px;">%s</div></div>'
        '<span style="flex-shrink: 0; width: 18px; height: 18px; display: flex; align-items: center; '
        'justify-content: center;">%s</span></button>'
        % (rand, ring, name, meta, haken))


# Scroll-Rad statt Chipreihe: ein senkrechtes Zahlenrad je Spalte (wie ein
# iOS-Picker), eine gemeinsame Auswahlleiste (zwei Linien) ueber alle
# Spalten hinweg -- ein Bedienelement, keine vier. Jede Spalte bekommt
# GENAU 5 Zeilen; die mittlere ist die Auswahl. Laeuft eine Werteliste am
# Rand aus (z. B. Schritt hat nur vier Werte, "1" steht ganz vorn), bleiben
# die fehlenden Randzeilen leer -- so wie ein echtes Rad dort ausliefe.
_RAD_ZEILENHOEHE = 40
_RAD_KOPFHOEHE = 32


def _rad_zeile(text, gewaehlt):
    return (
        '<div style="height: %dpx; display: flex; align-items: center; justify-content: center; '
        'font-size: %s; font-weight: %s; color: %s;">%s</div>'
        % (_RAD_ZEILENHOEHE, '20px' if gewaehlt else '14px', '800' if gewaehlt else '500',
           '#f2f4f7' if gewaehlt else '#5c636e', text))


def rad_spalte(label, werte, letzte=False):
    """werte: genau 5 Eintraege (Text, gewaehlt); der dritte ist die Mitte."""
    rand = '' if letzte else 'border-right: 1px solid #2a2e36;'
    zeilen = ''.join(_rad_zeile(text, gewaehlt) for text, gewaehlt in werte)
    return (
        '<div style="flex: 1; min-width: 0; %s"><div style="height: %dpx; display: flex; '
        'align-items: flex-end; justify-content: center; padding-bottom: 4px; %s color: #9ba3af; '
        'text-align: center;">%s</div>%s</div>'
        % (rand, _RAD_KOPFHOEHE, LABEL, label, zeilen))


def rad(spalten):
    """spalten: Liste von (label, werte). Eine Auswahlleiste (zwei Linien)
    liegt ueber allen Spalten auf Hoehe der mittleren Zeile."""
    hoehe = _RAD_KOPFHOEHE + _RAD_ZEILENHOEHE * 5
    leiste_oben = _RAD_KOPFHOEHE + _RAD_ZEILENHOEHE * 2
    return (
        '<div style="border: 1px solid #2a2e36; border-radius: 12px; background: #0f1114; '
        'position: relative; height: %dpx;">'
        '<div style="display: flex; height: 100%%;">%s</div>'
        '<div style="position: absolute; left: 0; right: 0; top: %dpx; height: %dpx; '
        'border-top: 1px solid #2a2e36; border-bottom: 1px solid #2a2e36; pointer-events: none;">'
        '</div></div>'
        % (hoehe, ''.join(rad_spalte(label, werte, letzte=(i == len(spalten) - 1))
                          for i, (label, werte) in enumerate(spalten)),
           leiste_oben, _RAD_ZEILENHOEHE))


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
                 'Technogym · 2 Geräte, 1 erreichbar · 2 Übungen, 1 mit Video · Foto · 2 Parameter',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY)
geraete += zeile('Beinpresse',
                 'Gym80 · 2 Geräte, 1 erreichbar · 1 Übung, 1 mit Video · Foto · 3 Parameter',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY)
geraete += zeile('Brustpresse',
                 '<span style="color: #5c636e;">Ohne Hersteller · noch kein Gerät · keine Übung · kein Foto, keine Parameter</span>',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY, letzte=True)
geraete += '</section>'
schreibe('Geraete.dc.html', portal('geraete', 900, geraete))


# ---------------------------------------------------------------- Modell
# Der Editor eines Gerätemodells. Vier Reiter, aber nie mehr als einer
# gleichzeitig sichtbar -- so bleibt es bei genau einer Akzentfläche je
# Bildschirm, auch wenn der Editor mehrere Formulare enthält. Dieser
# Artboard zeigt den Reiter "Einzelne Geräte": die Zählmechanik, mit der
# ein Trainer Geräte im Bestand hoch-, aber nie herunterzählt.
modell = modell_kopf('Einzelne Geräte')

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


# ------------------------------------------------- Modell, Einstellungen
# Reiter "Einstellungen" -- bekommt hier zum ersten Mal ein eigenes
# Artboard (bisher zeichnete nur "Einzelne Geräte" oben eines; die beiden
# anderen Nicht-Stammdaten-Reiter fehlten ganz). Inhalt nach
# geraete/[modelId]/einstellungen/page.tsx: Erklaersatz unter der
# Reiterleiste, bestehende Parameter mit Loeschen als Nebenaktion, das
# Anlegeformular offen darunter.
#
# Neu gegenueber dem echten ParameterFormular.tsx: eine Scrollliste mit
# Vorgaben vor dem Formular selbst, auf Nutzerwunsch -- Schluessel, Art,
# Bereich und Einheit sind bei "Wiederholungen"/"Gewicht"/"Winkel" schon
# gesetzt, nur die Beschriftung bleibt zum Anpassen. "Gewicht" rechnet
# seinen Bereich aus den Modell-Stammdaten aus (Schritt und niedrigste
# Einstellung stehen dort schon, siehe ModellNeuFormular.tsx) statt sie
# ein zweites Mal abzufragen; nur die obere Grenze (150 kg) ist fest.
# "Eigener Parameter" bleibt der Fluchtweg fuer alles, was keine Vorgabe
# trifft -- das heutige Formular unveraendert, nur ans Ende gerueckt.
modell_einstellungen = modell_kopf('Einstellungen')
modell_einstellungen += ('<p style="color: #9ba3af; margin: 20px 0 0; max-width: 62ch;">'
                         'Was ein Mitglied am Gerät einstellt und sich merken soll.</p>')

modell_einstellungen += abschnitt('Einstellparameter', (
    zeile('Sitzhöhe', 'Zahl · 1 – 8 · Schritt 1',
          '<a href="#" style="%s">Löschen</a>' % DESTRUCTIVE)
    + zeile('Griff', 'Auswahl · A, B, C',
            '<a href="#" style="%s">Löschen</a>' % DESTRUCTIVE, letzte=True)
))

vorgabenliste = (
    '<div style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; '
    'max-height: 224px; overflow-y: auto; display: flex; flex-direction: column;">%s</div>'
    % (vorgabe_zeile('Wiederholungen', 'Zahl · 1 – 30 · Schritt 1 · Standard 10')
       + vorgabe_zeile('Gewicht', 'Zahl · 5,0 – 150,0 kg · Schritt 2,5 kg')
       + vorgabe_zeile('Winkel', 'Zahl · 0 – 90° · Schritt 5°')
       + vorgabe_zeile('Eigener Parameter', 'Schlüssel, Art, Bereich und Einheit frei eintragen',
                        aktiv=True, letzte=True)))

# "Eigener Parameter" gewaehlt: Minimum/Maximum/Schritt/Einheit als ein
# Scroll-Rad statt getippter Zahlen -- vier Spalten unter einer
# gemeinsamen Auswahlleiste, wie ein iOS-Picker. Schluessel und
# Beschriftung bleiben Text (ein Name laesst sich nicht sinnvoll rollen);
# Minimum/Maximum/Schritt/Einheit dagegen sind aus einer kleinen,
# bekannten Menge -- genau der Fall, fuer den ein Rad weniger Tastatur
# braucht als ein Eingabefeld. Schritt und Einheit laufen am linken Rand
# ihrer Liste ("1" ist der erste Schritt, "keine" die erste Einheit) --
# die Randzeilen bleiben deshalb leer, wie bei einem echten Rad.
eigener_parameter = (
    '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px;">%s</div>'
    % (feld('Schlüssel', 'sitzhoehe') + feld('Beschriftung', 'Sitzhöhe')
       + feld('Art', 'Zahl mit Bereich', auswahl=True))
    + rad([
        ('Minimum', [('', False), ('0', False), ('1', True), ('2', False), ('3', False)]),
        ('Maximum', [('6', False), ('7', False), ('8', True), ('9', False), ('10', False)]),
        ('Schritt', [('', False), ('', False), ('1', True), ('2', False), ('5', False)]),
        ('Einheit', [('', False), ('keine', False), ('Stufe', True), ('kg', False), ('°', False)]),
    ]))

modell_einstellungen += (
    '<section style="%s margin-top: 24px;">'
    '<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
    '<div style="display: flex; flex-direction: column; gap: 8px;">'
    '<span style="%s color: #9ba3af;">Vorgabe</span>%s</div>'
    '%s'
    '<div><a href="#" style="%s">Parameter anlegen</a></div>'
    '</div></section>'
    % (CARD, LABEL, vorgabenliste, eigener_parameter, PRIMARY))
schreibe('ModellEinstellungen.dc.html', portal('geraete', 1420, modell_einstellungen))


# ------------------------------------------------------ Modell, Übungen
# Reiter "Übungen" -- ebenfalls neu. Inhalt nach
# geraete/[modelId]/uebungen/page.tsx: eine nummerierte, umsortierbare
# Liste (Hoch/Runter/Entfernen -- die Reihenfolge ist die Vorauswahl am
# Geraet, Canvas-Notiz note-uebungen), je Zeile ein Video-Upload-Feld
# (VideoUpload.tsx), darunter das Anlegeformular.
def uebungszeile(nr, name, meta, upload_html, letzte=False):
    rand = '' if letzte else 'border-bottom: 1px solid #2a2e36;'
    return (
        '<div style="padding: 16px 20px; %s display: flex; flex-direction: column; gap: 12px;">'
        '<div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 16px;">'
        '<div style="display: flex; align-items: flex-start; gap: 12px; min-width: 0;">'
        '<span style="width: 24px; height: 24px; border-radius: 999px; border: 1px solid #2a2e36; '
        'color: #9ba3af; font-size: 12px; font-weight: 700; display: inline-flex; align-items: center; '
        'justify-content: center; flex-shrink: 0; margin-top: 2px;">%d</span>'
        '<div style="min-width: 0;"><div style="font-weight: 600;">%s</div>'
        '<div style="font-size: 12px; color: #9ba3af; margin-top: 2px;">%s</div></div></div>'
        '<div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">'
        '<a href="#" style="%s">Hoch</a><a href="#" style="%s">Runter</a>'
        '<a href="#" style="%s">Entfernen</a></div></div>'
        '<div style="max-width: 420px;">%s</div></div>'
        % (rand, nr, name, meta, SECONDARY, SECONDARY, DESTRUCTIVE, upload_html))


def video_feld(label, wert, hinweis, gefuellt):
    farbe = '#f2f4f7' if gefuellt else '#5c636e'
    return ('<div style="display: flex; flex-direction: column; gap: 8px;">'
            '<span style="%s color: #9ba3af;">%s</span>'
            '<div style="%s color: %s;">%s</div>'
            '<span style="font-size: 12px; color: #9ba3af;">%s</span></div>'
            % (LABEL, label, FIELD, farbe, wert, hinweis))


modell_uebungen = modell_kopf('Übungen')
modell_uebungen += ('<p style="color: #9ba3af; margin: 20px 0 0; max-width: 62ch;">'
                    'Die Reihenfolge bestimmt, was am Gerät zuerst vorgeschlagen wird.</p>')

modell_uebungen += (
    '<section style="%s margin-top: 24px;">%s%s</section>'
    % (CARD,
       uebungszeile(1, '1. Latzug · Breiter Griff', '8–12 Wiederholungen · Video 28 s',
                    video_feld('Video ersetzen', 'latzug-breit.mp4 · 28 s',
                               'Höchstens 45 Sekunden. Länger nimmt der Upload nicht an.', True)),
       uebungszeile(2, '2. Latzug · Enger Griff', '8–12 Wiederholungen · ohne Video',
                    video_feld('Einweisungsvideo', 'Keine Datei ausgewählt',
                               'Höchstens 45 Sekunden. Länger nimmt der Upload nicht an.', False),
                    letzte=True)))

modell_uebungen += (
    '<section style="%s margin-top: 24px;">'
    '<div style="%s"><h2 style="%s">Übung anlegen</h2></div>'
    '<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
    '<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px;">%s</div>'
    '<div><a href="#" style="%s">Übung anlegen</a></div>'
    '</div></section>'
    % (CARD, HEADROW, SEC_TITLE,
       feld('Name', 'Rudern sitzend') + feld('Wiederholungen ab', '8') + feld('bis', '12'),
       PRIMARY))
schreibe('ModellUebungen.dc.html', portal('geraete', 1200, modell_uebungen))


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
              'Mi., 12. August 2026 · 100 Gerätetags · <strong>97 vorrätig</strong>, 2 aktiv, '
              '1 gesperrt', '')
tags += zeile('Charge 8',
              'Mi., 12. August 2026 · 5 Aushangschilder · <strong>5 aktiv</strong>',
              '', letzte=True)
tags += '</section>'
tags += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 16px 0 0; '
         'max-width: 62ch;">Der Gerätetag-Vorrat steht als Zahl. Ein vorrätiger Aufkleber lässt '
         'sich keinem Stück in der Packung zuordnen — 97 gleichlautende Zeilen wären keine '
         'Auskunft, sondern Lärm. Benennbar wird ein Gerätetag erst durch den Scan. '
         'Aushangschilder sind ab Lieferung gültig und stehen deshalb unten einzeln.</p>')

aktiv = '<span style="%s color: #f2f4f7; border-color: #5c636e;">aktiv</span>' % BADGE
gesperrt = '<span style="%s color: #ff5a4e; border-color: #ff5a4e;">gesperrt</span>' % BADGE

tags += '<section style="%s margin-top: 24px;">' % CARD
tags += ('<div style="%s"><h2 style="%s">Vergebene Geräte-Tags</h2>'
         '<span style="color: #5c636e; font-size: 12px;">3 von 100</span></div>'
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

# Aushangschilder sind ab Lieferung gueltig -- sie haengen an keinem Geraet,
# also gibt es keinen Scan, der sie aktivieren koennte, und keinen Bildschirm
# dafuer. Damit weiss das Portal auch nicht, welches am Eingang haengt und
# welche in der Schublade liegen: ein Ort wurde nie eingegeben, ein
# Anbringungsdatum nie erfasst. Benannt wird ein Schild deshalb ueber die
# aufgedruckte Nummer -- das einzige, was ohne Zutun feststeht.
#
# Sie stehen einzeln da und nicht als Zahl, anders als der Geraetetag-Vorrat:
# ein vorraetiger Aufkleber kann nichts, ein Schild dagegen ist gueltig, und
# ein gueltiges Schild muss sperrbar sein, wenn es verlorengeht.
tags += '<section style="%s margin-top: 24px;">' % CARD
tags += ('<div style="%s"><h2 style="%s">Aushangschilder</h2>'
         '<span style="color: #5c636e; font-size: 12px;">5 aus Charge 8</span></div>'
         % (HEADROW, SEC_TITLE))
tags += zeile('%s &nbsp; Schild 1' % aktiv, 'Charge 8 · geliefert Mi., 12. August 2026',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE)
tags += zeile('%s &nbsp; Schild 2' % aktiv, 'Charge 8 · geliefert Mi., 12. August 2026',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE)
tags += zeile('<span style="color: #5c636e;">… 3 weitere</span>', '', '',
              letzte=True, meta_faint=True)
tags += '</section>'
tags += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 16px 0 0; '
         'max-width: 62ch;">Ein Aushangschild hängt an keinem Gerät — wer es scannt, wird '
         'Mitglied. Alle Schilder einer Lieferung sind gleichwertig und ab Lieferung gültig; '
         'welches ihr aufhängt, ist eure Sache. Sperren macht genau eines ungültig, die '
         'anderen gelten weiter.</p>')
schreibe('Tags.dc.html', portal('tags', 1180, tags))
