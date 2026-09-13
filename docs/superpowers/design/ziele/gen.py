# -*- coding: utf-8 -*-
"""Erzeugt die Artboards fuer Ziele & Fortschritt (Spec
2026-09-13-ziele-und-fortschritt-design.md) aus einem Baukasten.

Masse und Farben sind die der Member-App (member/build.py, home-serie):
393 x 852, Archivo, 28 pt Seitenrand auf Einstiegsscreens, 20 pt im
Content, genau eine Akzentflaeche je Screen, keine gemalte Statusleiste,
Rastrad wie am Geraet (GeraetWertRad). Artboards teilen zur Laufzeit
nichts, deshalb steht der ganze Stil in jeder Datei.

    python3 gen.py   -- schreibt *.dc.html und canvas.json ins Verzeichnis
"""
import io
import json
import os

HIER = os.path.dirname(os.path.abspath(__file__))

HEAD = u"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700;800;900&display=swap">
  <style>
    * { box-sizing: border-box; }
    body { margin: 0; background: #0A0B0D; color: #F2F4F7; font-family: Archivo, -apple-system, "Segoe UI", system-ui, sans-serif; -webkit-font-smoothing: antialiased; font-variant-numeric: tabular-nums; }
    a { color: #D4FF3F; text-decoration: none; } a:hover { color: #E8FF8A; }
    .ph { width: 393px; height: 852px; background: #0A0B0D; color: #F2F4F7; display: flex; flex-direction: column; overflow: hidden; position: relative; }
    .eyebrow { font-size: 11px; font-weight: 800; letter-spacing: .14em; text-transform: uppercase; color: #9BA3AF; }
    .num { font-variant-numeric: tabular-nums; font-weight: 900; letter-spacing: -.03em; }
    .card { background: #14161A; border: 1px solid #2A2E36; border-radius: 14px; overflow: hidden; }
    .row { padding: 13px 16px; display: flex; align-items: center; gap: 12px; }
    .sep { height: 1px; background: #2A2E36; }
    .tabs { flex: none; height: 78px; border-top: 1px solid #2A2E36; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); padding-top: 11px; }
    .tab { display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 10px; font-weight: 700; color: #5C636E; }
    .tab.on { color: #D4FF3F; }
    /* Chip: 44 pt, Pille. Gewaehlt = Akzentstrich, keine Flaeche (Designsystem SS2). */
    .chip { height: 44px; border-radius: 22px; border: 1px solid #2A2E36; color: #9BA3AF; font-size: 15px; font-weight: 700; display: flex; align-items: center; justify-content: center; }
    .chip.on { border: 1.5px solid #D4FF3F; background: #14161A; color: #F2F4F7; }
    /* Zielkachel: Karte mit Symbol, Titel, Zeile. Gewaehlt wie der Chip. */
    .kachel { min-height: 132px; padding: 16px; border-radius: 14px; background: #14161A; border: 1px solid #2A2E36; display: flex; flex-direction: column; gap: 10px; }
    .kachel.on { border: 1.5px solid #D4FF3F; }
    .kachel-titel { font-size: 16px; font-weight: 800; line-height: 1.15; }
    .kachel-zeile { font-size: 12px; line-height: 1.4; color: #5C636E; }
    /* Stepper44 als Zeile: Minus, Wert, Plus. */
    .stepper { display: flex; align-items: stretch; gap: 8px; height: 58px; }
    .stepper-knopf { flex: none; width: 58px; border-radius: 14px; border: 1px solid #2A2E36; display: flex; align-items: center; justify-content: center; }
    .stepper-wert { flex-grow: 1; border-radius: 14px; background: #14161A; border: 1px solid #2A2E36; display: flex; align-items: baseline; justify-content: center; gap: 5px; }
    /* Rastrad ohne Rahmen -- GeraetWertRad.dc.html, eine Spalte. */
    .rad { position: relative; height: 244px; overflow: hidden; }
    .far { height: 34px; display: flex; align-items: center; justify-content: center; }
    .near { height: 38px; display: flex; align-items: center; justify-content: center; }
    .fT { position: absolute; left: 0; right: 0; top: 0; height: 66px; background: linear-gradient(180deg, #0A0B0D 12%, rgba(10,11,13,0) 100%); pointer-events: none; }
    .fB { position: absolute; left: 0; right: 0; bottom: 0; height: 66px; background: linear-gradient(0deg, #0A0B0D 12%, rgba(10,11,13,0) 100%); pointer-events: none; }
    .rad.im-sheet .fT { background: linear-gradient(180deg, #14161A 12%, rgba(20,22,26,0) 100%); }
    .rad.im-sheet .fB { background: linear-gradient(0deg, #14161A 12%, rgba(20,22,26,0) 100%); }
    /* Serie: Flamme links, Wochenstreifen rechts (home-serie/Main). */
    .serie { display: flex; align-items: center; gap: 12px; }
    .flamme { flex: none; width: 56px; display: flex; flex-direction: column; align-items: center; gap: 3px; }
    .flamme-reihe { display: flex; align-items: center; gap: 4px; }
    .flamme-zahl { font-size: 27px; line-height: 1; font-weight: 900; font-variant-numeric: tabular-nums; letter-spacing: -.04em; color: #D4FF3F; }
    .flamme-label { font-size: 10px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; color: #D4FF3F; }
    .woche { flex-grow: 1; display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 4px; }
    .tagbox { height: 44px; border-radius: 12px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px; }
    .kuerzel { font-size: 10px; font-weight: 800; letter-spacing: .08em; color: #5C636E; }
    .tagnr { font-size: 16px; font-weight: 900; font-variant-numeric: tabular-nums; letter-spacing: -.03em; color: #5C636E; }
    .tagbox.trainiert { background: #1D2026; }
    .tagbox.trainiert .kuerzel { color: #9BA3AF; }
    .tagbox.heute { box-shadow: inset 0 0 0 1.5px #2A2E36; }
    .tagbox.heute .kuerzel, .tagbox.heute .tagnr { color: #9BA3AF; }
    .serie-fuss { font-size: 12px; font-weight: 600; color: #5C636E; font-variant-numeric: tabular-nums; }
    /* Wochenziel: drei Striche je Zieltag, gefuellt = trainiert. */
    .zielstriche { display: flex; gap: 4px; }
    .strich { width: 18px; height: 4px; border-radius: 2px; background: #2A2E36; }
    .strich.voll { background: #F2F4F7; }
    /* Sheet ueber einem abgedunkelten Screen. */
    .scrim { position: absolute; inset: 0; background: rgba(10,11,13,.72); }
    .sheet { position: absolute; left: 0; right: 0; bottom: 0; background: #14161A; border-radius: 24px 24px 0 0; padding: 10px 20px 20px; display: flex; flex-direction: column; }
    .griff { width: 36px; height: 5px; border-radius: 3px; background: #2A2E36; align-self: center; }
    .note { font-size: 13px; line-height: 1.5; color: #9BA3AF; }
    .note-faint { font-size: 12px; line-height: 1.5; color: #5C636E; }
  </style>
</helmet>
"""

FOOT = u"""</x-dc>
</body>
</html>
"""

PRIMARY = (u'height: 64px; border-radius: 16px; background: #D4FF3F; color: #0A0B0D; '
           u'font-size: 19px; font-weight: 800; display: flex; align-items: center; justify-content: center; gap: 9px;')
NEBEN = (u'height: 52px; border-radius: 14px; border: 1px solid #2A2E36; color: #F2F4F7; '
         u'font-size: 16px; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 8px;')
ROT = (u'height: 52px; border-radius: 14px; border: 1px solid rgba(255,90,78,.45); color: #FF5A4E; '
       u'font-size: 16px; font-weight: 700; display: flex; align-items: center; justify-content: center;')

CHEVRON_R = (u'<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="#5C636E" stroke-width="2.2" '
             u'stroke-linecap="round" stroke-linejoin="round" style="flex: none"><path d="m9.5 5 7 7-7 7"/></svg>')
CHEVRON_L = (u'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#F2F4F7" stroke-width="2" '
             u'stroke-linecap="round" stroke-linejoin="round"><path d="m14.5 5-7 7 7 7"/></svg>')
HANTEL = (u'<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="#F2F4F7" stroke-width="2" '
          u'stroke-linecap="round"><path d="M4 9v6M7.5 6.5v11M16.5 6.5v11M20 9v6M7.5 12h9"/></svg>')
FLAMME = (u'<svg width="21" height="25" viewBox="0 0 21 25" fill="#D4FF3F" style="flex: none"><path d="M11.2.4c.9 4-.7 6.1-2.9 8.3C5.6 11.2 3.4 13.8 3.4 17.3a7.6 7.6 0 0 0 15.2.2c0-2.9-1.1-5.1-2.7-6.9-.3 1.8-1.3 2.9-2.5 3.2 1.2-4.3-.1-9.1-2.2-13.4Z"/></svg>')
PLUS = (u'<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="#F2F4F7" stroke-width="2.2" '
        u'stroke-linecap="round" style="flex: none"><path d="M12 5v14M5 12h14"/></svg>')
HAKEN = (u'<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="#D4FF3F" stroke-width="2.4" '
         u'stroke-linecap="round" stroke-linejoin="round" style="flex: none"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>')
INFO = (u'<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="#9BA3AF" stroke-width="1.9" '
        u'stroke-linecap="round" style="flex: none; margin-top: 2px"><circle cx="12" cy="12" r="9"/><path d="M12 11v5.5"/><path d="M12 7.6h.01"/></svg>')


def stepper_icon(minus, farbe=u'#F2F4F7'):
    pfad = u'M6 12h12' if minus else u'M12 6v12M6 12h12'
    return (u'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="2.4" '
            u'stroke-linecap="round"><path d="%s"/></svg>' % (farbe, pfad))


# Ziel-Symbole, 24er Raster, Strich 2 -- eine Familie.
ICON_AB = u'<path d="M4 7l6 6 4-4 6 6"/><path d="M14 15h6V9"/>'
ICON_MUSKEL = u'<path d="M4 9v6M7.5 6.5v11M16.5 6.5v11M20 9v6M7.5 12h9"/>'
ICON_FIT = u'<path d="M3 12h4l2.5-6 4 12 2.5-6h5"/>'
ICON_STARK = u'<path d="M4 17l6-6 4 4 6-6"/><path d="M14 9h6v6"/>'


def icon(pfad, farbe=u'#9BA3AF', groesse=24):
    return (u'<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="2" '
            u'stroke-linecap="round" stroke-linejoin="round" style="flex: none">%s</svg>' % (groesse, groesse, farbe, pfad))


_TAB_ICONS = {
    u'Home': u'<path d="M3 10.5 12 3l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/>',
    u'Training': u'<path d="M4 9v6M7.5 6.5v11M16.5 6.5v11M20 9v6M7.5 12h9"/>',
    u'Kurse': u'<rect x="3.5" y="5.2" width="17" height="15.3" rx="2.6"/><path d="M8 3v4M16 3v4M3.5 10.2h17"/>',
    u'Profil': u'<circle cx="12" cy="8" r="3.4"/><path d="M4.8 20c0-3.5 3.3-5.8 7.2-5.8s7.2 2.3 7.2 5.8"/>',
}


def tabs(aktiv):
    zellen = []
    for name in [u'Home', u'Training', u'Kurse', u'Profil']:
        an = name == aktiv
        zellen.append(u'<div class="%s"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" '
                      u'stroke="currentColor" stroke-width="%s" stroke-linecap="round" '
                      u'stroke-linejoin="round">%s</svg>%s</div>'
                      % (u'tab on' if an else u'tab', u'2' if an else u'1.8', _TAB_ICONS[name], name))
    return u'<div class="tabs">%s</div>' % u''.join(zellen)


def spacer_top():
    return u'<div style="height: 54px; flex: none;"></div>'


def fuellen():
    return u'<div style="flex-grow: 1;"></div>'


def schreibe(name, inhalt):
    io.open(os.path.join(HIER, name), 'w', encoding='utf-8').write(HEAD + inhalt + FOOT)
    print(u'geschrieben: %s' % name)


# ---------------------------------------------------------------- Onboarding

def onboarding(schritt, titel, lead, inhalt, primary=u'Weiter', fuss=None, kommentar=u''):
    """Ein Onboarding-Screen: Schrittzeile mit 'Spaeter', Titel, Inhalt,
    Hauptaktion. Seitenrand 28 wie auf den Login-Screens -- es ist die
    Einstiegs-Kette, noch ohne Tab-Leiste."""
    segmente = u''.join(
        u'<div style="flex-grow: 1; height: 4px; border-radius: 2px; background: %s"></div>'
        % (u'#F2F4F7' if i < schritt else u'#2A2E36') for i in range(5))
    out = [u'<div class="ph">', kommentar, spacer_top()]
    out.append(u'<div style="flex: none; height: 44px; padding: 0 28px; display: flex; align-items: center; justify-content: space-between;">'
               u'<span class="eyebrow">Schritt %d von 5</span>'
               u'<span style="font-size: 14px; font-weight: 700; color: #9BA3AF;">Später</span></div>' % schritt)
    out.append(u'<div style="flex: none; padding: 0 28px; display: flex; gap: 4px;">%s</div>' % segmente)
    out.append(u'<div style="flex: none; padding: 28px 28px 0; display: flex; flex-direction: column; gap: 10px;">'
               u'<div style="font-size: 32px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1.02;">%s</div>'
               u'<div class="note">%s</div></div>' % (titel, lead))
    out.append(inhalt)
    out.append(fuellen())
    out.append(u'<div style="flex: none; padding: 0 28px 20px; display: flex; flex-direction: column; gap: 12px;">'
               u'<div style="%s">%s</div>' % (PRIMARY, primary))
    if fuss:
        out.append(u'<div class="note-faint" style="text-align: center;">%s</div>' % fuss)
    out.append(u'</div></div>')
    return u''.join(out)


def chips(namen, gewaehlt, spalten):
    zellen = u''.join(u'<div class="chip%s">%s</div>' % (u' on' if n == gewaehlt else u'', n) for n in namen)
    return (u'<div style="display: grid; grid-template-columns: repeat(%d, minmax(0, 1fr)); gap: 8px;">%s</div>'
            % (spalten, zellen))


def abschnitt(label, innen, top=24, seite=28, hinweis=None):
    out = (u'<div style="flex: none; padding: %dpx %dpx 0; display: flex; flex-direction: column; gap: 10px;">'
           u'<span class="eyebrow">%s</span>%s' % (top, seite, label, innen))
    if hinweis:
        out += u'<div class="note-faint">%s</div>' % hinweis
    return out + u'</div>'


def rad(werte, einheit, sheet=False):
    """Fuenf Zeilen, die mittlere ist der Wert -- wie am Geraet, eine Spalte."""
    fern, nah, mitte, nah2, fern2 = werte
    return (u'<div class="rad%s" style="flex: none;"><div style="display: flex; flex-direction: column;">'
            u'<div class="far"><span class="num" style="font-size: 26px; color: #2A2E36">%s</span></div>'
            u'<div class="near"><span class="num" style="font-size: 30px; color: #5C636E">%s</span></div>'
            u'<div style="height: 100px; display: flex; flex-direction: column; justify-content: center; align-items: center; gap: 7px;">'
            u'<div style="display: flex; align-items: baseline; gap: 7px;">'
            u'<span class="num" style="font-size: 64px; line-height: 1">%s</span>'
            u'<span style="font-size: 19px; font-weight: 700; color: #9BA3AF">%s</span></div>'
            u'<div style="height: 4px; width: 180px; background: #D4FF3F; border-radius: 2px"></div></div>'
            u'<div class="near"><span class="num" style="font-size: 30px; color: #5C636E">%s</span></div>'
            u'<div class="far"><span class="num" style="font-size: 26px; color: #2A2E36">%s</span></div>'
            u'</div><div class="fT"></div><div class="fB"></div></div>'
            % (u' im-sheet' if sheet else u'', fern, nah, mitte, einheit, nah2, fern2))


def rad_kontext(text):
    return (u'<div class="num" style="flex: none; padding: 6px 28px 0; text-align: center; font-size: 11px; font-weight: 800; '
            u'letter-spacing: .06em; text-transform: uppercase; color: #5C636E;">%s</div>' % text)


def stepper(wert, einheit):
    return (u'<div class="stepper">'
            u'<div class="stepper-knopf">%s</div>'
            u'<div class="stepper-wert"><span class="num" style="font-size: 22px;">%s</span>'
            u'<span style="font-size: 13px; font-weight: 700; color: #9BA3AF;">%s</span></div>'
            u'<div class="stepper-knopf">%s</div></div>'
            % (stepper_icon(True), wert, einheit, stepper_icon(False)))


def kachel(pfad, titel, zeile, an=False):
    return (u'<div class="kachel%s">%s<div style="display: flex; flex-direction: column; gap: 4px;">'
            u'<div class="kachel-titel">%s</div><div class="kachel-zeile">%s</div></div></div>'
            % (u' on' if an else u'', icon(pfad, u'#F2F4F7' if an else u'#9BA3AF'), titel, zeile))


ALTER = [u'bis 17', u'18–24', u'25–34', u'35–44', u'45–54', u'55–64', u'65+']

schreibe(u'Onboarding1.dc.html', onboarding(
    1, u'Über dich',
    u'Beides freiwillig. Nur du siehst es — dein Studio nicht.',
    abschnitt(u'Geschlecht', chips([u'Weiblich', u'Männlich', u'Divers'], u'Weiblich', 3), top=28)
    + abschnitt(u'Alter', chips(ALTER, u'25–34', 4), top=22,
                hinweis=u'Als Spanne, damit die App nichts rechnen muss, was sie nicht wissen soll.')
    + u'<div style="flex: none; padding: 22px 28px 0;"><div class="note-faint">Wofür: später als Grundlage für Startgewichte am Gerät und für Trainingspläne. Heute noch für nichts.</div></div>',
    fuss=u'Nichts gewählt heißt: keine Angabe.',
    kommentar=u'<!-- Schritt 1: Geschlecht und Altersspanne. Keine Vorauswahl; "Spaeter" oben rechts ueberspringt alles. -->'))

schreibe(u'Onboarding2.dc.html', onboarding(
    2, u'Dein Körper',
    u'Das Gewicht wird der erste Punkt deines Verlaufs.',
    abschnitt(u'Größe', stepper(u'168', u'cm'), top=28)
    + abschnitt(u'Gewicht heute', u'', top=22)
    + rad([u'81,5', u'82,0', u'82,5', u'83,0', u'83,5'], u'kg')
    + rad_kontext(u'Schritt 0,5 kg · scrollen'),
    fuss=u'Beides freiwillig. Änderbar und löschbar im Profil.',
    kommentar=u'<!-- Schritt 2: Stepper44 fuer die Groesse, das Rastrad vom Geraet fuer das Gewicht (Schritt 0,5). -->'))

schreibe(u'Onboarding3.dc.html', onboarding(
    3, u'Dein Ziel',
    u'Eine Richtung. gymodo gibt keine Empfehlung dazu — das Ziel ist deins.',
    u'<div style="flex: none; padding: 28px 28px 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px;">'
    + kachel(ICON_AB, u'Abnehmen', u'Gewicht runter, Kraft halten', an=True)
    + kachel(ICON_MUSKEL, u'Muskeln aufbauen', u'Mehr Gewicht je Übung')
    + kachel(ICON_FIT, u'Fit bleiben', u'Dranbleiben, regelmäßig')
    + kachel(ICON_STARK, u'Stärker werden', u'Schwerere Sätze')
    + u'</div>',
    kommentar=u'<!-- Schritt 3: vier Kacheln, eine gewaehlt. Der Akzent markiert als Strich, die Flaeche bleibt dem Knopf. -->'))

schreibe(u'Onboarding4.dc.html', onboarding(
    4, u'Wie oft?',
    u'Trainingstage pro Woche. Die Serie auf Home zählt gegen dieses Ziel.',
    u'<div style="flex: none; padding: 36px 28px 0; display: flex; flex-direction: column; align-items: center; gap: 6px;">'
    u'<span class="num" style="font-size: 96px; line-height: 1;">3</span>'
    u'<span class="eyebrow">Tage pro Woche</span></div>'
    u'<div style="flex: none; padding: 28px 28px 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">'
    u'<div class="stepper-knopf" style="width: auto; height: 58px;">%s</div>'
    u'<div class="stepper-knopf" style="width: auto; height: 58px;">%s</div></div>'
    u'<div style="flex: none; padding: 22px 28px 0;"><div class="note-faint">Zwei Einheiten an einem Tag sind ein Tag. Erreichbar ist besser als ehrgeizig — du kannst es jederzeit im Profil verschieben.</div></div>'
    % (stepper_icon(True), stepper_icon(False)),
    kommentar=u'<!-- Schritt 4: Vorgabe 3, Bereich 1 bis 7. Zwei grosse Knoepfe statt eines Rads -- sieben Werte brauchen kein Rad. -->'))

schreibe(u'Onboarding5.dc.html', onboarding(
    5, u'Zielgewicht',
    u'Heute 82,5 kg. Wohin soll es gehen?',
    u'<div style="flex: none; height: 22px;"></div>'
    + rad([u'77,0', u'77,5', u'78,0', u'78,5', u'79,0'], u'kg')
    + rad_kontext(u'noch 4,5 kg · Schritt 0,5 kg')
    + u'<div style="flex: none; padding: 26px 28px 0;"><div class="note-faint">Erreicht ist es, sobald ein Eintrag die Marke erreicht. Kein Datum, kein Tempo — gymodo rechnet keinen Weg dorthin.</div></div>',
    primary=u'Los geht’s',
    fuss=u'Braucht Verbindung. „Später“ beendet ohne Zielgewicht.',
    kommentar=u'<!-- Schritt 5: nur wenn Schritt 2 ein Gewicht hat. Das Rad startet beim heutigen Wert. Danach: Home. -->'))


# ---------------------------------------------------------------------- Home

def kopf_home(vorname=u'Lena', studio=u'Kraftwerk Nord'):
    return (u'<div style="flex: none; padding: 14px 20px 0; display: flex; align-items: baseline; justify-content: space-between">'
            u'<div style="font-size: 32px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1">Hallo %s</div>'
            u'<div class="eyebrow">%s</div></div>' % (vorname, studio))


def streifen(trainiert, heute=u'MI'):
    tage = [(u'MO', 8), (u'DI', 9), (u'MI', 10), (u'DO', 11), (u'FR', 12), (u'SA', 13), (u'SO', 14)]
    boxen = []
    for kuerzel, nr in tage:
        if kuerzel in trainiert:
            boxen.append(u'<div class="tagbox trainiert"><span class="kuerzel">%s</span>%s</div>' % (kuerzel, HANTEL))
        elif kuerzel == heute:
            boxen.append(u'<div class="tagbox heute"><span class="kuerzel">%s</span><span class="tagnr">%d</span></div>' % (kuerzel, nr))
        else:
            boxen.append(u'<div class="tagbox"><span class="kuerzel">%s</span><span class="tagnr">%d</span></div>' % (kuerzel, nr))
    return u'<div class="woche">%s</div>' % u''.join(boxen)


def zielstriche(voll, gesamt):
    return u'<div class="zielstriche">%s</div>' % u''.join(
        u'<div class="strich%s"></div>' % (u' voll' if i < voll else u'') for i in range(gesamt))


def serie_block(ziel=None, wochen=6, trainiert=(u'MO', u'DI'), fuss=u'34 Einheiten gesamt · zuletzt gestern'):
    """Der Serien-Abschnitt aus home-serie/Main -- mit Wochenziel, wenn eins steht."""
    kopf = u'<span class="eyebrow">Deine Serie</span>'
    if ziel:
        kopf = (u'<div style="display: flex; align-items: baseline; justify-content: space-between;">%s'
                u'<span class="eyebrow" style="color: #5C636E;">Ziel %d Tage</span></div>' % (kopf, ziel))
    out = [u'<div style="flex: none; padding: 24px 20px 0; display: flex; flex-direction: column; gap: 12px">', kopf,
           u'<div class="serie"><div class="flamme"><div class="flamme-reihe">%s<span class="flamme-zahl">%d</span></div>'
           u'<span class="flamme-label">%s</span></div>%s</div>'
           % (FLAMME, wochen, u'Wochen', streifen(trainiert))]
    if ziel:
        out.append(u'<div style="display: flex; align-items: center; justify-content: space-between;">'
                   u'<span class="serie-fuss" style="color: #9BA3AF;">%d von %d Tagen diese Woche</span>%s</div>'
                   % (len(trainiert), ziel, zielstriche(len(trainiert), ziel)))
    out.append(u'<div class="serie-fuss">%s</div></div>' % fuss)
    return u''.join(out)


def sparkline(ziel_y=None):
    """Zwoelf Punkte, fallend, 120 x 44. Zielgewicht als gestrichelte Linie."""
    ys = [6, 8, 8, 12, 12, 16, 16, 20, 20, 24, 24, 28]
    xs = [4 + i * 10.2 for i in range(12)]
    pfad = u' '.join(u'%s%.1f %d' % (u'M' if i == 0 else u'L', xs[i], ys[i]) for i in range(12))
    ziel = (u'<line x1="0" y1="%d" x2="120" y2="%d" stroke="#5C636E" stroke-width="1" stroke-dasharray="3 3"/>' % (ziel_y, ziel_y)) if ziel_y else u''
    return (u'<svg width="120" height="44" viewBox="0 0 120 44" fill="none" style="flex: none">%s'
            u'<path d="%s" stroke="#D4FF3F" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
            u'<circle cx="%.1f" cy="%d" r="4" fill="#D4FF3F" stroke="#14161A" stroke-width="2"/></svg>'
            % (ziel, pfad, xs[-1], ys[-1]))


def gewichtskarte(wert=u'82,5', datum=u'gestern', seit=u'−2,0', seit_wann=u'seit 1. Aug', bis=u'noch 4,5 kg', bis_ziel=u'bis 78,0', erreicht=False):
    if erreicht:
        mitte = (u'<div class="row" style="padding: 12px 16px;">%s<div style="flex-grow: 1; font-size: 14px; font-weight: 700;">Zielgewicht erreicht'
                 u'<span style="color: #5C636E; font-weight: 600;"> · 78,0 kg am 3. November</span></div></div>' % HAKEN)
        aktion = (u'<div class="row" style="padding: 12px 16px;"><span style="flex-grow: 1; font-size: 15px; font-weight: 700;">Neues Ziel setzen</span>%s</div>'
                  u'<div class="sep"></div>'
                  u'<div class="row" style="padding: 12px 16px;">%s<span style="flex-grow: 1; font-size: 15px; font-weight: 700;">Eintragen</span></div>'
                  % (CHEVRON_R, PLUS))
        spark = sparkline(ziel_y=28)
    else:
        mitte = (u'<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr));">'
                 u'<div style="padding: 12px 16px; display: flex; flex-direction: column; gap: 2px;">'
                 u'<span class="num" style="font-size: 17px;">%s <span style="font-size: 11px; font-weight: 700; color: #9BA3AF;">kg</span></span>'
                 u'<span class="note-faint">%s</span></div>'
                 u'<div style="padding: 12px 16px; display: flex; flex-direction: column; gap: 2px; border-left: 1px solid #2A2E36;">'
                 u'<span class="num" style="font-size: 17px;">%s</span>'
                 u'<span class="note-faint">%s</span></div></div>' % (seit, seit_wann, bis, bis_ziel))
        aktion = u'<div class="row" style="padding: 12px 16px;">%s<span style="flex-grow: 1; font-size: 15px; font-weight: 700;">Eintragen</span></div>' % PLUS
        spark = sparkline(ziel_y=38)
    return (u'<div class="card">'
            u'<div class="row" style="padding: 14px 16px 12px;">'
            u'<div style="flex-grow: 1; display: flex; flex-direction: column; gap: 3px;">'
            u'<span class="eyebrow" style="font-size: 10px; color: #5C636E;">Gewicht · Abnehmen</span>'
            u'<div style="display: flex; align-items: baseline; gap: 5px;">'
            u'<span class="num" style="font-size: 26px; line-height: 1;">%s</span>'
            u'<span style="font-size: 13px; font-weight: 700; color: #9BA3AF;">kg</span>'
            u'<span class="note-faint" style="margin-left: 4px;">%s</span></div></div>%s%s</div>'
            u'<div class="sep"></div>%s<div class="sep"></div>%s</div>'
            % (wert, datum, spark, CHEVRON_R, mitte, aktion))


def nachholkarte():
    return (u'<div class="card"><div style="padding: 16px; display: flex; flex-direction: column; gap: 12px;">'
            u'<div style="display: flex; flex-direction: column; gap: 4px;">'
            u'<div style="font-size: 15px; font-weight: 700;">Ziele festlegen</div>'
            u'<div class="note">Wochenziel, Gewicht, Richtung — dauert eine Minute. Nur du siehst das.</div></div>'
            u'<div style="%s">Loslegen</div></div></div>' % NEBEN)


def letzte_trainings(anzahl=2):
    zeilen = [(u'Dienstag, 9. September', u'47 min · 3 Geräte · 8 Sätze'),
              (u'Montag, 8. September', u'52 min · 4 Geräte · 11 Sätze')][:anzahl]
    innen = u'<div class="sep"></div>'.join(
        u'<div class="row"><div style="flex-grow: 1; display: flex; flex-direction: column; gap: 3px">'
        u'<div style="font-size: 15px; font-weight: 700">%s</div>'
        u'<div class="num" style="font-size: 12px; font-weight: 700; color: #5C636E">%s</div></div>%s</div>'
        % (t, z, CHEVRON_R) for t, z in zeilen)
    return (u'<div style="flex: none; padding: 24px 20px 0; display: flex; flex-direction: column; gap: 11px">'
            u'<div class="eyebrow">Letzte Trainings</div><div class="card">%s</div></div>' % innen)


def home(ziele_block, serie, kommentar=u''):
    return (u'<div class="ph">' + kommentar + spacer_top() + kopf_home() + serie
            + u'<div style="flex: none; padding: 24px 20px 0; display: flex; flex-direction: column; gap: 11px">'
            + u'<div class="eyebrow">Deine Ziele</div>' + ziele_block + u'</div>'
            + letzte_trainings() + fuellen() + tabs(u'Home') + u'</div>')


schreibe(u'Main.dc.html', home(
    gewichtskarte(),
    serie_block(ziel=3),
    kommentar=u'<!-- Home mit Zielen: die Flamme zaehlt unveraendert Wochen mit mindestens einer Einheit; die Zeile unter dem Streifen zeigt den Stand gegen das Wochenziel. -->'))

schreibe(u'HomeNachholen.dc.html', home(
    nachholkarte(),
    serie_block(),
    kommentar=u'<!-- Home nach "Spaeter": Serie wie bisher, darunter die eine Karte, die das Onboarding als Sheet oeffnet. -->'))

schreibe(u'HomeZielErreicht.dc.html', home(
    gewichtskarte(wert=u'78,0', datum=u'heute', erreicht=True),
    serie_block(ziel=3, wochen=11, trainiert=(u'MO', u'DI', u'MI'), fuss=u'61 Einheiten gesamt · zuletzt heute'),
    kommentar=u'<!-- Ziel erreicht: eine Zeile mit Haken, kein Konfetti. Bleibt, bis ein neues Ziel steht. -->'))


# ------------------------------------------------------------ Gewichtsverlauf

def gewichtsverlauf():
    xs = [40 + i * 42.857 for i in range(8)]
    werte = [84.5, 84.0, 84.0, 83.5, 83.5, 83.0, 83.0, 82.5]
    y = lambda v: 38 + (85 - v) * 16
    linie = u' '.join(u'%s%.1f %.0f' % (u'M' if i == 0 else u'L', xs[i], y(werte[i])) for i in range(8))
    flaeche = linie + u' L%.1f 150 L40 150 Z' % xs[-1]
    punkte = u''.join(u'<circle cx="%.1f" cy="%.0f" r="4" fill="#14161A" stroke="#D4FF3F" stroke-width="2"/>' % (xs[i], y(werte[i])) for i in range(7))
    T = u'font-family="Archivo, system-ui, sans-serif"'
    chart = (u'<svg width="353" height="196" viewBox="0 0 353 196" fill="none" style="display: block">'
             u'<defs><linearGradient id="vg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#D4FF3F" stop-opacity=".18"/><stop offset="1" stop-color="#D4FF3F" stop-opacity="0"/></linearGradient></defs>'
             u'<line x1="34" y1="54" x2="348" y2="54" stroke="#2A2E36" stroke-width="1"/>'
             u'<line x1="34" y1="102" x2="348" y2="102" stroke="#2A2E36" stroke-width="1"/>'
             u'<line x1="34" y1="150" x2="348" y2="150" stroke="#5C636E" stroke-width="1" stroke-dasharray="3 3"/>'
             u'<text x="28" y="58" fill="#5C636E" font-size="11" font-weight="700" text-anchor="end" %s>84</text>'
             u'<text x="28" y="106" fill="#5C636E" font-size="11" font-weight="700" text-anchor="end" %s>81</text>'
             u'<text x="28" y="154" fill="#5C636E" font-size="11" font-weight="700" text-anchor="end" %s>78</text>'
             u'<text x="348" y="145" fill="#5C636E" font-size="10" font-weight="800" text-anchor="end" %s>ZIEL 78,0</text>'
             u'<path d="%s" fill="url(#vg)"/>'
             u'<path d="%s" stroke="#D4FF3F" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>%s'
             u'<line x1="%.1f" y1="%.0f" x2="%.1f" y2="150" stroke="#2A2E36" stroke-width="1" stroke-dasharray="3 3"/>'
             u'<circle cx="%.1f" cy="%.0f" r="6.5" fill="#D4FF3F" stroke="#14161A" stroke-width="2"/>'
             u'<text x="40" y="36" fill="#9BA3AF" font-size="12" font-weight="800" text-anchor="start" %s>84,5</text>'
             u'<text x="%.1f" y="%.0f" fill="#F2F4F7" font-size="13" font-weight="800" text-anchor="end" %s>82,5 kg</text>'
             u'<text x="40" y="176" fill="#5C636E" font-size="11" font-weight="700" text-anchor="start" %s>1. Aug</text>'
             u'<text x="190" y="176" fill="#5C636E" font-size="11" font-weight="700" text-anchor="middle" %s>23. Aug</text>'
             u'<text x="340" y="176" fill="#5C636E" font-size="11" font-weight="700" text-anchor="end" %s>13. Sep</text>'
             u'<text x="34" y="192" fill="#5C636E" font-size="10" font-weight="600" text-anchor="start" %s>Dein Eintrag je Tag · kg · keine Glättung</text>'
             u'</svg>' % (T, T, T, T, flaeche, linie, punkte, xs[-1], y(82.5), xs[-1], xs[-1], y(82.5), T, xs[-1], y(82.5) - 14, T, T, T, T, T))

    def zeile(datum, wert, delta, farbe=u'#9BA3AF'):
        return (u'<div style="padding: 11px 16px; display: flex; align-items: center; gap: 12px">'
                u'<span class="num" style="font-size: 12px; font-weight: 700; color: #5C636E; width: 62px">%s</span>'
                u'<div style="flex-grow: 1; display: flex; align-items: baseline; gap: 4px">'
                u'<span class="num" style="font-size: 16px">%s</span><span style="font-size: 11px; font-weight: 700; color: #9BA3AF">kg</span></div>'
                u'<span class="num" style="font-size: 12px; font-weight: 800; color: %s">%s</span></div>' % (datum, wert, farbe, delta))

    return (u'<div class="ph"><!-- Gewichtsverlauf nach dem Vorbild von Uebungsfortschritt: Achse nicht bei null, Ziel als gestrichelte Linie, Rohwerte darunter. -->'
            + spacer_top()
            + u'<div style="flex: none; height: 44px; padding: 0 16px; display: flex; align-items: center; gap: 12px">%s<span class="eyebrow">Home</span></div>' % CHEVRON_L
            + u'<div style="flex: none; padding: 6px 20px 0; display: flex; flex-direction: column; gap: 3px">'
              u'<div style="font-size: 28px; font-weight: 900; letter-spacing: -.025em; text-transform: uppercase; line-height: 1.05">Gewicht</div>'
              u'<div style="font-size: 16px; font-weight: 600; color: #9BA3AF">Ziel 78,0 kg · noch 4,5</div></div>'
            + u'<div style="flex: none; padding: 20px 20px 0; display: flex; align-items: flex-end; gap: 16px">'
              u'<div style="display: flex; align-items: baseline; gap: 6px"><span class="num" style="font-size: 52px; line-height: 1">82,5</span>'
              u'<span style="font-size: 18px; font-weight: 700; color: #9BA3AF">kg</span></div>'
              u'<div style="display: flex; flex-direction: column; gap: 2px; padding-bottom: 6px">'
              u'<span class="num" style="font-size: 16px; color: #D4FF3F">−2,0 kg</span>'
              u'<span class="eyebrow" style="font-size: 10px">seit 1. August</span></div></div>'
            + u'<div style="flex: none; padding: 18px 20px 0; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px">'
              u'<div class="chip" style="height: 34px; border-radius: 17px; font-size: 13px; background: #D4FF3F; border: none; color: #0A0B0D">3 Monate</div>'
              u'<div class="chip" style="height: 34px; border-radius: 17px; font-size: 13px;">6 Monate</div>'
              u'<div class="chip" style="height: 34px; border-radius: 17px; font-size: 13px;">Alles</div></div>'
            + u'<div style="flex: none; margin: 18px 20px 0; background: #14161A; border: 1px solid #2A2E36; border-radius: 14px; padding: 14px 0 8px">' + chart + u'</div>'
            + u'<div style="flex: none; padding: 16px 20px 0; display: flex; flex-direction: column; gap: 10px">'
              u'<div style="display: flex; align-items: baseline; justify-content: space-between;"><span class="eyebrow">Zuletzt</span>'
              u'<span class="note-faint">Antippen ändert, Wischen löscht</span></div><div class="card">'
            + zeile(u'13. Sep', u'82,5', u'−0,5', u'#D4FF3F') + u'<div class="sep"></div>'
            + zeile(u'10. Sep', u'83,0', u'−0,5', u'#D4FF3F') + u'<div class="sep"></div>'
            + zeile(u'6. Sep', u'83,5', u'±0', u'#5C636E')
            + u'</div></div>' + fuellen() + tabs(u'Home') + u'</div>')


schreibe(u'Gewichtsverlauf.dc.html', gewichtsverlauf())


# --------------------------------------------------------------------- Sheets

def hinter_home():
    """Der abgedunkelte Home-Kopf hinter einem Sheet -- nur so viel, dass man weiss, wo man ist."""
    return spacer_top() + kopf_home() + serie_block(ziel=3)


def sheet(inhalt, hinten, hoehe):
    return (u'<div class="ph">' + hinten + u'<div class="scrim"></div>'
            + u'<div class="sheet" style="height: %dpx;"><div class="griff"></div>%s</div></div>' % (hoehe, inhalt))


schreibe(u'GewichtEintragen.dc.html', sheet(
    u'<!-- Eintrag-Sheet: Datum vorbelegt mit heute, Rastrad vom Geraet, ein Wert je Tag. -->'
    u'<div style="flex: none; padding: 22px 0 0; font-size: 22px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1;">Gewicht eintragen</div>'
    u'<div style="flex: none; margin-top: 16px; height: 52px; border-radius: 14px; border: 1px solid #2A2E36; padding: 0 16px; display: flex; align-items: center; gap: 12px;">'
    u'<span style="flex-grow: 1; font-size: 15px; font-weight: 700;">Heute, 13. September</span>' + CHEVRON_R + u'</div>'
    + rad([u'81,5', u'82,0', u'82,5', u'83,0', u'83,5'], u'kg', sheet=True)
    + u'<div class="num" style="flex: none; text-align: center; font-size: 11px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; color: #5C636E;">Schritt 0,5 kg · zuletzt 83,0 am 10. Sep</div>'
    + u'<div style="flex-grow: 1;"></div>'
    + u'<div style="flex: none; display: flex; flex-direction: column; gap: 12px;">'
      u'<div style="%s">Eintragen</div>'
      u'<div class="note-faint" style="text-align: center;">Ein Wert je Tag. Ein zweiter am selben Tag ersetzt den ersten.</div></div>' % PRIMARY,
    hinter_home(), 560))

schreibe(u'ProfilAlter.dc.html', sheet(
    u'<!-- Picker-Sheet im Profil, stellvertretend fuer Geschlecht, Alter, Groesse, Richtung: waehlen oder entfernen. -->'
    u'<div style="flex: none; padding: 22px 0 0; font-size: 22px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1;">Alter</div>'
    u'<div style="flex: none; margin-top: 8px;" class="note">Als Spanne. Ändert sich nicht von selbst.</div>'
    u'<div style="flex: none; margin-top: 20px;">' + chips(ALTER, u'25–34', 4) + u'</div>'
    + u'<div style="flex-grow: 1;"></div>'
    + u'<div style="flex: none; display: flex; flex-direction: column; gap: 12px;">'
      u'<div style="%s">Übernehmen</div>'
      u'<div style="%s">Angabe entfernen</div></div>' % (PRIMARY, ROT),
    spacer_top() + u'<div style="flex: none; padding: 14px 20px 0"><div style="font-size: 32px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1">Profil</div></div>',
    420))


# --------------------------------------------------------------------- Profil

def profil_zeile(label, wert=None, links=None, chevron=True):
    teile = [u'<div class="row" style="padding: 12px 16px;">']
    if links:
        teile.append(links)
    teile.append(u'<span style="flex-grow: 1; font-size: 15px; font-weight: 700">%s</span>' % label)
    if wert:
        teile.append(u'<span class="num" style="font-size: 14px; font-weight: 700; color: #9BA3AF">%s</span>' % wert)
    if chevron:
        teile.append(CHEVRON_R)
    return u''.join(teile) + u'</div>'


def profil_karte(zeilen):
    return u'<div class="card">%s</div>' % u'<div class="sep"></div>'.join(zeilen)


schreibe(u'Profil.dc.html', u'<div class="ph"><!-- Profil mit den zwei neuen Abschnitten. "Beim Training", "Deine Daten" und Abmelden folgen darunter wie bisher. -->'
    + spacer_top()
    + u'<div style="flex: none; padding: 14px 20px 0"><div style="font-size: 32px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1">Profil</div></div>'
    + u'<div style="flex: none; padding: 20px 20px 0"><div class="card"><div class="row">'
      u'<div style="width: 44px; height: 44px; border-radius: 50%; background: #1D2026; display: flex; align-items: center; justify-content: center; flex: none">'
      u'<span style="font-size: 16px; font-weight: 900; color: #9BA3AF">LW</span></div>'
      u'<div style="flex-grow: 1; display: flex; flex-direction: column; gap: 3px"><div style="font-size: 17px; font-weight: 800">Lena Wagner</div>'
      u'<div style="font-size: 12px; color: #5C636E">lena.wagner@example.de</div></div>' + CHEVRON_R + u'</div></div></div>'
    + u'<div style="flex: none; padding: 20px 20px 0; display: flex; flex-direction: column; gap: 10px"><div class="eyebrow">Über dich</div>'
    + profil_karte([profil_zeile(u'Geschlecht', u'Weiblich'), profil_zeile(u'Alter', u'25–34'), profil_zeile(u'Größe', u'168 cm')])
    + u'</div>'
    + u'<div style="flex: none; padding: 20px 20px 0; display: flex; flex-direction: column; gap: 10px"><div class="eyebrow">Ziele</div>'
    + profil_karte([profil_zeile(u'Richtung', u'Abnehmen'), profil_zeile(u'Tage pro Woche', u'3'), profil_zeile(u'Zielgewicht', u'78,0 kg'),
                    profil_zeile(u'Gewicht eintragen', links=PLUS, chevron=False), profil_zeile(u'Gewichtsverlauf', u'82,5 kg · gestern')])
    + u'</div>'
    + u'<div style="flex: none; padding: 20px 20px 0; display: flex; flex-direction: column; gap: 10px"><div class="eyebrow">Deine Daten</div>'
      u'<div class="card"><div style="padding: 15px 16px; display: flex; gap: 12px; align-items: flex-start">' + INFO
    + u'<div class="note">gymodo misst nichts. Deine Körperdaten und Ziele sieht niemand außer dir — auch dein Studio nicht. Jede Angabe lässt sich einzeln entfernen.</div></div></div></div>'
    + fuellen() + tabs(u'Profil') + u'</div>')


# ------------------------------------------------------------------ Bausteine

def bausteine():
    def block(titel, text, innen, breite=u'1fr'):
        return (u'<div style="display: flex; flex-direction: column; gap: 12px;">'
                u'<div style="display: flex; flex-direction: column; gap: 4px;"><span class="eyebrow">%s</span><div class="note">%s</div></div>'
                u'%s</div>' % (titel, text, innen))

    reihe = lambda *k: u'<div style="display: flex; gap: 12px; align-items: flex-start; flex-wrap: wrap;">%s</div>' % u''.join(k)
    box = lambda w, innen: u'<div style="width: %dpx; flex: none;">%s</div>' % (w, innen)

    innen = [
        u'<div style="font-size: 28px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1;">Bausteine &amp; Entscheidungen</div>',
        block(u'Chip', u'44 pt, Pille, Rand #2A2E36. Gewählt: Rand 1,5 pt Volt, Fläche #14161A, Text weiß. Kein Volt als Fläche — die gehört dem Knopf.',
              reihe(box(110, u'<div class="chip">Divers</div>'), box(110, u'<div class="chip on">Weiblich</div>'))),
        block(u'Zielkachel', u'Karte 14 pt Radius, Symbol 24 pt Strich 2 in #9BA3AF, Titel 16/800, Zeile 12 in #5C636E. Gewählt wie der Chip, das Symbol wird weiß.',
              reihe(box(160, kachel(ICON_MUSKEL, u'Muskeln aufbauen', u'Mehr Gewicht je Übung')), box(160, kachel(ICON_AB, u'Abnehmen', u'Gewicht runter, Kraft halten', an=True)))),
        block(u'Wochenziel unter dem Streifen', u'Ein Strich je Zieltag, 18 × 4 pt. Gefüllt = trainiert. Die Flamme bleibt davon unberührt: sie zählt weiter Wochen mit mindestens einer Einheit. Ein verfehltes Wochenziel reißt keine Serie.',
              u'<div style="display: flex; flex-direction: column; gap: 10px; width: 353px;">'
              + u''.join(u'<div style="display: flex; align-items: center; justify-content: space-between;"><span class="serie-fuss" style="color: #9BA3AF;">%s</span>%s</div>' % (t, zielstriche(v, 3))
                         for t, v in [(u'0 von 3 Tagen diese Woche', 0), (u'2 von 3 Tagen diese Woche', 2), (u'3 von 3 Tagen · Ziel erreicht', 3)])
              + u'</div>'),
        block(u'Gewichtskarte', u'Vier Zahlen, alle mit Deckung: der letzte Eintrag, sein Datum, die Differenz zum ersten Eintrag, der Abstand zum Ziel. Kein Trend, kein BMI. Die Mini-Kurve nimmt die letzten zwölf Punkte, gestrichelt das Ziel.',
              box(353, gewichtskarte())),
        block(u'Stepper44 als Zeile und Rastrad', u'Größe über Minus/Plus (58 pt, Radius 14). Gewicht über dasselbe Rad wie am Gerät, Schritt 0,5 kg, Unterstreichung 180 pt.',
              box(353, stepper(u'168', u'cm'))),
        block(u'Altersspannen', u'Sieben Chips, vier je Zeile. Nichts gewählt heißt keine Angabe — es gibt keinen achten Chip dafür.',
              box(353, chips(ALTER, None, 4))),
        block(u'Entscheidungen', u'',
              u'<div class="note" style="max-width: 720px; white-space: pre-line;">'
              u'• Alter als Spanne, nicht als Jahr — sparsamer, und die App rechnet nichts daraus.\n'
              u'• Geschlecht bleibt: gespeichert für spätere Startgewicht-Vorschläge und Trainingspläne, heute für nichts ausgewertet. Der Screen sagt das.\n'
              u'• Wochenziel in Tagen. Zwei Einheiten an einem Tag sind ein Tag — wie im Streifen.\n'
              u'• Onboarding vor dem Studiobeitritt, jeder Schritt überspringbar, „Später“ schließt das Gate. Nachholen über die Karte auf Home, dieselben Screens als Sheet.\n'
              u'• Kein „Fertig“-Screen: „Los geht’s“ landet auf Home, wo das Ergebnis steht.\n'
              u'• Ziel erreicht: eine Zeile mit Haken, kein Konfetti (§5). Bleibt, bis ein neues Ziel steht.\n'
              u'• Keine Öffnung für Personal, auch nicht als Summe. Der Satz dazu steht im Profil unter „Deine Daten“.'
              u'</div>'),
    ]
    return (u'<div style="width: 900px; min-height: 1560px; background: #0A0B0D; color: #F2F4F7; padding: 40px; display: flex; flex-direction: column; gap: 36px;">'
            + u''.join(innen) + u'</div>')


schreibe(u'Bausteine.dc.html', bausteine())


# ------------------------------------------------------------------- Canvas

W, H, GAP = 393, 852, 80
X = lambda i: i * (W + GAP)
canvas = {
    u'artboards': [
        {u'file': u'Onboarding1.dc.html', u'x': X(0), u'y': 0, u'w': W, u'h': H, u'title': u'01 · Über dich'},
        {u'file': u'Onboarding2.dc.html', u'x': X(1), u'y': 0, u'w': W, u'h': H, u'title': u'02 · Dein Körper'},
        {u'file': u'Onboarding3.dc.html', u'x': X(2), u'y': 0, u'w': W, u'h': H, u'title': u'03 · Dein Ziel'},
        {u'file': u'Onboarding4.dc.html', u'x': X(3), u'y': 0, u'w': W, u'h': H, u'title': u'04 · Wie oft?'},
        {u'file': u'Onboarding5.dc.html', u'x': X(4), u'y': 0, u'w': W, u'h': H, u'title': u'05 · Zielgewicht'},
        {u'file': u'Main.dc.html', u'x': X(0), u'y': 1000, u'w': W, u'h': H, u'title': u'06 · Home · Deine Ziele'},
        {u'file': u'HomeNachholen.dc.html', u'x': X(1), u'y': 1000, u'w': W, u'h': H, u'title': u'07 · Home · übersprungen'},
        {u'file': u'HomeZielErreicht.dc.html', u'x': X(2), u'y': 1000, u'w': W, u'h': H, u'title': u'08 · Home · Ziel erreicht'},
        {u'file': u'Gewichtsverlauf.dc.html', u'x': X(3), u'y': 1000, u'w': W, u'h': H, u'title': u'09 · Gewichtsverlauf'},
        {u'file': u'GewichtEintragen.dc.html', u'x': X(4), u'y': 1000, u'w': W, u'h': H, u'title': u'10 · Gewicht eintragen'},
        {u'file': u'Profil.dc.html', u'x': X(0), u'y': 2000, u'w': W, u'h': H, u'title': u'11 · Profil'},
        {u'file': u'ProfilAlter.dc.html', u'x': X(1), u'y': 2000, u'w': W, u'h': H, u'title': u'12 · Profil · Alter ändern'},
        {u'file': u'Bausteine.dc.html', u'x': X(2), u'y': 2000, u'w': 900, u'h': 1560, u'title': u'13 · Bausteine & Entscheidungen'},
    ],
    u'annotations': [
        {u'id': u'brief', u'x': 0, u'y': -300, u'w': 866,
         u'text': u'Ziele & Fortschritt — Spec 2026-09-13-ziele-und-fortschritt-design.md.\n\n'
                  u'Reihe 1: das Onboarding nach der Registrierung, fünf Schritte, jeder überspringbar. Schritt 5 nur, wenn Schritt 2 ein Gewicht hat.\n'
                  u'Reihe 2: Home in drei Zuständen, der Gewichtsverlauf, das Eintrag-Sheet.\n'
                  u'Reihe 3: Profil mit den zwei neuen Abschnitten, ein Picker-Sheet stellvertretend für alle, die Bausteine.\n\n'
                  u'Beispielperson wie in den bisherigen Artboards: Lena, Kraftwerk Nord. 82,5 kg, Ziel 78,0, 3 Tage pro Woche.'},
        {u'id': u'volt', u'x': 946, u'y': -300, u'w': 866,
         u'text': u'Genau eine Akzentfläche je Screen (§2): im Onboarding der Knopf, auf Home die Flamme, im Verlauf der Zeitraum-Chip. Gewählte Chips und Kacheln tragen Volt nur als Strich — wie der Fokusrand der Felder.\n\n'
                  u'Serie und Flamme bleiben, wie sie sind: Wochen in Folge mit mindestens einer Einheit. Neu sind zwei Zeilen: „Ziel 3 Tage“ rechts im Kopf, „2 von 3 Tagen“ mit drei Strichen darunter. Das Wochenziel ist eine eigene Aussage neben der Serie, nicht ihre Bedingung — entschieden am 13. September.'},
        {u'id': u'offen', u'x': 1892, u'y': -300, u'w': 393,
         u'text': u'Zum Prüfen:\n\n• Schritt 4: zwei große Knöpfe statt Rad. Sieben Werte brauchen kein Rad — aber ist es dir zu leer?'},
        {u'id': u'home', u'x': 2365, u'y': 1000, u'w': 393,
         u'text': u'06 mit Zielen, 07 nach „Später“ — die Karte öffnet dieselben fünf Schritte als Sheet, 08 nach dem Eintrag, der die Marke erreicht.\n\n'
                  u'Die Gewichtskarte zeigt nur Zahlen mit Deckung: letzter Eintrag, Datum, Differenz zum ersten, Abstand zum Ziel. Kein Trend, kein BMI, keine Prognose.'},
    ],
    u'launch': {u'view': u'canvas'},
}
io.open(os.path.join(HIER, u'canvas.json'), 'w', encoding='utf-8').write(json.dumps(canvas, ensure_ascii=False, indent=2) + u'\n')
print(u'geschrieben: canvas.json')
