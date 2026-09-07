# iOS Member-App — Gerät-Kernflow (Sub-Projekt 2 von 4)

**Stand:** 7. September 2026
**Status:** Entschieden, bereit für Umsetzungsplan.
**Vorbedingung:** Sub-Projekt 1 (Fundament + Zugang) ist gebaut und in `master` gemergt — `APIClient`, `SessionStore`, `CatalogStore`, `DesignSystem`, Navigations-Hülle stehen.
**Zitierweise:** `§n` ohne Dokumentangabe verweist auf `2026-08-30-designsystem.md`; Verweise innerhalb dieses Dokuments stehen als „Abschnitt n".
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten) und `2026-08-30-designsystem.md` (Aussehen/Gefühl). Dieses Dokument bestimmt, *wie* Sub-Projekt 2 gebaut wird, und hält die Stellen fest, an denen es von beiden begründet abweicht.

---

## 1. Ausgangslage: zwei Punkte der Klärliste sind noch offen

`2026-09-07-member-app-design-challenge.md` §2 führt acht Punkte, die vor dem Swift-Start geklärt sein sollen. Ihr Abschnitt §5 beschreibt die Klärung als erledigt. Für die Gerät-Gruppe stimmt das nicht — nachgemessen am tatsächlichen Stand:

- **`designsystem.md` ist unverändert** (Commit `803b89e`, Stand 30. August). §6 „Bewegung" trägt weiterhin nur drei Bullets; die dort angekündigten Spring-/Momentum-Werte für die Rad-Geste existieren nicht.
- **Die Artboard-Korrekturen sind nicht angekommen.** `GeraetWertRad` hat weiter 50 px Wiederholungswert und den gefüllten Reserve-Chip, `GeraetErsteWerte` 58 px, `GeraetProblem` 60 px Hauptaktion und das gefüllte `#FFB020`-Badge, `GeraetKalibrierung` den falschen Deaktiviert-Token, `Main` den Akzent-Link „andere Übung", `GeraetErkannt` das Akzent-Badge „ERKANNT".
- Die Design-Challenge selbst ist unversioniert.

Damit sind **Punkt 1 (Akzentregel) und Punkt 2 (Bewegungs-Spec)** der Klärliste für diese Screen-Gruppe hier zu entscheiden. Beides geschieht in diesem Dokument: die Akzentkorrekturen in Abschnitt 9, die Bewegungswerte in Abschnitt 6.

Zwei Zusagen aus der SP1-Spec sind ebenfalls nicht gebaut und fallen hierher, weil sie zur Bewegungs- und Feedback-Schicht gehören:

- **`PrimaryButton` hat kein Press-Feedback.** `DesignSystem.Color.accentPressed` ist definiert und wird nirgends verwendet — der Design-Challenge-Befund „kein `:active`-Feedback für einen einzigen Button in der gesamten Canvas" ist unverändert nach Swift durchgeschlagen.
- **Es gibt keinen `NWPathMonitor`.** `CatalogStore.flushPending()` hat damit heute überhaupt keinen Auslöser.

---

## 2. Scope

**Enthalten:**

- Server: `bootstrap` um `machines[].visitCount` (Abschnitt 4.1) und `machines[].equipmentModel.settingDefinitions` (Abschnitt 4.1b) erweitern; neuer Endpoint `POST /api/v1/me/calibrations` (Abschnitt 4.2)
- iOS: `WorkoutSessionStore` (laufende Einheit, auf Platte persistiert), `NetzwerkMonitor`, `MachineResolver` (lokale Token-Auflösung), Einstiegsentscheidung als reine Funktion
- iOS: `RastRad` als wiederverwendbare Komponente, Press-Feedback als `ButtonStyle` im `DesignSystem`
- Die zehn Gerät-Artboards, umgesetzt als sechs Views (Abschnitt 7)
- Minimale Training-Wurzel: Scan-Button, Blockliste, „Training beenden" (Abschnitt 7.1)
- Reparaturen an `flushPending()` (Abschnitt 8.2)

**Nicht enthalten** (eigene Spec später):

- Vollausbau des Training-Tabs nach `TrainingLeer` / `TrainingLaeuft` / `TrainingAbschluss` — Sub-Projekt 3
- Kurse, Home, Session-Detail, Übungsfortschritt, vollständiges Profil — Sub-Projekte 3 und 4
- Der RIR-Schalter im Profil (nur die Vorbereitung, Abschnitt 7.6) — Sub-Projekt 4
- Medien-Cache für Gerätefotos und Videos (Abschnitt 8.4 begründet die Auslassung)
- Push-Benachrichtigungen

---

## 3. Zuschnitt: warum die Training-Wurzel mitkommt

Der Geräte-Screen ist laut `designsystem.md` §11 ein Push **innerhalb** des Training-Tabs, und der ist aus Sub-Projekt 1 ein `PlaceholderView`. Ohne eine minimale Wurzel wäre der Kernflow nicht schließbar:

- `POST .../complete` hätte keinen Auslöser — „Training beenden" lebt laut M1 §5.2 im Training-Tab.
- „Zurück zum Training" auf `GeraetResttimer` liefe ins Leere.
- Der Zirkelfall aus M1 §5.3 („im zweiten Durchgang nicht scannen, sondern Block antippen") wäre nicht baubar und nicht testbar.

Die Wurzel bleibt bewusst schmucklos: Scan-Button, Blockliste der laufenden Session, „Training beenden". Der Artboard-Ausbau der drei Training-Screens bleibt Sub-Projekt 3.

---

## 4. Server-Anteil

Drei Änderungen. Alle klein, aber ohne sie ist der Flow nicht baubar.

### 4.1 `bootstrap` → `machines[].visitCount`

Die Einstiegsentscheidung aus `designsystem.md` §8 braucht drei Größen. Zwei liefern die Endpoints bereits (Erstkontakt je Paar aus `calibrations`/`lastSets`, genutzte Übungen aus `lastSets`). Die dritte — **Anzahl Besuche an diesem Gerät** — liefert keiner.

Sie muss aus `bootstrap` kommen, nicht aus `tagContext`: M1 §8.1 Schritt 3 verlangt, dass der Screen sofort aus dem Prefetch rendert, bevor das Netz antwortet. Eine Entscheidung, die auf `tagContext` wartet, verletzt das.

`getBootstrap` liest bereits bis zu `SET_SCAN_LIMIT` (2000) Zeilen aus `workout_sets` und verwirft alles außer dem jeweils neuesten je (Gerät, Übung). Es genügt, `session_id` in dieses bestehende `select` aufzunehmen und im selben Durchlauf die unterschiedlichen Sessions je `machine_id` zu zählen. **Keine zusätzliche Abfrage.**

`visitCount` wird über das gelesene Fenster voll gezählt; die Entscheidung wertet davon nur 0 / 1 / ≥ 2 aus. Das Scan-Limit ist damit unkritisch. Der Randfall „sehr alte Sätze fallen aus dem 2000er-Fenster, `visitCount` liest fälschlich 0" wird abgefangen, weil Erstkontakt zusätzlich das Fehlen einer Kalibrierung verlangt (Abschnitt 7.2) — Kalibrierungen werden ungedeckelt gelesen.

### 4.1b `bootstrap` liefert die Einstellparameter mit

*Nachgetragen am 7. September, beim Ausschreiben der Screens im Umsetzungsplan gefunden.*

Der Offline-Zustand zeigt die eigenen Einstellwerte **mit Beschriftung** („Sitz 4 · Lehne 2 · Startwinkel 30°", `GeraetOffline.dc.html`). Die Werte stehen als `settingValues` im Prefetch — die Beschriftungen aber nur in `equipment_setting_definitions`, und die liest `getBootstrap` gar nicht. Offline stünde dort der rohe Schlüssel („sitz 4").

`machines[].equipmentModel` bekommt deshalb `settingDefinitions`. Das kostet **eine** zusätzliche Abfrage — anders als §4.1, das ohne auskommt. Vertretbar: die Definitionen sind Studioinhalt, klein, je Modell geteilt, und RLS beschränkt sie ohnehin auf die Studios des Mitglieds.

Swiftseitig ist das bewusst **derselbe Typ** wie in `tagContext` (`TagContextResponse.SettingDefinition`), damit `GeraetModel` online und offline dieselbe Liste verarbeitet statt zwei Formen zu kennen.

Die Alternative — offline den rohen Schlüssel zeigen — wurde verworfen: „sitz 4" ist kein Text, den ein Mitglied im Halbdunkel lesen soll, und §5 verlangt, dass ein Zustand erklärt statt nur anzeigt.

### 4.2 `POST /api/v1/me/calibrations`

**Es gibt heute keinen Schreibweg für die Kalibrierung.** Die Tabelle `member_machine_calibrations` steht seit Migration `0014` inklusive Insert-Policy, beide Lesepfade (`bootstrap`, `tag-context`) nutzen sie — aber es gibt weder Domain-Funktion noch Route. M1 §6.3 listet keinen, obwohl §8.3 Schritt 4 und `GeraetKalibrierung` („Speichern und weiter") ihn zwingend brauchen.

Neue Domain-Funktion `recordCalibration`:

```text
POST /api/v1/me/calibrations
  { machineId, exerciseId, settingValues, schemaVersion, source }
  → die angelegte Zeile
```

- Zod-Schema wie die übrigen Domain-Eingaben.
- **Serverseitige Validierung** jedes Eintrags in `settingValues` gegen `equipment_setting_definitions` des Modells: `min_value`, `max_value`, `step_value`, `allowed_values`, `kind`. `designsystem.md` §7.4 verlangt das ausdrücklich; ein JSONB ohne Validierung wäre ein Freitextfeld mit anderem Namen.
- Anfügend, nie überschreibend — die Tabelle hat bewusst weder Update- noch Delete-Policy.
- `source` kommt aus dem Schalter „Ein Trainer war dabei". `recorded_by` bleibt `null`: die Insert-Policy erzwingt `user_id = auth.uid()`, und ein Trainer weist sich in der Member-App nicht aus. Der Artboard-Text sagt korrekt nur „Wird an der Einstellung vermerkt" und bleibt unverändert.

**Korrektur an M1 §6.3.** Der Satz „Sechs Endpoints für die gesamte Member-App" stimmt nicht mehr. Sub-Projekt 1 hat bereits `POST /studios/join-by-code`, `POST /studios/join-by-tag` und `DELETE /studios/{id}/membership` ergänzt und als „außerhalb §6.3" vermerkt; dieser Endpoint ist der vierte Zusatz. Die Architekturaussage dahinter — screenorientiert statt ressourcenorientiert, keine Fachlogik im Client — bleibt unangetastet.

---

## 5. Das Wertrad

Die zentrale Geste der App: ein Tap auf Gewicht **oder** Wiederholungen öffnet **beide** Räder, danach wird nur noch gescrollt.

### 5.1 Der tragende Kniff

`designsystem.md` §7 sagt: „die Linie bleibt liegen, die Zahlen ziehen daran vorbei." Das heißt, die 4-pt-Akzentlinie gehört **nicht** zur scrollenden Zeile. Sie liegt als statisches Element im `ZStack` hinter dem Scroller auf Höhe der Mittelzeile und bewegt sich nie.

Daraus folgt: **Ruhe und Offen sind dieselbe View.** Der einzige Unterschied ist, ob die Nachbarn sichtbar und der Scroller aktiv ist. Der Übergang wird damit tatsächlich eine Bewegung statt eines Aufbaus (§7), und `GeraetWertRad` ist kein zweiter Screen, sondern ein Zustand von `GeraetView`.

### 5.2 Aufbau

```swift
struct RastRad: View {                    // ein Typ für beide Räder
    let werte: [Double]                   // aus dem Gerätemodell erzeugt
    @Binding var auswahl: Double
    let offen: Bool
    let unterstrich: UnterstrichStil      // .akzent(4) | .linie(3)
}
```

- `ScrollView(.vertical, showsIndicators: false)` mit `VStack(spacing: 0)`, jede Zeile 44 pt (§4: „Radzeile 44 pt").
- `.scrollTargetLayout()` auf dem Stack, `.scrollTargetBehavior(.viewAligned)` auf dem Scroller, `.scrollPosition(id: $auswahl)` als Zwei-Wege-Bindung.
- `.safeAreaPadding(.vertical, 88)`, damit Minimum und Maximum mittig einrasten können (2 × 44 pt).
- Kein `LazyVStack`: 59 Zeilen bei 5,0–150,0 in 2,5er-Schritten sind nichts, und `.scrollPosition` verhält sich mit einem festen `VStack` verlässlicher.

**Warum der System-Scroller und keine eigene Geste:** Momentum-Projektion, Deceleration-Kurve, Rubber-Banding an den Enden und Unterbrechbarkeit kommen damit von UIKit. Das sind genau die vier Dinge, die eine handgeschriebene `DragGesture` als erstes falsch macht — bei der laut §9 am häufigsten ausgelösten Geste der App das größte vermeidbare Risiko. `UIPickerView` scheidet aus, weil sein Auswahlbalken nicht abschaltbar ist und §7 ihn ausdrücklich verbietet.

### 5.3 Nachbar-Optik

`.scrollTransition(.interactive)` je Zeile, gesteuert über `phase.value`:

| Position | Größe | Farbe | Opazität |
| --- | --- | --- | --- |
| Mitte | 64 pt Black, tabellarisch | `text` | 1,0 |
| ± 1 | 30 pt | `text-faint` | 0,55 |
| ± 2 | 26 pt | `line` | 0,25 |

Dazu eine `LinearGradient`-Maske `clear → black → clear` über dem Scroller, die die von §7 verlangte Ausblendung nach `bg` erzeugt.

Das ist eine Positionsfunktion, keine Animation — sie bleibt unter Reduce Motion unverändert.

### 5.4 Rastung und Grenzen

Die Werteliste wird aus dem Gerätemodell erzeugt, nie aus dem Entwurf:

```swift
stride(from: minWeightKg, through: maxWeightKg, by: weightStepKg)
```

Quelle ist `tagContext.equipmentModel`, offline `bootstrap.machines[].equipmentModel`. Ein Wert, den das Gerät nicht kann, ist damit strukturell unmöglich — genau das Versprechen aus §7.

Zwei Randfälle:

- **`maxWeightKg == nil`** (die Spalte ist nullable): Das Rad endet bei `minWeightKg + 200 · weightStepKg`, und es gibt kein Anschlag-Feedback, weil kein dokumentierter Anschlag existiert. Der Server rechnet an dieser Stelle mit 9999 — als Radlänge wäre das absurd.
- **Wiederholungen:** 1 – 40, Schritt 1. Die Datenbank ließe bis 1000 zu; ein Rad ist kein Formularfeld, und 1–40 deckt jedes reale Kraft- und Ausdauerschema ab.

### 5.5 Feedback

- **Rastung:** `.sensoryFeedback(.selection, trigger: auswahl)`. Sichtbar ist sie ohnehin, weil sich die Zahl ändert — Haptik ist damit nie die einzige Rückmeldung (§6).
- **Anschlag:** `.sensoryFeedback(.impact(weight: .light))` **plus** sichtbar: Die Kontextzeile unter der Linie wechselt von „Schritt 2,5 kg · 5,0 – 150,0" auf „Maximum des Geräts erreicht" in `text-muted`. Die Design-Challenge bemängelte, dass es für sehende Nutzer bisher gar kein Anschlagsfeedback gibt; damit ist es erledigt.

### 5.6 VoiceOver

Der Scroller bekommt `.accessibilityHidden(true)`. Darüber liegt ein einzelnes Element:

- `.accessibilityLabel("Gewicht")` bzw. `"Wiederholungen"`
- `.accessibilityValue("80,0 Kilogramm")` — Wert und Einheit in **einer** Zeichenkette, sonst liest VoiceOver vier Elemente (§12)
- `.accessibilityAdjustableAction`, die genau einen Geräteschritt geht und den neuen Wert mit Einheit ansagt
- Am Anschlag wird „Maximum des Geräts erreicht" an den Wert angehängt

### 5.7 Dynamic Type

Die Zeilenhöhe ist ein `@ScaledMetric` auf 44 pt, die Radhöhe ergibt sich als fünf Zeilen. Der 64-pt-Heldwert skaliert nicht weiter (er ist bereits die größte Rolle im System), die Kontextzeilen tun es. Die Wertzeile ist ein vertikaler Stack, der ab XL umbricht statt zu skalieren (§12). Abnahmebedingung ist XXL.

---

## 6. Bewegung

Was UIKit liefert und hier bewusst **nicht** spezifiziert wird: Deceleration-Kurve, Momentum-Projektion, Rubber-Banding an den Enden, Unterbrechbarkeit.

Was wir spezifizieren, weil wir es tatsächlich fahren:

| Moment | Kurve | Was sich bewegt |
| --- | --- | --- |
| Räder öffnen (Tap auf Gewicht **oder** Wiederholungen öffnet beide) | `.spring(response: 0.34, dampingFraction: 0.86)` | Nachbarn faden von 0 auf Zielopazität und fahren aus der Mitte auf ihre Zeilenposition; der Einstellungsblock oben schrumpft auf eine Zeile |
| Räder schließen | dieselbe Kurve | rückwärts |
| Satz gesichert → Pause | `.spring(response: 0.4, dampingFraction: 0.9)` | Timerbalken fährt von oben ein, die neue Blockzeile schiebt sich in die Liste; dazu `.sensoryFeedback(.success)` |
| Press-Feedback, **alle** Buttons | `.spring(response: 0.22, dampingFraction: 0.9)` | `scaleEffect(0.97)` und `accent` → `accent-pressed` |

`response` unter 0,4 s hält den Öffnen-Moment innerhalb des „antippen und scrollen"-Gedankens; `dampingFraction` knapp unter 1 gibt einen Hauch Nachschwingen ohne Wackeln.

Das Press-Feedback wird **einmal** als `ButtonStyle` in `DesignSystem` definiert und von `PrimaryButton`/`SecondaryButton` benutzt — dieselbe Lehre wie bei den Maßkonstanten in Sub-Projekt 1: eine gemeinsame Komponente macht die Abweichung strukturell unmöglich statt nur unerwünscht.

**Reduce Motion** ersetzt alle vier durch Zustandswechsel ohne Interpolation. Keine Information geht verloren (§6).

**Interaktionsbudget nachgerechnet** (§9, Abnahmebedingung):

- Normalfall: ein Tap auf „Satz N sichern".
- Abweichungsfall: ein Tap öffnet beide Räder, Scrollen ist kostenlos, „Satz N sichern" bleibt im offenen Zustand sichtbar und sichert direkt — kein Schließen-Tap dazwischen. **Zwei Interaktionen.** ✔

---

## 7. Screens

Die zehn Artboards bilden Zustände ab, keine Navigationsziele. Sie werden zu sechs Views:

| Artboard(s) | Umsetzung |
| --- | --- |
| `GeraetErkannt` | eigene Push-View |
| `Main` · `GeraetWertRad` · `GeraetResttimer` · `GeraetOffline` | **eine** Push-View `GeraetView` in vier Zuständen (Rad zu / Rad offen / Pause läuft / kein Empfang) |
| `GeraetEinweisung` · `GeraetKalibrierung` · `GeraetErsteWerte` | ein `.fullScreenCover` mit drei Schritten |
| `GeraetUebungWechseln` | `.sheet` |
| `GeraetProblem` | `.sheet` |

Beide Sheet-Artboards tragen den Kommentar „abgedunkelter Geräte-Screen dahinter · Sheet"; der `fullScreenCover` verdeckt die Tab-Leiste und erfüllt damit „modaler Dreischritt ohne Tab-Leiste" (§8).

### 7.1 Training-Wurzel und Navigation

Der Training-Tab bekommt einen `NavigationStack` mit typisiertem Pfad. `GeraetErkannt` und `GeraetView` sind Pushes und behalten die Tab-Leiste (§11). „Zurück zum Training" bleibt zusätzlich zur System-Zurück-Geste als expliziter Ausstieg — Zirkeltrainierende brauchen ihn.

Die Wurzel selbst: Scan-Button (öffnet das bestehende `MemberScannerView`-Sheet aus Sub-Projekt 1, unverändert — es nimmt bereits ein `(String) -> Void`-Closure), Blockliste der laufenden Session, „Training beenden" (`POST .../complete`).

### 7.2 Einstiegsentscheidung

Als reine Funktion, damit sie ohne View testbar ist und offline aus dem Prefetch fällt:

```text
Erstkontakt je (Gerät, Übung)  ⟺  keine Kalibrierung ∧ kein lastSet für dieses Paar
visitCount == 0                →  GeraetErkannt; Tap auf eine Übung startet den Dreischritt
visitCount == 1                →  GeraetErkannt
visitCount ≥ 2, > 1 Übung      →  GeraetErkannt, zuletzt genutzte oben
visitCount ≥ 2, genau 1 Übung  →  direkt zu GeraetView
```

**Dokumentierte Abweichung von M1 §5.7.** Dort wird die Übungsauswahl übersprungen, sobald ein Gerät nur eine Übung trägt. `designsystem.md` §8 hebt das bewusst auf: „Jetzt entscheidet die Gewohnheit des Mitglieds, nicht der Katalog des Studios." Der Preis ist dort ausgerechnet (ein Tap ohne Wahlmöglichkeit beim zweiten Besuch an einem Ein-Übungs-Gerät) und der Gegenwert benannt (niemand findet eine Übung nie, weil die App zu früh optimiert hat). Dieses Dokument folgt §8. Dasselbe Muster wie in Sub-Projekt 1, wo die Spec den Code-statt-Link-Widerspruch aufgelöst hat.

### 7.3 Der Dreischritt

Einweisung → Kalibrierung → erste Werte. Er läuft genau einmal je Gerät **und** Übung.

- **„Kenne ich schon" überspringt nur die Einweisung**, nicht den ganzen Dreischritt. Übersprünge es alles, gäbe es weder Kalibrierung noch Startwert, und die Regel „kein Vorschlag beim ersten Mal" hätte nichts, worauf sie fallen könnte. Die Beschriftung wird deshalb von „Kenne ich schon — direkt zum Satz" auf **„Kenne ich schon"** gekürzt.
- **Fehlt ein Einweisungsvideo** (`instructionVideoUrl == nil`), ist das kein Fehlerzustand: der Schritt zeigt Foto und Einstellhinweise ohne Player. Das ist die „ohne Video"-Variante, die als Artboard fehlt.
- **Kalibrierung bleibt bei ± Steppern**, kein Rad — §8: einstellige Wertebereiche, ein Rad wäre dort mehr Mechanik als Nutzen. Sie ist zusätzlich von `GeraetView` aus erreichbar („ändern" neben „Sitz 4 · Lehne 2 · 30°"), außerhalb des Dreischritts.
- **Beim ersten Mal kein Vorschlag** (§8): Das Rad startet am Gerätminimum, unter der Linie steht kein „Vorschlag · +2,5".
- Der Haftungssatz aus §10 steht auf `GeraetEinweisung` **und** auf `GeraetView` — beides Pflichtorte.

### 7.4 Resttimer

- **90 s** als benannte Konstante. Kein Feld im Datenmodell, keine Einstellung in M1.
- Er läuft über einen gespeicherten `endsAt: Date`, **nicht** über einen Zähler — nur so hält er „Läuft weiter, auch wenn du wegsiehst" über Hintergrund und Sperrbildschirm. „+30 s" verschiebt `endsAt`.
- Anzeige über `TimelineView(.periodic(by: 1))`, Balken linear, kein Spinner (§6).
- **Reduce Motion** fällt hier von selbst richtig: die Sekundenschritte kommen ohnehin diskret, nur die `.linear(duration: 1)`-Interpolation dazwischen entfällt. Damit ist „der Balken springt sekundenweise" als umsetzbare Regel präzisiert.
- **VoiceOver:** Live-Region, auf **15 s** gedrosselt (§12) — ein eigener, langsamerer `TimelineView` für `accessibilityValue`, nicht das sekündliche Label. Ohne diese Trennung entstünde die naive 1:1-Kopplung, vor der die Design-Challenge warnt.
- Keine lokale Benachrichtigung: Push ist nicht in M1.

### 7.5 Problemmeldung

`.sheet` von `GeraetView`. Boolean plus feste Liste (`schmerz`, `geraet_passt_nicht`, `zu_schwer`, `sonstiges`) — kein Freitext, nirgends (§10, M1 §5.8). Kein eigener Endpoint: die Meldung sind zwei Felder im Satz-`PUT` (M1 §6.3). Das Auswahl-Badge trägt `warn` als **Umriss**, nie als Fläche (§2).

### 7.6 RIR / „Reserve"

Chips 0–4+, kein Rad (so das Artboard). Laut §9 optional und über das Profil abschaltbar; der Schalter selbst gehört zu Sub-Projekt 4. Hier kommt die Sichtbarkeit hinter ein `@AppStorage("rirSichtbar")` mit Vorgabe *an*, sodass Sub-Projekt 4 nur den Schalter anhängt statt die Screens anzufassen.

---

## 8. Zustand, Session-Lebenszyklus, Offline

### 8.1 `WorkoutSessionStore`

Ein neuer `@MainActor @Observable`-Store neben `SessionStore` und `CatalogStore`. Er hält die laufende Einheit und persistiert sie als JSON im App-Support-Verzeichnis — wie `PendingWriteStore`, aus demselben Grund: nach einem App-Kill muss „Satz 3" noch Satz 3 heißen und der Training-Tab seine Blöcke zeigen.

```swift
struct LokaleSession: Codable {
    let id: UUID
    let startedAt: Date
    var bloecke: [LokalerBlock]
}

struct LokalerBlock: Codable {
    let machineId: String
    let exerciseId: String
    var saetze: [LokalerSatz]
}
```

`setIndex` läuft **innerhalb des Blocks**, nicht innerhalb der Session — so verlangt es der Unique-Constraint `workout_sets_unique_index_per_block` aus Migration `0013`, und so trägt Zirkeltraining ohne Sonderlogik.

**Die Vier-Stunden-Regel gilt auf beiden Seiten.** M1 §5.2 wertet sie serverseitig träge aus. Aber `recordSet` upsertet die Session mit `ignoreDuplicates` und prüft **nicht**, ob sie bereits als beendet gilt — ein Client, der eine fünf Stunden alte `sessionId` weiterbenutzt, hängt Sätze an eine Einheit, die der Server längst als abgeschlossen liest. Der Store spiegelt die Regel deshalb lokal: liegt der letzte Satz mehr als vier Stunden zurück, gilt die Session als beendet, und der nächste Satz erzeugt eine neue `sessionId`.

### 8.2 Ein Schreibpfad, nicht zwei

**Jeder Satz geht durch die Warteschlange, immer:** lokal schreiben → `CatalogStore.enqueue` → sofort `flushPending()`. Nicht „erst direkt versuchen, bei Fehler einreihen".

Zwei Gründe: „gespeichert, wird gesendet" (§5) ist damit nie gelogen, und der Offline-Pfad ist derselbe, der jeden Tag läuft — statt der, den niemand testet. Online unterscheidet sich der Ablauf nur darin, dass die Schlange sofort wieder leer ist.

Zwei Reparaturen, die dieser Pfad erzwingt:

1. **`flushPending()` behält heute bei jedem Fehler.** Ein dauerhaft abweisbarer Schreibvorgang — Gerät stillgelegt, Übung entfernt, Token abgelaufen — bliebe für immer in der Schlange und würde bei jedem Netzwechsel neu versucht. Die Schlange unterscheidet künftig zwischen vorübergehend (`.offline`, `.server`) und dauerhaft (`.validation`, `.unauthorized`, nicht gefunden): vorübergehend behalten, dauerhaft verwerfen und sichtbar melden.
2. **`flushPending()` hat keinen Auslöser.** Ein `NetzwerkMonitor` (`@Observable`, um `NWPathMonitor`) kommt jetzt und speist zugleich die Offline-Leiste.

Serverseitige Validierungsfehler sind auf diesem Pfad praktisch ausgeschlossen, weil das Rad keinen ungültigen Wert erzeugen kann (Abschnitt 5.4). Der Fall wird trotzdem behandelt, statt ihn wegzuargumentieren.

### 8.3 Kalt- und Offline-Einstieg

M1 §8.1 Schritt 3: `MachineResolver` nimmt den Tag-Token, hasht ihn lokal mit CryptoKit (SHA-256) und sucht ihn in `bootstrap.machines[].tokenHashes`. Trifft er, rendert der Screen **sofort** — Gerät, Übungen, eigene Kalibrierung und letzte Werte stehen alle im Prefetch. Parallel läuft `tagContext(token:)` und ergänzt, was nur der Server hat: signiertes Gerätefoto, signierte Videos, den Vorschlag.

Genau das zeigt `GeraetOffline`: „Einweisungsvideo braucht Empfang. Deine Werte und deine Historie nicht."

Der Token wird nie gespeichert und nie protokolliert (M1 §10.4/§10.6). Der `PendingTagStore` aus Sub-Projekt 1 wird hier erstmals konsumiert: nach dem Login navigiert die App direkt zum getappten Gerät.

### 8.4 Kein Medien-Cache

`bootstrap` liefert für das Foto nur `photoPath`, keine signierte URL. **Offline gibt es deshalb kein Gerätefoto**, auch nicht beim zweiten Besuch; gezeigt wird der Platzhalter aus `GeraetOffline`.

Ein Medien-Cache wäre ein eigenes Thema mit Ablauf-, Speicher- und Invalidierungsfragen und wird hier bewusst nicht gebaut. Der Nutzen des Fotos — „stehe ich am richtigen Gerät?" — ist im Offline-Fall ohnehin schwächer, weil das Mitglied das Gerät gerade selbst getappt hat.

### 8.5 Der Reconnect-Moment

Fehlt als Artboard, wird hier festgelegt: Läuft die Warteschlange leer, wechselt die Karte „Wartet auf Empfang · 2 Sätze" für zwei Sekunden auf „Gesendet" und blendet dann aus; die `danger`-Offline-Leiste verschwindet.

Kein Toast, kein Häkchen-Jubel — §10 verbietet den Motivationston, und ein erfolgreicher Normalfall braucht keine Feier.

### 8.6 Der Vorschlag

Unter dem Gewicht steht „Vorschlag · +2,5", nie „Du solltest" (§10: eine Rechnung, keine Empfehlung). Der Wert kommt aus `tagContext.suggestion` und existiert offline nicht — dort steht stattdessen der letzte eigene Wert aus `bootstrap.lastSets`. Beim Erstkontakt steht dort nichts (Abschnitt 7.3).

---

## 9. Abweichungen vom Artboard

Swift wird gegen das Artboard **plus** diese Tabelle abgenommen. Die HTML-Dateien bleiben unangetastet; die Korrektur steht dort, wo sie beim Bauen gelesen wird.

| Artboard | Artboard zeigt | Swift baut | Warum |
| --- | --- | --- | --- |
| `Main` | „andere Übung" in `accent` | `text-muted` | §2, genau eine Akzentfläche |
| `GeraetErkannt` | „ERKANNT"-Badge in `accent` | `text-muted` | §2 |
| `GeraetWertRad` | Wiederholungswert 50 px | 44 pt | §3, gleiche Silhouette in Ruhe und Offen |
| `GeraetWertRad` | Reserve-Chip gefüllt | Umriss | §2 |
| `GeraetErsteWerte` | Gewichtswert 58 px | 64 pt | §3 |
| `GeraetProblem` | Warn-Badge als Fläche | Umriss | §2, „warn nie als Fläche" |
| `GeraetProblem` | Hauptaktion 60 px | 64 pt | §4 |
| `GeraetKalibrierung` | deaktivierter Stepper auf `surface` | `surface-raised` | §5 |
| `GeraetEinweisung` | „Kenne ich schon — direkt zum Satz" | „Kenne ich schon" | verspricht sonst mehr, als der Schritt halten darf (Abschnitt 7.3) |
| `GeraetEinweisung` | nur Variante mit Video | zusätzlich Variante ohne Video | fehlender Screen |
| `GeraetOffline` | nur Offline-Zustand | zusätzlich Reconnect-Zustand | fehlender Zustand (Abschnitt 8.5) |
| `GeraetOffline` | Gerätefoto | Platzhalter | `bootstrap` liefert keine signierte URL (Abschnitt 8.4) |

---

## 10. Tests

Die Logik liegt bewusst in reinen Funktionen, damit sie ohne View prüfbar ist.

**Swift Testing:**

- Einstiegsentscheidung: ein Test je Zeile der Tabelle aus Abschnitt 7.2, plus der Randfall „`visitCount` 0, aber Kalibrierung vorhanden" (Scan-Limit-Schutz)
- Rastwerte aus `weightStepKg` / `minWeightKg` / `maxWeightKg`, einschließlich `maxWeightKg == nil`
- Vier-Stunden-Grenze: derselbe Gerätetap vor und nach Ablauf ergibt dieselbe bzw. eine neue `sessionId`
- `flushPending()`: vorübergehender Fehler behält den Eintrag, dauerhafter verwirft ihn
- `setIndex` je Block über einen simulierten Prozess-Neustart
- Token-Hash-Auflösung gegen `tokenHashes`
- Resttimer aus `endsAt`, mit injizierter Uhr (keine echte Zeit im Test)

**Vitest (Server):**

- `visitCount` je Gerät, inklusive „zwei Sätze in derselben Session zählen einmal"
- `recordCalibration`: Validierung gegen `min_value` / `max_value` / `step_value` / `allowed_values`; anfügend, kein Update

**Manuell:**

- Jeder Zustand gegen Artboard plus Abweichungstabelle
- VoiceOver am Rad: Adjust geht genau einen Geräteschritt, Anschlagsansage kommt
- Reduce Motion: alle vier Bewegungen aus Abschnitt 6
- Dynamic Type bis XXL: die Wertzeile bricht um statt zu skalieren
- Ein vollständiger Flugmodus-Durchgang inklusive App-Kill und Reconnect

---

## 11. Selbstprüfung

- Keine Platzhalter oder offenen Punkte im Dokument.
- Kein Widerspruch zu `designsystem.md`. Die Abweichungen von der M1-Spec sind einzeln benannt und begründet: die Übungsauswahl (Abschnitt 7.2), der siebte Endpoint (Abschnitt 4.2), die beiden `bootstrap`-Zusätze (Abschnitte 4.1 und 4.1b).
- Die beiden für diese Gruppe offenen Punkte der Klärliste sind entschieden: Akzentregel in Abschnitt 9, Bewegungswerte in Abschnitt 6.
- Scope ist eng genug für einen Umsetzungsplan: drei Server-Änderungen, ein neuer Store, eine Komponente, sechs Views, eine minimale Training-Wurzel.
- Zwei Nachbesserungen aus Sub-Projekt 1 (Press-Feedback, `NWPathMonitor`) sind eingeplant statt stillschweigend übernommen.

---

## 12. Nächste Schritte

Nach Freigabe: `writing-plans`-Skill für den Umsetzungsplan zu Sub-Projekt 2, danach `subagent-driven-development`. Sub-Projekte 3 (Training & Kurse) und 4 (Home, Profil-Rest) bekommen je eine eigene Brainstorming-Runde.
