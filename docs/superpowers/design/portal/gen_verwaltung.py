# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, CARD, HEADROW, PRIMARY,
                   SECONDARY, DESTRUCTIVE, FIELD, BADGE, SEC_TITLE, portal, titel,
                   schreibe, svg, zeile, reiter)

NOTE = 'font-size: 12px; color: #5c636e;'
REITER = [('Mitglieder (24)', None), ('Mitarbeiter (4)', None)]


# ---------------------------------------------------------------- Mitglieder
# Mitglieder werden nicht mehr eingeladen -- sie treten mit dem Studio-Code
# bei (Theke, siehe Einstieg-Seite). Das Portal kann eine Mitgliedschaft
# nur noch anlegen lassen (Code) und beenden (Entfernen), nicht mehr werben.
mitglieder = titel(
    'Mitglieder',
    'Wer hier steht, kann sich anmelden und im Studio trainieren. Das Portal zeigt die '
    'Mitgliedschaft — nicht, was jemand trainiert hat.')
mitglieder += reiter(REITER, 'Mitglieder (24)')

mitglieder += '<section style="%s margin-top: 24px;">' % CARD
mitglieder += ('<div style="%s"><h2 style="%s">Alle Mitglieder</h2>'
               '<a href="#" style="color: #9ba3af; font-size: 13px;">Mitglieder treten über den '
               'Studio-Code bei · Einstellungen</a></div>' % (HEADROW, SEC_TITLE))
mitglieder += zeile('m.wolf@example.de', 'Seit Di., 25. August 2026',
                    '<a href="#" style="%s">Entfernen</a>' % DESTRUCTIVE)
mitglieder += zeile('s.roth@example.de', 'Seit So., 23. August 2026',
                    '<a href="#" style="%s">Entfernen</a>' % DESTRUCTIVE)
mitglieder += zeile('p.keller@example.de', 'Seit Fr., 21. August 2026',
                    '<a href="#" style="%s">Entfernen</a>' % DESTRUCTIVE)
mitglieder += zeile('<span style="color: #5c636e;">… 21 weitere</span>', '',
                    '<a href="#" style="%s">Alle anzeigen</a>' % SECONDARY, letzte=True)
mitglieder += '</section>'

mitglieder += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 24px 0 0; '
               'max-width: 70ch;">Zielzustand: Trainingsdaten eines Mitglieds sieht nur das Mitglied '
               'selbst — das Portal legt eine Mitgliedschaft an und beendet sie, sonst nichts. Heute '
               'lassen die Richtlinien der Datenbank Mitarbeiter noch an Sätze, Gewichte und Verläufe '
               'heran; das Portal zeigt sie nirgends, verhindert ist es damit aber nicht.</p>')
schreibe('LeuteMitglieder.dc.html', portal('leute', 840, mitglieder))


# ---------------------------------------------------------------- Mitarbeiter
# Der heikelste Bildschirm im Portal: hier entsteht Zugriff, den der
# Studio-Code nie vergibt. Elevation ist deshalb eine eigene, benannte
# Handlung in einem eigenen Abschnitt -- keine Rolle, die man in einer
# Zeile nebenbei umschaltet.
mitarbeiter = titel(
    'Mitarbeiter',
    'Mitarbeiter pflegen den Katalog und sehen die Mitgliederliste. Zugriff auf alles außer den '
    'Trainingsdaten der Mitglieder — so ist es gedacht; die Datenbank setzt diese Grenze noch '
    'nicht durch.')
mitarbeiter += reiter(REITER, 'Mitarbeiter (4)')

inhaber_plakette = '<span style="%s color: #f2f4f7; border-color: #5c636e;">Inhaber</span>' % BADGE
trainer_plakette = '<span style="%s color: #f2f4f7; border-color: #5c636e;">Trainer</span>' % BADGE

mitarbeiter += '<section style="%s margin-top: 24px;">' % CARD
mitarbeiter += '<div style="%s"><h2 style="%s">Alle Mitarbeiter</h2></div>' % (HEADROW, SEC_TITLE)
herabstufen = '<a href="#" style="%s">Zum Mitglied herabstufen</a>' % DESTRUCTIVE
mitarbeiter += zeile('%s &nbsp; Tim' % inhaber_plakette,
                     'tim@kraftwerk-nord.de · Seit Do., 6. August 2026',
                     '<span style="%s">Das bist du</span>' % NOTE)
mitarbeiter += zeile('%s &nbsp; Marek T.' % trainer_plakette,
                     'marek@kraftwerk-nord.de · Seit Fr., 14. August 2026', herabstufen)
mitarbeiter += zeile('%s &nbsp; Sabine K.' % trainer_plakette,
                     'sabine@kraftwerk-nord.de · Seit Mo., 17. August 2026', herabstufen)
mitarbeiter += zeile('%s &nbsp; Anna B.' % trainer_plakette,
                     'anna@kraftwerk-nord.de · Seit Di., 18. August 2026', herabstufen,
                     letzte=True)
mitarbeiter += '</section>'

mitarbeiter += '<section style="%s margin-top: 24px;">' % CARD
mitarbeiter += '<div style="%s"><h2 style="%s">Mitglied hochstufen</h2></div>' % (HEADROW, SEC_TITLE)
mitarbeiter += ('<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
                '<div style="display: flex; flex-direction: column; gap: 4px;">'
                '<span style="%s color: #9ba3af;">Mitglied</span>'
                '<div style="%s justify-content: space-between;">m.wolf@example.de %s</div></div>'
                '<div><a href="#" style="%s">Zum Trainer machen</a></div>'
                '<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 0; '
                'max-width: 60ch;">Hochstufen gibt Zugriff auf den ganzen Katalog. Der '
                'Studio-Code macht niemanden zum Trainer.</p></div>'
                % (LABEL, FIELD, svg('chevron-down', 18, '#5c636e'), PRIMARY))
mitarbeiter += '</section>'
schreibe('LeuteMitarbeiter.dc.html', portal('leute', 1000, mitarbeiter))


# =============================================================== Einstellungen
# Sammelt, was bisher nirgends hinsollte: Studioname und Zeitzone, die
# Stornofrist, die das Kurse-Feature braucht, der Studio-Code (die
# Beitrittsfläche des Studios) und das eigene Konto. Zwei Reiter, damit
# jede Seite bei genau einer Akzentfläche bleibt.
REITER_EINSTELLUNGEN = [('Studio', None), ('Konto', None)]

WARN = ('border: 1px solid #ffb020; border-radius: 10px; padding: 12px 16px; '
        'color: #ffb020; font-size: 13px; line-height: 1.45; background: transparent;')


# ---------------------------------------------------------------- Studio
studio = titel(
    'Einstellungen',
    'Stammdaten des Studios, die Regel für Kurse und der Code, mit dem Mitglieder beitreten.')
studio += reiter(REITER_EINSTELLUNGEN, 'Studio')

studio += '<section style="%s margin-top: 24px;">' % CARD
studio += '<div style="%s"><h2 style="%s">Stammdaten</h2></div>' % (HEADROW, SEC_TITLE)
studio += ('<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
           '<div style="display: flex; flex-direction: column; gap: 8px;">'
           '<span style="%s color: #9ba3af;">Name</span>'
           '<div style="%s">Kraftwerk Nord</div></div>'
           '<div style="display: flex; flex-direction: column; gap: 8px;">'
           '<span style="%s color: #9ba3af;">Zeitzone</span>'
           '<div style="%s justify-content: space-between;">Europe/Berlin %s</div></div>'
           '<div><a href="#" style="%s">Änderungen speichern</a></div></div>'
           % (LABEL, FIELD, LABEL, FIELD, svg('chevron-down', 18, '#5c636e'), PRIMARY))
studio += '</section>'

studio += '<section style="%s margin-top: 24px;">' % CARD
studio += '<div style="%s"><h2 style="%s">Kurse</h2></div>' % (HEADROW, SEC_TITLE)
studio += ('<div style="padding: 20px; display: flex; flex-direction: column; gap: 8px;">'
           '<span style="%s color: #9ba3af;">Stornofrist</span>'
           '<div style="display: flex; align-items: center; gap: 12px;">'
           '<div style="%s width: 84px; justify-content: center;">2</div>'
           '<span style="color: #9ba3af;">Stunden vor Beginn</span></div>'
           '<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 8px 0 0; '
           'max-width: 60ch;">Bis wann sich ein Mitglied abmelden kann. Das ist eure Regel, keine '
           'Vorgabe von gymodo.</p></div>'
           % (LABEL, FIELD))
studio += '</section>'

studio += '<section style="%s margin-top: 24px;">' % CARD
studio += '<div style="%s"><h2 style="%s">Studio-Code</h2></div>' % (HEADROW, SEC_TITLE)
studio += ('<div style="padding: 20px; display: flex; flex-direction: column; gap: 12px;">'
           '<code style="font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; '
           'font-size: 18px; letter-spacing: 0.08em; background: #0f1114; border: 1px solid #2a2e36; '
           'border-radius: 10px; padding: 16px; display: block;">KWNORD-7F2X</code>'
           '<span style="font-size: 12px; color: #5c636e;">Der zweite Weg ins Studio, wenn kein '
           'Aushangschild zur Hand ist: Mitglieder geben den Code in der App ein. Er macht '
           'niemanden zum Trainer — Mitarbeiter fügt ihr unter Leute hinzu.</span>'
           '<div style="display: flex; gap: 12px;">'
           '<a href="#" style="%s">Kopieren</a>'
           '<a href="#" style="%s">Neuen Code erzeugen</a></div>'
           # "Aushaenge" hiess hier frueher Papier mit aufgedrucktem Code -- zwei
           # Bildschirme weiter ist ein Aushang aber ein geliefertes Schild mit
           # Token. Ein Wort, zwei Erzeugnisse, benachbarte Seiten.
           '<div style="%s">Ein neuer Code macht den alten sofort ungültig. Ausdrucke und Verträge '
           'mit dem alten Code funktionieren dann nicht mehr. Aushangschilder tragen keinen '
           'Code — sie bleiben gültig.</div></div>'
           % (SECONDARY, SECONDARY, WARN))
studio += '</section>'
schreibe('EinstellungenStudio.dc.html', portal('einstellungen', 1300, studio))


# ---------------------------------------------------------------- Konto
konto = titel(
    'Einstellungen',
    'Deine E-Mail, dein Passwort und die Sitzung, in der du gerade angemeldet bist.')
konto += reiter(REITER_EINSTELLUNGEN, 'Konto')

konto += '<section style="%s margin-top: 24px;">' % CARD
konto += '<div style="%s"><h2 style="%s">Konto</h2></div>' % (HEADROW, SEC_TITLE)
konto += ('<div style="padding: 20px; display: flex; flex-direction: column; gap: 4px;">'
          '<span style="%s color: #9ba3af;">E-Mail</span>'
          '<div style="color: #9ba3af; font-weight: 600;">tim@kraftwerk-nord.de</div>'
          '<span style="font-size: 12px; color: #5c636e; margin-top: 2px;">Inhaber von Kraftwerk '
          'Nord seit Do., 6. August 2026</span></div>'
          % LABEL)
konto += '</section>'

konto += '<section style="%s margin-top: 24px;">' % CARD
konto += '<div style="%s"><h2 style="%s">Passwort ändern</h2></div>' % (HEADROW, SEC_TITLE)
konto += ('<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
          '<div style="display: flex; flex-direction: column; gap: 8px;">'
          '<span style="%s color: #9ba3af;">Aktuelles Passwort</span>'
          '<div style="%s letter-spacing: 0.2em;">••••••••••</div></div>'
          '<div style="display: flex; flex-direction: column; gap: 8px;">'
          '<span style="%s color: #9ba3af;">Neues Passwort</span>'
          '<div style="%s letter-spacing: 0.2em;">••••••••••</div></div>'
          '<div style="display: flex; flex-direction: column; gap: 8px;">'
          '<span style="%s color: #9ba3af;">Wiederholen</span>'
          '<div style="%s letter-spacing: 0.2em;">••••••••••</div></div>'
          '<div><a href="#" style="%s">Passwort ändern</a></div></div>'
          % (LABEL, FIELD, LABEL, FIELD, LABEL, FIELD, PRIMARY))
konto += '</section>'

konto += '<section style="%s margin-top: 24px;">' % CARD
konto += '<div style="%s"><h2 style="%s">Abmelden</h2></div>' % (HEADROW, SEC_TITLE)
konto += ('<div style="padding: 20px;"><a href="#" style="%s">Abmelden</a></div>' % DESTRUCTIVE)
konto += '</section>'
schreibe('EinstellungenKonto.dc.html', portal('einstellungen', 1080, konto))
