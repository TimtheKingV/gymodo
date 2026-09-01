# -*- coding: utf-8 -*-
"""Erzeugt den Einstieg der Member-App: Anmeldung, Registrierung,
Verifikation, Passwort, Studio-Beitritt, Passwort-Aendern im Profil.

Zwei der sechs Dateien sind Ueberarbeitungen bestehender, abgestimmter
Artboards (LoginMail, LoginCode) -- ihr Dateiname bleibt, weil er die
Identitaet auf der Canvas ist. LoginCode behaelt den sechsstelligen
Code: er verifiziert nach der Registrierung einmalig die Adresse, er
ist kein Anmeldeweg mehr. Alle uebrigen 25 Artboards bleiben unberuehrt
-- dieses Modul schreibt nur diese sechs Dateien.
"""
from build import (NOTE, NOTE_FAINT, FIELD, FIELD_FOCUS, PRIMARY, PRIMARY_OFF, NEBEN,
                    schreibe, kopf_marke, kopf_zurueck, titel, feld, tabs, ph, spacer_top, fuellen)

EMAIL = 'lena.wagner@example.de'


def zeile_svg(pfad, groesse=19, farbe='#9BA3AF', breite='1.9'):
    return ('<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="%s" '
            'stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</svg>'
            % (groesse, groesse, farbe, breite, pfad))


def qr_svg(groesse=22, farbe='#0A0B0D'):
    """QR-Umriss fuer die Hauptaktion. Steht auf der Akzentflaeche, ist
    deshalb dunkel -- nicht volt auf volt."""
    return ('<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="%s" '
            'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            '<rect x="3.5" y="3.5" width="6.5" height="6.5" rx="1.4"/>'
            '<rect x="14" y="3.5" width="6.5" height="6.5" rx="1.4"/>'
            '<rect x="3.5" y="14" width="6.5" height="6.5" rx="1.4"/>'
            '<path d="M14 14h3.2v3.2H14z"/><path d="M20.5 14v6.5H14"/></svg>'
            % (groesse, groesse, farbe))


def sucher_ecke(pos):
    """Eine der vier Sucherecken. Bewusst kein geschlossener Rahmen: ein
    Rahmen sieht aus wie eine Flaeche, die etwas verdeckt. Vier Winkel
    zeigen den Ausschnitt, ohne ihn zuzumachen. Rand, keine Flaeche --
    zaehlt nicht gegen die eine Akzentflaeche je Screen."""
    kanten = {
        'lo': 'top: 0; left: 0; border-top: 3px solid #D4FF3F; border-left: 3px solid #D4FF3F; border-top-left-radius: 15px;',
        'ro': 'top: 0; right: 0; border-top: 3px solid #D4FF3F; border-right: 3px solid #D4FF3F; border-top-right-radius: 15px;',
        'lu': 'bottom: 0; left: 0; border-bottom: 3px solid #D4FF3F; border-left: 3px solid #D4FF3F; border-bottom-left-radius: 15px;',
        'ru': 'bottom: 0; right: 0; border-bottom: 3px solid #D4FF3F; border-right: 3px solid #D4FF3F; border-bottom-right-radius: 15px;',
    }[pos]
    return '<div style="position: absolute; width: 44px; height: 44px; %s"></div>' % kanten


# =============================================================== LoginMail
# Schritt 1. E-Mail und Passwort wie ueberall sonst -- der Code aus
# LoginCode verifiziert danach nur noch einmalig die Adresse, er ist
# kein Anmeldeweg mehr. Der Pending-Tag (ein Tag-Tap vor dem Login geht
# nicht verloren) ist bestehender, abgestimmter Inhalt und bleibt.
pending_tag = ("""
  <div style="flex: none; margin: 26px 28px 0; background: #14161A; border: 1px solid #D4FF3F55; border-radius: 12px; padding: 14px 16px; display: flex; gap: 12px; align-items: flex-start;">
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#D4FF3F" stroke-width="2" stroke-linecap="round" style="flex: none; margin-top: 1px;"><path d="M7.5 8.5a5 5 0 0 1 0 7"/><path d="M11.5 5.5a10 10 0 0 1 0 13"/><path d="M15.5 2.5a15 15 0 0 1 0 19"/></svg>
    <div style="display: flex; flex-direction: column; gap: 4px;">
      <div style="font-size: 15px; font-weight: 800; letter-spacing: -.01em;">Beinpresse erkannt</div>
      <div style="font-size: 13px; line-height: 1.45; color: #9BA3AF;">Melde dich an — danach landest du direkt bei diesem Gerät.</div>
    </div>
  </div>
""")

login_mail = spacer_top() + kopf_marke() + pending_tag
login_mail += titel('Anmelden', 'Mit E-Mail und Passwort.', top=34)
login_mail += feld('E-Mail-Adresse', '<span style="font-size: 18px; font-weight: 600;">%s</span>' % EMAIL)
login_mail += feld('Passwort', '<span style="font-size: 18px; font-weight: 600; letter-spacing: .28em;">••••••••••</span>')
login_mail += fuellen()
login_mail += ("""
  <div style="flex: none; padding: 0 28px 20px; display: flex; flex-direction: column; gap: 16px;">
    <div style="%s">Anmelden</div>
    <div style="display: flex; align-items: center; justify-content: center; gap: 10px;">
      <a href="#" style="font-size: 13px; color: #9BA3AF;">Passwort vergessen</a>
      <span style="width: 3px; height: 3px; border-radius: 50%%; background: #2A2E36;"></span>
      <a href="#" style="font-size: 13px; color: #9BA3AF;">Konto anlegen</a>
    </div>
  </div>
""" % PRIMARY)
schreibe('LoginMail.dc.html', ph(login_mail))


# =============================================================== LoginCode
# Der Code bleibt hier genau richtig, wechselt aber den Job: er kommt
# nach der Registrierung und bestaetigt einmalig die Adresse. Der
# unvollstaendige Code plus deaktivierte Hauptaktion zeigen zugleich den
# Zustand "Deaktiviert" (Designsystem Abschnitt 5).
zellen = [
    ('4', '#2A2E36', None),
    ('1', None, None),
    ('9', None, None),
    ('7', None, None),
    (None, None, 'cursor'),
    (None, None, None),
]
zellen_html = []
for wert, randfarbe, sonder in zellen:
    stil = 'height: 66px; border-radius: 13px; background: #14161A; border: 1px solid #2A2E36; display: flex; align-items: center; justify-content: center; font-size: 28px;'
    if randfarbe:
        stil = stil.replace('border: 1px solid #2A2E36;', 'border: 1px solid %s;' % randfarbe)
    if sonder == 'cursor':
        stil = stil.replace('border: 1px solid #2A2E36;', 'border: 1.5px solid #D4FF3F;')
        zellen_html.append('<div class="num" style="%s"><span style="width: 2px; height: 28px; background: #D4FF3F;"></span></div>' % stil)
    elif wert:
        zellen_html.append('<div class="num" style="%s">%s</div>' % (stil, wert))
    else:
        zellen_html.append('<div style="%s"></div>' % stil)

login_code = spacer_top() + kopf_zurueck()
login_code += ("""
  <div style="flex: none; padding: 26px 28px 0; display: flex; flex-direction: column; gap: 10px;">
    <div style="font-size: 32px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1.02;">E-Mail bestätigen</div>
    <div style="%s">Code gesendet an <span style="color: #F2F4F7; font-weight: 600;">%s</span></div>
  </div>
""" % (NOTE, EMAIL))
login_code += ('<div style="flex: none; padding: 34px 28px 0; display: grid; '
               'grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 9px;">%s</div>' % ''.join(zellen_html))
login_code += ("""
  <div style="flex: none; padding: 22px 28px 0; display: flex; align-items: center; gap: 8px;">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#5C636E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>
    <span style="font-size: 13px; color: #5C636E;">Neuen Code anfordern in <span class="num" style="font-weight: 700; color: #9BA3AF;">00:42</span></span>
  </div>
""")
login_code += fuellen()
login_code += ("""
  <div style="flex: none; margin: 0 28px 20px; background: #14161A; border: 1px solid #2A2E36; border-radius: 12px; padding: 15px 16px; display: flex; gap: 12px; align-items: flex-start;">
    %s
    <div style="font-size: 13px; line-height: 1.5; color: #9BA3AF;">Keine Mail bekommen? Sieh im Spam-Ordner nach. Der Code ist eine Stunde gültig.</div>
  </div>
""" % zeile_svg('<rect x="3" y="5.5" width="18" height="13" rx="2.4"/><path d="m3.8 7 8.2 6 8.2-6"/>'))
login_code += ("""
  <div style="flex: none; padding: 0 28px 20px;">
    <div style="%s">Bestätigen</div>
    <div style="font-size: 12px; color: #5C636E; padding-top: 9px; text-align: center;">Noch zwei Ziffern</div>
  </div>
""" % PRIMARY_OFF)
schreibe('LoginCode.dc.html', ph(login_code))


# ======================================================== MemberRegistrieren
# Selbstregistrierung: jeder legt ein Konto an. Ein Konto ist noch kein
# Zugang -- das Studio kommt erst ueber den Code auf MemberKeinStudio.
registrieren = spacer_top() + kopf_zurueck()
registrieren += titel('Konto anlegen', 'Für dein Studio brauchst du ein Konto.', top=26)
registrieren += feld('E-Mail-Adresse', '<span style="font-size: 18px; font-weight: 600; color: #5C636E;">name@beispiel.de</span>', fokus=True)
registrieren += feld('Passwort', '<span style="font-size: 18px; font-weight: 600; letter-spacing: .28em;">••••••••••</span>')
registrieren += ('<div style="flex: none; padding: 6px 28px 0;"><div style="%s">Mindestens zehn Zeichen. '
                  'Länge zählt mehr als Sonderzeichen.</div></div>' % NOTE_FAINT)
registrieren += fuellen()
registrieren += ("""
  <div style="flex: none; padding: 0 28px 20px; display: flex; flex-direction: column; gap: 12px;">
    <div style="%s">Konto anlegen</div>
    <div style="%s text-align: center;">Danach schicken wir dir einen Code zur Bestätigung.</div>
  </div>
""" % (PRIMARY, NOTE_FAINT))
schreibe('MemberRegistrieren.dc.html', ph(registrieren))


# ============================================================= MemberPasswort
# Vergessen und Zurücksetzen als zwei beschriftete Zustände in einem
# Artboard. Nur die Hauptaktion (Passwort speichern) traegt Akzent --
# "Link anfordern" ist ein blosser Text-Link, kein zweites Volt.
passwort = spacer_top() + kopf_zurueck()
passwort += titel('Passwort', 'Fordere einen Link an, oder setze ein neues, wenn du schon einen hast.', top=26)

passwort += ('<div style="flex: none; padding: 28px 28px 0;"><span class="eyebrow">Vergessen</span></div>')
passwort += feld('E-Mail-Adresse', '<span style="font-size: 18px; font-weight: 600;">%s</span>' % EMAIL, top=9)
passwort += ("""
  <div style="flex: none; padding: 14px 28px 0; display: flex; align-items: center; gap: 8px;">
    %s
    <a href="#" style="font-size: 13px;">Link anfordern</a>
  </div>
  <div style="flex: none; padding: 6px 28px 0;"><div style="%s">Wenn es zu dieser Adresse ein Konto gibt, ist die Mail unterwegs.</div></div>
""" % (zeile_svg('<rect x="4.5" y="10.5" width="15" height="9.5" rx="2.2"/><path d="M8 10.5V7.8a4 4 0 0 1 8 0v2.7"/>', groesse=16, farbe='#D4FF3F', breite='2'), NOTE_FAINT))

passwort += '<div style="flex: none; margin: 24px 28px 0;" class="sep"></div>'

passwort += ('<div style="flex: none; padding: 22px 28px 0;"><span class="eyebrow">Zurücksetzen</span></div>')
passwort += feld('Neues Passwort', '<span style="font-size: 18px; font-weight: 600; letter-spacing: .28em;">••••••••••</span>', top=9)
passwort += feld('Wiederholen', '<span style="font-size: 18px; font-weight: 600; letter-spacing: .28em;">••••••••••</span>')

passwort += fuellen()
passwort += '<div style="flex: none; padding: 0 28px 20px;"><div style="%s">Passwort speichern</div></div>' % PRIMARY
schreibe('MemberPasswort.dc.html', ph(passwort))


# ========================================================== MemberKeinStudio
# Der wichtigste der sechs: was ein frisch registriertes Mitglied sieht.
# Keine Tab-Leiste -- es gibt nichts, wohin man wechseln koennte.
#
# Der Scan ist die Hauptaktion und traegt die eine Akzentflaeche. Das
# Code-Feld bleibt als zweiter Weg, verliert dabei aber den Akzent an
# den Scan: zwei Flaechen wuerden beide behaupten, DER Weg zu sein.
kein_studio = spacer_top() + kopf_marke()
kein_studio += titel('Noch kein Studio',
                     'gymodo gehört zu einem Studio. Scanne den Code, der dort aushängt — '
                     'oder den Aufkleber an jedem Gerät.', top=40)
kein_studio += ("""
  <div style="flex: none; padding: 26px 28px 0;">
    <div style="%s gap: 11px;">%s<span>Code im Studio scannen</span></div>
  </div>
""" % (PRIMARY, qr_svg()))
kein_studio += ('<div style="flex: none; padding: 11px 28px 0;">'
                '<div style="%s text-align: center;">Aushang am Eingang oder Aufkleber am Gerät.</div></div>'
                % NOTE_FAINT)
kein_studio += '<div style="flex: none; margin: 26px 28px 0;" class="sep"></div>'
kein_studio += ('<div style="flex: none; padding: 22px 28px 0;">'
                '<span class="eyebrow">Kein Code zur Hand?</span></div>')
kein_studio += feld('Studio-Code',
                    '<span class="num" style="font-size: 18px; letter-spacing: .08em;">KWNORD-7F2X</span>',
                    monospace=True, top=9)
kein_studio += ('<div style="flex: none; padding: 12px 28px 0;"><div style="%s">Beitreten</div></div>' % NEBEN)
kein_studio += fuellen()
kein_studio += ('<div style="flex: none; padding: 0 28px 20px;">'
                '<div style="%s text-align: center;">Den Code bekommst du an der Theke.</div></div>'
                % NOTE_FAINT)
schreibe('MemberKeinStudio.dc.html', ph(kein_studio))


# ====================================================== MemberPasswortAendern
# Im Profil, drei Felder. Push aus Profil -- behaelt die Tab-Leiste
# (Designsystem Abschnitt 11: ein Push innerhalb eines Tabs behaelt sie).
# Content-Screen, kein Login-Screen: 20 pt Seitenrand statt 28.
aendern = spacer_top() + kopf_zurueck('Profil')
aendern += titel('Passwort ändern', top=20, seite=20)
aendern += feld('Aktuelles Passwort', '<span style="font-size: 18px; font-weight: 600; letter-spacing: .28em;">••••••••••</span>', seite=20, top=24)
aendern += feld('Neues Passwort', '<span style="font-size: 18px; font-weight: 600; letter-spacing: .28em;">••••••••••</span>', seite=20)
aendern += feld('Wiederholen', '<span style="font-size: 18px; font-weight: 600; letter-spacing: .28em;">••••••••••</span>', seite=20)
aendern += fuellen()
aendern += '<div style="flex: none; padding: 0 20px 20px;"><div style="%s">Passwort speichern</div></div>' % PRIMARY
aendern += tabs('Profil')
schreibe('MemberPasswortAendern.dc.html', ph(aendern))


# ============================================================= MemberScanner
# Der Sucher, den Zugang 03 oeffnet. Es ist derselbe Scanner wie in
# "Training -> Geraet finden" (App 15), aber ohne Tab-Leiste: die Seite
# Zugang hat keine. Eigenes Artboard statt eines Verweises -- "wie 15,
# nur anders" wird beim Bauen verlaesslich falsch gelesen.
#
# Keine Akzentflaeche auf diesem Screen. Die vier Sucherecken sind
# Raender; die einzige Aktion unten ist eine Nebenaktion. Ein Screen
# darf hoechstens eine Akzentflaeche haben, nicht mindestens eine.
scanner = spacer_top() + kopf_zurueck()
scanner += titel('Code scannen',
                 'Halte die Kamera auf den Aushang oder auf den Aufkleber am Gerät.', top=26)
scanner += ("""
  <div style="flex: none; margin: 30px 28px 0; height: 330px; border-radius: 18px;
              background: #14161A; border: 1px solid #2A2E36; position: relative;
              display: flex; align-items: center; justify-content: center;">
    <div style="position: relative; width: 206px; height: 206px;">%s%s%s%s</div>
  </div>
""" % (sucher_ecke('lo'), sucher_ecke('ro'), sucher_ecke('lu'), sucher_ecke('ru')))
scanner += ("""
  <div style="flex: none; margin: 18px 28px 0; background: #14161A; border: 1px solid #2A2E36;
              border-radius: 12px; padding: 14px 16px; display: flex; gap: 12px; align-items: flex-start;">
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#9BA3AF" stroke-width="2"
         stroke-linecap="round" style="flex: none; margin-top: 1px;"><path d="M7.5 8.5a5 5 0 0 1 0 7"/><path d="M11.5 5.5a10 10 0 0 1 0 13"/><path d="M15.5 2.5a15 15 0 0 1 0 19"/></svg>
    <div style="%s">Klebt ein NFC-Aufkleber am Gerät, genügt es, das Telefon daran zu halten — ohne diesen Bildschirm.</div>
  </div>
""" % NOTE)
scanner += fuellen()
scanner += ('<div style="flex: none; padding: 0 28px 20px;"><div style="%s">Code stattdessen eingeben</div></div>'
            % NEBEN)
schreibe('MemberScanner.dc.html', ph(scanner))
