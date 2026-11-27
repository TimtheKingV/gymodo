# HIIT 20 Minuten: Übungen für den Katalog

So entsteht ein solcher Flow aus einem Video-Link: `docs/flows/flow-aus-video.md`.

Zur Durchsicht durch Tim, bevor die Übungen auf Prod gehen. Der Flow hat 20 Schritte mit 19 verschiedenen Übungen (Burpee in Schritt 2 und 6). 11 davon sind neue Katalogübungen, 8 gibt es schon. Für den Flow angelegt sind 14 neue Übungen; drei davon (`bw_lunge_kick`, `bw_leg_drop_pull`, `bw_broad_jump_touch`) sind seit dem 27.11.2026 nicht mehr im Flow und bleiben als normale Körpergewichtsübungen (siehe „Änderung vom 27.11.2026 (Flow vereinfacht)“). Alle neuen hängen am Gerätetyp „Körpergewicht“ (`bodyweight`), haben noch kein Video, keine Kameraangabe und keinen Plan-Block.

Bitte prüfen: Namen, Schlüssel und die drei Fälle unten, in denen eine neue Übung einer vorhandenen sehr nah ist.

## Die 20 Schritte

„Kamera“ heißt: Die Wiederholungen werden mit der Kamera gezählt, sobald die Zählung am Mac gegen das erzeugte Video stimmt. „Versuch“ heißt: Wir probieren es, und fällt die Zählung durch, läuft der Schritt auf der Uhr. Bei „Uhr“ zählt nur die Zeit.

| # | Schritt im Flow | Name im Katalog | Schlüssel | Neu / vorhanden | Zählung | Grund |
|---|---|---|---|---|---|---|
| 1 | High Kicks | High Kicks | `bw_high_kicks` | neu | Uhr | Beine wechseln abwechselnd, schnelles Hin und Her |
| 2 | Burpee | Burpee | `bw_burpee_slow` | neu | Kamera, Versuch | Hüfte geht deutlich hoch und runter |
| 3 | Jumping Jacks | Jumping Jack | `bw_jumping_jack` | neu | Kamera | Arme gehen klar hoch und runter, Blick von vorn |
| 4 | Klappmesser | Klappmesser | `bw_v_up` | vorhanden | Uhr | Kamera am Video durchgefallen: von vorn gefilmt, die Hüfte ist nicht zu sehen |
| 5 | Mini Scissor Kicks | Mini Scissor Kicks | `bw_scissor_kicks` | neu | Uhr | Kleines Flattern, kein klarer Gelenkwinkel |
| 6 | Burpee | Burpee | `bw_burpee_slow` | wie Schritt 2 | Kamera, Versuch | Hüfte, wie bei Schritt 2 |
| 7 | Squat-Pulse | Squat-Pulse | `bw_squat_pulse` | neu | Kamera, Versuch | Knie, aber der Hub ist sehr klein |
| 8 | Plank | Plank | `bw_plank` | vorhanden | Uhr | Halten, nichts zu zählen |
| 9 | Rückenstrecken | Rückenstrecken – liegend | `bw_back_extension_floor` | vorhanden | Kamera | Hüfte; am Boden |
| 10 | Russian Twist | Russian Twist | `bw_russian_twist` | vorhanden | Uhr | Drehung des Oberkörpers, kein Gelenkwinkel |
| 11 | Ausfallschritt rückwärts | Ausfallschritt – rückwärts | `bw_reverse_lunge` | vorhanden | Kamera | Knie |
| 12 | Liegestütze | Liegestütz | `bw_pushup` | vorhanden | Kamera, Versuch | Ellbogen; am Boden, Kamera noch ungeprüft |
| 13 | Beinheben | Beinheben – liegend | `bw_leg_raise_lying` | vorhanden | Kamera | Hüfte; am Boden |
| 14 | Strecksprung | Strecksprung | `bw_squat_jump` | neu | Kamera | Knie, am Video bestanden |
| 15 | Squat mit Händen zum Boden | Kniebeuge mit Bodenberührung | `bw_squat_floor_touch` | neu | Kamera | Knie, klare Bewegung |
| 16 | Plank mit Knie zur Brust | Mountain Climber | `bw_mountain_climber` | vorhanden | Uhr | Beine wechseln abwechselnd |
| 17 | Flutter Kicks | Flutter Kicks | `bw_flutter_kicks` | neu | Uhr | Flattern in Rückenlage |
| 18 | Skater Jumps | Skater Jump | `bw_skater_jump` | neu | Uhr | Seitlich abwechselnd |
| 19 | Crunch-Halten | Crunch-Halten | `bw_crunch_hold` | neu | Uhr | Halten |
| 20 | Burpees mit Streckung | Burpee mit Strecksprung | `bw_burpee_jump` | neu | Kamera, Versuch | Hüfte |

Die Schritt-Namen im Flow bleiben, wie sie sind (außer den Burpee-Schritten 2 und 6 und den fünf getauschten Schritten 4, 9, 11, 13 und 14, siehe Vermerke unten). Welcher Schritt heute tatsächlich mit der Kamera zählt, steht im Bericht `docs/flows/hiit-20-min-kamera-bericht.md`; die Spalte „Zählung“ ist für die nicht getauschten Schritte der ursprüngliche Vorschlag. Die Namen im Katalog dürfen davon abweichen, weil jeder Name im ganzen Katalog nur einmal vorkommen soll (eine spätere Zuordnung der Kameraangaben läuft über den Namen).

## Wiederholungen oder Sekunden

Halteübungen und Flattern zählen Sekunden (`seconds`), alle anderen Wiederholungen (`reps`).

- Sekunden: High Kicks, Mini Scissor Kicks, Flutter Kicks, Crunch-Halten.
- Wiederholungen: die übrigen 10 neuen Übungen (darunter Strecksprung).

## Nähe zu vorhandenen Übungen

Diese Übungen sind Varianten von Übungen, die es schon gibt. Ich habe sie als eigene Übungen angelegt, weil sich Bewegung und Zählweise unterscheiden. Wenn du lieber die vorhandene Übung nimmst, sag es, dann entfällt die neue.

| Neue Übung | Vorhanden | Unterschied |
|---|---|---|
| Kniebeuge mit Bodenberührung (`bw_squat_floor_touch`) | Kniebeuge (`bw_squat`) | Zusätzlich beide Hände zum Boden führen, tiefer und mit mehr Schwung |
| Crunch-Halten (`bw_crunch_hold`) | Crunch (`bw_crunch`) | Die obere Position wird gehalten (Sekunden), statt Wiederholungen zu zählen |

Weitere Namensnähe, ohne gleiche Bewegung:

- Burpee und Burpee mit Strecksprung: zwei Burpee-Varianten, die sich im Abschluss unterscheiden (ohne und mit Sprung).
- Strecksprung und Burpee mit Strecksprung: der Strecksprung ist nur der Sprung aus der Kniebeuge, ohne Stütz am Boden.
- Mini Scissor Kicks und Flutter Kicks: beide in Rückenlage mit kleinen Beinbewegungen, die eine über Kreuz, die andere auf und ab.
- Squat-Pulse und Kniebeuge mit Bodenberührung: beide aus der Kniebeuge, Pulse federt klein in der Tiefe.

Mountain Climber (Schritt 16) wird nicht neu angelegt. Im Katalog zählt er Sekunden, der Flow-Schritt „Plank mit Knie zur Brust“ nutzt ihn unverändert.

## Sichtbarkeit

Die neuen Übungen erscheinen in jedem Studio im Freien Training unter „Körpergewicht“. In Trainingspläne gelangen sie nicht, weil sie keinen Plan-Block haben. Ein Ausblenden ist nicht vorgesehen.

## Änderung vom 27.11.2026

27.11.2026: von Tim so entschieden (Videoabnahme). `bw_burpee_slow` heißt jetzt nur „Burpee“ (ohne Sprung); der Schlüssel bleibt. `bw_burpee_thigh_tap` (Burpee mit Oberschenkel-Tap) entfällt, Schritt 6 nutzt ebenfalls `bw_burpee_slow`. Damit sind es 15 neue Übungen statt 16, und die Schritte 2 und 6 teilen sich eine Übung.

## Änderung vom 27.11.2026 (Flow vereinfacht)

27.11.2026: von Tim so entschieden („Passt so“). Jeder Schritt soll genau eine klare Bewegung haben. Übungen mit mehreren Teilbewegungen (rechts/links/Mitte, Sprung mit Berührung und Drehung) sind schwer zu filmen, schwer mit der Kamera zu zählen und für den Nutzer schwer zu erfassen. Der Burpee bleibt.

Der Flow bleibt sonst gleich: 20 Schritte, je 40 s Arbeit und 20 s Pause, 3 Warm-up-Schritte, Schlüssel `hiit-20-min`, Titel „HIIT 20 Minuten“. Getauscht sind fünf Schritte:

| Schritt | bisher | neu | Name im Flow |
|---|---|---|---|
| 4 | `bw_toe_touch_jackknife` | `bw_v_up` | Klappmesser |
| 9 | `bw_swimmer` | `bw_back_extension_floor` | Rückenstrecken |
| 11 | `bw_lunge_kick` | `bw_reverse_lunge` | Ausfallschritt rückwärts |
| 13 | `bw_leg_drop_pull` | `bw_leg_raise_lying` | Beinheben |
| 14 | `bw_broad_jump_touch` | `bw_squat_jump` (neu) | Strecksprung |

Im Katalog:

- Neu: `bw_squat_jump` „Strecksprung“ am Gerätetyp „Körpergewicht“, Wiederholungen, ohne Plan-Block, ohne Kameraangabe, noch ohne Video.
- Entfernt: `bw_toe_touch_jackknife` (Toe Touch mit Jackknife) und `bw_swimmer` (Swimmer); beide hatten kein Video.
- `bw_lunge_kick`, `bw_leg_drop_pull` und `bw_broad_jump_touch` bleiben mit ihren Videos als normale Körpergewichtsübungen.
- `bw_v_up` bleibt, wie er ist; das Video kommt später, ebenso das für `bw_squat_jump`.

Damit sind 14 Übungen für den Flow angelegt (vorher 15), von denen 11 im Flow vorkommen.

## Nachtrag 27.11.2026: Videos für Klappmesser und Strecksprung

Von Tim am 27.11.2026 abgenommen und in den Katalog übernommen (`catalog/media/videos/bw_v_up.mp4`, `bw_squat_jump.mp4`, je 3 s). Strecksprung zählt mit der Kamera, Klappmesser läuft auf der Uhr (Grund im Kamera-Bericht).
