# Sensorik-Simulator (Python)

Werkzeug zum Abstimmen der Satzauswertung (`Satztakt`) ohne neue Aufnahmen. Standardbibliothek reicht.

- `lib.py` – Aufnahmen laden (nur `2026-10-16-*`), Signalkanäle (`pca`, `ay`, `grav`), Takt und die zwei Zähler (`huelle`, `gipfel`).
- `sim.py` – baut aus sauberen echten Sätzen künstliche Sätze mit bekannter Zahl: ganze Wiederholungen aus einem Satz, Tempo und Ausschlag je Satz verändert, echtes Aufheben und Ablegen davor und danach.
- `ev2.py [N]` – vergleicht alle Verfahren auf N simulierten Sätzen je Übungsart und auf den echten Sätzen; Vorlagen aus Block A (morgens) werden gegen die echten Sätze von Block B (mittags) geprüft und umgekehrt.
- `cmp.py` – Genauigkeit simuliert gegen echt je Verfahren und Korrelation.

- `eintragen.py <Tag> <csv>` – trägt die Aufnahmen eines Tages mit Wahrheit aus einer CSV (`set_id`, `reps_wahr`) in `data/sensoraufnahmen/korrekturen.json` ein.
- `marken.py` – lädt Sätze samt `# marke`-Zeilen; `rand.py` – Kappen von Ausreißern (Aufheben/Ablegen) vor Takt und Hüllkurve; `rand2.py` – Gegenprobe: Rand aus der Aktivität, Takt nur im Randfenster.

Aufruf: `cd tools/sensorik-sim && python3 ev2.py 40 && python3 cmp.py`

## Stand 16.10. (27 Sätze, nur Aufnahmen vom 16.10.)

- Simulation und echte Sätze stimmen für die Hüllkurven-Zählung gut überein (simuliert 54 %, echt 56 % exakt bei gleicher Streuung wie in der Standardeinstellung von früher). Die Gipfelzählung wird in der Simulation zu gut bewertet.
- Curl und Seitheben: Hauptachse (`pca`) mit Hüllkurve ist an beiden Blöcken am besten.
- Trizeps und Schulterdrücken: kein Verfahren überzeugt auf echten Sätzen; die Simulation trennt die Verfahren hier nicht belastbar.
- Grenze: alle Vorlagen kommen von einem Tag und einer Person. Die Zuschläge stimmen nur dafür.

## Stand 16.10. nachmittags (35 Sätze, 8 neue mit Marken)

- Marken sind menschliche Zeiten (Knopf gedrückt, nicht Bewegung): Start 1–3 s vor, Ende bis 3 s nach der Bewegung. Gut für die Größenordnung des Rands, nicht als Sekundenwahrheit. Satz 1325-03 hat kein `satzende`.
- Schulterdrücken scheiterte an zwei Dingen: Aufheben/Ablegen sind stärker als die Wiederholungen (die Hüllkurve liegt am Ablegen), und der Takt wird verdoppelt (3,1–3,4 s statt 1,6 s). Innerhalb der Marken ist der Takt eindeutig (Korrelation 0,75–0,97).
- Übernommen in `Satztakt`: Signal auf das 1,5-fache des typischen Sekunden-Effektivwerts kappen, Takt höchstens 3 s. Alt (27 Sätze) 15 → 17 exakt, ±1 unverändert 24; neu (8 Sätze) 3 → 6 exakt, ±1 5 → 8. Stabil für Kappfaktor 1,2–1,5 und Taktgrenze 2,6–3,0; ab Kappfaktor 1,6 kippt es.
- Nicht klar besser: Rand aus der Aktivität mit Takt nur im Fenster (`rand2.py`): 16/27 alt, 5/8 neu bei der besten Einstellung aus einem Gitter von 240 Kombinationen, also eher angepasst.
- Offen: Schulterdrücken morgens (0943-02 und 0945-01 je 12 statt 10, 0944-01 8 richtig; 1149-03 7 statt 5) zählt teils zu viel. Die neuen Sätze wurden beim Suchen der Ursache angesehen, sind also keine saubere Prüfmenge.

## Stand 16.10. später Nachmittag: Rand aus der Kette (`kette.py`)

- Statt einer Schwelle auf der Hüllkurve: Abschnitte einer Taktlänge, jeder dem Vorgänger nach Form und Größe gleich (`2<a,b>/(|a|²+|b|²)`, ohne Mittelwert), nächster Abschnitt 0,75–1,3 Takte weiter, Startpunkte im Vierteltakt-Raster. Gezählt wird die längste Kette.
- Normierte Korrelation allein reicht nicht: Das Ausklingen nach dem Ablegen gleicht in der Form (0,8–0,86) und hängt 2–4 Abschnitte an. Erst das Größenmaß schneidet es ab.
- Erste Wiederholung: Die Kette beginnt 0,1–0,5 s nach der Marke `satzbeginn`, die erste Wiederholung ist also schon drin. Kette + 1 trifft 1/8.
- Abgestimmt an Block A + B (27 Sätze): Schwelle (1 Wert, aus 12 probiert), Wahl des Größenmaßes nach dem ersten Lauf, +0/+1. Fest ohne Abstimmen: Abstand 0,75–1,3, Raster ¼ Takt; übernommen: Kappen 1,5 und Takt ≤ 3 s (bei deren Wahl waren die 13-Uhr-Sätze schon angesehen). Schwelle 0,88–0,93 gleich gut, gewählt 0,9.
- Ergebnis in Swift (`kurzhantel/takt2`): Abstimmung 17 → 21 exakt, ±1 24 → 27; Prüfung (13 Uhr, einmal gelaufen) 6 → 7 exakt, ±1 8 → 8. Python liefert dieselben Summen, einzelne Sätze unterscheiden sich wegen des Tiefpasses.
- Schwächer als vorher: kurze Sätze, bei denen die erste Wiederholung der zweiten zu wenig gleicht (1147-03, 1148-01, 1149-02, 1149-04: je eine zu wenig). Weiter falsch: 1324-02 (8 statt 9), Trizeps 1146-02 und 1147-01 (8 statt 7).
- Hinweis: `rand.py` sucht den Takt bis 4 s, Swift bis 3 s; die Baseline in `rand.py` ist daher für Schulterdrücken schlechter als die App (13 Uhr 5/8 statt 6/8).

## Rennen der Zähler (`rennen.py`), Festlegung vor der Blindprüfung

Entwicklung an den 35 Sätzen vom 16.10. (Signal wie Swift, Tiefpass 3 Hz). Probiert (gesamt ca. 35 Einstellungen gegen 35 Sätze):
Kette mit Randschwelle beidseitig/vorn (0,7–0,85), mit Vorlage, mit flexibler Länge (±5–15 %); Phase (Anteil 0,35–0,7 × Breite 0,3/0,5);
Motiv (Matrix-Profil, Schwelle 0,6–0,9); Gipfel mit Hysterese (0,4–1,2).

| Zähler | exakt | ±1 | zu viel | zu wenig |
|---|---|---|---|---|
| kette (Swift takt2) | 28/35 | 35 | 2 | 5 |
| phase (Anteil 0,6, Breite 0,3) | 26/35 | 31 | 5 | 4 |
| motiv (0,8) | 20/35 | 32 | 9 | 6 |
| takt1 (alt) | 23/35 | 32 | 6 | 6 |

Keine Ketten-Variante schlägt die einfache Kette. Paar „Kette & Phase einig → zeigen, sonst nachfragen“: 21 richtig gezeigt, 1 still falsch, 13 Nachfragen; bei Uneinigkeit liegt die Wahrheit in 12 von 13 Fällen bei einer der beiden Zahlen.

**Festgelegt für die Blindprüfung** (`data/sensoraufnahmen-blind`, 12 Sätze mit Wahrheit vom 16.10. 14:20–14:25): Kandidaten `kette`, `phase(0,6/0,3)`, `motiv(0,8)`, `takt1`, und das Paar Kette & Phase. Nichts wird danach nachgestellt.

**Ergebnis Blindprüfung** (einmal gelaufen, 11 Sätze; 1421-03 mit Wahrheit 1 verworfen, alle Zähler sagten 8 – vermutlich Eingabefehler):

| Zähler | exakt (ohne 1421-03) | ±1 |
|---|---|---|
| kette | 10/11 | 11/11 |
| takt1 (alt) | 8/11 | 10/11 |
| phase | 7/11 | 10/11 |
| motiv | 7/11 | 9/11 |

Einziger Ketten-Fehler: 1425-02 Schulterdrücken 9 statt 10, die Phase sagt ebenfalls 9. Das Paar Kette & Phase fängt ihn also nicht und fragt bei 3 von 11 Sätzen nach, obwohl die Kette dort jedes Mal recht hatte. Folgerung: Kette allein live, Phase als Zweitzähler bringt auf diesen Daten nichts.

**Zweite Blindrunde** (14:32–14:34, 5 Sätze: 3 × Schulterdrücken, 3 × Goblet Squat, eine Übung ohne jede Abstimmung; 1433-01 mit Wahrheit 1 verworfen): Kette 5/5 exakt, Phase 2/5, alt 2/5. Die App zählte live dieselben Zahlen wie der Simulator.
Über beide Runden: Kette 15/16 exakt, 16/16 auf ±1; alt 10/16. Die Sätze liegen jetzt in `data/sensoraufnahmen` und sind damit keine Prüfmenge mehr.
Offen: Zwei Korrekturen in der App ergaben Wahrheit 1 (1421-03, 1433-01), Ursache unklar (Bedienfehler oder Korrektur-Dialog).
