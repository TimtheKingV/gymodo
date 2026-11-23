# Tempobericht Lageschätzung

Erzeugt von `TempoBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
Stand: Aufnahmen bis 2026-11-10. Live-Lauf des `Lageschaetzer` ohne gemerkten Umfang gegen die nachträgliche Rechnung aus `tools/sensorik-sim/tempo_nachrechnung.py` (je Halbwelle auf 0…1 normiert), im aktiven Teil des Satzes.
Auswahl: Stapel, Kurz- und Langhantel, `repsWahr` ≥ 5, ohne Lücke, ≥ 300 Messwerte.
Tor je Art (Tempo-Spec 6.4): Verzögerung im Median ≤ 150 ms, Abweichung im Median ≤ 0.15 des Hubs, kein Satz länger als eine Wiederholung außerhalb −0,25…1,25. „sicher“ (Median des Anteils sicherer Messwerte) zählt nicht zum Tor.

| Art | Sätze | Verzögerung (Median) | Abweichung (Median) | außerhalb | sicher (Median) | Tor erreicht |
|---|---|---|---|---|---|---|
| stapel | 58 | -40 ms | 0.153 | 0 | 41 % | nein |
| kurzhantel | 83 | -160 ms | 0.426 | 0 | 0 % | nein |
| langhantel | 17 | -60 ms | 0.395 | 0 | 1 % | nein |

## stapel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-11-03-1815-01 | -260 ms | 0.566 | – | 23 % |
| 2026-10-26-1813-02 | -300 ms | 0.460 | – | 55 % |
| 2026-11-03-1825-01 | -180 ms | 0.455 | – | 1 % |
| 2026-10-18-1649-02 | -380 ms | 0.442 | – | 83 % |
| 2026-10-14-1810-01 | -120 ms | 0.399 | – | 29 % |
| 2026-11-03-1821-01 | -160 ms | 0.398 | – | 32 % |
| 2026-10-18-1709-01 | 40 ms | 0.394 | – | 38 % |
| 2026-10-18-1642-01 | -20 ms | 0.360 | – | 43 % |
| 2026-11-03-1813-01 | -20 ms | 0.328 | – | 46 % |
| 2026-10-26-1808-01 | -40 ms | 0.300 | – | 7 % |

## kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-11-03-1800-01 | -400 ms | 0.778 | – | 0 % |
| 2026-11-10-1824-01 | 400 ms | 0.729 | – | 0 % |
| 2026-11-03-1807-01 | -400 ms | 0.720 | – | 0 % |
| 2026-10-18-1611-02 | 0 ms | 0.627 | – | 0 % |
| 2026-10-18-1608-01 | 0 ms | 0.595 | – | 0 % |
| 2026-10-16-0943-02 | -540 ms | 0.584 | – | 6 % |
| 2026-11-10-1830-03 | -100 ms | 0.580 | – | 13 % |
| 2026-10-16-1149-02 | -200 ms | 0.564 | – | 13 % |
| 2026-10-26-1747-04 | -160 ms | 0.551 | – | 0 % |
| 2026-10-16-1327-04 | -620 ms | 0.545 | – | 5 % |

## langhantel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-10-26-1818-02 | 740 ms | 0.556 | – | 12 % |
| 2026-10-18-1702-01 | 0 ms | 0.541 | – | 0 % |
| 2026-10-18-1658-03 | -920 ms | 0.539 | – | 0 % |
| 2026-10-18-1619-01 | -880 ms | 0.536 | – | 2 % |
| 2026-10-08-0837-01 | -200 ms | 0.485 | – | 0 % |
| 2026-10-08-0836-01 | -500 ms | 0.411 | – | 12 % |
| 2026-10-26-1820-02 | -160 ms | 0.408 | – | 1 % |
| 2026-10-18-1654-01 | 500 ms | 0.403 | – | 0 % |
| 2026-10-26-1821-02 | 0 ms | 0.395 | – | 0 % |
| 2026-10-18-1621-01 | -300 ms | 0.393 | – | 19 % |
