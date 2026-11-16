# P5 Zirkel & Übungswahl – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drei Testnotizen vom 10.11. beheben: richtige Übungsbilder in der Pausen-Ablaufliste (#1), Favoriten-Filter im Zirkel mit Historie (#14), Suche in der Übungsliste eines Geräts ab 4 Übungen (#15).

**Architecture:** Reine Funktionen in `Workout/` tragen die Logik und werden mit Swift Testing geprüft; die Views (`AblaufZeileAnsicht`, `ZirkelUebungswahlSheet`, `UebungsAnsichtBereich`) zeigen nur an. Kein Server-, Schema- oder API-Eingriff.

**Tech Stack:** SwiftUI, Swift Testing, XcodeGen (`project.yml`), iOS-App `apps/ios-member`.

**Spec:** Paketliste `docs/superpowers/plans/2026-11-10-testnotizen-pakete.md` (Haupt-Checkout), Abschnitt P5; Entscheidungen von Tim (10.11.) unten.

## Ursachen (systematic-debugging)

- **#1 – gleiche Bilder in der ZirkelPauseView.** `AblaufZeile` trägt nur `bildModellId`; `AblaufZeileAnsicht` (`Screens/Training/PausenScreen.swift`) zeichnet daraus `Geraetefoto(modellId:)`. Für den Zirkel liefert `TrainingRootView` `zirkelStation($0)?.equipmentModel.id` – alle Kurzhantel-Übungen teilen ein Modell, also ein Foto. Gleiches Muster in Plan-Pause und `AblaufSheet` am Gerät (`PlanAnzeige.bildmodell`, `block.equipmentModelId`).
- **#14 – leerer Favoriten-Filter im Zirkel.** `ZirkelUebungswahlSheet` gibt `UebungsAnsichtBereich` als `hatHistorie` nur „heute an dieser Station gemacht“ mit. Das freie Training (`GeraetErkanntView`, `UebungWechselnSheet`) nimmt `GeraetModel.letzterSatzText` → `bootstrap.lastSets` (Gerät) bzw. `lastTypeSets` (Typ). Vor dem ersten Satz des Tages ist die Favoritenliste im Zirkel daher immer leer.

## Entscheidungen (Tim, 10.11.)

1. **#1:** Links in jeder Ablaufzeile das **Übungsvideo als stumme Schleife** (wie in der Zirkel-Planung), Fallback Gerätefoto, sonst Platzhalter. Gilt für alle Ablauflisten (Zirkel-Pause, Plan-Pause, Ablauf am Gerät).
2. **#14:** Favorit = an dieser Station (Gerät bzw. Typ) schon gemacht **oder** heute gemacht. Untertitel wie im freien Training: heute „Heute · 2 Sätze · 7,5 kg“, sonst „vor 3 Tagen · 10,0 kg“, ohne Historie „Noch nie · Ziel 8 – 12 Wdh.“.
3. **#15:** Suche **überall**, wo `UebungsAnsichtBereich` steht (Zirkel-Übungswahl, Geräteseite freies Training, „Übung wechseln“), ab **mehr als 3** Übungen.
4. **#15:** Mit Suchtext eine **flache Trefferliste** über alle Übungen des Geräts, Schalter und Bullets ausgeblendet; bei null Treffern „Keine Treffer für „…““.

**Eigene Entscheidungen (Claude):** Suche im Namen, Groß/klein und Diakritika egal (dieselbe Normalisierung wie die Gerätesuche). Schalter Muskelgruppe/Favorit bleibt ab 6. Das Suchfeld ist ein neuer Baustein `Suchfeld` im Stil der Gerätesuche; `GeraeteAuswahlView` behält ihr eigenes Feld (kein Umbau in diesem Paket).

## Global Constraints

- Texte deutsch, mit echten Umlauten in UI-Strings; Code-Kommentare im bestehenden Stil (ae/oe/ue).
- Neue Dateien → `xcodegen generate` in `apps/ios-member`, `project.pbxproj` mitcommitten.
- Tests: `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitnessMemberTests/<Suite>`; am Ende die ganze Suite.

## Review Focus

- Station ohne Video **und** ohne Gerätefoto (Typ ohne Foto, Cardio): Zeile zeigt den Platzhalter, keine leere Fläche – `UebungsVideoKachel`-Platzhalter, Sichtprüfung.
- Sheet ohne `UebungsVideoVorrat` in der Umgebung stürzt ab: `AblaufSheet` und `PausenScreen` hängen in Routen/Sheets von `TrainingRootView`/`GeraetView`, beide setzen `.environment(videoVorrat)` – im Simulator prüfen (Zirkel-Pause, Ablauf am Gerät).
- Gerät-Satz (`lastSets`) zählt nicht für einen Typ mit gleicher ID und umgekehrt – Test in Task 2.
- Suchtext nur Leerzeichen = keine Suche (volle Ansicht) – Test in Task 3.
- Genau 3 Übungen: kein Suchfeld; 4: Suchfeld – Test in Task 3.

---

### Task 1: Übungsvideo in der Ablaufzeile (#1)

**Files:**
- Modify: `FitnessMember/Workout/AblaufListe.swift` (`AblaufZeile`, `plan`, `zirkel`, `frei`)
- Modify: `FitnessMember/Screens/Training/PausenScreen.swift` (`AblaufZeileAnsicht`)
- Test: `FitnessMemberTests/AblaufListeTests.swift`

**Interfaces:**
- Produces: `AblaufZeile.exerciseId: String?` (neues Feld vor `bildModellId`).

- [ ] **Step 1: Failing test** `zirkelZeilenTragenIhreUebung`: Zirkel mit drei Übungen an derselben Station-Art (`bildModellId` liefert für alle `"m-kh"`), `AblaufListe.zirkel(...)` → `#expect(zeilen.map(\.exerciseId) == ["e1","e2","e3"])`. Dazu in bestehenden Plan-/Frei-Tests: `zeilen.map(\.exerciseId)` gleich der wirksamen Übung bzw. `block.exerciseId`.
- [ ] **Step 2:** Test läuft rot (Feld fehlt → Kompilierfehler).
- [ ] **Step 3:** Feld ergänzen und in `plan` (`wirksam` / `extra.id`), `zirkel` (`uebung.exerciseId`), `frei` (`block.exerciseId`) setzen. `AblaufZeileAnsicht`: `UebungsVideoKachel(exerciseId: zeile.exerciseId, kante: 36) { bisheriges Geraetefoto bzw. Uebungsbild(kante: 36) }`; Kommentar „Standbild statt Video“ durch Tims Entscheidung ersetzen. Testhelfer `zeile(_:_:)` bekommt `exerciseId: nil`.
- [ ] **Step 4:** `AblaufListeTests` grün.
- [ ] **Step 5:** Commit `fix(ios): Ablaufliste zeigt das Video der Übung statt des Gerätefotos (Testnotiz 10.11. #1)`.

### Task 2: Favorit und Untertitel im Zirkel aus der Historie (#14)

**Files:**
- Create: `FitnessMember/Workout/UebungsHistorie.swift`
- Modify: `FitnessMember/Screens/Geraet/GeraetModel.swift` (statisches `letzterSatz(an:uebungId:in:)` → ruft `UebungsHistorie`)
- Modify: `FitnessMember/Screens/Geraet/GeraetErkanntView.swift` (`altersangabe` → `UebungsHistorie.alter(tage:)`)
- Modify: `FitnessMember/Screens/Training/ZirkelUebungswahlSheet.swift` (`untertitel`, Sheet bekommt `bootstrap`)
- Modify: `FitnessMember/Screens/Training/TrainingRootView.swift` (drei Aufrufe: `bootstrap: katalog.bootstrap`)
- Test: `FitnessMemberTests/ZirkelUebungswahlTests.swift` (neu)

**Interfaces:**
- Produces:
  - `enum UebungsHistorie`
  - `static func letzterSatz(an station: Station, uebungId: String, in bootstrap: BootstrapResponse) -> GeraetModel.LetzterSatz?` (Logik 1:1 aus `GeraetModel`)
  - `static func alter(tage: Int) -> String` → `"heute"` (≤ 0), `"vor 1 Tag"`, `"vor N Tagen"`
  - `static func zeile(_ letzter: GeraetModel.LetzterSatz, loadUnit: LoadUnit, jetzt: Date) -> String` → `"vor 3 Tagen · 10,0 kg"`; Cardio: Cardio-Werte statt Belastung; ohne parsebares Datum nur der Wert.
  - `ZirkelUebungswahl.untertitel(_ uebung: GeraetUebung, station: Station, bloecke: [LokalerBlock], bootstrap: BootstrapResponse?, jetzt: Date = Date()) -> (text: String, hatHistorie: Bool)` (ersetzt die bisherige Signatur)
  - `ZirkelUebungswahlSheet.bootstrap: BootstrapResponse?` (Default `nil`)

- [ ] **Step 1: Failing tests** in `ZirkelUebungswahlTests`:
  - `typsatzMachtFavorit`: Station `testTyp("t1")`, Bootstrap mit `LastTypeSet(equipmentModelId: "t1", exerciseId: "e1", load: 10, …, performedAt: "2026-11-07T10:00:00Z")`, `jetzt` = 2026-11-10 12:00 UTC, keine Blöcke → `untertitel(e1…) == ("vor 3 Tagen · 10,0 kg", true)`; `e2` → `("Noch nie · Ziel 8 – 12 Wdh.", false)`.
  - `geraetesatzZaehltNichtFuerTyp`: `LastSet(machineId: "t1", exerciseId: "e1")` bei Station `testTyp("t1")` → `hatHistorie == false`; dieselbe Konstellation mit `testGeraet("g1")`/`LastSet(machineId: "g1")` → `true`.
  - `heuteGehtVor`: heutiger Block an der Station mit Satz → Text beginnt mit `"Heute · "`, `hatHistorie == true`, auch ohne Bootstrap.
  - `alterTexte`: `alter(tage: 0) == "heute"`, `alter(tage: 1) == "vor 1 Tag"`, `alter(tage: 8) == "vor 8 Tagen"`.
- [ ] **Step 2:** Rot.
- [ ] **Step 3:** `UebungsHistorie` anlegen, `GeraetModel` und `GeraetErkanntView` darauf umstellen (Verhalten unverändert), `untertitel` neu; im Sheet `hatHistorie: { untertitel($0, …).hatHistorie }` und die Zeile mit demselben Untertitel. `xcodegen generate`.
- [ ] **Step 4:** `ZirkelUebungswahlTests`, `GeraetModelTests` grün.
- [ ] **Step 5:** Commit `fix(ios): Favoriten im Mini-Zirkel kennen die Historie am Gerät (Testnotiz 10.11. #14)`.

### Task 3: Suche in der Übungsliste ab 4 Übungen (#15)

**Files:**
- Create: `FitnessMember/Workout/UebungsSuche.swift`
- Modify: `FitnessMember/Workout/GeraeteAuswahl.swift` (`normalisiert` von `private` auf `static` intern)
- Modify: `FitnessMember/Screens/Geraet/FilterBausteine.swift` (`Suchfeld`, `UebungsAnsichtBereich`)
- Test: `FitnessMemberTests/UebungsSucheTests.swift` (neu)

**Interfaces:**
- Produces:
  - `enum UebungsSuche { static let sucheAb = 4; static func bietetSucheAn(uebungsanzahl: Int) -> Bool; static func treffer(_ uebungen: [GeraetUebung], suchtext: String) -> [GeraetUebung]? }` – `nil` = keine Suche aktiv (leer/Leerzeichen), sonst die Treffer in Eingangsreihenfolge (Name enthält normalisierten Text).
  - `struct Suchfeld: View { @Binding var text: String; let prompt: String }`

- [ ] **Step 1: Failing tests** in `UebungsSucheTests`:
  - `schwelle`: `bietetSucheAn(uebungsanzahl: 3) == false`, `4 == true`.
  - `leerIstKeineSuche`: `treffer(liste, suchtext: "  ") == nil`, `"" == nil`.
  - `trifftNamenOhneGrossUndUmlaute`: Liste „Kurzhantel-Bankdrücken“, „Kurzhantel-Flys – Flachbank“, „Kurzhantel-Rudern“ → `"bankdrucken"` → nur Bankdrücken; `"FLYS"` → nur Flys; `"kurz"` → alle drei in Eingangsreihenfolge.
  - `keineTreffer`: `"xyz"` → `[]`.
- [ ] **Step 2:** Rot.
- [ ] **Step 3:** `UebungsSuche` anlegen. `Suchfeld` (Lupe, `TextField` mit Prompt, Löschen-Knopf 44 pt, Fläche `surface`, Rand `line`/`accent` bei Fokus, Höhe 52, Radius `neben`) in `FilterBausteine.swift`. `UebungsAnsichtBereich`: `@State suchtext`; ist `bietetSucheAn`, steht `Suchfeld(prompt: "Übung suchen")` oben; liefert `treffer` ein Array, dann flache `UebungsAbschnitte(gruppiert: false)` bzw. bei leerem Array `Text("Keine Treffer für „\(suchtext)“")` (13 pt, `textMuted`) – sonst die bisherige Ansicht unverändert. `xcodegen generate`.
- [ ] **Step 4:** `UebungsSucheTests`, `UebungsGruppierungTests` grün.
- [ ] **Step 5:** Commit `feat(ios): Suche in der Übungsliste eines Geräts ab 4 Übungen (Testnotiz 10.11. #15)`.

### Task 4: Prüfen und abgeben

- [ ] Ganze Testsuite grün (Befehl oben).
- [ ] Simulator-Sichtprüfung: Zirkel mit drei Kurzhantel-Übungen → Pause zeigt drei verschiedene Videos; „Welche Übung?“ an Kurzhantel → Suchfeld, Favorit gefüllt (mit Historie im Bootstrap), Suche „flys“ zeigt flache Treffer.
- [ ] PR gegen `master` (Freigabe durch Tim, kein Merge), Statuszeile P5 in der Paketliste im Haupt-Checkout aktualisieren.
