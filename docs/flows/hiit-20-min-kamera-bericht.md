# HIIT 20 Minuten: Kamera-Zählung gegen die Übungsvideos

Stand 27.11.2026, nachgezogen nach „Flow vereinfacht“ (Abschnitt unten). Geprüft am Mac, ohne Simulator: Die Skelette der Übungsvideos laufen durch den `FlowZaehler` des Packages `Koerperbild`, so wie im Flow eine Arbeitsphase von 40 s. Test: `FlowZaehlerAbspielTests` (`apps/ios-member/Packages/Koerperbild`).

## Ablauf der Prüfung

- Skelette: `skelette-rechnen` (Apples Vision, `VNDetectHumanBodyPoseRequest`) über die Videos aus `catalog/media/videos`, abgelegt in `data/koerperbild/skelette/<key>.skelett.json`.
- Zähler: `FlowZaehler`, Start bei t = 0 ohne Bilder davor, dann das Video in Schleife, bis 40 s erreicht sind (nur ganze Durchläufe). Profil, Signal und „beginnt mit“ wie in der Tabelle unten, Seite `beide`, Tempo 1 s senken / 0 s halten / 1 s heben.
- Erwartet: Wiederholungen im Loop × Durchläufe. Bestanden, wenn die Abweichung unter 1 je Durchlauf liegt (siehe „Toleranz“).
- Wiederholungen im Loop: Jedes der geprüften Videos zeigt genau eine Wiederholung. Bestimmt unabhängig vom Zähler aus dem Verlauf des Signalwinkels (Umkehrpunkte, selbst aus den Skelettdateien gerechnet) und aus einem Kontaktbogen je Video (3 bis 4 Bilder je Sekunde), Bild für Bild angesehen.
- Erkannt: Anteil der Bilder ab Start, in denen der Zähler die Person als erkannt führt (kein Hinweis „Kamera sieht dich gerade nicht“). Skelett: Anteil der Videobilder, in denen Vision überhaupt eine Person fand.

## Ergebnis

| Schritt | Übung | Schlüssel | Profil / Signal / beginnt mit | Video | Durchläufe | Erwartet | Gezählt | Erkannt | Skelett | Ergebnis |
|---|---|---|---|---|---|---|---|---|---|---|
| 3 | Jumping Jack | `bw_jumping_jack` | oberkoerper / schulter / heben | 2,4 s | 17 | 17 | 17 | 100 % | 100 % | bestanden |
| 15 | Kniebeuge mit Bodenberührung | `bw_squat_floor_touch` | ganzkoerper_stehend / knie / senken | 3,5 s | 12 | 12 | 12 | 100 % | 100 % | bestanden |
| 7 | Squat-Pulse | `bw_squat_pulse` | ganzkoerper_stehend / knie / senken | 2,75 s | 15 | 15 | 15 | 100 % | 100 % | bestanden (Vorbehalt) |
| 12 | Liegestütz | `bw_pushup` | stuetz_boden / ellbogen / senken | 3,7 s | 11 | 11 | 11 | 100 % | 100 % | bestanden |
| 9 | Rückenstrecken – liegend | `bw_back_extension_floor` | liegend / huefte / heben | 3,2 s | 13 | 13 | 13 | 100 % | 100 % | bestanden (Vorbehalt) |
| 11 | Ausfallschritt – rückwärts | `bw_reverse_lunge` | ganzkoerper_stehend / knie / senken | 2,9 s | 14 | 14 | 14 | 100 % | 100 % | bestanden (Vorbehalt) |
| 13 | Beinheben – liegend | `bw_leg_raise_lying` | liegend / huefte / heben | 3,1 s | 13 | 13 | 12 | 100 % | 100 % | bestanden (Vorbehalt) |
| 2, 6 | Burpee | `bw_burpee_slow` | ganzkoerper_stehend / huefte / senken | 6,9 s | 6 | 6 | 12 | 100 % | 100 % | durchgefallen |
| 20 | Burpee mit Strecksprung | `bw_burpee_jump` | ganzkoerper_stehend / huefte / senken | 7,7 s | 6 | 6 | 13 | 100 % | 100 % | durchgefallen |
| 4 | Klappmesser | `bw_v_up` | – | noch keins | – | – | – | – | – | offen, Video folgt |
| 14 | Strecksprung | `bw_squat_jump` | – | noch keins | – | – | – | – | – | offen, Video folgt |

Nicht mehr im Flow (seit 27.11.2026, Stand ihrer letzten Prüfung; nicht mehr in `flow-zuordnung.json` und nicht mehr in `FlowZaehlerAbspielTests`):

| bisher Schritt | Übung | Schlüssel | Profil / Signal / beginnt mit | Video | Durchläufe | Erwartet | Gezählt | Erkannt | Skelett | Ergebnis damals |
|---|---|---|---|---|---|---|---|---|---|---|
| 11 | Ausfallschritt mit Kick | `bw_lunge_kick` | ganzkoerper_stehend / knie / senken | 7,1 s | 6 | 6 | 6 | 100 % | 100 % | bestanden (Vorbehalt) |
| 13 | Leg Drop & Pull | `bw_leg_drop_pull` | liegend / huefte / senken | 8,0 s | 5 | 5 | 0 | 7,6 % | 36,5 % | durchgefallen |

Sieben Übungen (Schritte 3, 7, 9, 11, 12, 13, 15) stehen in `data/koerperbild/flow-zuordnung.json` und bekommen im Debug-Build ein Kamera-Testprofil. Die Schritte 2, 6 und 20 laufen auf der Uhr, weil die Kamera falsch zählt; die Schritte 4 und 14 laufen auf der Uhr, bis ihre Videos da sind und geprüft wurden.

## Welcher der 20 Schritte zählt mit Kamera

| # | Schritt im Flow | Schlüssel | Arbeitsphase | Grund |
|---|---|---|---|---|
| 1 | High Kicks | `bw_high_kicks` | Uhr | abwechselnd, kein Kamera-Schritt |
| 2 | Burpee | `bw_burpee_slow` | Uhr | durchgefallen (doppelt gezählt) |
| 3 | Jumping Jacks | `bw_jumping_jack` | Kamera | bestanden |
| 4 | Klappmesser | `bw_v_up` | Uhr | offen, Video folgt |
| 5 | Mini Scissor Kicks | `bw_scissor_kicks` | Uhr | Flattern, kein Kamera-Schritt |
| 6 | Burpee | `bw_burpee_slow` | Uhr | durchgefallen (doppelt gezählt) |
| 7 | Squat-Pulse | `bw_squat_pulse` | Kamera | bestanden (Vorbehalt) |
| 8 | Plank | `bw_plank` | Uhr | Halten |
| 9 | Rückenstrecken | `bw_back_extension_floor` | Kamera | bestanden (Vorbehalt) |
| 10 | Russian Twist | `bw_russian_twist` | Uhr | Drehung, kein Gelenkwinkel |
| 11 | Ausfallschritt rückwärts | `bw_reverse_lunge` | Kamera | bestanden (Vorbehalt) |
| 12 | Liegestütze | `bw_pushup` | Kamera | bestanden |
| 13 | Beinheben | `bw_leg_raise_lying` | Kamera | bestanden (Vorbehalt) |
| 14 | Strecksprung | `bw_squat_jump` | Uhr | offen, Video folgt |
| 15 | Squat mit Händen zum Boden | `bw_squat_floor_touch` | Kamera | bestanden |
| 16 | Plank mit Knie zur Brust | `bw_mountain_climber` | Uhr | abwechselnd |
| 17 | Flutter Kicks | `bw_flutter_kicks` | Uhr | Flattern |
| 18 | Skater Jumps | `bw_skater_jump` | Uhr | abwechselnd |
| 19 | Crunch-Halten | `bw_crunch_hold` | Uhr | Halten |
| 20 | Burpees mit Streckung | `bw_burpee_jump` | Uhr | durchgefallen (doppelt gezählt) |

7 Schritte mit Kamera, 13 auf der Uhr (davon 2 offen, bis das Video da ist).

## Durchgefallen, mit Grund

- **Burpee (`bw_burpee_slow`, Schritte 2 und 6): doppelt gezählt.** Das Signal ist der Hüftwinkel (Schulter–Hüfte–Knie). In einem Burpee beugt die Hüfte zweimal tief: beim Absetzen in die Hocke (bis etwa 32°) und beim Zurückkommen aus der Stütze in die Hocke (wieder etwa 32°). Dazwischen ist die Hüfte in der Stütze gestreckt (etwa 170°), genau wie im Stand. Für den Zähler sind das zwei vollständige Wiederholungen. Das liegt an der Übung, nicht an der Erkennung (Skelett in 100 % der Bilder). Dass das Video 15 % schneller läuft als erzeugt, spielt dafür keine Rolle.
- **Burpee mit Strecksprung (`bw_burpee_jump`, Schritt 20): doppelt gezählt, dazu eine Wiederholung mehr.** Gleicher Grund wie beim Burpee; zusätzlich beugt die Hüfte bei der Landung nach dem Sprung leicht (bis etwa 136°), was über alle Durchläufe einmal mehr zählt.
- **Leg Drop & Pull (`bw_leg_drop_pull`, bis 27.11.2026 Schritt 13, nicht mehr im Flow): nichts gezählt.** Vision findet die liegende Figur nur in 36,5 % der Bilder, und in keinem Bild sind Schulter, Hüfte und Knie zugleich sicher genug (Sicherheit ab 0,3) für den Hüftwinkel. Der Zähler führt die Person nur 7,6 % der Zeit als erkannt.

Nach Vorgabe des Plans ist die Erkennung (`Koerperlage`) dafür nicht nachgeschärft worden. Ein anderes Signal (beim Burpee etwa das Knie, bei Leg Drop & Pull die Kniebeugung) wäre eine eigene Entscheidung.

## Vorbehalte bei den bestandenen

- **Squat-Pulse:** Im Video richtet sich die Figur halb auf (Kniewinkel 96° bis 153°) statt klein zu federn. Am Video zählt es deshalb richtig. Federt jemand in Wirklichkeit nur wenige Grad, liegt der Hub unter der Untergrenze von 20° und es wird nichts gezählt. Im Studio prüfen.
- **Rückenstrecken – liegend:** Der Hüftwinkel ändert sich im Video nur um etwa 22° (von etwa 175° auf 153° und zurück), knapp über der Untergrenze von 20°. Hebt jemand den Oberkörper flacher an, wird nichts gezählt. Vision sieht nur die rechte, der Kamera zugewandte Körperseite. Im Studio prüfen.
- **Ausfallschritt – rückwärts:** Das Video zeigt nur eine Seite (ein Bein geht nach hinten), von der Seite gefilmt; beide Knie beugen bis etwa 90°. Wechselt jemand die Seiten, ist das am Video nicht geprüft.
- **Beinheben – liegend:** Eine Wiederholung zu wenig (12 statt 13), innerhalb der Toleranz. Am Anfang jedes Durchlaufs (etwa 0,5 s, Beine flach am Boden) findet Vision Schulter, Hüfte und Knie nicht sicher genug; der Hüftwinkel geht von etwa 160° auf etwa 111°, obwohl die Beine im Bild fast senkrecht stehen. Warum genau eine fehlt, ist nicht weiter untersucht. Im Studio prüfen.
- **Ausfallschritt mit Kick (nicht mehr im Flow):** Im Video dreht der Oberkörper zur Kamera, und es ist nur eine Seite zu sehen (ein Ausfallschritt, ein Kick). Gezählt wird der Ausfallschritt; der Kick beugt das Knie nur um etwa 30° und zählte hier nicht mit. Wechselt jemand die Seiten, ist das am Video nicht geprüft.
- **Liegestütz:** Die linke Körperseite ist in der tiefen Position verdeckt (Ellbogenwinkel nur in 61 von 89 Bildern), die rechte Seite trägt die Zählung. Die Kamera steht im Flow vorn, das Video zeigt die Figur von der Seite.

## Toleranz

Die Planvorgabe ist „± 1 je Durchlauf“. Jedes Video zeigt genau eine Wiederholung; mit eingeschlossener Grenze ginge dann sowohl „nichts gezählt“ (Leg Drop & Pull: 0 statt 5) als auch „doppelt gezählt“ (Burpee: 12 statt 6) als bestanden durch. Der Test nimmt deshalb die Grenze selbst aus: Abweichung unter 1 je Durchlauf. Für das Ergebnis macht das keinen Unterschied bei den bestandenen Übungen; sie zählen alle genau (Abweichung 0).

## Wiederholen

    cd apps/ios-member/Packages/Koerperbild
    swift run skelette-rechnen <Ordner mit den mp4> ../../../../data/koerperbild/skelette
    swift test --filter FlowZaehlerAbspielTests

Die Testausgabe enthält je Übung eine Zeile `FlowZaehlerAbspiel <key> gezaehlt … erwartet … erkannt … Skelett …`.

## Nachtrag 27.11.2026: Flow vereinfacht

Von Tim am 27.11.2026 entschieden: eine Bewegung je Schritt (`docs/flows/hiit-20-min-uebungen.md`, „Änderung vom 27.11.2026 (Flow vereinfacht)“). Neu gegen ihre Videos geprüft, mit den Ausgangswerten aus `data/koerperbild/zuordnung.json` und Tempo 1 / 0 / 1: `bw_back_extension_floor`, `bw_reverse_lunge`, `bw_leg_raise_lying`. Alle drei bestanden und stehen in `flow-zuordnung.json`. `bw_lunge_kick` ist aus dem Flow und aus `flow-zuordnung.json` genommen; `bw_leg_drop_pull` ist ebenfalls nicht mehr im Flow. `bw_v_up` und `bw_squat_jump` haben noch kein Video und sind nicht in `flow-zuordnung.json`; sie werden geprüft, sobald Video und Skelett da sind.

Folge im Debug-Build: `KameraTestprofile.json` führt `bw_reverse_lunge` jetzt mit dem Flow-Tempo 1 / 0 / 1 statt 3 / 1 / 2 aus dem Zuordnungsvorschlag, auch außerhalb des Flows (die Flow-Zuordnung ersetzt gleiche Schlüssel, wie in Task 9 festgelegt).
