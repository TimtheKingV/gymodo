# Tempobericht Lageschätzung

Erzeugt von `TempoBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
Stand: Aufnahmen bis 2026-11-10. Live-Lauf des `Lageschaetzer` ohne gemerkten Umfang gegen die nachträgliche Rechnung aus `tools/sensorik-sim/tempo_nachrechnung.py` (je Halbwelle auf 0…1 normiert), im aktiven Teil des Satzes.
Auswahl: Stapel, Kurz- und Langhantel, `repsWahr` ≥ 5, ohne Lücke, ≥ 300 Messwerte.
Tor je Art (Tempo-Spec 6.4): Verzögerung im Median ≤ 150 ms, Abweichung im Median ≤ 0.15 des Hubs, kein Satz länger als eine Wiederholung außerhalb −0,25…1,25. „sicher“ (Median des Anteils sicherer Messwerte) zählt nicht zum Tor.

| Art | Sätze | Verzögerung (Median) | Abweichung (Median) | außerhalb | sicher (Median) | Tor erreicht |
|---|---|---|---|---|---|---|
| stapel | 58 | -20 ms | 0.237 | 0 | 43 % | nein |
| kurzhantel | 83 | -100 ms | 0.400 | 0 | 0 % | nein |
| langhantel | 17 | -60 ms | 0.406 | 0 | 1 % | nein |

## stapel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-10-18-1646-01 | -20 ms | 0.451 | – | 4 % |
| 2026-10-18-1649-02 | -500 ms | 0.446 | – | 83 % |
| 2026-10-26-1809-02 | -240 ms | 0.433 | – | 37 % |
| 2026-10-18-1645-01 | 0 ms | 0.430 | – | 0 % |
| 2026-10-18-1648-01 | -20 ms | 0.409 | – | 19 % |
| 2026-10-26-1735-01 | 0 ms | 0.402 | – | 20 % |
| 2026-10-14-1810-01 | -60 ms | 0.402 | – | 29 % |
| 2026-10-26-1810-02 | -80 ms | 0.394 | – | 11 % |
| 2026-10-26-1808-01 | -120 ms | 0.389 | – | 7 % |
| 2026-10-14-1838-01 | -320 ms | 0.378 | – | 6 % |

## kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-11-03-1800-01 | 0 ms | 0.836 | – | 0 % |
| 2026-11-03-1807-01 | 0 ms | 0.833 | – | 0 % |
| 2026-11-10-1824-01 | 0 ms | 0.700 | – | 0 % |
| 2026-10-18-1611-02 | 0 ms | 0.627 | – | 0 % |
| 2026-10-16-0942-03 | 500 ms | 0.596 | – | 0 % |
| 2026-10-18-1608-01 | 0 ms | 0.595 | – | 0 % |
| 2026-10-16-0938-02 | -900 ms | 0.585 | – | 10 % |
| 2026-11-03-1805-02 | 400 ms | 0.580 | – | 2 % |
| 2026-10-16-0941-01 | 140 ms | 0.558 | – | 0 % |
| 2026-10-26-1747-04 | -140 ms | 0.552 | – | 0 % |

## langhantel: die zehn schlechtesten Sätze

| Aufnahme | Verzögerung | Abweichung | außerhalb | sicher |
|---|---|---|---|---|
| 2026-10-18-1702-01 | 0 ms | 0.541 | – | 0 % |
| 2026-10-18-1658-03 | 0 ms | 0.505 | – | 0 % |
| 2026-10-26-1818-02 | -300 ms | 0.491 | – | 12 % |
| 2026-10-18-1654-01 | 40 ms | 0.443 | – | 0 % |
| 2026-10-26-1820-02 | -1000 ms | 0.437 | – | 1 % |
| 2026-10-18-1619-01 | -540 ms | 0.422 | – | 2 % |
| 2026-10-18-1621-01 | -120 ms | 0.414 | – | 19 % |
| 2026-10-08-0836-01 | -180 ms | 0.411 | – | 12 % |
| 2026-10-08-0837-01 | -400 ms | 0.406 | – | 0 % |
| 2026-10-26-1821-02 | 0 ms | 0.395 | – | 0 % |
