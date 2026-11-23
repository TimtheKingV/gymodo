# Tempobericht Lageschätzung

Erzeugt von `TempoBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
Stand: Aufnahmen bis 2026-11-10. Live-Lauf des `Lageschaetzer` ohne gemerkten Umfang gegen die nachträgliche Rechnung aus `tools/sensorik-sim/tempo_nachrechnung.py` (je Halbwelle auf 0…1 normiert), im aktiven Teil des Satzes.
Auswahl: Stapel, Kurz- und Langhantel, `repsWahr` ≥ 5, ohne Lücke, ≥ 300 Messwerte.
Tor je Art (Tempo-Spec 6.4): Verzögerung im Median ≤ 150 ms, Abweichung im Median ≤ 0.15 des Hubs, kein Satz länger als eine Wiederholung außerhalb −0,25…1,25. „sicher“ (Median des Anteils sicherer Messwerte) zählt nicht zum Tor.

| Art | Sätze | Verzögerung (Median) | Abweichung (Median) | außerhalb | sicher (Median) | Tor erreicht |
|---|---|---|---|---|---|---|
| stapel | 58 | -360 ms | 31.239 | 52 | 90 % | nein |
| kurzhantel | 83 | 0 ms | 50.432 | 65 | 76 % | nein |
| langhantel | 17 | 360 ms | 78.351 | 16 | 99 % | nein |

## stapel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-10-14-1759-01 | -440 ms | 1784.509 | ja | 85 % |
| 2026-10-14-1753-01 | -560 ms | 1498.153 | ja | 79 % |
| 2026-10-14-1840-01 | -560 ms | 1290.252 | ja | 89 % |
| 2026-10-14-1801-01 | -520 ms | 1180.636 | ja | 98 % |
| 2026-10-18-1708-01 | 1000 ms | 895.285 | ja | 94 % |
| 2026-10-18-1709-01 | 1000 ms | 736.366 | ja | 80 % |
| 2026-10-26-1731-01 | 0 ms | 642.243 | ja | 82 % |
| 2026-10-14-1814-01 | -540 ms | 517.143 | ja | 96 % |
| 2026-11-03-1825-01 | -420 ms | 395.024 | ja | 77 % |
| 2026-11-03-1824-01 | -400 ms | 366.830 | ja | 94 % |

## kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-11-03-1808-01 | 920 ms | 25288.726 | ja | 91 % |
| 2026-11-03-1801-01 | 580 ms | 8867.781 | ja | 90 % |
| 2026-10-18-1613-03 | 620 ms | 4946.168 | ja | 88 % |
| 2026-10-14-1818-01 | 680 ms | 4145.861 | ja | 92 % |
| 2026-11-10-1820-01 | 1000 ms | 1758.793 | ja | 78 % |
| 2026-10-18-1606-02 | 340 ms | 1394.947 | ja | 85 % |
| 2026-11-03-1807-01 | 400 ms | 1272.921 | ja | 100 % |
| 2026-10-16-1324-02 | -280 ms | 1230.955 | ja | 97 % |
| 2026-10-26-1744-02 | -360 ms | 1143.776 | ja | 92 % |
| 2026-11-10-1825-04 | -380 ms | 1046.190 | ja | 37 % |

## langhantel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-10-18-1704-01 | -220 ms | 5764.040 | ja | 99 % |
| 2026-10-18-1658-03 | 920 ms | 1275.594 | ja | 100 % |
| 2026-10-18-1654-01 | 980 ms | 737.368 | – | 100 % |
| 2026-10-14-1830-01 | 460 ms | 291.165 | ja | 100 % |
| 2026-10-18-1656-02 | 380 ms | 238.674 | ja | 98 % |
| 2026-10-08-0836-01 | 1000 ms | 196.564 | ja | 97 % |
| 2026-10-18-1700-02 | 260 ms | 196.259 | ja | 79 % |
| 2026-10-18-1621-01 | -540 ms | 170.835 | ja | 98 % |
| 2026-10-18-1702-01 | -480 ms | 78.351 | ja | 100 % |
| 2026-10-18-1623-01 | -300 ms | 30.571 | ja | 78 % |
