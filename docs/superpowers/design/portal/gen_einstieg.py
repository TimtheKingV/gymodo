# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, PRIMARY, SECONDARY, FIELD, schreibe)

NOTE = 'font-size: 13px; color: #5c636e; line-height: 1.45;'

# ---------------------------------------------------------------- Start
# Die Wurzelseite. Wer hier landet, ist entweder Trainer (und will ins
# Portal) oder Mitglied (und ist im Web falsch -- die App gibt es nur auf
# dem iPhone). Beides muss die Seite in einem Blick beantworten.
start = HEAD + """
<div style="min-height: 960px; background: #0a0b0d; display: flex; flex-direction: column;">
  <header style="padding: 32px 48px; display: flex; align-items: center; justify-content: space-between;">
    <span style="font-size: 20px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase;">gymodo</span>
    <a href="#" style="%(sec)s">Anmelden</a>
  </header>

  <div style="flex: 1; display: flex; align-items: center; padding: 0 48px;">
    <div style="max-width: 720px;">
      <h1 style="font-size: 92px; line-height: 0.94; font-weight: 800; letter-spacing: -0.045em; text-transform: uppercase; margin: 0;">Dein Studio,<br>am Gerät<br>erklärt.</h1>
      <p style="color: #9ba3af; font-size: 17px; line-height: 1.5; margin: 32px 0 0; max-width: 52ch;">Ein Tag am Gerät, ein Tap, und das Mitglied sieht die Einweisung, seine eigenen Einstellwerte und was es zuletzt geschafft hat. Du pflegst den Katalog hier.</p>
      <div style="display: flex; gap: 16px; align-items: center; margin-top: 40px;">
        <a href="#" style="%(pri)s height: 64px; padding: 0 32px; border-radius: 16px; font-size: 17px;">Als Trainer anmelden</a>
      </div>
      <a href="#" style="%(note)s color: #9ba3af; display: inline-block; margin-top: 20px;">Konto anlegen</a>
      <p style="%(note)s margin: 48px 0 0; max-width: 52ch;">Du bist Mitglied? gymodo ist eine App fürs iPhone — im Web gibt es nichts für dich zu tun. Frag an der Theke nach der Einladung, oder tippe einfach ein Gerät an.</p>
    </div>
  </div>

  <footer style="padding: 32px 48px; border-top: 1px solid #2a2e36; color: #5c636e; font-size: 13px; line-height: 1.45; max-width: 80ch;">
    gymodo misst nichts. Angezeigt wird ausschließlich, was Mitglieder selbst bestätigt haben. Einweisungsvideos und Einstellhinweise sind Inhalte des Studios, keine Trainings- oder Gesundheitsempfehlung von gymodo.
  </footer>
</div>
""" % {'sec': SECONDARY, 'pri': PRIMARY, 'note': NOTE} + FOOT
schreibe('Start.dc.html', start)


def anmelde_seite(inhalt):
    return HEAD + """
<div style="min-height: 900px; background: #0a0b0d; display: flex; flex-direction: column;">
  <header style="padding: 32px 48px;">
    <span style="font-size: 20px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase;">gymodo</span>
  </header>
  <div style="flex: 1; display: flex; align-items: flex-start; justify-content: center; padding: 48px 28px 96px;">
    <div style="width: 100%; max-width: 420px;">
""" + inhalt + """
    </div>
  </div>
</div>
""" + FOOT


# ---------------------------------------------------------------- Anmelden
# Schritt 1. E-Mail und Passwort wie ueberall sonst -- der Code verifiziert
# danach nur noch die Adresse, er ist kein Anmeldeweg mehr.
anmelden = """
      <h1 style="font-size: 32px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 0;">Anmelden</h1>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 32px;">
        <span style="%(label)s color: #9ba3af;">E-Mail</span>
        <div style="%(field)s min-height: 52px; font-size: 16px;">tim@kraftwerk-nord.de</div>
      </div>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 20px;">
        <span style="%(label)s color: #9ba3af;">Passwort</span>
        <div style="%(field)s min-height: 52px; font-size: 16px; letter-spacing: 0.2em;">••••••••••</div>
      </div>

      <a href="#" style="%(pri)s height: 64px; width: 100%%; margin-top: 32px; border-radius: 16px; font-size: 17px;">Anmelden</a>

      <div style="display: flex; justify-content: center; gap: 24px; margin-top: 24px;">
        <a href="#" style="%(note)s color: #9ba3af;">Passwort vergessen</a>
        <a href="#" style="%(note)s color: #9ba3af;">Konto anlegen</a>
      </div>
""" % {'label': LABEL, 'field': FIELD, 'pri': PRIMARY, 'note': NOTE}
schreibe('Anmelden.dc.html', anmelde_seite(anmelden))


# ---------------------------------------------------------------- Registrieren
# Selbstregistrierung ist neu: jeder legt ein Konto an. Ein Konto ist aber
# noch kein Zugang -- das Studio kommt erst danach, ueber den Studio-Code.
registrieren = """
      <h1 style="font-size: 32px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 0;">Registrieren</h1>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 32px;">
        <span style="%(label)s color: #9ba3af;">E-Mail</span>
        <div style="%(field)s min-height: 52px; font-size: 16px;">tim@kraftwerk-nord.de</div>
      </div>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 20px;">
        <span style="%(label)s color: #9ba3af;">Passwort</span>
        <div style="%(field)s min-height: 52px; font-size: 16px; letter-spacing: 0.2em;">••••••••••</div>
        <p style="%(note)s margin: 4px 0 0;">Mindestens zehn Zeichen. Länge zählt mehr als Sonderzeichen.</p>
      </div>

      <a href="#" style="%(pri)s height: 64px; width: 100%%; margin-top: 32px; border-radius: 16px; font-size: 17px;">Konto anlegen</a>

      <p style="%(note)s margin: 24px 0 0;">Ein Konto allein reicht nicht — du brauchst danach den Code deines Studios.</p>
""" % {'label': LABEL, 'field': FIELD, 'pri': PRIMARY, 'note': NOTE}
schreibe('Registrieren.dc.html', anmelde_seite(registrieren))


# ---------------------------------------------------------------- Verifizieren
# Der Code aus dem alten Anmeldeweg bleibt als Bildschirm bestehen, wechselt
# aber den Job: er bestaetigt einmalig eine Adresse, er meldet nicht an.
verifizieren = """
      <h1 style="font-size: 32px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 0;">Verifizieren</h1>
      <p style="color: #9ba3af; margin: 12px 0 0;">Wir haben einen Code an <span style="color: #f2f4f7;">tim@kraftwerk-nord.de</span> geschickt. Er gilt eine Stunde.</p>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 32px;">
        <span style="%(label)s color: #9ba3af;">Code aus der E-Mail</span>
        <div style="%(field)s min-height: 64px; font-size: 28px; font-weight: 800; letter-spacing: 0.32em; color: #f2f4f7; justify-content: center;">418 903</div>
      </div>

      <a href="#" style="%(pri)s height: 64px; width: 100%%; margin-top: 24px; border-radius: 16px; font-size: 17px;">Bestätigen</a>

      <div style="display: flex; justify-content: center; margin-top: 24px;">
        <a href="#" style="%(note)s color: #9ba3af;">Neuen Code anfordern</a>
      </div>
""" % {'label': LABEL, 'field': FIELD, 'pri': PRIMARY, 'note': NOTE}
schreibe('Verifizieren.dc.html', anmelde_seite(verifizieren))


# ---------------------------------------------------------------- PasswortVergessen
# Der Satz unter dem Feld ist wortwoertlich Pflicht: dieselbe Antwort fuer
# eine Adresse mit Konto und eine ohne, sonst liesse sich das Studio
# durchzaehlen.
passwort_vergessen = """
      <h1 style="font-size: 32px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 0;">Passwort vergessen</h1>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 32px;">
        <span style="%(label)s color: #9ba3af;">E-Mail</span>
        <div style="%(field)s min-height: 52px; font-size: 16px;">tim@kraftwerk-nord.de</div>
      </div>

      <a href="#" style="%(pri)s height: 64px; width: 100%%; margin-top: 24px; border-radius: 16px; font-size: 17px;">Link anfordern</a>

      <p style="%(note)s margin: 24px 0 0;">Wenn es zu dieser Adresse ein Konto gibt, ist die Mail unterwegs.</p>
""" % {'label': LABEL, 'field': FIELD, 'pri': PRIMARY, 'note': NOTE}
schreibe('PasswortVergessen.dc.html', anmelde_seite(passwort_vergessen))


# ---------------------------------------------------------------- PasswortNeu
# Ziel des Links aus PasswortVergessen. Zwei Felder, damit ein Tippfehler
# nicht erst beim naechsten Anmeldeversuch auffaellt.
passwort_neu = """
      <h1 style="font-size: 32px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 0;">Neues Passwort</h1>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 32px;">
        <span style="%(label)s color: #9ba3af;">Neues Passwort</span>
        <div style="%(field)s min-height: 52px; font-size: 16px; letter-spacing: 0.2em;">••••••••••</div>
      </div>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 20px;">
        <span style="%(label)s color: #9ba3af;">Wiederholen</span>
        <div style="%(field)s min-height: 52px; font-size: 16px; letter-spacing: 0.2em;">••••••••••</div>
      </div>

      <a href="#" style="%(pri)s height: 64px; width: 100%%; margin-top: 32px; border-radius: 16px; font-size: 17px;">Passwort speichern</a>
""" % {'label': LABEL, 'field': FIELD, 'pri': PRIMARY}
schreibe('PasswortNeu.dc.html', anmelde_seite(passwort_neu))


# ---------------------------------------------------------------- KeinStudio
# Der Zustand direkt nach der Verifikation: ein Konto existiert, gehoert
# aber noch keinem Studio. Ohne Studio gibt es fuer diese Person nichts zu
# sehen -- das ist keine Fehlermeldung, sondern schlicht der Ausgangszustand.
#
# Hier stand bis zum 1. September ein Studio-Code-Feld. Es war an dieser
# Stelle falsch, gleich zweifach: der Code macht Mitglieder, und
# Einstellungen -> Studio sagt daneben ausdruecklich "Er macht niemanden zum
# Trainer" -- ein Konto, das ihn hier eingibt, saehe im Portal danach
# genauso wenig wie vorher. Und note-einstieg sagt im ersten Satz, dass es
# im Web fuer Mitglieder nichts gibt; ein Beitrittsformular war genau das.
#
# Wer im Web ohne Studio landet, ist Personal. Personal kommt ueber
# Leute -> Mitarbeiter eines bestehenden Studios herein, nicht ueber einen
# Code. Der Bildschirm hat deshalb keine Hauptaktion mehr, die er einloesen
# koennte -- die einzige Aktion gilt dem Mitglied, das sich hierher verirrt
# hat, und sie fuehrt aus dem Web heraus.
kein_studio = """
      <h1 style="font-size: 32px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 0;">Noch kein Studio</h1>
      <p style="color: #9ba3af; margin: 12px 0 0;">Dein Konto steht. Ein Studio muss dich noch als Mitarbeiter hinzufügen — danach steht hier das Portal.</p>

      <p style="%(note)s margin: 20px 0 0;">Wer im Studio schon dabei ist, findet dich über deine E-Mail-Adresse unter <span style="color: #9ba3af;">Leute → Mitarbeiter</span>. Bis dahin gibt es hier nichts zu sehen — das ist keine Sperre, sondern die Wahrheit.</p>

      <div style="margin-top: 32px; padding-top: 24px; border-top: 1px solid #2a2e36;">
        <div style="font-weight: 600;">Du wolltest trainieren?</div>
        <p style="%(note)s margin: 6px 0 0;">Das Portal ist für Studios. Trainieren läuft in der App — dort trittst du deinem Studio bei, indem du den Aushang am Eingang oder den Aufkleber an einem Gerät scannst.</p>
        <a href="#" style="%(sec)s height: 52px; width: 100%%; margin-top: 16px; border-radius: 14px; font-size: 15px;">App laden</a>
      </div>
""" % {'note': NOTE, 'sec': SECONDARY}
schreibe('KeinStudio.dc.html', anmelde_seite(kein_studio))
