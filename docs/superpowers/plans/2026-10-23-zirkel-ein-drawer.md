# Zirkel: Übung hinzufügen in einem Drawer – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "Übung hinzufügen" in der Zirkel-Planung läuft komplett in EINEM Sheet: Gerät/Kategorie → (Übungswahl) → (Einweisung) → Startwerte "Zur Planung", ohne dass ein Sheet schließt oder ein weiteres aufgeht.

**Architecture:** Das Auswahl-Sheet (`zirkelAuswahl(...)` in `TrainingRootView`) behält seinen `NavigationStack`. Statt weiterer Sheets (`zirkelUebungswahl`, `zirkelPlanungDrawer` nach `onDismiss`) werden "Welche Übung?" und der `UebungsstartSheet`-Inhalt als gepushte Ziele in denselben Stack gelegt. Das Sheet hat durchgehend `.large`; die Zwischenvariablen `zirkelPlanungDrawerWartet` und der `onDismiss`-Hop entfallen. Tipp auf eine Planungszeile (Werte bearbeiten) bleibt der eigene kleine Drawer.

**Tech Stack:** SwiftUI (iOS 17), Swift 6, Swift Testing (`@Test`, `#expect`), XcodeGen.

**Spec:** Nutzerwunsch vom 23.10.2026 (Chat); Vorgänger `docs/superpowers/plans/2026-10-23-zirkel-vorab-werte-reihenfolge.md`, `docs/superpowers/specs/2026-10-21-mini-zirkel-design.md`.

## Global Constraints

- Kommentare/Texte deutsch, Bezeichner mit ae/oe/ue (`Uebung`, `Geraet`), Nutzertexte mit echten Umlauten; Kommentare sagen das Warum.
- Keine neuen Dateien außer, falls nötig, mit `xcodegen` (`project.yml`); bevorzugt vorhandene Dateien erweitern.
- Branch `claude/zirkel-ein-drawer`, nicht auf `master`. Conventional Commits, Ende: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Out of Scope: der Erweitern-Weg ("+ Übung zum Zirkel" in der Pause, `zirkelErweiternOffen`) – der endet im "Übung starten"-Drawer an der Wurzel und bleibt unverändert. Er teilt aber `zirkelAuswahl(...)`, darf also nicht brechen.

## Review Focus

- Abbrechen/Wischen nach unten in jedem Schritt schließt das ganze Sheet; die Planung bleibt unverändert, nichts wird angehängt.
- Zurück aus Startwerte/Einweisung führt zur Geräteliste bzw. Übungswahl (nicht zum Schließen); der Wisch-zurück funktioniert.
- Bekannte Cardio-Übung (`zirkelDirektStart`): Sheet schließt, Übung steht in der Liste, kein leerer Schritt.
- Hinweis-Fälle (anderer Ort, schon im Zirkel): Sheet schließt, Hinweis erscheint in der Planung wie bisher.
- Zweites "Übung hinzufügen" direkt danach startet wieder an der Geräteliste (Pfad zurückgesetzt, keine Reste der letzten Wahl).
- Erweitern-Weg (Pause) funktioniert unverändert, auch mit mehreren Übungen ("Welche Übung?").

---

### Task 1: Entscheidung "nächster Schritt" als reine Logik

**Files:**
- Modify: `Workout/Zirkel.swift` (bei `ZirkelAuswahl`, ca. Zeile 204)
- Test: `FitnessMemberTests/ZirkelPlanungTests.swift`

**Interfaces:**
- Consumes: `ZirkelAuswahl.angebot(station:uebungId:bootstrap:imZirkel:)` und dessen Rückgabetyp (`.auswahl`, `.uebung`, `.schonDabei`, `.keine`) – Typnamen in `Zirkel.swift:204` nachlesen.
- Produces: `enum ZirkelHinzufuegenSchritt: Equatable { case fragen, werte(ZirkelUebung), direkt(ZirkelUebung), schonDabei, nichts }` und `static func ZirkelAuswahl.schritt(nach angebot: <Angebot>, direkt: (ZirkelUebung) -> Bool) -> ZirkelHinzufuegenSchritt`. Mapping: `.auswahl`→`.fragen`; `.uebung(u)`→`.direkt(u)` wenn `direkt(u)`, sonst `.werte(u)`; `.schonDabei`→`.schonDabei`; `.keine`→`.nichts`.

- [ ] **Step 1: Tests schreiben** in `ZirkelPlanungTests`: `bekannteCardioUebungWirdDirektAngehaengt` (`.uebung(u)` mit `direkt == true` → `.direkt(u)`), `uebungMitWertenFuehrtZuDenStartwerten` (→ `.werte(u)`), `mehrereUebungenFragenNach` (→ `.fragen`), `schonDabeiUndKeineLiefernKeinenSchritt`.
- [ ] **Step 2:** `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/ZirkelPlanungTests 2>&1 | tail -40` – Erwartet: FAIL (Typ fehlt).
- [ ] **Step 3:** Enum und `schritt(nach:direkt:)` implementieren (reine Abbildung, keine Seiteneffekte).
- [ ] **Step 4:** Test-Befehl aus Step 2 – Erwartet: PASS.
- [ ] **Step 5: Commit** `feat(ios): Zirkel-Hinzufügen entscheidet den nächsten Schritt als reine Logik`

### Task 2: Übungswahl und Startwerte als Ziele im Auswahl-Stack

**Files:**
- Modify: `Screens/Training/TrainingRootView.swift` (State 97–130, Sheets 247–253, `zirkelAuswahl` 1015–1063, `zirkelHinzufuegen` 1108–1142, `zirkelPlanungDrawerOeffnen` 1152, `zirkelPlanungDrawerInhalt` 1165, `zirkelPlanungWerte` 1181)
- Modify: `Screens/Training/ZirkelUebungswahlSheet.swift` (Detents entfernbar/optional machen)
- Modify: `Screens/Geraet/UebungsstartSheet.swift` (`detents`, Zeile 108/116)

**Interfaces:**
- Consumes: `ZirkelAuswahl.schritt(nach:direkt:)` aus Task 1; bestehendes `UebungsstartSheet(modell:startTitel:mitUmfang:beiStart:beiSchliessen:)`; `modell(station:exerciseId:token:startwerte:zirkel:)`.
- Produces: `UebungsstartSheet(…, eingebettet: Bool = false)` – bei `true` kein `.presentationDetents`/`.presentationDragIndicator` (der umgebende Stack bestimmt die Höhe); `ZirkelUebungswahlSheet` bekommt dasselbe Verhalten als `eingebettet`, ohne eigenen `NavigationStack`/"Abbrechen", wenn eingebettet (Titel "Welche Übung?" und Toolbar kommen vom Eltern-Stack). `private enum ZirkelAuswahlZiel: Hashable { case uebungswahl, start(ZirkelUebung) }`.

- [ ] **Step 1:** `zirkelAuswahlPfad` von `[GeraetRoute]` auf `NavigationPath` umstellen (Zeilen 99, 240, 1030, 1329, 1376 mit anpassen; `append(GeraetRoute.kategorie(gruppe))`, Reset `= NavigationPath()`).
- [ ] **Step 2:** In `zirkelAuswahl(...)` ein zweites `.navigationDestination(for: ZirkelAuswahlZiel.self)` ergänzen: `.uebungswahl` zeigt `ZirkelUebungswahlSheet(wahl: zirkelUebungswahl, eingebettet: true)`, `.start(u)` zeigt den Startwerte-Inhalt (Body von `zirkelPlanungDrawerInhalt`, `eingebettet: true`, `beiSchliessen` = `zirkelAuswahlPfad.removeLast()`; Nav-Leiste dort ausblenden, weil `UebungsstartSheet` eigene Köpfe/Zurück hat). Das `.sheet(item: $zirkelUebungswahl)` (Zeile 1054) entfällt für die Planung; für den Erweitern-Weg bleibt es (Parameter `inStapel: Bool` an `zirkelAuswahl`, Planung `true`, Erweitern `false`).
- [ ] **Step 3:** `zirkelHinzufuegen` auf `ZirkelAuswahl.schritt(nach:direkt: zirkelDirektStart)` umbauen: `.fragen` → `zirkelUebungswahl` setzen + `zirkelAuswahlPfad.append(ZirkelAuswahlZiel.uebungswahl)`; `.werte(u)` → `append(.start(u))`; `.direkt(u)` → Sheet schließen, `entwurf.hinzufuegen(u)`; `.schonDabei`/`.nichts`/Ortsfehler wie bisher (Sheet zu, Hinweis). Die Wahl aus der Übungswahl ruft `zirkelHinzufuegen(station, uebungId:)` erneut (wie jetzt), pusht dann `.start`; die Übungswahl bleibt darunter im Stack für "Zurück".
- [ ] **Step 4:** "Zur Planung" (`zirkelPlanungWerte`) schließt jetzt das Auswahl-Sheet (`zirkelAuswahlOffen = false`) statt `zirkelPlanungDrawer`, hängt an und setzt Werte. `zirkelPlanungDrawerWartet`, `zirkelPlanungDrawerOeffnen` und das `onDismiss:` am Auswahl-Sheet (Zeile 247) entfernen. `zirkelPlanungDrawer`/`zirkelPlanungDrawerInhalt` bleiben nur für `zirkelWerteBearbeiten` (Tipp auf Planungszeile).
- [ ] **Step 5:** `UebungsstartSheet.detents` unverändert für den Wurzel-Drawer; bei `eingebettet` die beiden `presentationDetents`/`DragIndicator`-Modifier weglassen. Im Sheet am Planungs-Sheet (Zeile 247) `.presentationDetents([.large])` setzen.
- [ ] **Step 6:** Build + Tests: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -40` – Erwartet: alle PASS.
- [ ] **Step 7: Commit** `feat(ios): Übung zum Zirkel hinzufügen läuft in einem Drawer`

### Task 3: Sichtprüfung im Simulator

**Files:** keine (nur Prüfung; Funde werden als Fix in Task 2 nachgezogen).

- [ ] **Step 1:** App im Simulator starten (Skill `run`), Mini-Zirkel anlegen, "Übung hinzufügen". Prüfen: (a) Kategorie → Kurzhantel → neue Übung: Einweisung → Startwerte → "Zur Planung" im selben Sheet, danach schließt es, Übung steht mit Werten in der Liste; (b) bekannte Übung: direkt Startwerte; (c) Zurück in jedem Schritt, Abbrechen und Wisch-nach-unten ändern die Planung nicht; (d) Cardio bekannt: direkt in der Liste; (e) Erweitern in der Pause (inkl. Gerät mit mehreren Übungen) wie vorher.
- [ ] **Step 2:** Falls Höhe/Sprung beim Wechsel Einweisung ↔ Startwerte stört: bei `.large` bleiben, nicht pro Schritt umschalten.
- [ ] **Step 3:** Plan nach `docs/superpowers/plans/2026-10-23-zirkel-ein-drawer.md` kopieren, committen `docs: Plan Zirkel-Hinzufügen in einem Drawer`.

---

## Self-Review

- Spec: einziges Sheet für Gerät → Übung → Einweisung/Startwerte (Task 2), bekannte Übung ohne Einweisung (Schrittlogik von `UebungsstartSheet` unverändert), Cardio-Direktweg (Task 1/2), Erweitern ausgenommen und geschützt (Review Focus).
- Typen: `ZirkelHinzufuegenSchritt`, `ZirkelAuswahlZiel`, `eingebettet` in Task 1/2 einheitlich benannt.
- Hinweis: Das Sheet bleibt für alle Schritte `.large`; der kurze Startwerte-Drawer der bekannten Übung ist in diesem Flow also höher als bisher. Das ist der Preis für kein Springen.
