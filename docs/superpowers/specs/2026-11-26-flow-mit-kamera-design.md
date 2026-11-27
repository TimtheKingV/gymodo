# Flow mit Kamera – Entwurf

**Stand:** 26. November 2026 · **Status:** Von Tim am 26.11.2026 freigegeben; „Mein Vorschlag“-Punkte gelten, bleiben aber gekennzeichnet
**Zweig:** `claude/flow-kamera` (Arbeitsbereich `.claude/worktrees/flow-kamera`), abgezweigt von `claude/kamera-ablauf`
**Bezug:** `2026-11-26-follow-along-flows-design.md` (Flows, auf master, PR #118), `2026-11-24-kamera-tempo-ablauf-design.md` (Kamera-Spec), `docs/superpowers/plans/2026-11-25-kamera-ablauf-e3-e4.md` (Kamera-Oberfläche, nur auf `claude/kamera-ablauf`)
**Wer was entschieden hat:** „Tim“ heißt im Gespräch am 26.11. gesagt. „Mein Vorschlag“ heißt von Claude gesetzt und von Tim noch nicht bestätigt.

## 1. Absicht und Warum

Tim will den Flow „HIIT 20 Minuten“ einmal als echtes geführtes Training in der App erleben: In der Pause sieht man die nächste Übung als Video, in der Arbeitsphase sieht man sich selbst im Kamerabild und die App zählt die Wiederholungen. Der Flow dient als Beispiel, um zu spüren, wie sich dieser Ablauf anfühlt. Daraus soll später der Standardweg für weitere Flows werden. Deshalb wird nebenbei mitgeschrieben, wie aus einem Video-Link ein fertiger Flow entsteht.

**Erfolg heißt:** Tim startet am iPhone den Flow, stellt das Handy einmal auf, trainiert die 20 Schritte durch, sieht in jeder Pause das Video der nächsten Übung mit der Restzeit oben rechts, wird bei den zählbaren Übungen gezählt und sieht am Ende, was er geschafft hat. Die Anleitung liegt im Repo.

## 2. Entscheidungen

| # | Frage | Entscheidung | Von |
|---|---|---|---|
| 1 | Welcher Flow | Der vorhandene `hiit-20-min` mit allen 20 Schritten, kein gekürzter Beispiel-Flow | Tim |
| 2 | Pause | Zeigt die nächste Übung wie im normalen Ablauf (Video, Name), Restzeit oben rechts | Tim |
| 3 | Arbeitsphase | Kamerabild mit Zählung der Wiederholungen | Tim |
| 4 | Welle | Bleibt so, wie sie im Kamera-Ablauf heute ist. Frequenz und Feinheiten später | Tim |
| 5 | Aufstellen | Einmal vor dem Start. Danach läuft die Uhr durch und wartet nie auf die Kamera | Tim |
| 6 | Übungen | Fehlende Übungen kommen in die Datenbank (Katalog), mit Vorschauvideo | Tim |
| 7 | Videos | Per OpenRouter erzeugt, mit dem vorhandenen Guthaben | Tim |
| 8 | Mitschrift | Eine Anleitung „Flow aus Video-Link“ entsteht nebenbei. Nur aufschreiben, nichts automatisieren | Tim |
| 9 | Bauweise | Flow-Schritt verweist auf eine Katalogübung; der Flow-Bildschirm bekommt eine eigene Kamera-Phase (Weg 1, Abschnitt 4) | Mein Vorschlag |
| 10 | Nicht zählbare Schritte | Halten, Flattern, abwechselnde Seiten: Arbeitsphase zeigt Video und Uhr wie die Pause, ohne Kamera | Mein Vorschlag |
| 11 | Kamera sieht dich nicht | Der Schritt läuft mit Uhr weiter, ein kurzer Hinweis erscheint, die Kamera versucht es weiter. Kein „Tracking verloren“-Bildschirm, kein Anhalten | Mein Vorschlag |
| 12 | Gezählte Wiederholungen | Stehen im Fertig-Bildschirm je Übung. Sie bleiben auf dem Handy und werden nicht an den Server gesendet | Mein Vorschlag |
| 13 | Kameraprofile | Im Katalog ist nur „ohne Kamera“ freigeschaltet (`FREIGESCHALTETE_PROFILE`). Die Zählung im Flow läuft deshalb vorerst nur im Test-Build über die Testprofile (Abschnitt 7) | Mein Vorschlag |
| 14 | Kein Rückblick aufs Tempo | Im Flow gibt es keinen Tempo-Rückblick je Schritt, nur die Zahl | Mein Vorschlag |
| 15 | Kostengrenze Videos | 10 $ für alle Bilder und Videos dieser Runde | Mein Vorschlag |
| 16 | Blickrichtung | Das Handy steht einmal, aber die Übungen brauchen verschiedene Blickrichtungen (Kniebeuge und Bodenübungen von der Seite, Jumping Jacks von vorn). Die Pause zeigt deshalb bei Kamera-Schritten eine Zeile „Stell dich seitlich zur Kamera“ bzw. „Schau zur Kamera“, abgeleitet aus dem Profil. Passt es trotzdem nicht, greift Entscheidung 11 | Mein Vorschlag |
| 17 | Bodenübungen | Die Profile `stuetz_boden` und `liegend` sind am iPhone ungeprüft. Liegestütze und Leg Drop & Pull gelten deshalb als Versuch, nicht als sicher. Die Aufstellprüfung bleibt stehend; eine zweite Prüfung im Liegen gibt es nicht | Mein Vorschlag |
| 18 | Build für den Test | Signierter Debug-Build direkt aus Xcode auf Tims iPhone. Nur dort gibt es die Testprofile; Release und TestFlight zählen nichts | Mein Vorschlag |
| 19 | Sichtbarkeit der neuen Übungen | Sie hängen am Gerätetyp `bodyweight` und erscheinen damit in jedem Studio im Freien Training unter „Körpergewicht“. In Trainingspläne geraten sie nicht (kein `plan`-Block). Ein Ausblend-Merkmal wird nicht gebaut | Tim |

## 3. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**
- Ein Flow-Schritt kann auf eine Katalogübung verweisen und bekommt von dort Video und Kameraangaben.
- Pause und Arbeitsphase des Flows sehen aus wie in Abschnitt 6.
- Alle 20 Schritte des HIIT-Flows haben eine Katalogübung mit Video.
- Die Anleitung beschreibt jeden Schritt so, dass der nächste Flow danach gebaut werden kann.

**Nicht-Ziele**
- Welle an HIIT-Tempo anpassen, Frequenz, Punktestand.
- Wiederholungen auf dem Server speichern oder im Portal zeigen.
- Kameraprofile für Mitglieder freischalten (dafür gilt weiter der Gütetest der Kamera-Spec).
- Zählen von Halteübungen, Flatterbewegungen und abwechselnden Seiten.
- Ein Werkzeug, das den Weg vom Link zum Flow automatisch geht.
- Flows im Trainerportal anlegen.

**Anti-Ziele**
- Die Uhr des Flows hält wegen der Kamera an oder läuft später los. Der Flow bleibt 20 Minuten.
- Ein Kamerafehler bricht den Flow ab oder verhindert, dass der Lauf gespeichert wird.
- Ein Flow ohne Verweise (alter Stand) funktioniert nicht mehr.
- Texte, Namen oder Bilder des Trainers landen in der App (gilt weiter aus der Flow-Spec).
- Etwas geht auf Prod ohne Tims ausdrückliches Ja für genau diesen Schritt.

## 4. Wege

1. **Verweis auf den Katalog, eigene Kamera-Phase im Flow (gewählt).** `flow_steps` bekommt einen optionalen Verweis auf `exercises`. Die fehlenden Übungen kommen in `catalog/gymtavo.json`. Der Flow-Bildschirm bekommt eine schlanke Kamera-Phase, die Bausteine des Kamera-Ablaufs wiederverwendet: `Koerperlage` (Zählung), `Erkennungspruefung`, `Wellenband`, `Livebild`, `Strichfigur`, `Bildquelle`. Die Zeitmaschine `FlowAblauf` bleibt, wie sie ist. Preis: eine zweite, kleinere Kamera-Steuerung neben `KameraSatzAblauf`.
2. **Den fertigen Kamera-Ablauf je Schritt einhängen** (über eine eigene `KameraNaht`, wie `KameraDemoNaht`). Am wenigsten neuer Code. Aber `KameraSatzAblauf` ist für Sätze gebaut: eigener Countdown, wartet auf 0,5 s Ruhe, hält die Welle bei verlorenem Tracking an, beendet nach 8 s Stillstand, zeigt einen Rückblick mit Pause. Das widerspricht Entscheidung 5.
3. **Video und Kameraangaben direkt am Flow-Schritt, ohne Katalog.** Schnell, widerspricht aber Entscheidung 6, und jede Übung müsste je Flow neu gepflegt werden.

Tim hat den Weg Claude überlassen; gewählt ist Weg 1.

## 5. Was heute da ist

- **Flows** (master): Tabellen `flows`, `flow_steps`, `flow_runs` (0078, 0079), `packages/domain/src/flows.ts`, `GET /me/flows`, `PUT /me/flow-runs/{id}`. App: `Flows/FlowAblauf.swift` (Zustand als Funktion der Zeit), `FlowLauf.swift` (Wanduhr), `Screens/Flows/FlowLaufView.swift`. Ein Schritt hat Name, Beschreibung, `work_s`, `rest_s`, `is_warmup`. Import: `tools/flow-import` (`flow:transkript`, `flow:sql`, `flows/hiit-20-min.json`).
- **Kamera-Oberfläche** (nur `claude/kamera-ablauf`, 25 Commits, kein PR, nicht auf origin): `Screens/Kamera/*`, `Workout/Kamera/*`, Package `Koerperbild`. Debug-Hilfen: `KameraTestprofile` (Profile aus dem Zuordnungsvorschlag), `AbspielQuelle` (Übungsvideo statt Kamera im Simulator).
- **Zusammenführen:** `claude/kamera-ablauf` steht auf `cbee5c45`, die Flows kamen danach auf master. Ein Probe-Merge zeigt genau einen Konflikt: `FitnessMember.xcodeproj/project.pbxproj`. Das Projekt wird aus `project.yml` erzeugt.
- **Katalog:** `catalog/gymtavo.json`, 260 Übungen, Körpergewicht mit Schlüsseln `bw_*`. Videos in `catalog/media/videos/`, Einspielen mit `catalog:import --nur-videos`. Die App holt Videos über `UebungsVideoVorrat` (`me/exercise-videos`) und spielt sie mit `Schleifenvideo`.
- **Videoserie:** `~/Documents/gymtavo/3D-Animationen/ki-video-serie/` (außerhalb des Repos, kein Git): `beschreiben.py`, `serie.py`, `loop.py`, `pruefen.py`, `uebungen.json`, `progress.md`. Modelle `heygen/heygen-video-1` und `google/gemini-nano-banana-2.1`. Bisher rund 0,17 $ je Übung. Schlüssel in `~/Documents/gymtavo/3D-Animationen/.env`, nie ausgeben.

## 6. Ablauf in der App

**Vor dem Start (neu, nur wenn der Flow mindestens einen zählbaren Schritt hat und die Kamera erlaubt ist):** Aufstell-Bildschirm mit Livebild, Rahmen und Strichfigur, Bausteine aus `AufstellSchritt`. Text: „Stell das Handy so auf, dass du stehend und am Boden liegend ganz im Bild bist.“ Bestanden, wenn Schulter, Hüfte, Knie und Fuß einer Seite 1 s sicher erkannt sind (Profil `ganzkoerper_stehend`). Dann beginnt der Countdown. „Ohne Kamera starten“ ist immer sichtbar; dann läuft der ganze Flow wie heute, mit Videos. Kamera nicht erlaubt: Hinweis mit Weg in die Einstellungen und „Ohne Kamera starten“.

**Pause (und Countdown vor Schritt 1):**

```
PAUSE                        ⏱ 0:14
┌────────────────────────────────┐
│     Übungsvideo (Schleife)     │
└────────────────────────────────┘
Als Nächstes
Liegestütze
Den Körper gerade halten …
[ Anhalten ]   [ Abbrechen ]
```

Ohne Video (kein Verweis, offline, nicht geladen): der Platz zeigt den Ring von heute.

**Arbeit, zählbarer Schritt:**

```
SCHRITT 12 VON 20            ⏱ 0:31
┌────────────────────────────────┐
│   Livebild + Strichfigur       │
│   ~~~~ Welle ~~~●~~~~          │
│              14 Wdh.           │
└────────────────────────────────┘
Liegestütze
Als Nächstes: Leg Drop & Pull
```

- Die Kamera startet 5 s vor Ende der Pause und stoppt am Ende der Arbeitsphase. In Pausen und nicht zählbaren Schritten ist sie aus (Wärme und Akku über 20 Minuten sind ungemessen).
- Die Zählung beginnt mit der Arbeitsphase. Es gibt keine Wartezeit auf eine ruhige Startposition. `Koerperlage.los(t:)` verlangt keine Ruhe und nimmt das Mittel der letzten 0,5 s als Startlage; kostet das die erste Wiederholung, ist das für diesen Versuch hinnehmbar.
- Die Welle läuft ab Beginn der Arbeitsphase mit dem Tempo der Übung (`Wellenband`, unverändert). Kein Phasenwort-Zwang, kein „zu schnell“-Urteil nötig; der Bauende darf Pille und Phasenwort weglassen, wenn sie stören.
- Sind die Pflichtgelenke 3 s nach Beginn nicht erkannt oder gehen sie länger als 1 s verloren: Hinweiszeile „Kamera sieht dich gerade nicht“, das Livebild bleibt, die Zahl bleibt stehen, die Uhr läuft. Kommt die Erkennung zurück, zählt sie weiter.
- Anhalten hält Uhr und Zählung an. Die App im Hintergrund: Die Uhr läuft wie heute weiter (Wanduhr), die Kamera stoppt und startet beim Zurückkommen neu.

**Arbeit, nicht zählbarer Schritt:** wie die Pause, mit Überschrift „SCHRITT n VON 20“, Video der laufenden Übung und „Als Nächstes: …“.

**Fertig:** wie heute, dazu eine Liste der gezählten Schritte mit Zahl („Liegestütze 14“). Schritte ohne Zählung stehen nicht in der Liste.

## 7. Daten

- **Migration 0080:** `flow_steps.exercise_id uuid null references public.exercises(id) on delete set null`. Keine neue Policy. Lokal bauen und testen; auf Prod nur mit Tims Ja.
- **Domäne und API:** `FlowSchritt` bekommt `exerciseId: string | null`; `GET /me/flows` liefert es. App-DTO entsprechend, optional dekodiert, damit ein alter Server die App nicht bricht.
- **Flow-Datei:** jeder Schritt in `tools/flow-import/flows/*.json` bekommt optional `uebung` (Katalogschlüssel). `flow:sql` löst ihn im SQL per Unterabfrage auf die Gymtavo-Katalogübung auf und bricht ab, wenn ein Schlüssel nicht im Katalog steht (Prüfung gegen `catalog/gymtavo.json`).
- **Übung in der App finden:** über `exerciseId` in den Übungen aus dem Bootstrap (er enthält den ganzen Gymtavo-Katalog; Übungen und Videos hängen dort am Gerätetyp, die neuen also an `bodyweight`); Video über `UebungsVideoVorrat`. Fehlt die Übung dort, läuft der Schritt wie ohne Verweis.
- **Kameraangaben:** Die App nimmt `kameravorgabe` und `uebungstempo` der Übung. Weil der Katalog noch keine echten Profile ausliefern darf, kommen sie im Test-Build aus `KameraTestprofile.json`; `tools/kamera-zuordnung/testprofile.py` wird um die Flow-Übungen aus Abschnitt 8 ergänzt. Im Release-Build sind damit vorerst alle Schritte „nicht zählbar“. Der Schalter „Kamera-Testprofile“ im Profil gilt auch für Flows.
- **Lauf speichern:** `flow_runs` und der Weg dorthin bleiben unverändert.

## 8. Die 20 Schritte

Vorschlag von Claude, von Tim zu prüfen. „Kamera“ heißt: bekommt ein Testprofil, wenn die Zählung am Mac gegen das erzeugte Video stimmt (wie Stufe 1 der Kamera-Spec, `Skelettfolge`/Profilbericht). Stimmt sie nicht, fällt der Schritt auf „Uhr“ zurück; das ist kein Scheitern.

| # | Schritt | Katalog | Video | Arbeitsphase | Signal (Vorschlag) |
|---|---|---|---|---|---|
| 1 | High Kicks | neu | neu | Uhr (abwechselnd) | – |
| 2 | Burpee | neu | neu | Kamera, Versuch | Hüfte |
| 3 | Jumping Jacks | neu | neu | Kamera | Schulter |
| 4 | Toe Touches + Jackknifes | neu | neu | Uhr (zwei Bewegungen im Wechsel) | – |
| 5 | Mini Scissor Kicks | neu | neu | Uhr (Flattern) | – |
| 6 | Burpee (wie Schritt 2, `bw_burpee_slow`) | `bw_burpee_slow` | von Schritt 2 | Kamera, Versuch | Hüfte |
| 7 | Squat-Pulse | neu | neu | Kamera, Versuch (kleiner Hub) | Knie |
| 8 | Plank | `bw_plank` | neu | Uhr (Halten) | – |
| 9 | Swimmer | neu | neu | Uhr (Flattern) | – |
| 10 | Russian Twist | `bw_russian_twist` | neu | Uhr (Drehung, kein Gelenkwinkel) | – |
| 11 | Lunge + Kick | neu | neu | Kamera, Versuch | Knie |
| 12 | Liegestütze | `bw_pushup` | vorhanden | Kamera, Versuch (Boden) | Ellbogen |
| 13 | Leg Drop & Pull | neu | neu | Kamera, Versuch (Boden) | Hüfte |
| 14 | Weitsprung mit Bodenberührung | neu | neu | Uhr (verlässt das Bild) | – |
| 15 | Squat mit Händen zum Boden | neu | neu | Kamera | Knie |
| 16 | Plank mit Knie zur Brust | `bw_mountain_climber` | prüfen | Uhr (abwechselnd) | – |
| 17 | Flutter Kicks | neu | neu | Uhr (Flattern) | – |
| 18 | Skater Jumps | neu | neu | Uhr (abwechselnd) | – |
| 19 | Crunch-Halten | neu | neu | Uhr (Halten) | – |
| 20 | Burpees mit Streckung | neu | neu | Kamera, Versuch | Hüfte |

Ergebnis: 15 neue Katalogübungen, bis zu 18 neue Videos (27.11.2026: von Tim so entschieden: `bw_burpee_slow` heißt nur „Burpee“, `bw_burpee_thigh_tap` entfällt, Schritt 6 nutzt `bw_burpee_slow`; vorher 16 und 19), 2 Schritte sicher mit Kamera (Jumping Jacks, Squat mit Händen zum Boden), 7 als Versuch, 11 mit Uhr.

- **Nah an Vorhandenem:** Der Katalog hat `bw_v_up` (Klappmesser), `bw_squat` (Kniebeuge) und `bw_crunch` (Crunch). Die Schritte 4, 15 und 19 sind Varianten davon (Wechsel mit Toe Touches, Hände zum Boden, Halten) und werden als eigene Übungen angelegt. Tim sieht das bei der Listenprüfung ausdrücklich.
- **Die Prüfung am Mac beweist die Blickrichtung nicht:** Jedes erzeugte Video hat seinen eigenen passenden Kamerawinkel. Ob ein Schritt am iPhone mit einem einzigen Aufstellort zählt, zeigt erst Tims Test. Die neuen Videos der Kamera-Schritte werden in der Blickrichtung ihres Profils erzeugt.
- **Testprofile:** `KameraTestprofile` schlüsselt nach Übungsname und lässt die Bodenprofile bisher aus (`testprofile.py`). Für den Flow werden die acht Kamera-Übungen (neun Schritte, Burpee doppelt) dort aufgenommen, einschließlich `stuetz_boden` und `liegend`; die neuen Namen müssen eindeutig sein. Das Profil wirkt bisher nur in `GeraetModel`, der Flow braucht denselben Zugriff.

- **Neue Katalogübungen:** Schlüssel `bw_*`, Namen und Beschreibungen in eigenen Worten (die Texte aus `hiit-20-min.json` sind schon eigene), alle Pflichtfelder des Katalogformats (`packages/domain/src/katalog-datei.ts`). `volume_kind`: `seconds` für Halteübungen, sonst `reps`. Tempo für die Kamera-Schritte: schnell, im erlaubten Raster (Vorschlag 1 s / 0 / 1 s); die Welle selbst bleibt unangetastet.
- **Tim prüft die Liste der neuen Übungen** (Name, Schlüssel), bevor sie in den Katalog und auf Prod gehen.

## 9. Videos

- Erzeugt mit der vorhandenen Serie im Ordner `ki-video-serie`, gleicher Look (Graphit-Figur, schwarzes Shirt mit „G.“, helles Studio), ohne Gerät. Dazu werden die 18 Übungen in `uebungen.json` ergänzt (Szene, Kamera, Bewegung, Prüfpunkte, Ende), Startbild und Video erzeugt, als Loop geschnitten.
- Abwechselnde und zusammengesetzte Übungen nutzen die Loop-Arten `wechsel` und `ganz` der Serie.
- **Halt:** Claude sieht Videos nur als Standbilder. Tim nimmt die Bewegung auf einer Prüfseite ab (`seiten/…html`). Höchstens 3 Anläufe je Übung; was dann nicht passt, bleibt ohne Video und der Schritt zeigt den Ring.
- Kostengrenze 10 $ (Entscheidung 15), erwartet 4–6 $. Vor dem Start wird das Guthaben bei OpenRouter geprüft.
- Einspielen: Loops nach `catalog/media/videos/` im Format der vorhandenen (640×640, 24 Bilder/s), dann `catalog:import --nur-videos`. Auf Prod nur mit Tims Ja.

## 10. Mitschrift

`docs/flows/flow-aus-video.md`, entsteht während der Arbeit und wird am Ende geglättet. Inhalt: Link → Transkript (`flow:transkript`) → Entwurf und unsichere Schritte → Abgleich mit dem Katalog (wie gesucht, wann „gleiche Übung“, wann neu) → neue Katalogübungen → Videos (Befehle, Prüfseite, Kosten) → Kamera oder Uhr je Schritt (Regeln aus Abschnitt 8) → `uebung`-Schlüssel in der Flow-Datei → `flow:sql` → Einspielen und Freigaben → Probe in der App. Dazu eine Liste „Was beim HIIT-Flow schiefging oder Zeit gekostet hat“. Keine neuen Skripte außer dem, was dieser Entwurf ohnehin verlangt.

## 11. Fehlerfälle

| Fall | Verhalten |
|---|---|
| Schritt ohne Verweis oder Übung nicht im Bootstrap | Pause und Arbeit mit Ring wie heute |
| Kein Video geladen | Ring statt Video |
| Kamera nicht erlaubt oder nicht verfügbar | Flow läuft ohne Kamera; ein Hinweis vor dem Start |
| Kamera fällt mitten im Flow aus | Hinweiszeile, Schritt läuft mit Uhr; beim nächsten zählbaren Schritt neuer Versuch |
| Person nicht erkannt | Entscheidung 11 |
| Bildrate bricht ein | wie „nicht erkannt“; kein eigener Dialog |
| Abbrechen | wie heute; gezählte Zahlen verfallen |
| Alter Server ohne `exerciseId` | App läuft wie heute |

## 12. Etappen

| Etappe | Inhalt | Fertig, wenn |
|---|---|---|
| E0 | `origin/master` in `claude/flow-kamera` mergen, Xcode-Projekt neu erzeugen, alle Tests grün | App baut mit Flows und Kamera-Ablauf |
| E1 | Daten: Migration 0080 lokal, Domäne, API, DTO, `uebung` in Flow-Datei und `flow:sql` | Tests grün, lokaler Flow liefert `exerciseId` |
| E2 | Katalog: 15 neue Übungen, Flow-Datei mit 20 Verweisen | Tim hat die Liste gesehen |
| E3 | Videos: Beschreibungen, Erzeugen, Prüfseite | Tim hat die Videos abgenommen, Loops im Katalog |
| E4 | App: Pause und Uhr-Schritt mit Video und Zeit oben rechts | Im Simulator sichtbar |
| E5 | App: Aufstellen vor dem Start, Kamera-Phase, Fertig mit Zahlen; Testprofile für die Flow-Übungen, Prüfung am Mac gegen die Videos | Im Simulator mit `AbspielQuelle` zählt ein Schritt; Bericht je Kamera-Schritt liegt vor |
| E6 | Prod mit Tims Ja je Schritt (0080, API-Deploy für `exerciseId`, Katalog, Videos, Flow neu einspielen), signierter Debug-Build, Anleitung fertig | Tim hat den Flow am iPhone trainiert |

E3 hängt an Tims Abnahme und läuft neben E4 und E5.

## 13. Tests

- Domäne/API: `exerciseId` im Flow, Flow ohne Verweise unverändert; Integrationstests nach dem Muster `api-flows.test.ts`, `db-flows.test.ts`.
- `flow-sql`: Schlüssel wird aufgelöst, unbekannter Schlüssel bricht ab, Datei ohne Schlüssel erzeugt SQL wie heute.
- Katalog: Prüfung der Datei bleibt grün mit den neuen Übungen.
- App, reine Logik: welche Ansicht ein Schritt bekommt (Video, Ring, Kamera) aus Flow, Übungen, Erlaubnis und Wahl; Kamera-Steuerung des Flows mit Skeletten aus Dateien (zählt, verliert, findet wieder, Anhalten); Zahlen im Fertig-Bildschirm.
- `FlowAblauf`- und `FlowLauf`-Tests bleiben unverändert grün.

## 14. Dem Bauenden überlassen

- Name und Zuschnitt der Kamera-Steuerung für den Flow; was sie aus `KameraSatzAblauf` teilt.
- Wie der Aufstell-Bildschirm die vorhandenen Ansichten wiederverwendet.
- Genaue Anordnung und Texte innerhalb der Skizzen aus Abschnitt 6; ob Phasenwort und Takt-Pille gezeigt werden.
- Schwellen (3 s, 1 s, 5 s Vorlauf der Kamera).
- Pflichtfelder der neuen Katalogübungen (Muskeln, Planmerkmale) nach dem Muster der vorhandenen `bw_*`.
- Aufteilung in PRs.

## 15. Offen bei Tim

1. ~~Reihenfolge der PRs~~ Entschieden (Tim, 26.11.): Der Kamera-Ablauf geht in diesem Zweig mit, ein gemeinsamer PR.
2. Liste aus Abschnitt 8 und die neuen Übungsnamen.
3. Abnahme der Videos.
4. Freigaben für Prod, jeweils einzeln.
