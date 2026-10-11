# Testnotiz 11.10. #15 – Kurse aus allen Studios mit Studiofilter

## Kontext

Testsitzung `~/Downloads/2026-10-11-1210/sitzung.md`, Notiz #15 (KurseWochenView):

> Wenn ich bei mehreren Studios bin, bitte die Kurse von allen Studios anzeigen, oben ein Filter, mit dem ich Studios an- und abwählen kann. Hat jemand nur ein Studio plus Freies Training, den Filter weglassen. Freies Training zählt hier nicht als Studio.

Aus Teil 1 dieser Sitzung (PR #51) ausgelagert. Stand: `a00f62c`.

**Heute:** Der Kurse-Tab kennt genau ein Studio, das aktive.
- `KurseOrtZustand.fuer(ort:)` (`Kurse/KurseAnsicht.swift:90`) zeigt im Freien Training immer „Tritt einem Studio bei“, auch für Mitglieder mit Studios (Screenshot 15).
- `KurseStore.laden(studioId:)` lädt ein Studio und verwirft beim Wechsel Plan und eigene Buchungen.
- `GespeicherteBuchungen` hängt an einer `studioId`, ebenso Frist und Zeitzone.
- Home zeigt eigene Kurse nur für das aktive Studio (`HomeRootView.swift:70-75`).

**Vorgehen:** Skill `finetuning`, für iOS übertragen.
- Branch `claude/kurse-alle-studios` von `master`, Worktree `.claude/worktrees/testnotizen-1110b`.
- Je Etappe zuerst ein roter Test (Swift Testing), dann die Umsetzung und ein Commit.

### Rückfragen (beantwortet, 11.10.: „bei allen Empfehlungen mitgehen“)
- **F:** Kurse aus allen Studios, auch wenn gerade Freies Training aktiv ist.
- Filter-Chips gibt es erst ab 2 Studios. Am Anfang sind alle an, die Auswahl wird gemerkt.
- Buchen geht in jedem Studio.
- „Beitreten“ erscheint nur ohne Mitgliedschaft.
- Am Server ändert sich nichts.

## Etappe 1 – Plan zusammenführen und filtern (reine Funktionen)

- **Neu: `Kurse/KursePlan.swift`:**
  - `zusammenfuehren(_ teile: [(studioId: String, woche: CourseWeek)]) -> CourseWeek?`:
    - Die Termine aller Studios werden nach `startsAt` sortiert, und jeder Termin trägt seine `studioId`.
    - `timezone` und `cancellationDeadlineHours` des Ergebnisses kommen vom ersten Teil. Das ist das aktive Studio, sonst das erste der Liste. Sie gelten nur für Wochenstreifen und Ladefenster.
    - Für Frist und Uhrzeit eines Termins gilt immer sein eigenes Studio, siehe Etappe 2.
  - `KurseFilter.sichtbar(_:ausgeblendet:)` blendet Termine abgewählter Studios aus. `KurseFilter.zeigtAuswahl(studios:)` ist wahr ab 2 Studios.
- **`CourseWeekSession`:** bekommt `var studioId: String?`. Der Server liefert das Feld nicht; der Store setzt es beim Zusammenführen.
- **`KurseOrtZustand.fuer(studios:)`:** `.plan` ab einem Studio, sonst `.beitreten`. Der aktive Ort spielt keine Rolle mehr.
- **Tests zuerst:**
  - Neu `KursePlanTests`: zwei Studios werden sortiert zusammengeführt und tragen ihr Studio; die Frist kommt vom ersten Studio; ohne Teile gibt es kein Ergebnis.
  - Filter: ausgeblendet und leer; Chips bei einem und bei zwei Studios.
  - `KurseAnsichtTests` (bisher an den Ort gebunden) wird umgeschrieben.

## Etappe 2 – Store lädt alle Studios, Ablage je Termin

- **`KurseStore.laden(studioIds:von:bis:)`:**
  - Lädt die Studios parallel (TaskGroup) und führt sie zusammen.
  - Schlägt ein Studio fehl, gilt das wie bisher als Fehlschlag des Ladens. Der vorige Plan bleibt stehen, der Screen datiert ihn (`KurseHerkunft`). Teilpläne zeigt er nicht: Ein Plan, dem ein Studio fehlt, sähe vollständig aus.
  - Plan und eigene Buchungen werden verworfen, wenn sich die **Menge** der Studios ändert (Beitritt, Austritt), nicht mehr beim Wechsel des aktiven Orts.
  - `plaene: [String: CourseWeek]` behält die Teilpläne. `frist(fuer:)` und `zeitzone(fuer:)` liefern Frist und Zeitzone des Studios eines Termins.
- **`GespeicherteBuchungen`:**
  - `studioId` wird zu `studioIds: [String]`. Eine Datei im alten Format scheitert am Decoder und gilt als leerer Cache; das Muster gibt es schon.
  - `GespeicherterTermin` bekommt `studioId`, `cancellationDeadlineHours` und `timezone` je Termin. `frist(fuer:)` und `zeitzone(fuer:)` fallen auf die Werte oben zurück.
- **Buchen und Stornieren:** Danach wird mit der letzten Studioliste neu geladen.
- **Tests zuerst (`KurseStoreTests`):**
  - Zwei Studios landen in einem Plan.
  - Eine andere Studiomenge verwirft Plan und eigene Buchungen; dieselbe Menge in anderer Reihenfolge verwirft nichts.
  - Eigene Termine tragen ihr Studio und ihre Frist.
  - Ein Fehlschlag eines Studios behält den vorigen Plan.
  - Eine alte Datei mit `studioId` gilt als leer.
- Die bestehenden Tests zum Studiowechsel (`:232-330`) werden auf die Studiomenge umgestellt.

## Etappe 3 – Kurse-Tab: alle Studios, Filter-Chips

- **`KurseWochenView`:**
  - Gezeigt wird nach `KurseOrtZustand.fuer(studios:)`, geladen werden alle `bootstrap.studios`, das aktive zuerst. Der `task` hängt an der Studioliste statt an `activeStudioId`.
  - Ab 2 Studios steht unter dem Kopf eine Chip-Zeile mit einem Chip je Studio. Ein Tipp schaltet das Studio ein oder aus; das letzte sichtbare lässt sich nicht abwählen.
  - Die Auswahl liegt in `@AppStorage("kurseAusgeblendeteStudios")` als ausgeblendete IDs. Ein neues Studio ist dadurch automatisch an.
  - Tagesliste, Tagesindikator und „Angemeldet“ zeigen nur sichtbare Studios.
  - Im Kopf steht bei einem Studio sein Name, sonst „N STUDIOS“.
  - In der Terminzeile steht der Studioname, wenn mehr als ein Studio sichtbar ist. So sieht man, wohin man fährt.
- **`KursDetailView`:** Frist, Zeitzone und Studioname kommen vom Studio des Termins statt vom aktiven (`:373-390`, `:604`).
- **`KurseBandView`:** Frist und Zeitzone je Termin über `eigene.frist(fuer:)` und `eigene.zeitzone(fuer:)`.
- **Home:**
  - `eigeneKurse` zeigt die Buchungen aller Studios, auch im Freien Training.
  - `kurseLaden` lädt alle Studios. Sonst beschnitte Home der Kurse-Seite den Cache: Es gibt ein Fenster und eine Menge für beide.
- **Ohne eigenen Unit-Test:** Die Darstellung wird im Sichtcheck geprüft. Die Regeln dahinter sind in Etappe 1 und 2 getestet.

## Etappe 4 – Sichtcheck und Abschluss

- **Sichtcheck:** Lokales Mitglied in zwei Studios mit je einem Kurs und aktivem Freiem Training.
  - Beide Kurse sind zu sehen, darüber die Chips.
  - Abwählen blendet aus.
  - Buchen im nicht aktiven Studio funktioniert.
  - Ein Mitglied mit nur einem Studio sieht keine Chips.
  - Ohne Studio erscheint „Beitreten“.
- **Testsatz:** `pnpm typecheck`, `pnpm test`, `xcodebuild test`. Der Server bleibt unverändert, Integrationstests nur zur Kontrolle.

## Gestaltungsentscheidungen (selbst getroffen)
- Die Chips nutzen den vorhandenen `Chip`-Baustein, horizontal scrollbar. „Alle“ als eigener Chip entfällt: Bei 2–3 Studios ist ein Tipp je Studio kürzer als ein Umschalter mehr.
- Der Studioname in der Terminzeile steht in `textMuted` hinter dem Raum.

## Geprüft

Umgesetzt in zwei Commits (`d17c200`, `0e2985b`).
- Etappe 1 und 2 liefen zuerst rot: `KursePlanTests` fehlte, die Store-Tests riefen `laden(studioIds:)` auf.
- Etappe 3 lief in denselben Commit, weil die Ansichten ohne sie nicht kompilierten (`KurseOrtZustand.fuer(ort:)` entfiel).
- Den Test zu `KurseStudios.reihenfolge` schrieb ich erst nach der Funktion.

- **Tests:**
  - `pnpm typecheck` und `pnpm test` grün (domain 312, web 303). Am Server änderte sich nichts.
  - `xcodebuild test`: 1060 Tests in 108 Suites grün.
- **Sichtcheck im Simulator:**
  - Aufbau: Lokales Mitglied mit aktivem Freiem Training, in zwei Studios „Sichtcheck Nord“ (Frist 2 h) und „Sichtcheck Süd“ (Frist 24 h), je ein Kurs am Montag, 12.10.
  - Der Kurse-Tab zeigt im Freien Training beide Kurse. Darüber stehen die Chips, im Kopf „2 STUDIOS“, in der Zeile der Studioname.
  - Wird Süd abgewählt, steht nur noch Rücken Fit da und im Kopf „SICHTCHECK NORD“. Nord lässt sich danach nicht abwählen, es ist das letzte sichtbare Studio.
  - Spinning (Süd) lässt sich buchen. Die Detailseite nennt „Abmeldefrist verstrichen“, also die 24-h-Frist von Süd und nicht die 2 h des ersten Studios.
  - Gefunden und behoben (`0e2985b`): Der Chip-Text stieß an die Kontur.
- **Nicht im Bild geprüft:**
  - Ein Mitglied mit genau einem Studio (keine Chips) und eines ohne Studio („Beitreten“). Beides ist nur über `KurseFilter.zeigtAuswahl` und `KurseOrtZustand.fuer(studios:)` getestet.
  - Die Kursleiste auf Home mit Buchungen aus zwei Studios.
- **Lokale Daten:** Die beiden Sichtcheck-Studios liegen in der geteilten lokalen DB. Sie stören keine Tests, die Namen sind eindeutig.
