# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, CARD, HEADROW, ROW, ROW_LAST, PRIMARY,
                   SECONDARY, DESTRUCTIVE, FIELD, BADGE, portal, titel, schreibe,
                   svg, zurueck)

SEC_TITLE = '%s color: #9ba3af; margin: 0;' % LABEL
NOTE = 'font-size: 12px; color: #5c636e;'


def zeile(haupt, meta, rechts, letzte=False, meta_faint=False):
    stil = ROW_LAST if letzte else ROW
    mc = '#5c636e' if meta_faint else '#9ba3af'
    return ('<div style="%s"><div style="min-width: 0;">'
            '<div style="font-weight: 600;">%s</div>'
            '<div style="font-size: 12px; color: %s; margin-top: 2px;">%s</div></div>'
            '<div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">%s</div></div>'
            % (stil, haupt, mc, meta, rechts))


# ---------------------------------------------------------------- Katalog
katalog = titel(
    'Gerätemodelle',
    'Ein Modell beschreibt den Gerätetyp. Die einzelnen Geräte im Raum sind Instanzen davon — '
    'zwei Kabelzüge nebeneinander sind ein Modell und zwei Geräte.')
katalog += '<section style="%s margin-top: 32px;">' % CARD
katalog += ('<div style="%s"><h2 style="%s">Alle Modelle</h2>'
            '<a href="#" style="%s">Modell anlegen</a></div>' % (HEADROW, SEC_TITLE, SECONDARY))
katalog += zeile('Latzug',
                 'Technogym · 2 Geräte, 1 erreichbar · 2 Übungen, 1 mit Video · Foto',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY)
katalog += zeile('Beinpresse',
                 'Gym80 · 2 Geräte, 1 erreichbar · 1 Übung, 1 mit Video · Foto',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY)
katalog += zeile('Brustpresse',
                 '<span style="color: #5c636e;">Ohne Hersteller · noch kein Gerät · keine Übung · kein Foto</span>',
                 '<a href="#" style="%s">Öffnen</a>' % SECONDARY, letzte=True)
katalog += '</section>'
schreibe('Katalog.dc.html', portal('modelle', 900, katalog))


# ---------------------------------------------------------------- Geräte
geraete = titel('Geräte',
                'Zwei Geräte haben keinen aktiven Tag. Ohne Tag findet ein Mitglied sie nicht — '
                'sie existieren für die App nicht.')
geraete += '<section style="%s margin-top: 32px;">' % CARD
geraete += ('<div style="%s"><h2 style="%s">Alle Geräte</h2>'
            '<span style="%s">Ohne Tag zuerst</span></div>' % (HEADROW, SEC_TITLE, NOTE))
geraete += zeile('13',
                 'Latzug · Rückwand mitte · <span style="color: #5c636e;">kein aktiver Tag</span>',
                 '<a href="#" style="%s">Tag anlegen</a>' % PRIMARY)
geraete += zeile('4',
                 'Brustpresse · Freifläche · <span style="color: #5c636e;">kein aktiver Tag</span>',
                 '<a href="#" style="%s">Tag anlegen</a>' % PRIMARY)
geraete += zeile('7', 'Beinpresse · Beinbereich · erreichbar',
                 '<a href="#" style="%s">Tag ersetzen</a><a href="#" style="%s">Stilllegen</a>'
                 % (SECONDARY, DESTRUCTIVE))
geraete += zeile('12', 'Latzug · Rückwand links · erreichbar',
                 '<a href="#" style="%s">Tag ersetzen</a><a href="#" style="%s">Stilllegen</a>'
                 % (SECONDARY, DESTRUCTIVE))
geraete += zeile('8 <span style="%s margin-left: 8px;">stillgelegt</span>' % BADGE,
                 '<span style="color: #5c636e;">Beinpresse · Beinbereich</span>',
                 '<a href="#" style="%s">Wieder in Betrieb</a>' % SECONDARY,
                 letzte=True, meta_faint=True)
geraete += '</section>'
schreibe('Geraete.dc.html', portal('geraete', 820, geraete))


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
