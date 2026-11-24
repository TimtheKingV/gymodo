# Kamera-Tracking und Tempo-Welle, Teil 1: Kern und Katalog (E1 + E2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Logik, die aus erkannten Skeletten Lage, Wiederholungen und Tempo-Rückblick macht, und die Katalogfelder für Kameraprofil und Tempo von der Datenbank bis ins App-Modell – beides ohne Oberfläche, vollständig getestet.

**Architecture:** Ein neues Swift-Package `Koerperbild` (rein, am Mac mit `swift test` lauffähig) liefert aus `Skelett`-Folgen dieselbe `Lage`, die das Package `Sensorik` schon für `Sollwelle` kennt; `Sensorik` bekommt nur die Haltephase dazu. Die Katalogfelder laufen denselben Weg wie `geraet_label`: Migration → Katalogdatei → Import → Bootstrap/Tag-Kontext → `BootstrapResponse`. Ein Zuordnungsvorschlag und ein Bericht über die Übungsvideos entscheiden später, welche Profile freigeschaltet werden.

**Tech Stack:** Swift 6 (SwiftPM, XCTest/Swift Testing wie in `Packages/Sensorik`), Vision nur im Mac-Werkzeug; TypeScript, zod, vitest (`@fitretro/domain`), Supabase-Migrationen, pnpm.

**Spec:** `docs/superpowers/specs/2026-11-24-kamera-tempo-ablauf-design.md` (Etappen E1 und E2, Abschnitte 5, 8, 9, 10 Stufe 1). E3–E6 (Oberfläche, Fehlerfälle, übrige Profile, Portal) bekommen eigene Pläne, sobald dieser Teil steht und Tim die Zuordnungsliste gesehen hat.

## Global Constraints

- Arbeitsbasis ist `origin/master` in einem eigenen Worktree und Branch `claude/kamera-kern-katalog`. Der Hauptordner steht auf einem alten Branch und wird von anderen Sessions genutzt.
- Der Versuch im Worktree `.claude/worktrees/kamera-versuch` ist uncommittet. Nur lesen und kopieren, dort nichts ändern, nichts committen.
- Keine Oberfläche, keine Kamera, kein Eingriff in `GeraetModel` in diesem Plan.
- Kein Kamerabild und kein Skelett einer echten Person wird gespeichert. Die Skelett-Dateien dieses Plans stammen nur aus den Übungsvideos unter `catalog/media/videos`.
- Bestehendes Verhalten der Sensorik bleibt: Mit Haltezeit 0 liefern `Tempovorgabe`, `Sollwelle` und `Tempoauswertung` dieselben Werte wie heute, alle bestehenden Tests bleiben unverändert grün.
- Migrationen nur lokal. **Nichts auf Supabase-Prod**; das braucht Tims ausdrückliche Freigabe und ist nicht Teil dieses Plans.
- Freigeschaltet ist anfangs nur das Profil `ohne_kamera`. Kein Kameraprofil wird in `catalog/gymtavo.json` eingetragen.
- Feste Werte aus der Spec: Gelenk sicher ab Sicherheit 0,3; Check bestanden nach 1,0 s; Tracking verloren nach mehr als 1,0 s; Ruhe vor dem Los 0,5 s; Glättung 0,08 s; im Takt ab 70 % der Dauer in der Bahn; Wegtoleranz 25 %; Hub zu klein unter 20°; Tempozeiten in Schritten von 0,5 s (senken/heben 1–4 s, halten 0–3 s); Standard 1,5 s heben / 2,5 s senken / 0 s halten.
- Namen, Kommentare und Commit-Texte deutsch wie im Bestand (Umlaute im Code als ae/oe/ue).
- Swift-Tests: im jeweiligen Package-Ordner `swift test --filter <Name>`. Domain: `pnpm --filter @fitretro/domain test -- <Datei>`. Integration (lokales Supabase muss laufen): `pnpm test:integration -- <Datei>`.

## Review Focus

1. **Skelett fällt mitten in einer Wiederholung für wenige Bilder aus** – die Wiederholung darf weder doppelt noch gar nicht zählen (Task 5).
2. **Einarmige Übung, der ruhende Arm ist besser erkannt als der arbeitende** – die Lage muss dem arbeitenden Arm folgen (Task 5).
3. **Winkel springt von +179° auf −179°** (Ellbogen wandert beim Rudern hinter den Rumpf) – keine Phantom-Wiederholung (Task 3 und 5).
4. **Alter Server oder alte App: Feld fehlt oder trägt ein unbekanntes Profil** – die App behandelt die Übung wie ohne Profil, statt beim Dekodieren zu scheitern (Task 11).
5. **Katalogdatei mit halbem Tempo oder Tempo ohne Profil** – der Import lehnt mit einer Meldung ab, die Index und Schlüssel nennt, statt eine Zeile zu schreiben, an der die Datenbank scheitert (Task 9).

---

## Dateien

| Datei | Aufgabe |
|---|---|
| `apps/ios-member/Packages/Sensorik/Sources/Sensorik/Tempovorgabe.swift`, `Sollwelle.swift`, `Tempoauswertung.swift` | Haltephase (Task 1, 2) |
| `apps/ios-member/Packages/Koerperbild/Package.swift` | neues Package: Targets `Koerperbild`, `KoerperErkennung`, `skelette-rechnen`, Tests |
| `…/Koerperbild/Sources/Koerperbild/Skelett.swift` | `Gelenk`, `Punkt`, `Skelett`, `Gelenkwinkel`, `Koerperseite` (Task 3) |
| `…/Koerperbild/Sources/Koerperbild/Skelettfolge.swift` | Dateiformat der vorgerechneten Skelette (Task 3) |
| `…/Koerperbild/Sources/Koerperbild/Kameravorgabe.swift` | `Kameraprofil`, `Seitenwahl`, `Kameravorgabe`, Pflichtgelenke (Task 4) |
| `…/Koerperbild/Sources/Koerperbild/Erkennungspruefung.swift` | bestanden / verloren über die Zeit (Task 4) |
| `…/Koerperbild/Sources/Koerperbild/Koerperlage.swift` | Skelett → `Lage`, Wiederholungen, Hub, Seite (Task 5) |
| `…/Koerperbild/Sources/Koerperbild/Uebungstempo.swift` | senken/halten/heben ↔ `Tempovorgabe`, Phasenworte (Task 6) |
| `…/Koerperbild/Sources/Koerperbild/Satzrueckblick.swift` | Urteil je gezählter Wiederholung (Task 6) |
| `…/Koerperbild/Sources/KoerperErkennung/PoseErkenner.swift` | Vision → `Skelett` (Task 7) |
| `…/Koerperbild/Sources/skelette-rechnen/main.swift` | Mac-Werkzeug: Videos → Skelett-Dateien (Task 7) |
| `data/koerperbild/skelette/<key>.skelett.json` | je Übungsvideo eine Datei (Task 7) |
| `supabase/migrations/00NN_uebung_kamera_tempo.sql` | Spalten und Prüfregeln (Task 8) |
| `packages/domain/src/kamera.ts` | Werte, Schemas, Abbildung, Freischalt-Liste (Task 9) |
| `packages/domain/src/katalog-datei.ts`, `katalog-plan.ts`, `katalog-import.ts` | Dateiformat und Import (Task 9) |
| `packages/domain/src/bootstrap.ts`, `machine-context.ts`, `catalog.ts` | Ausgabe an App und Portal (Task 10) |
| `apps/ios-member/FitnessMember/Networking/DTOs/BootstrapResponse.swift`, `TagContextResponse.swift` | App-Modell (Task 11) |
| `tools/kamera-zuordnung/vorschlag.py`, `data/koerperbild/zuordnung.json`, `docs/kamera-zuordnung-2026-11.md` | Zuordnungsvorschlag für Tim (Task 12) |
| `…/Koerperbild/Tests/KoerperbildTests/ProfilBerichtTests.swift`, `data/koerperbild/profilbericht.md` | Gütetest Stufe 1 (Task 13) |

---

### Task 1: Haltezeit in `Tempovorgabe`

**Files:**
- Modify: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/Tempovorgabe.swift`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/TempovorgabeTests.swift` (anlegen, falls es die Datei nicht gibt; sonst ergänzen)

**Interfaces:**
- Produces: `Tempovorgabe.init(kraftweg: Double, ablassen: Double, halten: Double = 0)`, `let halten: Double`, `var periode: Double` (= kraftweg + halten + ablassen). `Tempovorgabe.standard` unverändert (1,5 / 2,5 / 0).

- [ ] **Step 1: Tests schreiben**

```swift
func testHaltenStandardIstNull() {
    XCTAssertEqual(Tempovorgabe(kraftweg: 2, ablassen: 3).halten, 0)
    XCTAssertEqual(Tempovorgabe.standard.periode, 4.0)
}
func testHaltenRundetUndBegrenzt() {
    XCTAssertEqual(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 1.2).halten, 1.0)
    XCTAssertEqual(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 9).halten, 3.0)
    XCTAssertEqual(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: -1).halten, 0)
    XCTAssertEqual(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: .nan).halten, 0)
}
func testPeriodeMitHalten() {
    XCTAssertEqual(Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 1).periode, 6.0)
}
func testAltesJSONOhneHaltenDekodiert() throws {
    let v = try JSONDecoder().decode(Tempovorgabe.self, from: Data(#"{"kraftweg":2,"ablassen":3}"#.utf8))
    XCTAssertEqual(v, Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 0))
}
```

- [ ] **Step 2:** `swift test --filter TempovorgabeTests` → FAIL (kein Parameter `halten`).
- [ ] **Step 3:** `halten` ergänzen: Rundung auf 0,5 s, Grenzen 0…3, nicht endlich → 0; `CodingKeys` um `halten`, beim Dekodieren `decodeIfPresent` mit 0.
- [ ] **Step 4:** `swift test --filter Tempovorgabe` → PASS; `swift test --filter Sollwelle` und `--filter Tempoauswertung` weiter PASS.
- [ ] **Step 5:** Commit `feat(sensorik): Haltezeit in der Tempovorgabe`.

### Task 2: Haltephase in `Sollwelle` und `Tempoauswertung`

**Files:**
- Modify: `…/Sensorik/Sources/Sensorik/Sollwelle.swift`, `Tempoauswertung.swift`
- Test: `…/Sensorik/Tests/SensorikTests/SollwelleTests.swift`, `TempoauswertungTests.swift`

**Interfaces:**
- Consumes: `Tempovorgabe.halten`, `.periode` (Task 1).
- Produces: `enum Weg { case kraftweg, halten, ablassen }`. `Sollwelle.lage(bei:)` ist während der Haltezeit genau 1. `weg(bei:)` liefert `.halten` nur, wenn `vorgabe.halten > 0`. `taktmarken` enthält bei Haltezeit > 0 zusätzlich das Ende des Haltens (`t = kraftweg + halten`, Lage 1) und die Mitte des Ablassens bei `kraftweg + halten + ablassen/2`.

- [ ] **Step 1: Tests schreiben** (Vorgabe `Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 1)`, Periode 6):

```swift
func testHaltephaseIstFlachOben() {
    let w = Sollwelle(vorgabe: v)
    XCTAssertEqual(w.lage(bei: 2.0), 1, accuracy: 1e-9)
    XCTAssertEqual(w.lage(bei: 2.5), 1, accuracy: 1e-9)
    XCTAssertEqual(w.lage(bei: 3.0), 1, accuracy: 1e-9)
    XCTAssertEqual(w.lage(bei: 4.5), 0.5, accuracy: 1e-9)   // Mitte des Ablassens
    XCTAssertEqual(w.lage(bei: 6.0), 0, accuracy: 1e-9)
}
func testWegKenntHalten() {
    let w = Sollwelle(vorgabe: v)
    XCTAssertEqual(w.weg(bei: 1.0), .kraftweg)
    XCTAssertEqual(w.weg(bei: 2.5), .halten)
    XCTAssertEqual(w.weg(bei: 3.5), .ablassen)
    XCTAssertEqual(w.weg(bei: 8.5), .halten)                // zweite Periode
}
func testOhneHaltenKeinHaltenWeg() {
    let w = Sollwelle(vorgabe: .standard)
    XCTAssertEqual(w.weg(bei: 1.5), .ablassen)
}
func testTaktmarkenMitHalten() {
    let marken = Sollwelle(vorgabe: v).taktmarken(von: 0, bis: 6)
    XCTAssertEqual(marken.map(\.t), [0, 1, 2, 3, 4.5])
    XCTAssertEqual(marken.map(\.lage), [0, 0.5, 1, 1, 0.5])
}
func testZielzeitNutztPeriodeMitHalten() {
    XCTAssertEqual(Sollwelle(vorgabe: v).zielzeit(wiederholungen: 8), 48)
}
```

In `TempoauswertungTests`: ein Satz mit Haltezeit 1 s, dessen Lage exakt der Soll-Welle folgt, ergibt Quote 1,0 und `kraftweg == .imTempo`, `ablassen == .imTempo`.

- [ ] **Step 2:** `swift test --filter SollwelleTests` → FAIL.
- [ ] **Step 3:** Umsetzen. In `Tempoauswertung` zählen Messwerte des Wegs `.halten` zum Kraftweg (Index 0); `Wegurteil` und `Tempoergebnis` bleiben unverändert.
- [ ] **Step 4:** `swift test --filter "Sollwelle|Tempoauswertung|Tempovorgabe"` → PASS, keine bestehende Erwartung geändert.
- [ ] **Step 5:** Commit `feat(sensorik): Haltephase in Soll-Welle und Auswertung`.

### Task 3: Package `Koerperbild`, Skelett und Skelettfolge

**Files:**
- Create: `apps/ios-member/Packages/Koerperbild/Package.swift`, `Sources/Koerperbild/Skelett.swift`, `Sources/Koerperbild/Skelettfolge.swift`
- Test: `Tests/KoerperbildTests/SkelettTests.swift`, `SkelettfolgeTests.swift`
- Vorlage (nur lesen): `.claude/worktrees/kamera-versuch/apps/ios-member/Packages/KameraVersuch/Sources/PoseKern/Skelett.swift`

**Interfaces:**
- Produces:
  - `Package`: Swift-Tools 6.0, Sprachmodus 6, Plattformen iOS 17 / macOS 14, Abhängigkeit `.package(path: "../Sensorik")`. Targets: `Koerperbild` (hängt an `Sensorik`), Test-Target `KoerperbildTests`. Die Targets `KoerperErkennung` und `skelette-rechnen` kommen in Task 7.
  - `enum Gelenk: String, CaseIterable, Sendable` mit den 15 Fällen des Versuchs (`nase, hals, schulterL, schulterR, ellbogenL, ellbogenR, handL, handR, wurzel, hueftL, hueftR, knieL, knieR, fussL, fussR`).
  - `struct Punkt: Sendable, Equatable { var x, y, sicherheit: Double }` (0…1, Ursprung oben links).
  - `enum Koerperseite: Sendable { case links, rechts }`.
  - `enum Gelenkwinkel: String, CaseIterable, Sendable { case ellbogen, schulter, huefte, knie }` mit `func gelenke(_ seite: Koerperseite) -> (Gelenk, Gelenk, Gelenk)`: ellbogen = (schulter, ellbogen, hand), schulter = (ellbogen, schulter, hueft), huefte = (schulter, hueft, knie), knie = (hueft, knie, fuss).
  - `struct Skelett: Sendable, Equatable { var punkte: [Gelenk: Punkt]; var seitenverhaeltnis: Double }`, `static let mindestSicherheit = 0.3`, `func sicher(_ g: Gelenk) -> Punkt?`, `func winkel(_ w: Gelenkwinkel, seite: Koerperseite) -> Double?` (Grad mit Vorzeichen, −180…180, Rechnung wie im Versuch mit Seitenverhältnis).
  - `struct Skelettfolge: Sendable { let bildrate: Double; let seitenverhaeltnis: Double; let bilder: [Skelett?] }`, `init(daten: Data) throws`, `func daten() throws -> Data`. JSON: `{"bildrate":24,"seitenverhaeltnis":0.5625,"bilder":[{"schulterL":[0.41,0.22,0.93],…}, null, …]}`; Zahlen beim Schreiben auf vier Nachkommastellen gerundet, Schlüssel sortiert.

- [ ] **Step 1: Tests schreiben**

```swift
func testWinkelGestreckterArmIst180() {
    let s = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.5, 0.6)])
    XCTAssertEqual(abs(s.winkel(.ellbogen, seite: .links)!), 180, accuracy: 0.01)
}
func testWinkelRechterWinkelMitSeitenverhaeltnis() {
    // Bild 9:16; ohne Seitenverhaeltnis waere der Winkel verzerrt.
    let s = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.5 + 0.2 * 16 / 9, 0.4)], sv: 9.0 / 16.0)
    XCTAssertEqual(abs(s.winkel(.ellbogen, seite: .links)!), 90, accuracy: 0.01)
}
func testUnsicheresGelenkGibtKeinenWinkel() {
    var s = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.5, 0.6)])
    s.punkte[.handL]!.sicherheit = 0.29
    XCTAssertNil(s.winkel(.ellbogen, seite: .links))
}
func testVorzeichenWechseltMitDerSeiteDerHand() {
    let a = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.6, 0.5)])
    let b = skelett([.schulterL: (0.5, 0.2), .ellbogenL: (0.5, 0.4), .handL: (0.4, 0.5)])
    XCTAssertEqual(a.winkel(.ellbogen, seite: .links)!, -b.winkel(.ellbogen, seite: .links)!, accuracy: 0.01)
}
func testSkelettfolgeHinUndZurueck() throws {
    let f = Skelettfolge(bildrate: 24, seitenverhaeltnis: 0.5625, bilder: [skelett([.nase: (0.5, 0.1)], sv: 0.5625), nil])
    let g = try Skelettfolge(daten: f.daten())
    XCTAssertEqual(g.bilder.count, 2); XCTAssertNil(g.bilder[1])
    XCTAssertEqual(g.bilder[0]?.punkte[.nase]?.x, 0.5)
}
func testSkelettfolgeUnbekanntesGelenkWirdUebergangen() throws {
    let json = #"{"bildrate":24,"seitenverhaeltnis":0.5625,"bilder":[{"schweif":[0.1,0.1,0.9],"nase":[0.5,0.1,0.9]}]}"#
    XCTAssertEqual(try Skelettfolge(daten: Data(json.utf8)).bilder[0]?.punkte.count, 1)
}
```

(`skelett(_:sv:)` ist ein Testhelfer: Sicherheit 1, Seitenverhältnis Standard 1.)

- [ ] **Step 2:** `swift test` im neuen Package-Ordner → FAIL (Typen fehlen).
- [ ] **Step 3:** Package und Typen anlegen.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5:** Commit `feat(koerperbild): Package mit Skelett und Skelettfolge`.

### Task 4: Kameravorgabe, Pflichtgelenke, Erkennungsprüfung

**Files:**
- Create: `Sources/Koerperbild/Kameravorgabe.swift`, `Sources/Koerperbild/Erkennungspruefung.swift`
- Test: `Tests/KoerperbildTests/KameravorgabeTests.swift`, `ErkennungspruefungTests.swift`

**Interfaces:**
- Consumes: `Gelenk`, `Gelenkwinkel`, `Koerperseite`, `Skelett` (Task 3).
- Produces:
  - `enum Kameraprofil: String, CaseIterable, Sendable { case ganzkoerperStehend = "ganzkoerper_stehend", oberkoerper = "oberkoerper", stuetzBoden = "stuetz_boden", liegend = "liegend", zugHaengend = "zug_haengend", ohneKamera = "ohne_kamera" }`
  - `enum Seitenwahl: String, Sendable { case links, rechts, beide }`
  - `struct Kameravorgabe: Sendable, Equatable { let profil: Kameraprofil; let signal: Gelenkwinkel?; let seite: Seitenwahl }`; `init?(profil:signal:seite:)` liefert nil, wenn `signal == nil` und das Profil nicht `ohneKamera` ist; bei `ohneKamera` wird `signal` verworfen.
  - `func pflichtgelenke(_ seite: Koerperseite) -> Set<Gelenk>`: Gelenke des Profils auf dieser Seite, vereinigt mit den drei Gelenken des Signals. Profil-Gelenke: ganzkoerperStehend = schulter, hueft, knie, fuss; oberkoerper = schulter, ellbogen, hand; stuetzBoden = schulter, ellbogen, hand, hueft; liegend = keine eigenen; zugHaengend = schulter, ellbogen, hand; ohneKamera = leer.
  - `enum Gelenkgruppe: CaseIterable, Sendable { case schultern, arme, hueftenKnie, fuesse }` mit `func gelenke(_ seite: Koerperseite) -> Set<Gelenk>` (schultern = schulter; arme = ellbogen, hand; hueftenKnie = hueft, knie; fuesse = fuss).
  - `struct Erkennungspruefung: Sendable` mit `init(vorgabe: Kameravorgabe)`, `mutating func eingabe(t: TimeInterval, skelett: Skelett?)`, `var fuehrendeSeite: Koerperseite` (bei `Seitenwahl.beide` die Seite mit mehr sicheren Pflichtgelenken, bei Gleichstand links; sonst die vorgegebene), `var fehlendeGruppen: Set<Gelenkgruppe>` (nur Gruppen, die Pflichtgelenke enthalten), `var imRahmen: Bool` (alle Pflichtgelenke sicher und mit x, y in 0,03…0,97), `var bestanden: Bool` (seit mindestens `Self.bestandenNach = 1.0` s durchgehend `imRahmen`), `var verloren: Bool` (seit mehr als `Self.verlorenNach = 1.0` s nicht alle Pflichtgelenke sicher; der Rand zählt hier nicht), `mutating func zuruecksetzen()`.

- [ ] **Step 1: Tests schreiben**

```swift
func testPflichtgelenkeGanzkoerperMitKnie() {
    let v = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide)!
    XCTAssertEqual(v.pflichtgelenke(.links), [.schulterL, .hueftL, .knieL, .fussL])
}
func testPflichtgelenkeLiegendNurSignal() {
    let v = Kameravorgabe(profil: .liegend, signal: .ellbogen, seite: .beide)!
    XCTAssertEqual(v.pflichtgelenke(.rechts), [.schulterR, .ellbogenR, .handR])
}
func testSignalGelenkeImmerPflicht() {
    let v = Kameravorgabe(profil: .oberkoerper, signal: .schulter, seite: .beide)!
    XCTAssertTrue(v.pflichtgelenke(.links).contains(.hueftL))
}
func testVorgabeOhneSignalNurOhneKamera() {
    XCTAssertNil(Kameravorgabe(profil: .oberkoerper, signal: nil, seite: .beide))
    XCTAssertNotNil(Kameravorgabe(profil: .ohneKamera, signal: nil, seite: .beide))
}
func testBestandenErstNachEinerSekunde() {
    var p = Erkennungspruefung(vorgabe: curl)
    p.eingabe(t: 0.0, skelett: voll); XCTAssertFalse(p.bestanden)
    p.eingabe(t: 0.9, skelett: voll); XCTAssertFalse(p.bestanden)
    p.eingabe(t: 1.0, skelett: voll); XCTAssertTrue(p.bestanden)
}
func testAussetzerSetztBestandenZurueck() {
    var p = Erkennungspruefung(vorgabe: curl)
    p.eingabe(t: 0, skelett: voll); p.eingabe(t: 0.6, skelett: nil); p.eingabe(t: 1.2, skelett: voll)
    XCTAssertFalse(p.bestanden)
}
func testVerlorenErstNachMehrAlsEinerSekunde() {
    var p = Erkennungspruefung(vorgabe: curl)
    p.eingabe(t: 0, skelett: voll); p.eingabe(t: 1, skelett: voll)
    p.eingabe(t: 1.5, skelett: ohneHand); XCTAssertFalse(p.verloren)
    p.eingabe(t: 2.5, skelett: ohneHand); XCTAssertFalse(p.verloren)   // genau 1,0 s
    p.eingabe(t: 2.6, skelett: ohneHand); XCTAssertTrue(p.verloren)
    XCTAssertEqual(p.fehlendeGruppen, [.arme])
}
func testFehlendeFuesseStoerenDenCurlNicht() {
    var p = Erkennungspruefung(vorgabe: curl)
    p.eingabe(t: 0, skelett: ohneFuesse); p.eingabe(t: 1, skelett: ohneFuesse)
    XCTAssertTrue(p.bestanden); XCTAssertTrue(p.fehlendeGruppen.isEmpty)
}
func testGelenkAmBildrandIstNichtImRahmenAberNichtVerloren() {
    var p = Erkennungspruefung(vorgabe: curl)
    for t in stride(from: 0.0, through: 3.0, by: 0.5) { p.eingabe(t: t, skelett: handAmRand) }   // handL.x = 0.99
    XCTAssertFalse(p.bestanden); XCTAssertFalse(p.verloren)
}
```

(`curl` = oberkoerper / ellbogen / beide; die Skelette sind Testhelfer mit allen 15 Gelenken bzw. ohne die genannten.)

- [ ] **Step 2:** `swift test --filter "Kameravorgabe|Erkennungspruefung"` → FAIL.
- [ ] **Step 3:** Umsetzen.
- [ ] **Step 4:** → PASS.
- [ ] **Step 5:** Commit `feat(koerperbild): Kameravorgabe, Pflichtgelenke und Erkennungspruefung`.

### Task 5: `Koerperlage` – vom Skelett zur Lage und zur Wiederholung

**Files:**
- Create: `Sources/Koerperbild/Koerperlage.swift`
- Test: `Tests/KoerperbildTests/KoerperlageTests.swift`, Testhelfer `Tests/KoerperbildTests/Kunstbewegung.swift`
- Vorlage (nur lesen): `PoseKern/Auswertung.swift` im Versuch (`WendeZaehler`, Entfalten über ±180°, Glättung).

**Interfaces:**
- Consumes: `Kameravorgabe`, `Skelett`, `Gelenkwinkel`, `Koerperseite` (Task 3, 4); `Lage`, `Wegrichtung` aus `Sensorik`.
- Produces:
  - `struct Wiederholung: Sendable, Equatable { let beginn, umkehr, ende: TimeInterval }` mit `var dauerHin: TimeInterval`, `var dauerRueck: TimeInterval`.
  - `struct Koerperlage: Sendable` mit
    - `init(vorgabe: Kameravorgabe, gemerkterHub: Double?)` (verlangt eine Vorgabe mit Signal; `precondition`),
    - `mutating func los(t: TimeInterval)`: legt die Startposition fest = Mittel des geglätteten Signalwinkels der letzten 0,5 s; ohne Werte der nächste gültige Winkel,
    - `mutating func verarbeite(t: TimeInterval, skelett: Skelett?) -> Lage`,
    - `mutating func unterbrechen()`: eine angefangene Wiederholung fällt weg, gezählte bleiben; die nächste beginnt mit der nächsten Bewegung aus der Nähe der Startposition,
    - `var wiederholungen: [Wiederholung]`, `var fuehrendeSeite: Koerperseite?`, `var hubGrad: Double?` (für das Merken), `var hubZuKlein: Bool`, `var istRuhig: Bool`.
  - Regeln (alle Werte als `static let`):
    - Winkel je Seite fortlaufend entfaltet, Glättung exponentiell mit 0,08 s; nach einer Lücke über 0,5 s ohne Glättung neu ansetzen.
    - `istRuhig`: der geglättete Winkel der führenden Seite (vor Festlegung: beider Seiten) schwankt über 0,5 s um höchstens 5°.
    - Seite bei `Seitenwahl.beide`: am ersten Umkehrpunkt die Seite mit dem größeren Ausschlag seit dem Los; liegen beide innerhalb von 25 % beieinander, die Seite, deren drei Signalgelenke im Mittel sicherer sind. Danach für die Instanz fest. Vor der Festlegung kommt die Lage aus der Seite mit dem bisher größeren Ausschlag.
    - Lage = Vorzeichen · (Winkel − Startwinkel) / Maßstab; Vorzeichen = Richtung der ersten Bewegung. Maßstab: gemerkter Hub; ohne ihn das Größere aus 40° und dem bisherigen Gipfel, nach der ersten Wiederholung deren Ausschlag, nach der zweiten das Mittel, danach höchstens 10 % Änderung je Wiederholung.
    - Umkehrpunkte: Schwelle = max(15°, 35 % des Maßstabs). Eine Wiederholung ist gezählt, sobald nach einem oberen Umkehrpunkt die Lage auf höchstens 0,15 fällt oder, bei unvollständiger Rückkehr, der Winkel vom Tal um die Schwelle wieder ansteigt. `ende` und das nächste `beginn` werden nachträglich auf das Tal gelegt (Messwerte höchstens 1,5° über dem Talminimum). (Geändert in der Umsetzung am 24.11.: Die ursprüngliche Regel „erst beim erkannten unteren Umkehrpunkt“ verzögerte Zählung und `sicher` um rund 0,8 s und hätte die letzte Wiederholung nie gezählt.)
    - `sicher`: Hub bekannt (gemerkt oder zwei Wiederholungen gezählt) **und** alle drei Signalgelenke der führenden Seite in diesem Bild sicher. Ohne Skelett oder ohne Signalgelenke: letzte Lage halten, `sicher = false`, Richtung `.unbekannt`.
    - `hubZuKlein`: nach zwei gezählten Wiederholungen ist der Hub unter 20°.
    - `Lage.t` ist das übergebene `t`.

- [ ] **Step 1: Testhelfer schreiben.** `Kunstbewegung.swift`: `func armSkelett(ellbogenL: Double, ellbogenR: Double, sicherheitL: Double = 1, sicherheitR: Double = 1) -> Skelett` baut ein Skelett mit festen Schultern und Hüften und Händen so, dass die Ellbogenwinkel die gegebenen Beträge haben; `func satz(wdh: Int, hin: Double, rueck: Double, von: Double, bis: Double, rate: Double = 30) -> [(t: Double, winkel: Double)]` liefert eine Cosinus-Bewegung des Winkels von `von` nach `bis` und zurück, mit 1 s Ruhe davor.

- [ ] **Step 2: Tests schreiben**

```swift
func testZaehltAchtSaubereWiederholungen() {
    let k = lauf(satz(wdh: 8, hin: 1.5, rueck: 2.5, von: 170, bis: 50))
    XCTAssertEqual(k.wiederholungen.count, 8)
    XCTAssertEqual(k.hubGrad!, 120, accuracy: 6)
}
func testLageLaeuftVonNullBisEins() {
    let lagen = lagenImLauf(satz(wdh: 6, hin: 2, rueck: 2, von: 170, bis: 50), gemerkterHub: 120)
    XCTAssertEqual(lagen.first!.lage, 0, accuracy: 0.05)
    XCTAssertEqual(lagen.map(\.lage).max()!, 1, accuracy: 0.08)
    XCTAssertTrue(lagen.allSatisfy { $0.lage > -0.15 && $0.lage < 1.15 })
}
func testOhneGemerktenHubErstNachZweiWiederholungenSicher() {
    let (k, lagen) = lagenUndStand(satz(wdh: 4, hin: 2, rueck: 2, von: 170, bis: 50), gemerkterHub: nil)
    let zweiteEnde = k.wiederholungen[1].ende
    XCTAssertTrue(lagen.filter { $0.t < zweiteEnde - 0.2 }.allSatisfy { !$0.sicher })
    XCTAssertTrue(lagen.filter { $0.t > zweiteEnde + 0.2 }.allSatisfy(\.sicher))
}
func testMitGemerktemHubSofortSicher() {
    XCTAssertTrue(lagenImLauf(satz(wdh: 3, hin: 2, rueck: 2, von: 170, bis: 50), gemerkterHub: 120).dropFirst(5).allSatisfy(\.sicher))
}
func testKurzerAussetzerZaehltNichtDoppelt() {
    // 0,3 s ohne Skelett mitten im Hinweg der dritten Wiederholung.
    XCTAssertEqual(laufMitLuecke(satz(wdh: 6, hin: 2, rueck: 2, von: 170, bis: 50), von: 9.5, bis: 9.8).wiederholungen.count, 6)
}
func testEinarmigFolgtDemArbeitendenArm() {
    // Links ruht bei 170 mit Sicherheit 1, rechts arbeitet mit Sicherheit 0,6.
    let k = laufEinarmig(arbeitet: .rechts, sicherheitRuhend: 1.0, sicherheitArbeitend: 0.6, wdh: 5)
    XCTAssertEqual(k.fuehrendeSeite, .rechts); XCTAssertEqual(k.wiederholungen.count, 5)
}
func testWinkelsprungUeber180ZaehltNicht() {
    // Vorzeichen-Winkel laeuft 150 → 200 (= -160) → 150; eine Wiederholung, keine zwei.
    XCTAssertEqual(laufRoh(vorzeichenWinkel: uebersprung(wdh: 4)).wiederholungen.count, 4)
}
func testZitternInRuheZaehltNicht() {
    XCTAssertEqual(lauf(rauschen(dauer: 10, um: 170, ausschlag: 6)).wiederholungen.count, 0)
}
func testHubZuKlein() {
    XCTAssertTrue(lauf(satz(wdh: 3, hin: 1.5, rueck: 1.5, von: 170, bis: 153)).hubZuKlein)
    XCTAssertFalse(lauf(satz(wdh: 3, hin: 1.5, rueck: 1.5, von: 170, bis: 120)).hubZuKlein)
}
func testUnterbrechenVerwirftNurDieOffene() {
    var k = Koerperlage(vorgabe: curl, gemerkterHub: 120)
    speise(&k, satz(wdh: 3, hin: 2, rueck: 2, von: 170, bis: 50), bis: 11.0)   // zwei fertig, dritte am Gipfel
    k.unterbrechen()
    XCTAssertEqual(k.wiederholungen.count, 2)
    speise(&k, satz(wdh: 2, hin: 2, rueck: 2, von: 170, bis: 50), versatz: 20)
    XCTAssertEqual(k.wiederholungen.count, 4)
}
func testWegdauernStimmen() {
    let w = lauf(satz(wdh: 5, hin: 1.5, rueck: 2.5, von: 170, bis: 50)).wiederholungen[3]
    XCTAssertEqual(w.dauerHin, 1.5, accuracy: 0.25); XCTAssertEqual(w.dauerRueck, 2.5, accuracy: 0.25)
}
func testRuhigVorDemLos() {
    var k = Koerperlage(vorgabe: curl, gemerkterHub: nil)
    for i in 0..<30 { _ = k.verarbeite(t: Double(i) / 30, skelett: armSkelett(ellbogenL: 170, ellbogenR: 170)) }
    XCTAssertTrue(k.istRuhig)
}
```

(`lauf…`-Funktionen sind Helfer in der Testdatei: Instanz anlegen, 1 s Ruhe einspeisen, `los(t:)`, Rest einspeisen.)

- [ ] **Step 3:** `swift test --filter KoerperlageTests` → FAIL.
- [ ] **Step 4:** `Koerperlage` umsetzen.
- [ ] **Step 5:** → PASS.
- [ ] **Step 6:** Commit `feat(koerperbild): Lage und Wiederholungen aus dem Skelett`.

### Task 6: `Uebungstempo` und `Satzrueckblick`

**Files:**
- Create: `Sources/Koerperbild/Uebungstempo.swift`, `Sources/Koerperbild/Satzrueckblick.swift`
- Test: `Tests/KoerperbildTests/UebungstempoTests.swift`, `SatzrueckblickTests.swift`

**Interfaces:**
- Consumes: `Tempovorgabe`, `Sollwelle`, `Weg`, `Lage` (Sensorik, Task 1–2); `Wiederholung` (Task 5).
- Produces:
  - `enum Tempophase: String, Sendable { case senken, halten, heben }`
  - `struct Uebungstempo: Sendable, Equatable { let senken, halten, heben: Double; let beginntMit: Tempophase }`; `init(senken:halten:heben:beginntMit:)` (`beginntMit` nur `.senken` oder `.heben`, sonst `precondition`); `static func standard(beginntMit: Tempophase) -> Uebungstempo` (heben 1,5 / senken 2,5 / halten 0); `var vorgabe: Tempovorgabe` (der erste Weg wird `kraftweg`, der zweite `ablassen`, `halten` bleibt); `func phase(_ weg: Weg) -> Tempophase`; `var inWorten: String` in der Reihenfolge der Bewegung, deutsche Dezimalkommas, ganze Zahlen ohne Komma, Halten 0 entfällt: „3 s senken · 1 s halten · 2 s heben“, „1,5 s heben · 2,5 s senken“.
  - `enum Tempourteil: Sendable, Equatable { case imTempo, zuSchnell, zuLangsam }`
  - `struct Wiederholungsurteil: Sendable, Equatable { let anteilInBahn: Double?; let imTakt: Bool?; let hin: Tempourteil; let rueck: Tempourteil }` (`imTakt == nil` heißt: nicht bewertet, leerer Balken).
  - `struct Rueckblick: Sendable, Equatable { let urteile: [Wiederholungsurteil]; var imTakt: Int; var bewertet: Int; var zuSchnellHin: [Int]; var zuLangsamHin: [Int]; var zuSchnellRueck: [Int]; var zuLangsamRueck: [Int] }` (Listen mit 1-basierten Nummern der Wiederholungen).
  - `struct Satzrueckblick: Sendable` mit `init(welle: Sollwelle, hubWarGemerkt: Bool)`, `mutating func erfasse(_ lage: Lage, sollzeit: TimeInterval)` (Sollzeit = Sekunden seit der letzten Los-Marke), `func ergebnis(wiederholungen: [Wiederholung]) -> Rueckblick?`.
  - Regeln: `ergebnis` ist nil bei weniger als drei Wiederholungen. Je Wiederholung zählen die erfassten Lagen mit `beginn <= lage.t <= ende`; nur `sicher`e gehen in den Anteil ein. Sind weniger als die Hälfte der Lagen einer Wiederholung sicher: `anteilInBahn = nil`, `imTakt = nil`. `imTakt = anteilInBahn >= 0.7`. Die ersten zwei Wiederholungen sind nur bewertet, wenn `hubWarGemerkt`; sonst `imTakt = nil`. `hin`: `dauerHin` gegen `welle.vorgabe.kraftweg`, `rueck`: `dauerRueck` gegen `ablassen`; kürzer als 75 % der Soll-Dauer = `.zuSchnell`, länger als 125 % = `.zuLangsam`. Die Wegurteile gibt es für jede Wiederholung, auch für nicht bewertete; in die Listen des `Rueckblick` gehen nur bewertete ein.

- [ ] **Step 1: Tests schreiben**

```swift
func testKniebeugeBeginntMitSenken() {
    let t = Uebungstempo(senken: 3, halten: 1, heben: 2, beginntMit: .senken)
    XCTAssertEqual(t.vorgabe, Tempovorgabe(kraftweg: 3, ablassen: 2, halten: 1))
    XCTAssertEqual(t.phase(.kraftweg), .senken); XCTAssertEqual(t.phase(.halten), .halten); XCTAssertEqual(t.phase(.ablassen), .heben)
    XCTAssertEqual(t.inWorten, "3 s senken · 1 s halten · 2 s heben")
}
func testCurlBeginntMitHeben() {
    let t = Uebungstempo.standard(beginntMit: .heben)
    XCTAssertEqual(t.vorgabe, Tempovorgabe(kraftweg: 1.5, ablassen: 2.5, halten: 0))
    XCTAssertEqual(t.inWorten, "1,5 s heben · 2,5 s senken")
}
func testSaubererSatzIstGanzImTakt() {
    let r = rueckblick(folgtDerWelle: 8, hubWarGemerkt: true)!
    XCTAssertEqual(r.bewertet, 8); XCTAssertEqual(r.imTakt, 8)
    XCTAssertTrue(r.zuSchnellHin.isEmpty && r.zuLangsamRueck.isEmpty)
}
func testOhneGemerktenHubZaehlenDieErstenZweiNicht() {
    let r = rueckblick(folgtDerWelle: 8, hubWarGemerkt: false)!
    XCTAssertEqual(r.bewertet, 6); XCTAssertNil(r.urteile[0].imTakt); XCTAssertNil(r.urteile[1].imTakt)
}
func testZuSchnelleWiederholungWirdBenannt() {
    // Wiederholung 4: Hinweg 1,5 s statt 3 s, danach wieder im Takt der Welle.
    let r = rueckblick(mitAusreisser: 4, dauerHin: 1.5, soll: Tempovorgabe(kraftweg: 3, ablassen: 2, halten: 0))!
    XCTAssertEqual(r.zuSchnellHin, [4]); XCTAssertEqual(r.urteile[3].imTakt, false); XCTAssertEqual(r.imTakt, 7)
}
func testGenauAnDerToleranzIstImTempo() {
    XCTAssertEqual(urteil(dauer: 2.25, soll: 3), .imTempo)    // 75 %
    XCTAssertEqual(urteil(dauer: 2.2, soll: 3), .zuSchnell)
    XCTAssertEqual(urteil(dauer: 3.75, soll: 3), .imTempo)    // 125 %
    XCTAssertEqual(urteil(dauer: 3.8, soll: 3), .zuLangsam)
}
func testUeberwiegendUnsichereWiederholungBleibtLeer() {
    let r = rueckblick(folgtDerWelle: 6, hubWarGemerkt: true, unsicherIn: 3)!
    XCTAssertNil(r.urteile[2].imTakt); XCTAssertEqual(r.bewertet, 5)
}
func testZuKurzGibtKeinenRueckblick() {
    XCTAssertNil(rueckblick(folgtDerWelle: 2, hubWarGemerkt: true))
}
func testNachPauseGiltDieNeueSollzeit() {
    // Vier Wiederholungen, 10 s Pause, vier weitere mit Sollzeit wieder ab 0: alle im Takt.
    XCTAssertEqual(rueckblickMitPause(vor: 4, pause: 10, nach: 4)!.imTakt, 8)
}
```

- [ ] **Step 2:** → FAIL. **Step 3:** umsetzen. **Step 4:** `swift test --filter "Uebungstempo|Satzrueckblick"` → PASS.
- [ ] **Step 5:** Commit `feat(koerperbild): Uebungstempo und Rueckblick je Wiederholung`.

### Task 7: Erkennung am Mac und Skelett-Dateien der Übungsvideos

**Files:**
- Modify: `apps/ios-member/Packages/Koerperbild/Package.swift` (Targets `KoerperErkennung`, `skelette-rechnen`)
- Create: `Sources/KoerperErkennung/PoseErkenner.swift`, `Sources/skelette-rechnen/main.swift`, `data/koerperbild/skelette/*.skelett.json`, `data/koerperbild/LIESMICH.md`
- Test: `Tests/KoerperbildTests/SkelettDateienTests.swift`
- Vorlage (nur lesen): `PoseKern/PoseErkenner.swift` und `loops-pruefen/main.swift` im Versuch.

**Interfaces:**
- Consumes: `Skelett`, `Skelettfolge` (Task 3).
- Produces:
  - Target `KoerperErkennung` (hängt an `Koerperbild`): `public final class PoseErkenner { public init(); public func erkennen(_ bild: CVPixelBuffer) -> Skelett?; public private(set) var letzterFehler: String? }`. Verhalten wie im Versuch: `VNDetectHumanBodyPoseRequest`, bei mehreren Personen die größte, y von oben gezählt. Die Simulator-Umschaltung des Versuchs bleibt erhalten. `Koerperbild` selbst importiert kein Vision.
  - `swift run -c release skelette-rechnen <Ordner mit mp4> <Ausgabeordner>` schreibt je Video `<Dateiname ohne Endung>.skelett.json` als `Skelettfolge` und gibt je Video eine Zeile `<key> <Bilder> <Anteil erkannt %>` aus.
  - `data/koerperbild/LIESMICH.md`: woher die Dateien stammen, Aufruf, Datum und macOS-Version des Laufs, und dass sie keine echten Personen zeigen.

- [ ] **Step 1: Test schreiben**

```swift
func testFuerJedesKatalogvideoGibtEsEineLesbareSkelettdatei() throws {
    let videos = try FileManager.default.contentsOfDirectory(atPath: wurzel + "/catalog/media/videos").filter { $0.hasSuffix(".mp4") }
    XCTAssertGreaterThan(videos.count, 180)
    for v in videos {
        let pfad = wurzel + "/data/koerperbild/skelette/" + v.replacingOccurrences(of: ".mp4", with: ".skelett.json")
        let folge = try Skelettfolge(daten: Data(contentsOf: URL(fileURLWithPath: pfad)))
        XCTAssertGreaterThan(folge.bilder.count, 20, v); XCTAssertGreaterThan(folge.bildrate, 0, v)
    }
}
```

(`wurzel` = Repo-Wurzel, aus `#filePath` hergeleitet wie in den Berichtstests von `Sensorik`.)

- [ ] **Step 2:** → FAIL (Ordner fehlt).
- [ ] **Step 3:** Targets und Werkzeug anlegen; `swift build -c release` im Package → ohne Fehler.
- [ ] **Step 4:** `swift run -c release skelette-rechnen ../../../../catalog/media/videos ../../../../data/koerperbild/skelette` ausführen (dauert wenige Minuten). Erwartet: eine Zeile je Video, Gesamtgröße des Ordners unter 15 MB (`du -sh`); ist sie größer, Nachkommastellen prüfen.
- [ ] **Step 5:** `swift test --filter SkelettDateienTests` → PASS.
- [ ] **Step 6:** Commit `feat(koerperbild): Erkennung am Mac und Skelette der Uebungsvideos`.

### Task 8: Migration – Kamera- und Tempofelder an `exercises`

**Files:**
- Create: `supabase/migrations/00NN_uebung_kamera_tempo.sql` (NN = höchste vorhandene Nummer + 1; am 24.11. ist das 0077. Vor dem Anlegen `ls supabase/migrations | tail -3` prüfen.)
- Test: `tests/integration/migration-kamera-tempo.test.ts` (Aufbau wie `tests/integration/migration-exercise-muscles.test.ts`)

**Interfaces:**
- Produces: Spalten an `public.exercises`, alle nullable, ohne Default: `kamera_profil text`, `kamera_signal text`, `kamera_seite text`, `tempo_senken_s numeric(3,1)`, `tempo_halten_s numeric(3,1)`, `tempo_heben_s numeric(3,1)`, `tempo_beginnt_mit text`. Prüfregeln (je ein benannter Constraint `exercises_kamera_…` / `exercises_tempo_…`):
  1. `kamera_profil` ∈ {ganzkoerper_stehend, oberkoerper, stuetz_boden, liegend, zug_haengend, ohne_kamera}
  2. `kamera_signal` ∈ {ellbogen, schulter, huefte, knie}; `kamera_seite` ∈ {links, rechts, beide}
  3. Signal und Seite sind genau dann gesetzt, wenn ein Profil gesetzt und nicht `ohne_kamera` ist
  4. `tempo_beginnt_mit` ∈ {senken, heben} und genau dann gesetzt, wenn ein Profil gesetzt ist
  5. die drei Tempowerte alle oder keiner; nur mit Profil
  6. senken und heben in 1,0…4,0, halten in 0,0…3,0, jeweils Vielfache von 0,5
  7. Profil nur bei `volume_kind = 'reps'`
- Keine neue Policy, kein Backfill. Kopfkommentar wie in 0076 mit Verweis auf die Spec.

- [ ] **Step 1: Integrationstest schreiben.** Fälle, je ein `it`: gültige Zeile mit `oberkoerper`/`ellbogen`/`beide`/`heben` und Tempo 2,5/0/1,5 wird angenommen; `ohne_kamera` mit `beginnt_mit` und Tempo, ohne Signal und Seite, wird angenommen; abgelehnt werden: unbekanntes Profil, Profil ohne Signal, `ohne_kamera` mit Signal, Profil ohne `beginnt_mit`, Tempo mit nur zwei Werten, Tempo ohne Profil, `tempo_senken_s = 2.3`, `tempo_halten_s = 3.5`, Profil an einer Übung mit `volume_kind = 'seconds'`. Eine Zeile ganz ohne die neuen Felder bleibt gültig.
- [ ] **Step 2:** `pnpm test:integration -- migration-kamera-tempo` → FAIL (Spalten fehlen).
- [ ] **Step 3:** Migration schreiben, lokal anwenden (`supabase migration up` bzw. der im Repo übliche Weg aus `scripts/`).
- [ ] **Step 4:** → PASS; zusätzlich `pnpm test:integration -- migration-exercise-muscles katalog-key` weiter PASS.
- [ ] **Step 5:** Commit `feat(db): Kameraprofil und Tempo an der Uebung`.

### Task 9: Domäne – Werte, Katalogdatei, Import

**Files:**
- Create: `packages/domain/src/kamera.ts`, `packages/domain/src/kamera.test.ts`
- Modify: `packages/domain/src/index.ts` (Export), `katalog-datei.ts` (`uebungSchema`, `querPruefen`), `katalog-plan.ts` (`UebungZeile`, `UEBUNG_FELDER`, Abbildung bei Zeile 261 ff.), `katalog-import.ts` (Select bei Zeile 91 und Schreiben der Übung)
- Test: `katalog-datei.test.ts`, `katalog-plan.test.ts`, `tests/integration/katalog-import.test.ts`

**Interfaces:**
- Produces in `kamera.ts`:
  - `KAMERA_PROFILE`, `KAMERA_SIGNALE`, `KAMERA_SEITEN`, `TEMPO_BEGINN` als `as const`-Listen mit den Werten aus Task 8.
  - `FREIGESCHALTETE_PROFILE: readonly KameraProfil[] = ["ohne_kamera"]`.
  - Typen `UebungKamera = { profil: KameraProfil; signal: KameraSignal | null; seite: KameraSeite | null; beginntMit: TempoBeginn }`, `UebungTempo = { senkenS: number; haltenS: number; hebenS: number }`.
  - `kameraDateiSchema` (zod, strict): `{ profil, signal: nullable default null, seite: default "beide", beginnt_mit }`; `tempoDateiSchema` (strict): `{ senken_s, halten_s, heben_s }` mit den Grenzen und der 0,5-Rasterung aus Task 8.
  - `kameraFehler(k, tempo, volumeKind, opts: { nurFreigeschaltet: boolean }): string[]`: dieselben Regeln wie die Datenbank (Signal-Pflicht, Seite bei `ohne_kamera` wird null, Tempo nur mit Kamera, nur `reps`) plus „Profil ist noch nicht freigeschaltet“.
  - `kameraSpalten(k, tempo)`: liefert die sieben Spaltenwerte (snake_case) für Insert/Update; ohne Kamera alle null.
  - `kameraAusZeile(z): { kamera: UebungKamera | null; tempo: UebungTempo | null }` aus den sieben Spalten; numerische Spalten können als String ankommen (`"2.5"`) und werden zu Zahlen.
- `uebungSchema` bekommt `kamera: kameraDateiSchema.optional()` und `tempo: tempoDateiSchema.optional()`. `querPruefen` ruft `kameraFehler(..., { nurFreigeschaltet: true })` und stellt jeder Meldung Index und Schlüssel voran wie die übrigen Meldungen.
- `UebungZeile` und `UEBUNG_FELDER` in `katalog-plan.ts` um die sieben Spalten erweitert; der Import schreibt und vergleicht sie.

- [ ] **Step 1: Tests schreiben.** `kamera.test.ts`:

```ts
it("ohne_kamera braucht kein Signal und bekommt keine Seite", () => {
  expect(kameraFehler({ profil: "ohne_kamera", signal: null, seite: "beide", beginnt_mit: "heben" }, undefined, "reps", { nurFreigeschaltet: true })).toEqual([]);
  expect(kameraSpalten({ profil: "ohne_kamera", signal: null, seite: "beide", beginnt_mit: "heben" }, undefined)).toMatchObject({ kamera_signal: null, kamera_seite: null, tempo_beginnt_mit: "heben", tempo_senken_s: null });
});
it("Kameraprofil ohne Signal ist ein Fehler", () => {
  expect(kameraFehler({ profil: "oberkoerper", signal: null, seite: "beide", beginnt_mit: "heben" }, undefined, "reps", { nurFreigeschaltet: false })).toHaveLength(1);
});
it("nicht freigeschaltetes Profil wird nur mit nurFreigeschaltet abgelehnt", () => {
  const k = { profil: "oberkoerper", signal: "ellbogen", seite: "beide", beginnt_mit: "heben" } as const;
  expect(kameraFehler(k, undefined, "reps", { nurFreigeschaltet: false })).toEqual([]);
  expect(kameraFehler(k, undefined, "reps", { nurFreigeschaltet: true })[0]).toMatch(/freigeschaltet/);
});
it("Tempo ohne Kamera und Kamera bei Sekunden-Uebungen sind Fehler", () => {
  expect(kameraFehler(undefined, { senken_s: 3, halten_s: 1, heben_s: 2 }, "reps", { nurFreigeschaltet: false })).toHaveLength(1);
  expect(kameraFehler({ profil: "ohne_kamera", signal: null, seite: "beide", beginnt_mit: "heben" }, undefined, "seconds", { nurFreigeschaltet: false })).toHaveLength(1);
});
it("Tempo ausserhalb des Rasters scheitert am Schema", () => {
  expect(tempoDateiSchema.safeParse({ senken_s: 2.3, halten_s: 0, heben_s: 2 }).success).toBe(false);
  expect(tempoDateiSchema.safeParse({ senken_s: 3, halten_s: 3.5, heben_s: 2 }).success).toBe(false);
  expect(tempoDateiSchema.safeParse({ senken_s: 3, halten_s: 0, heben_s: 2 }).success).toBe(true);
});
it("kameraAusZeile liest Zahlen auch aus Strings und gibt null ohne Profil", () => {
  expect(kameraAusZeile({ kamera_profil: null, kamera_signal: null, kamera_seite: null, tempo_senken_s: null, tempo_halten_s: null, tempo_heben_s: null, tempo_beginnt_mit: null })).toEqual({ kamera: null, tempo: null });
  expect(kameraAusZeile({ kamera_profil: "ohne_kamera", kamera_signal: null, kamera_seite: null, tempo_senken_s: "2.5", tempo_halten_s: "0.0", tempo_heben_s: "1.5", tempo_beginnt_mit: "heben" }).tempo).toEqual({ senkenS: 2.5, haltenS: 0, hebenS: 1.5 });
});
```

`katalog-datei.test.ts`: (a) eine Übung mit `kamera: { profil: "ohne_kamera", beginnt_mit: "senken" }` und `tempo` wird angenommen; (b) `tempo` ohne `kamera` liefert eine Meldung, die Index und Schlüssel der Übung enthält; (c) `kamera.profil: "oberkoerper"` wird als nicht freigeschaltet abgelehnt; (d) vertipptes Feld `kamera.signl` scheitert (strict). `katalog-plan.test.ts`: eine geänderte `tempo`-Angabe erscheint in `felder` der Übung; ohne Angaben sind alle sieben Spalten null. `tests/integration/katalog-import.test.ts`: nach dem Import einer Datei mit `ohne_kamera` + Tempo stehen die Werte in `exercises`; ein zweiter Import ohne Änderung schreibt nichts.

- [ ] **Step 2:** `pnpm --filter @fitretro/domain test -- kamera katalog-datei katalog-plan` → FAIL.
- [ ] **Step 3:** Umsetzen.
- [ ] **Step 4:** Dieselben Tests PASS; `pnpm --filter @fitretro/domain typecheck` ohne Fehler; `pnpm test:integration -- katalog-import` PASS; die echte Datei bleibt gültig: der bestehende Test, der `catalog/gymtavo.json` prüft, bleibt grün.
- [ ] **Step 5:** Commit `feat(katalog): Kameraprofil und Tempo in Katalogdatei und Import`.

### Task 10: Ausgabe an App und Portal

**Files:**
- Modify: `packages/domain/src/bootstrap.ts` (Typ `Uebung`, `UebungZeile`, `uebungAusZeile`, Select bei Zeile 483), `machine-context.ts` (Typ bei Zeile 75, Zeile 237, Select 297, Abbildung 328), `catalog.ts` (Typ bei 1233, Select 1351, Zeilentyp 1383, Abbildung 1418)
- Test: `packages/domain/src/bootstrap.test.ts`, die bestehenden Tests zu `machine-context` und `catalog` an den Stellen, die heute `geraetLabel` prüfen; `tests/integration/domain-bootstrap-katalog.test.ts`

**Interfaces:**
- Consumes: `kameraAusZeile`, `UebungKamera`, `UebungTempo` (Task 9).
- Produces: Überall, wo eine Übung heute `geraetLabel` trägt, trägt sie zusätzlich `kamera: UebungKamera | null` und `tempo: UebungTempo | null` (camelCase im JSON: `kamera.beginntMit`, `tempo.senkenS`). Die Selects lesen die sieben Spalten mit.

- [ ] **Step 1: Tests schreiben.** In `bootstrap.test.ts`: die bestehende Erwartung an `uebungAusZeile` um `kamera: null, tempo: null` ergänzen; neuer Fall:

```ts
expect(uebungAusZeile({ id: "e1", name: "Kniebeuge", description: null, volume_kind: "reps", target_min: 8, target_max: 12,
  kamera_profil: "ganzkoerper_stehend", kamera_signal: "knie", kamera_seite: "beide",
  tempo_senken_s: "3.0", tempo_halten_s: "1.0", tempo_heben_s: "2.0", tempo_beginnt_mit: "senken" }))
  .toMatchObject({ kamera: { profil: "ganzkoerper_stehend", signal: "knie", seite: "beide", beginntMit: "senken" }, tempo: { senkenS: 3, haltenS: 1, hebenS: 2 } });
```

Entsprechend je ein Fall für Tag-Kontext und Katalog-Liste. Integration: Eine Übung mit gesetzten Spalten kommt im Bootstrap mit `kamera` und `tempo` an.

- [ ] **Step 2:** → FAIL. **Step 3:** umsetzen. **Step 4:** `pnpm --filter @fitretro/domain test` und `pnpm typecheck` (ganzes Repo: API und Portal übersetzen mit dem erweiterten Typ; Testdaten in `apps/web` wie `typVorlage.test.ts` und `gymtavo.test.ts` um `kamera: null, tempo: null` ergänzen) → PASS; `pnpm test:integration -- domain-bootstrap` → PASS.
- [ ] **Step 5:** Commit `feat(api): Kameraprofil und Tempo in Bootstrap, Tag-Kontext und Katalog`.

### Task 11: App-Modell

**Files:**
- Modify: `apps/ios-member/project.yml` (Package `Koerperbild` wie `Sensorik` eintragen, für App- und Test-Target), danach `xcodegen` im Ordner `apps/ios-member`; `FitnessMember/Networking/DTOs/BootstrapResponse.swift` (`Exercise`, `CodingKeys`, `init(from:)`), `TagContextResponse.swift` (dieselbe Ergänzung an der Stelle, die heute `geraetLabel` dekodiert)
- Create: `FitnessMember/Workout/Kamera/UebungKamera.swift`
- Test: `apps/ios-member/FitnessMemberTests/UebungKameraTests.swift` (Ordner und Stil der bestehenden DTO-Tests)

**Interfaces:**
- Consumes: `Kameravorgabe`, `Kameraprofil`, `Gelenkwinkel`, `Seitenwahl`, `Uebungstempo`, `Tempophase` (Koerperbild).
- Produces:
  - `BootstrapResponse.Exercise` bekommt `var kamera: KameraDTO? = nil` und `var tempo: TempoDTO? = nil`; `struct KameraDTO: Decodable, Equatable { let profil: String; let signal: String?; let seite: String?; let beginntMit: String }`, `struct TempoDTO: Decodable, Equatable { let senkenS: Double; let haltenS: Double; let hebenS: Double }`. Dekodiert mit `decodeIfPresent`; ein kaputtes Unterobjekt macht das Feld nil, nicht die ganze Antwort ungültig.
  - `UebungKamera.swift`: `extension BootstrapResponse.Exercise { var kameravorgabe: Kameravorgabe?; var uebungstempo: Uebungstempo? }`. `kameravorgabe` ist nil, wenn `volumeKind != .reps`, `kamera == nil`, das Profil unbekannt ist, oder ein Kameraprofil ohne bekanntes Signal kommt. `uebungstempo` ist nil ohne `kameravorgabe`; sonst aus `tempo`, ohne `tempo` `Uebungstempo.standard(beginntMit:)`; unbekanntes `beginntMit` → nil für beide.

- [ ] **Step 1: Tests schreiben**

```swift
func testAlterServerOhneFelder() throws {
    let u = try dekodiere(#"{"id":"e1","name":"Curl","volumeKind":"reps","targetMin":8,"targetMax":12}"#)
    XCTAssertNil(u.kamera); XCTAssertNil(u.kameravorgabe); XCTAssertNil(u.uebungstempo)
}
func testKniebeugeMitTempo() throws {
    let u = try dekodiere(#"{"id":"e1","name":"Kniebeuge","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"ganzkoerper_stehend","signal":"knie","seite":"beide","beginntMit":"senken"},"tempo":{"senkenS":3,"haltenS":1,"hebenS":2}}"#)
    XCTAssertEqual(u.kameravorgabe, Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide))
    XCTAssertEqual(u.uebungstempo, Uebungstempo(senken: 3, halten: 1, heben: 2, beginntMit: .senken))
}
func testOhneTempoGiltDerStandard() throws {
    let u = try dekodiere(#"{"id":"e1","name":"Curl","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"ohne_kamera","signal":null,"seite":null,"beginntMit":"heben"}}"#)
    XCTAssertEqual(u.kameravorgabe?.profil, .ohneKamera)
    XCTAssertEqual(u.uebungstempo, .standard(beginntMit: .heben))
}
func testUnbekanntesProfilVomNeuerenServer() throws {
    let u = try dekodiere(#"{"id":"e1","name":"X","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"kopfstand","signal":"knie","seite":"beide","beginntMit":"heben"}}"#)
    XCTAssertNil(u.kameravorgabe); XCTAssertNil(u.uebungstempo)
}
func testKaputtesKameraObjektLaesstDieUebungLeben() throws {
    let u = try dekodiere(#"{"id":"e1","name":"X","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":7}}"#)
    XCTAssertEqual(u.name, "X"); XCTAssertNil(u.kamera)
}
func testSekundenUebungHatNieEineVorgabe() throws {
    let u = try dekodiere(#"{"id":"e1","name":"Plank","volumeKind":"seconds","targetMin":30,"targetMax":60,"kamera":{"profil":"ohne_kamera","signal":null,"seite":null,"beginntMit":"heben"}}"#)
    XCTAssertNil(u.kameravorgabe)
}
```

- [ ] **Step 2:** Tests bauen → FAIL (Felder fehlen). Befehl wie in den bestehenden Plänen der App: `xcodebuild test -project apps/ios-member/FitnessMember.xcodeproj -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FitnessMemberTests/UebungKameraTests` (Gerätename an den vorhandenen Simulator anpassen).
- [ ] **Step 3:** Umsetzen.
- [ ] **Step 4:** Derselbe Befehl → PASS; ein Lauf der ganzen `FitnessMemberTests` → PASS.
- [ ] **Step 5:** Commit `feat(ios): Kameraprofil und Tempo im App-Modell`.

### Task 12: Zuordnungsvorschlag für Tim

**Files:**
- Create: `data/koerperbild/versuch-2026-11-23.csv` (Kopie von `.claude/worktrees/kamera-versuch/tools/kamera-versuch/ergebnis/ergebnis.csv`), `tools/kamera-zuordnung/vorschlag.py`, `data/koerperbild/zuordnung.json`, `docs/kamera-zuordnung-2026-11.md`
- Test: `packages/domain/src/kamera-zuordnung.test.ts`

**Interfaces:**
- Consumes: `kameraDateiSchema`, `tempoDateiSchema`, `kameraFehler` (Task 9).
- Produces:
  - `zuordnung.json`: `{ "<exercise key>": { "kamera": { "profil", "signal", "seite", "beginnt_mit" }, "tempo": { "senken_s", "halten_s", "heben_s" }, "grund": "<ein Satz>" } }` für jede Übung mit `volume_kind: "reps"`; Übungen auf Zeit fehlen.
  - Regeln des Skripts, in dieser Reihenfolge:
    1. Kein Video, oder der Versuch urteilte nicht „zählt richtig“ → `ohne_kamera`, Grund nennt das Urteil.
    2. Der Name enthält „abwechselnd“, „im Wechsel“ oder „alternierend“ → `ohne_kamera` (Spec, Entscheidung 22).
    3. Signal = führendes Gelenk des Versuchs ohne Seite („Ellbogen links“ → `ellbogen`); `seite` immer `beide`.
    4. Profil: Gerätegruppe `eigengewicht` und Signal `ellbogen` mit „stütz“/„push“/„dip“ im Schlüssel oder Namen → `stuetz_boden`; Schlüssel oder Name mit Bank, Crunch, Beinheben, liegend → `liegend`; Klimmzug/Latzug (`pullup`, `chinup`, `lat_pulldown`) → `zug_haengend`; Signal `knie` oder `huefte` bei Gruppe `freihantel`, `kettlebell`, `eigengewicht`, `gummiband` → `ganzkoerper_stehend`; Signal `ellbogen` oder `schulter` sonst → `oberkoerper`.
    5. **Sitzende und liegende Beingeräte** (Gruppe `geraete`, Signal `knie` oder `huefte`: Beinstrecker, Beinbeuger, Beinpresse, Wadenheben sitzend …) passen in keins der sechs Profile → `ohne_kamera` mit Grund „kein Profil für Beingeräte im Sitzen“. Das ist ein offener Punkt für Tim, siehe Kopf der Liste.
    6. `beginnt_mit`: `senken` bei Kniebeuge, Ausfallschritt, Bankdrücken und Brustpresse mit freien Gewichten, Liegestütz, Dip, rumänischem Kreuzheben, Good Morning; sonst `heben`. Die Schlüsselmuster stehen als Liste oben im Skript.
    7. Tempo: Profil `ganzkoerper_stehend` → 3 / 1 / 2 (senken / halten / heben); alle anderen → 2,5 / 0 / 1,5.
  - `docs/kamera-zuordnung-2026-11.md`: Kopf mit Zählung je Profil, der Liste der Übungen aus Regel 5 und dem Satz, dass nichts davon im Katalog steht, bevor Tim die Liste gesehen und das Profil den Gütetest bestanden hat; darunter eine Tabelle je Profil: Übung, Gerät, Signal, beginnt mit, Tempo, Grund.

- [ ] **Step 1: Test schreiben**

```ts
const zuordnung = JSON.parse(readFileSync(resolve(wurzel, "data/koerperbild/zuordnung.json"), "utf8"));
const katalog = JSON.parse(readFileSync(resolve(wurzel, "catalog/gymtavo.json"), "utf8"));
it("deckt genau die Uebungen mit Wiederholungen ab", () => {
  const reps = katalog.exercises.filter((u: any) => u.volume_kind === "reps").map((u: any) => u.key).sort();
  expect(Object.keys(zuordnung).sort()).toEqual(reps);
});
it("jeder Eintrag besteht Schema und Regeln (ohne Freischalt-Liste)", () => {
  for (const [key, e] of Object.entries<any>(zuordnung)) {
    const k = kameraDateiSchema.parse(e.kamera); const t = tempoDateiSchema.parse(e.tempo);
    expect(kameraFehler(k, t, "reps", { nurFreigeschaltet: false }), key).toEqual([]);
    expect(e.grund.length, key).toBeGreaterThan(0);
  }
});
it("was der Versuch nicht richtig zaehlte, startet ohne Kamera", () => {
  expect(zuordnung["leg_press_45"].kamera.profil).toBe("ohne_kamera");
});
```

- [ ] **Step 2:** → FAIL (Datei fehlt).
- [ ] **Step 3:** CSV kopieren, Skript schreiben, `python3 tools/kamera-zuordnung/vorschlag.py` ausführen (schreibt JSON und Markdown, druckt die Zählung je Profil).
- [ ] **Step 4:** `pnpm --filter @fitretro/domain test -- kamera-zuordnung` → PASS. Die Liste einmal ganz lesen: Fällt eine Übung offensichtlich ins falsche Profil, die Regel im Skript schärfen und neu erzeugen, nicht die Ausgabe von Hand ändern.
- [ ] **Step 5:** Commit `docs(katalog): Zuordnungsvorschlag Kameraprofil und Tempo`.

### Task 13: Gütetest Stufe 1 – Bericht über die Übungsvideos

**Files:**
- Create: `apps/ios-member/Packages/Koerperbild/Tests/KoerperbildTests/ProfilBerichtTests.swift`, `data/koerperbild/profilbericht.md` (vom Test geschrieben)
- Vorlage für den Aufbau: die Berichtstests in `Packages/Sensorik/Tests/SensorikTests` (`WinkelBerichtTests`).

**Interfaces:**
- Consumes: `Skelettfolge` (Task 3), `Kameravorgabe`, `Erkennungspruefung` (Task 4), `Koerperlage` (Task 5), `data/koerperbild/skelette` (Task 7), `data/koerperbild/zuordnung.json` (Task 12).
- Produces: `profilbericht.md` mit Datum, einer Zeile je Profil (Videos, davon richtig gezählt, Anteil, Median des Anteils der Bilder mit allen Pflichtgelenken, „Stufe 1 bestanden: ja/nein“) und darunter je Profil die Liste der Videos, die nicht stimmen (gezählt / erwartet, Anteil Pflichtgelenke, führende Seite).
  - Ablauf je Video mit einem Kameraprofil außer `ohne_kamera`: die Skelettfolge sechsmal hintereinander abspielen (Zeit aus `bildrate`), 1 s Ruhe mit dem ersten Bild davor, `los`, dann durch `Koerperlage` (ohne gemerkten Hub). Erwartet: 5 oder 6 gezählte Wiederholungen (der Schnitt des Loops kann eine halbe Wiederholung kosten); „richtig“ heißt eins von beiden.
  - Anteil Pflichtgelenke: Anteil der Bilder, in denen alle Pflichtgelenke der führenden Seite sicher sind.
  - Bestanden: mindestens 90 % der Videos des Profils richtig **und** Median des Pflichtgelenk-Anteils mindestens 95 %.
  - Der Test selbst schlägt nur fehl, wenn eine Datei fehlt oder nicht lesbar ist oder ein Profil gar kein Video hat – nicht, wenn ein Profil die Messlatte verfehlt. Das Urteil trifft Tim anhand des Berichts.

- [ ] **Step 1:** Test schreiben; zusätzlich eine Zusicherung, dass der Bericht für jedes der fünf Kameraprofile mit mindestens einem zugeordneten Video eine Zeile enthält.
- [ ] **Step 2:** `swift test --filter ProfilBerichtTests` → PASS, Bericht liegt unter `data/koerperbild/profilbericht.md`.
- [ ] **Step 3:** Bericht lesen. Zählt ein Profil unter 90 %, die drei schlechtesten Videos mit den Tests aus Task 5 vergleichen: Liegt es an einer Regel der `Koerperlage` (Schwelle, Seite, Entfalten), dort mit einem neuen Kunstsignal-Test nachschärfen und den Bericht neu erzeugen. Liegt es am Signal der Zuordnung, die Regel in Task 12 ändern. Kein Abstimmen einzelner Videos.
- [ ] **Step 4:** Ganze Suiten: `swift test` in `Packages/Koerperbild` und `Packages/Sensorik`, `pnpm --filter @fitretro/domain test`, `pnpm typecheck` → alle PASS.
- [ ] **Step 5:** Commit `feat(koerperbild): Profilbericht Stufe 1 ueber die Uebungsvideos`.

---

## Stand nach der Umsetzung (24. November 2026)

Alle 13 Tasks sind auf `claude/kamera-kern-katalog` umgesetzt, einzeln geprüft und nach einer Schlussprüfung nachgebessert.

**Geprüft:** `swift test` Koerperbild 69 Tests, Sensorik 235 Tests, Domain 774 Tests, Typprüfung im ganzen Repo, App-Tests 2079 im Simulator.
**Nicht geprüft, erst in der CI:** die Integrationstests gegen Postgres (`migration-kamera-tempo`, Kamera-Fälle in `katalog-import` und `domain-bootstrap-katalog`) und der Linux-Build von `Packages/Koerperbild`. Lokal lief kein Supabase.

**Reihenfolge beim Ausrollen:** Migration 0077 muss auf Prod liegen, bevor die API mit diesem Stand deployt wird. Die Selects in `bootstrap.ts`, `machine-context.ts`, `catalog.ts` und `katalog-import.ts` nennen die neuen Spalten; fehlen sie, liefert die API still keine Übungen.

**Abweichungen vom Plan, in der Umsetzung entschieden:**
- Zählregel in Task 5 (siehe dort): gezählt wird bei Rückkehr auf Lage ≤ 0,15, ersatzweise beim Wiederanstieg.
- Der Typ heißt `Koerperwiederholung` (nicht `Wiederholung`), weil `Sensorik` schon einen Typ dieses Namens hat.
- `Lage.richtung` bleibt `.rueck` bis zum Tal.
- Wegurteile im Rückblick rechnen die Haltezeit als Spielraum nach oben ein: im Tempo von 0,75·Weg bis 1,25·(Weg + Halten).
- `Erkennungspruefung.seiteFesthalten(_:)` richtet die Prüfung auf die Seite aus, die gezählt wird.
- `Koerperlage` behandelt einen gemerkten Hub unter 20° oder nicht endlich wie keinen und meldet `hubWarGemerkt`.
- Die Zuordnungsregeln wurden fachlich geschärft: Schulterheben, Handgelenk, Wadenheben, Schulterrotation, Crunch an Kabel und Gerät, Bird Dog, Arm-Isolation mit fremdem Signal und gehende Übungen starten ohne Kamera.

**Vermerke für den Plan E3 + E4:**
- Der Kamera-Ablauf ruft `Erkennungspruefung.seiteFesthalten(koerperlage.fuehrendeSeite)`, sobald die Seite feststeht.
- `Koerperlage.init` verlangt eine Vorgabe mit Signal (`precondition`); bei `ohne_kamera` nicht aufrufen.
- Kameravorgabe und Tempo kommen aus `station.exercises` (Bootstrap); `TagContextResponse.Exercise` trägt sie nicht.
- `Satzrueckblick` bekommt `hubWarGemerkt` aus `Koerperlage`; die Listen sprechen von Hin- und Rückweg, die Anzeige übersetzt mit `Uebungstempo.phase(_:)`.
- Die letzte Wiederholung eines Satzes zählt nicht, wenn die Rückkehr unvollständig bleibt und keine Bewegung mehr folgt. Im Studio messen.
- Bei `Seitenwahl.beide` kann ein unruhig erkannter ruhender Arm die Seitenwahl verfälschen. Im Studio messen.

**Zurückgestellte Kleinigkeiten** (von der Schlussprüfung als unkritisch eingestuft): Rundlauf-Test für die Kodierung mit Haltezeit; Tests für Rundung und Fehlerpfad der `Skelettfolge`; rückwärts laufende Zeit in der Erkennungsprüfung; wiederholter Block in `Koerperlage`; Wertelisten- und Grenztests der Migration; Raster-Toleranz 1e-6 in `kamera.ts`; nicht exportierte Hilfstypen in `index.ts`; Mocks prüfen den Select-String nicht; CI-Job heißt weiter `sensorik`; LIESMICH nennt die Videos „KI-erzeugt“ ohne Beleg im Repo; `profilbericht.md` wird in der CI nicht gegen den eingecheckten Stand geprüft.

## Nach diesem Plan

- Tim liest `docs/kamera-zuordnung-2026-11.md` und `data/koerperbild/profilbericht.md` und entscheidet über die Beingeräte im Sitzen (Regel 5 in Task 12): eigenes siebtes Profil oder vorerst ohne Kamera.
- Push und PR erst auf Tims Wort. Migration auf Prod erst auf Tims ausdrückliche Freigabe.
- Nächste Pläne: E3 + E4 (Kamera-Ablauf, Fehlerfälle, Sichern), danach E5 + E6 (übrige Profile, Gütetest im Studio, Portal).
