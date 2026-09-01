# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, CARD, HEADROW, PRIMARY,
                   SECONDARY, DESTRUCTIVE, FIELD, BADGE, SEC_TITLE, portal, titel,
                   schreibe, svg, zeile, reiter)

NOTE = 'font-size: 12px; color: #5c636e;'
REITER = [('Mitglieder (24)', None), ('Mitarbeiter (2)', None)]


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
mitglieder += zeile('m.wolf@example.de', 'Seit Mo., 25. August 2026',
                    '<a href="#" style="%s">Entfernen</a>' % DESTRUCTIVE)
mitglieder += zeile('s.roth@example.de', 'Seit Sa., 23. August 2026',
                    '<a href="#" style="%s">Entfernen</a>' % DESTRUCTIVE)
mitglieder += zeile('p.keller@example.de', 'Seit Do., 21. August 2026',
                    '<a href="#" style="%s">Entfernen</a>' % DESTRUCTIVE)
mitglieder += zeile('<span style="color: #5c636e;">… 21 weitere</span>', '',
                    '<a href="#" style="%s">Alle anzeigen</a>' % SECONDARY, letzte=True)
mitglieder += '</section>'

mitglieder += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 24px 0 0; '
               'max-width: 70ch;">Trainingsdaten eines Mitglieds sieht nur das Mitglied selbst. Das '
               'Portal kann eine Mitgliedschaft anlegen und beenden — es kann keine Sätze, Gewichte '
               'oder Verläufe einsehen.</p>')
schreibe('LeuteMitglieder.dc.html', portal('leute', 760, mitglieder))


# ---------------------------------------------------------------- Mitarbeiter
# Der heikelste Bildschirm im Portal: hier entsteht Zugriff, den der
# Studio-Code nie vergibt. Elevation ist deshalb eine eigene, benannte
# Handlung in einem eigenen Abschnitt -- keine Rolle, die man in einer
# Zeile nebenbei umschaltet.
mitarbeiter = titel(
    'Mitarbeiter',
    'Mitarbeiter pflegen den Katalog und sehen die Mitgliederliste. Wer hier steht, hat Zugriff '
    'auf alles außer den Trainingsdaten der Mitglieder.')
mitarbeiter += reiter(REITER, 'Mitarbeiter (2)')

inhaber_plakette = '<span style="%s color: #f2f4f7; border-color: #5c636e;">Inhaber</span>' % BADGE
trainer_plakette = '<span style="%s color: #f2f4f7; border-color: #5c636e;">Trainer</span>' % BADGE

mitarbeiter += '<section style="%s margin-top: 24px;">' % CARD
mitarbeiter += '<div style="%s"><h2 style="%s">Alle Mitarbeiter</h2></div>' % (HEADROW, SEC_TITLE)
mitarbeiter += zeile('%s &nbsp; tim@kraftwerk-nord.de' % inhaber_plakette,
                     'Seit Mi., 6. August 2026',
                     '<span style="%s">Das bist du</span>' % NOTE)
mitarbeiter += zeile('%s &nbsp; jana@kraftwerk-nord.de' % trainer_plakette,
                     'Seit Do., 14. August 2026',
                     '<a href="#" style="%s">Zum Mitglied herabstufen</a>' % DESTRUCTIVE,
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
schreibe('LeuteMitarbeiter.dc.html', portal('leute', 700, mitarbeiter))
