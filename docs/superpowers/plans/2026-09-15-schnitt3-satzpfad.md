# Schnitt 3: Satzpfad am Gerät — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Am Gerät wird sofort gescrollt: beide Räder sind immer aktiv, der Tap zum Öffnen fällt weg, und mit ihm `GeraetModel.radOffen`. Rückblick („Zuletzt 77,5 kg × 11“) und Empfehlung („Vorschlag · +2,5“) stehen nicht mehr unter dem Rad, sondern in einem Drawer, der beim Öffnen des Geräts von unten kommt — nur vor dem ersten Satz eines Geräteblocks, beim ersten Mal an diesem Gerät gar nicht. Die Einstellwerte gibt es nur noch als schmale Zeile. Der ganze Satzpfad (Kopf, Gerät, Einstellwerte, beide Räder, „Satz N sichern“, „Gerät abschließen“, „Problem melden“) passt ohne Scrollen der Seite auf ein 667-pt-iPhone bei Standard-Schriftgröße.

**Architecture:** Reiner Client, kein Server. Ein Grund für alles: `radOffen` verschwindet, und damit fällt alles, was am geschlossenen Zustand hing — die Karte mit großen Einstellwerten, „Zuletzt“ unter dem Rad, der Vorschlag in der Kontextzeile, der Tap-Gesture in `WertZeile`, das `offen`-Argument von `RastRad`. Zwei Ableitungen tragen den Umbau und bekommen ihren Test vor dem View: `GeraetModel.rueckblickFaellig` (wann der Drawer kommt) und `RastRad.nachbarstufe(phase:sichtbareZeilen:)` (wie ein Rad mit drei statt fünf Zeilen seine Nachbarn zeigt). Das Höhenbudget ist aus den Schriftmetriken gerechnet, nicht geschätzt (Task 5), und wird im Sichtcheck auf einem SE-Simulator nachgemessen (Task 7). Entschieden am 15. September.

**Tech Stack:** Swift 6 / SwiftUI / Swift Testing / XcodeGen (`apps/ios-member`). Keine Änderung an `packages/domain` oder `apps/web`.

**Quelle:** `docs/superpowers/plans/2026-09-12-ios-verbesserungen-aus-dem-betrieb.md`, Punkte 11, 12, 13, „Schnitt 3 — Satzpfad am Gerät“ und „Was wovon abhängt“ (12 und 13 hängen an 11). Vorbild für Aufbau und Ton: `docs/superpowers/plans/2026-09-15-schnitt2-training-tab.md`, samt seiner Nachträge.

## Global Constraints

- **Kommentare in Swift ohne Umlaute** (ASCII). Nutzertexte tragen Umlaute.
- **Kommentare begründen, sie beschreiben nicht.** Wird durch den Umbau ein Kommentar falsch, wird er im selben Task umgeschrieben, nicht stehen gelassen. Betroffen sind mindestens: der Typkommentar von `GeraetView` („dieselbe Silhouette in Ruhe und Offen“), der von `RastRad` („Ruhe und Offen sind derselbe Aufbau“), der von `WertZeile` („Ein Tap auf EINE der beiden Zahlen oeffnet BEIDE Raeder“), `GeraetView.einstellung` („Schrumpft auf eine Zeile, sobald die Raeder offen sind“), `GeraetModel.gewichtVomNutzer` („Sobald das Mitglied das Rad geoeffnet hat“) und der Kommentar an `PrimaryButton` in `aktionen` („Bleibt im offenen Zustand sichtbar“).
- **Design-Tokens aus `DesignSystem.swift`**, nie als Literal: `bg`, `surface`, `surfaceRaised`, `line`, `text`, `textMuted`, `textFaint`, `accent`, `warn`, `danger`. Radien `card` 12, `neben` 14, `haupt` 16. Abstände 4/8/12/16/24/32/48. Ausnahme wie im Bestand: die horizontale Seitenkante 20.
- **Eine Akzentfläche pro Screen** (designsystem.md §2). Im Eingabezustand ist es „Satz N sichern“. Der Drawer trägt keine: sein Knopf ist ein `SecondaryButton`. Die Rastlinie unter dem Rad ist Akzent als Linie, keine Fläche, wie bisher.
- **Hit-Targets nie unter 44 pt.** „ändern“ und „Problem melden“ bleiben 44 pt hoch, auch wenn ihre Zeile schmal aussieht.
- **Die App misst nichts** (§10). „Vorschlag · +2,5“ ist eine Rechnung, keine Empfehlung; im Drawer steht derselbe Text wie vorher in der Kontextzeile, nichts Neues. Beim ersten Mal an einem Gerät steht nirgends ein Vorschlag.
- **Swift-Tests mit Swift Testing** (`import Testing`, `@Test`, `#expect`), als `struct`-Suite. Tests beweisen Ableitungen und Werte, nicht Sichtbarkeit und Höhe — die prüft der Sichtcheck (Task 7) mit Screenshots.
- **Neue Swift-Dateien:** `project.yml` zieht Verzeichnisse, nach dem Anlegen `xcodegen generate` in `apps/ios-member`. Danach nie blind `git add -u`: `git status` vor jedem Commit, `Package.resolved` muss unangetastet bleiben (Schnitt-2-Lehre).
- **Reihenfolge:** Jede Ableitung kommt mit ihrem Test vor dem View, der sie benutzt.
- **iOS-Tests:** in `apps/ios-member`
  `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  (einen anderen iPhone-Simulator gibt es auf dem Rechner nicht; für 667 pt legt Task 7 einen iPhone-SE-Simulator an und löscht ihn danach). Einzelne Suite: `-only-testing:FitnessMemberTests/<Suite>`. Vor jedem vollen Build `df -h /` — am 15. September waren 4,6 GB frei, das reicht knapp; eigene DerivedData-Ordner unter `~/Library/Developer/Xcode/DerivedData/FitnessMember-*` bei Bedarf aufräumen. Grün vor dem nächsten Task.
- **Ein Commit je Task**, deutsche Message im Stil der Historie mit ae/oe/ue (`feat(geraet): …`, `fix(geraet): …`, `docs: …`). Trailer genau so, wörtlich, und nach jedem Commit mit `git log -1 --format=%B` geprüft:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  ```
- **Nicht pushen.**
- **Sichtcheck nur gegen das lokale Backend**, nie gegen Produktion. `Config.xcconfig` zeigt auf Produktion und bleibt unangetastet; die Umleitung geschieht über xcodebuild-Overrides (Task 7).

---

## Task 1: Einstellwerte nur noch als Zeile (Punkt 13)

Heute schaltet `GeraetView.einstellung` über `radOffen` zwischen einer schmalen Zeile („Sitzposition 4 · Rückenlehne 2 · ändern“) und einer Karte mit großen Zahlen um. Es bleibt die Zeile — sie ist 44 pt hoch, die Karte 71 (16 + 13 + 4 + 22 + 16), und Punkt 12 braucht jeden Punkt. Dieser Task geht zuerst, weil er `radOffen` an dieser Stelle schon abhängt, ohne die Eigenschaft anzurühren; Task 3 räumt sie dann ab, ohne hier noch entscheiden zu müssen.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`einstellung`, Z. 202–239)

**Interfaces:**
- Produces: keine neuen Typen. `einstellung` liest `radOffen` nicht mehr.

- [x] **Step 1: `einstellung` auf die Zeile reduzieren.** Der `if modell.radOffen`-Zweig bleibt als einziger Inhalt, der `else`-Zweig (Karte mit `ForEach`, `wertSekundaer`, `surface`-Hintergrund) entfällt. Der Kommentar „Schrumpft auf eine Zeile, sobald die Raeder offen sind …“ wird falsch und wird ersetzt:

```swift
/// Eine Zeile, nicht die Karte: derselbe Inhalt stand vorher in zwei
/// Gestalten (Sammelstelle Punkt 13), und die Karte mit grossen Zahlen kostete
/// 71 pt, die der Satzpfad auf einem 667-pt-iPhone nicht hat (Punkt 12).
/// Die Zeile ist 44 pt hoch, weil "aendern" es ist -- ein Hit-Target unter
/// 44 pt gibt es nicht.
@ViewBuilder
private var einstellung: some View {
    if !modell.einstellwerte.isEmpty {
        HStack {
            Text(modell.einstellwerte.map { "\($0.label) \($0.anzeige)" }
                .joined(separator: " · "))
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .lineLimit(1)
            Spacer()
            aendernKnopf
        }
    }
}
```

- [x] **Step 2: Bauen und Tests.** `xcodebuild test …` grün (kein Test hängt an der Karte; `DesignSystem.Typography.wertSekundaer` bleibt, es hat sieben andere Nutzer).

- [x] **Step 3: Commit** — `feat(geraet): Einstellwerte nur noch als Zeile`

---

## Task 2: Der Rückblick ist eine Ableitung mit Regel (Punkt 11, Modell)

Was der Drawer sagt und wann er kommt, entscheidet das Modell, nicht der View. Heute stehen `zuletztText` („Zuletzt 77,5 kg × 11“) und `vorschlagText` getrennt und nur im geschlossenen Zustand. Daraus wird ein `Rueckblick`, und die Regel „wann kommt der Drawer“ wird `rueckblickFaellig` mit Test.

Die Regel, wie in der Sammelstelle festgelegt:

1. **Nur vor dem ersten Satz des Geräteblocks** — `satzNummer == 1`. `satzNummer` liest live aus der lokalen Session (`WorkoutSessionStore.naechsterSetIndex`), kennt also auch einen Satz, den `bootstrap` noch nicht kennt. Im Zirkel zurück am selben Gerät entsteht über die Blockliste ein frisches `GeraetModel`, und dort ist der erste Satz längst gesichert: kein Drawer.
2. **Beim ersten Mal an diesem Gerät gar nicht** — ohne letzten Satz gibt es keinen `Rueckblick` (und ohne letzten Satz auch keinen Vorschlag: `suggestion.inputs.currentWeightKg` ist der letzte Satz).
3. **Einmal beim Öffnen des Screens**, nicht nach jedem Satz und nicht beim Übungswechsel: `geraetGeoeffnet()` ist der einzige Aufrufer, der `rueckblickOffen` auf `true` setzt. Ein Übungswechsel stellt das Rad ohnehin auf den letzten Wert der neuen Übung; ein zweiter Drawer wäre eine Karte, die den Pfad wieder höher macht.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (`zuletztText` Z. 323–328 entfällt; neu `Rueckblick`, `rueckblick`, `rueckblickFaellig`, `rueckblickOffen`, `geraetGeoeffnet()`)
- Modify: `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift` (Z. 47 und neue Tests)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/WertZeile.swift` (Z. 34–38, der `zuletzt`-Block entfällt, sonst bricht der Build)

**Interfaces:**
- Produces:
  - `struct Rueckblick: Equatable { let zuletzt: String; let vorschlag: String? }` — auf Dateiebene neben `Einstellwert`, wie `GeraetUebung`. `zuletzt` ist `"77,5 kg × 11"` (ohne das Wort „Zuletzt“, das trägt der Drawer als Label), `vorschlag` ist `vorschlagText`.
  - `GeraetModel.rueckblick: Rueckblick?` — `nil` ohne letzten Satz für (Gerät, angezeigte Übung) im Bootstrap.
  - `GeraetModel.rueckblickFaellig: Bool` — `satzNummer == 1 && rueckblick != nil`.
  - `GeraetModel.rueckblickOffen: Bool` — der View bindet sein Sheet daran.
  - `GeraetModel.geraetGeoeffnet()` — setzt `rueckblickOffen = rueckblickFaellig`.
  - `zuletztText` entfällt. `vorschlagText` bleibt (der Drawer und der Test in Task 3 lesen ihn).

- [x] **Step 1: Tests schreiben** (`GeraetModelTests.swift`). Z. 47 wird `#expect(sut.rueckblick?.zuletzt == "77,5 kg × 11")`. Dazu ein neuer Abschnitt:

```swift
// MARK: - Rueckblick (Sammelstelle Punkt 11)

@Test func rueckblickTraegtDenLetztenSatzUndSpaeterDenVorschlag() {
    let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
    let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)
    // Offline gibt es nur den letzten Satz; der Vorschlag kommt mit dem Kontext.
    #expect(sut.rueckblick == Rueckblick(zuletzt: "77,5 kg × 11", vorschlag: nil))

    sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

    #expect(sut.rueckblick == Rueckblick(zuletzt: "77,5 kg × 11", vorschlag: "Vorschlag · +2,5"))
}

@Test func beimErstenMalAmGeraetGibtEsKeinenRueckblick() {
    // Ohne letzten Satz und ohne Vorschlag haette der Drawer nichts zu
    // sagen -- er kommt gar nicht (Sammelstelle Punkt 11).
    let sut = modell(maschine: GeraetTestdaten.maschine,
                     bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
    #expect(sut.rueckblick == nil)
    #expect(sut.rueckblickFaellig == false)

    sut.geraetGeoeffnet()

    #expect(sut.rueckblickOffen == false)
}

@Test func rueckblickKommtNurVorDemErstenSatzDesBlocks() async {
    let sut = modell(maschine: GeraetTestdaten.maschine,
                     bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                     satzZiel: 3)
    #expect(sut.rueckblickFaellig == true)
    sut.geraetGeoeffnet()
    #expect(sut.rueckblickOffen == true)
    sut.rueckblickOffen = false

    await sut.satzSichern(problemFlag: false, problemReason: nil)
    sut.pauseBeenden()

    // Vor Satz 2 ist der Rueckblick da, aber nicht mehr faellig -- und ein
    // erneutes "Oeffnen" (das im View nicht vorkommt) holte ihn nicht zurueck.
    #expect(sut.rueckblick != nil)
    #expect(sut.rueckblickFaellig == false)
    sut.geraetGeoeffnet()
    #expect(sut.rueckblickOffen == false)
}

@Test func imZirkelZurueckAmGeraetKommtDerRueckblickNichtNochEinmal() {
    // Ueber die Blockliste entsteht ein FRISCHES GeraetModel
    // (TrainingRootView.modell(...)); bootstrap ist die alte Momentaufnahme
    // mit dem letzten Satz von gestern, nur die lokale Session weiss vom
    // ersten Satz von heute. satzNummer liest aus der Session -- deshalb
    // ist sie die tragende Bedingung, nicht bootstrap.
    let verzeichnis = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
    _ = sessions.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 77.5, reps: 11,
                              problemFlag: false, problemReason: nil)
    let sut = modell(maschine: GeraetTestdaten.maschine,
                     bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                     sessions: sessions)

    #expect(sut.rueckblick != nil)
    #expect(sut.rueckblickFaellig == false)
}

@Test func rueckblickGehoertZurAngezeigtenUebung() {
    // Derselbe Uebungs-Vorbehalt wie bei kalibrierungswerte: der letzte Satz
    // von e2 sagt nichts ueber e1.
    let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                     bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e2", 40, 10)]))
    #expect(sut.rueckblick == nil)

    sut.uebungWechseln(zu: "e2")

    #expect(sut.rueckblick?.zuletzt == "40,0 kg × 10")
}
```

- [x] **Step 2: Rot sehen.** `-only-testing:FitnessMemberTests/GeraetModelTests`. Erwartet: Build-Fehler „cannot find 'Rueckblick' in scope“.

- [x] **Step 3: Implementieren** (`GeraetModel.swift`). Neben `Einstellwert` auf Dateiebene:

```swift
/// Was der Drawer beim Oeffnen des Geraets sagt. nil, wenn er nichts zu
/// sagen haette: beim ersten Mal an diesem Geraet gibt es weder einen
/// letzten Satz noch einen Vorschlag (Sammelstelle Punkt 11).
struct Rueckblick: Equatable {
    /// "77,5 kg × 11" -- der letzte eigene Satz dieser Uebung an diesem
    /// Geraet, aus dem Prefetch, also auch offline.
    let zuletzt: String
    /// "Vorschlag · +2,5", sobald der Kontext da ist. Offline nil.
    let vorschlag: String?
}
```

Im Modell ersetzt das `zuletztText` (Z. 323–328):

```swift
var rueckblick: Rueckblick? {
    guard let letzter = bootstrap.lastSets.first(where: {
        $0.machineId == maschine.id && $0.exerciseId == uebungId
    }) else { return nil }
    return Rueckblick(
        zuletzt: "\(Zahlformat.gewichtMitEinheit(letzter.weightKg)) × \(letzter.reps)",
        vorschlag: vorschlagText
    )
}

/// Die Regel "wann kommt der Drawer": nur vor dem ersten Satz DIESES
/// Geraeteblocks, und nur, wenn es einen Rueckblick gibt. satzNummer liest
/// live aus der lokalen Session -- im Zirkel zurueck am selben Geraet ist
/// der erste Satz laengst gesichert, auch wenn bootstrap ihn nicht kennt.
var rueckblickFaellig: Bool { satzNummer == 1 && rueckblick != nil }

/// Ob der Drawer gerade steht. GeraetScreen bindet sein Sheet daran.
var rueckblickOffen = false

/// Einmal beim Oeffnen des Screens -- nicht nach jedem Satz und nicht beim
/// Uebungswechsel. Der Drawer ist der Blick zurueck VOR dem ersten Satz;
/// danach waere er eine Karte, die den Satzpfad wieder hoeher macht
/// (Punkt 12).
func geraetGeoeffnet() { rueckblickOffen = rueckblickFaellig }
```

Der Kommentar an `vorschlagText` („Fehlt offline und beim Erstkontakt“) bleibt richtig.

- [x] **Step 4: Grün sehen.** Dieselbe Suite; `WertZeile` liest `zuletztText` noch — der Build bricht dort. Für diesen Task in `WertZeile.swift` Z. 34–38 den `if !modell.radOffen, let zuletzt = modell.zuletztText { … }`-Block entfernen (Task 3 baut die Datei ohnehin um). Dann der volle `xcodebuild test`.

- [x] **Step 5: Commit** — `feat(geraet): Rueckblick als Ableitung mit der Regel, wann der Drawer kommt`

---

## Task 3: Die Räder sind immer aktiv (Punkt 11, Modell und Views)

`radOffen` verschwindet. Was daran hing:

| Stelle | Heute | Danach |
| --- | --- | --- |
| `GeraetModel.radOffen`, `radOeffnen()` | Zustand + einziger Weg, `gewichtVomNutzer` zu setzen | entfallen; `gewichtGewaehlt(_:)` übernimmt die Markierung |
| `GeraetModel.uebungWechseln`, `satzSichern` | setzen `radOffen = false` | Zeilen entfallen |
| `RastRad.offen` | Höhe 1,6 oder 5 Zeilen, `scrollDisabled`, Nachbarn nur offen sichtbar | Parameter entfällt; das Rad ist immer offen |
| `WertZeile` | `onTapGesture` öffnet, Kopf „antippen und scrollen“, Kontextzeile zeigt geschlossen den Vorschlag | kein Gesture, Kopf „scrollen, dann sichern“, Kontextzeile immer Schritt und Bereich |
| `GeraetView` | `.animation(…, value: modell.radOffen)` | Zeile entfällt |
| `ErsteWerteSchritt` | `.onAppear { modell.radOeffnen() }` | Zeile entfällt (das Rad ist offen) |
| `GewichtEintragenSheet`, `OnboardingSchritte` (2×), `RastRad`-Preview | `offen: true` | Argument entfällt |

Der Nutzerschutz bleibt: `gewichtVomNutzer` wird gesetzt, sobald das Mitglied am Rad **dreht**, nicht mehr, sobald es das Rad **öffnet**. Das Rad schreibt deshalb über `gewichtGewaehlt(_:)`, nicht direkt in `gewicht`. Die programmatischen Schreiber (`init`, `uebungWechseln`, `kontextUebernehmen`) setzen `gewicht` weiter direkt und lassen die Markierung in Ruhe. `RastRad` ruft den Binding-Setter nur aus `onChange(of: scrollPosition)` mit `neu != auswahl` und aus der `onAppear`-Verteidigung — letztere greift nie, weil alle drei Schreiber auf `gewichtsWerte` rasten.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (Z. 75–81, 421–426, 436, 458; Kommentar an `kontextUebernehmen` Z. 413–415)
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Components/RastRad.swift` (`offen` Z. 39, `body` Z. 72–78, `verlaufsrand` Z. 125–148, `scrollDisabled` Z. 183, `deckkraft` Z. 285–291, Kommentare Z. 18–29 und 272–276, Preview Z. 312–338)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/WertZeile.swift` (ganze Datei)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (Z. 3–5, 65, 252–253)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/ErsteWerteSchritt.swift` (Z. 47)
- Modify: `apps/ios-member/FitnessMember/Screens/Home/GewichtEintragenSheet.swift` (Z. 222), `apps/ios-member/FitnessMember/Onboarding/OnboardingSchritte.swift` (Z. 347, 530)
- Modify: `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift` (Z. 72–86, 106–133), `apps/ios-member/FitnessMemberTests/GeraetKontextLadenTests.swift` (Z. 99–115)

**Interfaces:**
- Produces:
  - `GeraetModel.gewichtGewaehlt(_ neu: Double)` — setzt `gewicht` und markiert es als vom Mitglied übernommen.
  - `RastRad` ohne `offen`. Signatur danach: `RastRad(werte:auswahl:unterstrich:voLabel:voWert:anschlagText:text:basisGroesse:)`.
  - `radOffen`, `radOeffnen()` entfallen.

- [x] **Step 1: Tests umschreiben.**
  - `GeraetModelTests`, Z. 72–86: aus `kontextUebernehmenLaesstEinBereitsGeoeffnetesRadInRuhe` wird

```swift
@Test func kontextUebernehmenLaesstEinenSelbstGewaehltenWertInRuhe() {
    // Ein spaet eintreffender tagContext darf den Wert nicht mehr unter
    // dem Daumen ersetzen, sobald das Mitglied am Rad gedreht hat
    // (Review-Fund I2). gewichtGewaehlt(_:) ist der einzige Weg dahin --
    // seit die Raeder immer offen sind, gibt es kein "Oeffnen" mehr, an
    // dem man es festmachen koennte.
    let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
    let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)
    sut.gewichtGewaehlt(75.0)

    sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

    #expect(sut.gewicht == 75.0)
    // Der Vorschlag selbst bleibt sichtbar -- nur die Uebernahme in
    // gewicht unterbleibt.
    #expect(sut.vorschlagText == "Vorschlag · +2,5")
}
```

  - `GeraetModelTests`, Z. 106–133 (`satzNummerZaehltImBlock`): `#expect(sut.radOffen == false)` entfällt, im Kommentar Z. 107–109 wird „satzNummer/phase/radOffen“ zu „satzNummer/phase“.
  - `GeraetKontextLadenTests`, Z. 99–115: aus `ohneTokenLaesstEinBereitsGeoeffnetesRadInRuhe` wird `ohneTokenLaesstEinenSelbstGewaehltenWertInRuhe`: statt `modell.radOeffnen()` steht `modell.gewichtGewaehlt(7.5)`, beide `#expect` prüfen `7.5`. Der Kommentar darüber („das Rad vor dem eintreffenden Kontext schon geoeffnet“) wird „am Rad gedreht“.

- [x] **Step 2: Rot sehen.** `-only-testing:FitnessMemberTests/GeraetModelTests`. Erwartet: „value of type 'GeraetModel' has no member 'gewichtGewaehlt'“.

- [x] **Step 3: Modell.** `radOffen` (Z. 75) und `radOeffnen()` (Z. 421–426) entfallen, ebenso `radOffen = false` in `uebungWechseln` (Z. 436) und `satzSichern` (Z. 458). Dafür:

```swift
/// Sobald das Mitglied am Rad gedreht hat, gehoert `gewicht` ihm -- ein
/// spaeter eintreffender tagContext (die Anfrage lief seit .task auf
/// GeraetView, kann in einem Keller zehn Sekunden brauchen) darf den Wert
/// dann nicht mehr unter dem Daumen ersetzen. Der einzige Ort mit zwei
/// Schreibern auf denselben Zustand im ganzen Branch.
private var gewichtVomNutzer = false

/// Der einzige Weg, auf dem das Mitglied selbst das Gewicht setzt: das
/// Rad schreibt hierher, nicht direkt in `gewicht`. init, uebungWechseln
/// und kontextUebernehmen setzen `gewicht` programmatisch und lassen die
/// Markierung in Ruhe -- sonst schuetzte ein Vorschlag sich vor sich selbst.
func gewichtGewaehlt(_ neu: Double) {
    gewicht = neu
    gewichtVomNutzer = true
}
```

Der Kommentar in `kontextUebernehmen` (Z. 413–415, „hat das Mitglied das Rad schon geoeffnet“) wird „hat das Mitglied schon am Rad gedreht“.

- [x] **Step 4: `RastRad` ohne `offen`.**
  - `let offen: Bool` entfällt. `body`: `.frame(height: radhoehe)`, das `.animation(…, value: offen)` entfällt.
  - `verlaufsrand`: `max(0, (1 - (zeilenhoehe * 1.8) / radhoehe) / 2)`. Vom Kommentarblock Z. 125–148 bleibt nur der Grund, nicht mehr die Geschichte des geschlossenen Rads:

```swift
/// Wo der Verlauf oben (und gespiegelt unten) voll deckend wird -- als
/// Anteil der Radhoehe, weil LinearGradient in Anteilen rechnet, die
/// Zeile aber in Punkten steht. Die voll deckende Mitte ist immer
/// `zeilenhoehe * 1.8` hoch: die Versalhoehe der 64-pt-Ziffern liegt bei
/// rund 46 pt, und ein Verlauf, der schon in der Mitte beginnt, blendet
/// die gewaehlte Zahl selbst an -- sie saehe ausgegraut aus.
```

  - `.scrollDisabled(!offen)` entfällt.
  - `deckkraft(fuer:)` wird `private nonisolated static func deckkraft(fuer phase: Double) -> Double` mit den offenen Werten (`1.0`, `0.38`, `0.15`); der Aufruf in `scrollTransition` wird `Self.deckkraft(fuer:)`. Der Kommentar Z. 272–276 („deckkraft nur `offen` (ein `let`)“) schrumpft auf: beide Funktionen lesen keinen Instanzzustand und laufen deshalb `nonisolated static`, weil die Effekt-Closure nonisolated ist.
  - Typkommentar Z. 18–29: „Ein Wertrad. Ruhe und Offen sind derselbe Aufbau.“ wird „Ein Wertrad, immer offen.“ Der Absatz zum Kniff bleibt, aber ohne „Dadurch hat der Screen in beiden Zustaenden dieselbe Silhouette und der Uebergang ist eine Bewegung statt eines Aufbaus“ — dafür: „Seit Schnitt 3 gibt es keinen geschlossenen Zustand mehr (Sammelstelle Punkt 11): gescrollt wird sofort, und die Linie ist von Anfang an die Rastmarke.“
  - Preview: `offen` und der Schließen/Öffnen-Knopf entfallen.
  - Aufrufer: `GewichtEintragenSheet.swift` Z. 222, `OnboardingSchritte.swift` Z. 347 und 530: die Zeile `offen: true,` entfällt.

- [x] **Step 5: `WertZeile` ohne Tap.**
  - Typkommentar: „Ein Tap auf EINE der beiden Zahlen oeffnet BEIDE Raeder. Danach wird nur noch gescrollt …“ wird „Beide Raeder sind immer aktiv (Sammelstelle Punkt 11): gescrollt wird sofort, ohne Tap, ohne Tastatur, mit dem Daumen der Hand, die das Handy haelt.“
  - `@Environment(\.accessibilityReduceMotion)` entfällt (nur der Gesture las es). `.contentShape(Rectangle())` und `.onTapGesture { … }` entfallen.
  - `kopf`: `Text("scrollen, dann sichern")` statt des Ternärs.
  - `gewichtsrad`: `auswahl: Binding(get: { modell.gewicht }, set: { modell.gewichtGewaehlt($0) })` mit dem Kommentar „Ueber gewichtGewaehlt, nicht $modell.gewicht: nur so weiss das Modell, dass der Wert vom Mitglied kommt und ein spaeter Vorschlag ihn nicht mehr ersetzen darf.“ `offen:` entfällt in beiden Rädern.
  - `kontextzeileGewicht`: `Text(modell.kontextzeileGewicht)`. Vom Kommentar Z. 84–92 bleibt der Grund für Schritt und Bereich; dazu ein Satz: „Der Vorschlag stand hier im geschlossenen Zustand; seit Schnitt 3 steht er im Drawer beim Oeffnen des Geraets (RueckblickSheet), damit die Zeile immer dasselbe sagt.“
  - Der `zuletzt`-Block ist seit Task 2 weg.

- [x] **Step 6: `GeraetView` und `ErsteWerteSchritt`.**
  - `GeraetView` Z. 65 (`.animation(…, value: modell.radOffen)`) entfällt.
  - Typkommentar Z. 3–5 wird: „Main, Pause und Abschluss sind derselbe Screen in drei Zustaenden -- keine Navigationsziele. Einen vierten (Raeder zu / offen) gibt es seit Schnitt 3 nicht mehr: die Raeder sind immer aktiv, und was am geschlossenen Zustand hing, ist weg oder im Drawer (Sammelstelle Punkt 11 bis 13).“ Der Absatz zur Pause bleibt.
  - Kommentar an `PrimaryButton` in `aktionen` (Z. 252–253) wird: „Sichert direkt aus dem Rad heraus: scrollen, dann sichern -- zwei Interaktionen, kein Tap dazwischen (Interaktionsbudget SS9).“
  - `ErsteWerteSchritt` Z. 47 (`.onAppear { modell.radOeffnen() }`) entfällt.

- [x] **Step 7: Grün sehen.** `xcodebuild test`, ganz. Danach `grep -rn "radOffen\|radOeffnen\|offen: " apps/ios-member/FitnessMember apps/ios-member/FitnessMemberTests` — außer `kalibrierungOffen`, `datumOffen`, `rueckblickOffen` und ähnlichen Namen darf nichts mehr kommen.

- [x] **Step 8: Commit** — `feat(geraet): Raeder immer aktiv, radOffen verschwindet`

---

## Task 4: Der Drawer (Punkt 11, View)

Der Rückblick kommt als Sheet von unten, sobald `GeraetView` erscheint und `rueckblickFaellig` gilt. Gemessen, nicht geschätzt: der Inhalt hat zwei oder drei Zeilen und wächst mit Dynamic Type — ein fester Detent ließe den Knopf bei großen Stufen unter der Kante verschwinden. Deshalb misst der Inhalt seine Höhe (`onGeometryChange`, im Bestand schon in `TestnotizKnopf`) und setzt sie als Detent.

```
┌──────────────────────────────┐
│           ────               │  <- Drag-Indicator
│ ZULETZT · BEIDBEINIG         │  <- label, textFaint
│ 77,5 kg × 11                 │  <- detailScreentitel (28 Black), text
│ Vorschlag · +2,5             │  <- 15 Semibold, textMuted, nur mit Kontext
│ [        Weiter        ]     │  <- SecondaryButton, keine Akzentflaeche
└──────────────────────────────┘  <- Hoehe = Inhalt + untere Safe Area
```

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/RueckblickSheet.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`.task` Z. 69–71; `GeraetScreen` Z. 344–349, neben den beiden Sheets)

**Interfaces:**
- Consumes: `Rueckblick`, `GeraetModel.rueckblick`, `rueckblickOffen`, `geraetGeoeffnet()` aus Task 2; `GeraetModel.aktiveUebung`.
- Produces: `struct RueckblickSheet: View { let uebung: String; let rueckblick: Rueckblick; let beiWeiter: () -> Void }`.

- [x] **Step 1: `RueckblickSheet.swift`.**

```swift
import SwiftUI

/// Der Blick zurueck, bevor der erste Satz an diesem Geraet faellt: letzter
/// eigener Satz und Vorschlag, als Drawer von unten (Sammelstelle Punkt 11).
///
/// Ein Sheet statt einer Karte auf dem Satzpfad: beides stand vorher unter
/// dem Rad und in der Kontextzeile -- und machte den Pfad hoeher, als ein
/// 667-pt-iPhone hergibt (Punkt 12). Weggewischt bleibt der Satzpfad
/// zurueck, ohne dass sich dort etwas bewegt. Wann der Drawer kommt,
/// entscheidet GeraetModel.rueckblickFaellig, nicht dieser View.
struct RueckblickSheet: View {
    let uebung: String
    let rueckblick: Rueckblick
    let beiWeiter: () -> Void

    /// Gemessen statt geschaetzt: zwei oder drei Zeilen, die mit Dynamic
    /// Type wachsen -- ein fester Detent liesse "Weiter" bei grossen Stufen
    /// unter der Kante verschwinden. 220 ist nur der Startwert, bis die
    /// erste Messung da ist, damit das Sheet nicht aus dem Nichts waechst.
    @State private var hoehe: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                // Mit Uebung, nicht "an diesem Geraet": der letzte Satz
                // gehoert zur Uebung, und ein Geraet kann zwei haben.
                Text("ZULETZT · \(uebung.uppercased())")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text(rueckblick.zuletzt)
                    .font(DesignSystem.Typography.detailScreentitel)
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.text)
                if let vorschlag = rueckblick.vorschlag {
                    // Eine Rechnung, keine Empfehlung (designsystem.md SS10)
                    // -- woertlich der Text, der vorher in der Kontextzeile
                    // stand.
                    Text(vorschlag)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
            // Ein Element fuer VoiceOver: "Zuletzt, Beidbeinig, 77,5 kg
            // mal 11, Vorschlag plus 2,5" -- drei Zeilen, ein Gedanke.
            .accessibilityElement(children: .combine)

            // Nebenaktion, keine Akzentflaeche: die eine des Screens ist
            // "Satz N sichern" dahinter (SS2).
            SecondaryButton(title: "Weiter", action: beiWeiter)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s32)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .onGeometryChange(for: CGFloat.self) { proxy in
            // Die untere Safe Area gehoert zum Detent, nicht zum Inhalt:
            // ohne sie sitzt "Weiter" auf dem iPhone 17 Pro hinter dem
            // Home-Indikator, auf dem SE (keine) stimmt es zufaellig.
            proxy.size.height + proxy.safeAreaInsets.bottom
        } action: { hoehe = $0 }
        .presentationDetents([.height(hoehe)])
        .presentationDragIndicator(.visible)
        .presentationBackground(DesignSystem.Color.surface)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RueckblickSheet(uebung: "Beidbeinig",
                            rueckblick: Rueckblick(zuletzt: "77,5 kg × 11", vorschlag: "Vorschlag · +2,5"),
                            beiWeiter: {})
        }
}
```

- [x] **Step 2: Verdrahten.**
  - `GeraetView`, `.task` Z. 71: `.task { modell.geraetBetreten(); modell.geraetGeoeffnet(); await modell.kontextLaden() }`. Der Kommentar darüber bekommt einen Satz dazu: „Der Drawer haengt am selben Moment: einmal beim Oeffnen, nicht nach jedem Satz.“
  - `GeraetScreen`, neben den beiden `.sheet`:

```swift
// Der Rueckblick vor dem ersten Satz. Das Sheet haengt an rueckblickOffen,
// die Regel dahinter am Modell (rueckblickFaellig) -- der View entscheidet
// nichts. Faellt der Rueckblick weg, waehrend das Sheet steht (kommt nicht
// vor: der Bootstrap aendert sich waehrend des Screens nicht), bleibt das
// Sheet leer statt zu stuerzen.
.sheet(isPresented: $modell.rueckblickOffen) {
    if let rueckblick = modell.rueckblick {
        RueckblickSheet(uebung: modell.aktiveUebung?.name ?? "",
                        rueckblick: rueckblick) {
            modell.rueckblickOffen = false
        }
    }
}
```

  - Der Erstkontakt-`fullScreenCover` und der Drawer schließen sich gegenseitig aus, ohne dass jemand es prüfen muss: `istErstkontakt` verlangt `!hatLetztenSatz`, `rueckblick` verlangt einen letzten Satz. Das steht als Kommentar an der `.sheet`-Zeile nicht noch einmal; es steht in Task 2 am Modell.

- [x] **Step 3: `xcodegen generate`, `xcodebuild test`**, grün. `git status`: `Package.resolved` unverändert, die neue Datei und `project.pbxproj` dabei.

- [ ] **Step 4: Im Simulator (iPhone 17 Pro) einmal ansehen**, ohne Backend geht das nicht — der Drawer braucht einen letzten Satz aus dem Bootstrap. Deshalb hier nur bauen; der Sichtcheck in Task 7 prüft: Das Sheet erscheint **nach** dem Push und nicht gar nicht (SwiftUI stellt ein Sheet, das während der Push-Animation angefordert wird, normalerweise nach ihr dar; bleibt es aus, hilft in `geraetGeoeffnet`-Aufruf ein `try? await Task.sleep(for: .milliseconds(400))` davor — dann mit Kommentar, warum).

- [x] **Step 5: Commit** — `feat(geraet): Rueckblick und Vorschlag als Drawer beim Oeffnen des Geraets`

---

## Task 5: Alles auf einen Screen (Punkt 12)

### Das Höhenbudget, aus dem Code gerechnet

Zeilenhöhen sind SF-Metriken (`ascender − descender`, aus `NSFont.systemFont` gemessen am 15. September): 11 pt Heavy 13,0 · 12 pt 14,1 · 13 pt 15,3 · 15 pt Semibold 17,7 · 17 pt Semibold 20,0 · 32 pt Black 37,7 · 64 pt Black 75,4.

**Rahmen auf dem iPhone SE (3. Gen., 375 × 667):** Statusleiste 20 + Navigationsleiste inline 44 = 64 oben, Tab-Leiste 49 unten (kein Home-Indikator). Für den Inhalt bleiben **554 pt**. Die `ScrollView` beginnt direkt unter der Navigationsleiste; der Inhalt hat kein oberes Padding.

**Heute** (Eingabezustand, Räder offen, Gerät mit Einstellwerten und zweiter Übung, keine Statuskarten — der häufigste Fall):

| Element | pt | Woher |
| --- | ---: | --- |
| Kopfzeile (Label · Ort, Uhr) | 17,7 | die 15-pt-Uhr überragt das 11-pt-Label |
| Abstand | 24 | `VStack(spacing: s24)` |
| Gerät + Übung | 75,2 | 37,7 + 4 + 20,0 = 61,7; „andere Übung“ (44 pt) hängt an der letzten Grundlinie und ragt 13,5 darunter |
| Abstand | 24 | |
| Einstellwerte (Zeile, seit Task 1) | 44 | „ändern“ `minHeight: 44` |
| Abstand | 24 | |
| WertZeile | 268,2 | Kopf 14,1 + 12 + Rad 220 (5 × 44) + 8 + Kontextzeile 14,1 |
| Abstand | 24 | |
| Aktionen | 180 | 64 + 12 + 48 + 12 + 44 |
| Fuß | 32 | `.padding(.bottom, s32)` |
| **Summe** | **713,1** | **159 zu viel** |

Vor Task 1 war es mit der Karte (71) statt der Zeile (44) noch mehr. Zwei Zeilen Radzeile (44 → 40) bringen nichts: Die 64-pt-Ziffer der gewählten Zeile reicht bis 24 pt unter die Zeilenmitte, der Nachbar darunter beginnt bei 44 − 10 = 34; bei 40 pt Zeilen läge die 4-pt-Rastlinie (Mitte + 32 bis + 36) mitten in seinen Ziffern. Die Zeilenhöhe bleibt 44.

**Was geht, und was es bringt:**

1. **Drei Radzeilen statt fünf** — der zweite Nachbar je Richtung entfällt: **−88**. Ein Nachbar reicht für die Aussage des Rads („wer 80,0 sieht, sieht auch, dass der nächste Schritt 82,5 ist“, §7). Braucht eine Ableitung: `scrollTransition` liefert die Phase auf [−1, 1] über den halben Ausschnitt, nicht in Zeilen — bei drei Zeilen liegt der erste Nachbar schon bei Phase 1,0 und fiele mit den festen Schwellen 0,25 / 0,75 in die Stufe „fern“ (26 pt, 15 % Deckkraft, praktisch unsichtbar). Die Schwellen werden deshalb in Zeilen gerechnet.
2. **„Problem melden“ neben „Gerät abschließen“** statt als dritte Zeile darunter — die Kandidatin aus Punkt 12: **−56**. Es bleibt ein 44-pt-Textknopf, kein zweiter Umriss.
3. **Abstände 16 statt 24 um die Kopfzeile und um die Einstellwerte-Zeile:** **−24**. Kopfzeile und Gerätename sind eine Einheit; die Einstellwerte-Zeile ist 44 pt hoch bei 15 pt Schrift und trägt selbst 14 pt Luft je Seite — mit 16 außen sieht sie aus wie 30. Vor den Aktionen bleiben 24.
4. **Fuß 16 statt 32:** **−16**. Die 32 waren Scrollreserve für einen Pfad, der nicht mehr scrollen soll; 16 halten die Tab-Leiste auf Abstand.

**Danach:**

| Element | pt |
| --- | ---: |
| Kopfzeile | 17,7 |
| Abstand | 16 |
| Gerät + Übung | 75,2 |
| Abstand | 16 |
| Einstellwerte | 44 |
| Abstand | 16 |
| WertZeile (Kopf 14,1 + 12 + Rad 132 + 8 + 14,1) | 180,2 |
| Abstand | 24 |
| Aktionen (64 + 12 + 48) | 124 |
| Fuß | 16 |
| **Summe** | **529,1** |

**25 pt Reserve** auf dem SE. Ohne Einstellwerte 469. Was die Reserve frisst: eine zweizeilige Kopfzeile (+13, ab etwa 32 Zeichen bei 11 pt mit Tracking 1,5 — „RUDERMASCHINE · FENSTERSEITE“ misst 241 pt, passt) und ein zweizeiliger Gerätename (+38, „BEINPRESSE SITZEND“ bei 32 pt Black misst rund 380 pt, passt nicht in 335). Der Name bekommt deshalb `lineLimit(1)` mit `minimumScaleFactor(0.75)`: schrumpfen statt kürzen, ein abgeschnittener Name sagt nicht, an welchem Gerät man steht. Die Statuskarten (Offline, Warteschlange, Abgelehnt) sind Ausnahmezustände; mit ihnen scrollt die Seite, und das ist in Ordnung. Das iPhone 17 Pro (874 pt, Inhalt ~ 741 pt) hat danach über 200 pt Luft — es bleibt oben ausgerichtet, nichts wird gestreckt.

**Nachgetragen vor der Umsetzung (15. September, gemessen auf dem SE-Simulator mit iOS 26.3, Stand nach Task 3):** Die Rechnung oben nimmt 44 pt Navigationsleiste und 49 pt Tab-Leiste an. Auf iOS 26 sind es **54 pt Navigationsleiste** (Rahmen y 20, Höhe 54 → Inhalt ab 74) und **83 pt untere Safe Area** für die schwebende Tab-Leiste (Rahmen y 584, Höhe 83). Dem Inhalt bleiben **510 pt**, nicht 554 — die 529 oben reichen nicht. Zweiter Befund aus demselben Lauf: „andere Übung“ steht heute in derselben `HStack` wie der Gerätename und nimmt ihm 100 pt Breite; „RUDERMASCHINE“ bricht deshalb schon auf dem SE in zwei Zeilen („RUDERMASCHI / NE“). Beides ändert Step 4:

1. **Kopf umbauen:** Der Gerätename bekommt die volle Breite in seiner eigenen Zeile (mit `lineLimit(1)` und `minimumScaleFactor(0.75)` wie geplant); darunter eine `HStack(alignment: .center)` aus Übungsname, `Spacer` und „andere Übung“. Die Zeile ist 44 pt hoch (der Knopf), der Übungsname steht mittig darin. Gerät + Übung = 37,7 + 4 + 44 = **85,7 mit Knopf**, ohne Knopf (Pause, Abschluss, nur eine Übung) 37,7 + 4 + 20 = 61,7. Vorher 75,2 — aber vorher mit falsch umbrechendem Namen.
2. **Abstände:** Kopfzeile → Name **8** (Label über seinem Titel, eine Einheit), Name → Einstellwerte 16, Einstellwerte → Räder 16, Räder → Aktionen **16** (statt 24), Fuß **8** (die 83 pt Safe Area tragen schon den Abstand zur Tab-Leiste).

| Element | pt |
| --- | ---: |
| Kopfzeile | 17,7 |
| Abstand | 8 |
| Gerät + Übung (mit „andere Übung“) | 85,7 |
| Abstand | 16 |
| Einstellwerte | 44 |
| Abstand | 16 |
| WertZeile | 180,2 |
| Abstand | 16 |
| Aktionen | 124 |
| Fuß | 8 |
| **Summe** | **515,6** |

Das sind **5,6 pt zu viel** bei Gerät mit Einstellwerten UND zweiter Übung. Deshalb zusätzlich: **die Übungszeile ist 44 pt hoch nur durch den Knopf** — der Knopf bekommt `.frame(minHeight: 44)` weiterhin, aber die Zeile richtet sich nach dem Text: `.padding(.vertical, -12)` am Knopf hebt seine 44 pt über die 20-pt-Zeile hinaus, ohne die Zeile zu strecken; die Trefferfläche bleibt 44, die Zeile misst 20. Gerät + Übung = 61,7 in jedem Zustand. Summe dann **491,6 von 510 — 18 pt Reserve.** Ohne Einstellwerte 431,6. Eine zweizeilige Kopfzeile (Ortsangabe lang und Training über einer Stunde: „RUDERMASCHINE · LINKS AM FENSTER“ misst 273 pt, die Uhr „1:23:41“ 52, dazu 12 Abstand = 337 > 335) kostet 13,5 und lässt die Seite um 0 bis 5 pt scrollen — hingenommen, weil selten und ohne Überlappung.

Der negative vertikale Padding am Knopf ist der einzige Trick in diesem Layout, und er ist begründet: eine 44-pt-Trefferfläche muss die Zeile nicht 44 pt hoch machen, wenn über und unter ihr 16 pt Luft liegen, in die sie hineinragen darf (Design §4 verlangt die Trefferfläche, nicht die Zeilenhöhe). Der Kommentar am Knopf sagt das.

**Files:**
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Components/RastRad.swift` (`radhoehe` Z. 70, `scrollTransition` Z. 174–178, `skalierung`/`deckkraft` Z. 277–291)
- Create: `apps/ios-member/FitnessMemberTests/RastRadTests.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/WertZeile.swift` (beide `RastRad`-Aufrufe)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`body` Z. 30–66, `geraetUndUebung` Z. 171–200, `aktionen` Z. 250–283, `abschlussEntscheidung` Z. 292–307, `problemMelden` Z. 311–319)

**Interfaces:**
- Produces:
  - `enum Nachbarstufe: Equatable { case gewaehlt, nachbar, fern }` (in `RastRad.swift`, Dateiebene neben `UnterstrichStil`)
  - `nonisolated static func RastRad.nachbarstufe(phase: Double, sichtbareZeilen: Int) -> Nachbarstufe`
  - `RastRad.sichtbareZeilen: Int = 5` — neuer Parameter mit Vorgabe, `WertZeile` übergibt 3. `GewichtEintragenSheet` und `OnboardingSchritte` bleiben bei 5 (dort ist Platz, und sie gehören nicht zu diesem Schnitt).

- [x] **Step 1: Test schreiben** (`RastRadTests.swift`)

```swift
import Testing
@testable import FitnessMember

/// Wie das Rad seine Nachbarn zeigt, haengt davon ab, wie viele Zeilen es
/// zeigt: scrollTransition liefert die Phase auf [-1, 1] ueber den halben
/// Ausschnitt, nicht in Zeilen.
struct RastRadTests {

    @Test func fuenfZeilenZeigenZweiNachbarnJeRichtung() {
        // Wie bisher: der erste Nachbar liegt bei 0,5, der zweite am Rand.
        #expect(RastRad.nachbarstufe(phase: 0, sichtbareZeilen: 5) == .gewaehlt)
        #expect(RastRad.nachbarstufe(phase: 0.5, sichtbareZeilen: 5) == .nachbar)
        #expect(RastRad.nachbarstufe(phase: -0.5, sichtbareZeilen: 5) == .nachbar)
        #expect(RastRad.nachbarstufe(phase: 1, sichtbareZeilen: 5) == .fern)
    }

    @Test func dreiZeilenZeigenDenNachbarnAmRandAlsNachbarn() {
        // Bei drei Zeilen liegt der erste Nachbar schon am Rand (Phase 1).
        // Mit den festen Schwellen von frueher (0,25 / 0,75) waere er
        // "fern": 26 pt bei 15 % Deckkraft, also praktisch unsichtbar --
        // und das Rad zeigte keinen Nachbarn mehr (designsystem.md SS7).
        #expect(RastRad.nachbarstufe(phase: 0.2, sichtbareZeilen: 3) == .gewaehlt)
        #expect(RastRad.nachbarstufe(phase: 1, sichtbareZeilen: 3) == .nachbar)
        #expect(RastRad.nachbarstufe(phase: -1, sichtbareZeilen: 3) == .nachbar)
    }
}
```

- [x] **Step 2: Rot sehen.** `xcodegen generate`, `-only-testing:FitnessMemberTests/RastRadTests`. Erwartet: „type 'RastRad' has no member 'nachbarstufe'“.

- [x] **Step 3: `RastRad` mit `sichtbareZeilen`.**

```swift
/// Wie das Rad eine Zeile zeigt: die gewaehlte in voller Groesse, die
/// Nachbarn kleiner und blasser (designsystem.md SS7).
enum Nachbarstufe: Equatable {
    case gewaehlt
    case nachbar
    case fern
}
```

Im `RastRad`, nach `basisGroesse`:

```swift
/// Wie viele Zeilen der Ausschnitt zeigt -- immer ungerade, die gewaehlte
/// in der Mitte. Fuenf ist die Vorgabe (zwei Nachbarn je Richtung); der
/// Satzpfad nimmt drei, weil er auf ein 667-pt-iPhone passen muss
/// (Sammelstelle Punkt 12) und ein Nachbar fuer die Aussage des Rads
/// reicht: wer 80,0 sieht, sieht auch, dass der naechste Schritt 82,5 ist.
var sichtbareZeilen = 5

private var radhoehe: CGFloat { zeilenhoehe * CGFloat(sichtbareZeilen) }
```

Der Kommentar an `radhoehe` („Fuenf Zeilen: der gewaehlte Wert plus zwei Nachbarn je Richtung“) entfällt, der an `sichtbareZeilen` ersetzt ihn. In `scroller`, vor der `ScrollView`: `let zeilen = sichtbareZeilen` — die Effekt-Closure ist nonisolated und darf keinen Instanzzustand lesen, ein lokaler `Int` geht mit. Die Closure wird:

```swift
.scrollTransition(.interactive, axis: .vertical) { inhalt, phase in
    let stufe = Self.nachbarstufe(phase: phase.value, sichtbareZeilen: zeilen)
    return inhalt
        .scaleEffect(Self.skalierung(stufe))
        .opacity(Self.deckkraft(stufe))
}
```

Die drei Funktionen ersetzen `skalierung(fuer:)` und `deckkraft(fuer:)`; der Kommentarblock „Nachbar-Optik“ (Z. 235–270) behält die beiden Korrekturen (Phase ist kontinuierlich; `VisualEffect` kennt kein `.font`), verliert aber den Satz mit den festen Schwellen 0,25 / 0,75 — die stehen jetzt in Zeilen:

```swift
/// Phase -> Stufe, aus der Zeilenzahl gerechnet. `phase` ist auf [-1, 1]
/// ueber den HALBEN Ausschnitt begrenzt: bei fuenf Zeilen liegt der erste
/// Nachbar bei 0,5, bei drei Zeilen schon bei 1,0. Die Schwellen 0,5 und
/// 1,5 ZEILEN sind fuer beide dieselben -- deshalb wird die Phase erst in
/// Zeilen umgerechnet.
nonisolated static func nachbarstufe(phase: Double, sichtbareZeilen: Int) -> Nachbarstufe {
    let halberAusschnitt = Double(sichtbareZeilen - 1) / 2
    switch abs(phase) * halberAusschnitt {
    case ..<0.5: .gewaehlt
    case ..<1.5: .nachbar
    default: .fern
    }
}

private nonisolated static func skalierung(_ stufe: Nachbarstufe) -> CGFloat {
    switch stufe {
    case .gewaehlt: 1.0
    case .nachbar: 30.0 / 64.0
    case .fern: 26.0 / 64.0
    }
}

private nonisolated static func deckkraft(_ stufe: Nachbarstufe) -> Double {
    switch stufe {
    case .gewaehlt: 1.0
    case .nachbar: 0.38
    case .fern: 0.15
    }
}
```

`WertZeile`: beide `RastRad`-Aufrufe bekommen `sichtbareZeilen: 3` (nach `basisGroesse` bzw. vor `text:` — die Reihenfolge der Memberwise-Init folgt der Deklaration, `sichtbareZeilen` steht nach `basisGroesse`).

- [x] **Step 4: `GeraetView`-Layout.**
  - `body`: `VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16)`, `kopfzeile` mit `.padding(.bottom, -DesignSystem.Spacing.s8)` (8 statt 16 zum Namen; oder Kopfzeile und Kopf in einer eigenen `VStack(spacing: s8)`), `.padding(.bottom, DesignSystem.Spacing.s8)`, dazu `.scrollBounceBehavior(.basedOnSize)` an der `ScrollView`. Der `.padding(.top, s8)` an `aktionen` entfällt (Abstand 16 wie überall). Kommentar am `VStack`:

```swift
// 16 statt 24 zwischen den Bloecken: der Satzpfad muss auf ein
// 667-pt-iPhone passen, ohne dass die Seite scrollt -- und iOS 26 laesst
// dem Inhalt dort nur 510 pt (54 pt Navigationsleiste, 83 pt Safe Area
// fuer die schwebende Tab-Leiste; Sammelstelle Punkt 12, Rechnung im
// Plan zu Schnitt 3). Die Einstellwerte-Zeile ist 44 pt hoch bei 15 pt
// Schrift und traegt ihre Luft selbst. Scrollen tut die Seite nur noch
// mit Statuskarten -- deshalb basedOnSize, sonst federt ein Pfad, der
// passt.
```

  - `geraetUndUebung` wird zum Kopf aus dem Nachtrag oben: `VStack(alignment: .leading, spacing: s4) { Name; HStack(alignment: .center) { Übungsname; Spacer(); if eingabe && hatWeitereUebungen { Button … .frame(minHeight: 44).padding(.vertical, -12) } } }`. Gerätename: `.lineLimit(1)` und `.minimumScaleFactor(0.75)` mit Kommentar: „Eine Zeile: ein zweizeiliger Name (BEINPRESSE SITZEND misst rund 380 pt bei 32 pt Black) kostete 38 pt, die das Hoehenbudget auf 667 pt nicht hat. Schrumpfen statt kuerzen -- ein abgeschnittener Name sagt nicht, an welchem Geraet man steht.“
  - `aktionen`:

```swift
private var aktionen: some View {
    VStack(spacing: DesignSystem.Spacing.s12) {
        // Sichert direkt aus dem Rad heraus: scrollen, dann sichern --
        // zwei Interaktionen, kein Tap dazwischen (Interaktionsbudget SS9).
        PrimaryButton(title: hauptaktion) {
            await modell.satzSichern(problemFlag: false, problemReason: nil)
        }
        .testnotizElement("geraet.satz-sichern", typ: "PrimaryButton")
        .accessibilityLabel("\(hauptaktion), \(Zahlformat.gewichtGesprochen(modell.gewicht))")

        // Abschliessen und Problem melden in EINER Zeile (Sammelstelle
        // Punkt 12): als dritte Zeile kostete "Problem melden" 56 pt, die
        // auf einem 667-pt-iPhone fehlten. Es bleibt ein Textknopf mit
        // 44 pt Hoehe, kein zweiter Umriss -- die Ausnahme, nicht die
        // Alternative. "Geraet abschliessen" steht weiter direkt unter dem
        // Weg zum naechsten Satz, weil es die andere Haelfte derselben
        // Frage ist: noch einer, oder fertig hier?
        HStack(spacing: DesignSystem.Spacing.s12) {
            SecondaryButton(title: "Gerät abschließen", action: beiZurueckZumTraining)
                .testnotizElement("geraet.abschliessen", typ: "SecondaryButton")
            problemMelden
        }
    }
    // (sensoryFeedback samt Kommentar unveraendert)
}
```

  - `abschlussEntscheidung`: derselbe Umbau — `SecondaryButton(title: "Weiterer Satz")` und `problemMelden` in einer `HStack(spacing: s12)`. Der Kommentar an `problemMelden` („In beiden Aktionsgruppen dieselbe Zeile“) bleibt richtig; `problemMelden` behält `.frame(maxWidth: .infinity, minHeight: 44)`, damit die Zeile hälftig teilt (auf dem SE 161 pt je Seite; „Gerät abschließen“ braucht 130 + 16).

- [x] **Step 5: Grün sehen.** `xcodebuild test`, ganz.

- [x] **Step 6: Commit** — `feat(geraet): Satzpfad passt ohne Scrollen auf 667 pt -- drei Radzeilen, Problem melden in der Zeile`

---

## Task 6: Doku nachziehen

Was der Umbau falsch macht, wird in einem Commit geradegezogen: das Designsystem, die Sammelstelle, die Kernflow-Spec.

**Files:**
- Modify: `docs/superpowers/specs/2026-08-30-designsystem.md` (§7 Z. 104–127, §9 Z. 156)
- Modify: `docs/superpowers/plans/2026-09-12-ios-verbesserungen-aus-dem-betrieb.md` („Stand“, Punkt **Gerät**, Z. 32–34; Kopf von „Schnitt 3“, Z. 545–555)
- Modify: `docs/superpowers/specs/2026-09-07-ios-geraet-kernflow-design.md` (Z. 207, 333)

- [x] **Step 1: designsystem.md §7.**
  - Überschrift: „## 7. Wertwahl — scrollen, dann sichern“.
  - Absatz 1, Satz 2 wird: „**Beide Räder sind immer aktiv** — gescrollt wird sofort, ohne Tap, ohne Tastatur, mit dem Daumen der Hand, die das Handy hält. (Bis Schnitt 3 öffnete ein Tap auf eine der Zahlen beide Räder; der Tap ist gefallen, Sammelstelle Punkt 11.)“
  - Absatz 2 („Der Kniff“): der letzte Satz „Damit hat der Screen in beiden Zuständen dieselbe Silhouette, und der Übergang ist eine Bewegung statt eines Aufbaus.“ entfällt; stattdessen: „Die Unterstreichung markiert den aktiven Wert und ist zugleich die Rastmarke.“
  - Die Tabelle „Zustand / Aussehen“ wird ein Absatz: „**Aussehen:** Wert 64 pt (Gewicht) bzw. 44 pt (Wiederholungen), **darunter** 4 pt bzw. 3 pt `accent`. Je Richtung ein Nachbar, 30 pt in `text-faint`, nach oben und unten in `bg` ausgeblendet; auf dem Satzpfad drei Zeilen, in Onboarding und Gewichtseintrag fünf (zwei Nachbarn, der äußere 26 pt in `line`). Unter der Linie der Kontext: `Schritt 2,5 kg · 5,0 – 150,0` bzw. `Ziel 8 – 12`. **Rückblick und Vorschlag** („Zuletzt 77,5 kg × 11“, „Vorschlag · +2,5“) stehen nicht unter dem Rad, sondern in einem Drawer, der beim Öffnen des Geräts von unten kommt — nur vor dem ersten Satz eines Geräteblocks, beim ersten Mal an einem Gerät gar nicht.“ (Die alte Zeile „3 pt `line` (Wiederholungen)“ war schon vor diesem Schnitt falsch: `RastRad` zeichnet beide Linien in `accent`.)
- [x] **Step 2: designsystem.md §9**, Z. 156: „Wer abweicht, zahlt genau **einen** zusätzlichen Tap — er öffnet beide Räder, und danach ist Scrollen kostenlos. Damit bleibt auch der Abweichungsfall bei zwei Interaktionen.“ wird „Wer abweicht, scrollt — die Räder sind immer aktiv, ein Tap kommt nicht dazu. Damit bleibt auch der Abweichungsfall bei zwei Interaktionen: scrollen, sichern.“
- [x] **Step 3: Sammelstelle.**
  - „Stand“, Punkt **Gerät** wird: „**Gerät** hat seit `8f73fa0` eine Trainingsuhr im Kopf (`GeraetView.trainingsuhr`). Seit Schnitt 3 sind die Räder immer aktiv (`radOffen` gibt es nicht mehr), Rückblick und Vorschlag stehen in einem Drawer beim Öffnen (`GeraetModel.rueckblick`, `rueckblickFaellig`, `RueckblickSheet`), die Einstellwerte nur noch als Zeile, und der Satzpfad passt mit drei Radzeilen und „Problem melden“ neben „Gerät abschließen“ auf 667 pt (gerechnet 492 von 510 pt, die iOS 26 dem Inhalt dort lässt). Punkt 11 bis 13 sind damit umgesetzt.“
  - Kopf von „Schnitt 3“: unter der Überschrift ein Satz „Umgesetzt, Plan: `docs/superpowers/plans/2026-09-15-schnitt3-satzpfad.md`.“ Der letzte Spiegelstrich („Ergebnis messen: passt der Pfad ohne Seiten-Scrollen auf ein iPhone mini …“) bekommt das Ergebnis aus Task 7 nachgetragen (Zahl und Simulator).
  - Bei Punkt 11 bis 13 nichts löschen — die Sammelstelle hält fest, was gemeint war.
- [x] **Step 4: Kernflow-Spec.** Z. 207 („ein Tap öffnet beide Räder, Scrollen ist kostenlos …“) und Z. 333 („dort steht stattdessen der letzte eigene Wert aus `bootstrap.lastSets`“) bekommen je einen Einschub „(seit Schnitt 3: die Räder sind immer aktiv, kein Tap; Rückblick und Vorschlag stehen im Drawer beim Öffnen, siehe designsystem.md §7)“. Nicht umschreiben — die Spec beschreibt den Stand vom 7. September.
- [x] **Step 5: Commit** — `docs: Designsystem SS7/SS9 und Sammelstelle fuer Schnitt 3 nachgezogen`

---

## Task 7: Sichtcheck gegen das lokale Backend

Tests beweisen Ableitungen, nicht Sichtbarkeit und Höhe. Der Sichtcheck läuft auf zwei Simulatoren — iPhone 17 Pro (vorhanden) und iPhone SE 3. Generation (667 pt, anzulegen, danach löschen) — gegen das lokale Backend. Die Screenshots werden angesehen, nicht nur gemacht.

**Aufbau (Lehren aus Schnitt 2):**
- `df -h /` vor dem ersten Build; eigene DerivedData wegräumen.
- Lokales Supabase in Docker (`supabase status` in `apps/web` oder `docker ps`), Web-API in `apps/web` mit `set -a; source ../../.env; set +a; pnpm dev` im Hintergrund.
- Build mit Overrides, `Config.xcconfig` bleibt unangetastet:
  `xcodebuild build -scheme FitnessMember -destination '…' API_BASE_URL=http://127.0.0.1:3000/api/v1 SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=<aus .env>`. Danach die drei Werte in der `Info.plist` des Builds prüfen (`plutil -p`). **Nicht** `CODE_SIGNING_ALLOWED=NO`, sonst verliert der Login die Session (Keychain).
- Testnutzer per Service-Key mit Passwort anlegen (Skript im Scratchpad), Mitgliedschaft in einem Studio mit mindestens: einem Gerät mit Einstellwerten und zwei Übungen, einem Gerät ohne Einstellwerte, einem Gerät mit langem Namen („Beinpresse sitzend“). Wegen des 422 aus Frage b) brauchen die Testgeräte vorab eine Zeile in `member_machine_calibrations`.
- Taps über ein kleines XCUITest-Harness im Scratchpad (eigenes Projekt, `XCUIApplication(bundleIdentifier:)`), Screenshots mit `xcrun simctl io <udid> screenshot`. AppleScript geht bei gesperrtem Bildschirm nicht.
- SE-Simulator: `xcrun simctl create "SE-Schnitt3" "iPhone SE (3rd generation)" <iOS-Runtime aus simctl list runtimes>`, am Ende `xcrun simctl delete SE-Schnitt3`.
- Für den Drawer braucht der Bootstrap einen letzten Satz: erster Lauf am Gerät (Dreischritt, ein Satz, „Gerät abschließen“, „Training beenden“), App neu starten, Gerät erneut öffnen.

- [ ] **Step 1: Satzpfad auf dem SE, Eingabezustand**, Gerät mit Einstellwerten und zweiter Übung: Kopfzeile, Gerätename, Übung, „andere Übung“, Einstellwerte-Zeile, beide Räder mit je einem sichtbaren Nachbarn, „Satz 1 sichern“, „Gerät abschließen“ und „Problem melden“ — alles im Bild, Fuß über der Tab-Leiste, die Seite federt nicht. Screenshot. Die Reserve nachmessen (Abstand Unterkante der Aktionszeile zur Tab-Leiste) und in die Sammelstelle (Task 6, Schnitt 3, letzter Spiegelstrich) eintragen.
- [ ] **Step 2: Der Drawer**: Gerät mit Historie öffnen — das Sheet kommt nach dem Push, mit „ZULETZT · <Übung>“, Wert, „Vorschlag · …“ (online) und „Weiter“. Wegwischen: die Räder stehen darunter und reagieren sofort auf Scrollen. Screenshot SE und 17 Pro (auf dem 17 Pro sitzt „Weiter“ über dem Home-Indikator, nicht dahinter).
- [ ] **Step 3: Kein Drawer** in drei Fällen: Gerät zum ersten Mal (Dreischritt läuft, danach kein Drawer), zweiter Satz nach der Pause, Rückkehr ans Gerät über die Blockliste. Für jeden Fall ein Screenshot des Satzpfads ohne Sheet.
- [ ] **Step 4: Räder**: am Gewicht drehen, dann `kontextLaden` abwarten (Vorschlag) — der Wert bleibt. Anschlag: am Minimum weiterdrehen, das Rad klopft (nicht sichtbar prüfbar, aber der Wert bleibt am Rand).
- [ ] **Step 5: Gerät ohne Einstellwerte**: keine Zeile, kein Loch — der Abstand Übung → Räder ist 16. Gerät mit langem Namen: eine Zeile, geschrumpft, nicht abgeschnitten.
- [ ] **Step 6: Pause und Abschluss** auf dem SE: Pausenrad, „Weiter“, „+30 s | Gerät abschließen“; Abschluss mit „Weiterer Satz | Problem melden“. Screenshot. Hier auch Frage a) reproduzieren (Gerätename und Ort links abgeschnitten) und die Ursache notieren — der Fix ist Task 8.
- [ ] **Step 7: Dynamic Type** `xcrun simctl ui <udid> content_size extra-extra-extra-large` auf dem SE: der Satzpfad darf scrollen, aber nichts überlappt, die Räder zeigen ihren Wert (geschrumpft, nicht gekürzt), der Drawer wächst mit und „Weiter“ bleibt erreichbar. Danach `content_size medium`.
- [ ] **Step 8: Bericht**: Liste der Screenshots mit je einem Satz, was sie zeigen; Abweichungen als Nachtrag-Commit `fix(geraet): Nachzuege aus dem Sichtcheck -- …` oder als Notiz unter „Beim Sichtcheck gefunden, außerhalb dieses Schnitts“ im Abschlussbericht. SE-Simulator löschen, Web-API beenden.

---

---

## Task 8: Pausenscreen auf dem SE (Frage a, aufgenommen am 15. September)

Der Sichtcheck von Schnitt 2 zeigte auf dem SE in der Pause den Gerätenamen und den Ort links abgeschnitten („ASCHINE“ statt „RUDERMASCHINE“). Aus dem Code allein ist die Ursache nicht eindeutig (siehe „Offen“ unten); Task 7, Step 6 reproduziert sie. Dazu kommt der Nebenbefund aus dem Höhenbudget: die Pause ist auf dem SE auch nach Task 5 zu hoch.

**Höhenbudget der Pause auf dem SE** (510 pt für den Inhalt auf iOS 26, siehe Nachtrag in Task 5), nach Task 5: Kopfzeile 17,7 + 8 + Gerät/Übung 61,7 (ohne „andere Übung“, der Knopf zeigt nur im Eingabezustand) + 16 + `PausenRad` 444 (24 + 240 + 32 + 64 + 12 + 48 + 24) + Fuß 8 = **555,4 — 45 zu viel.** Das `.padding(.vertical, s24)` am `PausenRad` (48 pt) ist überflüssig, der umschließende `VStack` trägt den Abstand: ohne es **507,4**, 2,6 Reserve — zu knapp. Dazu `spacing: s24` statt `s32` zwischen Rad und Knöpfen (−8): **499,4, 10,6 Reserve.**

**Files:**
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Components/PausenRad.swift` (Z. 68)
- Modify: je nach Ursache `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`kopfzeile`, `geraetUndUebung`, `inhalt`) oder `PausenRad.swift`

- [x] **Step 1: Reproduzieren** auf dem SE-Simulator aus Task 7: Satz sichern, Pause läuft, Screenshot. Zeigt er den Abschnitt links, mit `Debug View Hierarchy` oder durch schrittweises Ausblenden (`PausenRad` durch `Color.clear.frame(height: 444)` ersetzen, dann die Knopfzeile, dann das Rad) das Kind finden, das breiter als 335 pt ist oder den Inhalt verschiebt. Ursache in den Bericht.
- [x] **Step 2: Kleinster Fix** an der gefundenen Stelle, mit Kommentar, der die Ursache nennt. Kein Umbau des Pausenzustands.
- [x] **Step 3: `.padding(.vertical, DesignSystem.Spacing.s24)`** in `PausenRad.body` entfällt, und der äußere `VStack(spacing: s32)` wird `s24`; die Preview zeigt das Rad ohnehin mit `.padding(20)` auf `bg`, sie braucht nichts. Kommentar am `VStack` in `PausenRad`: „Kein eigenes vertikales Padding: der Abstand kommt vom Satzpfad-VStack, und 48 pt hier machten die Pause auf einem 667-pt-iPhone 17 pt zu hoch (Plan Schnitt 3, Task 8).“
- [x] **Step 4: Screenshot SE**, Pause: Kopfzeile und Gerätename vollständig, „Weiter“ und die geteilte Knopfzeile im Bild, ohne Scrollen.
- [x] **Step 5: `xcodebuild test`**, grün.
- [x] **Step 6: Commit** — `fix(geraet): Pausenscreen schneidet auf 667 pt nichts mehr ab`

## Selbstprüfung

`xcodebuild test` beweist die Ableitungen (`rueckblickFaellig`, `gewichtGewaehlt`, `nachbarstufe`), der Sichtcheck die Screens im Simulator. Von Hand, am Gerät, im Studio:

- [ ] Gerät mit Historie öffnen: Von unten kommt der Drawer mit „ZULETZT · <Übung>“, „77,5 kg × 11“ und — mit Empfang — „Vorschlag · +2,5“. Wegwischen oder „Weiter“: der Satzpfad steht unverändert dahinter, nichts rutscht.
- [ ] Ohne Tap direkt am Gewicht scrollen: das Rad dreht sofort, ein Nachbar je Richtung ist lesbar (nicht ausgegraut wie früher der zweite), die Linie bleibt liegen. Die Kopfzeile sagt „SATZ 1 · scrollen, dann sichern“.
- [ ] Gerät zum ersten Mal: Dreischritt wie bisher, danach kein Drawer. Vor Satz 2 (nach der Pause) kein Drawer. Nach dem Zirkel zurück am Gerät kein Drawer.
- [ ] Übung wechseln: kein Drawer, das Rad steht auf dem letzten Wert der neuen Übung.
- [ ] Im Keller: am Rad drehen, dann Empfang — der Wert bleibt, wo der Daumen ihn hingedreht hat. Ohne Drehen springt das Rad auf den Vorschlag.
- [ ] Einstellwerte: nur die schmale Zeile, „ändern“ öffnet die Kalibrierung. Gerät ohne Einstellwerte: keine Zeile, kein Loch.
- [ ] iPhone mit 667 pt (SE) bei Standard-Schrift: Kopf, Gerät, Einstellwerte, beide Räder, „Satz N sichern“, „Gerät abschließen“ und „Problem melden“ ohne Scrollen im Bild. Die Seite federt nicht.
- [ ] „Problem melden“ neben „Gerät abschließen“: beide treffbar, das Sheet zum Problem kommt wie bisher, der Satz wird mit Markierung gesichert.
- [ ] Abschlussentscheidung: „Gerät abschließen“ (Akzent), „Weiterer Satz“ und „Problem melden“ in einer Zeile.
- [ ] Flugmodus: Offline-Leiste oben, Seite scrollt, nichts überlappt; Drawer zeigt nur „Zuletzt“, keinen Vorschlag.
- [ ] VoiceOver: jedes Rad ein Regler („Gewicht, 77,5 Kilogramm“, auf/ab ein Geräteschritt). Der Drawer liest sich als ein Satz, dann „Weiter“.
- [ ] Dynamic Type größte Stufe: Satzpfad scrollt, nichts überlappt; der Drawer wächst, „Weiter“ bleibt erreichbar.

## Offen — vor der Umsetzung zu entscheiden

**a) Pausenscreen schneidet Gerätename und Ort links ab** (Sichtcheck Schnitt 2, SE: „ASCHINE“ statt „RUDERMASCHINE“). Derselbe Screen, derselbe Kopf (`kopfzeile`, `geraetUndUebung`) in allen Zuständen — aber nur in der Pause abgeschnitten. Im Code ist im Pausenzustand nichts breiter als der Screen: `PausenRad` misst 240 pt, die geteilte Knopfzeile braucht auf dem SE 146 von 161 pt je Seite, die Kopfzeile 241 + 12 + 40 pt von 335. Ein Abschnitt links bei vollem rechtem Rand entsteht, wenn ein `ScrollView`-Inhalt breiter als der Viewport ist und zentriert wird — welches Kind das ist, zeigt erst die Reproduktion. Nebenbefund aus dem Höhenbudget: die Pause ist auf dem SE mit 571 pt (nach Task 5) 17 pt zu hoch und scrollt. **Entschieden (15. September): in Schnitt 3, als Task 8** nach dem Sichtcheck — die SE-Umgebung steht dann, die Reproduktion kostet nichts, und der Fix liegt in `GeraetView`/`PausenRad`, wo dieser Schnitt ohnehin arbeitet. Wenn die Ursache außerhalb liegt, wird sie notiert, nicht gefixt.

**b) Gerät ohne Einstellwerte kommt nicht über die Kalibrierung hinaus** (`POST /me/calibrations` → 422 „Es wurde kein Einstellwert uebergeben.“, `pruefeEinstellwerte` in `packages/domain/src/calibration.ts` Z. 61–64). `KalibrierungSchritt` zeigt dann nur den Trainer-Schalter und „Speichern und weiter“, das Banner mit dem Servertext, kein Weiter. Zwei Fixes, beide klein: der Server akzeptiert leere `settingValues`, wenn das Modell keine Definitionen hat (eine Bedingung, ein Unit- und ein Integrationstest); und/oder die App überspringt Schritt 2, wenn `einstellDefinitionen` leer ist, und zeigt „ändern“ nicht. **Entschieden (15. September): eigener Fix, nicht in Schnitt 3** — es ist Erstkontakt und Server, nicht Satzpfad, und der Schnitt bleibt „Client, ohne Server“. Der Sichtcheck umgeht es über eine vorab angelegte Zeile in `member_machine_calibrations`.

## Was dieser Schnitt NICHT tut

- **Startzeitpunkt der Einheit und der Screen „Training starten“** (Punkt 10, Schnitt 4). Die Uhr zählt weiter ab dem ersten Gerät (`geraetBetreten`), der Dreischritt bleibt, wie er ist.
- **Löschen einer Einheit** (Punkt 19), **Übungsbilder** (Punkte 14 und 18, Schnitt 5), **laufendes Training auf Home** (Punkt 21).
- **Frage b)** — Gerät ohne Einstellwerte am Erstkontakt (422) — ist ein eigener Fix, entschieden am 15. September.
- **Die Artboards** `docs/superpowers/design/member/GeraetWertRad.dc.html` und `Main.dc.html` bleiben, wie sie sind: sie zeigen den Entwurf vom September-Anfang mit Ruhe- und Offen-Zustand. Kommentare im Code, die auf sie verweisen (`RastRad.basisGroesse`, `WertZeile.wiederholungsrad`), bleiben richtig — sie zitieren Schriftgrößen, nicht Zustände.
- **Kein „Vorschlag übernehmen“ im Drawer.** Das Rad steht schon auf dem Vorschlag, sobald er da ist (`kontextUebernehmen`); ein Knopf dafür wäre ein Tap für etwas, das schon passiert ist.
- **`RastRad` in Onboarding und Gewichtseintrag** behalten fünf Zeilen. `sichtbareZeilen` ist ein Parameter mit Vorgabe 5, nicht eine Änderung an diesen Screens.
- **Tab-Leiste und Navigationsleiste** bleiben sichtbar. Beide zusammen kosten 113 pt auf dem SE; sie zu verstecken wäre der billigste Weg zu Punkt 12 gewesen, und der falsche: der Weg zurück zum Training und der Tab-Wechsel gehören zum Screen.
- **Dynamic Type skaliert die festen Schriftgrößen nicht** (Sichtcheck-Fund Schnitt 2, außerhalb). Die Räder und die Zeilenhöhe skalieren über `@ScaledMetric`, wie bisher; der Rest bleibt fest.
- **Die dunkle Statusleiste in „Gerät wählen“** (Sichtcheck-Fund Schnitt 2, anderer Screen).
