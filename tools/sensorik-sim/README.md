# Sensorik-Simulator (Python)

Werkzeug zum Abstimmen der Satzauswertung (`Satztakt`) ohne neue Aufnahmen. Standardbibliothek reicht.

- `lib.py` – Aufnahmen laden (nur `2026-10-16-*`), Signalkanäle (`pca`, `ay`, `grav`), Takt und die zwei Zähler (`huelle`, `gipfel`).
- `sim.py` – baut aus sauberen echten Sätzen künstliche Sätze mit bekannter Zahl: ganze Wiederholungen aus einem Satz, Tempo und Ausschlag je Satz verändert, echtes Aufheben und Ablegen davor und danach.
- `ev2.py [N]` – vergleicht alle Verfahren auf N simulierten Sätzen je Übungsart und auf den echten Sätzen; Vorlagen aus Block A (morgens) werden gegen die echten Sätze von Block B (mittags) geprüft und umgekehrt.
- `cmp.py` – Genauigkeit simuliert gegen echt je Verfahren und Korrelation.

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
