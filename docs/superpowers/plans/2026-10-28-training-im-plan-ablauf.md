# Ablauf im geplanten Training: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im laufenden geplanten Training Übungen ersetzen, auslassen, hinzufügen und umsortieren, jederzeit in eine angefangene Übung zurückkehren und ohne Gerätewahl starten.

**Architecture:** Fast alles baut auf Vorhandenem auf: `PlanTauschSitzung` (Sheet-Schritte, Tausch heute/dauerhaft), `TrainingsplanAblaufStore` (Reihenfolge steckt schon in `AblaufZustand.positionen`, `PlanAnzeige.planstellen` liest sie) und `GeraeteAuswahlView` (normale Auswahl). Neu sind: Umordnen und Auslassen im Ablaufspeicher (app-lokal, nicht im gespiegelten `AblaufZustand`), eine Startregel für Geräte, eine Ersatzwahl-Route auf der Auswahl und ein Training-Tab, der im Planmodus nur die Plankarte zeigt.

**Tech Stack:** Swift 6 / SwiftUI, Swift Testing (`import Testing`), xcodebuild. Kein Server-Eingriff.

**Spec:** `docs/superpowers/specs/2026-10-28-training-im-plan-ablauf-design.md`. Skizzen: https://claude.ai/artifact/7c3gp1LtFwYQfWqBDyaRuZ

Testbefehl (Suite = Dateiname ohne `.swift`, im Zweifel Suite-Namen aus der Datei lesen):

```bash
cd apps/ios-member && xcodebuild test -project FitnessMember.xcodeproj -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitnessMemberTests/<Suite>
```

## Global Constraints

- Deutsche UI-Texte und Kommentare im Stil der Umgebung; Umlaute in Texten (ä/ö/ü), in Bezeichnern ae/oe/ue.
- Keine Akzentfläche außer dem einen Hauptknopf je Bildschirm (Plankarte-Kommentar: "Keine Akzentfläche"). "Weiter mit Satz X" ist der Hauptknopf des Sheets.
- Tippflächen mindestens 44 pt; Griff 36 × 44 pt.
- `AblaufZustand`/`AblaufPosition`/`PositionStatus` sind 1:1 mit `packages/domain/src/trainingsplan-ablauf.ts` gespiegelt: **nicht** um Felder oder Stati erweitern. Neues lebt in `PlanLauf` (`TrainingsplanAblaufStore.swift`).
- Bestehende gespeicherte `PlanAblaufDatei` ohne die neuen Felder müssen weiter laden.
- Die dauerhaften Gründe brauchen Verbindung (wie `PlanTauschSitzung.dauerhaftMoeglich`).
- Die drei Gründe heißen genau: "Heute auslassen", "Belegt", "Übung gefällt mir nicht". Keine Erklärtexte darunter.
- Gerät: 0 oder 1 passende Station → direkt starten; mehrere → Auswahl mit Scan/QR.

## Review Focus

- Position mit schon abgehaktem Status (`erledigt` nach dem ersten Satz) lässt sich weiter starten: "Weiter mit Satz 3" bei 2 von 3 (das war der Fehler aus Punkt 4, `status != .erledigt` im Sheet).
- Umsortieren erhält Status, Ersatzübung und Muskeln jeder Position; `nachSatz` nimmt bei doppelt geplanter Übung danach die neue erste Position.
- Alte Ablaufdatei ohne `ausgelassen` lädt mit leerer Liste.
- Ausgelassene Position: nicht im Nenner von "x von N", zählt nicht für `zaehlt`, "Doch machen" stellt sie wieder her.
- "Übung gefällt mir nicht" mit Ersatz außerhalb des Bausteins: Server antwortet 422; das Sheet zeigt den Fehler und bietet "Nur heute" an, statt nichts zu tun.
- "Gefällt mir nicht" offline: gesperrt, sagt "Braucht Verbindung".
- Station nennt keine passende Übung (0 Treffer): kein Absturz, kein leeres Sheet.

---

### Task 1: Umordnen und Auslassen im Ablaufspeicher

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/TrainingsplanAblauf.swift` (reine Funktion), `apps/ios-member/FitnessMember/Workout/TrainingsplanAblaufStore.swift` (`PlanLauf`, Store-Methoden)
- Test: `apps/ios-member/FitnessMemberTests/TrainingsplanAblaufTests.swift`, `TrainingsplanAblaufStoreTests.swift`

**Interfaces:**
- Produces:
  - `TrainingsplanAblauf.umordnen(_ z: AblaufZustand, positionKey: String, nach index: Int) -> AblaufZustand` (index wird in `0...count-1` geklemmt; unbekannter Schlüssel: unverändert)
  - `PlanLauf.ausgelassen: [String]` (Positionsschlüssel; fehlt in alten Dateien → `[]`)
  - `TrainingsplanAblaufStore.umordnen(positionKey: String, nach index: Int)`, `.auslassen(positionKey: String)`, `.auslassenZuruecknehmen(positionKey: String)`, `var ausgelassen: Set<String>`

- [ ] **Step 1: Failing tests** in `TrainingsplanAblaufTests`: `umordnenVerschiebtNachVorn`, `umordnenErhaeltStatusUndErsatz` (Position mit `.getauscht` + `ersatzExerciseId` wandert, Felder bleiben), `umordnenKlemmtIndex`, `umordnenUnbekannterSchluesselIstNoop`. In `TrainingsplanAblaufStoreTests`: `ausgelassenUeberlebtSpeichernUndLaden`, `alteDateiOhneAusgelassenLaedt` (JSON ohne das Feld), `auslassenZuruecknehmen`, `umordnenSpeichertImLauf`.
- [ ] **Step 2:** Tests laufen lassen, Erwartung: Compile-Fehler/FAIL.
- [ ] **Step 3:** Implementieren wie oben signiert. `PlanLauf.init(from:)` mit `decodeIfPresent(...) ?? []` (Muster: `LokalZuletzt.init(from:)` im selben File). Store-Methoden rufen `speichern()` und erhöhen `stand` wie `tauschen(positionKey:ersatz:)`.
- [ ] **Step 4:** Tests grün.
- [ ] **Step 5: Commit** `feat(ios): Umordnen und Auslassen im Ablaufspeicher`

### Task 2: Anzeige kennt Auslassen und Satzfortschritt

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/PlanAnzeige.swift` (`Heute`, `zeilen`, `fortschritt`, `heute(...)`), `apps/ios-member/FitnessMember/Screens/Training/PlanKarte.swift` (`PlanAnzeige.heute(katalog:ablauf:)`), `PlanZeile.swift` (`PlanZeilenModell`, `PlanStatusMarke`)
- Test: `apps/ios-member/FitnessMemberTests/PlanAnzeigeTests.swift`

**Interfaces:**
- Consumes: `TrainingsplanAblaufStore.ausgelassen` (Task 1)
- Produces:
  - `PlanAnzeige.Heute.ausgelassen: Set<String>`
  - `PlanZeilenModell.ausgelassen: Bool`, `PlanZeilenModell.satzFortschritt: String?` ("2/3", nur bei angefangener Kraftposition, sonst nil)
  - `PlanAnzeige.fortschritt(...)` zählt ausgelassene weder im Zähler noch im Nenner (neuer Parameter `ausgelassen: Set<String> = []`)

- [ ] **Step 1: Failing tests:** `ausgelasseneZeileTraegtUntertitelAusgelassen` (Untertitel "Heute ausgelassen", `ausgelassen == true`), `fortschrittOhneAusgelassene` ("1 von 5" bei 6 Positionen, einer ausgelassen, einer erledigt), `angefangenePositionZeigtSatzFortschritt` (3 Sätze geplant, 2 in `bloecke` → "2/3"), `erledigtePositionOhneRestZeigtKeinenFortschritt` (3 von 3 → nil).
- [ ] **Step 2:** FAIL bestätigen.
- [ ] **Step 3:** Implementieren. `satzzahl(exerciseId:bloecke:)` existiert schon in `PlanAnzeige`; Satzfortschritt = Sätze der wirksamen Übung gegen `vorgabe.saetze`, nur wenn `0 < gemacht < geplant`. Marke "n/m" statt Haken in `PlanZeile` für diesen Fall (Entwurf 1); ausgelassene Zeile gedimmt und durchgestrichen.
- [ ] **Step 4:** Tests grün.
- [ ] **Step 5: Commit** `feat(ios): Plananzeige mit Auslassen und Satzfortschritt`

### Task 3: Startregel für Geräte

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/PlanStart.swift`
- Test: `apps/ios-member/FitnessMemberTests/PlanStartAuswahlTests.swift`

**Interfaces:**
- Produces: `PlanStart.Ziel` mit `case direkt(Station)`, `case auswahl([Station])`, `case keine` und `PlanStart.ziel(stationen: [Station], uebungId: String) -> Ziel` (filtert mit `bietetAn`; 1 → `.direkt`, ≥2 → `.auswahl`, 0 → `.keine`).

- [ ] **Step 1: Failing tests:** `einStationStartetDirekt`, `mehrereStationenZeigenAuswahl`, `keineStationIstKeine`, `stationOhneDieUebungZaehltNicht`. Testdaten-Helfer (`maschine`, `typ`, `bootstrap`) stehen schon in der Datei.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** grün.
- [ ] **Step 5: Commit** `feat(ios): Startregel für Geräte im Plan`

### Task 4: Sheet "Übung antippen" mit Weiter und Rückkehr

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/PlanTausch.swift` (`PlanTauschAuftrag`, `PlanTausch.auftrag`), `apps/ios-member/FitnessMember/Screens/Training/PlanPositionSheet.swift` (`vorgabe`), `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (Aufruf von `PlanTausch.auftrag` und `beiStarten`)
- Test: `apps/ios-member/FitnessMemberTests/PlanTauschTests.swift`

**Interfaces:**
- Consumes: `PlanStart.ziel` (Task 3), `PlanZeilenModell.satzFortschritt` (Task 2)
- Produces:
  - `PlanTauschAuftrag.satzGemacht: Int`, `.satzGeplant: Int`, `var weiterTitel: String` ("Weiter mit Satz \(gemacht+1)" bei `0 < gemacht`, sonst "Übung starten"; Cardio immer "Übung starten"), `var istAusgelassen: Bool`
  - `PlanTausch.auftrag(position:katalog:ablauf:bloecke:)` nimmt zusätzlich die Blöcke der Session
  - `PlanPositionSheet` bekommt `beiStarten` ohne `status != .erledigt`-Sperre

- [ ] **Step 1: Failing tests:** `weiterTitelNachZweiSaetzen` ("Weiter mit Satz 3", Status `.erledigt`), `weiterTitelOhneSaetze` ("Übung starten"), `erledigtePositionBleibtStartbar` (Auftrag trägt `status == .erledigt`, Titel trotzdem "Weiter…"), `ausgelassenePositionZeigtDochMachen`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Auftrag erweitern. Im Sheet: Hauptknopf (Akzent, `PrimaryButton` o. ä. wie `UebungsstartSheet`) mit `auftrag.weiterTitel`; darunter "Andere Übung wählen" (immer vorhanden, nicht mehr von `kandidaten` abhängig, Task 6 liefert das Ziel); "Übung entfernen" entfällt (ersetzt durch Task 5); bei ausgelassener Position statt Hauptknopf "Doch machen" (`ablauf.auslassenZuruecknehmen`). In `TrainingRootView` das Starten über `PlanStart.ziel`: `.direkt(station)` → `waehle(station, uebungId:)`; `.auswahl` → bisherige Route `.planUebung(exerciseId:)`; `.keine` → ebenfalls `.planUebung` (zeigt den vorhandenen Leerzustand).
- [ ] **Step 4:** Tests grün, außerdem `PlanStartAuswahlTests`.
- [ ] **Step 5: Commit** `feat(ios): Weiter mit Satz X und direkter Start aus dem Plan`

### Task 5: Grund-Frage mit drei Optionen und Ersatz außerhalb der Kandidaten

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/PlanTausch.swift` (`EntfernOption`, `PlanTauschSitzung`), `apps/ios-member/FitnessMember/Screens/Training/PlanPositionSheet.swift` (`PlanEntfernenFrage`, Bestätigung)
- Test: `apps/ios-member/FitnessMemberTests/PlanTauschTests.swift`

**Interfaces:**
- Produces:
  - `PlanTausch.EntfernOption`: `case heuteAuslassen, belegt, gefaelltNicht` (`nichtVorhanden` und `ueberspringen` entfallen; `serverGrund` nur für `gefaelltNicht` = `"gefaellt_nicht"`)
  - `PlanTauschSitzung.ersatzGewaehlt(_ kandidat: TauschKandidat?)`: setzt `schritt = .entfernen` (nil = ohne Ersatz)
  - `PlanTauschSitzung.grundWaehlen(_:)`: `heuteAuslassen`/`belegt` mit Ersatz → `ablauf.tauschen`; ohne Ersatz → `ablauf.auslassen(positionKey:)`; `gefaelltNicht` → nur mit Ersatz und online, weiter wie bisher in `.bestaetigen`
  - `PlanTauschSitzung.nurHeuteTauschen()`: Rückfall nach 422/Fehler im Bestätigungsschritt, ruft `ablauf.tauschen` und schließt
  - `PlanTauschAuftrag.entfernOptionen(mitErsatz: Bool) -> [EntfernOption]`: ohne Ersatz nur `[.heuteAuslassen, .belegt]`
  - Rückgabe wie bisher `waehlen`: `true` = Sheet darf zu

- [ ] **Step 1: Failing tests:** `heuteAuslassenUndBelegtVerhaltenSichGleich` (beide: Ablauf nur lokal, kein Client-Aufruf, Merkliste unberührt), `ohneErsatzNurZweiOptionen`, `gefaelltNichtOhneErsatzNichtAngeboten`, `gefaelltNichtOfflineGesperrt`, `gefaelltNichtMitErsatzAusserhalbBausteinMeldetFehlerUndBietetNurHeute` (Client-Attrappe wirft `.validation`; danach `nurHeuteTauschen()` setzt `getauscht`), `ohneErsatzAuslassenSetztAusgelassen`. Attrappe `PlanTauschend` existiert in der Datei.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Umsetzen. `waehlen(_:)` darf Kandidaten außerhalb von `auftrag.kandidaten` annehmen (die Prüfung `contains` entfällt; die Server-Prüfung ist maßgeblich). Texte der Optionen exakt wie in Global Constraints; bestehende Fehlertexte (`PlanTausch.fehlerText`) weiterverwenden. Aufräumen: nicht mehr erreichbare Teile (`dauerhaftSetzen`-Schalter im Bestätigungsschritt, `.kandidaten`-Schritt, `PlanTauschListe`) nur entfernen, wenn kein Test/View sie mehr braucht.
- [ ] **Step 4:** grün.
- [ ] **Step 5: Commit** `feat(ios): Grund-Frage mit drei Optionen und freier Ersatzwahl`

### Task 6: Ersatzwahl über die normale Auswahl

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (`GeraetRoute` um `.planErsatz(positionKey: String)`, `ziel(_:)`, neue Ersatz-Handler), `apps/ios-member/FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift` (Kopfinhalt-Slot ist schon da)
- Create: `apps/ios-member/FitnessMember/Screens/Training/PlanErsatzKopf.swift` ("PASSEND ZUM PLAN"-Liste und Zeile "Ohne Ersatz auslassen")
- Test: `apps/ios-member/FitnessMemberTests/PlanTauschTests.swift` (Ableitung `TauschKandidat` aus Station und Übung), Sichtprüfung im Simulator

**Interfaces:**
- Consumes: `PlanTauschSitzung.ersatzGewaehlt` (Task 5), `PlanTauschAuftrag.kandidaten`
- Produces: `PlanTausch.kandidat(station: Station, uebungId: String, bootstrap: BootstrapResponse?) -> TauschKandidat?` (Name, Hauptmuskeln, `modelId` des Katalogmodells der Station; nil, wenn nicht ableitbar)

- [ ] **Step 1: Failing tests** für `PlanTausch.kandidat`: Studiogerät und Katalogtyp liefern `modelId` und `hauptmuskeln`; Übung, die die Station nicht kennt, liefert nil.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** "Andere Übung wählen" im Sheet schließt das Sheet und pusht `.planErsatz(positionKey:)`. `ziel(.planErsatz)` zeigt `GeraeteAuswahlView` mit `PlanErsatzKopf` im Kopf; die Auswahl liefert `(station, uebungId)`. Bietet die Station mehrere Übungen und `uebungId == nil`, kommt eine kleine Übungswahl (vorhandenes `ZirkelUebungswahlSheet` als Muster). Danach öffnet ein neues Sheet die Grund-Frage (Task 5) mit Titel "<neu> statt <alt>"; bei "Ohne Ersatz auslassen" mit "<alt> auslassen". Der Pfad wird zurück auf die Wurzel gesetzt, sobald die Wahl angewandt ist.
- [ ] **Step 4:** Tests grün; im Simulator (iPhone 17 Pro) prüfen: Ersetzen heute, Auslassen, Belegt, Gefällt mir nicht (online mit Kandidat und mit Fremdübung).
- [ ] **Step 5: Commit** `feat(ios): Ersatzübung über die normale Auswahl wählen`

### Task 7: Plan-Modus im Training-Tab, Hinzufügen und Umsortieren

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (`wurzel`, `laufendeUebungen`), `apps/ios-member/FitnessMember/Screens/Training/PlanKarte.swift`, `PlanZeile.swift`
- Test: `apps/ios-member/FitnessMemberTests/AccessibilityBaumTests.swift` (Griff und Aktionen), `PlanAnzeigeTests.swift`

**Interfaces:**
- Consumes: `TrainingsplanAblaufStore.umordnen` (Task 1), `PlanZeilenModell.satzFortschritt` (Task 2)
- Produces: `PlanKarte(beiUmordnen: ((_ positionKey: String, _ nach: Int) -> Void)?)`; Route `.planHinzufuegen` (gleiche Auswahl ohne Kopf, Auswahl startet die Übung mit `waehle(station, uebungId:)`)

- [ ] **Step 1: Failing tests:** `PlanAnzeigeTests.zeilenFolgenDerUmgeordnetenReihenfolge` (Zustand mit vertauschten `positionen` ergibt vertauschte Zeilen); Zugänglichkeitstest: jede Plan-Zeile bietet die Aktionen "Nach oben verschieben" und "Nach unten verschieben".
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Läuft eine Session und gibt es `PlanAnzeige.heute`, zeigt `wurzel` nur: Kopf (`laufendKopf`), Plankarte, "Übung hinzufügen" (gestrichelter Rand, öffnet `.planHinzufuegen`), `zirkelHinweis`, Fuss; die Kategorien-/"Zuletzt"-Liste (`GeraeteAuswahlView`-Inhalt) und `laufendeUebungen` entfallen. Ohne Plan bleibt alles wie heute. Zeilen bekommen rechts den Griff (3 Balken, 36 × 44 pt). Ziehen per `draggable`/`dropDestination` (kein `List.onMove`, die Karte liegt in einer `LazyVStack`); angehobene Zeile mit Schatten, Rest gedimmt (Entwurf 5), Haptik beim Loslassen. Nur Planpositionen sind verschiebbar; "Zusätzlich gemacht" bleibt darunter.
- [ ] **Step 4:** Tests grün; im Simulator: Umsortieren, Hinzufügen, Rückkehr in Übung nach 2 Sätzen, Start ohne Gerätewahl (ein Gerät) und mit Auswahl (mehrere).
- [ ] **Step 5: Commit** `feat(ios): Plan-Modus im Training mit Hinzufügen und Umsortieren`

### Task 8: Spec nachziehen und Gesamtlauf

**Files:**
- Modify: `docs/superpowers/specs/2026-10-28-training-im-plan-ablauf-design.md`, `docs/superpowers/specs/2026-10-21-trainingsplan-design.md` (Abschnitt 5, Hinweis auf Überholung)

- [ ] **Step 1:** Spec an die Umsetzung anpassen: "Gefällt mir nicht" gibt es nur mit Ersatz (der Server kennt kein Entfernen einer Position); Ersatz außerhalb des Bausteins scheitert beim Server mit 422 und fällt auf "Nur heute" zurück; "Ausgelassen" lebt app-lokal in `PlanLauf`; Zusatzzeilen sind nicht verschiebbar.
- [ ] **Step 2:** Gesamte Testsuite laufen lassen:

```bash
cd apps/ios-member && xcodebuild test -project FitnessMember.xcodeproj -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Erwartet: alle grün. Bei Fehlschlag zuerst klären, ob er vorher schon bestand (`git stash`-frei: Vergleich auf `master`).
- [ ] **Step 3: Commit** `docs: Spec und Plan zum Ablauf im geplanten Training nachgezogen`
