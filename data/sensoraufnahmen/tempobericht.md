# Tempobericht Lageschätzung

Erzeugt von `TempoBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
Stand: Aufnahmen bis 2026-11-10. Live-Lauf des `Lageschaetzer` ohne gemerkten Umfang gegen die nachträgliche Rechnung aus `tools/sensorik-sim/tempo_nachrechnung.py` (je Halbwelle auf 0…1 normiert), im aktiven Teil des Satzes.

Es gibt keine gemessene Wahrheit der Lage, nur die Übereinstimmung mit dieser nachträglichen Rechnung. Die Hilfslage im unsicheren Zustand ist dem Bezug nachgebaut, die Abweichung ist deshalb über sichere Messwerte („Abweichung sicher“) aussagekräftiger.

Auswahl: Stapel, Kurz- und Langhantel, `repsWahr` ≥ 5, ohne Lücke, ≥ 300 Messwerte.
Rückhalt: Abstimmung = Aufnahmen vor 2026-11-01, Prüfung = ab 2026-11-01. Konstanten werden nur an der Abstimmung gewählt; die Prüfung wird gelesen, nicht optimiert.
Tor je Art (Tempo-Spec 6.4): Betrag der Verzögerung im Median ≤ 150 ms, Abweichung im Median ≤ 0.15 des Hubs, kein Satz, dessen unbegrenzte Schätzung länger als eine Wiederholung außerhalb −0,25…1,25 liegt („außerhalb (roh)“). „tragfähig“ ist ein Vorschlag, nicht die Spec: Tor erreicht und sicher im Median ≥ 80 % und Wdh. gegen Wahrheit im Median ≤ 1.
„Wdh. gegen Wahrheit“ (Median von |Umkehrpunkte/2 − `repsWahr`|) ist die einzige Spalte mit echter Wahrheit.
Verzögerung: Median der Verschiebung mit der größten Korrelation (positiv = live später); |Verzögerung|: Median der Beträge. Alle Spalten sind Mediane über die Sätze der Art, „außerhalb (roh)“ ist eine Anzahl.
Winkel-Versuch (Task 5b): je Schwerkraftquelle ein Abschnitt; Live-Lauf und Bezug nutzen dieselbe Quelle.

## Winkel in Ruhe

Winkel zwischen der Richtung aus Roll/Pitch und der gemessenen Beschleunigung an ruhenden Messwerten (Betrag auf 0,01 g bei 1 g, Drehrate unter 5 °/s, seit 0,5 s). Über etwa 3° trüge `.winkel` nicht.

| Art | ruhende Messwerte | Winkelfehler (Median) |
|---|---|---|
| stapel | 28304 | 1.66° |
| kurzhantel | 23725 | 1.35° |
| langhantel | 4946 | 1.48° |

## Bezug `.ruhe` gegen Bezug `.winkel`

Mittel von |Bezug `.ruhe` − Bezug `.winkel`| im gemeinsamen aktiven Teil, Median über die Sätze: so stark verschiebt die Schwerkraft aus der Ruhe den Bezug selbst.

„verschiedener Abschnitt“: Die beiden Bezüge nehmen ganz verschiedene Teile der Aufnahme als aktiv.

| Art | Sätze | Unterschied (Median) | Unterschied (größter) | verschiedener Abschnitt |
|---|---|---|---|---|
| stapel | 58 | 0.000 | 0.000 | 0 |
| kurzhantel | 79 | 0.056 | 0.574 | 4 |
| langhantel | 13 | 0.010 | 0.622 | 4 |

## Schwerkraft aus der Ruhe (`.ruhe`, bisher)

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

#### stapel: die zehn schlechtesten Sätze

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

#### kurzhantel: die zehn schlechtesten Sätze

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

#### langhantel: die zehn schlechtesten Sätze

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

## Schwerkraft aus Roll/Pitch je Messwert (`.winkel`)

### Abstimmung (vor 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 50 | -50 ms | 50 ms | 0.170 | 0.265 | 25 | 38 % | 3.8 | nein | nein |
| kurzhantel | 62 | -40 ms | 40 ms | 0.181 | 0.139 | 12 | 76 % | 1.5 | nein | nein |
| langhantel | 17 | -20 ms | 20 ms | 0.118 | 0.086 | 6 | 89 % | 1.5 | nein | nein |

### Prüfung (ab 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 8 | 0 ms | 10 ms | 0.107 | 0.102 | 2 | 90 % | 0.5 | nein | nein |
| kurzhantel | 21 | -200 ms | 200 ms | 0.290 | 0.376 | 9 | 23 % | 2.0 | nein | nein |
| langhantel | 0 | – | – | – | – | – | – | – | – | – |

**Warnung:** langhantel hat in der Prüfung nur 0 Sätze (unter 5); daraus folgt keine Aussage.

#### stapel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-18-1642-01 | Abstimmung | 20 ms | 0.519 | 0.529 | – | 97 % | 19.0 |
| 2026-10-26-1808-01 | Abstimmung | -100 ms | 0.503 | 0.442 | – | 27 % | 1.5 |
| 2026-10-18-1646-01 | Abstimmung | -120 ms | 0.482 | 0.456 | – | 38 % | 3.0 |
| 2026-10-18-1650-02 | Abstimmung | -60 ms | 0.422 | 0.469 | ja | 8 % | 25.5 |
| 2026-10-26-1736-01 | Abstimmung | -360 ms | 0.403 | 0.445 | ja | 15 % | 2.5 |
| 2026-10-18-1638-01 | Abstimmung | -140 ms | 0.324 | 0.529 | ja | 10 % | 10.0 |
| 2026-10-26-1813-04 | Abstimmung | -40 ms | 0.293 | 0.217 | ja | 47 % | 4.5 |
| 2026-10-14-1759-01 | Abstimmung | -200 ms | 0.292 | 0.370 | ja | 19 % | 5.5 |
| 2026-10-18-1648-01 | Abstimmung | -40 ms | 0.292 | 0.760 | ja | 1 % | 39.0 |
| 2026-10-14-1747-01 | Abstimmung | -320 ms | 0.280 | – | – | 0 % | 10.0 |

#### kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-16-1148-02 | Abstimmung | -240 ms | 0.554 | 0.534 | – | 19 % | 0.5 |
| 2026-11-10-1830-01 | Prüfung | -280 ms | 0.547 | 0.530 | – | 17 % | 0.5 |
| 2026-10-16-1146-03 | Abstimmung | -160 ms | 0.509 | 0.500 | ja | 32 % | 1.5 |
| 2026-10-16-0940-01 | Abstimmung | -540 ms | 0.487 | 0.501 | ja | 6 % | 1.0 |
| 2026-10-16-0945-01 | Abstimmung | -220 ms | 0.480 | 0.547 | – | 28 % | 1.5 |
| 2026-11-03-1800-01 | Prüfung | 0 ms | 0.479 | – | ja | 0 % | 20.0 |
| 2026-10-16-0943-02 | Abstimmung | -40 ms | 0.478 | 0.482 | – | 88 % | 7.0 |
| 2026-10-16-1147-01 | Abstimmung | -160 ms | 0.469 | 0.434 | – | 30 % | 2.5 |
| 2026-10-16-1147-03 | Abstimmung | -240 ms | 0.468 | 0.499 | – | 17 % | 1.0 |
| 2026-10-16-1325-02 | Abstimmung | -80 ms | 0.442 | 0.676 | – | 42 % | 3.0 |

#### langhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-14-1832-01 | Abstimmung | -180 ms | 0.573 | – | ja | 0 % | 20.0 |
| 2026-10-26-1820-02 | Abstimmung | -240 ms | 0.480 | 0.495 | ja | 20 % | 7.0 |
| 2026-10-08-0836-01 | Abstimmung | -140 ms | 0.267 | – | ja | 0 % | 12.0 |
| 2026-10-26-1821-02 | Abstimmung | 0 ms | 0.230 | 0.175 | ja | 74 % | 2.5 |
| 2026-10-18-1621-01 | Abstimmung | 40 ms | 0.225 | 0.199 | – | 92 % | 0.5 |
| 2026-10-18-1654-01 | Abstimmung | -120 ms | 0.203 | 0.363 | ja | 7 % | 20.0 |
| 2026-10-26-1816-01 | Abstimmung | -140 ms | 0.190 | 0.513 | ja | 4 % | 14.5 |
| 2026-10-18-1619-01 | Abstimmung | -20 ms | 0.139 | 0.121 | – | 95 % | 1.0 |
| 2026-10-08-0837-01 | Abstimmung | -20 ms | 0.118 | 0.113 | – | 88 % | 1.0 |
| 2026-10-26-1818-02 | Abstimmung | -60 ms | 0.110 | 0.053 | – | 84 % | 3.0 |

## Schwerkraft mit der Drehrate fortgeschrieben (`.drehrate`)

### Abstimmung (vor 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 50 | -40 ms | 40 ms | 0.162 | 0.193 | 26 | 61 % | 1.5 | nein | nein |
| kurzhantel | 62 | -50 ms | 50 ms | 0.192 | 0.173 | 17 | 64 % | 1.5 | nein | nein |
| langhantel | 17 | -40 ms | 40 ms | 0.137 | 0.147 | 8 | 82 % | 2.5 | nein | nein |

### Prüfung (ab 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 8 | 0 ms | 20 ms | 0.135 | 0.125 | 2 | 88 % | 0.5 | nein | nein |
| kurzhantel | 21 | -160 ms | 160 ms | 0.309 | 0.376 | 11 | 28 % | 1.5 | nein | nein |
| langhantel | 0 | – | – | – | – | – | – | – | – | – |

**Warnung:** langhantel hat in der Prüfung nur 0 Sätze (unter 5); daraus folgt keine Aussage.

#### stapel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-18-1642-01 | Abstimmung | 40 ms | 0.520 | 0.529 | – | 97 % | 19.0 |
| 2026-10-18-1646-01 | Abstimmung | -100 ms | 0.512 | 0.561 | ja | 53 % | 8.0 |
| 2026-10-26-1736-01 | Abstimmung | -400 ms | 0.479 | 0.471 | ja | 18 % | 0.0 |
| 2026-10-14-1747-01 | Abstimmung | 0 ms | 0.472 | – | ja | 0 % | 10.0 |
| 2026-10-18-1649-02 | Abstimmung | -120 ms | 0.470 | 0.616 | ja | 6 % | 18.5 |
| 2026-11-03-1815-01 | Prüfung | -120 ms | 0.434 | 0.719 | ja | 6 % | 17.5 |
| 2026-10-18-1648-01 | Abstimmung | -40 ms | 0.285 | 0.713 | ja | 1 % | 38.5 |
| 2026-10-18-1652-01 | Abstimmung | -20 ms | 0.260 | 0.214 | ja | 54 % | 6.5 |
| 2026-10-18-1638-01 | Abstimmung | -100 ms | 0.259 | 0.497 | ja | 7 % | 12.0 |
| 2026-10-26-1810-02 | Abstimmung | -60 ms | 0.259 | 0.281 | ja | 19 % | 13.5 |

#### kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-16-1148-02 | Abstimmung | -260 ms | 0.576 | 0.551 | – | 19 % | 0.5 |
| 2026-10-16-1146-03 | Abstimmung | -180 ms | 0.550 | 0.545 | ja | 31 % | 1.5 |
| 2026-11-03-1803-01 | Prüfung | -500 ms | 0.543 | 0.574 | – | 21 % | 1.0 |
| 2026-11-10-1830-01 | Prüfung | -300 ms | 0.532 | 0.529 | – | 15 % | 0.0 |
| 2026-10-16-1147-01 | Abstimmung | -200 ms | 0.529 | 0.497 | ja | 27 % | 1.5 |
| 2026-10-16-1147-03 | Abstimmung | 0 ms | 0.528 | – | ja | 0 % | 6.0 |
| 2026-10-16-0943-02 | Abstimmung | -780 ms | 0.477 | 0.483 | – | 98 % | 9.0 |
| 2026-11-10-1826-02 | Prüfung | -340 ms | 0.470 | 0.430 | – | 15 % | 3.0 |
| 2026-10-16-0945-01 | Abstimmung | -200 ms | 0.461 | 0.532 | – | 29 % | 1.5 |
| 2026-10-18-1611-02 | Abstimmung | -180 ms | 0.436 | 0.821 | ja | 3 % | 10.5 |

#### langhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-08-0836-01 | Abstimmung | -220 ms | 0.302 | 0.385 | ja | 22 % | 3.0 |
| 2026-10-26-1821-02 | Abstimmung | 0 ms | 0.217 | 0.160 | ja | 76 % | 4.0 |
| 2026-10-18-1621-01 | Abstimmung | 40 ms | 0.216 | 0.188 | – | 92 % | 0.5 |
| 2026-10-26-1816-01 | Abstimmung | -140 ms | 0.207 | 0.510 | ja | 5 % | 13.5 |
| 2026-10-18-1654-01 | Abstimmung | -100 ms | 0.202 | 0.454 | ja | 5 % | 20.0 |
| 2026-10-26-1820-02 | Abstimmung | -80 ms | 0.199 | 0.230 | ja | 35 % | 9.0 |
| 2026-10-18-1619-01 | Abstimmung | -60 ms | 0.160 | 0.127 | – | 82 % | 1.5 |
| 2026-10-14-1832-01 | Abstimmung | -80 ms | 0.153 | 0.524 | ja | 3 % | 16.5 |
| 2026-10-18-1700-02 | Abstimmung | 20 ms | 0.137 | 0.135 | – | 99 % | 0.5 |
| 2026-10-14-1830-01 | Abstimmung | -60 ms | 0.129 | 0.418 | ja | 9 % | 21.0 |
