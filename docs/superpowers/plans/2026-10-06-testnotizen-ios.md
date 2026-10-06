# Testnotizen 06.10. — Member-App (iOS)

**Quelle:** Testsitzung 2026-10-06 11:18, iPhone14,4 (375 × 812 pt), iOS 26.6.2,
Debug-Build, Stand 2e814b0 (master nach PR #38). 20 Einträge zu Home,
Training-Tab, Gerät erkannt, Satzpfad, Erstkontakt, Abschluss und
Trainingsdetail.
**Vorgehen:** testgetrieben. Je Etappe zuerst ein roter Swift-Testing-Test an
einer Reinfunktion oder am Modell, dann die Umsetzung. Reine Layout- und
Farbänderungen haben keinen Test, die Begründung steht jeweils dabei.
**Rückfragen (beantwortet):**
- #5/#18: Die Uhr startet bei einem neuen Gerät erst nach der Einstellung.
  Die Reihenfolge ist Erkannt → Einweisung → „Einstellung speichern“ →
  „Training starten“ (nur ohne laufendes Training) → Satzseite. Schritt 3
  („Erste Werte“) fällt weg.
- #16: „Kenne ich schon“ überspringt Einweisung **und** Einstellung.
- #12: Der Drawer nach „Übung abschließen“ erscheint immer, wenn das Gerät
  mehrere Übungen hat. Die Übungsliste zeigt bei schon gemachten Übungen
  die Sätze dieser Einheit, wie die Blockliste im laufenden Training.
- #20: Der Gesamttrend vergleicht das Gesamtvolumen (Summe kg × Wdh.) mit
  dessen Durchschnitt aus den bis zu fünf vorherigen Trainings.
- #19: Statt „Kein Vorschlag“ steht der Grund.
- #1: Auch Wartelistenplätze bekommen einen Punkt auf Home, im Gelb der
  Warteliste.

---

## Etappe 1 · Auswahl-Einstellungen in der Kalibrierung (Notiz #17)

**Ursache:** Die App kannte nur Zahlen-Parameter. `SettingDefinition.kind`
und `allowedValues` wurden dekodiert, aber nie gelesen. Jede Auswahl
(Griffposition: eng / weit / neutral) bekam ein ±-Rad von 0 bis 99. Der
Entwurf war `[String: Double]` und ging als Zahl an den Server.
`pruefeEinstellwerte` (calibration.ts) lehnt bei `kind = enum` jede Zahl ab:
„Griffposition erwartet eine Auswahl, keinen Zahlenwert.“ Das passierte bei
jedem Speichern, egal was gewählt war.

- `SettingDefinition.auswahlwerte` ist der eine Ort, der „Auswahl oder
  Zahl“ unterscheidet.
- `GeraetModel.entwurfAuswahl: [String: String]` liegt neben dem
  Zahlenentwurf. `kalibrierungVorbereiten()` übernimmt einen bisherigen
  Text, wenn er noch erlaubt ist, sonst den ersten erlaubten Wert.
  `kalibrierungSichern()` sendet Auswahlen als `.string`.
- `KalibrierungSchritt` zeigt Auswahlen als Chips auf einer Karte
  (`AuswahlKarte`).
- Tests (rot zuerst, `GeraetModelTests`): Vorbelegung mit dem ersten Wert,
  bisherige Auswahl übernommen, gestrichener Wert verworfen, Senden als
  Text.

## Etappe 2 · Erstkontakt neu (Notizen #5, #6, #8, #15, #16, #18)

**#5 Ursache:** „Training starten“ kam vor dem Erstkontakt. Die Uhr lief
deshalb schon während Einweisung und Einstellung.
**#8/#18 Ursache:** Schritt 3 „Erste Werte“ war eine zweite Satzseite ohne
Sensor. Einstellung und Satz sind in der Datenbank nicht verbunden
(eigene Endpunkte und Tabellen), der Schritt war also unnötig.
**#16 Ursache:** „Kenne ich schon“ rief denselben `beiWeiter` auf wie die
Hauptaktion.

- `ErstkontaktSchritt`: `.ersteWerte` ersetzt durch `.trainingStarten`.
  `erstkontaktSchritte(hatEinstellparameter:trainingLaeuft:)` hängt den
  Start nur ohne laufendes Training an.
  `positionNachUeberspringen(in:)` springt zu „Training starten“ oder
  beendet den Erstkontakt.
- `GeraetEinstiegRechner.brauchtErstkontakt(...)` ist eine Regel für
  `GeraetModel.istErstkontakt` und für `TrainingRootView`.
  `TrainingStart.ziel(... erstkontakt:)` führt beim Erstkontakt direkt zum
  Satzpfad. Dort steht der Erstkontakt als fullScreenCover, „Training
  starten“ ist sein letzter Schritt (`TrainingStartView` mit eigener
  Schrittzeile).
- `ErsteWerteSchritt.swift` ist entfernt. Der erste Satz läuft auf der
  Satzseite, mit Sensor (DEBUG) und denselben Knöpfen.
- „Speichern und weiter“ heißt „Einstellung speichern“ (#18).
- #6/#15: Die Knöpfe von Einweisung und Einstellung stehen unten bündig
  (`safeAreaInset`, wie auf „Training starten“). Ohne Einstellparameter
  heißt die Hauptaktion „Weiter“, und „Kenne ich schon“ entfällt (er wäre
  dasselbe).
- Der Erklärtext auf „Training starten“ sagt nicht mehr „auch während
  Einweisung und Einstellung“.
- Tests (rot zuerst): `GeraetEinstiegTests` (Schrittlisten in vier
  Kombinationen, Überspringen, `brauchtErstkontakt`) und
  `TrainingStartTests` (Erstkontakt ohne Training führt zum Satzpfad).

## Etappe 3 · Satzseite und Übungslisten (Notizen #3, #7, #9, #10, #11, #12)

- #10: „Gerät abschließen“ heißt auf Satzseite, Pause und Abschluss
  „Übung abschließen“.
- #11: „andere Übung“ ist weg.
- #12: „Übung abschließen“ öffnet bei mehr als einer Übung am Gerät einen
  Drawer (`UebungAbschliessenSheet`, Detent 280 pt) mit „Weitere Übung an
  dem Gerät“ (öffnet die Übungsliste) und „Gerät abschließen“. Sonst geht
  es wie bisher zurück zur Liste. Zwei Sheets nacheinander laufen über
  `onDismiss`.
- `UebungWechselnSheet` heißt „Weitere Übung“. Schon gemachte Übungen
  zeigen „Heute · 2 Sätze · 7,5 kg“ (`GeraetModel.blockInEinheit`).
- #7: In der Pause steht „Weiter“ unten, darüber „+30 s“ und „Übung
  abschließen“. So bleibt der Daumen dort, wo „Satz sichern“ war.
- #3/#9: Kein Akzentbalken und keine hellere Fläche mehr in den
  Übungslisten (Gerät erkannt, Weitere Übung). Links steht der neue
  Platzhalter `Uebungsbild` (56 pt) für ein späteres Bild oder GIF.
- Tests (rot zuerst, `GeraetModelTests`): `abschlussFragtNach` bei einer
  und zwei Übungen, `blockInEinheit` nur für dieses Gerät.

## Etappe 4 · Training-Tab (Notizen #2, #4, #13, #14)

- #2/#13: Die Wurzel des Tabs ist „Gerät wählen“ (`GeraeteAuswahlView`, ab
  iOS 26 mit Systemsuche und einklappendem Titel). Der Knopf „Suchen“ ist
  weg.
- QR-Code und NFC stehen nebeneinander und schweben über der Liste
  (`safeAreaInset`): Akzentfläche mit Schatten (`ScanWege`).
- Läuft ein Training, stehen über den Geräten Uhr, Pausenknopf und die schon
  gemachten Übungen, darunter „NÄCHSTES GERÄT“. Dafür ist
  `GeraeteAuswahlView` generisch über einen `kopfinhalt`. Ohne Prefetch
  oder Studio bleibt der alte Titel „TRAINING“ mit den Scanwegen.
- #14: Die Blockzeilen haben links den Übungsplatzhalter (48 pt).
- #4: „Pausieren / Training beenden“ ist ein Drawer statt eines
  Aktionsblatts (`TrainingSteuerungSheet`, Detent 300 pt). Er gilt auf dem
  Tab und an der Uhr im Satzpfad.
- Kein Test: Das ist Aufbau und Verdrahtung. Die Regeln dahinter
  (`TrainingTab`, `GeraeteAuswahl`) sind schon geprüft.

## Etappe 5 · Kurse auf Home (Notiz #1)

- `HomeKurse.termineJeTag` und `HomeKurse.punkt`: Es zählen bestätigte
  Plätze und Wartelistenplätze, nicht abgesagt und noch nicht begonnen.
  Grün geht vor Gelb.
- `HomeSerieView`: ein 5-pt-Punkt unter jedem Tag des Wochenstreifens. Ein
  Tag mit eigenem Kurs ist antippbar und zeigt unter den Trainings
  `KurseBandView`, dieselbe Karte wie auf der Kurse-Seite, mit „Abmelden“
  und Rückfrage. Ein Tipp auf die Karte öffnet `KursDetailView` (neue
  `HomeRoute.kursDetail`).
- `HomeRootView` lädt die Kurse selbst (`kurseLaden`), im selben Fenster wie
  der Kurse-Tab. Gezeigt werden nur Buchungen des aktiven Studios.
- Tests (rot zuerst, `HomeKurseTests`): Zuordnung je Tag, Abgesagtes und
  Vergangenes fallen weg, Grün vor Gelb, Gelb nur bei Warteliste, ohne
  Termin kein Punkt.

## Etappe 6 · Grund statt „Kein Vorschlag“ (Notiz #19)

**Antwort auf die Frage:** Der Server rechnet die Vorschläge beim Abschluss
aus den letzten zwei Trainingstagen der Übung
(packages/domain/src/progression.ts):
- Haben an beiden Tagen bei gleichem Gewicht alle Sätze das obere Ziel
  erreicht, kommt eine Gewichtsstufe mehr.
- Hat an beiden Tagen schon der erste Satz das untere Ziel verfehlt, kommt
  eine Stufe weniger.
- Sonst heißt es „Gewicht halten“.

- `VorschlagsAnzeige.ohne(OhneGrund)` steht für `kein_verlauf`,
  `daten_uneindeutig`, `problem_gemeldet` und `geraetegrenze_erreicht`.
  Rechts steht weiter „Kein Vorschlag“, links unter den Zahlen der Grund.
  VoiceOver liest beides.
- Ohne Vorschlagszeile (etwa bei automatisch beendeten Trainings oder
  wenn die Sätze den Server noch nicht erreicht haben) bleibt es bei
  „Kein Vorschlag“ ohne Grund.
- Tests (rot zuerst, `TrainingAbschlussZeilenTests`): vier Gründe mit Text
  und Vorlesetext, unbekannter Code ohne Grund.

## Etappe 7 · Fortschritt im Trainingsdetail (Notiz #20)

- `Satzvergleich.fuer(block:in:verlauf:)`:
  - Vergleicht je Position den Satz mit dem Durchschnitt derselben
    Position aus den bis zu fünf jüngeren vorherigen Trainings mit
    derselben Übung.
  - Liefert Δ kg, Δ Wdh. und den Pfeil nach kg × Wdh.
  - Gesamttrend: Summe kg × Wdh. gegen den Durchschnitt der Summen.
  - Nur kg und Wdh., Grundlage sind die geladenen 50 Einheiten.
  - Ein Satz ohne Gegenstück bekommt keinen Vergleich.
  - Bei Gleichstand gibt es keinen Pfeil.
- `SessionDetailView` zeigt:
  - rechts in jeder Satzzeile den Pfeil, „+2,5 kg  +2 Wdh.“;
  - rechts oben den Gesamttrend;
  - darunter „Verglichen mit dem Schnitt deiner letzten N Trainings dieser
    Übung.“
  - Nach oben in der Signalfarbe, nach unten gedeckt.
- Tests (rot zuerst, `SatzvergleichTests`):
  - das Beispiel aus der Notiz;
  - Volumen statt Gewicht (10 × 10 > 5 × 18);
  - höchstens fünf und nur frühere Trainings;
  - fehlendes Gegenstück;
  - Gesamttrend;
  - ohne Vorgänger, Cardio und andere Übung ergeben nil;
  - Texte mit Vorzeichen.

---

## Geprüft

- **Nicht gelaufen:** Xcode-Build und iOS-Tests. Die Cloud-Session hat keinen
  Mac, und download.swift.org ist für den Proxy gesperrt. Es gibt also auch
  keinen Linux-Compiler für eine Syntaxprüfung. Die CI baut nur das
  Web-Projekt. Die Tests oben sind geschrieben, aber nicht ausgeführt, also
  auch nicht rot gesehen.
- Den Diff hat ein zweiter Agent als „Compiler“ gegengelesen: Signaturen,
  Aufrufer geänderter Inits, Result-Builder, Testerwartungen von Hand
  nachgerechnet. Seine Funde sind eingearbeitet.
- **Vor dem Merge am Mac:** `xcodegen generate` (neue Dateien: HomeKurse,
  Satzvergleich, zwei Testdateien; ErsteWerteSchritt entfernt), dann alle
  Tests im Simulator.

### Am Gerät ansehen

- Training-Tab: Liste als Wurzel, Titel klappt ein, Lupe oben rechts (iOS
  26). QR/NFC schweben über dem letzten Gerät, ohne es zu verdecken. Im
  laufenden Training stehen Uhr und Blöcke über der Liste.
- Neues Gerät ohne Training: Einweisung → Einstellung → Training starten →
  Satzseite, und die Uhr beginnt erst mit dem Tipp. Mit laufendem Training
  ohne Startschritt. „Kenne ich schon“ springt direkt zum Start.
- Kabelzug mit drei Parametern: Griffposition als Chips, Speichern geht
  durch.
- „Übung abschließen“ mit zwei Übungen: Drawer, dann „Weitere Übung“ mit
  „Heute · 2 Sätze · …“. Der zweite Sheet muss nach dem ersten erscheinen.
- Drawer „Training läuft“ auf Tab und Satzpfad.
- Home: Punkt unter dem Kurstag (grün oder gelb), Tipp zeigt die Karte mit
  Abmelden. Die Zellenhöhe wächst um 11 pt.
- Abschluss: Grund unter „Kein Vorschlag“.
- Trainingsdetail: Platz der Vergleichszeile auf 375 pt.

## Offen

- Übungsbilder: Es gibt noch kein Feld dafür (`exercises` hat keine
  Medienspalte). Für Bilder oder GIFs braucht es eine Migration, den Upload
  im Trainerportal und das Feld im Bootstrap. Bis dahin steht überall der
  Platzhalter.
- Die Monatsansicht auf Home zeigt keine Kurspunkte. Das Ladefenster reicht
  nur bis heute + 14 Tage.
