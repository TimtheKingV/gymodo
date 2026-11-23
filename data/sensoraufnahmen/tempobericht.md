# Tempobericht Lageschätzung

Erzeugt von `TempoBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
Stand: Aufnahmen bis 2026-11-10. Live-Lauf des `Lageschaetzer` ohne gemerkten Umfang gegen die nachträgliche Rechnung aus `tools/sensorik-sim/tempo_nachrechnung.py` (je Halbwelle auf 0…1 normiert), im aktiven Teil des Satzes.

Es gibt keine gemessene Wahrheit der Lage, nur die Übereinstimmung mit dieser nachträglichen Rechnung. Die Hilfslage im unsicheren Zustand ist dem Bezug nachgebaut, die Abweichung ist deshalb über sichere Messwerte („Abweichung sicher“) aussagekräftiger.

Auswahl: Stapel, Kurz- und Langhantel, `repsWahr` ≥ 5, ohne Lücke, ≥ 300 Messwerte.
Rückhalt: Abstimmung = Aufnahmen vor 2026-11-01, Prüfung = ab 2026-11-01. Konstanten werden nur an der Abstimmung gewählt; die Prüfung wird gelesen, nicht optimiert.
Tor je Art (Tempo-Spec 6.4): Betrag der Verzögerung im Median ≤ 150 ms, Abweichung im Median ≤ 0.15 des Hubs, kein Satz, dessen unbegrenzte Schätzung länger als eine Wiederholung außerhalb −0,25…1,25 liegt („außerhalb (roh)“). „tragfähig“ ist ein Vorschlag, nicht die Spec: Tor erreicht und sicher im Median ≥ 80 % und Wdh. gegen Wahrheit im Median ≤ 1.
„Wdh. gegen Wahrheit“ (Median von |Umkehrpunkte/2 − `repsWahr`|) ist die einzige Spalte mit echter Wahrheit.
Verzögerung: Median der Verschiebung mit der größten Korrelation (positiv = live später); |Verzögerung|: Median der Beträge. Alle Spalten sind Mediane über die Sätze der Art, „außerhalb (roh)“ ist eine Anzahl.

### Abstimmung (vor 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 50 | -40 ms | 40 ms | 0.150 | 0.165 | 12 | 41 % | 1.8 | nein | nein |
| kurzhantel | 62 | -160 ms | 220 ms | 0.422 | 0.455 | 18 | 0 % | 1.8 | nein | nein |
| langhantel | 17 | -60 ms | 160 ms | 0.395 | 0.484 | 9 | 1 % | 6.0 | nein | nein |

### Prüfung (ab 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 8 | -40 ms | 40 ms | 0.277 | 0.240 | 3 | 39 % | 1.8 | nein | nein |
| kurzhantel | 21 | -100 ms | 400 ms | 0.446 | 0.476 | 11 | 1 % | 2.0 | nein | nein |
| langhantel | 0 | – | – | – | – | – | – | – | – | – |

**Warnung:** langhantel hat in der Prüfung nur 0 Sätze (unter 5); daraus folgt keine Aussage.

## stapel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-11-03-1815-01 | Prüfung | -260 ms | 0.566 | 0.906 | ja | 23 % | 2.0 |
| 2026-10-26-1813-02 | Abstimmung | -300 ms | 0.460 | 0.464 | ja | 55 % | 10.5 |
| 2026-11-03-1825-01 | Prüfung | -180 ms | 0.455 | 0.899 | – | 1 % | 1.5 |
| 2026-10-18-1649-02 | Abstimmung | -380 ms | 0.442 | 0.430 | – | 83 % | 24.0 |
| 2026-10-14-1810-01 | Abstimmung | -120 ms | 0.399 | 0.203 | ja | 29 % | 9.0 |
| 2026-11-03-1821-01 | Prüfung | -160 ms | 0.398 | 0.340 | – | 32 % | 4.5 |
| 2026-10-18-1709-01 | Abstimmung | 40 ms | 0.394 | 0.131 | – | 38 % | 2.0 |
| 2026-10-18-1642-01 | Abstimmung | -20 ms | 0.360 | 0.240 | ja | 43 % | 6.5 |
| 2026-11-03-1813-01 | Prüfung | -20 ms | 0.328 | 0.169 | ja | 46 % | 4.5 |
| 2026-10-26-1808-01 | Abstimmung | -40 ms | 0.300 | 0.774 | ja | 7 % | 9.0 |

## kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-11-03-1800-01 | Prüfung | -400 ms | 0.778 | – | ja | 0 % | 4.0 |
| 2026-11-10-1824-01 | Prüfung | 400 ms | 0.729 | – | ja | 0 % | 3.0 |
| 2026-11-03-1807-01 | Prüfung | -400 ms | 0.720 | – | ja | 0 % | 8.0 |
| 2026-10-18-1611-02 | Abstimmung | 0 ms | 0.627 | – | ja | 0 % | 2.5 |
| 2026-10-18-1608-01 | Abstimmung | 0 ms | 0.595 | – | ja | 0 % | 2.5 |
| 2026-10-16-0943-02 | Abstimmung | -540 ms | 0.584 | 0.517 | ja | 6 % | 6.5 |
| 2026-11-10-1830-03 | Prüfung | -100 ms | 0.580 | 0.493 | ja | 13 % | 3.5 |
| 2026-10-16-1149-02 | Abstimmung | -200 ms | 0.564 | 0.473 | – | 13 % | 2.5 |
| 2026-10-26-1747-04 | Abstimmung | -160 ms | 0.551 | – | ja | 0 % | 8.0 |
| 2026-10-16-1327-04 | Abstimmung | -620 ms | 0.545 | 0.568 | – | 5 % | 3.0 |

## langhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-26-1818-02 | Abstimmung | 740 ms | 0.556 | 0.557 | ja | 12 % | 6.0 |
| 2026-10-18-1702-01 | Abstimmung | 0 ms | 0.541 | – | – | 0 % | 8.5 |
| 2026-10-18-1658-03 | Abstimmung | -920 ms | 0.539 | – | ja | 0 % | 17.0 |
| 2026-10-18-1619-01 | Abstimmung | -880 ms | 0.536 | 0.484 | ja | 2 % | 6.0 |
| 2026-10-08-0837-01 | Abstimmung | -200 ms | 0.485 | – | – | 0 % | 1.5 |
| 2026-10-08-0836-01 | Abstimmung | -500 ms | 0.411 | 0.580 | ja | 12 % | 3.5 |
| 2026-10-26-1820-02 | Abstimmung | -160 ms | 0.408 | 0.251 | – | 1 % | 16.0 |
| 2026-10-18-1654-01 | Abstimmung | 500 ms | 0.403 | – | – | 0 % | 13.5 |
| 2026-10-26-1821-02 | Abstimmung | 0 ms | 0.395 | – | ja | 0 % | 2.5 |
| 2026-10-18-1621-01 | Abstimmung | -300 ms | 0.393 | 0.297 | – | 19 % | 1.5 |
