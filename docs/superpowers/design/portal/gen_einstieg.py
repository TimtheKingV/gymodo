# -*- coding: utf-8 -*-
from build import (HEAD, FOOT, LABEL, PRIMARY, SECONDARY, FIELD, schreibe,
                   zurueck)

NOTE = 'font-size: 13px; color: #5c636e; line-height: 1.45;'

# ---------------------------------------------------------------- Start
# Die Wurzelseite. Wer hier landet, ist entweder Trainer (und will ins
# Portal) oder Mitglied (und ist im Web falsch -- die App gibt es nur auf
# dem iPhone). Beides muss die Seite in einem Blick beantworten.
start = HEAD + """
<div style="min-height: 900px; background: #0a0b0d; display: flex; flex-direction: column;">
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
# Schritt 1. Kein Passwort, keine Selbstregistrierung: der Zugang kommt
# ueber das Studio (signInWithOtp laeuft mit shouldCreateUser: false).
anmelden = """
      <h1 style="font-size: 32px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 0;">Anmelden</h1>
      <p style="color: #9ba3af; margin: 12px 0 0;">Wir schicken dir einen sechsstelligen Code per E-Mail. Ein Passwort brauchst du nicht.</p>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 32px;">
        <span style="%(label)s color: #9ba3af;">E-Mail</span>
        <div style="%(field)s min-height: 52px; font-size: 16px;">tim@kraftwerk-nord.de</div>
      </div>

      <a href="#" style="%(pri)s height: 64px; width: 100%%; margin-top: 24px; border-radius: 16px; font-size: 17px;">Code anfordern</a>

      <p style="%(note)s margin: 32px 0 0;">Noch kein Zugang? Den bekommst du von deinem Studio — es lädt dich ein. Hier kannst du kein Konto anlegen.</p>
""" % {'label': LABEL, 'field': FIELD, 'pri': PRIMARY, 'note': NOTE}
schreibe('Anmelden.dc.html', anmelde_seite(anmelden))


# ---------------------------------------------------------------- Code
# Schritt 2. Die Zieladresse steht sichtbar da -- sonst weiss niemand, in
# welchem Postfach er nachsehen soll.
code = """
      <a href="#" style="%(label)s color: #5c636e;">%(zurueck)s</a>
      <h1 style="font-size: 32px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 12px 0 0;">Code eingeben</h1>
      <p style="color: #9ba3af; margin: 12px 0 0;">Wir haben ihn an <span style="color: #f2f4f7;">tim@kraftwerk-nord.de</span> geschickt. Er gilt eine Stunde.</p>

      <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 32px;">
        <span style="%(label)s color: #9ba3af;">Code aus der E-Mail</span>
        <div style="%(field)s min-height: 64px; font-size: 28px; font-weight: 800; letter-spacing: 0.32em; color: #f2f4f7; justify-content: center;">418 903</div>
      </div>

      <a href="#" style="%(pri)s height: 64px; width: 100%%; margin-top: 24px; border-radius: 16px; font-size: 17px;">Anmelden</a>

      <div style="display: flex; justify-content: center; margin-top: 24px;">
        <a href="#" style="%(note)s color: #9ba3af;">Neuen Code anfordern</a>
      </div>
""" % {'label': LABEL, 'field': FIELD, 'pri': PRIMARY, 'note': NOTE,
       'zurueck': zurueck('Andere Adresse')}
schreibe('AnmeldenCode.dc.html', anmelde_seite(code))
