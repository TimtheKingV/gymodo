# -*- coding: utf-8 -*-
from build import HEAD, FOOT, LABEL, PRIMARY, SECONDARY, schreibe, zurueck

NOTE = 'font-size: 12px; color: #5c636e; line-height: 1.4;'
CHIP = ('display: inline-flex; align-items: center; flex: 0 0 auto; padding: 8px 16px; '
        'border-radius: 999px; background: #1d2026; color: #9ba3af; font-weight: 600; '
        'font-size: 13px; white-space: nowrap;')
CHIP_AKTIV = CHIP.replace('color: #9ba3af;', 'color: #f2f4f7;') + ' box-shadow: inset 0 0 0 1px #d4ff3f;'
KAMERA_BTN = PRIMARY.replace('height: 44px;', 'height: 56px;') + ' width: 100%;'

# Der einzige Pfad, der auf dem Telefon tragen muss: die Aufnahme entsteht
# auf dem Trainerhandy und wird aus mobilem Safari hochgeladen (Spec 6.8).
# Deshalb steht hier die Uebungsliste mit dem laufenden Upload -- nicht der
# ganze Katalogeditor auf 390 px gequetscht.
telefon = HEAD + """
<div style="min-height: 1240px; background: #0a0b0d;">

  <div style="border-bottom: 1px solid #2a2e36; background: #14161a; padding: 16px 0;">
    <div style="padding: 0 16px 12px;">
      <div style="font-size: 15px; font-weight: 800; letter-spacing: -0.02em; text-transform: uppercase;">Kraftwerk Nord</div>
    </div>
    <div style="display: flex; gap: 8px; overflow-x: auto; padding: 0 16px;">
      <span style="%(chip)s">Überblick</span>
      <span style="%(chip)s">Kurse</span>
      <span style="%(aktiv)s">Geräte</span>
      <span style="%(chip)s">Tags</span>
      <span style="%(chip)s">Leute</span>
      <span style="%(chip)s">Einstellungen</span>
    </div>
  </div>

  <div style="padding: 20px 16px 40px;">
    <a href="#" style="%(label)s color: #5c636e;">%(zurueck)s</a>
    <h1 style="font-size: 28px; font-weight: 800; letter-spacing: -0.03em; text-transform: uppercase; margin: 8px 0 0;">Latzug</h1>
    <p style="color: #9ba3af; font-size: 13px; margin: 6px 0 0;">Technogym · Schritt 2,5 kg</p>

    <div style="display: flex; gap: 8px; overflow-x: auto; margin-top: 20px;">
      <span style="%(chip)s">Stammdaten</span>
      <span style="%(chip)s">Einstellungen</span>
      <span style="%(aktiv)s">Übungen</span>
      <span style="%(chip)s">Einzelne Geräte</span>
    </div>

    <div style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; margin-top: 20px; padding: 16px; display: flex; flex-direction: column; gap: 12px;">
      <div>
        <div style="font-size: 16px; font-weight: 600;">1. Latzug breit</div>
        <div style="font-size: 12px; color: #9ba3af; margin-top: 2px;">8–12 Wiederholungen · Video 28 s</div>
      </div>
      <a href="#" style="%(sec)s width: 100%%; height: 48px;">Video ersetzen</a>
    </div>

    <div style="border: 1px solid #2a2e36; border-radius: 12px; background: #14161a; margin-top: 16px; padding: 16px; display: flex; flex-direction: column; gap: 12px;">
      <div>
        <div style="font-size: 16px; font-weight: 600;">2. Latzug eng</div>
        <div style="font-size: 12px; color: #9ba3af; margin-top: 2px;">8–12 Wiederholungen</div>
      </div>

      <div style="display: flex; flex-direction: column; gap: 8px;">
        <div style="display: flex; align-items: baseline; justify-content: space-between;">
          <span style="%(label)s color: #9ba3af;">Wird übertragen</span>
          <span style="font-size: 13px; font-weight: 700; color: #f2f4f7;">62 %%</span>
        </div>
        <div style="height: 6px; border-radius: 999px; background: #1d2026; overflow: hidden;">
          <div style="width: 62%%; height: 100%%; background: #d4ff3f;"></div>
        </div>
        <span style="%(note)s">Bricht die Verbindung ab, setzt der nächste Versuch hier fort — er fängt nicht von vorn an.</span>
      </div>
    </div>

    <div style="border: 1px dashed #2a2e36; border-radius: 12px; background: #0f1114; margin-top: 16px; padding: 16px; display: flex; flex-direction: column; gap: 12px;">
      <div style="display: flex; align-items: center; gap: 12px;">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#5c636e" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M23 7l-7 5 7 5V7z"></path><rect x="1" y="5" width="15" height="14" rx="2"></rect></svg>
        <div style="min-width: 0;">
          <div style="font-weight: 600;">Video aufnehmen</div>
          <div style="%(note)s margin-top: 2px;">Höchstens 45 Sekunden. Die Länge wird an der Datei geprüft, nicht geschätzt.</div>
        </div>
      </div>
      <a href="#" style="%(kamera)s">Kamera öffnen</a>
    </div>

    <p style="%(note)s margin: 24px 0 0;">Ein Gerät ohne Video ist vollständig nutzbar. Du musst das hier nicht fertig machen.</p>
  </div>
</div>
""" % {'chip': CHIP, 'aktiv': CHIP_AKTIV, 'label': LABEL, 'sec': SECONDARY,
       'note': NOTE, 'kamera': KAMERA_BTN,
       'zurueck': zurueck('Geräte')} + FOOT
schreibe('Telefon.dc.html', telefon)
