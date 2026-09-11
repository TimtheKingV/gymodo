# Satzpfad am Gerät — Feinschliff, und was manuell abzunehmen bleibt

Sieben Änderungen am Geräte-Screen, alle aus dem Betrieb heraus gemeldet.
`xcodebuild test` beweist die Ableitungen (420 iOS-Tests in 57 Suiten, grün);
es beweist nichts über das, was auf dem Bildschirm passiert. Die
Abnahmeschritte unten sind deshalb der eigentliche Beweis.

## Was sich geändert hat

1. **Die Rastmarke unterstreicht.** `RastRad.unterstreichung` lag exakt auf der
   vertikalen Mitte der gewählten Zeile und strich damit durch die Ziffern.
   Sie sitzt jetzt eine halbe `UIFont.capHeight` plus `s8` darunter — aus der
   Schriftgröße gerechnet, weil dasselbe Rad in 64 pt (Gewicht) und 44 pt
   (Wiederholungen) läuft.
2. **Das Gewicht wird nicht mehr gekürzt.** `100,5` wurde zu `1…`: 64 pt Black
   monospaced brauchen ~172 pt, die hälftig geteilte Spalte bot ~135. Die
   Wiederholungsspalte bekommt jetzt eine feste (skalierende) Breite von 112 pt
   — sie ist strukturell zweistellig (`Rastwerte.wiederholungen` = 1…40) —, das
   Gewicht den Rest. `lineLimit(1) + minimumScaleFactor(0.6)` fängt die
   Restfälle ab (Gerät ohne Obergrenze, große Dynamic-Type-Stufen).
3. **„Maximum des Geräts erreicht" ist aus der Kontextzeile raus.** Der Satz
   verdrängte Schritt und Bereich genau dort, wo man sie beim Scrollen braucht.
   Der Anschlag bleibt hörbar (`RastRad.voWertMitAnschlag`) und spürbar
   (`anschlagStoss`); sichtbar trägt ihn die Bereichsangabe derselben Zeile.
4. **Die Reserve (RIR) ist ganz gefallen** — Eingabe, Profilschalter und die
   Anzeige im Verlauf. Wie viele Wiederholungen jemand geschafft hat, steht
   schon im zweiten Rad. `workout_sets.rir` bleibt nullable und trägt Altdaten;
   neue Sätze schreiben `null`.
5. **Die Pause ist ein Zustand, kein Band.** `GeraetModel.Phase` ersetzt
   `pause: Resttimer?`. Während `.pause` zeigt der Screen nur Gerät, Übung und
   das Rad — vorher konnte man mitten in der Pause das Gewicht verstellen und
   den nächsten Satz sichern, was den eben gestarteten Timer sofort neu
   startete. Die Pause beendet sich jetzt auch selbst (`.task(id:)` in
   `GeraetView`); vorher blieb sie auf `00:00` stehen.
6. **„Gerät abschließen"** steht als Sekundäraktion direkt unter „Satz N
   sichern" und ersetzt das kleingesetzte „← Zurück zum Training". Dieselbe
   Navigation, der Name, den der Moment verdient. Geschrieben wird nichts
   Zusätzliches — die Sätze des Blocks liegen bereits in der Session, und die
   Einheit endet weiterhin nur über „Training beenden".
7. **Nach dem Satzziel keine Pause, sondern die Entscheidung**
   „Gerät abschließen" / „Weiterer Satz". Das Ziel steht im Profil
   (`Einstellungen.satzZiel`, Vorgabe 3, Stufen 2–5) und gilt je Gerät und
   Übung. Es gibt keinen Trainingsplan in den Daten — `exercises` kennt nur
   einen Wiederholungskorridor —, und eine Vorgabe, die das Mitglied selbst
   verschiebt, ist ehrlicher als eine erfundene Zahl vom Server.

Neu: `DesignSystem/Components/PausenRad.swift`.
Entfallen: `Screens/Geraet/ResttimerBalken.swift`.
Nachgezogen: `docs/superpowers/specs/2026-08-30-designsystem.md` §§6, 7, 9.

## Bewusste Abweichungen

- **§6 „Haptik nie als einzige Rückmeldung":** am Anschlag bleibt sichtbar nur,
  dass das Rad stehenbleibt, plus die Bereichsangabe `5,0 – 100,0` in der Zeile
  darunter. Der eigene Grenzsatz ist gefallen (Punkt 3).
- **Während der Pause bleiben die Statusbänder stehen** (`OfflineLeiste`,
  `WarteschlangeKarte`, `AbgelehnteKarte`), obwohl der Zustand sonst
  ausschließend ist. Es sind bedingte Bänder, die meist gar nicht da sind;
  einen abgelehnten Schreibvorgang 90 Sekunden zu verstecken wäre die
  schlechtere Entscheidung.
- **Die Progression wird konservativer.** `packages/domain/src/progression.ts`
  nutzte `rir >= 1` als schnellen Pfad zur Steigerung. Ohne RIR greift nur noch
  der Fallback: gesteigert wird erst, wenn zweimal hintereinander das obere Ende
  des Korridors erreicht ist. Kein Code-Change nötig, `rir === null` ist dort
  bereits der behandelte Fall — aber es ist eine Verhaltensänderung.

## Manuelle Abnahme

Training-Tab → Gerät wählen → Übung.

- [ ] Rad öffnen: die Linie steht **unter** der Zahl, in beiden Rädern.
      Gegenprobe mit einstelligen und vierstelligen Werten.
- [ ] Auf `100,5` scrollen: vollständig lesbar, nicht `1…`. Gegenprobe auf
      iPhone SE und mit Dynamic Type XXL.
- [ ] Gerät ohne `max_weight_kg`: `1005,0` skaliert, statt zu kürzen.
- [ ] Ans Maximum scrollen: die Kontextzeile bleibt „Schritt 2,5 kg · 5,0 –
      100,0". VoiceOver sagt weiterhin „… Maximum des Geräts erreicht", die
      Haptik klopft.
- [ ] Keine Reserve-Zeile mehr; kein RIR-Schalter im Profil; ein Altsatz mit
      RIR im Verlauf zeigt ihn nicht mehr an.
- [ ] „Satz 1 sichern": nur noch Gerät/Übung und das Pausenrad. Der Bogen
      füllt sich, die Ziffern zählen runter.
- [ ] „+30 s" verlängert, ohne dass der Bogen bei voll klebt. „Weiter" bringt
      die Räder sofort zurück; ohne Tap kommen sie beim Ablauf von selbst.
- [ ] App in den Hintergrund und zurück, während die Pause läuft: der Countdown
      stimmt weiter (der Timer hält einen Endzeitpunkt, keinen Zähler).
- [ ] Reduce Motion an: der Bogen springt sekundenweise, die Zahl bleibt.
- [ ] Profil → „Sätze pro Gerät" auf 3. Sätze 1 und 2 → Pause. Satz 3 → keine
      Pause, sondern „Gerät abschließen" / „Weiterer Satz".
- [ ] „Weiterer Satz" → Pause → Räder → Satz 4 → dieselbe Entscheidung.
- [ ] Übung wechseln direkt nach einem Satz: die Pause der alten Übung gilt
      für die neue nicht.
- [ ] „Gerät abschließen" landet auf der Trainingsübersicht, der Block steht
      dort mit der richtigen Satzanzahl, „Training beenden" funktioniert
      unverändert.
- [ ] Offline einen Satz sichern: das Warteschlangen-Band bleibt auch während
      der Pause sichtbar.
