# Task 4: Bericht

Stand 27.11.2026: Schritte 1–4 sind erledigt. Alle 19 Loops sind erzeugt, die Prüfseite steht. **HALT:** Tim nimmt die Bewegung ab. Keine Übung ist abgenommen, ich habe die Loops nur als Standbildstreifen gesehen.

Der erste Stand war BLOCKED: Das Guthaben lag bei 5,61 $, also unter 10 $. Danach hat Tim die Runde mit dem vorhandenen Guthaben und einer Grenze von 5 $ freigegeben.

**Aktueller Stand:** Die Nachzüge nach Tims Abnahme sind erledigt. Paket 11 hat jetzt 18 Übungen, Tim prüft erneut. Details stehen im Abschnitt „Nachzüge nach Tims Abnahme“ unten.

## Nachzüge nach Tims Abnahme (27.11.2026)

**Kosten und Guthaben:**

| | Wert |
|---|---|
| Kosten der Runde gesamt | 3,21 $ (Grenze 5 $), davon 0,64 $ für die Nachzüge |
| Kostenbuch | 35,26 $ |
| Guthaben OpenRouter nachher | 2,40 $ |
| Halt in `api.py` | unverändert bei 36,35 $ |

**Prüfseite** (18 Videos, bw_burpee_slow heißt dort „Burpee“):

```bash
open /Users/timbuttner/Documents/gymtavo/3D-Animationen/ki-video-serie/seiten/paket-11.html
```

Die Serien-Tests laufen 76 von 76 grün. Sie haben jetzt die Liste `ENTFALLEN` in `tests/hiit_keys.py`.

### Ohne API-Aufruf erledigt

- **Abgenommen, unverändert:** bw_scissor_kicks, bw_squat_pulse, bw_russian_twist, bw_lunge_kick, bw_leg_drop_pull, bw_squat_floor_touch, bw_flutter_kicks, bw_burpee_jump.
- **15 % schneller** per ffmpeg: bw_high_kicks (jetzt 5,25 s), bw_burpee_slow (6,92 s), bw_jumping_jack (2,38 s). Das Format bleibt 640×640, 24 Bilder/s, h264 yuv420p. Die Originale liegen unter `alt-hiit/loops-<key>-vor-abnahme.mp4`.
- **bw_plank:** ruhender Loop von 4 s aus dem Umkehrbild des Rohclips (Bild 27). Es zeigt eine saubere gestreckte Unterarm-Plank.
- **bw_burpee_thigh_tap:** entfällt (Tim, 27.11.). In `stand.json` steht `entfaellt`. Die Übung ist aus Paket 11 genommen, der Loop bleibt liegen.

### Neu erzeugt

| Übung | Anlauf | Was der Streifen zeigt |
|---|---|---|
| bw_toe_touch_jackknife | 2 | Drei Hochkommen: zweimal über Kreuz (der Oberkörper dreht dabei zur Kamera), dann die Mitte. Den Loop habe ich von Hand mit 3 Ausschlägen gebaut, weil `serie.py` nach dem ersten Toe Touch abschnitt. Er endet knapp, bevor der Oberkörper ganz liegt, an der Naht ist ein kleiner Ruck möglich. Ob jeweils das richtige Bein und der richtige Arm zusammengehen, kann ich im Standbild nicht beurteilen. |
| bw_swimmer | 2, jetzt `wechsel` | Neues Startbild, alle vier Gliedmaßen auf der Matte. In Clip A heben Arm und Bein kaum sichtbar ab. Clip B musste ich einmal extra neu erzeugen, weil die Figur zur Kamera rollte; jetzt mit `ohne_logo`, die Figur bleibt auf dem Bauch und hebt ein Bein deutlich (eher zu hoch) mit dem Gegenarm. Ob in A beide Beine liegen bleiben, ist nicht sicher erkennbar. |
| bw_broad_jump_touch | **3 (letzter)** | Zügiger Sprung, Boden berühren, umdrehen, zurückspringen, Boden berühren. Am Ende steht die Figur zur Kamera gedreht statt nach rechts, an der Loop-Naht ist eine Drehung zu sehen. |
| bw_mountain_climber | Zähler 1, Clip B neu | Clip A unverändert. Clip B zieht das Knie jetzt höher und deutlicher zur Brust, die Wippbewegung sehe ich nicht mehr. |
| bw_skater_jump | 2, jetzt Hin-und-zurück | Startbild zweimal neu, bis die Landelage stimmte. Die Figur springt direkt von der einen Landung in die andere, ohne Zwischenschritt. |
| bw_crunch_hold | **3 (letzter)** | Mit `ohne_logo` bleibt die Figur seitlich und kommt gerade hoch. Die Hände umfassen eher den Kopf, als dass sie an den Schläfen liegen. |

### Hinweise für die Anleitung „Flow aus Video“

- **Der Logo-Satz im Videoprompt** lässt Figuren in Bauch- oder Rückenlage zur Kamera drehen. Für Bodenübungen sollte `ohne_logo` von Anfang an gesetzt sein.
- **Mehrere Phasen gleicher Größe** wie Toe Touch links, rechts und Mitte schneidet die Loop-Art `ganz` nach der ersten ab. Die Zahl der Ausschläge sollte in `uebungen.json` einstellbar sein.
- **Abwechselnde Sprünge:** Hin-und-zurück zwischen zwei Landelagen ergibt einen direkten Wechsel ohne Zwischenschritt.
- **Halteübungen:** Ein Standbild-Loop aus dem Umkehrbild kostet nichts und ist sauberer als ein Clip.

## Erzeugung (Runde 27.11.2026)

**Kosten und Guthaben:**

| | Wert |
|---|---|
| Kostenbuch vorher | 32,05 $ |
| Kostenbuch nachher | 34,62 $ |
| Kosten der Runde | 2,57 $ (Grenze 5 $) |
| Guthaben OpenRouter vorher | 5,61 $ |
| Guthaben OpenRouter nachher | 3,04 $ |

**Geänderte Dateien:**
- **Budget-Halt in `api.py`:** von `halt=0.81` (32,40 $) auf `halt=0.9087` (36,35 $). Sonst ist nichts geändert.
- **Tests der Serie:** neue Zusatzliste `tests/hiit_keys.py`. `test_datei_vollstaendig` und `test_pakete_decken_umfang` prüfen weiter die 190 Katalogübungen und zusätzlich genau diese 19 als letztes Paket. 76 von 76 Tests sind grün.

**Prüfseite** (19 Videos, mit Namen):

```bash
open /Users/timbuttner/Documents/gymtavo/3D-Animationen/ki-video-serie/seiten/paket-11.html
```

Die alten Fassungen nachgezogener Startbilder und Videos liegen in `alt-hiit/`.

| # | Schlüssel | Loop-Art | Winkel | Anläufe Video | Startbild / eigene Prüfung |
|---|---|---|---|---|---|
| 1 | bw_high_kicks | wechsel (bewegung_b) | seitlich | 1 | ok; ob Clip B wirklich das andere Bein schwingt, ist im Standbild nicht sicher erkennbar |
| 2 | bw_burpee_slow | ganz | seitlich | 1 | ok; voller Ablauf mit Rückkehr in den Stand, 7,96 s |
| 3 | bw_jumping_jack | Hin-und-zurück | frontal | 1 | 2 Startbilder; die Füße stehen auch im zweiten hüftbreit statt geschlossen, so belassen |
| 4 | bw_toe_touch_jackknife | ganz | seitlich, liegend | 1 | ok; Toe Touch, Ablegen und V-Klappe gut erkennbar |
| 5 | bw_scissor_kicks | Hin-und-zurück | vom Fußende, erhöht | 1 | Hände liegen neben dem Körper statt unter dem Gesäß, die Beine sind kaum angehoben; das Kreuzen ist sichtbar |
| 6 | bw_burpee_thigh_tap | ganz | seitlich | 1 | 2 Startbilder, das erste schaute nach links; Ablauf voll, den Oberschenkel-Tap habe ich im Streifen nicht gesehen |
| 7 | bw_squat_pulse | Hin-und-zurück | seitlich | **3 (letzter)** | Anlauf 1 und 2 standen ganz auf; Anlauf 3 richtet sich noch halb auf und federt nicht klein |
| 8 | bw_plank | Hin-und-zurück | seitlich | 1 | startet schon fast im Stütz, kleine Bewegung, 2,08 s; zeigt eher Halten als Hochkommen |
| 9 | bw_swimmer | Hin-und-zurück | schräg seitlich, erhöht | 1 | 2 Startbilder, im ersten fehlte die Gegenlage; Flattern sichtbar |
| 10 | bw_russian_twist | wechsel (gespiegelt) | frontal, symmetrisch | 1 | ok, Drehung zu beiden Seiten |
| 11 | bw_lunge_kick | ganz | seitlich | 1 | Oberkörper dreht im Ausfallschritt zur Kamera, Kick nach vorn ok, nur eine Seite |
| 13 | bw_leg_drop_pull | ganz | seitlich, liegend | 1 | ok, voller Ablauf |
| 14 | bw_broad_jump_touch | ganz | seitlich, weit | 2 | 3 Startbilder (zweimal zu weit rechts); in beiden Anläufen kehrt die Figur nicht ganz an den Startplatz zurück, an der Loop-Naht springt sie |
| 15 | bw_squat_floor_touch | Hin-und-zurück | seitlich | 1 | ok, Fingerspitzen gehen zum Boden |
| 16 | bw_mountain_climber | wechsel (bewegung_b) | seitlich | 1 | ok, Knie kommt nach vorn; nah/fern nicht sicher erkennbar |
| 17 | bw_flutter_kicks | Hin-und-zurück | seitlich, liegend | 1 | ok; Hände nicht unter dem Gesäß; Loop nur 1,46 s |
| 18 | bw_skater_jump | wechsel (gespiegelt) | frontal | 1 | ok, Sprünge zu beiden Seiten |
| 19 | bw_crunch_hold | Hin-und-zurück | seitlich, liegend | 1 | ok, Kopf im Startbild schon leicht angehoben |
| 20 | bw_burpee_jump | ganz | seitlich | 1 | ok, voller Ablauf mit Strecksprung |

### Hinweise für die Anleitung „Flow aus Video“ (Ergänzung)

- **Sehr kleine Bewegungen** wie Squat-Pulse setzt das Videomodell nicht um. Es macht daraus volle Wiederholungen. Solche Schritte besser als Uhr führen oder ein anderes Video in Kauf nehmen.
- **Ortswechsel** wie Weitsprünge brauchen eine Rückkehr an den Startplatz. Das Modell schafft sie nicht sicher, und der Loop bekommt einen Sprung an der Naht.
- **Platzierung im Bild** („am linken Rand“) setzt das Bildmodell erst um, wenn es ausdrücklich heißt, dass der Rest des Bildes leer bleibt.
- **Kontaktbogen von `pruefen.py`** zeigt nur die ersten 5 s. Für die Loop-Art `ganz` (8 s) braucht die Prüfung einen eigenen Streifen über die ganze Länge.
- **Rundenkosten:** 19 Übungen haben 2,57 $ gekostet, darin 6 neue Startbilder und 2 Videonachzüge.

## Vorarbeit

Alles liegt in `~/Documents/gymtavo/3D-Animationen/ki-video-serie/`. Erledigt ist nur die kostenlose Vorarbeit:

- **Sicherungen:** `uebungen.vor-hiit-2026-11-27.json`, `pakete.vor-hiit-2026-11-27.json` und `stand.vor-hiit-2026-11-27.json`.
- **`uebungen.json`:** 19 neue `bw_*`-Einträge, von Hand geschrieben nach `docs/flows/hiit-20-min-uebungen.md` und den Katalogtexten aus dem Worktree. Die 190 alten Einträge sind unverändert, das ist per Vergleich mit der Sicherung geprüft. `beschreiben.pruefe_eintrag` meldet 19 von 19 als gültig. Die Texte sind eigene, neutrale Formulierungen ohne Bezug zur Videovorlage.
- **`pakete.json`:** Paket 11 mit den 19 Übungen in Flow-Reihenfolge. Die Pakete 1–10 sind unverändert.
- **`stand.json`:** unverändert. Die Einträge entstehen erst bei `serie.py erzeuge`.
- **`api.py`:** unverändert, wie vorgegeben.

### Die 19 Einträge

| # | Schlüssel | Loop-Art | Kamera | Geräte |
|---|---|---|---|---|
| 1 | bw_high_kicks | wechsel (bewegung_b: nahes, dann fernes Bein) | seitlich | – |
| 2 | bw_burpee_slow | ganz | seitlich | – |
| 3 | bw_jumping_jack | Hin-und-zurück | frontal | – |
| 4 | bw_toe_touch_jackknife | ganz | seitlich, liegend | matte |
| 5 | bw_scissor_kicks | Hin-und-zurück zwischen zwei Kreuzlagen | vom Fußende, erhöht | matte |
| 6 | bw_burpee_thigh_tap | ganz | seitlich | – |
| 7 | bw_squat_pulse | Hin-und-zurück (Start tief, Viertelhub) | seitlich | – |
| 8 | bw_plank | Hin-und-zurück (Hochkommen, Halten, Ablegen) | seitlich | matte |
| 9 | bw_swimmer | Hin-und-zurück zwischen zwei Gegenlagen | schräg von vorn-seitlich, erhöht | matte |
| 10 | bw_russian_twist | wechsel (gespiegelt) | frontal, symmetrisch | matte |
| 11 | bw_lunge_kick | ganz (eine Seite) | seitlich | – |
| 13 | bw_leg_drop_pull | ganz | seitlich, liegend | matte |
| 14 | bw_broad_jump_touch | ganz (mit Rücksprung) | seitlich, weit | – |
| 15 | bw_squat_floor_touch | Hin-und-zurück | seitlich | – |
| 16 | bw_mountain_climber | wechsel (bewegung_b) | seitlich | – |
| 17 | bw_flutter_kicks | Hin-und-zurück zwischen zwei Gegenlagen | seitlich, liegend | matte |
| 18 | bw_skater_jump | wechsel (gespiegelt) | frontal, symmetrisch | – |
| 19 | bw_crunch_hold | Hin-und-zurück (Hochrollen, Halten, Ablegen) | seitlich, liegend | matte |
| 20 | bw_burpee_jump | ganz | seitlich | – |

Die Spalten Anläufe und Auffälligkeiten am Startbild fehlen, weil noch nichts erzeugt ist.

### Abweichungen vom Brief, je mit Grund

- **Matte statt `[]`:** Die Bodenübungen haben `geraete: ["matte"]`, wie `bw_crunch` und `bw_dead_bug` der Serie. So sieht es aus wie im bisherigen Katalog.
- **`bw_russian_twist` als `wechsel`:** Der Brief nennt die Übung bei keiner Loop-Art. Sie ist gebaut wie das abgenommene `db_russian_twist`: frontal, die zweite Seite gespiegelt. Der Katalogtext verlangt beide Seiten.
- **`bw_leg_drop_pull` als `ganz`:** Auch diese Übung steht in keiner Liste des Briefs. Der Ablauf Absenken, Knie heran, Strecken ist kein Hin-und-zurück.
- **Halten und Flattern:** Ein ruhender Clip hat keinen Umkehrpunkt und bricht mit `KeinUmkehrpunkt` ab. Deshalb zeigen Plank und Crunch-Halten das Hochkommen, kurz Halten und Ablegen. Die Flatterübungen beginnen in einer Gegenlage und kehren in der anderen um. Hin und zurück ergibt so einen vollen Wechsel.
- **`wechsel` in Seitenansicht mit `bewegung_b`:** Spiegeln vertauscht nur links und rechts im Bild, nicht nah und fern. Laut `progress.md` ist Spiegeln bei schräger Ansicht schon einmal gescheitert.

### Tests der Serie

74 sind grün, 2 rot: `test_datei_vollstaendig` und `test_pakete_decken_umfang`. Beide verlangen, dass Serie und Pakete genau die reps-Übungen der Katalogkopie `katalog/gymtavo.json` abdecken. Die 19 `bw_*` stehen nicht in der Kopie, und 7 davon zählen Sekunden. Funktional ändert das nichts, `serie.py` und `pruefen.py` laufen mit Paket 11. Die Entscheidung steht noch aus: entweder die Tests um eine Zusatzliste erweitern oder die Einträge zurücknehmen.

### Namen auf der Prüfseite

`pruefen.namen()` liest die Namen aus `katalog.uebungen()`. Diese Funktion filtert auf `volume_kind == "reps"`. Ein Eintrag in die Serienkopie des Katalogs hilft deshalb nur bei 12 von 19 Übungen. Für die 7 Übungen mit Sekunden und für `bw_russian_twist` ginge es nur mit einer Codeänderung.

Die kleinste Lösung kommt ohne Dateiänderung aus: Die Seite wird mit einem eigenen Namensverzeichnis aus dem Worktree-Katalog gebaut. Der Befehl steht in `progress.md` und ist getestet, alle 19 Namen werden gefunden:

```bash
cd ~/Documents/gymtavo/3D-Animationen/ki-video-serie && python3 -c "import json,pruefen; k=json.load(open('/Users/timbuttner/Documents/gymtavo/fitness-app/.claude/worktrees/flow-kamera/catalog/gymtavo.json')); print(pruefen.seite(11, pruefen.pakete()[10], {u['key']: u['name']+' · Körpergewicht' for u in k['exercises']}))"
```

Die Seite entsteht dann unter `~/Documents/gymtavo/3D-Animationen/ki-video-serie/seiten/paket-11.html`.

### Vor dem Start nötig (Entscheidung Tim)

- **Guthaben:** auf mindestens 10 $ aufladen.
- **Budget-Halt in `api.py`:** `Kosten(obergrenze=40, halt=0.81)` hält bei 32,40 $. Gebucht sind 32,05 $, der Halt käme also nach etwa 0,35 $. Für diese Runde müsste die Grenze bei etwa 41,3 $ liegen: 32,05 $ plus 10 $, abzüglich etwa 0,7 $ Puffer, weil 8 Threads parallel laufen.

### Geplante Reihenfolge und Kostenschätzung

Grundlage sind die Mittelwerte aus `kosten.json`: Bild 0,043 $, Video 5 s 0,05 $, Video 8 s (`ganz`) 0,08 $, `wechsel` 0,10 $.

| Block | Übungen | 1. Anlauf | mit üblichen Nachzügen |
|---|---|---|---|
| A, Kamera-Schritte | 2, 3, 6, 7, 11, 13, 15, 20 (5 × ganz, 3 × Hin-und-zurück) | ca. 0,90 $ | ca. 1,5 $ |
| B, Uhr-Schritte | 1, 4, 5, 8, 9, 10, 14, 16, 17, 18, 19 (4 × wechsel, 2 × ganz, 5 × Hin-und-zurück) | ca. 1,30 $ | ca. 2,1 $ |
| Summe | 19 | ca. 2,2 $ | ca. 3,5–4 $; schlimmster Fall mit 3 Anläufen je Übung ca. 7 $ |

Ablauf je Block: zuerst `serie.py start <keys>` (nur Startbilder) und große Prüfung mit `pruefen.py starts`. Danach `serie.py erzeuge <keys>` und die Paarprüfung mit `pruefen.py paare`.

## Für die spätere Anleitung „Flow aus Video“

- **Halteübungen** brauchen eine Bewegung in die Haltung hinein. Sonst findet `loop.py` keinen Umkehrpunkt.
- **Flatterübungen:** Start und Umkehr als zwei Gegenlagen beschreiben, dann ergibt Hin-und-zurück einen vollen Zyklus.
- **Abwechselnde Übungen:** Spiegeln nur bei frontal-symmetrischer Szene. In Seitenansicht trägt `bewegung_b` die zweite Seite, und das ist unsicher.
- **Zusammengesetzte Übungen** als `ganz` mit 8-s-Clip, die Phasen nummeriert beschreiben.
- **Katalogkopie der Serie:** Neue Übungen fehlen dort. Namen auf der Prüfseite und die Tests der Serie gehen von der Kopie aus, und die Kopie kennt nur reps.

## Übernahme in den Katalog (16)

Stand 27.11.2026. 16 von 18 Übungen aus Paket 11 sind im Katalog; `bw_swimmer` und `bw_toe_touch_jackknife` folgen nach Abnahme.

**Umrechnen nicht nötig:** Die Loops aus `ki-video-serie/loops/` haben schon das Katalogformat (h264 High, yuv420p, 640×640, 24 Bilder/s, keine Tonspur), wie `bw_pushup`. Es gab daher keinen ffmpeg-Aufruf; die Dateien sind byte-gleich kopiert. Das Skript `scripts/katalog-videos-einspielen.ts` prüft 640×640 und keine Tonspur per ffprobe.

**Skript-Änderung:** Das Skript lehnte Übungen mit Zeitvorgabe ab (6 der 16: crunch_hold, flutter_kicks, high_kicks, mountain_climber, plank, scissor_kicks). Neu: Option `--auch-zeit` (`plane(..., { auchZeit: true })`), Standard unverändert. Neuer Test „nimmt eine Zeituebung nur mit auchZeit“ erst rot, dann grün.

| Schlüssel | Zieldatei | Größe (Byte) |
|---|---|---|
| bw_high_kicks | catalog/media/videos/bw_high_kicks.mp4 | 439632 |
| bw_burpee_slow | catalog/media/videos/bw_burpee_slow.mp4 | 626371 |
| bw_jumping_jack | catalog/media/videos/bw_jumping_jack.mp4 | 262542 |
| bw_scissor_kicks | catalog/media/videos/bw_scissor_kicks.mp4 | 165599 |
| bw_squat_pulse | catalog/media/videos/bw_squat_pulse.mp4 | 227859 |
| bw_plank | catalog/media/videos/bw_plank.mp4 | 35289 |
| bw_russian_twist | catalog/media/videos/bw_russian_twist.mp4 | 431722 |
| bw_lunge_kick | catalog/media/videos/bw_lunge_kick.mp4 | 570657 |
| bw_leg_drop_pull | catalog/media/videos/bw_leg_drop_pull.mp4 | 507059 |
| bw_broad_jump_touch | catalog/media/videos/bw_broad_jump_touch.mp4 | 792868 |
| bw_squat_floor_touch | catalog/media/videos/bw_squat_floor_touch.mp4 | 291531 |
| bw_mountain_climber | catalog/media/videos/bw_mountain_climber.mp4 | 469507 |
| bw_flutter_kicks | catalog/media/videos/bw_flutter_kicks.mp4 | 87269 |
| bw_skater_jump | catalog/media/videos/bw_skater_jump.mp4 | 387382 |
| bw_crunch_hold | catalog/media/videos/bw_crunch_hold.mp4 | 174457 |
| bw_burpee_jump | catalog/media/videos/bw_burpee_jump.mp4 | 699592 |

`duration_s` aus der Datei (Importfunktion): 2 s ×1, 3 s ×3, 4 s ×4, 6 s ×1, 7 s ×2, 8 s ×5. `bw_burpee_slow` hat ein Video für beide Flow-Schritte.

**Tests:** `pnpm --filter @fitretro/domain test` 53 Dateien / 798 Tests grün (inkl. Katalog- und Medienprüfung); `npx tsc --noEmit` ohne Fehler. Kein `catalog:import`, keine Datenbank. Zweiter Skriptlauf änderte nichts; `git diff --stat catalog/gymtavo.json`: 64 Einfügungen, 16 Löschungen (nur `video`-Felder).

**Nachziehen der zwei fehlenden Videos** (nach Tims Abnahme, im Worktree):

```bash
S=~/Documents/gymtavo/3D-Animationen/ki-video-serie
D=$(mktemp -d)   # besser im Scratch-Ordner
cp $S/loops/bw_swimmer.mp4 $S/loops/bw_toe_touch_jackknife.mp4 $D/
pnpm catalog:videos $D --auch-zeit          # Bericht: 2 neu
pnpm catalog:videos $D --auch-zeit --ja
pnpm --filter @fitretro/domain test
rm -rf $D
```

Beide sind Zeitübungen oder nicht, das Skript meldet es; `--auch-zeit` ist dafür nötig, falls `volume_kind` "seconds" ist. Danach committen: `feat(katalog): Uebungsvideos swimmer und toe-touch-jackknife`.
