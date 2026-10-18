# Fortschritt nach Muskelgruppen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auf Home gibt es im Übungsfortschritt einen Toggle „Muskelgruppen | Übungen“; „Muskelgruppen“ zeigt Ausgewogenheit, eingefärbte Körperfigur und Gruppenliste, ein Tipp auf eine Gruppe öffnet das Detail mit Teilmuskeln.

**Architecture:** Reine, getestete Berechnung (`Muskelauswertung/`) aus `VerlaufStore.sessions`, `VerlaufStore.fortschritt` und den Muskeln je Übung (`HomeZeilen.muskelnJeUebung`). Die Figur `MuskelFigur` bekommt freie Farben je Muskel. Zwei neue Views hängen an `HomeRootView` und `HomeRoute`. Kein Server- und kein Datenbankcode.

**Tech Stack:** Swift 6, SwiftUI (Canvas), Swift Testing (`@Test`, `#expect`), XcodeGen (`project.yml`, `FitnessMember.xcodeproj/project.pbxproj` ist eingecheckt).

**Spec:** `docs/superpowers/specs/2026-10-17-muskelgruppen-fortschritt-design.md`

## Global Constraints

- Nur `apps/ios-member`. Kein Code in `apps/web`, `packages/`, `supabase/`.
- Neue Dateien in `FitnessMember/` oder `FitnessMemberTests/` verlangen `cd apps/ios-member && xcodegen generate`; die geänderte `project.pbxproj` gehört in denselben Commit wie die neuen Dateien.
- Tests: `cd apps/ios-member && xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FitnessMemberTests/<Suite>`.
- Sprache der Oberfläche und Kommentare: Deutsch, Dateien und Bezeichner wie im Bestand ohne Umlaute im Code (`ruecken`, `Haeufigkeit`).
- Fenster: Trainingshäufigkeit **28 Tage**, Fortschritt **3 Monate** (`Fortschrittsfenster.dreiMonate`, 92 Tage).
- Gruppen und Reihenfolge: `MuskelHauptgruppe` (nur `.brust, .ruecken, .schultern, .arme, .beine, .rumpf`; `.weitere` und `.mehrere` zählen nie).
- Seltene Muskeln, die nie Hinweis auslösen: `erectors`, `adductors`, `abductors`, `rotator_cuff`.
- „Zu wenig“ = unter 0,5 × Mittel; „viel“ = über 1,5 × Mittel; null Einheiten bei vorhandener Datenreife = Nachholbedarf. „Stabil“ = Fortschritt zwischen −3 % und +3 %.
- Datenreife: Häufigkeit ab mindestens 3 Einheiten im 28-Tage-Fenster; Fortschritt je Übung nur mit mindestens 2 Messpunkten im Abstand von mindestens 14 Tagen.
- Farben nur aus `DesignSystem.Color`: Nachholbedarf `warn`, ok `accentPressed`, viel `accent`, keine Auswertung / kaum Übungen `muskelInaktiv`. **Kein neuer Farbwert** (Spec nennt `#E8A33D`; das vorhandene `warn` `#FFB020` ersetzt ihn – Abweichung bewusst).
- Texte exakt wie in den Tests unten. Ruhiger Ton, kein Rot, kein Ausrufezeichen.

## Review Focus

- Nutzer ohne Einheiten im Fenster oder ohne Verlauf: alles grau, Satz „Für die Analyse braucht es noch ein paar Trainings.“, kein Absturz, keine Division durch null.
- Einheit mit Cardio-Block (Satz ohne `load`, Übung ohne Muskeln im Katalog): zählt nirgends und bricht nichts.
- Übung aus `sessions`, die der Bootstrap nicht kennt (stillgelegtes Gerät, Offline-Bootstrap, `muskelnJeUebung` leer): wird übersprungen.
- `startedAt` nicht parsebar: Einheit wird übersprungen.
- Eine Gruppe, in der nur seltene Muskeln trainiert wurden (z. B. Rücken nur mit `erectors`): Gruppe zählt die Einheit, aber kein Teilmuskel-Hinweis auf seltene Muskeln.
- Fortschritt mit Startlast 0 oder Übung nur im Zeitraum von einem Tag: `nil`, nie „Infinity“ oder „NaN“.
- Geschlecht unbekannt (`nil`): Figur nimmt das männliche Modell, wie `MuskelFigur` es schon tut.

---

### Task 1: Trainingshäufigkeit

**Files:**
- Create: `FitnessMember/Muskelauswertung/Haeufigkeit.swift`
- Test: `FitnessMemberTests/HaeufigkeitTests.swift`

**Interfaces:**
- Produces:
  - `struct Haeufigkeit: Equatable { let einheiten: Int; let jeMuskel: [String: Int]; let jeGruppe: [MuskelHauptgruppe: Int]; var istAuswertbar: Bool }` – `einheiten` = Einheiten im Fenster, `istAuswertbar` = `einheiten >= 3`.
  - `extension Haeufigkeit { static func berechne(sessions: [SessionSummary], muskeln: [String: [GeraetMuskel]], jetzt: Date) -> Haeufigkeit }`
  - `extension MuskelHauptgruppe { static let angezeigt: [MuskelHauptgruppe]; var muskelSchluessel: [String] }` – `angezeigt` = die sechs Gruppen in Reihenfolge; `muskelSchluessel` macht das bisher `fileprivate` `muskeln` aus `UebungsGruppierung.swift` für alle sichtbar (umbenennen, Aufrufer anpassen).

- [ ] **Step 1: Failing tests schreiben** in `HaeufigkeitTests`. Hilfsfunktionen bauen `SessionSummary` (ein Block je Übung, `startedAt` als ISO-8601-String, `Zeitpunkt.parse` ist das Parsergegenstück). Testnamen und Erwartungen:
  - `hauptmuskelZaehltEineEinheitPoSession`: zwei Sätze „bank“ (Hauptmuskel `pectorals`) in einer Einheit → `jeMuskel["pectorals"] == 1`, `jeGruppe[.brust] == 1`.
  - `unterstuetzenderMuskelBrauchtZweiSaetze`: ein Satz Übung mit `triceps` secondary → `jeMuskel["triceps"] == nil`; zwei Sätze (auch über zwei Blöcke derselben Einheit) → `1`.
  - `gruppeZaehltDieEinheitEinmalAuchBeiMehrerenMuskeln`: eine Einheit mit `lats` und `upper_back` primär → `jeGruppe[.ruecken] == 1`, `jeMuskel["lats"] == 1`, `jeMuskel["upper_back"] == 1`.
  - `nurDieLetzten28TageZaehlen`: Einheit vor 27 Tagen zählt, vor 29 Tagen nicht.
  - `cardioUndUnbekannteUebungenZaehlenNicht`: Block mit `exerciseId` ohne Eintrag in `muskeln` → keine Spuren, `einheiten` zählt die Einheit trotzdem mit (sie ist Training).
  - `unlesbaresDatumWirdUebersprungen`: `startedAt: "kaputt"` → `einheiten == 0`.
  - `auswertbarAbDreiEinheiten`: zwei Einheiten → `istAuswertbar == false`, drei → `true`.
  - `seltenerMuskelSchluesselUnbekannterSchluesselZaehltNicht`: Muskel `deep_core` primär → in `jeMuskel` nicht enthalten.

- [ ] **Step 2: Fehlschlag prüfen:** `xcodegen generate` und Suite `HaeufigkeitTests` laufen; erwartet FAIL (Typ fehlt).

- [ ] **Step 3: Implementieren** `Haeufigkeit.berechne` in `Muskelauswertung/Haeufigkeit.swift` und `angezeigt`/`muskelSchluessel` in `UebungsGruppierung.swift` (Umbenennung, Verhalten unverändert). Ansatz: je Einheit im Fenster zwei Zähler (Hauptsätze, Nebensätze je Schlüssel) über alle Blöcke und Sätze, danach Regel „Haupt > 0 oder Neben ≥ 2“; Gruppenzählung über `muskelSchluessel`.

- [ ] **Step 4: Tests grün:** `HaeufigkeitTests` und `UebungsGruppierungTests` PASS.

- [ ] **Step 5: Commit**
```bash
git add apps/ios-member/FitnessMember apps/ios-member/FitnessMemberTests apps/ios-member/FitnessMember.xcodeproj
git commit -m "feat(ios): Trainingshäufigkeit je Muskel und Gruppe (28 Tage)"
```

---

### Task 2: Status, Ausgewogenheit, Hinweise

**Files:**
- Create: `FitnessMember/Muskelauswertung/Ausgewogenheit.swift`, `FitnessMember/Muskelauswertung/Hinweise.swift`
- Test: `FitnessMemberTests/AusgewogenheitTests.swift`, `FitnessMemberTests/MuskelHinweiseTests.swift`

**Interfaces:**
- Consumes: `Haeufigkeit`, `MuskelHauptgruppe.angezeigt`, `.muskelSchluessel` (Task 1).
- Produces:
  - `enum MuskelStatus: Equatable { case nachholbedarf, ok, viel, kaumUebungen, keineAuswertung }`
  - `enum Ausgewogenheit { static let seltene: Set<String>; static func prozent(_ h: Haeufigkeit) -> Int?; static func status(gruppe: MuskelHauptgruppe, in h: Haeufigkeit) -> MuskelStatus; static func status(muskel: String, gruppe: MuskelHauptgruppe, in h: Haeufigkeit) -> MuskelStatus }`
  - `enum MuskelHinweise { static func startsatz(_ h: Haeufigkeit) -> String; static func gruppenhinweis(gruppe: MuskelHauptgruppe, in h: Haeufigkeit, namen: [String: String]) -> String? }`

- [ ] **Step 1: Failing tests schreiben.** `Haeufigkeit` wird direkt aus `einheiten`, `jeGruppe`, `jeMuskel` gebaut (Memberwise-Init). `AusgewogenheitTests`:
  - `prozentBeiGleichmaessigerVerteilung`: alle sechs Gruppen 6 → `100`.
  - `prozentBeiZweiVergessenenGruppen`: `[6,6,6,6,0,0]` → `33`.
  - `prozentBeiLeichterAbweichung`: `[8,6,6,4,6,6]` → `89`.
  - `prozentNilOhneDatenreife`: `einheiten == 2` → `nil`; Mittel 0 → `nil`.
  - `statusGruppe`: Mittel 6: Gruppe mit 2 → `.nachholbedarf`, mit 0 → `.nachholbedarf`, mit 6 → `.ok`, mit 10 → `.viel`; nicht auswertbar → `.keineAuswertung`.
  - `statusMuskelVergleichtMitDerEigenenGruppe`: Rücken `lats` 8, `upper_back` 2 (Mittel der nicht-seltenen Muskeln 5) → `upper_back == .nachholbedarf`, `lats == .ok`.
  - `seltenerMuskelIstKaumUebungen`: `erectors` mit 0 Einheiten → `.kaumUebungen`.

  `MuskelHinweiseTests`:
  - `startsatzOhneNachholbedarf`: „Du trainierst alle Gruppen ähnlich oft.“
  - `startsatzMitEinerGruppe`: „Rumpf kommt zu kurz.“
  - `startsatzMitZweiGruppen`: „Rumpf und Beine kommen zu kurz.“ (Reihenfolge: die geringste Zahl zuerst, bei Gleichstand die Gruppenreihenfolge, also Beine vor Rumpf bei Gleichstand: Test mit Rumpf 0 / Beine 1 erwartet „Rumpf und Beine …“, Test mit beiden 0 erwartet „Beine und Rumpf …“).
  - `startsatzMitDreiGruppenNenntNurDieZweiSchwaechsten`.
  - `startsatzNichtAuswertbar`: „Für die Analyse braucht es noch ein paar Trainings.“
  - `gruppenhinweisNenntSchwaechstenNichtSeltenenMuskel`: „Oberer Rücken kam in 28 Tagen 2× dran. Eine Übung dafür würde dein Training abrunden.“; bei 0: „Oberer Rücken kam in 28 Tagen nicht dran. Eine Übung dafür würde dein Training abrunden.“; Name aus `namen[key]`, fehlt er, der Schlüssel.
  - `gruppenhinweisNilWennNurSelteneMuskelFehlen`.

- [ ] **Step 2: Fehlschlag prüfen** (Suites rot).

- [ ] **Step 3: Implementieren.** Prozentformel: `max(0, 1 − Σ|cᵢ − m| / 6 / m)` über die sechs Gruppen, `m` = Mittel, gerundet auf ganze Prozent. Status-Schwellen nur aus den Global Constraints. Für Muskeln ist das Referenzmittel das Mittel der **nicht seltenen** Muskel-Schlüssel der Gruppe (fehlender Schlüssel = 0).

- [ ] **Step 4: Tests grün.**

- [ ] **Step 5: Commit** (`feat(ios): Ausgewogenheit, Status und Hinweistexte der Muskelgruppen`), mit `project.pbxproj`.

---

### Task 3: Fortschritt je Muskel und Gruppe

**Files:**
- Create: `FitnessMember/Muskelauswertung/MuskelFortschritt.swift`
- Test: `FitnessMemberTests/MuskelFortschrittTests.swift`

**Interfaces:**
- Consumes: `ExerciseProgress` (`points`, `performedOn`, `topLoad`), `Fortschrittsfenster.dreiMonate.punkte(_:jetzt:)`, `MuskelHauptgruppe.muskelSchluessel`.
- Produces:
  - `enum FortschrittsWert: Equatable { case wert(Int), stabil, keinWert }`
  - `struct MuskelFortschritt: Equatable { let jeMuskel: [String: Double]; let jeGruppe: [MuskelHauptgruppe: Double]; static func berechne(fortschritt: [ExerciseProgress], muskeln: [String: [GeraetMuskel]], jetzt: Date) -> MuskelFortschritt; static func anzeige(_ prozent: Double?) -> FortschrittsWert }`

- [ ] **Step 1: Failing tests.**
  - `uebungMitZweiMesspunktenImAbstand`: Punkte (Tag −90: 40, −80: 50, −20: 55, −2: 60) → Übung +20 % (Startwert = beste Last der ersten 30 Tage ab dem ersten Messpunkt, Endwert = beste Last der letzten 30 Tage bis `jetzt`); `jeMuskel["lats"] == 20` für Hauptmuskel `lats`.
  - `unterstuetzenderMuskelZaehltNicht`: Übung mit `triceps` secondary füllt `jeMuskel["triceps"]` nicht.
  - `mittelUeberMehrereUebungen`: +20 und +10 für denselben Hauptmuskel → `15`.
  - `gruppeIstDasMittelIhrerMuskelMitWert`: `lats` 20, `upper_back` 10, `erectors` ohne Wert → `jeGruppe[.ruecken] == 15`.
  - `zuKurzerAbstandOderEinPunktGibtKeinenWert`: Punkte nur 10 Tage auseinander → Muskel fehlt in `jeMuskel`.
  - `startlastNullGibtKeinenWert`.
  - `punkteAusserhalbDesFenstersZaehlenNicht`: Punkt vor 100 Tagen wird ignoriert.
  - `anzeige`: `nil` → `.keinWert`; `2.9` → `.stabil`; `-2.9` → `.stabil`; `-3.0` → `.wert(-3)`; `14.4` → `.wert(14)`; `3.0` → `.wert(3)`.

- [ ] **Step 2: Fehlschlag prüfen.**
- [ ] **Step 3: Implementieren** `berechne` (Prozent je Übung relativ zur Startlast, danach Mittel je Muskel, dann je Gruppe) und `anzeige` (Rundung `.rounded()`).
- [ ] **Step 4: Tests grün.**
- [ ] **Step 5: Commit** (`feat(ios): Fortschritt je Muskel und Gruppe aus dem Übungsverlauf`), mit `project.pbxproj`.

---

### Task 4: Figur mit freien Farben

**Files:**
- Modify: `FitnessMember/DesignSystem/Components/MuskelKarte.swift` (`MuskelFigur`, ab Zeile ~107), `FitnessMember/DesignSystem/Components/MuskelModell.swift`
- Create: `FitnessMember/Muskelauswertung/MuskelFarben.swift`
- Test: `FitnessMemberTests/MuskelFarbenTests.swift`

**Interfaces:**
- Consumes: `MuskelStatus` (Task 2).
- Produces:
  - `enum MuskelFarben { static func farbe(_ status: MuskelStatus) -> Color; static func farben(gruppe: MuskelHauptgruppe, h: Haeufigkeit, nurGruppe: Bool) -> [String: Color] }` – mit `nurGruppe`, wird jeder Muskel außerhalb der Gruppe `DesignSystem.Color.line`; sonst bekommt jeder Muskel seine Statusfarbe aus der eigenen Gruppe. Für die Startansicht: `static func farbenAlle(_ h: Haeufigkeit) -> [String: Color]`.
  - `MuskelFigur.init(farben: [String: Color], geschlecht: Geschlecht?, ansichten: Set<MuskelFigur.Ansicht> = [.vorne, .hinten])` und `enum MuskelFigur.Ansicht { case vorne, hinten }`. Der bestehende Init `MuskelFigur(muskeln:geschlecht:)` bleibt und berechnet `farben` wie bisher (Aufrufer unverändert).
  - `extension MuskelHauptgruppe { var detailAnsichten: Set<MuskelFigur.Ansicht> }`

- [ ] **Step 1: Failing tests.**
  - `farbeJeStatus`: `.nachholbedarf == DesignSystem.Color.warn`, `.ok == accentPressed`, `.viel == accent`, `.kaumUebungen == muskelInaktiv`, `.keineAuswertung == muskelInaktiv`.
  - `detailZeigtNurDieGruppeHervorgehoben`: `farben(gruppe: .ruecken, …, nurGruppe: true)["pectorals"] == DesignSystem.Color.line` und `["lats"]` ist Statusfarbe.
  - `detailAnsichten`: Rücken `[.hinten]`; Brust, Rumpf `[.vorne]`; Schultern, Arme, Beine `[.vorne, .hinten]`.
  - `bestehendeKarteBleibtGleich`: `MuskelModell.fuellung(fuer:in:)` unverändert (der vorhandene Test in `MuskelModellTests` läuft weiter grün).

- [ ] **Step 2: Fehlschlag prüfen.**
- [ ] **Step 3: Implementieren.** `zeichne` bleibt unverändert, nimmt `farben`; `MuskelFigur` speichert `farben` und `ansichten` statt `muskeln`, berechnet Breite und Versatz nur für die gewählten Ansichten (bei einer Ansicht kein Abstand). Seitenverhältnis weiter nur vom Modell abhängig, nicht von den Farben.
- [ ] **Step 4: Tests grün,** dazu `MuskelModellTests` und die Vorschau „Brustpresse“ in `MuskelKarte.swift` im Simulator ansehen: sieht aus wie vorher.
- [ ] **Step 5: Commit** (`feat(ios): Muskelfigur mit freien Farben und wählbaren Ansichten`), mit `project.pbxproj`.

---

### Task 5: Toggle, Startansicht, Detail

**Files:**
- Create: `FitnessMember/Screens/Home/MuskelgruppenUebersichtView.swift`, `FitnessMember/Screens/Home/MuskelgruppeDetailView.swift`, `FitnessMember/Muskelauswertung/MuskelAuswertung.swift`
- Modify: `FitnessMember/Navigation/HomeRoute.swift`, `FitnessMember/Screens/Home/HomeRootView.swift` (`var fortschritt`, Zeilen ~326–355 und Route-Switch ~159), `FitnessMember/Einstellungen.swift`
- Test: `FitnessMemberTests/MuskelAuswertungTests.swift`, `FitnessMemberTests/EinstellungenTests.swift` (erweitern)

**Interfaces:**
- Consumes: `Haeufigkeit`, `MuskelFortschritt`, `Ausgewogenheit`, `MuskelHinweise`, `MuskelFarben`, `MuskelFigur`.
- Produces:
  - `struct MuskelAuswertung: Equatable { let haeufigkeit: Haeufigkeit; let fortschritt: MuskelFortschritt; static func berechne(sessions:fortschritt:muskeln:jetzt:) -> MuskelAuswertung }` – fasst Task 1 und 3 zusammen, damit Views nur diese Struktur kennen.
  - `enum Fortschrittsansicht: String, CaseIterable { case muskelgruppen, uebungen }`; `Einstellungen.fortschrittsansichtKey = "fortschrittsansicht"`; `Einstellungen.fortschrittsansicht(_ defaults: UserDefaults = .standard) -> Fortschrittsansicht` (Vorgabe `.muskelgruppen`, unbekannter Wert fällt darauf zurück, wie `uebungsansicht`).
  - `HomeRoute.muskelgruppe(MuskelHauptgruppe)`.

- [ ] **Step 1: Failing tests.**
  - `MuskelAuswertungTests.berechneVerbindetHaeufigkeitUndFortschritt`: ein Fixture mit drei Einheiten und einer Übung ergibt `haeufigkeit.istAuswertbar == true` und `fortschritt.jeGruppe[.ruecken] != nil`.
  - `MuskelAuswertungTests.leererVerlaufIstNichtAuswertbar`: `sessions: []`, `fortschritt: []` → `haeufigkeit.istAuswertbar == false`, `fortschritt.jeGruppe.isEmpty`.
  - `EinstellungenTests`: `fortschrittsansichtKey == "fortschrittsansicht"`; Vorgabe `.muskelgruppen`; gespeichertes `"uebungen"` → `.uebungen`; Unsinn → `.muskelgruppen` (eigene `UserDefaults(suiteName:)` wie in den bestehenden Tests).

- [ ] **Step 2: Fehlschlag prüfen.**
- [ ] **Step 3: Logik + Einstellung implementieren** (`MuskelAuswertung.berechne`, `Fortschrittsansicht`, Schlüssel), Tests grün.
- [ ] **Step 4: Toggle** in `HomeRootView.fortschritt`: großer Zweier-Schalter über der Überschrift „Muskelgruppen | Übungen“ (Optik: Entwurf A, Kapsel in `surface`, aktive Hälfte `accent` mit `onAccent`-Text; Vorbild für Pillen: `UebungsAnsichtSchalter.swift`), Wahl über `@AppStorage(Einstellungen.fortschrittsansichtKey)`. Die Zweige: `.uebungen` = der bisherige Inhalt der Variable unverändert (inklusive `GruppenLeiste`), `.muskelgruppen` = `MuskelgruppenUebersichtView`.
- [ ] **Step 5: `MuskelgruppenUebersichtView`** (Parameter: `auswertung: MuskelAuswertung`, `geschlecht: Geschlecht?`, `onGruppe: (MuskelHauptgruppe) -> Void`). Von oben: Karte „AUSGEWOGENHEIT“ mit Prozentzahl (`DesignSystem.Typography.wertHeld` nur falls passend, sonst `wertSekundaer`) und `MuskelHinweise.startsatz`; Karte mit `MuskelFigur(farben: MuskelFarben.farbenAlle(h), geschlecht:)` mit Beschriftung „Vorderseite“/„Rückseite“ und der Legende (Nachholbedarf · ok · viel · keine Auswertung); Liste der sechs Gruppen (`MuskelHauptgruppe.angezeigt`) mit Name, Balken (Anteil `jeGruppe`/`max`, Farbe aus Status), Fortschritt (`MuskelFortschritt.anzeige`: „+14 %“ in `accent`, „stabil“ und negative Werte in `textMuted`, „–“ bei `.keinWert`). Nicht auswertbar: Prozentzahl durch „–“ ersetzen, Figur grau, Zeilen ohne Balken, Satz aus `startsatz`. Jede Zeile ist ein Button mit `PressButtonStyle`, Accessibility-Label „<Gruppe>, Fortschritt <…>, <Status>“.
- [ ] **Step 6: `MuskelgruppeDetailView`** (Parameter: `gruppe`, `auswertung`, `namen: [String: String]`, `geschlecht`). Von oben: Kopf mit Gruppenname (`detailScreentitel`) und `Geschlecht`-abhängiger `MuskelFigur(farben: MuskelFarben.farben(gruppe:h:nurGruppe: true), ansichten: gruppe.detailAnsichten)` neben dem Gesamtfortschritt; Statuschip („Gut dabei“ für `.ok`, „Eher viel“ für `.viel`, „Zu wenig“ für `.nachholbedarf`, kein Chip sonst); Hinweiskarte aus `MuskelHinweise.gruppenhinweis` (Karte nur, wenn nicht `nil`); Zeilen je Muskel in `gruppe.muskelSchluessel` (Name aus `namen`, Fortschritt, Balken, bei seltenen Muskeln statt Balken der Text „kaum Übungen“); Button „Passende Übungen ansehen“ – führt zur bestehenden Übungsansicht „Muskelgruppe“; wenn es dafür von Home aus keinen Einstieg gibt, den Button weglassen und das in der Übergabe nennen. Route: `HomeRoute.muskelgruppe(…)` in `HomeRootView` (Switch bei Zeile ~159) und `pfad.append` aus der Übersicht.
- [ ] **Step 7: Anzeige prüfen** im Simulator (iPhone 16): `xcodebuild` Build und App starten, Home → Fortschritt: Toggle wechselt, Startansicht mit Testdaten und mit Konto ohne Verlauf (alles grau, Satz sichtbar), Tipp auf „Rücken“ öffnet das Detail, Zurück funktioniert; Screenshots ablegen, dunkler Modus ist der einzige. Dynamic Type „sehr groß“: nichts abgeschnitten.
- [ ] **Step 8: Gesamttests:** Voller Lauf `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16'`; erwartet alle Suites PASS.
- [ ] **Step 9: Commit** (`feat(ios): Fortschritt nach Muskelgruppen auf Home mit Detail`), mit `project.pbxproj`.

---

### Task 6: Spec angleichen und abschließen

**Files:**
- Modify: `docs/superpowers/specs/2026-10-17-muskelgruppen-fortschritt-design.md`

- [ ] **Step 1:** Im Abschnitt „Farben und Texte“ den Satz zum neuen Orange-Token ersetzen durch: „Nachholbedarf nimmt das vorhandene `DesignSystem.Color.warn` (`#FFB020`); kein neuer Farbwert.“ Der Rest der Spec bleibt.
- [ ] **Step 2:** Commit (`docs: Spec zur Nachholbedarf-Farbe angleichen`), danach `superpowers:finishing-a-development-branch`.
