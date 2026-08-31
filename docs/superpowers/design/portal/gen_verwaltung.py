# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, CARD, HEADROW, PRIMARY,
                   SECONDARY, DESTRUCTIVE, FIELD, BADGE, SEC_TITLE, portal, titel,
                   schreibe, svg, zeile)

NOTE = 'font-size: 12px; color: #5c636e;'


# ---------------------------------------------------------------- Leute
leute = titel('Mitglieder',
              'Wer hier steht, kann sich anmelden und im Studio trainieren. Das Portal zeigt die '
              'Mitgliedschaft — nicht, was jemand trainiert hat.')

leute += '<section style="%s margin-top: 32px;">' % CARD
leute += ('<div style="%s"><h2 style="%s">Einladen</h2>'
          '<span style="%s">Die Einladung geht per E-Mail raus und gilt sieben Tage.</span></div>'
          % (HEADROW, SEC_TITLE, NOTE))
leute += ('<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">'
          '<div style="display: grid; grid-template-columns: minmax(0, 2fr) minmax(0, 1fr); gap: 16px;">'
          '<div style="display: flex; flex-direction: column; gap: 4px;">'
          '<span style="%s color: #9ba3af;">E-Mail</span>'
          '<div style="%s">anna.berger@example.de</div></div>'
          '<div style="display: flex; flex-direction: column; gap: 4px;">'
          '<span style="%s color: #9ba3af;">Rolle</span>'
          '<div style="%s justify-content: space-between;">Mitglied %s</div>'
          '</div></div>'
          '<div><a href="#" style="%s">Einladen</a></div></div>'
          % (LABEL, FIELD, LABEL, FIELD, svg('chevron-down', 18, '#5c636e'), PRIMARY))
leute += '</section>'

leute += '<section style="%s margin-top: 24px;">' % CARD
leute += ('<div style="%s"><h2 style="%s">Im Studio</h2>'
          '<span style="%s">24 Mitglieder · 2 Trainer · 2 offene Einladungen</span></div>'
          % (HEADROW, SEC_TITLE, NOTE))
trainer = '<span style="%s color: #f2f4f7; border-color: #5c636e;">Trainer</span>' % BADGE
mitglied = '<span style="%s">Mitglied</span>' % BADGE
offen = '<span style="%s color: #ffb020; border-color: #ffb020;">eingeladen</span>' % BADGE
leute += zeile('%s &nbsp; tim@kraftwerk-nord.de' % trainer, 'Inhaber · seit Mi., 6. August 2026',
               '<span style="%s">Das bist du</span>' % NOTE)
leute += zeile('%s &nbsp; jana@kraftwerk-nord.de' % trainer, 'Seit Do., 14. August 2026',
               '<a href="#" style="%s">Entfernen</a>' % DESTRUCTIVE)
leute += zeile('%s &nbsp; m.wolf@example.de' % mitglied, 'Seit Mo., 25. August 2026',
               '<a href="#" style="%s">Entfernen</a>' % DESTRUCTIVE)
leute += zeile('%s &nbsp; anna.berger@example.de' % offen,
               'Eingeladen heute · noch nicht angenommen',
               '<a href="#" style="%s">Erneut senden</a><a href="#" style="%s">Zurückziehen</a>'
               % (SECONDARY, DESTRUCTIVE))
leute += zeile('<span style="color: #5c636e;">… 21 weitere Mitglieder</span>', '',
               '<a href="#" style="%s">Alle anzeigen</a>' % SECONDARY, letzte=True)
leute += '</section>'

leute += ('<p style="color: #5c636e; font-size: 13px; line-height: 1.45; margin: 24px 0 0; '
          'max-width: 70ch;">Trainingsdaten eines Mitglieds sieht nur das Mitglied selbst. Das '
          'Portal kann eine Mitgliedschaft anlegen und beenden — es kann keine Sätze, Gewichte '
          'oder Verläufe einsehen.</p>')
schreibe('Leute.dc.html', portal('leute', 900, leute))
