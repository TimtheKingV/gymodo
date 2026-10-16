# Sensorik-Simulator (Python)

Werkzeug zum Abstimmen der Satzauswertung (`Satztakt`) ohne neue Aufnahmen. Standardbibliothek reicht.

- `lib.py` – Aufnahmen laden (nur `2026-10-16-*`), Signalkanäle (`pca`, `ay`, `grav`), Takt und die zwei Zähler (`huelle`, `gipfel`).
- `sim.py` – baut aus sauberen echten Sätzen künstliche Sätze mit bekannter Zahl: ganze Wiederholungen aus einem Satz, Tempo und Ausschlag je Satz verändert, echtes Aufheben und Ablegen davor und danach.
- `ev2.py [N]` – vergleicht alle Verfahren auf N simulierten Sätzen je Übungsart und auf den echten Sätzen; Vorlagen aus Block A (morgens) werden gegen die echten Sätze von Block B (mittags) geprüft und umgekehrt.
- `cmp.py` – Genauigkeit simuliert gegen echt je Verfahren und Korrelation.

Aufruf: `cd tools/sensorik-sim && python3 ev2.py 40 && python3 cmp.py`

## Stand 16.10. (27 Sätze, nur Aufnahmen vom 16.10.)

- Simulation und echte Sätze stimmen für die Hüllkurven-Zählung gut überein (simuliert 54 %, echt 56 % exakt bei gleicher Streuung wie in der Standardeinstellung von früher). Die Gipfelzählung wird in der Simulation zu gut bewertet.
- Curl und Seitheben: Hauptachse (`pca`) mit Hüllkurve ist an beiden Blöcken am besten.
- Trizeps und Schulterdrücken: kein Verfahren überzeugt auf echten Sätzen; die Simulation trennt die Verfahren hier nicht belastbar.
- Grenze: alle Vorlagen kommen von einem Tag und einer Person. Die Zuschläge stimmen nur dafür.
