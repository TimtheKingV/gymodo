# Testnotizen 11.10. (Teil 2) – Übungsstart als Drawer, Home-Fortschritt, Kurse aus allen Studios

## Kontext

Testsitzung `~/Downloads/2026-10-11-1210/sitzung.md` (iPhone14,4, iOS 26.6.2, Stand `dd40757`), 16 Notizen.
Schwerpunkte:
- ein neuer Einstieg in eine Übung: Einweisung und Startwerte als Drawer, 5-s-Countdown auf der Satzseite
- die Fortschrittszeilen auf Home
- leisere Hinweise im Training-Tab
- Kurse aus allen Studios

**Vorgehen:** Ablauf nach Skill `finetuning`, für iOS übertragen, wie beim Teil 1 (`2026-10-11-testnotizen-member-app.md`).
- Worktree `.claude/worktrees/testnotizen-1110b`, Branch `claude/testnotizen-1110-drawer` von `master`.
- Je Etappe zuerst ein roter Test (Swift Testing bzw. Vitest), dann die Umsetzung, dann ein Commit (deutsch, ae/oe/ue).
- Kommentare verweisen auf „(Testnotiz 11.10., #n)“. Gemeint ist die Sitzung 12:10. Die Nummern aus Teil 1 tragen dort den Zusatz „Teil 1“, wo es zu Verwechslungen käme.
- Etappe 8 (Kurse, #15) kommt als eigener PR nach diesem.

### Rückfragen (beantwortet: „bei allen Empfehlungen mitgehen“)

- **A, #1:** Ohne Studio nimmt der Server die Zeitzone des Gymtavo-Katalogstudios. Serie und Wochenzahl erscheinen damit auch im Freien Training.
- **B, #4:**
  - Die Veränderung bleibt „seit Start“ (erster gegen aktuellen Trainingstag).
  - Bewusste Ausnahme vom Designsystem §2/§13 nur für diese Zeile, im Spec vermerkt. Steigend `accent`, fallend `warn`, gleich `textFaint`. Gefärbt werden Linie, Pfeil und Zahl, nie eine Fläche.
- **C, #6/#10/#11:**
  - C1: Die Einstellung bleibt ein Schritt im Einweisungs-Drawer. „Übung starten“ startet ein noch nicht laufendes Training gleich mit; der Screen „Training starten“ entfällt.
  - C2: Der Countdown läuft nur beim Start der Übung. Ein Tipp auf den Ring überspringt ihn.
  - C3: Der Start-Drawer ersetzt den Rückblick-Sheet.
  - C4: Bei neuen Übungen gelten die heutigen Startwerte der Satzseite.
- **D, #12:** Ein Drawer nur mit dem Gewichtsrad. Der Wert gilt ab dem nächsten Satz.
- **E, #8/#9:**
  - Der Hinweis „automatisch beendet“ entfällt ganz.
  - „Verworfen“ wird ein Toast von etwa 3 s.
  - Der Vier-Stunden-Satz in der Trainingsuhr fällt weg. Die Regel selbst bleibt.
- **F, #15:**
  - Kurse aus allen Studios, auch im Freien Training.
  - Chips ab 2 Studios, die Auswahl wird gemerkt.
  - Buchen geht überall.
  - „Beitreten“ erscheint nur noch ohne Mitgliedschaft.
  - Eigener PR.
- **G, #5:** Noch offen, ob am Gerät Icons oder Standbilder zu sehen waren. Die Screenshots erfassen Videoebenen nicht (`Testnotiz/Bildschirmfoto.swift:14`, `drawHierarchy`). Prod-Daten und Endpunkt sind in Ordnung (162 Videos, H.264 High; `me/exercise-videos` antwortet). Prüfung im Simulator gegen die Prod-Daten, danach Rückmeldung an Tim.
- **H, #14:** Fotos kommen auf die Platte wie die Videos. Das Einweisungsvideo läuft aus der Ablage.

## Etappe 1 – Serie im Freien Training (#1)

- **Ursache:** `getSessions` (`packages/domain/src/sessions.ts:278`) holt die Zeitzone nur über `studioId`. `zeitzoneDesStudios` (`:431`) liefert ohne Studio `null`, damit werden `streak` und `thisWeekCount` zu `null`, und `HomeRootView.swift:88` blendet die Serie aus. Die Serie zählt schon alle Einheiten des Mitglieds, es fehlt nur die Zeitzone.
- **Änderung, Domain:** Ohne `studioId` nimmt `getSessions` die Zeitzone des Katalogstudios (`studios.is_catalog = true`, per RLS lesbar).
- **Änderung, App:** `HomeRootView.zeitzone` (`:64`) fällt im Freien Training nicht mehr auf UTC zurück, sondern auf die Katalogzeitzone aus dem Bootstrap. Liefert der Bootstrap keine, gilt `TimeZone.current`.
- **Test zuerst:** Neuer Fall in `packages/domain/src/sessions.test.ts`: Ohne `studioId` ist `streak` nicht `null`. Dazu ein Integrationstest in `tests/integration` für `me/sessions` ohne `?studio`.

## Etappe 2 – Fortschrittszeile auf Home: Video, ohne Nummer, Trend (#2, #3, #4)

- **#2, Video links:**
  - `UebungsVideoVorrat` lebt bisher nur im Training-Tab (`TrainingRootView.swift:38`). Er zieht in die App-Umgebung (`FitnessMemberApp.swift:44-50`), und Home lädt ihn ebenfalls in `neuLaden()`.
  - Die Zeile bekommt `UebungsVideoKachel(exerciseId: uebung.id, kante: 48) { Uebungsbild() }`. `ExerciseProgress.id` ist die `exercises.id`, also derselbe Schlüssel wie im Vorrat.
- **#3:** `machineLabel` fällt aus dem Zeilentitel (`HomeRootView.swift:318`). Es bleibt nur der Übungsname.
- **#4:** Rechts in der Zeile wird die Last nach oben gestellt. Darunter steht ein Mini-Graph aus `points`, etwa 64×20 pt, Swift Charts wie `HomeZieleView.miniKurve`. Darunter wiederum steht `↗ +5,0 kg` bzw. `↘ −25,0 kg` bzw. `±0 kg`, und Linie und Text tragen die Trendfarbe.
- **Reine Funktionen in `Verlauf/HomeZeilen.swift`:**
  - `trend(_ delta: Double) -> Trend` (`.hoch`, `.runter`, `.gleich`)
  - `trendText(delta:einheit:)` mit Einheit
  - `sparkPunkte(_:max:)` mit den letzten n Punkten. Bei 0–1 Punkten gibt es keinen Graph.
- **Spec:** `docs/superpowers/specs/2026-08-30-designsystem.md` §13 bekommt den Absatz zur Ausnahme „Trendzeile Übungsfortschritt“.
- **Test zuerst:** Fälle in `HomeZeilenTests`: hoch, runter, gleich, Rundung bei −0,0, ein Punkt ohne Graph, Kappung auf n Punkte.

## Etappe 3 – Videos und Fotos aus der Ablage (#5, #7, #14, #16)

- **#16:** `UebungWechselnSheet.swift:63` bekommt die `UebungsVideoKachel` wie `GeraetErkanntView.swift:127`. Ein Sheet erbt die Umgebung; ab Etappe 2 hängt der Vorrat ohnehin an der App.
- **#7:**
  - `EinweisungSchritt.swift:126` hat heute `VideoPlayer(player: AVPlayer(url:))`: das Video streamt, startet erst auf Tipp und baut den Spieler bei jedem Rendern neu.
  - Neu ist ein großes `UebungsVideoKachel` mit Breite und Höhe (Erweiterung um `hoehe:`), stumm in Schleife aus der Ablage.
  - Fehlt die Quelle im Vorrat, dient `instructionVideoUrl` aus dem Kontext als Quelle. Pfad ist dabei der URL-Pfad ohne Token.
  - Eine reine Funktion `UebungsVideos.quelle(vorrat:kontextURL:)` entscheidet das.
- **#14, Fotos:**
  - `VorschauLader` (`Vorschaubild.swift:56`) hält Bilder nur im Speicher.
  - Das Gerätefoto oben in `GeraetErkanntView` (`:55-70`) und in der Einweisung kommt per `AsyncImage` jedes Mal neu.
  - Neu: Die Ablage wird verallgemeinert. `VideoAblage` heißt künftig `Medienablage(ordner:endung:)`, mit einer Instanz für Videos und einer für Fotos. Der Schlüssel ist der URL-Pfad ohne Signatur.
  - `VorschauLader` liest zuerst von der Platte.
  - Die beiden `AsyncImage` werden zu `Vorschaubild`.
- **#5:** Ein Sichtcheck im Simulator gegen Prod-Daten (nur lesend) prüft, ob die Zeilen auf „Gerät erkannt“ Videos zeigen. Bestätigt sich ein Fehler, folgt eine eigene Unteretappe mit Test.
- **Test zuerst:**
  - `UebungsVideosTests`: Quelle aus Vorrat vor Kontext, Kontext-Fallback mit stabilem Pfad.
  - `VideoAblageTests` wird zu `MedienablageTests`, mit einem Fall für die zweite Instanz und eigene Endung.
  - `VorschaubildTests`: Platte vor Netz.

## Etappe 4 – Hinweise im Training-Tab (#8, #9)

- **Ursache:** `TabHinweis` (`TrainingRootView.swift:885-900`) steht als `InlineBanner` im Fuß und bleibt stehen, bis die Wurzel verschwindet.
- **Änderung:**
  - Der Fall `.ausgelaufen` entfällt. `ausgelaufeneQuittieren()` bleibt, aber still.
  - `.verworfen` wird ein neuer Baustein `DesignSystem/Components/Toast.swift`:
    - surfaceRaised, Text in `text`
    - blendet nach 3 s aus und lässt sich per Tipp schließen
    - wird von VoiceOver angesagt (`AccessibilityNotification.Announcement`)
    - bei „Bewegung reduzieren“ ohne Slide
  - In `Trainingsuhr.swift:112` fällt der Satz weg.
- **Test zuerst:**
  - Die Entscheidung kommt in eine reine Funktion `TrainingTabHinweis.nachBeenden(zusammenfassung:)` und `nachAblauf(...)`. Letztere liefert immer nil.
  - `Toast.anzeigedauer` wird mit Test festgehalten.
  - `WorkoutSessionStoreTests` bleiben unverändert grün.

## Etappe 5 – Übungsstart als Drawer (#6, #10, #11)

Der neue Ablauf beim Wählen einer Übung (Liste, Geräteseite, Scan, Direktweg):

```
Übung gewählt ──► Sheet „Übungsstart“ über dem aktuellen Screen
                    ├─ Erstkontakt:  Einweisung ─► (Einstellung) ─► Startwerte
                    └─ sonst:        Startwerte (letzter Satz vorbelegt)
                  „Übung starten“ ─► ggf. Training starten ─► push .geraet(…, start:)
                  Satzseite: 5-s-Countdown im Ring ─► „Los!“ ─► Eingabe
```

- **Navigation:**
  - `zielNachUebungswahl` (`TrainingRootView.swift:800`) und `TrainingStart.ziel` liefern keine Route mehr. Stattdessen setzen sie `@State uebungsstart: Uebungsstart?` an der Wurzel. Das Sheet hängt am `NavigationStack` und liegt damit über Liste oder Geräteseite.
  - Ein Schließen lässt den Screen darunter stehen. Damit erledigt sich `Pfadregel.nachEinweisungAbbruch` (Teil 1, #6), es fällt weg.
  - Nicht mehr nötig sind außerdem die Route `.start`, `TrainingStartView`, der `ErstkontaktFlow`-Cover in `GeraetScreen` (`GeraetView.swift:498-528`) und `RueckblickSheet`.
  - Der Cover bleibt nur für „Einstellung ändern“ (`kalibrierungOffen`).
- **Neu, reine Funktionen in `Workout/Uebungsstart.swift`:**
  - `schritte(erstkontakt:hatEinstellparameter:) -> [.einweisung, .einstellung, .startwerte]`. Das ersetzt `erstkontaktSchritte`; „Training starten“ ist kein Schritt mehr.
  - `Startwerte(belastung:umfang:nebenbelastung:)`: vorbelegt aus dem letzten Satz, sonst aus den heutigen Startwerten des `GeraetModel`.
- **Sheet `Screens/Geraet/UebungsstartSheet.swift`:**
  - Es hält ein eigenes `GeraetModel` aus `modell(station:exerciseId:token:)` und lädt den Kontext für Video und Einstellparameter.
  - Seine Schritte sind `EinweisungSchritt` (ohne Kreuz, Sheet mit Griff), `KalibrierungSchritt` und der neue Startwerte-Schritt.
  - Der Startwerte-Schritt zeigt „ZULETZT · …“ und den Vorschlag (aus `RueckblickSheet`), dazu die `WertZeile`-Räder und unten „Übung starten“ in `PrimaryButton`.
  - Detents: `.large` für die Einweisung, gemessen für die Startwerte.
- **Route:** `.geraet(station:exerciseId:token:start: Startwerte?)`. Die Blockliste und „Weitere Übung“ nutzen weiter `start: nil`.
- **`GeraetModel`:**
  - Neue Phase `.bereit(Resttimer(dauer: 5))`, wenn `start` gesetzt ist.
  - Danach `.eingabe`, mit einer kurzen Einblendung „Los!“ (0,8 s, ohne Bewegung bei „Bewegung reduzieren“).
  - Ein Tipp auf den Ring setzt sofort `.eingabe`.
  - Die Startwerte überschreiben die Vorbelegung und gelten als „vom Nutzer“ (`belastungVomNutzer`).
- **Ring:** `PausenRad.rad` (`PausenRad.swift:86-133`) wird ein eigener `CountdownRing`. Pause und Countdown nutzen beide ihn.
- **Erstkontakt erledigt:** Bisher galt er im `GeraetModel` der Satzseite als erledigt (`erledigt`). Künftig setzt ihn das Sheet. Die Satzseite fragt danach nicht mehr.
- **Tests zuerst:**
  - Neu `UebungsstartTests`: Schritte für Erstkontakt mit und ohne Einstellparameter, für eine bekannte Übung, Startwerte aus dem letzten Satz und ohne letzten Satz.
  - `GeraetModelTests`: Ein Start mit Startwerten beginnt in `.bereit`; nach Ablauf bzw. Überspringen folgt `.eingabe`; die Startwerte stehen in den Rädern; ohne Startwerte beginnt der Start in `.eingabe`.
  - Wegfallende Tests werden entfernt bzw. umgeschrieben: `TrainingStartTests` (Regel „Training mitstarten“ in `UebungsstartTests`), `PfadregelTests`, `GeraetEinstiegTests` (erstkontaktSchritte, positionNachUeberspringen).

## Etappe 6 – Satzseite: Gewicht ändern, Titel öffnet die Einweisung (#12, #13)

- **#12:**
  - `PausenRad` bekommt in die Knopfzeile (`:66-70`) einen dritten Knopf „Gewicht“ (secondary).
  - Der öffnet `GewichtAendernSheet` mit einem `RastRad` über `modell.belastungsWerte` und dem Knopf „Übernehmen“. Das ruft `modell.belastungGewaehlt(_:)` auf.
  - Die Pause läuft dabei weiter.
  - Bei drei Knöpfen wird die Beschriftung kürzer: „+30 s“, „Gewicht“, „Abschließen“. Die volle Bedeutung trägt das Accessibility-Label.
- **#13:**
  - `GeraetView.namen` (`:263-293`) wird ein Button mit dem Hinweis „Zeigt die Einweisung“.
  - Er öffnet ein Sheet mit `EinweisungSchritt` im Modus `nurAnsehen`: ohne Weiter-Kette, nur „Schließen“.
- **Test zuerst:**
  - `GeraetModelTests`: Ein in der Pause gewähltes Gewicht steht nach `pauseBeenden()` im Rad und landet im nächsten Satz.
  - Der Rest ist Darstellung: Sichtcheck.

## Etappe 7 – E2E/Sichtcheck und Abschluss

- **Sichtcheck:** Wegwerf-UI-Test gegen das lokale Backend (siehe Memory „Simulator-Sichtcheck“). Zu prüfen:
  - Home zeigt im Freien Training Serie, Videos und Trend.
  - Neue Übung: Einweisung, dann Startwerte, dann Countdown, dann „Los!“, dann Räder.
  - Bekannte Übung: Startwerte vorbelegt.
  - Pause: Gewicht ändern.
  - Tipp auf den Titel: Einweisung.
  - Die Videos in „Weitere Übung“ laufen.
  - Toast nach „Training beenden“ ohne Satz.
- **Vollständiger Testsatz:** `pnpm typecheck`, `pnpm test`, `pnpm test:integration` (lokales Supabase), `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- Der Abschnitt **Geprüft** wird ausgefüllt.

## Etappe 8 – Kurse aus allen Studios (#15, eigener PR)

- **App, ohne Serveränderung:** `KurseStore` lädt `courseWeek` je Studio aus `bootstrap.studios` parallel und führt die Termine zusammen. Jeder Termin trägt dann `studioId`, Zeitzone und Storno-Frist seines Studios.
- **Ablage:** `GespeicherteBuchungen` bekommt `studioId` je Termin. Eine alte Datei gilt als leerer Cache, so wie es `KurseStoreTests.eineDateiOhneStudiokennungGiltAlsLeererCache` schon tut.
- **`KurseOrtZustand.fuer`:** Die Entscheidung hängt an der Zahl der Mitgliedschaften, nicht am aktiven Ort. „Beitreten“ erscheint nur bei 0 Studios.
- **Filter:** Chips (`Chip.swift`) gibt es erst ab 2 Studios. Die Auswahl liegt in UserDefaults, neue Studios sind an.
- **Home:** `eigeneKurse` (`HomeRootView.swift:66-75`) zeigt Buchungen aller Studios.
- **Tests zuerst:** `KurseAnsichtTests` (Zustand nach Mitgliedschaften), `KurseStoreTests` (Zusammenführen, Filter, Datei mit Studiokennung je Termin), `HomeKurseTests`.

## Gestaltungsentscheidungen (selbst getroffen)

- Fortschrittszeile:
  - Videokachel 48 pt wie in der Blockliste.
  - Der Graph ohne Achsen, 2 pt Linie, letzter Punkt markiert.
- Countdown: die Ringfarbe `accent` wie die Pause. Darunter steht „Gleich geht’s los“, danach kommt „Los!“ groß in der Ringmitte.
- Toast unten über den Scan-Knöpfen, an der Stelle des bisherigen Banners.
- Knopfzeile in der Pause mit drei gleich breiten Knöpfen und kurzer Beschriftung.

## Geprüft

(nach der Umsetzung ausfüllen)
