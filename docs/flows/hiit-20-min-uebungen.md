# HIIT 20 Minuten: Übungen für den Katalog

Zur Durchsicht durch Tim, bevor die Übungen auf Prod gehen. Der Flow hat 20 Schritte. 15 davon sind neue Katalogübungen, 4 gibt es schon. Alle neuen hängen am Gerätetyp „Körpergewicht“ (`bodyweight`), haben noch kein Video, keine Kameraangabe und keinen Plan-Block.

Bitte prüfen: Namen, Schlüssel und die drei Fälle unten, in denen eine neue Übung einer vorhandenen sehr nah ist.

## Die 20 Schritte

„Kamera“ heißt: Die Wiederholungen werden mit der Kamera gezählt, sobald die Zählung am Mac gegen das erzeugte Video stimmt. „Versuch“ heißt: Wir probieren es, und fällt die Zählung durch, läuft der Schritt auf der Uhr. Bei „Uhr“ zählt nur die Zeit.

| # | Schritt im Flow | Name im Katalog | Schlüssel | Neu / vorhanden | Zählung | Grund |
|---|---|---|---|---|---|---|
| 1 | High Kicks | High Kicks | `bw_high_kicks` | neu | Uhr | Beine wechseln abwechselnd, schnelles Hin und Her |
| 2 | Burpee | Burpee | `bw_burpee_slow` | neu | Kamera, Versuch | Hüfte geht deutlich hoch und runter |
| 3 | Jumping Jacks | Jumping Jack | `bw_jumping_jack` | neu | Kamera | Arme gehen klar hoch und runter, Blick von vorn |
| 4 | Toe Touches + Jackknifes | Toe Touch mit Jackknife | `bw_toe_touch_jackknife` | neu | Uhr | Zwei Bewegungen im Wechsel |
| 5 | Mini Scissor Kicks | Mini Scissor Kicks | `bw_scissor_kicks` | neu | Uhr | Kleines Flattern, kein klarer Gelenkwinkel |
| 6 | Burpee | Burpee | `bw_burpee_slow` | wie Schritt 2 | Kamera, Versuch | Hüfte, wie bei Schritt 2 |
| 7 | Squat-Pulse | Squat-Pulse | `bw_squat_pulse` | neu | Kamera, Versuch | Knie, aber der Hub ist sehr klein |
| 8 | Plank | Plank | `bw_plank` | vorhanden | Uhr | Halten, nichts zu zählen |
| 9 | Swimmer | Swimmer | `bw_swimmer` | neu | Uhr | Flattern in Bauchlage |
| 10 | Russian Twist | Russian Twist | `bw_russian_twist` | vorhanden | Uhr | Drehung des Oberkörpers, kein Gelenkwinkel |
| 11 | Lunge + Kick | Ausfallschritt mit Kick | `bw_lunge_kick` | neu | Kamera, Versuch | Knie |
| 12 | Liegestütze | Liegestütz | `bw_pushup` | vorhanden | Kamera, Versuch | Ellbogen; am Boden, Kamera noch ungeprüft |
| 13 | Leg Drop & Pull | Leg Drop & Pull | `bw_leg_drop_pull` | neu | Kamera, Versuch | Hüfte; am Boden, Kamera noch ungeprüft |
| 14 | Weitsprung mit Bodenberührung | Weitsprung mit Bodenberührung | `bw_broad_jump_touch` | neu | Uhr | Man springt aus dem Bild |
| 15 | Squat mit Händen zum Boden | Kniebeuge mit Bodenberührung | `bw_squat_floor_touch` | neu | Kamera | Knie, klare Bewegung |
| 16 | Plank mit Knie zur Brust | Mountain Climber | `bw_mountain_climber` | vorhanden | Uhr | Beine wechseln abwechselnd |
| 17 | Flutter Kicks | Flutter Kicks | `bw_flutter_kicks` | neu | Uhr | Flattern in Rückenlage |
| 18 | Skater Jumps | Skater Jump | `bw_skater_jump` | neu | Uhr | Seitlich abwechselnd |
| 19 | Crunch-Halten | Crunch-Halten | `bw_crunch_hold` | neu | Uhr | Halten |
| 20 | Burpees mit Streckung | Burpee mit Strecksprung | `bw_burpee_jump` | neu | Kamera, Versuch | Hüfte |

Die Schritt-Namen im Flow bleiben, wie sie sind (außer den Burpee-Schritten 2 und 6, siehe Vermerk unten). Die Namen im Katalog dürfen davon abweichen, weil jeder Name im ganzen Katalog nur einmal vorkommen soll (eine spätere Zuordnung der Kameraangaben läuft über den Namen).

## Wiederholungen oder Sekunden

Halteübungen und Flattern zählen Sekunden (`seconds`), alle anderen Wiederholungen (`reps`).

- Sekunden: High Kicks, Mini Scissor Kicks, Swimmer, Flutter Kicks, Crunch-Halten.
- Wiederholungen: die übrigen 10 neuen Übungen.

## Nähe zu vorhandenen Übungen

Diese drei neuen Übungen sind Varianten von Übungen, die es schon gibt. Ich habe sie als eigene Übungen angelegt, weil sich Bewegung und Zählweise unterscheiden. Wenn du lieber die vorhandene Übung nimmst, sag es, dann entfällt die neue.

| Neue Übung | Vorhanden | Unterschied |
|---|---|---|
| Toe Touch mit Jackknife (`bw_toe_touch_jackknife`) | Klappmesser (`bw_v_up`) | Zusätzlich im Wechsel mit den Händen die Zehen berühren, nicht nur zusammenklappen |
| Kniebeuge mit Bodenberührung (`bw_squat_floor_touch`) | Kniebeuge (`bw_squat`) | Zusätzlich beide Hände zum Boden führen, tiefer und mit mehr Schwung |
| Crunch-Halten (`bw_crunch_hold`) | Crunch (`bw_crunch`) | Die obere Position wird gehalten (Sekunden), statt Wiederholungen zu zählen |

Weitere Namensnähe, ohne gleiche Bewegung:

- Burpee und Burpee mit Strecksprung: zwei Burpee-Varianten, die sich im Abschluss unterscheiden (ohne und mit Sprung).
- Mini Scissor Kicks und Flutter Kicks: beide in Rückenlage mit kleinen Beinbewegungen, die eine über Kreuz, die andere auf und ab.
- Squat-Pulse und Kniebeuge mit Bodenberührung: beide aus der Kniebeuge, Pulse federt klein in der Tiefe.

Mountain Climber (Schritt 16) wird nicht neu angelegt. Im Katalog zählt er Sekunden, der Flow-Schritt „Plank mit Knie zur Brust“ nutzt ihn unverändert.

## Sichtbarkeit

Die neuen Übungen erscheinen in jedem Studio im Freien Training unter „Körpergewicht“. In Trainingspläne gelangen sie nicht, weil sie keinen Plan-Block haben. Ein Ausblenden ist nicht vorgesehen.

## Änderung vom 27.11.2026

27.11.2026: von Tim so entschieden (Videoabnahme). `bw_burpee_slow` heißt jetzt nur „Burpee“ (ohne Sprung); der Schlüssel bleibt. `bw_burpee_thigh_tap` (Burpee mit Oberschenkel-Tap) entfällt, Schritt 6 nutzt ebenfalls `bw_burpee_slow`. Damit sind es 15 neue Übungen statt 16, und die Schritte 2 und 6 teilen sich eine Übung.
