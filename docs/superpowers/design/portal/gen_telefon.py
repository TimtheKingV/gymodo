# -*- coding: utf-8 -*-
"""Die Seite "Einrichten am Geraet" -- der einzige Weg, der auf dem Telefon
tragen muss.

Er traegt ihn ganz: ein Trainer geht mit dem Telefon und einer Packung Tags
durch die Halle und richtet Geraet fuer Geraet ein. Vorher stand hier ein
einziger Bildschirm (die Uebungsliste mit laufendem Upload); aus dem ging
nicht hervor, wo der Ablauf anfaengt, was bei einem noch nicht angelegten
Modell passiert und wie mehrere Uebungen entstehen.

Die Tags erzeugt das Portal nicht mehr. Sie kommen chargenweise als
physisches Erzeugnis -- NFC-Chip und aufgedruckter QR auf derselben
/t/<token>-Adresse -- und werden am Geraet geklebt und gescannt.

Der Bestand, den alle Bildschirme teilen (er muss zu Geraete, Modell, Tags
und Ueberblick passen): drei Modelle, vier Geraete, davon zwei erreichbar.
Latzug 12 aktiv, Latzug 13 ohne Tag, Beinpresse 7 aktiv, Beinpresse 8
stillgelegt mit gesperrtem Tag. Charge 7 hat 100 Tags, drei sind vergeben,
97 liegen in der Packung. Eingerichtet wird in diesem Gang ein neuer
Kabelzug mit der Nummer 14.
"""
from build import (HEAD, FOOT, LABEL, CARD, PRIMARY, SECONDARY, SECONDARY_TEL,
                   DESTRUCTIVE, BADGE, NOTE, CHIP, CHIP_AKTIV, PRIMARY_XL,
                   SECONDARY_XL, DESTRUCTIVE_XL, FIELD_XL, antwort, balken,
                   feld, kopfzeile, schrittleiste, sheet, sucher, svg, telefon,
                   telefon_voll, tkarte, schreibe, zurueck)

MUTED = 'font-size: 12px; color: #9ba3af;'
H2 = 'font-size: 16px; font-weight: 600;'


def abschnitt(titel, zeilen, rechts=''):
    """Karte mit Kopfzeile und Zeilen, in Telefonbreite."""
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


def schrittmarke(n, titel, von=5):
    """Die Wegmarke fuer Bildschirme, die keine Leiste tragen koennen --
    Sucher und Aufnahme laufen randlos ueber die Kamera."""
    return ('<span style="%s color: #9ba3af;">Schritt %d von %d &middot; %s</span>'
            % (LABEL, n, von, titel))


def stapel(*teile):
    return ''.join(teile)


# ------------------------------------------------------------------ 1 Start
# Der Einstieg steht in der Halle, nicht am Schreibtisch: was fehlt noch,
# wie viele Tags sind in der Packung, und ein Knopf, der den Gang beginnt.
start = stapel(
    kopfzeile('Einrichten', 'Geh von Gerät zu Gerät. Jedes ist fertig, sobald sein Tag klebt.'),
    tkarte('<div style="display: flex; gap: 20px;">'
           '<div><div style="font-size: 28px; font-weight: 800; letter-spacing: -0.03em; '
           'line-height: 1;">4</div><div style="%s color: #9ba3af; margin-top: 6px;">Geräte</div></div>'
           '<div><div style="font-size: 28px; font-weight: 800; letter-spacing: -0.03em; '
           'line-height: 1;">3</div><div style="%s color: #9ba3af; margin-top: 6px;">Modelle</div></div>'
           '<div><div style="font-size: 28px; font-weight: 800; letter-spacing: -0.03em; '
           'line-height: 1; color: #ffb020;">1</div><div style="%s color: #ffb020; margin-top: 6px;">'
           'ohne Tag</div></div></div>' % (LABEL, LABEL, LABEL)),
    tkarte('<div style="display: flex; align-items: center; gap: 12px;">%s'
           '<div style="min-width: 0;"><div style="%s">97 Tags vorrätig</div>'
           '<div style="%s margin-top: 2px;">Charge 7 &middot; geliefert Mi., 12. August 2026 &middot; '
           '100 Stück, 3 vergeben</div></div></div>' % (svg('tag', 24, '#5c636e'), H2, NOTE)),
    '<a href="#" style="%s">Gerät einrichten</a>' % PRIMARY_XL,
    '<a href="#" style="%s">Tag prüfen</a>' % SECONDARY_XL,
    abschnitt('Was noch fehlt', [
        tzeile('Latzug 13', 'Rückwand mitte &middot; kein Tag, für Mitglieder nicht auffindbar',
               '<a href="#" style="%s">Weiter</a>' % SECONDARY_TEL, letzte=True),
    ]),
    abschnitt('Zuletzt eingerichtet', [
        tzeile('Latzug 12', 'Rückwand links &middot; gestern &middot; erreichbar'),
        tzeile('Beinpresse 7', 'Fensterseite &middot; gestern &middot; erreichbar',
               letzte=True, faint=True),
    ]),
    '<p style="%s margin: 0;">Ein Gerät ist fertig, sobald sein Tag klebt. Übungen und Videos '
    'lassen sich jederzeit nachtragen.</p>' % NOTE)
schreibe('TelefonStart.dc.html', telefon(1000, start))


# ------------------------------------------------------------- 2 Modell
# Schritt 1: welches Modell. Der Akzent gehoert dem Anlegen, wie auf der
# Geraeteliste am Schreibtisch -- bei der Erstbestueckung ist das der Fall,
# der oefter eintritt als das Wiederfinden.
modell = stapel(
    schrittleiste(1, 'Modell'),
    kopfzeile('Was steht hier?', zurueck_zu='Einrichten'),
    '<div style="%s color: #5c636e;">%s Modell suchen …</div>'
    % (FIELD_XL, svg('search', 18, '#5c636e')),
    abschnitt('Modelle im Studio', [
        tzeile('Latzug', 'Technogym &middot; 2 Geräte &middot; 2 Übungen',
               '<a href="#" style="%s">Wählen</a>' % SECONDARY_TEL),
        tzeile('Beinpresse', 'Gym80 &middot; 2 Geräte &middot; 1 Übung',
               '<a href="#" style="%s">Wählen</a>' % SECONDARY_TEL),
        tzeile('Brustpresse', 'Ohne Hersteller &middot; noch kein Gerät',
               '<a href="#" style="%s">Wählen</a>' % SECONDARY_TEL, letzte=True, faint=True),
    ]),
    tkarte('<div style="display: flex; align-items: center; gap: 12px;">%s'
           '<div style="min-width: 0;"><div style="%s">Noch nicht dabei</div>'
           '<div style="%s margin-top: 2px;">Ein Modell beschreibt den Gerätetyp. Zwei Kabelzüge '
           'nebeneinander sind ein Modell und zwei Geräte.</div></div></div>'
           '<a href="#" style="%s">Neues Modell anlegen</a>'
           % (svg('plus', 24, '#5c636e'), H2, NOTE, PRIMARY_XL), gestrichelt=True))
schreibe('TelefonModell.dc.html', telefon(900, modell))


# --------------------------------------------------------- 3 Modell neu
# Bewusst knapp: Foto, Name, Hersteller, Schrittweite, Spanne. Die
# Einstellparameter eines Modells sind Schreibtischarbeit -- sie am Geraet
# zu erfragen hiesse, den Katalogeditor auf 390 px zu quetschen.
schritt_chips = ''.join('<span style="%s">%s</span>' % (CHIP_AKTIV if s == '2,5 kg' else CHIP, s)
                        for s in ('1,25 kg', '2,5 kg', '5,0 kg'))
modell_neu = stapel(
    schrittleiste(1, 'Modell'),
    kopfzeile('Neues Modell', zurueck_zu='Modell wählen'),
    tkarte('<div style="display: flex; align-items: center; gap: 12px;">%s'
           '<div style="min-width: 0;"><div style="%s">Foto aufnehmen</div>'
           '<div style="%s margin-top: 2px;">Das Foto bestätigt dem Mitglied in einer Sekunde, '
           'dass es am richtigen Gerät steht.</div></div></div>'
           % (svg('image', 24, '#5c636e'), H2, NOTE), gestrichelt=True),
    feld('Name', 'Kabelzug', gefuellt=True),
    feld('Hersteller', 'Technogym', gefuellt=True),
    '<div style="display: flex; flex-direction: column; gap: 8px;">'
    '<span style="%s color: #9ba3af;">Gewichtsschritt</span>'
    '<div style="display: flex; gap: 8px;">%s</div>'
    '<span style="%s">Die Schrittweite kommt von den Platten am Gerät. Sie rastet später das Rad '
    'des Mitglieds — ein Wert, den das Gerät nicht kann, wird damit unmöglich.</span></div>'
    % (LABEL, schritt_chips, NOTE),
    '<div style="display: flex; gap: 12px;">'
    '<div style="flex: 1;">%s</div><div style="flex: 1;">%s</div></div>'
    % (feld('Ab', '5,0 kg', gefuellt=True), feld('Bis', '100,0 kg', gefuellt=True)),
    '<a href="#" style="%s">Weiter zum Gerät</a>' % PRIMARY_XL,
    '<p style="%s margin: 0;">Einstellparameter, Beschreibung und ein besseres Foto trägst du am '
    'Schreibtisch nach. Hier steht nur, was das Rad braucht.</p>' % NOTE)
schreibe('TelefonModellNeu.dc.html', telefon(1120, modell_neu))


# ------------------------------------------------------------- 4 Gerät
ort_chips = ''.join('<span style="%s">%s</span>' % (CHIP, s)
                    for s in ('Rückwand links', 'Rückwand mitte', 'Fensterseite'))
geraet = stapel(
    schrittleiste(2, 'Gerät'),
    kopfzeile('Dieses Gerät', 'Kabelzug &middot; Technogym', zurueck_zu='Modell'),
    feld('Nummer', '14', 'Vorgeschlagen ist die nächste nach der höchsten. Sie steht am Gerät und '
         'in der App des Mitglieds — nimm die, die schon draufsteht.', gefuellt=True),
    '<div style="display: flex; flex-direction: column; gap: 8px;">%s'
    '<div style="display: flex; gap: 8px; overflow-x: auto;">%s</div></div>'
    % (feld('Standort', 'Rückwand rechts', gefuellt=True), ort_chips),
    '<a href="#" style="%s">Weiter zum Tag</a>' % PRIMARY_XL,
    '<p style="%s margin: 0;">Ein Gerät verschwindet später nicht mehr. Es wird stillgelegt, '
    'einzeln, mit Namen — die Zuordnungshistorie bleibt.</p>' % NOTE)
schreibe('TelefonGeraet.dc.html', telefon(760, geraet))


# --------------------------------------------------------------- 5 Kleben
# Der Schritt, der vorher ganz fehlte: erst kleben, dann scannen. Die Skizze
# steht hier, weil die Anbringungsposition ueber die Trefferquote entscheidet
# (M0 Task 8) und ein Satz sie nicht so gut traegt wie ein Bild.
skizze = (
    '<svg width="100%" height="150" viewBox="0 0 300 150" fill="none" stroke="#5c636e" '
    'stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M60 132h90"></path>'
    '<path d="M105 132V44"></path>'
    '<path d="M105 44h52"></path>'
    '<path d="M157 44v14"></path>'
    '<rect x="60" y="60" width="34" height="62" rx="3"></rect>'
    '<path d="M60 74h34M60 86h34M60 98h34M60 110h34"></path>'
    '<path d="M128 132v-22h34v22"></path>'
    '<path d="M128 110c0-9 7-14 17-14s17 5 17 14"></path>'
    '<circle cx="196" cy="82" r="17" stroke="#d4ff3f" stroke-width="2"></circle>'
    '<path d="M188 82h16M196 74v16" stroke="#d4ff3f" stroke-width="2"></path>'
    '<path d="M179 82h-14" stroke="#d4ff3f" stroke-width="2" stroke-dasharray="3 4"></path>'
    '<text x="196" y="118" fill="#d4ff3f" font-size="11" font-weight="700" text-anchor="middle" '
    'stroke="none" letter-spacing="1.4">HIER</text>'
    '</svg>')
kleben = stapel(
    schrittleiste(3, 'Tag'),
    kopfzeile('Tag ankleben', 'Kabelzug 14 &middot; Rückwand rechts', zurueck_zu='Gerät'),
    tkarte(skizze + '<div style="%s">In Augenhöhe, wo man im Stehen hinsieht.</div>' % NOTE),
    abschnitt('Worauf es ankommt', [
        tzeile('Nicht auf Bewegtes', 'Kein Gewichtsblock, kein Hebel, kein Polster'),
        tzeile('Metall braucht die Ferritseite', 'Sonst liest der Chip nicht — der QR schon'),
        tzeile('Sauber und trocken', 'Einmal abwischen hält den Tag jahrelang', letzte=True),
    ]),
    '<a href="#" style="%s">Tag scannen</a>' % PRIMARY_XL,
    '<p style="%s margin: 0;">Nimm irgendeinen Tag aus der Gerätepackung — welcher es ist, findet '
    'der Scan heraus.</p>' % NOTE)
schreibe('TelefonKleben.dc.html', telefon(900, kleben))


# ----------------------------------------------------------------- 6 Scan
# Der Sucher. Kein Akzent als Flaeche: die Kamera ist die Handlung. Statt der
# Schrittleiste traegt er die Wegmarke als Zeile -- eine Leiste ueber einem
# randlosen Kamerabild waere Chrome ohne Grund.
scan = (sucher('Halt den QR auf dem Tag ins Feld. Geh nah ran — der Code ist klein.')
        + '<div style="position: relative; margin: 0 16px 16px; text-align: center;">%s</div>'
        % schrittmarke(3, 'Tag')
        + '<div style="position: relative; margin: 0 16px 20px;">'
        + tkarte('<div style="display: flex; align-items: flex-start; gap: 12px;">%s'
                 '<div style="min-width: 0;"><div style="font-weight: 600;">Der Chip zählt hier nicht'
                 '</div><div style="%s margin-top: 2px;">Im Tag steckt zusätzlich NFC — der trägt '
                 'den Weg des Mitglieds. Ein Browser liest kein NFC, im Portal geht es allein über '
                 'den QR.</div></div></div>' % (svg('alert', 20, '#5c636e'), NOTE))
        + '</div>')
schreibe('TelefonScan.dc.html', telefon_voll(860, scan))


# ------------------------------------------------------------- 7 Treffer
treffer = stapel(
    schrittleiste(3, 'Tag'),
    '<div style="display: flex; align-items: center; gap: 12px;">'
    '<div style="width: 44px; height: 44px; border-radius: 50%%; border: 2px solid #d4ff3f; '
    'display: flex; align-items: center; justify-content: center; flex-shrink: 0;">%s</div>'
    '<div><div style="font-size: 22px; font-weight: 800; letter-spacing: -0.02em; '
    'text-transform: uppercase;">Tag erkannt</div>'
    '<div style="%s margin-top: 2px;">Vorrätig, noch keinem Gerät zugeordnet</div></div></div>'
    % (svg('check', 22, '#d4ff3f'), MUTED),
    abschnitt('Der Tag', [
        tzeile('<span style="%s">vorrätig</span>' % BADGE,
               'Charge 7 &middot; geliefert Mi., 12. August 2026', letzte=True),
    ]),
    abschnitt('Das Gerät', [
        tzeile('Kabelzug 14', 'Technogym &middot; Rückwand rechts', letzte=True),
    ]),
    '<a href="#" style="%s">Verbinden</a>' % PRIMARY_XL,
    '<a href="#" style="%s">Anderen Tag scannen</a>' % SECONDARY_XL,
    '<p style="%s margin: 0;">Ab dem Verbinden ist Kabelzug 14 für Mitglieder auffindbar. Übungen '
    'und Videos kannst du danach jederzeit nachtragen.</p>' % NOTE)
schreibe('TelefonScanTreffer.dc.html', telefon(860, treffer))


# ----------------------------------------------------- 8 Übung auswählen
# Uebungen gehoeren dem Studio, nicht dem Geraet (equipment_model_exercises).
# Deshalb steht hier eine Auswahl und kein leeres Namensfeld -- sonst legt
# jedes Studio "Rudern sitzend" fuenfmal an. Aus demselben Grund traegt
# "Neue Uebung anlegen" hier keinen Akzent: der Bildschirm soll zum Waehlen
# einladen, nicht zum Doppeln.
def uebung_zeile(name, meta, letzte=False, faint=False):
    return ('<div style="padding: 14px 16px; %s display: flex; align-items: center; gap: 12px; '
            'min-height: 48px;"><div style="flex-grow: 1; min-width: 0;">'
            '<div style="font-size: 16px; font-weight: 600;">%s</div>'
            '<div style="font-size: 12px; color: %s; margin-top: 2px;">%s</div></div>%s</div>'
            % ('' if letzte else 'border-bottom: 1px solid #2a2e36;', name,
               '#5c636e' if faint else '#9ba3af', meta, svg('plus', 20, '#5c636e')))


waehlen = sheet(stapel(
    '<div><div style="font-size: 22px; font-weight: 800; letter-spacing: -0.02em; '
    'text-transform: uppercase;">Übung hinzufügen</div>'
    '<div style="margin-top: 6px;">%s</div>'
    '<div style="%s margin-top: 4px;">Kabelzug 14</div></div>'
    % (schrittmarke(4, 'Übungen'), MUTED),
    '<div style="%s color: #5c636e;">%s Übung suchen …</div>'
    % (FIELD_XL, svg('search', 18, '#5c636e')),
    '<section style="%s">%s</section>' % (CARD, stapel(
        uebung_zeile('Latzug · Breiter Griff', 'An 1 Modell &middot; 8–12 Wiederholungen'),
        uebung_zeile('Latzug · Enger Griff', 'An 1 Modell &middot; 8–12 Wiederholungen'),
        uebung_zeile('Rudern sitzend', 'An 2 Modellen &middot; 10–15 Wiederholungen'),
        uebung_zeile('Trizepsdrücken am Seil', 'Noch an keinem Modell &middot; 10–15 Wiederholungen',
                     letzte=True, faint=True))),
    '<a href="#" style="%s">Neue Übung anlegen</a>' % SECONDARY_XL,
    '<div style="display: flex; gap: 10px; align-items: flex-start;">%s'
    '<div style="%s">Übungen gehören dem Studio, nicht dem Gerät. Dieselbe Übung an zwei Modellen '
    'behält ihren Namen — das Einweisungsvideo hängt dagegen am Paar aus Modell und Übung, jedes '
    'Modell zeigt also sein eigenes.</div></div>' % (svg('alert', 16, '#5c636e'), NOTE)), 240)
schreibe('TelefonUebungWaehlen.dc.html', telefon_voll(1000, waehlen))


# --------------------------------------------------------- 9 Übung neu
# Der Name ist bewusst einer, der in der Auswahlliste NICHT steht -- sonst
# zeigt der Entwurf genau die Doppelung, vor der er warnt.
uebung_neu = stapel(
    schrittleiste(4, 'Übungen'),
    kopfzeile('Neue Übung', zurueck_zu='Übung wählen'),
    feld('Name', 'Latzug · Neutralgriff', gefuellt=True),
    '<div style="display: flex; gap: 12px;">'
    '<div style="flex: 1;">%s</div><div style="flex: 1;">%s</div></div>'
    % (feld('Wiederholungen ab', '8', gefuellt=True), feld('bis', '12', gefuellt=True)),
    '<p style="%s margin: 0;">Die Spanne ist ein Ziel, kein Vorschlag. gymodo rechnet daraus nichts '
    'aus — sie steht dem Mitglied unter dem Rad.</p>' % NOTE,
    '<a href="#" style="%s">Hinzufügen</a>' % PRIMARY_XL,
    '<p style="%s margin: 0;">Die Übung steht danach dem ganzen Studio zur Verfügung und lässt sich '
    'an weitere Modelle hängen.</p>' % NOTE)
schreibe('TelefonUebungNeu.dc.html', telefon(820, uebung_neu))


# ---------------------------------------------------- 10 Übungsliste
# Der Nachfolger des alten Telefon-Artboards: dieselbe Liste, aber mit
# Reihenfolge, vier Uebungen und dem Videostand je Zeile. Der Akzent liegt
# auf dem Weiterkommen, nicht auf dem Hinzufuegen -- sonst betont der
# Bildschirm das Sammeln und nicht das Fertigwerden.
def uebungsposten(nr, name, meta, unten, letzte=False):
    return ('<div style="padding: 14px 16px; %s display: flex; flex-direction: column; gap: 12px;">'
            '<div style="display: flex; align-items: flex-start; gap: 12px;">'
            '<span style="width: 24px; height: 24px; border-radius: 999px; border: 1px solid #2a2e36; '
            'color: #9ba3af; font-size: 12px; font-weight: 700; display: inline-flex; '
            'align-items: center; justify-content: center; flex-shrink: 0;">%d</span>'
            '<div style="flex-grow: 1; min-width: 0;"><div style="%s">%s</div>'
            '<div style="%s margin-top: 2px;">%s</div></div>%s</div>%s</div>'
            % ('' if letzte else 'border-bottom: 1px solid #2a2e36;', nr, H2, name, MUTED, meta,
               svg('grip', 20, '#5c636e'), unten))


def videostand(label_text, prozent, note_text):
    return ('<div style="display: flex; flex-direction: column; gap: 8px;">'
            '<div style="display: flex; align-items: baseline; justify-content: space-between;">'
            '<span style="%s color: #9ba3af;">%s</span>'
            '<span style="font-size: 13px; font-weight: 700;">%d %%</span></div>%s'
            '<span style="%s">%s</span></div>'
            % (LABEL, label_text, prozent, balken(prozent), NOTE, note_text))


uebungen = stapel(
    schrittleiste(4, 'Übungen'),
    kopfzeile('Übungen', 'Kabelzug 14 &middot; Technogym', zurueck_zu='Gerät'),
    '<section style="%s">%s</section>' % (CARD, stapel(
        uebungsposten(1, 'Latzug · Breiter Griff', '8–12 Wiederholungen &middot; Video 28 s',
                      '<a href="#" style="%s">Video ersetzen</a>' % SECONDARY_XL),
        uebungsposten(2, 'Latzug · Enger Griff', '8–12 Wiederholungen',
                      videostand('Video wird übertragen', 62,
                                 'Bricht die Verbindung ab, setzt der nächste Versuch hier fort — '
                                 'er fängt nicht von vorn an.')),
        uebungsposten(3, 'Rudern sitzend', '10–15 Wiederholungen',
                      videostand('Video wartet', 0, 'Beginnt, sobald das vorige durch ist.')),
        uebungsposten(4, 'Latzug · Neutralgriff', '8–12 Wiederholungen &middot; gerade angelegt',
                      '<a href="#" style="%s">Video aufnehmen</a>' % SECONDARY_XL, letzte=True))),
    tkarte('<div style="display: flex; align-items: center; gap: 12px;">%s'
           '<div style="%s">Noch eine Übung</div></div>'
           '<a href="#" style="%s">Aus dem Studio wählen</a>'
           % (svg('plus', 24, '#5c636e'), H2, SECONDARY_XL), gestrichelt=True),
    '<p style="%s margin: 0;">Die Reihenfolge zählt: Übung 1 ist am Gerät die Vorauswahl. Halt den '
    'Griff gedrückt und schieb.</p>' % NOTE,
    '<a href="#" style="%s">Einrichtung abschließen</a>' % PRIMARY_XL)
schreibe('TelefonUebungen.dc.html', telefon(1360, uebungen))


# ------------------------------------------------------------- 11 Video
# Die Aufnahme entsteht auf dem Trainerhandy und geht aus mobilem Safari
# hoch (Spec 6.8). Die 45-Sekunden-Grenze steht sichtbar, weil sie an der
# Datei geprueft wird -- eine zu lange Aufnahme faellt sonst erst am Ende auf.
video = (
    '<div style="position: absolute; inset: 0; background: linear-gradient(168deg, #232730 0%, '
    '#14161a 55%, #0a0b0d 100%);"></div>'
    '<div style="position: relative; height: 54px;"></div>'
    '<div style="position: relative; min-height: 52px; padding: 0 20px; display: flex; '
    'align-items: center; justify-content: space-between; gap: 12px;">'
    '<div style="min-width: 0;">'
    '<div style="font-size: 17px; font-weight: 800; letter-spacing: -0.01em;">Kabelzug 14 · Rudern '
    'sitzend</div><div style="margin-top: 4px;">' + schrittmarke(5, 'Video') + '</div></div>'
    '<div style="width: 44px; height: 44px; border-radius: 50%; background: rgba(10,11,13,.6); '
    'display: flex; align-items: center; justify-content: center; flex-shrink: 0;">'
    + svg('close', 19, '#f2f4f7') + '</div></div>'
    '<div style="position: relative; padding: 16px 20px 0; display: flex; flex-direction: column; '
    'gap: 8px;"><div style="display: flex; align-items: baseline; justify-content: space-between;">'
    '<span style="' + LABEL + ' color: #ff5a4e;">Aufnahme läuft</span>'
    '<span style="font-size: 15px; font-weight: 800; font-variant-numeric: tabular-nums;">'
    '0:28 <span style="color: #5c636e;">von 0:45</span></span></div>'
    + balken(62) +
    '</div>'
    '<div style="position: relative; height: 300px;"></div>'
    '<div style="position: relative; display: flex; align-items: center; justify-content: center; '
    'gap: 28px; padding: 0 20px;">'
    '<span style="' + MUTED + ' width: 72px; text-align: right;">Neu</span>'
    '<a href="#" style="width: 76px; height: 76px; border-radius: 50%; background: #d4ff3f; '
    'display: flex; align-items: center; justify-content: center; flex-shrink: 0;">'
    '<span style="width: 26px; height: 26px; border-radius: 5px; background-color: #0a0b0d; '
    'display: block;"></span></a>'
    '<span style="' + MUTED + ' width: 72px;">Übernehmen</span></div>'
    '<div style="position: relative; padding: 24px 24px 24px; text-align: center;">'
    '<div style="' + NOTE + '">Höchstens 45 Sekunden. Die Länge wird an der Datei geprüft, nicht '
    'geschätzt — eine zu lange Aufnahme wird abgelehnt, nicht beschnitten.</div></div>')
schreibe('TelefonVideo.dc.html', telefon_voll(880, video))


# ----------------------------------------------------------- 12 Uploads
def upload_zeile(titel, meta, unten, letzte=False):
    return ('<div style="padding: 14px 16px; %s display: flex; flex-direction: column; gap: 10px;">'
            '<div><div style="font-weight: 600;">%s</div>'
            '<div style="%s margin-top: 2px;">%s</div></div>%s</div>'
            % ('' if letzte else 'border-bottom: 1px solid #2a2e36;', titel, MUTED, meta, unten))


uploads = stapel(
    kopfzeile('Videos', 'Läuft weiter, während du weitergehst', zurueck_zu='Einrichten'),
    abschnitt('Warteschlange', [
        upload_zeile('Kabelzug 14 · Enger Griff', '18 MB &middot; wird übertragen',
                     '<div style="display: flex; flex-direction: column; gap: 6px;">%s'
                     '<span style="%s">62 %% &middot; setzt bei Abbruch hier fort</span></div>'
                     % (balken(62), NOTE)),
        upload_zeile('Kabelzug 14 · Rudern sitzend', '22 MB &middot; wartet',
                     '<div style="display: flex; flex-direction: column; gap: 6px;">%s'
                     '<span style="%s">Beginnt, sobald das vorige durch ist</span></div>'
                     % (balken(0), NOTE)),
        upload_zeile('Beinpresse 7 · Beidbeinig', '15 MB &middot; wartet',
                     '<div style="display: flex; flex-direction: column; gap: 6px;">%s'
                     '<span style="%s">Von gestern, noch nicht oben</span></div>'
                     % (balken(0), NOTE), letzte=True),
    ], rechts='<span style="%s">3 offen</span>' % MUTED),
    tkarte('<div style="display: flex; align-items: flex-start; gap: 12px;">%s'
           '<div style="min-width: 0;"><div style="font-weight: 600;">Lass diesen Bildschirm offen'
           '</div><div style="%s margin-top: 2px;">Safari hält Uploads an, sobald du zu einer '
           'anderen App wechselst. Sie gehen nicht verloren — sie warten, bis du zurückkommst.'
           '</div></div></div>' % (svg('alert', 20, '#ffb020'), NOTE), rand='#ffb020'),
    '<a href="#" style="%s">Weiter einrichten</a>' % SECONDARY_XL)
schreibe('TelefonUploads.dc.html', telefon(820, uploads))


# ------------------------------------------------------------ 13 Fertig
fertig = stapel(
    '<div style="display: flex; align-items: center; gap: 12px;">'
    '<div style="width: 44px; height: 44px; border-radius: 50%%; border: 2px solid #d4ff3f; '
    'display: flex; align-items: center; justify-content: center; flex-shrink: 0;">%s</div>'
    '<div><div style="font-size: 22px; font-weight: 800; letter-spacing: -0.02em; '
    'text-transform: uppercase;">Kabelzug 14 steht</div>'
    '<div style="%s margin-top: 2px;">Für Mitglieder auffindbar</div></div></div>'
    % (svg('check', 22, '#d4ff3f'), MUTED),
    abschnitt('Was jetzt gilt', [
        tzeile('Tag verbunden', 'Charge 7 &middot; aktiv seit gerade eben'),
        tzeile('4 Übungen', 'Latzug breit, Latzug eng, Rudern sitzend, Neutralgriff'),
        tzeile('2 Videos in der Warteschlange', 'Gehen hoch, solange die Seite offen bleibt'),
        tzeile('1 Übung ohne Video', 'Nutzbar, nur ohne Anleitung', letzte=True, faint=True),
    ]),
    tkarte('<div style="display: flex; align-items: center; gap: 12px;">%s'
           '<div style="min-width: 0;"><div style="font-weight: 600;">Zur Probe scannen</div>'
           '<div style="%s margin-top: 2px;">Zeigt dir, was ein Mitglied sieht, wenn es hier '
           'ankommt.</div></div></div><a href="#" style="%s">Probe scannen</a>'
           % (svg('qr', 24, '#5c636e'), NOTE, SECONDARY_XL)),
    '<a href="#" style="%s">Nächstes Gerät</a>' % PRIMARY_XL,
    '<a href="#" style="%s">Für heute fertig</a>' % SECONDARY_XL,
    '<p style="%s margin: 0;">96 Tags noch in der Packung.</p>' % NOTE)
schreibe('TelefonFertig.dc.html', telefon(960, fertig))


# --------------------------------------------------------- 14 Zustände
# Ein Blatt statt neun fast gleicher Telefone: die Faelle unterscheiden sich
# in einer Karte, nicht im Bildschirm. Vorbild ist Zustaende.dc.html.
def zwei(a, b):
    return ('<div style="display: flex; flex-direction: column; gap: 8px;">'
            '<a href="#" style="%s">%s</a><a href="#" style="%s">%s</a></div>'
            % (SECONDARY_XL, a, SECONDARY_XL, b))


zustaende = stapel(
    kopfzeile('Zustände', 'Was der Sucher antwortet, und was dann gilt'),
    '<span style="%s color: #9ba3af;">Beim Scannen</span>' % LABEL,
    antwort('Der Tag hängt schon woanders',
            'Dieser Tag gehört zu Beinpresse 7. Ein vergebener Tag wird nicht mit einem Tap '
            'umgehängt — sonst verliert ein Gerät seinen Tag, ohne dass jemand davorsteht.',
            zwei('Beinpresse 7 ansehen', 'Anderen Tag nehmen'),
            symbol=svg('tag', 20, '#9ba3af')),
    antwort('Der Tag ist gesperrt',
            'Gesperrt bleibt gesperrt — auch nach einem Neustart, auch nach einem Jahr. Der Eintrag '
            'steht als Nachweis weiter in der Liste. Nimm einen anderen aus der Packung.',
            symbol=svg('alert', 20, '#ff5a4e'), rand='#ff5a4e'),
    # Der Fehlgriff ist eingeplant, nicht unwahrscheinlich: vor dem Scan sieht
    # ein Aushangschild aus wie ein Geraetetag, und genau das ist Absicht --
    # "benennbar wird ein Tag erst durch den Scan". Ohne diese Karte waere der
    # einzige angebotene Ausgang "Verbinden", also machine_id setzen, was der
    # kind-Constraint zurueckweist: eine Check-Verletzung ohne Bildschirm.
    # Eine Sackgasse mit einem Ausgang, weil es hier nichts zu tun gibt --
    # das Schild ist bereits gueltig und gehoert an die Wand.
    antwort('Das ist ein Aushangschild',
            'Kein Gerätetag: dieses Schild gehört an die Wand. Wer es scannt, wird Mitglied bei '
            'Kraftwerk Nord — dafür ist es ab der Lieferung gültig, du musst nichts freischalten. '
            'Nimm einen Tag aus der Gerätepackung.',
            '<a href="#" style="%s">Anderen Tag scannen</a>' % SECONDARY_XL,
            symbol=svg('tag', 20, '#9ba3af')),
    antwort('Der Tag gehört nicht zu Kraftwerk Nord',
            'Eine Antwort für drei Fälle: unbekannt, fremdes Studio, oder eine Charge, die noch '
            'niemand deinem Studio zugeordnet hat. Neue Lieferung angekommen? Dann fehlt die '
            'Zuordnung — melde dich beim Betreiber.',
            symbol=svg('alert', 20, '#9ba3af')),
    '<span style="%s color: #9ba3af;">Am Gerät</span>' % LABEL,
    antwort('Tag ersetzen',
            'Der Tag an Latzug 12 ist zerkratzt. Kleb einen neuen daneben und scanne ihn — der alte '
            'wird dabei ungültig. Zieh ihn danach ab: er öffnet nichts mehr, aber er verwirrt.',
            '<a href="#" style="%s">Neuen Tag scannen</a>' % DESTRUCTIVE_XL,
            symbol=svg('qr', 20, '#9ba3af')),
    antwort('Die Kamera ist nicht freigegeben',
            'Ohne Kamera gibt es keinen zweiten Weg — der Chip im Tag hilft im Browser nicht. '
            'In Safari: „aA" links in der Adresszeile, dann Website-Einstellungen, dann Kamera '
            'erlauben.',
            symbol=svg('camera', 20, '#ff5a4e'), rand='#ff5a4e'),
    antwort('Kein Netz im Keller',
            'Gespeichert, wird gesendet. Gerät und Tag liegen lokal und gehen hoch, sobald wieder '
            'Empfang da ist.',
            symbol=svg('offline', 20, '#ff5a4e'), rand='#ff5a4e',
            flaeche='rgba(255,90,78,0.1)'),
    '<span style="%s color: #9ba3af;">Leer</span>' % LABEL,
    antwort('Die Packung ist leer',
            'Kein Tag mehr vorrätig. Die eingerichteten Geräte funktionieren weiter; die übrigen '
            'warten auf die nächste Lieferung.',
            symbol=svg('tag', 20, '#5c636e')),
    antwort('Noch keine Übung',
            'Ohne Übung zeigt das Gerät dem Mitglied nichts zum Trainieren. Nimm eine aus dem '
            'Studio oder leg eine neue an.',
            '<a href="#" style="%s">Übung hinzufügen</a>' % SECONDARY_XL,
            symbol=svg('plus', 20, '#5c636e')))
schreibe('TelefonZustaende.dc.html', telefon(2000, zustaende))


# --------------------------------------------------------- 15 Ablaufkarte
# Der Bildschirm, der vorher fehlte: die Reihenfolge selbst. Ohne ihn muss
# man sich den Gang aus dreizehn Einzelbildern zusammenreimen.
PUNKT = ('<span style="width: 6px; height: 6px; border-radius: 999px; background: #5c636e; '
         'display: block;"></span>')


def a_schritt(marke, titel, text):
    return ('<div style="display: flex; gap: 12px; align-items: flex-start;">'
            '<span style="width: 26px; height: 26px; border-radius: 999px; border: 1px solid #2a2e36; '
            'color: #9ba3af; font-size: 12px; font-weight: 700; display: inline-flex; '
            'align-items: center; justify-content: center; flex-shrink: 0; margin-top: 1px;">%s</span>'
            '<div style="min-width: 0;"><div style="font-weight: 600;">%s</div>'
            '<div style="%s margin-top: 2px;">%s</div></div></div>' % (marke, titel, NOTE, text))


def a_spalte(marke, titel, inhalt, rand='#2a2e36'):
    return ('<div style="border: 1px solid %s; border-radius: 12px; background: #14161a; '
            'padding: 20px; display: flex; flex-direction: column; gap: 16px; height: 100%%;">'
            '<div><div style="%s color: #5c636e;">%s</div>'
            '<div style="font-size: 18px; font-weight: 800; letter-spacing: -0.02em; '
            'text-transform: uppercase; margin-top: 6px;">%s</div></div>'
            '<div style="display: flex; flex-direction: column; gap: 14px;">%s</div></div>'
            % (rand, LABEL, marke, titel, inhalt))


pfeil = ('<div style="display: flex; align-items: center; justify-content: center;">%s</div>'
         % svg('arrow-right', 22, '#5c636e'))

ablauf = HEAD + (
    '<div style="min-height: 800px; background: #0a0b0d; padding: 40px 48px;">'
    '<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.025em; text-transform: '
    'uppercase; margin: 0;">Einrichten am Gerät</h1>'
    '<p style="color: #9ba3af; margin: 8px 0 0; max-width: 78ch;">Ein Trainer geht mit dem Telefon '
    'und einer Packung Tags durch die Halle. Alles, was ein Gerät für Mitglieder auffindbar macht, '
    'passiert dabei vor dem Gerät — der Rest ist Nacharbeit und hat Zeit.</p>'
    '<div style="display: grid; grid-template-columns: minmax(0, 1fr) 56px minmax(0, 1.5fr) 56px '
    'minmax(0, 1fr); gap: 0; margin-top: 32px; align-items: stretch;">'
    + a_spalte('Vorher', 'Betreiber',
               a_schritt(PUNKT, 'Charge herstellen',
                         'Tags mit NFC-Chip und aufgedrucktem QR, beide auf derselben Adresse. '
                         'Das Studio erzeugt keine Tags.')
               + a_schritt(PUNKT, 'Charge zuordnen und schicken',
                           'Eine Handlung, hundert Tags. Danach sieht das Studio „97 vorrätig".'))
    + pfeil
    + a_spalte('Je Gerät, in der Halle', 'Der Gang',
               a_schritt(1, 'Modell', 'Wählen — oder knapp neu anlegen: Foto, Name, Hersteller, '
                                      'Gewichtsschritt, Spanne.')
               + a_schritt(2, 'Gerät', 'Nummer und Standort. Die Nummer steht am Gerät und in der '
                                       'App des Mitglieds.')
               + a_schritt(3, 'Tag', 'Ankleben, scannen, verbinden. Ab hier ist das Gerät '
                                     'auffindbar.')
               + a_schritt(4, 'Übungen', 'Aus dem Studio wählen oder neu anlegen. Reihenfolge '
                                         'zählt: Übung 1 ist die Vorauswahl.')
               + a_schritt(5, 'Video', 'Je Übung höchstens 45 Sekunden. Überspringbar — ein Gerät '
                                       'ohne Video ist vollständig nutzbar.'),
               rand='#d4ff3f')
    + pfeil
    + a_spalte('Danach', 'Schreibtisch',
               a_schritt(PUNKT, 'Einstellparameter', 'Sitz, Lehne, Startwinkel — je Modell, '
                                                     'nicht je Gerät.')
               + a_schritt(PUNKT, 'Beschreibungen und Fotos', 'Was am Telefon knapp blieb.')
               + a_schritt(PUNKT, 'Fehlende Videos', 'Der Überblick führt Buch darüber, was '
                                                     'noch offen ist.'))
    + '</div>'
    '<div style="display: grid; grid-template-columns: minmax(0, 1fr) 56px minmax(0, 1.5fr) 56px '
    'minmax(0, 1fr);">'
    '<div></div><div></div>'
    '<div style="display: flex; align-items: center; gap: 10px; padding: 14px 20px 0;">'
    '<div style="height: 1px; flex-grow: 1; background: #2a2e36;"></div>'
    '<span style="' + LABEL + ' color: #5c636e;">nächstes Gerät</span>'
    + svg('arrow-up', 14, '#5c636e') +
    '<div style="height: 1px; flex-grow: 1; background: #2a2e36;"></div></div>'
    '<div></div><div></div></div>'
    '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 20px; '
    'margin-top: 40px;">'
    '<div style="border-left: 2px solid #2a2e36; padding-left: 16px;">'
    '<div style="font-weight: 600;">Der Tag kommt aus der Packung</div>'
    '<div style="' + NOTE + ' margin-top: 4px;">Kein Drucken, kein Token auf dem Bildschirm. Welcher '
    'Tag an welchem Gerät hängt, entscheidet der Scan vor dem Gerät — nicht ein Dropdown am '
    'Schreibtisch.</div></div>'
    '<div style="border-left: 2px solid #2a2e36; padding-left: 16px;">'
    '<div style="font-weight: 600;">Übungen gehören dem Studio</div>'
    '<div style="' + NOTE + ' margin-top: 4px;">„Rudern sitzend" wird einmal angelegt und an mehrere '
    'Modelle gehängt. Das Einweisungsvideo hängt dagegen am Paar aus Modell und Übung — zwei '
    'baugleiche Geräte teilen es sich, zwei verschiedene Modelle nicht.</div></div>'
    '<div style="border-left: 2px solid #2a2e36; padding-left: 16px;">'
    '<div style="font-weight: 600;">Schritt 5 darf ausfallen</div>'
    '<div style="' + NOTE + ' margin-top: 4px;">Ein Gerät ohne Video ist vollständig nutzbar, nur '
    'ohne Anleitung. Der Überblick am Schreibtisch zählt, was fehlt.</div></div>'
    '</div></div>\n') + FOOT
schreibe('Ablauf.dc.html', ablauf)
