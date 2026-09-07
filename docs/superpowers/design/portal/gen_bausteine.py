# -*- coding: utf-8 -*-
"""Ein Blatt statt drei Konventionen.

portal.module.css, einstieg.module.css und halle.module.css zeichnen
Textfeld, Auswahl, Knopf und Fehlermeldung heute mit drei verschiedenen
Klassennamen und stellenweise leicht verschiedenen Werten -- derselbe
Fehler wie die Zwillinge in den fruehen Befunden (.sectionNote,
.abschnittNotiz, .hint), nur ueber drei Dateien statt zwei Klassen verteilt.
Dieses Blatt zeichnet nicht neu, was die Artboards schon zeigen: es zieht
die eine Fassung heraus, an der sich die Konsolidierung misst.

Die Schrittleiste steht zweimal, mit verschiedener Schrittzahl, um zu
zeigen, dass sie ein Baustein ist und keine Konstante -- SCHRITTE = 6 in
Schrittleiste.tsx ist heute fest im Code."""
from build import (LABEL, CARD, HEADROW, SEC_TITLE, PRIMARY, SECONDARY,
                    DESTRUCTIVE, FIELD, BADGE, NOTE, portal, schreibe, svg)

TEXTAREA = FIELD.replace('min-height: 44px;', 'min-height: 88px; align-items: flex-start;')
ERROR = ('border: 1px solid #ff5a4e; background: #14161a; color: #f2f4f7; '
         'border-radius: 10px; padding: 12px 16px;')


def karte(titel, inhalt, rechts=''):
    kopf = '<div style="%s"><h2 style="%s">%s</h2>%s</div>' % (HEADROW, SEC_TITLE, titel, rechts)
    return '<section style="%s margin-top: 24px;">%s<div style="padding: 20px; display: flex; flex-direction: column; gap: 16px;">%s</div></section>' % (CARD, kopf, inhalt)


def feld(label, wert, hinweis=None, fehler=None, art='input'):
    stil = {'input': FIELD, 'select': FIELD, 'textarea': TEXTAREA}[art]
    rechts = svg('chevron-down', 18, '#5c636e') if art == 'select' else ''
    unten = ''
    if fehler:
        unten = '<span style="font-size: 12px; color: #ff5a4e;">%s</span>' % fehler
    elif hinweis:
        unten = '<span style="font-size: 12px; color: #9ba3af;">%s</span>' % hinweis
    rand = 'border-color: #ff5a4e;' if fehler else ''
    return ('<div style="display: flex; flex-direction: column; gap: 8px; max-width: 360px;">'
            '<span style="%s color: #9ba3af;">%s</span>'
            '<div style="%s %s justify-content: space-between; color: #f2f4f7;">%s%s</div>%s</div>'
            % (LABEL, label, stil, rand, wert, rechts, unten))


def schrittleiste_muster(n, von, titel):
    segmente = ''.join(
        '<div style="flex: 1; height: 3px; border-radius: 999px; background: %s;"></div>'
        % ('#f2f4f7' if i < n else '#2a2e36') for i in range(von))
    return ('<div style="display: flex; flex-direction: column; gap: 8px; max-width: 420px;">'
            '<div style="display: flex; gap: 4px;">%s</div>'
            '<span style="%s color: #9ba3af;">Schritt %d von %d &middot; %s</span></div>'
            % (segmente, LABEL, n, von, titel))


inhalt = (
    '<h1 style="font-size: 26px; font-weight: 800; letter-spacing: -0.025em; text-transform: '
    'uppercase; margin: 0;">Bausteine</h1>'
    '<p style="color: #9ba3af; margin: 8px 0 0; max-width: 62ch;">Eine Fassung statt drei. '
    'portal.module.css, einstieg.module.css und halle.module.css zeichnen dasselbe heute mit '
    'verschiedenen Klassennamen -- dieses Blatt ist die Vorlage, auf die sie zusammenlaufen.</p>'

    + karte('Textfeld', (
        '<div style="display: flex; gap: 32px; flex-wrap: wrap;">'
        + feld('Name', 'Latzug')
        + feld('E-Mail', 'tim@kraftwerk-nord.de', hinweis='Nur für die Anmeldung, nicht sichtbar für Mitglieder.')
        + feld('Neues Passwort', '••••••••••', fehler='Mindestens zehn Zeichen.')
        + '</div>'))

    + karte('Auswahl &amp; Mehrzeiliges Feld', (
        '<div style="display: flex; gap: 32px; flex-wrap: wrap;">'
        + feld('Rolle', 'Trainer', art='select')
        + feld('Raum', 'Kursraum 2', art='select')
        + feld('Beschreibung', 'Kraftzirkel für Fortgeschrittene, 60 Minuten.', art='textarea')
        + '</div>'))

    + karte('Rückmeldung', (
        '<div style="%s">Der Studio-Code ist ungültig oder abgelaufen. Prüf ihn in den '
        'Studio-Einstellungen.</div>' % ERROR))

    + karte('Knöpfe', (
        '<div style="display: flex; gap: 12px; align-items: center; flex-wrap: wrap;">'
        '<a href="#" style="%s">Speichern</a>'
        '<a href="#" style="background: #1d2026; color: #5c636e; border: none; border-radius: 10px; '
        'padding: 0 20px; height: 44px; display: inline-flex; align-items: center; '
        'justify-content: center; font-weight: 700;">Speichern</a>'
        '<a href="#" style="%s">Abbrechen</a>'
        '<a href="#" style="%s">Entfernen</a>'
        '<span style="%s">Aktiv</span>'
        '<span style="%s color: #ff5a4e; border-color: #ff5a4e;">Gesperrt</span>'
        '</div>'
        '<p style="%s margin: 0;">Erster Knopf aktiv, zweiter dieselbe Fläche deaktiviert -- das '
        'Muster aus .primary:disabled. Genau eine Akzentfläche je Bildschirm bleibt Regel: diese '
        'Reihe ist ein Muster, kein Bildschirm.</p>'
        % (PRIMARY, SECONDARY, DESTRUCTIVE, BADGE.replace('color: #9ba3af;', 'color: #f2f4f7; border-color: #5c636e;'), BADGE, NOTE)))

    + karte('Schrittleiste', (
        '<p style="%s margin: 0 0 4px;">Derselbe Baustein, zwei Schrittzahlen -- Schrittleiste.tsx '
        'kennt heute nur sechs (SCHRITTE = 6, fest im Code). Als Baustein in bausteine/ wandert die '
        'Zahl in eine Prop.</p>'
        % NOTE
        + schrittleiste_muster(2, 6, 'Einstellungen') + schrittleiste_muster(1, 3, 'Details'))))

schreibe('Formulare.dc.html', portal(None, 1500, inhalt))
