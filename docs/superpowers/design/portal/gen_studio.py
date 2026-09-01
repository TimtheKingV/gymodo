# -*- coding: utf-8 -*-
"""Erzeugt die Kurse-Screens: Studio-Bereich des Portals.

Datenmodell aus docs/superpowers/plans/2026-08-30-kurse-datenmodell.md:
Vorlage und Termin sind getrennte Tabellen, capacity liegt am Termin (nicht
an der Vorlage), Serientermine werden beim Anlegen ausgeschrieben statt als
Regel gespeichert, und eine Absage setzt status='abgesagt' statt zu loeschen
-- der Termin bleibt fuer angemeldete Mitglieder sichtbar.
"""
from build import (LABEL, CARD, HEADROW, ROW, ROW_LAST, PRIMARY, SECONDARY,
                    DESTRUCTIVE, FIELD, BADGE, SEC_TITLE, portal, titel,
                    schreibe, svg, zeile, zurueck, reiter)

NOTE = 'font-size: 12px; color: #5c636e; line-height: 1.4;'
PARA = 'color: #5c636e; font-size: 13px; line-height: 1.45; margin: 16px 0 0; max-width: 64ch;'


def kopf(zurueck_text, titel_text, lead=None):
    out = ('<a href="#" style="%s color: #5c636e;">%s</a>'
           '<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.025em; '
           'text-transform: uppercase; margin: 8px 0 0;">%s</h1>'
           % (LABEL, zurueck(zurueck_text), titel_text))
    if lead:
        out += '<p style="color: #9ba3af; margin: 8px 0 0; max-width: 62ch;">%s</p>' % lead
    return out


def feld(label, wert, auswahl=False, hoehe=None):
    innen = FIELD
    if hoehe:
        innen = innen.replace('min-height: 44px;', 'min-height: %dpx;' % hoehe)
        innen += ' align-items: flex-start;'
    if auswahl:
        innen += ' justify-content: space-between;'
    chevron = svg('chevron-down', 18, '#5c636e') if auswahl else ''
    return ('<div style="display: flex; flex-direction: column; gap: 8px;">'
            '<span style="%s color: #9ba3af;">%s</span>'
            '<div style="%s">%s%s</div></div>' % (LABEL, label, innen, wert, chevron))


def zwei(a, b):
    return ('<div style="display: flex; gap: 16px;">'
            '<div style="flex: 1;">%s</div><div style="flex: 1;">%s</div></div>' % (a, b))


def abschnitt(titel_text, inhalt, aktion=None):
    kopf_html = '<h2 style="%s">%s</h2>' % (SEC_TITLE, titel_text)
    if aktion:
        kopf_html += aktion
    return ('<section style="%s margin-top: 24px;">'
            '<div style="%s">%s</div>%s</section>' % (CARD, HEADROW, kopf_html, inhalt))


def einfache_zeile(text, letzte=False):
    stil = ROW_LAST if letzte else ROW
    return '<div style="%s"><span style="font-weight: 600;">%s</span></div>' % (stil, text)


# ============================================================== Kurse (Woche)
# Eine Tagesliste, kein Kalendergitter: ein Gitter loest das Erkennen von
# Ueberschneidungen zwischen parallelen Raeumen -- bei ein bis zwei Raeumen
# gibt es dieses Problem nicht, das Gitter stuende leer, und die Zahl, auf
# die es ankommt (die Belegung), muesste man sich aus der Kachel klauben.
kurse = titel('Kurse')
kurse += ('<div style="display: flex; align-items: center; justify-content: space-between; '
          'gap: 16px; margin-top: 20px; flex-wrap: wrap;">'
          '<div style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap;">'
          '<a href="#" style="%s">%s Vorige Woche</a>'
          '<span style="font-weight: 700; font-size: 16px;">Mo., 31. August – So., 6. September 2026</span>'
          '<a href="#" style="%s">Nächste Woche %s</a></div>'
          '<a href="#" style="%s">Termin anlegen</a></div>'
          % (SECONDARY, svg('arrow-left', 14), SECONDARY, svg('arrow-right', 14), PRIMARY))
kurse += ('<a href="#" style="font-size: 13px; color: #9ba3af; display: inline-block; '
          'margin-top: 12px;">Vorlagen verwalten</a>')

abgesagt_plakette = '<span style="%s color: #ff5a4e; border-color: #ff5a4e;">abgesagt</span>' % BADGE


def belegung(n, kap, warteliste=None):
    out = '<div style="text-align: right;"><div style="font-weight: 700;">%d von %d</div>' % (n, kap)
    if warteliste:
        out += '<div style="font-size: 11px; color: #5c636e; margin-top: 2px;">+%d Warteliste</div>' % warteliste
    out += '</div>'
    return out


def tag(datum, zeilen):
    return ('<div style="margin-top: 24px;">'
            '<div style="%s color: #9ba3af; margin-bottom: 8px;">%s</div>'
            '<section style="%s">%s</section></div>' % (LABEL, datum, CARD, zeilen))


kurse += tag('Montag, 31. August', (
    zeile('18:00 · Kraftzirkel', 'Jana · Raum 1', belegung(12, 16))
    + zeile('19:30 · Rücken fit', 'Tim · Raum 2', belegung(8, 12), letzte=True)
))

kurse += tag('Dienstag, 1. September', einfache_zeile(
    '<span style="color: #5c636e; font-weight: 400;">Keine Kurse</span>', letzte=True))

kurse += tag('Mittwoch, 2. September', zeile(
    '18:00 · Kraftzirkel', 'Jana · Raum 1', belegung(16, 16, warteliste=3), letzte=True))

kurse += tag('Donnerstag, 3. September', zeile(
    '18:00 · Kraftzirkel', 'Jana · Raum 1', belegung(12, 16), letzte=True))

kurse += tag('Freitag, 4. September', zeile(
    '<span style="text-decoration: line-through; color: #5c636e;">18:00 · Kraftzirkel</span>',
    '<span style="text-decoration: line-through;">Jana · Raum 1</span>',
    abgesagt_plakette, letzte=True, meta_faint=True))

kurse += tag('Samstag, 5. September', einfache_zeile(
    '<span style="color: #5c636e; font-weight: 400;">Keine Kurse</span>', letzte=True))

kurse += tag('Sonntag, 6. September', einfache_zeile(
    '<span style="color: #5c636e; font-weight: 400;">Keine Kurse</span>', letzte=True))

schreibe('Kurse.dc.html', portal('kurse', 1780, kurse))


# ========================================================== Kursvorlagen
# Vorlage und Termin sind bewusst getrennt: "Kraftzirkel" ist die Vorlage,
# "Do 3.9. 18:00" der Termin. Ohne diese Trennung pflegt ein Trainer jede
# Woche dieselbe Beschreibung neu -- siehe Datenmodell-Notiz.
kursvorlagen = ('<a href="#" style="%s color: #5c636e;">%s</a>'
                '<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.025em; '
                'text-transform: uppercase; margin: 8px 0 0;">Kursvorlagen</h1>'
                '<p style="color: #9ba3af; margin: 8px 0 0; max-width: 62ch;">Eine Vorlage '
                'beschreibt den Kurs. Die einzelnen Termine im Kalender entstehen daraus — '
                'und behalten ihre Werte, auch wenn du die Vorlage später änderst.</p>'
                % (LABEL, zurueck('Kurse')))

kursvorlagen += abschnitt(
    'Alle Vorlagen',
    zeile('Kraftzirkel', '45 min · 16 Plätze · Standard: Jana · 4 Termine in den nächsten 4 Wochen',
          '<a href="#" style="%s">Öffnen</a>' % SECONDARY)
    + zeile('Rücken fit', '45 min · 12 Plätze · Standard: Tim · 4 Termine in den nächsten 4 Wochen',
            '<a href="#" style="%s">Öffnen</a>' % SECONDARY)
    + zeile('Yoga Flow',
            '<span style="color: #5c636e;">60 min · 10 Plätze · Standard: Jana · keine Termine in den nächsten 4 Wochen</span>',
            '<a href="#" style="%s">Öffnen</a>' % SECONDARY, letzte=True),
    aktion='<a href="#" style="%s">Vorlage anlegen</a>' % PRIMARY)

schreibe('Kursvorlagen.dc.html', portal('kurse', 820, kursvorlagen))


# =========================================================== Kursvorlage
# Reiter halten das Formular bei genau einer Akzentflaeche: nur "Stammdaten"
# ist gebaut, "Termine (7)" bleibt wie bei Modell.dc.html unbestueckter Reiter.
kursvorlage = kopf('Kursvorlagen', 'Kraftzirkel', 'Zirkeltraining aus Kraft- und Ausdauerübungen '
                    'im Wechsel · 45 min · 16 Plätze · Standard: Jana')
kursvorlage += reiter([('Stammdaten', None), ('Termine (7)', None)], 'Stammdaten')

kursvorlage += abschnitt('Stammdaten', (
    '<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
    + feld('Name', 'Kraftzirkel')
    + feld('Beschreibung', 'Zirkeltraining aus Kraft- und Ausdauerübungen im Wechsel, für alle '
           'Level geeignet.', hoehe=88)
    + zwei(feld('Dauer', '45 min'), feld('Plätze', '16'))
    + feld('Standard-Trainer', 'Jana', auswahl=True)
    + '<div><a href="#" style="%s">Änderungen speichern</a></div></div>' % PRIMARY
))

foto_platzhalter = ('<div style="width: 160px; height: 120px; flex-shrink: 0; border: 1px dashed '
                     '#2a2e36; border-radius: 10px; background: #0f1114; display: flex; '
                     'align-items: center; justify-content: center; text-align: center; '
                     'color: #5c636e; font-size: 12px; padding: 8px;">Noch kein Foto</div>')
kursvorlage += abschnitt('Foto', (
    '<div style="padding: 20px; display: flex; gap: 20px; align-items: flex-start; flex-wrap: wrap;">'
    + foto_platzhalter
    + '<div style="display: flex; flex-direction: column; gap: 8px; flex: 1; min-width: 220px;">'
    + '<a href="#" style="%s">Foto auswählen</a>' % SECONDARY
    + '<span style="%s">JPEG oder PNG, höchstens 10 MiB. Aufnahmedaten werden beim Hochladen entfernt.</span>' % NOTE
    + '</div></div>'
))

schreibe('Kursvorlage.dc.html', portal('kurse', 1420, kursvorlage))


# ========================================================= TerminAnlegen
# Der Kern dieses Bildschirms ist die Vorschau: Serientermine werden beim
# Anlegen ausgeschrieben, nicht als Regel gespeichert -- also zeigt der
# Bildschirm vor dem Anlegen genau, welche Zeilen entstehen.
anlegen = kopf('Kurse', 'Termin anlegen')

anlegen += abschnitt('Termin', (
    '<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
    + feld('Vorlage', 'Kraftzirkel', auswahl=True)
    + zwei(feld('Datum', 'Do., 3. September 2026'), feld('Uhrzeit', '18:00'))
    + zwei(feld('Dauer', '45 min'), feld('Plätze', '16'))
    + zwei(feld('Raum', 'Raum 1', auswahl=True), feld('Trainer', 'Jana', auswahl=True))
    + '</div>'
))

anlegen += abschnitt('Wiederholen', (
    '<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
    + zwei(feld('Wiederholung', 'Wöchentlich', auswahl=True), feld('bis', 'Do., 3. Dezember 2026'))
    + '</div>'
))

vorschau_liste = (
    einfache_zeile('Do., 3. September 2026 · 18:00')
    + einfache_zeile('Do., 10. September 2026 · 18:00')
    + einfache_zeile('Do., 17. September 2026 · 18:00')
    + einfache_zeile('<span style="color: #5c636e; font-weight: 400;">… 11 weitere</span>', letzte=True)
)

anlegen += ('<p style="%s margin: 24px 0 8px;">Diese 14 Termine werden angelegt. Jeder ist danach '
            'einzeln änderbar und absagbar.</p>' % NOTE)
anlegen += '<section style="%s">%s</section>' % (CARD, vorschau_liste)
anlegen += ('<p style="%s">Änderst du die Vorlage später, bleiben diese 14 Termine unverändert — '
            'sie behalten ihre eigenen Werte.</p>' % PARA)
anlegen += '<div style="margin-top: 20px;"><a href="#" style="%s">14 Termine anlegen</a></div>' % PRIMARY

schreibe('TerminAnlegen.dc.html', portal('kurse', 1680, anlegen))


# ================================================================= Termin
# Die Teilnehmerliste ist der einzige Ort im Portal, an dem einzelne Namen
# auftauchen -- eine Anwesenheitsliste, die dem Studio gehoert, nicht der
# Mitgliedschaft. Absagen setzt status='abgesagt', loescht nicht: der Termin
# bleibt fuer angemeldete Mitglieder sichtbar.
termin = kopf('Kurse', 'Kraftzirkel', 'Do., 3. September 2026 · 18:00–18:45 · Raum 1')

termin += abschnitt('Termin', (
    '<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
    + zwei(feld('Uhrzeit', '18:00'), feld('Dauer', '45 min'))
    + zwei(feld('Plätze', '16'), feld('Raum', 'Raum 1', auswahl=True))
    + '<div style="display: flex; flex-direction: column; gap: 8px;">'
    + '<span style="%s color: #9ba3af;">Trainer</span>' % LABEL
    + '<div style="%s justify-content: space-between;">Tim %s</div>' % (FIELD, svg('chevron-down', 18, '#5c636e'))
    + '<span style="%s">Abweichend von der Vorlage (Standard: Jana).</span>' % NOTE
    + '</div>'
    + '<div><a href="#" style="%s">Änderungen speichern</a></div></div>' % PRIMARY
))

teilnehmer = (
    zeile('M. Wolf', 'Angemeldet Mo., 25. August 2026 · 14:32',
          '<a href="#" style="%s">Abmelden</a>' % DESTRUCTIVE)
    + zeile('S. Roth', 'Angemeldet Di., 26. August 2026 · 09:07',
            '<a href="#" style="%s">Abmelden</a>' % DESTRUCTIVE)
    + zeile('P. Keller', 'Angemeldet Mi., 27. August 2026 · 18:50',
            '<a href="#" style="%s">Abmelden</a>' % DESTRUCTIVE)
    + zeile('<span style="color: #5c636e;">… 9 weitere</span>', '',
            '<a href="#" style="%s">Alle anzeigen</a>' % SECONDARY, letzte=True)
)
termin += abschnitt('Angemeldet (12 von 16)', teilnehmer)

warteliste = (
    zeile('L. Bauer', 'Position 1', '')
    + zeile('N. Fischer', 'Position 2', '')
    + zeile('K. Hartmann', 'Position 3', '', letzte=True)
)
termin += abschnitt('Warteliste (3)', warteliste)

termin += ('<p style="%s">Diese Liste ist eine Anwesenheitsliste. Andere Mitglieder sehen sie '
           'nicht.</p>' % PARA)

termin += abschnitt('Absagen', (
    '<div style="padding: 20px; display: flex; align-items: center; gap: 16px; flex-wrap: wrap;">'
    + '<a href="#" style="%s">Termin absagen</a>' % DESTRUCTIVE
    + '<span style="%s">Der Termin bleibt sichtbar und wird als abgesagt gekennzeichnet. '
      'Angemeldete Mitglieder sehen, dass er ausfällt.</span></div>' % NOTE
))

schreibe('Termin.dc.html', portal('kurse', 2020, termin))
