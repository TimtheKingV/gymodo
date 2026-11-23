# Tempobericht Lageschätzung

Erzeugt von `TempoBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
Stand: Aufnahmen bis 2026-11-10. Live-Lauf des `Lageschaetzer` ohne gemerkten Umfang gegen die nachträgliche Rechnung aus `tools/sensorik-sim/tempo_nachrechnung.py` (je Halbwelle auf 0…1 normiert), im aktiven Teil des Satzes.
Auswahl: Stapel, Kurz- und Langhantel, `repsWahr` ≥ 5, ohne Lücke, ≥ 300 Messwerte.
Tor je Art (Tempo-Spec 6.4): Verzögerung im Median ≤ 150 ms, Abweichung im Median ≤ 0.15 des Hubs, kein Satz länger als eine Wiederholung außerhalb −0,25…1,25. „sicher“ (Median des Anteils sicherer Messwerte) zählt nicht zum Tor.

| Art | Sätze | Verzögerung (Median) | Abweichung (Median) | außerhalb | sicher (Median) | Tor erreicht |
|---|---|---|---|---|---|---|
| stapel | 58 | 20 ms | 0.280 | 17 | 72 % | nein |
| kurzhantel | 83 | -40 ms | 0.596 | 38 | 26 % | nein |
| langhantel | 17 | 0 ms | 48.826 | 13 | 92 % | nein |

## stapel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-10-18-1708-01 | 0 ms | 16.485 | ja | 86 % |
| 2026-10-14-1759-01 | 100 ms | 16.176 | ja | 58 % |
| 2026-10-18-1648-01 | 0 ms | 5.679 | ja | 83 % |
| 2026-10-14-1838-01 | -220 ms | 5.357 | ja | 76 % |
| 2026-10-14-1749-01 | 300 ms | 3.883 | ja | 49 % |
| 2026-10-14-1758-01 | 40 ms | 2.753 | ja | 47 % |
| 2026-10-14-1812-01 | 80 ms | 2.583 | ja | 40 % |
| 2026-10-26-1729-01 | 60 ms | 2.405 | ja | 73 % |
| 2026-10-18-1642-01 | 40 ms | 1.472 | ja | 73 % |
| 2026-10-26-1813-02 | 40 ms | 1.186 | ja | 80 % |

## kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-11-03-1807-01 | -300 ms | 2784.935 | ja | 100 % |
| 2026-10-26-1747-04 | 0 ms | 1565.758 | ja | 100 % |
| 2026-10-26-1745-02 | 880 ms | 497.132 | ja | 100 % |
| 2026-10-18-1611-02 | 400 ms | 426.599 | ja | 100 % |
| 2026-11-03-1804-01 | 400 ms | 297.084 | ja | 78 % |
| 2026-11-03-1800-01 | -360 ms | 269.409 | ja | 100 % |
| 2026-11-03-1805-02 | 400 ms | 231.907 | ja | 72 % |
| 2026-11-03-1808-01 | 360 ms | 223.512 | ja | 98 % |
| 2026-10-18-1608-01 | -300 ms | 197.936 | ja | 100 % |
| 2026-11-10-1824-01 | -400 ms | 180.711 | ja | 100 % |

## langhantel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-10-26-1816-01 | 400 ms | 4733.742 | ja | 100 % |
| 2026-10-14-1832-01 | 880 ms | 4393.390 | ja | 100 % |
| 2026-10-14-1830-01 | 460 ms | 1334.818 | ja | 100 % |
| 2026-10-26-1821-02 | 340 ms | 1020.904 | ja | 100 % |
| 2026-10-18-1658-03 | -920 ms | 896.837 | ja | 100 % |
| 2026-10-26-1818-02 | -220 ms | 345.790 | ja | 94 % |
| 2026-10-18-1702-01 | 280 ms | 253.575 | ja | 100 % |
| 2026-10-18-1654-01 | -980 ms | 229.144 | – | 100 % |
| 2026-10-18-1619-01 | -400 ms | 48.826 | ja | 60 % |
| 2026-10-08-0836-01 | 0 ms | 29.198 | ja | 81 % |
