# Schnitt 1: Kalender, Karten, Überschriften — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Verlauf ist auf einen Blick lesbar. Im Home-Kalender und im Kurse-Wochenplan sagt dieselbe Regel, welcher Tag heute ist und welcher gewählt — Akzentring für heute, weiße Füllung für die Auswahl. Die Trainingskarte zeigt groß, was zählt (Zeit, Sätze) und klein, wann es war. Einheiten, die nur eine kurze Pause trennt, stehen in einer Karte. Die eigenen Kursanmeldungen tragen Überschriften nach Wochenabstand.

**Architecture:** Alles Client, kein Server, keine Migration. Drei neue reine Ableitungen (`HomeZeilen.trainingskarten`, `KurseMeineEinteilung.abschnitte`, die Farbregel als eigene Komponente) tragen die Entscheidungen; die Views werden dünner, nicht dicker. Die Tageszelle zieht aus `HomeSerieView` und `KurseWochenView` in **eine** Komponente `Kalenderzelle`, damit die Regel nicht an zwei Stellen auseinanderlaufen kann — sie ist heute genau deshalb an zwei Stellen verschieden.

**Tech Stack:** Swift 6 / SwiftUI / Swift Testing / XcodeGen (`apps/ios-member`).

**Quelle:** `docs/superpowers/plans/2026-09-12-ios-verbesserungen-aus-dem-betrieb.md`, Punkte 1, 4, 6, 7, 15, 17 — dort stehen die Entscheidungen und die Bilder dazu.

## Global Constraints

- **Kommentare in Swift ohne Umlaute** (ASCII). Nutzertexte tragen Umlaute.
- **Kommentare begründen, sie beschreiben nicht.**
- **Design-Tokens aus `DesignSystem.swift`**, nie als Literal: `bg` `#0A0B0D`, `surface` `#14161A`, `surfaceRaised` `#1D2026`, `line` `#2A2E36`, `text` `#F2F4F7`, `textMuted` `#9BA3AF`, `textFaint` `#5C636E`, `accent` `#D4FF3F`, `onAccent`. Radien `card` 12, `pille` 999. Abstände 4/8/12/16/24/32/48.
- **Eine Akzentfläche pro Screen** (designsystem.md §2). Dieser Schnitt NIMMT Akzentfläche weg (die gewählte Tageszelle im Kursplan) und gibt dem Akzent dafür eine Linie (der heutige Tag). Auf Home bleibt die Flamme die einzige Fläche, im Kursplan der Umschalter „Angemeldet/Alle Kurse".
- **Hit-Targets nie unter 44 pt** — die Zelle ist 40 pt, die Trefferfläche die ganze Spalte.
- **Die App misst nichts** (§10): keine Zahl behaupten, die nicht aus bestätigten Sätzen kommt. Betrifft hier die zusammengefasste Karte: die Pause zwischen zwei Teilen ist keine Trainingszeit.
- **Swift-Tests mit Swift Testing** (`import Testing`, `@Test`, `#expect`), als `struct`-Suite.
- **Neue Swift-Dateien brauchen keinen pbxproj-Eingriff:** `project.yml` zieht Verzeichnisse; nach dem Anlegen `xcodegen generate`.
- **Reihenfolge:** jede Ableitung kommt mit ihrem Test vor dem View, der sie benutzt.

---

## Task 1: Die Karte tauscht ihre Zeilen

Heute ist die Uhrzeitspanne die größte Zahl (`HomeZeilen.kartenTitel`), darunter steht klein „41 min · 1 Gerät · 3 Sätze" (`zeilenText`). Nach dem Tausch trägt die Karte oben **Zeit und Sätze** groß und darunter klein **Uhrzeit und Geräte**.

Die Entscheidung dahinter (Plan Punkt 17): keine Intensität. Die Gerätezahl bleibt, aber klein — sie sagt, was für ein Training es war, nicht wie viel.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Verlauf/HomeZeilen.swift`
- Modify: `apps/ios-member/FitnessMemberTests/HomeZeilenTests.swift`

**Interfaces:**
- Produces:
  - `HomeZeilen.grosseZeile(_ einheit: SessionSummary) -> String` — „41 min · 3 Sätze"; ohne Dauer (auto beendet) nur „3 Sätze"
  - `HomeZeilen.kleineZeile(_ einheit: SessionSummary) -> String` — „15:36 – 16:16 · 1 Gerät"; ohne Zeitraum „ab 15:36 · 1 Gerät"
- `kartenTitel` und `zeilenText` entfallen, sobald Task 2 und 4 durch sind — bis dahin bleiben sie stehen, damit der Baum grün bleibt.

- [ ] **Step 1: Tests schreiben** (`HomeZeilenTests`): Normalfall, auto beendete Einheit (keine Dauer, kein Zeitraum, „ab 08:32"), Einzahl/Mehrzahl bei einem Satz und einem Gerät.
- [ ] **Step 2: Beide Funktionen ergänzen**, aufgebaut auf den vorhandenen `dauerText`, `zeitraum`, `zahlWortMitPlural`.
- [ ] **Step 3: `xcodebuild test`** — grün, bevor ein View angefasst wird.

---

## Task 2: Benachbarte Einheiten werden eine Karte

Fünf Einträge an einem Freitag sind nicht fünf Trainings. **Unter 60 Minuten Lücke** gehört zusammen (Ende des einen bis Beginn des nächsten). Zusammengefasst wird **nur in der Anzeige** — die Einheiten bleiben in den Daten getrennt.

Die große Zeit der zusammengefassten Karte ist die **summierte Trainingszeit**, nicht die Spanne: 08:32–09:06 und 10:14–10:20 sind 40 Minuten Training, nicht 108. Die Spanne steht klein daneben. Die Gerätezahl kommt aus den **verschiedenen** `machineId` aller Teile, nicht aus der Summe der `machineCount` — wer nach der Pause an dasselbe Gerät zurückkehrt, hat kein zweites benutzt.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Verlauf/HomeZeilen.swift`
- Modify: `apps/ios-member/FitnessMemberTests/HomeZeilenTests.swift`

**Interfaces:**
- Produces:
  - `struct Trainingskarte: Identifiable { let teile: [SessionSummary]; var id: String { teile[0].id } }`
  - `HomeZeilen.trainingskarten(_ einheiten: [SessionSummary], luecke: TimeInterval = 3600) -> [Trainingskarte]` — absteigend wie die Tagesliste, innerhalb einer Karte aufsteigend
  - `HomeZeilen.grosseZeile(_ karte: Trainingskarte) -> String`, `HomeZeilen.kleineZeile(_ karte: Trainingskarte) -> String` — dieselben zwei Zeilen wie in Task 1, über alle Teile gerechnet
  - `HomeZeilen.karte(fuer sessionId: String, in einheiten: [SessionSummary]) -> Trainingskarte?` — für das Detail (Task 5)

- [ ] **Step 1: Tests schreiben.** Die Fälle, die wehtun:
  - zwei Einheiten mit 14 Minuten Lücke → eine Karte, Dauer = Summe der Teile
  - zwei Einheiten mit 68 Minuten Lücke → zwei Karten
  - genau 60 Minuten → zwei Karten (die Grenze gehört nach oben, nicht nach unten)
  - ein auto beendeter Teil → zählt für Sätze und Geräte, aber nicht für die Dauer; trägt die Karte nur auto beendete Teile, steht keine Dauer da
  - derselbe `machineId` in zwei Teilen → ein Gerät
  - eine Einheit ohne lesbares `completedAt` steht allein (sie kann keine Lücke begründen)
- [ ] **Step 2: `trainingskarten` implementieren.** Aufsteigend sortieren, falten, am Ende umdrehen. Kein `Date()` in der Ableitung — alles kommt aus den Zeitstempeln.
- [ ] **Step 3: `xcodebuild test`.**

---

## Task 3: Eine Tageszelle für beide Kalender

Die Regel — **heute = Akzentring, gewählt = weiße Füllung** — bekommt genau einen Ort. Heute steht sie zweimal verschieden im Code: `HomeSerieView.zelle` füllt die Auswahl mit `line` und ringt heute mit `accent`; `KurseWochenView.tagesboxen` füllt die Auswahl mit `accent` und markiert heute gar nicht.

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/Kalenderzelle.swift`
- Create: `apps/ios-member/FitnessMemberTests/KalenderzelleTests.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Home/HomeSerieView.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Kurse/KurseWochenView.swift`

**Interfaces:**
- Produces:
  - `enum Kalenderzelleninhalt { case zahl(Int); case hantel }`
  - `struct Kalenderzelle: View { let inhalt: …; let istGewaehlt: Bool; let istHeute: Bool; let trainiert: Bool; let gedeckt: Bool }` — 40 pt Kreis
  - `enum Kalenderfarben { static func fuellung(...) -> Color; static func vordergrund(...) -> Color }` — die prüfbare Hälfte, ohne SwiftUI-View
- Regeln, die die Tests festhalten:
  - gewählt → Füllung `text`, Vordergrund `bg` (sonst weiß auf weiß)
  - trainiert und nicht gewählt → Füllung `surfaceRaised`, Vordergrund `text`
  - sonst → keine Füllung, Vordergrund `textMuted` (heute) bzw. `textFaint`
  - heute → Ring `accent` 1,5 pt, unabhängig von allem anderen; gewählt UND heute zeigt beides

- [ ] **Step 1: Tests für `Kalenderfarben`** — die sechs Kombinationen aus (gewählt, trainiert, heute), plus: gewählt und heute ergibt weiße Füllung UND Ring.
- [ ] **Step 2: Komponente bauen**, `strokeBorder` statt `stroke` (der Ring liegt innen, sonst wandern die Spalten).
- [ ] **Step 3: `HomeSerieView.zelle` durch die Komponente ersetzen.** Der Dokukommentar am Typ („Zwei Kanaele an der Tageszelle") wandert mit — er beschreibt jetzt die Komponente.
- [ ] **Step 4: `KurseWochenView.tagesboxen` ebenso.** Der Punkt unter der Zelle (`punkt(indikator)`) bleibt, wo er ist. Die Kommentare an `tagesboxen` und an der Datei („Die einzige AkzentFLAECHE des Screens: nur der gewaehlte Tag") sind danach falsch und werden umgeschrieben: die einzige Akzentfläche ist jetzt der Umschalter.
- [ ] **Step 5: `xcodegen generate`, `xcodebuild test`.**

---

## Task 4: Der Home-Kalender zeigt Karten und Umschalter neu

Zwei Änderungen an einem View: die Tagesliste rendert **Trainingskarten** statt Einheiten (Task 2), und der Umschalter „Monatsansicht/Wochenansicht" steht **oben rechts** statt unten.

Oben rechts heißt: in der Kopfzeile neben Flamme und Fußnote, rechtsbündig. Nicht über dem Monatstitel — den gibt es in der Wochenansicht nicht, und ein Umschalter, der je nach Ansicht an einer anderen Stelle steht, ist zweimal zu suchen.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Home/HomeSerieView.swift`

- [ ] **Step 1: Umschalter in `kopfzeile` ziehen**, Fußnote bekommt `frame(maxWidth: .infinity, alignment: .leading)`, der Umschalter behält seine 44 pt Trefferfläche. Der eigene `umschalter`-Aufruf am Ende des `body` entfällt.
- [ ] **Step 2: `tagesliste` auf `HomeZeilen.trainingskarten` umstellen.** Die Karte zeigt oben `grosseZeile` in `Typography.wertSekundaer`, darunter `kleineZeile` in `fliesstext`/`textMuted`. Die Marke „AUTO BEENDET" bleibt und steht an der Karte, sobald **ein** Teil auto beendet ist.
- [ ] **Step 3: `beiAuswahl` gibt die `id` der Karte weiter** (die des ersten Teils) — die Route bleibt `HomeRoute.sessionDetail(id:)`, das Detail sucht sich die Teile selbst (Task 5).
- [ ] **Step 4: Prüfen, dass die Auswahl weiß ist** (kommt aus Task 3) und dass ein Tag mit zwei zusammengefassten Einheiten nur noch eine Karte zeigt.
- [ ] **Step 5: `xcodebuild test`.**

---

## Task 5: Das Session-Detail zeigt die Teile untereinander

Wird eine zusammengefasste Karte angetippt, gehören alle ihre Teile in das Detail — sonst führt eine Karte, die zwei Einheiten zeigt, in eine, die nur eine zeigt.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Home/SessionDetailView.swift`

- [ ] **Step 1: Die Teile über `HomeZeilen.karte(fuer:in:)` aus `verlauf.sessions` holen**, statt `first { $0.id == sessionId }`. Fällt die Einheit aus dem geladenen Fenster, bleibt der vorhandene Satz „Diese Einheit steht nicht mehr im Verlauf."
- [ ] **Step 2: Kopf über alle Teile** — Datum wie bisher, Untertitel aus `grosseZeile`/`kleineZeile` der Karte.
- [ ] **Step 3: Je Teil eine Überschrift mit seinem Zeitraum**, darunter dessen Blöcke — aber nur, wenn die Karte mehr als einen Teil hat. Bei einem Teil bleibt der Screen wie er ist.
- [ ] **Step 4: `xcodebuild test`.**

---

## Task 6: Die eigenen Anmeldungen bekommen Überschriften

Bei ausgewähltem Freitag steht heute eine Karte für den Montag darauf ohne Hinweis, dass sie einer anderen Woche gehört. Die Liste wird in vier Abschnitte geteilt: **Diese Woche / Nächste Woche / Übernächste Woche / Bald**.

`KurseMeineEinteilung` kennt die Zuordnung halb: `angemeldet`, `warteliste`, `spaeter` — geteilt nach Status, nicht nach Zeit. Das Band zeigt seit dem Umbau nur noch `alleZeilen`. Der Status steht auf der Karte (Kontur, Marke, Abmeldehinweis) und bleibt dort; die Überschrift trägt ab jetzt nur noch den Wochenabstand.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Kurse/KurseMeineEinteilung.swift`
- Modify: `apps/ios-member/FitnessMemberTests/KurseMeineEinteilungTests.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Kurse/KurseBandView.swift`

**Interfaces:**
- Produces:
  - `struct KurseAbschnitt: Identifiable { let titel: String; let zeilen: [KurseMeineZeile]; var id: String { titel } }`
  - `KurseMeineEinteilung.abschnitte(jetzt: Date, zeitzone: String) -> [KurseAbschnitt]` — leere Abschnitte fallen weg, die Reihenfolge ist zeitlich

- [ ] **Step 1: Tests schreiben.** Wochenabstand über `KurseWochenBerechnung.montag(enthaelt:zeitzone:)`, gerechnet in ganzen Wochen: 0 → „Diese Woche", 1 → „Nächste Woche", 2 → „Übernächste Woche", ≥ 3 → „Bald". Dazu: Sonntag 23:30 und Montag 00:30 liegen in verschiedenen Abschnitten (die Woche beginnt am Montag, Studio-Zeitzone); ein leerer Abschnitt erscheint nicht.
- [ ] **Step 2: `abschnitte` implementieren.** „Bald" bleibt beim heutigen 14-Tage-Ladefenster leer — die Stufe wird trotzdem gebaut, damit ein größeres Fenster sie nur noch füllt.
- [ ] **Step 3: `KurseBandView` rendert Abschnitte** mit `Typography.label` + `tracking(1.5)` + `textMuted` als Überschrift, wie „ALLE KURSE" im selben Screen. Bei genau einem Abschnitt „Diese Woche" steht keine Überschrift — die Beschriftung des Umschalters darüber sagt schon, was die Liste ist.
- [ ] **Step 4: `xcodebuild test`.**

---

## Selbstprüfung

`xcodebuild test` beweist die Ableitungen, nicht den Bildschirm. Von Hand nachzusehen, am Gerät, im Dunkeln des Studios:

- [ ] Home, Wochenansicht: heute trägt den Ring, der gewählte Tag die weiße Füllung, ein Tag der beides ist zeigt beides und bleibt lesbar.
- [ ] Home: der Umschalter steht oben rechts, trifft mit dem Daumen und schaltet Monat/Woche wie vorher.
- [ ] Home: ein Tag mit zwei Einheiten kurz hintereinander zeigt EINE Karte; die große Zahl ist die Summe der Trainingszeiten, nicht die Spanne.
- [ ] Diese Karte antippen: das Detail zeigt beide Teile untereinander, jeder mit seinem Zeitraum.
- [ ] Kurse: heute trägt den Ring, auch wenn ein anderer Tag gewählt ist; die gewählte Zelle ist weiß, nicht grün.
- [ ] Kurse, „Angemeldet": die Überschriften stimmen mit dem Kalender überein — ein Termin unter „Nächste Woche" liegt wirklich in der Woche nach der laufenden.
- [ ] VoiceOver: die Tageszelle sagt weiterhin Wochentag, Datum, „Heute." und den Kursindikator; die Karte sagt Zeit und Sätze.
- [ ] Dynamic Type auf der größten Stufe: die Kopfzeile mit Flamme, Fußnote und Umschalter bricht nicht über den Rand.

## Was dieser Schnitt NICHT tut

Löschen (Punkt 19), Startzeitpunkt (Punkt 10) und alles, was aus zwei Quellen zählt (Punkt 20), bleiben draußen — sie ändern, was eine Einheit ist, und gehören in Schnitt 4 und 6. Die zusammengefasste Karte ist hier reine Anzeige; kein Satz wird umgehängt, nichts wird gelöscht.
