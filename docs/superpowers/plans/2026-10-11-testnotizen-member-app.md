# Testnotizen 11.10. – Übungsvideos in der Member-App (iOS)

## Kontext

Testsitzung `~/Downloads/2026-10-11-1036/sitzung.md` (iPhone14,4, iOS 26.6.2, Stand `7bfcd08`), 7 Notizen.
Der Gymtavo-Katalog hat je Übung ein kurzes Loop-MP4 (162 Stück, ca. 30 KB, 5 s) und je Gerätetyp ein PNG (55 Stück).
Die App spielt Videos bisher nur in der Einweisung (`EinweisungSchritt.swift:126`). Dort bleibt die Fläche schwarz, bis man auf Play tippt (Screenshot 06).
In der Geräteliste stehen nur Platzhalter-Icons, weil `getMachinePhotos` nur `machines` abfragt und Katalogtypen leer ausgehen.
Ziel: Videos laufen als stumme Endlosschleife überall dort, wo eine Übung oder ein Gerät mit nur einer Übung angezeigt wird. Dazu kommen die Navigation (Geräteseite überspringen, X führt zur Geräteseite) und eine Zeile mit der Zahl der Übungen.

**Vorgehen:** Ablauf nach Skill `finetuning`, für iOS übertragen.
- Arbeit im eigenen Worktree `.claude/worktrees/testnotizen-1110` von `master`.
- Dieser Plan wird als `docs/superpowers/plans/2026-10-11-testnotizen-member-app.md` ins Repo übernommen.
- Je Etappe zuerst ein roter Test (Swift Testing bzw. Vitest), dann die Umsetzung, dann ein Commit (deutsch, ae/oe/ue).
- Kommentare verweisen auf „(Testnotiz 11.10., #n)“.

### Rückfragen (beantwortet)
1. **#4 Gerät mit nur einer Übung:** Die Geräteseite wird übersprungen, beim Tippen in der Liste und beim Scan. Ziel ist dasselbe wie nach einer Übungswahl (`zielNachUebungswahl`): ohne laufendes Training zuerst „Training starten“. „Zurück“ führt dann zur Liste.
2. **#2 Gerät mit mehreren Übungen:** Bis das eigene Bild kommt, wird das vorhandene Katalogfoto gezeigt. Das neue Bild ersetzt später nur die Datei.
3. **#6 X ohne Geräteseite darunter:** Die Geräteseite wird an die Stelle des Satzpfads gesetzt. Ausnahme: Hat das Gerät nur eine Übung, führt X zur Liste (Folge von #4).

## Etappe 1 – Server: signierte Videos und Katalogfotos für die Liste (#1, #2)

Grundlage für alle Listenbilder.

- **`packages/domain/src/machine-photos.ts`:**
  - `getMachinePhotos` deckt zusätzlich die Katalogtypen ab: `equipment_models` mit `is_catalog = true`. Das ist dieselbe Menge, die `getBootstrap` als `catalog` liefert (`bootstrap.ts:229-237`).
  - Geräte mit `catalog_model_id` und ohne eigenes Foto fallen auf das Foto ihres Typs zurück.
- **Neu: `packages/domain/src/exercise-videos.ts` → `getExerciseVideos(client)`:**
  - Liefert `{ videos: [{ exerciseId, url, pfad }] }` für alle Übungen, die die Liste zeigen kann: eigene Modelle und Katalogtypen.
  - Die Regel „eigenes Video vor Katalogvideo“ wird aus `uebungenZusammenfuehren` (`machine-context.ts:233`) geteilt, also exportiert und wiederverwendet.
  - Alle Videos werden in einem Aufruf signiert: `signMediaUrls(client, VIDEO_BUCKET, …)`.
  - `pfad` dient der App als Cache-Schlüssel, damit ein ersetztes Video neu geladen wird.
- **Neu: Route `apps/web/app/api/v1/me/exercise-videos/route.ts`:** wie `me/machine-photos/route.ts` aufgebaut (bearer, `no-store`).
- **Tests zuerst (Vitest, Muster `bootstrap.test.ts` mit gemocktem Client):**
  - Katalogtyp bekommt ein Foto.
  - Gerät ohne eigenes Foto erbt das Foto des Typs.
  - Eigenes Video schlägt Katalogvideo.
  - Nicht signierbarer Pfad fehlt in der Antwort.

## Etappe 2 – iOS-Baustein: Schleifenvideo mit Dateiablage

- **Neu: `DesignSystem/Components/Schleifenvideo.swift`:**
  - `UIViewRepresentable` mit `AVPlayerLayer`, `AVQueuePlayer` und `AVPlayerLooper`.
  - Stumm, ohne Bedienelemente, `videoGravity` aspectFill.
  - Spielt bei `onAppear` und pausiert bei `onDisappear`. In einer `LazyVStack` laufen dadurch nur sichtbare Zeilen.
  - Respektiert „Bewegung reduzieren“: dann nur das erste Bild, kein Abspielen.
  - Fallback ist das bisherige Bild bzw. `Uebungsbild`.
- **Neu: `Networking/VideoAblage.swift` (actor):**
  - Lädt das MP4 einmal nach `Caches/uebungsvideos/<hash(pfad)>.mp4` und liefert die lokale URL.
  - Gleichzeitige Anfragen für dieselbe Datei werden gebündelt.
  - So läuft die Schleife nach dem ersten Laden auch offline weiter. Das ist wichtig, weil die signierten URLs nach 15 Minuten ablaufen.
- **Neu: `Workout/UebungsVideos.swift`:**
  - Lädt `me/exercise-videos` beim Öffnen der Liste, nach demselben Muster wie `GeraeteFotos.laden` (`GeraeteAuswahlView.swift:99`).
  - `APIClient` bekommt den Endpunkt dazu (`APIClient.swift:56` als Vorbild).
- **Tests zuerst:** `VideoAblageTests` mit Fake-Loader.
  - Zweiter Abruf lädt nicht neu.
  - Neuer Pfad lädt neu.
  - Fehler liefert nil.
  - `UebungsVideosTests` dekodiert die Antwort.

## Etappe 3 – Geräteliste: Video oder Foto, Zahl der Übungen (#1, #2, #3)

- **Neu, reine Funktion in `Workout/GeraeteAuswahl.swift`:**
  - `vorschau(station:videos:fotos:) -> .video(exerciseId) | .foto(modellId) | .platzhalter`.
  - Genau eine Übung mit Video ergibt `.video`, sonst das Foto, sonst der Platzhalter (#2).
  - `uebungsanzahlText(_:)` ergibt „1 Übung“ bzw. „n Übungen“ (#3).
- **`GeraeteAuswahlView.vorschau(_:)` (`:351-378`):** setzt `Schleifenvideo` ein. Unter dem Namen kommt die zweite Zeile mit der Zahl der Übungen, in `textMuted`.
- **„Bereits trainiert“-Zeilen (`TrainingRootView.blockZeile`, `:464-515`):** `Uebungsbild(kante: 48)` wird durch `Schleifenvideo` für `block.exerciseId` ersetzt (#1).
- **Tests zuerst:** Fälle in `GeraeteAuswahlTests`.
  - 1 Übung mit Video
  - 1 Übung ohne Video, aber mit Foto
  - 3 Übungen
  - nichts vorhanden
  - Singular und Plural

## Etappe 4 – Navigation: Geräteseite überspringen, X zur Geräteseite (#4, #6)

- **`GeraetEinstiegRechner.einstieg` (`GeraetEinstieg.swift:32`):**
  - Bekommt `uebungsanzahl`. Bei `== 1` ergibt sich `.direktZumSatz` mit dieser Übung.
  - Die bisherige Regel (Besuche ≥ 2 und 1 genutzte Übung) bleibt.
- **`TrainingRootView`:**
  - `oeffneAusListe` (`:702`) nutzt dieselbe Entscheidung wie `navigiere(zu:)` (`:756`). Daraus wird eine gemeinsame Funktion, damit Liste und Scan nicht auseinanderlaufen.
- **Neu, reine Funktion `Navigation/Pfadregel.swift`:**
  - `nachEinweisungAbbruch(pfad:uebungsanzahl:) -> [GeraetRoute]`.
  - Liegt `.erkannt` unter dem obersten Eintrag, wird `removeLast` ausgeführt.
  - Sonst wird bei mehr als einer Übung der oberste Eintrag durch `.erkannt(station, token)` ersetzt.
  - Sonst wird der Pfad geleert.
- **`GeraetScreen` (`GeraetView.swift:480-509`):**
  - Bekommt einen eigenen Parameter `beiErstkontaktAbbruch`.
  - `beiZurueckZumTraining` bleibt für „Gerät abschließen“ (`:436, :458`) unverändert.
- **Tests zuerst:**
  - `GeraetEinstiegTests`: eine Übung beim ersten Besuch ergibt direkt.
  - Neu `PfadregelTests`: die drei Fälle oben, außerdem `[.erkannt, .geraet]` und `[.geraet]` mit 1 bzw. 3 Übungen.

## Etappe 5 – Video auf Geräteseite und Satzseite (#5, #7)

- **`GeraetErkanntView` Übungszeilen (`:123-142`):** `Uebungsbild()` wird durch `Schleifenvideo` mit dem Video der Übung ersetzt. Quelle ist der `UebungsVideoVorrat`; ein Ersatz über `uebung.videoURL` aus dem Kontext war nicht nötig, weil die Liste als Wurzel des Tabs den Vorrat immer zuerst lädt und die Dateiablage offline weiterhilft.
- **`GeraetView.geraetUndUebung` (`:252-280`):** `HStack` mit einem 56-pt-Schleifenvideo links von Titel und Untertitel. Ohne Video entfällt die Kachel, damit kein leerer Kasten entsteht.
- **Ohne Unit-Test:** reine Darstellung. Die Auswahl der Quelle steckt in Funktionen, die schon in Etappe 2/3 getestet sind. Sichtprüfung im Simulator.

### Nebenbefund (nicht verlangt, nur gemeldet)
Das Einweisungsvideo bleibt schwarz, bis man Play tippt. Außerdem wird `AVPlayer` bei jedem Neuzeichnen neu erzeugt (`EinweisungSchritt.swift:127`).
Empfehlung: dort ebenfalls `Schleifenvideo` in groß. Umsetzung nur nach Rückfrage bei der Abschlussmeldung.

## Gestaltungsentscheidungen (selbst getroffen)
- Videos ohne Ton, ohne Bedienelemente, Ecken wie die bisherige Vorschau (56 pt, gleicher Radius).
- Die Übungszahl steht als zweite Zeile in `textMuted`, Wortlaut „1 Übung“ / „4 Übungen“.
- „Bewegung reduzieren“ zeigt ein Standbild.

## Geprüft

Umgesetzt in 6 Commits (`e51b5e7` bis `fecc83d`), je Etappe zuerst ein roter Test.

- **Domain/Web:** `pnpm test` grün (domain 312, web 303). `pnpm typecheck` grün.
- **Integration:** `pnpm test:integration api-exercise-videos api-machine-photos`: 13/13 grün gegen das lokale Supabase. Die ganze Integrationssuite lief nicht.
- **iOS:** `xcodebuild test` mit dem ganzen Testsatz: 1033 Tests in 107 Suites grün, auch nach dem Fix aus dem Sichtcheck.
- **Prod (nur gelesen):** 55 Gymtavo-Typen mit Foto, 162 Katalogvideos in `instruction_assets`, 162 Objekte im Bucket. Die Daten sind also da. Der neue Endpunkt `me/exercise-videos` kommt erst mit dem Deploy der Web-App. Bis dahin zeigt die App Fotos und Platzhalter, ohne Fehler.
- **Sichtcheck im Simulator** (Wegwerf-UI-Test gegen das lokale Backend, Freies Training):
  - #1/#2/#3: In der Liste läuft das Video der Schlittenpresse. Zwei Aufnahmen im Abstand von 0,7 s unterscheiden sich in der Kachel. Darunter steht „1 Übung“.
  - #5: Auf der Geräteseite der Ab-/Adduktorenmaschine haben beide Übungszeilen ihr Video.
  - #6: Das Kreuz in der Einweisung führt zurück auf die Geräteseite.
  - #4: Die Schlittenpresse (1 Übung) springt aus der Liste direkt in die Einweisung.
  - #7: Auf der Satzseite steht das Video links vom Namen. Gefunden und behoben: Ohne Platzhalter verschwand die Kachel ganz (`fecc83d`). Der Gerätename darf jetzt auf 0,6 schrumpfen.
- **Abweichung vom Plan:** Aus der Liste gilt die Besuchsregel (ab 2 Besuchen direkt) weiterhin nicht, nur die Regel „eine Übung“. Liste und Scan teilen sich dafür eine Funktion (`oeffne(_:token:besuche:)`).
- **Am Gerät noch ansehen:**
  - Scrollen durch die ganze Liste mit vielen Schleifen (Ruckeln, Akku)
  - Musik läuft beim Öffnen der Liste weiter (die Kacheln spielen nur die Bildspur)
  - Verhalten ohne Empfang nach einem Neustart
  - ob das Einweisungsvideo am iPhone weiter schwarz startet (Nebenbefund, im Simulator lief es sofort)
