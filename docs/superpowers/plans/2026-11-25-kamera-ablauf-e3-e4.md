# Kamera-Tracking und Tempo-Welle, Teil 2: Kamera-Ablauf (E3 + E4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Kamera-Ablauf als eigener Vollbild-Ablauf über der Übungsansicht (Video → Aufstellen → Countdown → Satz mit Welle → Tracking verloren → Satzende mit Sichern und Rückblick → „Ohne Kamera“), mit Erlaubnis und allen Fehlerfällen aus Spec Abschnitt 12, im Simulator mit vorgerechneten Skeletten und am iPhone mit der Frontkamera.

**Architecture:** Die Abfolge der Schritte ist eine reine Zustandsmaschine `KameraSatzAblauf` im Package `Koerperbild` (am Mac mit `swift test`), gespeist mit `(t, Skelett?)` und Tipp-Ereignissen; sie nutzt `Erkennungspruefung`, `Koerperlage`, `Sollwelle` und `Satzrueckblick` aus Teil 1. In der App verbindet ein `@MainActor @Observable` `KameraAblaufModell` eine `Bildquelle` (Frontkamera oder, nur im Debug-Build, Abspielen von Video + Skelettdatei) mit der Maschine und mit `GeraetModel` über die schmale Naht `KameraNaht`. Die Ansichten liegen als `fullScreenCover` über `GeraetScreen`; die Übungsansicht darunter bleibt in `eingabe`/`pause`/`abschluss` und sichert wie heute.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation (`AVCaptureSession`, `AVSampleBufferDisplayLayer`, `AVPlayer`), Vision über `KoerperErkennung.PoseErkenner`, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-24-kamera-tempo-ablauf-design.md` (Abschnitte 2, 7.1–7.7, 8, 11, 12, 14 E3+E4). Plan Teil 1: `docs/superpowers/plans/2026-11-24-kamera-tempo-kern-katalog.md`, Abschnitt „Stand nach der Umsetzung“. Bildentwürfe (abgenommen): lokale Kopie unter `docs/superpowers/plans/kamera-ablauf-canvas/project/*.dc.html` (Bilder 1–7: `Main`, `Aufstellen`, `Bereit`, `ImTakt`, `ZuSchnell`, `AusDemBild`, `Satzende`; Profil Oberkörper: `AufstellenBizeps`). `AufstellenLiegestuetz` ist überholt.

## Global Constraints

- Arbeitsbasis: Worktree `.claude/worktrees/kamera-ablauf`, Branch `claude/kamera-ablauf`, abgezweigt von `origin/claude/kamera-kern-katalog` (PR #116 ist noch offen). Kein Push, kein PR ohne Tims Wort.
- Hauptordner und Worktree `kamera-versuch` nur lesen. Aus dem Versuch wird kopiert und angepasst, nichts gemergt.
- Kein `git commit --amend`, kein Rebase. Nie zwei Umsetzer gleichzeitig: alle Tasks laufen nacheinander (App-Tasks teilen DerivedData, Package-Tasks kompilieren mit).
- `Config.xcconfig` fehlt im Worktree (nicht eingecheckt): einmalig aus dem Hauptordner `apps/ios-member/Config.xcconfig` kopieren, nicht committen. Nach jeder Änderung an `project.yml`: `cd apps/ios-member && xcodegen generate`.
- **`GeraetModel` bekommt nur die Naht aus Task 4.** Kein Kamera-Code, kein `import AVFoundation` in `GeraetModel.swift`.
- Ein Kamera-Fehler darf nie einen Satz verlieren oder das Sichern blockieren: Gesichert wird ausschließlich über `GeraetModel` (`satzLokalSichern`), sofort am Satzende; der Rückblick erscheint auch, wenn das Sichern abgelehnt wird.
- Katalog und Freischaltung bleiben unberührt: `FREIGESCHALTETE_PROFILE` und `catalog/gymtavo.json` werden nicht geändert. Testprofile kommen nur im Debug-Build (Task 5). Keine Migration, nichts auf Supabase.
- Ausgeschlossen vom Kamera-Ablauf (alles wie heute): `volumeKind != .reps`, Cardio, Zirkel (`imZirkel`), Übung ohne `kameravorgabe`, Profil `ohneKamera` (dessen Welle ist E5).
- Immer Frontkamera, hochkant, Anzeige gespiegelt. Vision läuft auf dem **ungespiegelten**, aufrechten Bild (damit links/rechts stimmen); gespiegelt wird nur die Anzeige (Livebild und Strichfigur, x → 1 − x).
- Kein Bild, kein Skelett, kein Winkel wird gespeichert oder gesendet. Lokal gemerkt wird nur der Hub je Übung: `UserDefaults` Schlüssel `kamera.hub.<exerciseId>` (Double, Grad).
- Feste Werte (Spec, Vorschlag): Check bestanden nach 1,0 s; Ruhe vor dem Countdown 0,5 s (`Koerperlage.istRuhig`); Countdown 3 s; Tracking verloren nach mehr als 1,0 s; Vorlauf nach Wiedereinstieg 2 s; neben der Bahn erst nach 0,5 s; Satzende nach 8 s Ruhe bei mindestens 1 Wiederholung; keine Bewegung nach der Los-Marke: zwei Wellenperioden ohne gezählte Wiederholung; Bildrate unter 15/s über 3 s; Rückblick erst ab 3 Wiederholungen.
- Texte wörtlich aus Spec und Canvas (Abschnitt „Texte“ unten). Farben und Schrift nur aus `DesignSystem` (`Color.accent`, `.warn`, `.bg`, `.surface`, `.text`, `.textMuted`; `Typography.wertHeld`, `.label`, `.screentitel`, `.fliesstext`). Namen, Kommentare, Commits deutsch, im Code ae/oe/ue.
- Bildschirm bleibt an, solange der Ablauf offen ist (`UIApplication.shared.isIdleTimerDisabled`, beim Schließen zurück). Keine Änderung an `AudioSitzung` (`.ambient` lässt fremde Musik laufen; die Kamera nimmt keinen Ton auf).
- Namenskonflikt: Die App hat ein eigenes `struct Rueckblick` (`GeraetModel.swift:33`). In App-Dateien, die `Koerperbild` importieren, immer `Koerperbild.Rueckblick` schreiben.
- Tests: Package `cd apps/ios-member/Packages/Koerperbild && swift test --filter <Name>`. App: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/<Suite> 2>&1 | tail -30`.

## Review Focus

1. **Pause läuft ab, während der Rückblick offen ist** – der Ablauf springt von selbst zu Aufstellen bzw. Countdown, ohne dass `pauseBeenden()` zweimal wirkt oder die Übungsansicht in `pause` hängen bleibt (Task 4, Task 7).
2. **Sensor-Automatik im Debug-Build feuert während eines Kamera-Satzes `.beendet`** – kein zweiter Satz wird gesichert, die Zahl am Rad bleibt die der Kamera (Task 4).
3. **„Ohne Kamera weiterzählen“ nach 5 gezählten Wdh.** – das Rad steht auf 5, der Satz ist nicht gesichert, der Sensor überschreibt die 5 nicht (Task 4).
4. **App geht mitten im Satz in den Hintergrund und kommt nach einer Minute zurück** – Kamera aus, Satz pausiert, beim Zurückkommen Aufstell-Check, gezählte Wdh. bleiben (Task 3, Task 7).
5. **Kamera liefert keine Bilder (Simulator ohne Abspieldaten, Kamera belegt)** – Hinweis mit „Ohne Kamera“ statt schwarzem Bildschirm (Task 6, Task 7).

---

## Die Naht (Weg 1)

```
GeraetScreen ──fullScreenCover(isPresented: $modell.kameraAblaufOffen)──▶ KameraAblaufAnsicht
      │                                                                        │
  GeraetModel  ◀── KameraNaht ─────────────────────────────────────────  KameraAblaufModell
  (sichert, Pause, Rad)   hinein: kameraSatzSichern(wiederholungen:)            │   ├ KameraSatzAblauf (Koerperbild, rein)
                                  kameraVerlassen(gezaehlt:)                    │   └ Bildquelle (Frontkamera | Abspielen)
                                  umfangNachtragen(_:)
                          heraus: kameraStart, kameraWahl, phase,
                                  laufendePause, kameraAblaufOffen, kameraEinstieg
```

`GeraetModel` entscheidet allein, wann der Ablauf offen ist (`kameraAblaufOffen`), und sichert. `KameraAblaufModell` kennt `GeraetModel` nur über das Protokoll `KameraNaht`.

## Dateien

| Datei | Aufgabe |
|---|---|
| `Packages/Koerperbild/Sources/Koerperbild/Aufstellanweisung.swift` | die eine Anweisung im Aufstell-Schritt (Task 1) |
| `Packages/Koerperbild/Sources/Koerperbild/KameraSatzAblauf.swift` | Zustandsmaschine 7.1–7.6 + Fehlerfälle (Task 2, 3) |
| `Packages/Koerperbild/Tests/KoerperbildTests/AufstellanweisungTests.swift`, `KameraSatzAblaufTests.swift`, `KameraSatzAblaufAbspielTests.swift` | Tests (Task 1–3) |
| `FitnessMember/Screens/Geraet/GeraetModel.swift` | Naht (Task 4) |
| `FitnessMember/Workout/Kamera/KameraNaht.swift` | Protokoll + Werttypen der Naht (Task 4) |
| `tools/kamera-zuordnung/testprofile.py`, `FitnessMember/Resources/KameraTestprofile.json`, `FitnessMember/Workout/Kamera/KameraTestprofile.swift` | Debug-Testprofile (Task 5) |
| `FitnessMember/Workout/Kamera/Bildquelle.swift`, `FrontkameraQuelle.swift`, `AbspielQuelle.swift`, `Kameraerlaubnis.swift` | Bildquellen und Erlaubnis (Task 6) |
| `FitnessMember/Workout/Kamera/KameraAblaufModell.swift`, `Hubspeicher.swift` | App-Modell (Task 7) |
| `FitnessMember/Screens/Kamera/*.swift` | Ansichten (Task 8, 9) |
| `FitnessMember/Screens/Geraet/GeraetView.swift`, `Screens/Training/PausenScreen.swift`, `Screens/Profil/…` (Debug-Zeile) | Einbindung (Task 5, 8, 9) |
| `project.yml` | `KoerperErkennung` linken, Kameratext (Task 6) |
| `FitnessMemberTests/GeraetKameraNahtTests.swift`, `KameraAblaufModellTests.swift`, `KameraTestprofileTests.swift` | App-Tests (Task 4, 5, 7) |

Pfade unter `apps/ios-member/`, wo nicht anders angegeben.

## Texte

Aus Spec 7 und Canvas, wörtlich:
- 7.1: Kopf „ÜBUNG n VON m“ (nur wenn bekannt, sonst weglassen), Name in Versalien, „Gerät · s Sätze · w Wdh.“; „DEIN TEMPO“; `Uebungstempo.inWorten`; „Gleich siehst du dich selbst im Bild. Der Punkt folgt deiner Bewegung, halte ihn auf der Welle.“; Knöpfe „Handy aufstellen“, „Ohne Kamera trainieren“. Erlaubnis fehlt: „Kamera ist nicht erlaubt“, „In den Einstellungen erlauben“, „Ohne Kamera trainieren“.
- 7.2: „AUFSTELLEN · NAME“; Zeile je Profil: `ganzkoerperStehend` „Lehn das Handy an und stell dich in den Rahmen.“, `oberkoerper` „Oberkörper von vorn reicht.“; Gruppen: `schultern` „Kopf und Schultern“, `arme` „Ellbogen und Hände“, `hueftenKnie` „Hüfte und Knie“, `fuesse` „Füße“ mit „… erkannt“ / „… fehlen im Bild“; Entlastung bei `oberkoerper`: „Beine müssen nicht ins Bild“; Anweisungen: „Stell dich in den Rahmen“, „Geh einen Schritt zurück“, „Geh etwas nach links“, „Geh etwas nach rechts“, „Mehr Licht oder näher ran“; Aufstellhilfe `oberkoerper`: „Handy hochkant auf Hüfthöhe“ / „Etwa 1,5 m vor dir, zum Beispiel auf der Hantelablage.“, `ganzkoerperStehend`: „Handy hochkant an den Boden lehnen“ / „Etwa 2 m vor dir, der ganze Körper muss ins Bild.“; „Ohne Kamera“. Kamera nicht verfügbar: „Die Kamera startet gerade nicht.“ mit „Ohne Kamera trainieren“.
- 7.3: „SATZ n VON s · NAME“, „Du bist ganz im Bild“, „Geh in die Startposition und bleib kurz ruhig stehen.“, „LOS IN“, Ziffer, „Abbrechen“.
- 7.4: „SATZ n VON s“, Name, Phasenwort „SENKEN“/„HALTEN“/„HEBEN“, Pille „Im Takt“ / „Zu schnell, langsamer <verb>“ / „Zu langsam, zügiger <verb>“ (verb = „senken“/„heben“; in der Haltephase „halten“ → „Zu schnell, länger halten“ / „Zu langsam, jetzt <nächster Weg>“), Zähler „n von s Wdh.“ (ohne Soll nur „n Wdh.“), „Satz beenden“, Videoknopf `accessibilityLabel` „Übungsvideo noch einmal ansehen“. Bildrate: „Dein Handy kommt nicht mehr mit.“ mit „Ohne Kamera weiterzählen“.
- 7.5: „SATZ n VON s · PAUSIERT“, „Wir sehen dich nicht mehr“, „Die Welle wartet. Deine n Wiederholungen bleiben gezählt. Stell dich wieder in den Rahmen, dann geht es von allein weiter.“, „Ohne Kamera weiterzählen“, „Satz bei n Wdh. beenden“; Vorlauf: „Gleich geht es weiter“ + Ziffer.
- Fehlerfälle: keine Bewegung „Bereit? Tippen zum Neustart“; Hub zu klein „Wir erkennen die Bewegung nicht sicher“ + „Ohne Kamera weiterzählen“.
- 7.6: „NAME · SATZ n VON s“, „SATZ GESCHAFFT“, „WDH.“, „IM TAKT“ x „von“ n, „TEMPO JE WIEDERHOLUNG“, Ausreißersatz (Task 9), „Zu kurz für einen Rückblick“, „PAUSE“ + Uhr, „Satz n starten“, „Wdh. korrigieren“; nach dem letzten Satz „Gerät abschließen“ / „Weiterer Satz“; Sichern abgelehnt: der Text aus `satzAbgelehnt` unter der Überschrift.
- Pausenansicht: „Satz n mit Kamera“ (Übung läuft mit Kamera, Rückblick geschlossen) bzw. „Mit Kamera“ (nach „Ohne Kamera“).

---

### Task 1: `Aufstellanweisung`

**Files:**
- Create: `Packages/Koerperbild/Sources/Koerperbild/Aufstellanweisung.swift`
- Test: `Packages/Koerperbild/Tests/KoerperbildTests/AufstellanweisungTests.swift`

**Interfaces:**
- Consumes: `Skelett`, `Punkt`, `Gelenk`, `Erkennungspruefung` (`fehlendeGruppen`, `imRahmen`, `fuehrendeSeite`), `Kameravorgabe.pflichtgelenke(_:)`, `Gelenkgruppe.gelenke(_:)`.
- Produces:
  ```swift
  public enum Aufstellanweisung: Equatable, Sendable {
      case inDenRahmen, schrittZurueck, nachLinks, nachRechts, mehrLicht, passt
      public static func aus(skelett: Skelett?, pruefung: Erkennungspruefung, vorgabe: Kameravorgabe) -> Aufstellanweisung
  }
  ```

Regeln in dieser Reihenfolge, die erste zutreffende gilt (Koordinaten des ungespiegelten Bilds, 0…1, Ursprung oben links):
1. Kein Skelett oder kein Gelenk mit `sicherheit >= Skelett.mindestSicherheit` → `.inDenRahmen`.
2. Eine fehlende Pflichtgruppe, deren Gelenke im Skelett als Punkte mit Sicherheit unter 0,3 vorkommen → `.mehrLicht`.
3. Eine fehlende Pflichtgruppe ohne Punkte, oder ein sicheres Pflichtgelenk mit `y < 0,04` oder `y > 0,96` → `.schrittZurueck`.
4. Mittel `m` der x-Werte der sicheren Pflichtgelenke; in der gespiegelten Anzeige liegt der Körper bei `1 − m`: `1 − m > 0,7` → `.nachLinks`, `1 − m < 0,3` → `.nachRechts`.
5. Sonst `!pruefung.imRahmen` → `.schrittZurueck`, sonst `.passt`.

„Dreh dich zur Seite“ entfällt: der Check besteht frontal, die Anweisung käme nie zum Tragen (offener Punkt für E5, siehe Ende).

- [ ] **Step 1: Failing tests** – je Regel ein Test mit künstlichem Skelett (Helfer wie in `ErkennungspruefungTests`): `keinSkelettHeisstInDenRahmen`, `unsichereFuesseHeissenMehrLicht` (Füße mit 0,2), `fehlendeFuesseHeissenSchrittZurueck` (`ganzkoerperStehend`, Signal `knie`), `kopfAmOberenRandHeisstSchrittZurueck` (Schulter y 0,02), `koerperRechtsImBildHeisstNachRechts` (m = 0,8 → Anzeige 0,2 → `.nachRechts`), `koerperLinksImBildHeisstNachLinks` (m = 0,2), `oberkoerperOhneBeinePasst` (`oberkoerper`, Signal `ellbogen`, keine Hüft-/Beinpunkte → `.passt`).
- [ ] **Step 2:** `swift test --filter AufstellanweisungTests` → FAIL (Typ fehlt).
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** `swift test` (ganzes Package) → alle grün.
- [ ] **Step 5:** Commit `feat(koerperbild): Aufstellanweisung fuer den Aufstell-Check`.

### Task 2: `KameraSatzAblauf` – Video, Aufstellen, Countdown, Satz

**Files:**
- Create: `Packages/Koerperbild/Sources/Koerperbild/KameraSatzAblauf.swift`
- Test: `Packages/Koerperbild/Tests/KoerperbildTests/KameraSatzAblaufTests.swift`

**Interfaces:**
- Consumes: Task 1; `Erkennungspruefung`, `Koerperlage` (`verarbeite`, `los`, `istRuhig`, `wiederholungen`, `fuehrendeSeite`, `hubGrad`, `hubZuKlein`, `hubWarGemerkt`, `unterbrechen`), `Uebungstempo` (`vorgabe`, `phase(_:)`, `beginntMit`), `Sollwelle` (`lage(bei:)`, `weg(bei:)`, `inDerBahn(_:bei:)`, `periode`), `Satzrueckblick`, `Lage`.
- Produces (Task 3 ergänzt nur Übergänge, keine neuen öffentlichen Namen außer den hier genannten):
  ```swift
  public struct KameraSatzAblauf: Sendable {
      public enum Schritt: Equatable, Sendable {
          case video, aufstellen
          case countdown(rest: Int?)      // nil: wartet auf 0,5 s Ruhe; sonst 3, 2, 1
          case satz, verloren
          case vorlauf(rest: Int)         // 2, 1
          case keineBewegung
          case bewegungZuKlein
          case fertig(Satzende)
      }
      public enum Satzende: Equatable, Sendable {
          case beendet(Satzergebnis)
          case ohneKamera(gezaehlt: Int?)
      }
      public struct Satzergebnis: Equatable, Sendable {
          public let wiederholungen: Int
          public let rueckblick: Rueckblick?      // nil unter 3 Wdh.
          public let hubGrad: Double?
      }
      public enum Takt: Equatable, Sendable { case imTakt, zuSchnell, zuLangsam }
      public struct Spurpunkt: Equatable, Sendable { public let sollzeit: TimeInterval; public let lage: Double; public let sicher: Bool }

      public init(vorgabe: Kameravorgabe, tempo: Uebungstempo, gemerkterHub: Double?, mitVideo: Bool)
      public private(set) var schritt: Schritt
      public var wiederholungen: Int
      public private(set) var sollzeit: TimeInterval?       // Sekunden seit der (letzten) Los-Marke, steht in .verloren
      public let welle: Sollwelle
      public var phase: Tempophase?                          // aus welle.weg(bei: sollzeit) über tempo.phase
      public private(set) var takt: Takt
      public private(set) var spur: [Spurpunkt]              // letzte 6 s Sollzeit
      public var fehlendeGruppen: Set<Gelenkgruppe>
      public private(set) var anweisung: Aufstellanweisung
      public private(set) var bildrateZuNiedrig: Bool
      public let tempo: Uebungstempo
      public let vorgabe: Kameravorgabe

      public mutating func handyAufstellen()
      public mutating func bild(t: TimeInterval, skelett: Skelett?)
      public mutating func abbrechen()
      public mutating func satzBeenden()
      public mutating func neuStarten()
      public mutating func unterbrechen()
      public mutating func ohneKamera()
  }
  ```
  `Rueckblick` ist der Typ aus `Satzrueckblick.swift`.

Verhalten in diesem Task (Zeit kommt nur über `bild(t:)`; jedes Bild geht an `pruefung.eingabe` und `koerperlage.verarbeite`):
- Start: `.video` bei `mitVideo`, sonst `.aufstellen`. `handyAufstellen()` nur aus `.video`.
- `.aufstellen`: `anweisung` und `fehlendeGruppen` je Bild neu; `pruefung.bestanden` → `.countdown(rest: nil)`.
- `.countdown(nil)`: `koerperlage.istRuhig` → Countdown startet bei diesem `t`, `rest` = 3, 2, 1 (aufgerundete Restsekunden). Bei Ablauf: `koerperlage.los(t:)`, Los-Marke `t0 = t`, `.satz`. `pruefung.verloren` im Countdown → `.aufstellen`. `abbrechen()` → `.aufstellen`.
- `.satz`: `sollzeit = t − t0`; `Lage` aus `verarbeite` → `satzrueckblick.erfasse(lage, sollzeit:)` und an `spur` (ältere als 6 s weg). Sobald `koerperlage.fuehrendeSeite` erstmals nicht nil ist: `pruefung.seiteFesthalten(_)` (Vermerk Teil 1).
- Takt: Liegt eine sichere Lage länger als 0,5 s ununterbrochen außerhalb `welle.inDerBahn`, wird `takt` `.zuSchnell` oder `.zuLangsam`, zurück auf `.imTakt` beim ersten Bild in der Bahn. Richtung: Soll steigt (`welle.lage(bei: s+0,05) > welle.lage(bei: s)`) und Ist > Soll → zu schnell; Soll fällt und Ist < Soll → zu schnell; Halten: Ist < Soll − Bahn → zu schnell (zu früh zurück); sonst zu langsam.
- `satzBeenden()` aus `.satz`: mit mindestens 1 Wdh. → `.fertig(.beendet(ergebnis))`, sonst `.fertig(.ohneKamera(gezaehlt: nil))`. Ergebnis: `wiederholungen = koerperlage.wiederholungen.count`, `rueckblick = satzrueckblick.ergebnis(wiederholungen:)`, `hubGrad = koerperlage.hubGrad`.
- `ohneKamera()` aus jedem nicht fertigen Schritt → `.fertig(.ohneKamera(gezaehlt: n > 0 ? n : nil))`.

- [ ] **Step 1: Failing tests** mit einem Skelett-Generator im Test (Kniewinkel als Funktion der Zeit, Pflichtgelenke von `ganzkoerperStehend` sicher; `Uebungstempo(senken: 2, halten: 0, heben: 1, beginntMit: .senken)`, gemerkter Hub 90°):
  - `beginntMitVideoNurWennVerlangt`
  - `aufstellenBestehtNachEinerSekunde` (0,9 s → `.aufstellen`, 1,05 s → `.countdown(rest: nil)`)
  - `countdownWartetAufRuhe` (Knie wackelt ±10° → bleibt `nil`; ruhig 0,5 s → `rest == 3`)
  - `countdownZaehltDreiZweiEins` und `nachDreiSekundenLaeuftDerSatz` (`sollzeit == 0` am Übergang)
  - `pflichtgelenkImCountdownVerlorenZurueckZumAufstellen` (Füße fehlen 1,1 s)
  - `abbrechenImCountdownFuehrtZumAufstellen`
  - `saubereSaetzeZaehlenUndBleibenImTakt` (5 Wdh. genau nach Welle → `wiederholungen == 5`, `takt == .imTakt` durchgehend)
  - `zuSchnellNachEinerHalbenSekundeNebenDerBahn` (Senken in 1 s statt 2 s → `.zuSchnell` erst nach > 0,5 s neben der Bahn)
  - `satzBeendenOhneWiederholungFuehrtOhneKamera`
  - `satzBeendenLiefertErgebnisMitRueckblickAbDrei` (2 Wdh. → `rueckblick == nil`; 3 Wdh. → nicht nil)
  - `ohneKameraNimmtGezaehlteMit`
- [ ] **Step 2:** `swift test --filter KameraSatzAblaufTests` → FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** `swift test` → alle grün.
- [ ] **Step 5:** Commit `feat(koerperbild): KameraSatzAblauf bis zum laufenden Satz`.

### Task 3: `KameraSatzAblauf` – Tracking verloren, Satzende, Fehlerfälle

**Files:**
- Modify: `Packages/Koerperbild/Sources/Koerperbild/KameraSatzAblauf.swift`
- Test: `KameraSatzAblaufTests.swift`, Create `KameraSatzAblaufAbspielTests.swift`

**Interfaces:** nur die Namen aus Task 2.

Übergänge:
- `.satz` + `pruefung.verloren` → `.verloren`: `koerperlage.unterbrechen()`, `sollzeit` steht, `takt = .imTakt`. Kürzere Aussetzer: Lage nicht sicher, nichts weiter (die Spur trägt `sicher: false`).
- `.verloren` + `pruefung.bestanden` → `.vorlauf(rest: 2)`, dann 1; nach 2 s neue Los-Marke (`koerperlage.los(t:)`, `t0 = t`, `sollzeit = 0`) → `.satz`. Gezählte Wiederholungen bleiben. `pruefung.verloren` im Vorlauf → `.verloren`.
- `satzBeenden()` auch aus `.verloren` und `.vorlauf` (Knopf „Satz bei n Wdh. beenden“).
- Satzende von selbst: in `.satz` mit mindestens 1 Wdh. und `koerperlage.istRuhig` ununterbrochen 8 s → wie `satzBeenden()`.
- Keine Bewegung: in `.satz` mit 0 Wdh., `sollzeit > 2 × tempo.vorgabe.periode` und seit der Los-Marke nie `!istRuhig` länger als 0,5 s → `.keineBewegung`. `neuStarten()` → `.countdown(rest: nil)`, Rückblick und Spur neu.
- Hub zu klein: `koerperlage.hubZuKlein` in `.satz` → `.bewegungZuKlein`. Von dort nur `ohneKamera()` (→ `.ohneKamera(gezaehlt: n)`).
- Bildrate: Abstand der `t` der letzten Bilder; liegt die mittlere Rate über ein gleitendes Fenster von 3 s unter 15/s → `bildrateZuNiedrig = true` (in `.satz`, `.vorlauf`; nicht blockierend), sonst false.
- `unterbrechen()` (App im Hintergrund): aus `.satz`/`.vorlauf` → `.verloren` mit `koerperlage.unterbrechen()`; aus `.countdown` → `.aufstellen`; immer `pruefung.zuruecksetzen()` (die festgehaltene Seite bleibt).

- [ ] **Step 1: Failing tests**
  - `aussetzerUnterEinerSekundeHaeltDenSatz` (0,8 s ohne Füße → bleibt `.satz`, Zählung durchgehend richtig)
  - `pflichtgelenkLaengerAlsEineSekundeVerlorenPausiert` (`sollzeit` steht in `.verloren`)
  - `wiedereinstiegMitZweiSekundenVorlaufUndNeuerLosMarke` (`sollzeit == 0` nach Vorlauf, Wdh. vorher bleiben; angefangene Wdh. vor dem Verlust zählt nicht doppelt)
  - `satzBeendenAusVerlorenLiefertGezaehlte`
  - `achtSekundenRuheBeendetDenSatz` (7,9 s → `.satz`, 8,1 s → `.fertig(.beendet)`)
  - `ruheOhneWiederholungBeendetNicht` sondern → `.keineBewegung` nach zwei Perioden; `neuStartenFuehrtZumCountdown`
  - `zuKleinerHubFuehrtZumHinweis` (Hub 12°, kein gemerkter Hub)
  - `langsameBildrateMeldetSich` (10 Bilder/s über 3,1 s → true; 30/s → false)
  - `hintergrundImSatzPausiertUndVerlangtAufstellen`
  - `einarmigFolgtDemArbeitendenArm` (`oberkoerper`, `ellbogen`, `.beide`; rechter Arm ruht sicherer erkannt, linker curlt → Zählung stimmt, danach Verlust nur des rechten Arms löst **kein** `.verloren` aus, Vermerk Teil 1 `seiteFesthalten`)
- [ ] **Step 2: Abspieltest** `KameraSatzAblaufAbspielTests`: für zwei Skelettdateien aus `data/koerperbild/skelette/` – eine `oberkoerper` (Zuordnung `zuordnung.json`, z. B. ein Kurzhantel-Curl mit „zählt richtig“) und eine `ganzkoerper_stehend` – Bilder mit `t = i / bildrate` einspeisen, nach dem Countdown die Wdh. zählen lassen, `satzBeenden()`; erwartet wird die Wiederholungszahl aus `data/koerperbild/versuch-2026-11-23.csv` ± 1. Pfad wie `SkelettDateienTests` (über `#filePath`). Vorlaufzeit: die Videos beginnen in Bewegung; der Test speist zuerst 1,6 s das erste Bild ein (Aufstellen + Ruhe).
- [ ] **Step 3:** FAIL prüfen, implementieren, `swift test` → alle grün.
- [ ] **Step 4:** Commit `feat(koerperbild): Tracking verloren, Satzende und Fehlerfaelle im KameraSatzAblauf`.

### Task 4: Naht in `GeraetModel`

**Files:**
- Create: `FitnessMember/Workout/Kamera/KameraNaht.swift`
- Modify: `FitnessMember/Screens/Geraet/GeraetModel.swift`
- Test: `FitnessMemberTests/GeraetKameraNahtTests.swift` (Helfer `modell(...)`, `ZaehlerDouble`, `GeraetTestdaten` aus `GeraetModelTests.swift` wiederverwenden; Übung mit `kamera`/`tempo` über `BootstrapResponse.Exercise` mit gesetztem `KameraDTO`)

**Interfaces:**
- Produces:
  ```swift
  // KameraNaht.swift
  struct KameraStart: Equatable {
      let exerciseId: String
      let name: String
      let geraet: String?            // geraetLabel
      let vorgabe: Kameravorgabe
      let tempo: Uebungstempo
      let sollWiederholungen: Int?   // umfang der Startwerte
      let satzZiel: Int
  }
  enum KameraWahl: Equatable { case keine, mitKamera, ohneKamera }
  enum KameraEinstieg: Equatable { case video, aufstellen }
  enum KameraSichern: Equatable { case gesichert(letzterSatz: Bool), abgelehnt(String) }

  @MainActor protocol KameraNaht: AnyObject {
      var kameraStart: KameraStart? { get }
      var kameraWahl: KameraWahl { get }
      var kameraEinstieg: KameraEinstieg { get }
      var anzeigeSatz: Int { get }
      var laufendePause: Resttimer? { get }
      var satzAbgelehnt: String? { get }
      func kameraSatzSichern(wiederholungen: Int) async -> KameraSichern
      func kameraVerlassen(gezaehlt: Int?)
      func kameraAblaufSchliessen()
      func kameraWiederAufnehmen()
      func umfangNachtragen(_ wiederholungen: Int)
      func pauseBeenden()
      func weitererSatz()
  }
  ```
  `GeraetModel: KameraNaht`, dazu `var kameraAblaufOffen: Bool` (lesbar und schreibbar für die Bindung).

Verhalten:
- `kameraStart`: nil, wenn `imZirkel`, `istCardio`, die aktive Übung keine `kameravorgabe`/`uebungstempo` hat oder `vorgabe.profil == .ohneKamera`. Quelle: `station.exercises.first { $0.id == uebungId }` mit den Extensions aus `UebungKamera.swift`; im Debug-Build danach `KameraTestprofile.ergaenzt(_:)` (Task 5; bis dahin nicht aufrufen).
- `uebungStarten(mit:mitCountdown:)`: ist `mitCountdown` true und `kameraStart != nil` → Phase `.eingabe` **ohne** Countdown, `kameraWahl = .mitKamera`, `kameraEinstieg = .video`, `kameraAblaufOffen = true`. Sonst unverändert. Im Zirkel kommt `mitCountdown` immer false (TrainingRootView), dort bleibt `kameraWahl = .keine`. `uebungWechseln(zu:)` setzt `kameraWahl = .keine`.
- Sensor stilllegen, solange `kameraWahl == .mitKamera` **oder** der laufende Satz mit Kamera begonnen hat (`kameraSatzOhneSensor`, zurückgesetzt bei `pauseBeenden()`/`weitererSatz()` mit `kameraWahl != .mitKamera`): `mitschnittBeginnen()` ruft `zaehler?.satzBeginnt` und `automatikBeobachten` nicht (der Mitschnitt läuft weiter); `automatikEreignis` und `zaehlerMeldung` kehren sofort zurück; `satzLokalSichern` liest `zaehler?.ergebnis()` nicht → Herkunft `.eingegeben`.
- `kameraSatzSichern(wiederholungen:)`: setzt `umfang = wiederholungen` (ohne Einrasten auf `umfangsWerte`, Zahl wie gezählt), ruft `satzLokalSichern(problemFlag: false, problemReason: nil)`. Rückgabe `.abgelehnt(satzAbgelehnt!)` wenn danach `satzAbgelehnt != nil`, sonst `.gesichert(letzterSatz: phase == .abschluss)`. `kameraAblaufOffen` bleibt true (Rückblick).
- `kameraVerlassen(gezaehlt:)`: `kameraWahl = .ohneKamera`, `kameraAblaufOffen = false`; mit `gezaehlt` → `umfang = gezaehlt`, `zaehlerZustand = .vonHand(gezaehlt)`. Der Sensor bleibt für diesen Satz still.
- `kameraAblaufSchliessen()`: nur `kameraAblaufOffen = false` (Rückblick schließen, Gewicht ändern in der Pause); `kameraWahl` bleibt `.mitKamera`.
- `kameraWiederAufnehmen()`: `kameraWahl = .mitKamera`, `kameraEinstieg = .aufstellen`, `kameraAblaufOffen = true`; in `.pause` zusätzlich `pauseBeenden()`.
- `pauseBeenden()` (bestehend): ist `kameraWahl == .mitKamera`, danach `kameraEinstieg = .aufstellen`, `kameraAblaufOffen = true`. Doppelter Aufruf bleibt wirkungslos (bestehender Guard). `weitererSatz()` aus `abschluss`: ebenso.
- `umfangNachtragen(_:)`: korrigiert den zuletzt gesicherten Satz dieser Übung: `sessions.letzterWrite(blockId:)` holen, `body.volume` ersetzen, lokal am Satz setzen und denselben `setId` erneut einreihen – Muster `WorkoutSessionStore.reserveNachtragen` (neue Methode `umfangNachtragen(blockId:umfang:enqueue:)` dort, mit Test). Herkunft bleibt `.eingegeben`. Ohne letzten Write: nichts.

- [ ] **Step 1: Failing tests**
  - `kameraUebungStartetOhneCountdownMitOffenemAblauf`
  - `ohneProfilZeitUebungUndZirkelBleibenWieHeute` (je `kameraStart == nil`, Countdown läuft, `kameraAblaufOffen == false`)
  - `kameraSatzWirdMitGezaehlterZahlEingegebenGesichert` (`body.volume == 7`, `volumeSource` eingegeben, Pause läuft)
  - `kameraSatzAbgelehntMeldetGrund` (Ortswechsel-Fall aus `GeraetModelTests` nachbauen)
  - `sensorAutomatikIstImKameraSatzStill` (`ZaehlerDouble` mit `automatikAktiv`, `.beendet` melden → kein Write; `ergebnis` 3 gesetzt, Kamera sichert 7 → `volume == 7`, eingegeben)
  - `ohneKameraWeiterzaehlenStelltRadUndSichertNicht` (`gezaehlt: 5` → `umfang == 5`, keine Writes, Sensor-`.stand(2)` ändert `umfang` nicht)
  - `pausenendeOeffnetAblaufBeimAufstellen` und `pausenendeNachOhneKameraOeffnetNichts`
  - `rueckblickSchliessenLaesstKameraWahl`; `mitKameraAusDerPauseBeendetPauseUndOeffnet`
  - `umfangNachtragenSchicktDenLetztenSatzErneut` (gleicher `setId`, neues `volume`)
- [ ] **Step 2:** Test laufen lassen → FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** Suite + `GeraetModelTests` + `ZaehlerKoordinatorTests` → grün.
- [ ] **Step 5:** Commit `feat(geraet): schmale Naht fuer den Kamera-Ablauf`.

### Task 5: Testprofile im Debug-Build

Zum Bauen und Testen braucht es Übungen mit `ganzkoerper_stehend` und `oberkoerper`, ohne Freischalt-Liste, Katalogdatei oder Datenbank anzufassen (Prod hat 0077 nicht, die API liefert kein `kamera`).

**Files:**
- Create: `tools/kamera-zuordnung/testprofile.py`, `FitnessMember/Resources/KameraTestprofile.json` (erzeugt, eingecheckt), `FitnessMember/Workout/Kamera/KameraTestprofile.swift`, Debug-Zeile in der bestehenden Debug-Sektion von `ProfilRootView` (dort, wo die Sensor-Debug-Zeilen stehen)
- Modify: `GeraetModel.kameraStart` (ein Aufruf, `#if DEBUG`)
- Test: `FitnessMemberTests/KameraTestprofileTests.swift`

**Interfaces:**
- Produces:
  ```swift
  #if DEBUG
  enum KameraTestprofile {
      static var aktiv: Bool              // UserDefaults "kamera.testprofile", Standard false
      static func ergaenzt(_ uebung: BootstrapResponse.Exercise) -> BootstrapResponse.Exercise
      static func katalogKey(name: String) -> String?   // für die Abspielquelle (Task 6)
  }
  #endif
  ```
- `testprofile.py` liest `data/koerperbild/zuordnung.json` und `catalog/gymtavo.json`, schreibt je Übung mit Profil `ganzkoerper_stehend` oder `oberkoerper` `{ "name", "key", "kamera": {profil, signal, seite, beginnt_mit}, "tempo": {senken_s, halten_s, heben_s} }` als Liste, sortiert nach `key`. Aufruf `python3 tools/kamera-zuordnung/testprofile.py` (ohne Argumente, Pfade relativ zum Repo).
- `ergaenzt`: nur wenn `aktiv` und `uebung.kamera == nil`; Zuordnung über den Namen (Gymtavo-Katalognamen sind eindeutig; studioeigene Übungen bleiben ohne). Setzt `kamera` und `tempo` (Memberwise-Init des DTO).
- Die JSON-Datei liegt im Bundle (rund 30 KB, auch im Release; gelesen wird sie nur im Debug-Build).
- Debug-Zeile: Schalter „Kamera-Testprofile“ mit Untertitel „Profile aus dem Zuordnungsvorschlag (Ganzkörper stehend, Oberkörper)“.

- [ ] **Step 1: Failing tests** `testprofilErgaenztBekannteUebung` (Name aus der JSON → `kameravorgabe?.profil == .oberkoerper`), `ausgeschaltetBleibtAllesWieGeliefert`, `vorhandenesServerprofilGewinnt`, `unbekannterNameBleibtOhne`.
- [ ] **Step 2:** Skript schreiben, ausführen, JSON prüfen (`python3 -c` zählt 96 Einträge: 78 + 18).
- [ ] **Step 3:** Implementieren, `xcodegen generate`, Tests → grün.
- [ ] **Step 4:** Commit `feat(kamera): Testprofile im Debug-Build aus dem Zuordnungsvorschlag`.

### Task 6: Bildquellen und Erlaubnis

**Files:**
- Create: `FitnessMember/Workout/Kamera/Bildquelle.swift`, `FrontkameraQuelle.swift`, `AbspielQuelle.swift` (`#if DEBUG`), `Kameraerlaubnis.swift`
- Modify: `project.yml`
- Vorlage (nur lesen): `.claude/worktrees/kamera-versuch/apps/ios-member/Packages/KameraVersuch/Sources/KameraVersuch/Quellen.swift`, `KameraVersuchModell.swift` (Anzeige-Layer)

**Interfaces:**
- Produces:
  ```swift
  struct Kamerabild: @unchecked Sendable { let t: TimeInterval; let skelett: Skelett?; let anzeige: CMSampleBuffer? }
  enum BildquellenFehler: Error, Equatable { case nichtErlaubt, nichtVerfuegbar }

  @MainActor protocol Bildquelle: AnyObject {
      /// Liefert Bilder auf dem MainActor. Wirft bei fehlender Erlaubnis/Kamera.
      func starten(beiBild: @escaping @MainActor (Kamerabild) -> Void) async throws
      func stoppen()
      /// Ziel für das Livebild; die Quelle stellt Bilder selbst ein.
      var anzeige: AVSampleBufferDisplayLayer { get }
  }

  enum Kameraerlaubnis: Equatable { case offen, erlaubt, verweigert
      static var aktuell: Kameraerlaubnis          // AVCaptureDevice.authorizationStatus(for: .video); .restricted → .verweigert
      static func anfragen() async -> Kameraerlaubnis
  }

  @MainActor enum Bildquellen { static func fuer(_ start: KameraStart) -> any Bildquelle }
  ```
- `FrontkameraQuelle`: aus dem Versuch übernehmen (Preset `.hd1280x720`, `.builtInWideAngleCamera` `.front`, `alwaysDiscardsLateVideoFrames`, eigene serielle Queue). Abweichungen: `isVideoMirrored = false` (Spiegelung nur in der Anzeige), Drehwinkel über `AVCaptureDevice.RotationCoordinator.videoRotationAngleForHorizonLevelCapture` (aufrechtes Bild für `PoseErkenner`, der `.up` erwartet). Auf der Capture-Queue: `anzeige.sampleBufferRenderer.enqueue` (mit `DisplayImmediately`, `flush` bei `.failed`), dann `PoseErkenner.erkennen(CMSampleBufferGetImageBuffer)`; nur ein Bild zugleich in der Erkennung (spätere verwerfen); Ergebnis mit `t` = PTS-Sekunden per `Task { @MainActor in beiBild(...) }`. Kein Gerät / `canAddInput` false / Laufzeitfehler (`AVCaptureSessionRuntimeError`) → `nichtVerfuegbar` werfen bzw. melden (Bild mit `skelett: nil` reicht nicht: eigener Rückruf `beiFehler: (@MainActor () -> Void)?`).
- `AbspielQuelle` (nur `#if DEBUG`, und nur gewählt, wenn die Launch-Option `-kameraAbspielen <Repo-Wurzel>` gesetzt ist, `UserDefaults.standard.string(forKey: "kameraAbspielen")`): Video `<Wurzel>/catalog/media/videos/<key>.mp4` mit `AVAssetReader` (32BGRA) in Echtzeit wie `VideoQuelle` im Versuch, am Ende von vorn; Skelett je Bildnummer aus `<Wurzel>/data/koerperbild/skelette/<key>.skelett.json` über `Skelettfolge(daten:)`; `key` über `KameraTestprofile.katalogKey(name:)`. Fehlt etwas → `nichtVerfuegbar`. Das Video wird für die Anzeige als `CMSampleBuffer` eingestellt; die Abspielquelle spiegelt nicht.
- `Bildquellen.fuer`: Debug + Launch-Option → `AbspielQuelle`, sonst `FrontkameraQuelle`. Im Simulator ohne Option wirft die Frontkamera `nichtVerfuegbar` (das ist der Fehlerfall „Kamera nicht verfügbar“).
- `project.yml`: App-Target zusätzlich `- package: Koerperbild` mit `product: KoerperErkennung`; `NSCameraUsageDescription`: „Gymtavo braucht die Kamera, um den QR-Code am Gerät oder am Studioeingang zu scannen und beim Training deine Bewegung zu erkennen. Die Bilder bleiben auf deinem iPhone.“ (Vorschlag, Tim prüft mit dem Datenschutztext).

Keine Unit-Tests für AVFoundation; geprüft wird in Task 7 mit einer Test-Bildquelle und in Task 10 am Gerät.

- [ ] **Step 1:** Dateien anlegen, `xcodegen generate`, `xcodebuild build` für Simulator → BUILD SUCCEEDED, keine neuen Warnungen zu Sendable.
- [ ] **Step 2:** Commit `feat(kamera): Frontkamera- und Abspielquelle, Kameraerlaubnis`.

### Task 7: `KameraAblaufModell`

**Files:**
- Create: `FitnessMember/Workout/Kamera/KameraAblaufModell.swift`, `Hubspeicher.swift`
- Test: `FitnessMemberTests/KameraAblaufModellTests.swift` (mit `TestBildquelle: Bildquelle`, die Bilder auf Zuruf liefert oder wirft, und `NahtDouble: KameraNaht`)

**Interfaces:**
- Consumes: Tasks 2–4, 6.
- Produces:
  ```swift
  @MainActor @Observable final class KameraAblaufModell {
      enum Ansicht: Equatable {
          case erlaubnisFehlt              // 7.1 mit Einstellungen-Weg
          case kameraFehlt                 // Kamera nicht verfügbar
          case ablauf                      // Schritt aus `ablauf.schritt`
          case rueckblick(Rueckblickdaten) // nach dem Sichern
      }
      struct Rueckblickdaten: Equatable { let wiederholungen: Int; let rueckblick: Rueckblick?; let abgelehnt: String?; let letzterSatz: Bool; let tempo: Uebungstempo }
      init(naht: any KameraNaht, quelle: @escaping @MainActor (KameraStart) -> any Bildquelle = Bildquellen.fuer, hub: Hubspeicher = .standard, erlaubnis: @escaping () -> Kameraerlaubnis = { .aktuell }, anfragen: @escaping () async -> Kameraerlaubnis = Kameraerlaubnis.anfragen)
      private(set) var ansicht: Ansicht
      private(set) var ablauf: KameraSatzAblauf?
      var videoOffen: Bool
      var quelle: (any Bildquelle)? { get }
      func erscheint() async         // Einstieg nach naht.kameraEinstieg, ggf. Kamera starten
      func handyAufstellen() async   // Erlaubnis fragen, dann Kamera starten
      func ohneKamera()
      func satzBeenden() async
      func abbrechen(); func neuStarten()
      func naechsterSatz() async     // „Satz n starten“ / „Weiterer Satz“
      func rueckblickSchliessen()    // „Gerät abschließen“ und Schließen für Gewicht ändern
      func umfangKorrigieren(_ n: Int)
      func szene(aktiv: Bool)        // scenePhase
      func verschwindet()            // Kamera aus, Idle-Timer zurück
  }
  struct Hubspeicher { static let standard: Hubspeicher; func hub(_ exerciseId: String) -> Double?; func merken(_ hub: Double, fuer exerciseId: String) }
  ```

Verhalten:
- `erscheint()`: `kameraStart` nil → `naht.kameraVerlassen(gezaehlt: nil)`. Einstieg `.video` → Maschine mit `mitVideo: true`, Kamera erst bei `handyAufstellen()`; Einstieg `.aufstellen` → Erlaubnis prüfen, Kamera starten. `isIdleTimerDisabled = true`.
- Erlaubnis `.verweigert` → `ansicht = .erlaubnisFehlt`. `.offen` → `anfragen()` bei `handyAufstellen()`; danach verweigert → `.erlaubnisFehlt`.
- Kamera starten wirft `nichtVerfuegbar` oder meldet den Fehler später → `ansicht = .kameraFehlt`. Kamera läuft nur in `.aufstellen`…`.vorlauf`/`.satz`/`.verloren`/`.keineBewegung`; bei `.fertig` und im Rückblick `stoppen()`.
- Jedes `Kamerabild` → `ablauf.bild(t:skelett:)`. Erreicht die Maschine `.fertig(.beendet(e))`: Hub merken, `await naht.kameraSatzSichern(wiederholungen: e.wiederholungen)` **genau einmal**, dann `ansicht = .rueckblick(...)` (auch bei `.abgelehnt`). `.fertig(.ohneKamera(g))` → `naht.kameraVerlassen(gezaehlt: g)`.
- Rückblick: beobachtet `naht.laufendePause?.endetAm`; läuft die Pause ab (eigener Task, der bis `endetAm` schläft), ruft es `naht.pauseBeenden()` (wirkungslos, wenn die Übungsansicht schneller war) und beginnt den nächsten Satz bei `.aufstellen` (neue Maschine, `mitVideo: false`, gemerkter Hub). `naechsterSatz()`: in Pause `naht.pauseBeenden()`, im letzten Satz `naht.weitererSatz()`, dann ebenso.
- `rueckblickSchliessen()` → `naht.kameraAblaufSchliessen()`.
- `umfangKorrigieren(n)` → `naht.umfangNachtragen(n)` und Rückblickzahl anpassen.
- `szene(aktiv: false)` → `ablauf.unterbrechen()`, Kamera stoppen; `aktiv: true` → Kamera wieder starten, sofern ein Bild-Schritt läuft.

- [ ] **Step 1: Failing tests**
  - `videoEinstiegStartetKameraErstBeimAufstellen`
  - `verweigerteErlaubnisZeigtHinweis` und `offeneErlaubnisWirdBeimAufstellenGefragt`
  - `kameraNichtVerfuegbarZeigtHinweisOhneAbsturz`
  - `satzendeSichertGenauEinmalUndZeigtRueckblick` (Bilder eines Satzes mit 4 Wdh. einspeisen, `satzBeenden()` zweimal tippen → ein Aufruf mit 4)
  - `abgelehntesSichernZeigtRueckblickMitGrund`
  - `ohneKameraImSatzUebergibtGezaehlte`
  - `pausenendeStartetNaechstenSatzBeimAufstellen` (Resttimer mit 0,1 s)
  - `hubWirdGemerktUndBeimNaechstenSatzGenutzt`
  - `hintergrundStopptKameraUndPausiert`
- [ ] **Step 2:** FAIL, implementieren, Suite grün.
- [ ] **Step 3:** Commit `feat(kamera): KameraAblaufModell verbindet Quelle, Ablauf und Naht`.

### Task 8: Ansichten 7.1–7.3 und Einbindung

**Files:**
- Create in `FitnessMember/Screens/Kamera/`: `KameraAblaufAnsicht.swift` (Wurzel, schaltet nach `ansicht`/`schritt`), `UebungsvideoSchritt.swift` (7.1 inkl. `erlaubnisFehlt`), `AufstellSchritt.swift` (7.2 inkl. `kameraFehlt`), `CountdownSchritt.swift` (7.3), `Livebild.swift` (`UIViewRepresentable` mit dem `AVSampleBufferDisplayLayer` der Quelle, `videoGravity .resizeAspectFill`, gespiegelt per `CATransform3DMakeScale(-1, 1, 1)` – nur bei der Frontkamera), `Strichfigur.swift` (`Canvas`, Knochenliste lokal definieren wie `Skelett.knochen` im Versuch, x gespiegelt, Abbildung über dieselbe Aspect-Fill-Rechnung wie das Livebild), `Aufstellrahmen.swift`, `EinmalVideo.swift` (AVPlayer, `actionAtItemEnd = .pause`, stumm, Tippen spielt von vorn; Reduce Motion: erstes Bild), `Wellenband.swift` (Task 9 nutzt es mit Spur)
- Modify: `GeraetView.swift` (`GeraetScreen`): `.fullScreenCover(isPresented: $modell.kameraAblaufOffen) { KameraAblaufAnsicht(modell: KameraAblaufModell(naht: modell)) }` an einem eigenen Hintergrund-View, damit es nicht mit der Kalibrierungs-Abdeckung kollidiert; `.environment` für `UebungsVideoVorrat` weiterreichen.

`Wellenband(welle:, tempo:, sollzeit:, spur:, punkt:, gedaempft:)`: Fenster 2,5 Perioden, Jetzt-Linie bei 40 % der Breite, läuft von rechts nach links; Soll-Linie `Color.text` 55 % Deckkraft, 4 pt; Spur und Punkt `Color.accent` (bei `takt != .imTakt` das Stück seit dem Verlassen der Bahn und der Punkt in `Color.warn`); Lage 0 oben, wenn `beginntMit == .senken`, sonst unten (die Welle geht in der Bewegungsrichtung). In 7.1 ohne Spur und Punkt, Sollzeit läuft aus `TimelineView`. Ohne Video: Platzhalter wie Canvas (Kreis mit Dreieck, „Kein Video verfügbar“).

Aussehen nach den Canvas-Dateien `Main`, `Aufstellen`, `AufstellenBizeps`, `Bereit`: Kopf- und Fußleisten `Color.bg` mit 82 % Deckkraft über dem Livebild, Checkliste mit Haken (`accent`) bzw. Warnkreis (`warn`) bzw. Strich (`textMuted`), Anweisungskarte unten mit `warn`-Rand (Profil-Aufstellhilfe mit `line`-Rand, wenn `anweisung == .passt`), Rahmen gestrichelt `text` bzw. durchgezogen `accent` ab `.countdown`. Rahmengröße je Profil: `ganzkoerperStehend` 80 % × 66 % der Höhe, `oberkoerper` 74 % × 51 %, mittig, 24 pt Radius. „Ohne Kamera“ oben rechts in jedem Schritt. Text mindestens 15 pt, Zähler/Countdown `Typography.wertHeld`.

- [ ] **Step 1:** Ansichten bauen, `#Preview` je Schritt mit festem `KameraSatzAblauf` (Vorschau braucht keine Kamera).
- [ ] **Step 2:** `xcodebuild build` → SUCCEEDED; App-Tests `GeraetKameraNahtTests`, `KameraAblaufModellTests` grün.
- [ ] **Step 3:** Simulator: Testprofile an, Launch-Option `-kameraAbspielen <Repo-Wurzel>`, eine Oberkörper-Übung starten → Video, Aufstellen, Countdown sichtbar; Screenshot je Schritt nach `/private/tmp/…/scratchpad`.
- [ ] **Step 4:** Commit `feat(kamera): Video, Aufstellen und Countdown als Vollbild-Ablauf`.

### Task 9: Ansichten 7.4–7.6, Pausenknopf

**Files:**
- Create in `FitnessMember/Screens/Kamera/`: `SatzSchritt.swift` (7.4, Fehler-Banner Bildrate, `keineBewegung`- und `bewegungZuKlein`-Hinweise als Karten über dem Livebild), `VerlorenSchritt.swift` (7.5 inkl. Vorlauf), `RueckblickAnsicht.swift` (7.6), `Ausreisser.swift` (Satz zu den Ausreißern), `WiederholungKorrigieren.swift` (Sheet mit einem Rad 0…`max(30, n+10)`, „Übernehmen“)
- Modify: `Screens/Training/PausenScreen.swift` (optionaler Knopf), `GeraetView.swift` (Knopf an PausenScreen geben)

`SatzSchritt` nach `ImTakt`/`ZuSchnell`: Livebild + Strichfigur dezent (50 % Deckkraft, im Satz nur das Signalgelenk kräftig), Band ab 64 % der Höhe, 160 pt hoch, Phasenwort links, Pille rechts, Fußleiste `Color.bg` mit Zähler und „Satz beenden“; Videoknopf oben rechts öffnet `EinmalVideo` klein (Karte 40 % Breite oben rechts), Welle und Zählung laufen weiter. Nach Erreichen der Soll-Zahl: Band gedämpft (Soll-Linie 30 %). Nicht sichere Lage: Punkt mit 35 % Deckkraft.

`Ausreisser.satz(rueckblick:tempo:) -> String?`: nimmt die erste nicht leere Liste in der Reihenfolge `zuSchnellRueck, zuSchnellHin, zuLangsamRueck, zuLangsamHin`, übersetzt Hin/Rück mit `tempo.phase(.kraftweg/.ablassen)` (Vermerk Teil 1) und bildet „Bei Wdh. 4 und 7 warst du beim Senken zu schnell. Lass dir die vollen 3 Sekunden.“ (zu langsam: „… beim Heben zu langsam. Zügiger, etwa 2 Sekunden.“); Sekunden aus `tempo`, ganzzahlig ohne „,0“; bei einer Wdh. „Bei Wdh. 4 warst du …“; drei und mehr „Bei Wdh. 2, 4 und 7 …“. Keine Ausreißer: „Alle Wiederholungen im Takt.“ (Wenn alle bewertet sind.) Unit-Test `AusreisserTests` mit diesen vier Fällen.

`RueckblickAnsicht` nach `Satzende`: Balken je Wiederholung (im Takt `accent` 64 pt; neben dem Takt `#B36F00`-Ton aus dem Canvas als `Color.warn` mit 70 % Deckkraft, Höhe 96/88 pt je nach Urteil zu schnell/zu langsam; leerer Balken `surfaceRaised` bei `imTakt == nil`), Pausenuhr aus `laufendePause.endetAm` mit `TimelineView`. Knöpfe nach Spec 7.6 und Texten oben. Schließen-Knopf oben links (`xmark`, `accessibilityLabel` „Rückblick schließen“) → `rueckblickSchliessen()`.

`PausenScreen`: neuer optionaler Parameter `kameraKnopf: (titel: String, aktion: () -> Void)?`, als Sekundärknopf unter den bestehenden. GeraetView gibt ihn, wenn `kameraWahl == .mitKamera` („Satz n mit Kamera“) oder `.ohneKamera` mit `kameraStart != nil` („Mit Kamera“); Aktion `modell.kameraWiederAufnehmen()`.

- [ ] **Step 1:** `AusreisserTests` schreiben → FAIL → implementieren → grün.
- [ ] **Step 2:** Ansichten bauen, Previews.
- [ ] **Step 3:** Build + alle App-Tests (`xcodebuild … test`) → grün, Zahl der Tests notieren.
- [ ] **Step 4:** Simulator wie Task 8 bis zum Rückblick; Pause ablaufen lassen (Pausendauer im Plan der Testübung kurz) → nächster Satz beginnt bei Aufstellen; „Ohne Kamera weiterzählen“ → Rad steht auf der Zahl.
- [ ] **Step 5:** Commit `feat(kamera): Satz mit Welle, Tracking verloren, Rueckblick`.

### Task 10: Vorführung und Gerätebuild (Leitung, kein Subagent)

- [ ] **Step 1:** Simulator mit Testkonto (Memory „Testaccount Member-App“), Testprofile an, `xcrun simctl launch booted de.gymtaro.member -kameraAbspielen <Repo-Wurzel>`; Ablauf für eine `oberkoerper`- und eine `ganzkoerper_stehend`-Übung Tim im Simulator-Panel zeigen. Fehlerfälle im Simulator vorführen: ohne Launch-Option (Kamera nicht verfügbar), Erlaubnis verweigert (`xcrun simctl privacy booted revoke camera de.gymtaro.member`).
- [ ] **Step 2:** Schlussprüfung über den ganzen Branch (superpowers:requesting-code-review), Funde beheben.
- [ ] **Step 3:** Signierter Debug-Build auf „Just4Us“ (`xcodebuild -destination 'platform=iOS,name=Just4Us'` bzw. `devicectl`); Tim schaltet in der App „Kamera-Testprofile“ ein.
- [ ] **Step 4:** Plan um „Stand nach der Umsetzung“ ergänzen (Abweichungen, Ungeprüftes, Messpunkte fürs Studio).

---

## Offen bei Tim (berührt den Bau, im Plan mit dem Spec-Vorschlag umgesetzt)

1. **„Wdh. korrigieren“ (Spec 7.6)** nennt eine „bestehende Korrektur“, die es nicht gibt: Heute korrigiert man nur am Rad vor dem Sichern. Plan: der Rückblick korrigiert den eben gesicherten Satz, indem derselbe Satz mit neuer Zahl erneut geschickt wird (Muster Reserve-Frage). Alternative: Knopf weglassen.
2. **Gewicht zwischen den Sätzen (13.2):** Plan nach Vorschlag – Rückblick schließen, in der Pausenansicht ändern, dort „Satz n mit Kamera“.
3. **Welle bei „Ohne Kamera“ (13.3):** Plan nach Annahme 9 – alles wie heute; die Vorgabe-Welle (7.8) ist E5.
4. **Kameratext in `NSCameraUsageDescription`:** Vorschlag in Task 6; der Datenschutztext bleibt offen.
5. **„Dreh dich zur Seite“** entfällt vorerst (Task 1). Ob der Kniewinkel von vorn trägt, zeigt das Studio.
6. Zuordnungsliste, Ausfallschritte rückwärts, Beingeräte: berühren E3/E4 nicht, weil die Testprofile im Debug-Build aus dem Vorschlag kommen.
