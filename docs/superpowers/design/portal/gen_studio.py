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
    '18:00 · Kraftzirkel', 'Jana · Raum 1', belegung(16, 16, warteliste=3), letzte=True))

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
    zeile('Kraftzirkel', '45 min · 16 Plätze · Standard: Jana · 16 Termine in den nächsten 4 Wochen',
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
# ist gebaut, "Termine (14)" bleibt wie bei Modell.dc.html unbestueckter
# Reiter -- die Zahl stimmt mit der Serie ueberein, die TerminAnlegen.dc.html
# fuer diese Vorlage anlegt.
kursvorlage = kopf('Kursvorlagen', 'Kraftzirkel', 'Zirkeltraining aus Kraft- und Ausdauerübungen '
                    'im Wechsel · 45 min · 16 Plätze · Standard: Jana')
kursvorlage += reiter([('Stammdaten', None), ('Termine (14)', None)], 'Stammdaten')

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
    + zeile('<span style="color: #5c636e;">… 13 weitere</span>', '',
            '<a href="#" style="%s">Alle anzeigen</a>' % SECONDARY, letzte=True)
)
termin += abschnitt('Angemeldet (16 von 16)', teilnehmer)

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


# ================================================================= Überblick
# Der Einleitungssatz zog frueher eine Grenze, die die Datenbank nicht zieht:
# "einzelne Mitglieder und ihre Werte sieht das Portal nicht" -- das Portal
# sieht sehr wohl, wer zu einem Kurstermin angemeldet ist (siehe Termin.dc.html).
# Was es wirklich nicht zeigt, sind Trainingsdaten: Saetze, Gewichte, Verlaeufe.
main = titel('Überblick', 'Letzte 30 Tage. Studioweite Summen — welches Mitglied was '
             'trainiert hat, zeigt das Portal nirgends.')

main += ("""
<div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; margin-top: 32px;">
  <div style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; padding: 20px;">
    <div style="font-size: 34px; font-weight: 800; letter-spacing: -0.03em; line-height: 1;">2<span style="color: #5c636e; font-size: 20px;"> / 4</span></div>
    <div style="font-size: 11px; font-weight: 800; letter-spacing: 0.14em; text-transform: uppercase; color: #9ba3af; margin-top: 12px;">Geräte erreichbar</div>
  </div>
  <div style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; padding: 20px;">
    <div style="font-size: 34px; font-weight: 800; letter-spacing: -0.03em; line-height: 1;">23</div>
    <div style="font-size: 11px; font-weight: 800; letter-spacing: 0.14em; text-transform: uppercase; color: #9ba3af; margin-top: 12px;">Mitglieder aktiv</div>
  </div>
  <div style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; padding: 20px;">
    <div style="font-size: 34px; font-weight: 800; letter-spacing: -0.03em; line-height: 1;">412</div>
    <div style="font-size: 11px; font-weight: 800; letter-spacing: 0.14em; text-transform: uppercase; color: #9ba3af; margin-top: 12px;">Sätze erfasst</div>
  </div>
  <div style="border: 1px solid #ffb020; border-radius: 12px; background: #14161a; padding: 20px;">
    <div style="font-size: 34px; font-weight: 800; letter-spacing: -0.03em; line-height: 1;">7</div>
    <div style="font-size: 11px; font-weight: 800; letter-spacing: 0.14em; text-transform: uppercase; color: #ffb020; margin-top: 12px;">Probleme gemeldet</div>
  </div>
</div>
""")

# "Diese Woche" holt die naechsten drei Kurstermine samt Belegung aus
# Kurse.dc.html herueber -- dieselben Zahlen, keine neuen erfunden.
main += abschnitt('Diese Woche', (
    zeile('Mo., 31. August 2026 · 18:00 · Kraftzirkel', 'Jana · Raum 1', belegung(12, 16))
    + zeile('Mo., 31. August 2026 · 19:30 · Rücken fit', 'Tim · Raum 2', belegung(8, 12))
    + zeile('Mi., 2. September 2026 · 18:00 · Kraftzirkel', 'Jana · Raum 1',
            belegung(16, 16, warteliste=3), letzte=True)
), aktion='<a href="#" style="%s">Zu den Kursen</a>' % SECONDARY)

main += ("""
<div style="display: grid; grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr); gap: 24px; margin-top: 24px;">

  <section style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; overflow: hidden;">
    <div style="padding: 16px 20px; border-bottom: 1px solid #2a2e36;">
      <h2 style="font-size: 11px; font-weight: 800; letter-spacing: 0.14em; text-transform: uppercase; color: #9ba3af; margin: 0;">Was noch fehlt</h2>
    </div>
    <div style="display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 20px; border-bottom: 1px solid #2a2e36;">
      <div>
        <div style="font-weight: 600;">1 Gerät ohne Tag</div>
        <div style="font-size: 12px; color: #9ba3af; margin-top: 2px;">Für Mitglieder nicht auffindbar</div>
      </div>
      <a href="#" style="display: inline-flex; align-items: center; justify-content: center; height: 40px; padding: 0 16px; border-radius: 10px; background: #d4ff3f; color: #0a0b0d; font-weight: 700; flex-shrink: 0;">Tags anlegen</a>
    </div>
    <div style="display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 20px; border-bottom: 1px solid #2a2e36;">
      <div>
        <div style="font-weight: 600;">1 Übung ohne Einweisungsvideo</div>
        <div style="font-size: 12px; color: #5c636e; margin-top: 2px;">Nutzbar, nur ohne Anleitung</div>
      </div>
      <a href="#" style="display: inline-flex; align-items: center; justify-content: center; height: 40px; padding: 0 16px; border-radius: 10px; background: #1d2026; border: 1px solid #2a2e36; color: #f2f4f7; font-weight: 600; flex-shrink: 0;">Ansehen</a>
    </div>
    <div style="display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 20px;">
      <div>
        <div style="font-weight: 600;">1 Modell ohne Foto</div>
        <div style="font-size: 12px; color: #5c636e; margin-top: 2px;">Brustpresse</div>
      </div>
      <a href="#" style="display: inline-flex; align-items: center; justify-content: center; height: 40px; padding: 0 16px; border-radius: 10px; background: #1d2026; border: 1px solid #2a2e36; color: #f2f4f7; font-weight: 600; flex-shrink: 0;">Ansehen</a>
    </div>
  </section>

  <section style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; overflow: hidden;">
    <div style="padding: 16px 20px; border-bottom: 1px solid #2a2e36; display: flex; align-items: baseline; justify-content: space-between; gap: 16px;">
      <h2 style="font-size: 11px; font-weight: 800; letter-spacing: 0.14em; text-transform: uppercase; color: #9ba3af; margin: 0;">Meistgenutzt</h2>
      <span style="font-size: 12px; color: #5c636e;">Sätze</span>
    </div>
    <div style="display: flex; align-items: baseline; justify-content: space-between; padding: 12px 20px; border-bottom: 1px solid #2a2e36;">
      <span style="font-weight: 600;">Beinpresse 7</span><span style="color: #9ba3af;">312</span>
    </div>
    <div style="display: flex; align-items: baseline; justify-content: space-between; padding: 12px 20px; border-bottom: 1px solid #2a2e36;">
      <span style="font-weight: 600;">Latzug 12</span><span style="color: #9ba3af;">287</span>
    </div>
    <div style="display: flex; align-items: baseline; justify-content: space-between; padding: 12px 20px; border-bottom: 1px solid #2a2e36;">
      <span style="font-weight: 600;">Latzug 13</span><span style="color: #9ba3af;">198</span>
    </div>
    <div style="display: flex; align-items: baseline; justify-content: space-between; padding: 12px 20px;">
      <span style="color: #5c636e;">Beinpresse 8</span><span style="color: #5c636e;">stillgelegt</span>
    </div>
  </section>
</div>

<section style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; overflow: hidden; margin-top: 24px;">
  <div style="padding: 16px 20px; border-bottom: 1px solid #2a2e36; display: flex; align-items: baseline; justify-content: space-between; gap: 16px;">
    <h2 style="font-size: 11px; font-weight: 800; letter-spacing: 0.14em; text-transform: uppercase; color: #9ba3af; margin: 0;">Gemeldete Probleme</h2>
    <span style="font-size: 12px; color: #5c636e;">Ohne Namen. Wer gemeldet hat, steht hier nicht.</span>
  </div>
  <div style="display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 20px; border-bottom: 1px solid #2a2e36;">
    <div>
      <div style="font-weight: 600;">Latzug 13</div>
      <div style="font-size: 12px; color: #9ba3af; margin-top: 2px;">Schmerz</div>
    </div>
    <span style="display: inline-flex; align-items: center; border: 1px solid #ffb020; color: #ffb020; border-radius: 999px; padding: 2px 10px; font-size: 11px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase;">2 ×</span>
  </div>
  <div style="display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 20px; border-bottom: 1px solid #2a2e36;">
    <div>
      <div style="font-weight: 600;">Latzug 12</div>
      <div style="font-size: 12px; color: #9ba3af; margin-top: 2px;">Zu schwer</div>
    </div>
    <span style="display: inline-flex; align-items: center; border: 1px solid #2a2e36; color: #9ba3af; border-radius: 999px; padding: 2px 10px; font-size: 11px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase;">3 ×</span>
  </div>
  <div style="display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 20px;">
    <div>
      <div style="font-weight: 600;">Beinpresse 7</div>
      <div style="font-size: 12px; color: #9ba3af; margin-top: 2px;">Gerät passt nicht</div>
    </div>
    <span style="display: inline-flex; align-items: center; border: 1px solid #2a2e36; color: #9ba3af; border-radius: 999px; padding: 2px 10px; font-size: 11px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase;">2 ×</span>
  </div>
</section>

<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 24px 0 0; max-width: 70ch;">gymodo misst nichts. Alles hier ist gezählt, was Mitglieder selbst bestätigt haben.</p>
""")

schreibe('Main.dc.html', portal('ueberblick', 1320, main))


# ================================================================= Zustaende
# Ein Blatt, kein Bildschirm: es zeigt die Zustaende, die im Portal wirklich
# gelten. Offline gilt hier nicht -- das ist ein Konzept der Trainingshalle,
# nicht des Portals. Skelett gilt sehr wohl, aber nur fuer Medien -- genau
# das zeigt die Karte "Medien laden"; fuer Katalogwerte waere ein Skelett
# eine Luege ueber die Architektur (Spec Abschnitt 5).
zustaende = titel('Zustände', 'Drei Zustände plus ein Ladezustand für Medien. Offline gilt '
                   'hier nicht — das ist ein Konzept der Trainingshalle. Skelett gilt laut '
                   'Spezifikation nur für Medien.')

FEHLER = ('border: 1px solid #ff5a4e; border-radius: 12px; background: #14161a;')
DEAKTIVIERT_BTN = ('display: inline-flex; align-items: center; justify-content: center; '
                    'height: 40px; padding: 0 16px; border-radius: 10px; background: #1d2026; '
                    'border: 1px solid #2a2e36; color: #5c636e; font-weight: 600;')

leer_karte = ('<div style="%s margin-top: 32px;">'
              '<div style="padding: 32px 20px; display: flex; flex-direction: column; gap: 12px; '
              'align-items: flex-start;">'
              '<span style="%s color: #5c636e;">Leer</span>'
              '<div style="font-size: 17px; font-weight: 700;">Noch kein Kurs.</div>'
              '<div style="color: #9ba3af; font-size: 13px;">Leg eine Vorlage an, dann '
              'Termine daraus.</div>'
              '<a href="#" style="%s margin-top: 4px;">Vorlage anlegen</a>'
              '</div></div>' % (CARD, LABEL, PRIMARY))

fehler_karte = ('<div style="%s margin-top: 32px;">'
                 '<div style="padding: 32px 20px; display: flex; flex-direction: column; gap: 8px;">'
                 '<span style="%s color: #ff5a4e;">Fehler</span>'
                 '<div style="font-weight: 600;">Das Gewicht liegt über dem Gerätemaximum '
                 'von 100,0 kg.</div></div></div>' % (FEHLER, LABEL))

deaktiviert_karte = ('<div style="%s margin-top: 32px;">'
                      '<div style="padding: 32px 20px; display: flex; flex-direction: column; gap: 12px;">'
                      '<span style="%s color: #5c636e;">Deaktiviert</span>'
                      '<div style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap;">'
                      '<span style="%s">Zuweisen</span>'
                      '<span style="color: #5c636e; font-size: 13px;">Wähle zuerst ein Gerät.</span>'
                      '</div></div></div>' % (CARD, LABEL, DEAKTIVIERT_BTN))

zustaende += ('<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px;">'
              + leer_karte + fehler_karte + deaktiviert_karte + '</div>')

medien_platzhalter = ('<div style="width: 160px; height: 120px; flex-shrink: 0; border-radius: 10px; '
                       'background: #1d2026;"></div>')
zustaende += abschnitt('Medien laden', (
    '<div style="padding: 20px; display: flex; gap: 20px; align-items: flex-start; flex-wrap: wrap;">'
    + medien_platzhalter
    + '<span style="%s max-width: 46ch;">Nur für Fotos und Videos. Katalogwerte sind sofort da '
      '— ein Skelett darüber wäre eine Lüge über die Architektur.</span></div>' % NOTE
))

schreibe('Zustaende.dc.html', portal(None, 760, zustaende))
