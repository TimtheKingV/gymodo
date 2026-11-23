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
| stapel | 50 | -60 ms | 60 ms | 0.145 | 0.373 | 21 | 2 % | 9.0 | nein | nein |
| kurzhantel | 62 | -40 ms | 40 ms | 0.137 | 0.089 | 2 | 68 % | 1.5 | nein | nein |
| langhantel | 17 | -40 ms | 40 ms | 0.131 | 0.087 | 5 | 74 % | 3.5 | nein | nein |

### Prüfung (ab 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 8 | -40 ms | 40 ms | 0.115 | 0.284 | 3 | 6 % | 5.5 | nein | nein |
| kurzhantel | 21 | -60 ms | 60 ms | 0.181 | 0.111 | 3 | 47 % | 2.0 | nein | nein |
| langhantel | 0 | – | – | – | – | – | – | – | – | – |

**Warnung:** langhantel hat in der Prüfung nur 0 Sätze (unter 5); daraus folgt keine Aussage.

#### stapel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-18-1650-02 | Abstimmung | -40 ms | 0.424 | – | – | 0 % | 26.5 |
| 2026-10-18-1635-01 | Abstimmung | -60 ms | 0.413 | 0.595 | ja | 1 % | 23.5 |
| 2026-10-18-1642-01 | Abstimmung | -40 ms | 0.349 | – | – | 0 % | 19.0 |
| 2026-10-14-1753-01 | Abstimmung | -120 ms | 0.330 | 0.338 | ja | 3 % | 9.5 |
| 2026-10-18-1634-01 | Abstimmung | -80 ms | 0.314 | 0.685 | ja | 7 % | 16.0 |
| 2026-10-26-1813-02 | Abstimmung | -40 ms | 0.297 | 0.346 | ja | 3 % | 8.5 |
| 2026-10-18-1648-01 | Abstimmung | -40 ms | 0.287 | – | – | 0 % | 38.5 |
| 2026-10-14-1747-01 | Abstimmung | -320 ms | 0.280 | – | – | 0 % | 10.0 |
| 2026-10-18-1638-01 | Abstimmung | -60 ms | 0.271 | 0.840 | ja | 7 % | 7.5 |
| 2026-10-26-1808-01 | Abstimmung | -40 ms | 0.267 | 0.809 | – | 8 % | 5.5 |

#### kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-11-03-1800-01 | Prüfung | 0 ms | 0.479 | – | ja | 0 % | 20.0 |
| 2026-11-10-1822-03 | Prüfung | -240 ms | 0.318 | – | – | 0 % | 1.0 |
| 2026-11-10-1830-03 | Prüfung | -100 ms | 0.280 | – | – | 0 % | 9.0 |
| 2026-11-10-1824-01 | Prüfung | -60 ms | 0.264 | 0.231 | – | 76 % | 2.0 |
| 2026-10-16-1325-03 | Abstimmung | -60 ms | 0.257 | – | – | 0 % | 3.0 |
| 2026-10-16-1327-02 | Abstimmung | -80 ms | 0.252 | 0.304 | – | 58 % | 2.5 |
| 2026-11-03-1806-01 | Prüfung | -120 ms | 0.249 | 0.189 | – | 59 % | 1.0 |
| 2026-10-16-0941-01 | Abstimmung | -140 ms | 0.249 | – | – | 0 % | 5.5 |
| 2026-10-16-1149-02 | Abstimmung | -140 ms | 0.243 | – | – | 0 % | 0.5 |
| 2026-10-16-1147-01 | Abstimmung | -60 ms | 0.241 | – | – | 0 % | 3.0 |

#### langhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-14-1832-01 | Abstimmung | -180 ms | 0.573 | – | ja | 0 % | 20.0 |
| 2026-10-08-0836-01 | Abstimmung | -140 ms | 0.267 | – | ja | 0 % | 12.0 |
| 2026-10-14-1830-01 | Abstimmung | -100 ms | 0.248 | 0.656 | ja | 6 % | 11.0 |
| 2026-10-26-1821-02 | Abstimmung | 0 ms | 0.223 | 0.176 | ja | 74 % | 3.5 |
| 2026-10-18-1621-01 | Abstimmung | -140 ms | 0.186 | – | – | 0 % | 0.5 |
| 2026-10-18-1654-01 | Abstimmung | -80 ms | 0.166 | – | – | 0 % | 23.0 |
| 2026-10-18-1619-01 | Abstimmung | -40 ms | 0.157 | 0.130 | – | 82 % | 1.0 |
| 2026-10-26-1816-01 | Abstimmung | -60 ms | 0.144 | – | – | 0 % | 13.0 |
| 2026-10-18-1623-01 | Abstimmung | -20 ms | 0.131 | 0.088 | – | 84 % | 0.5 |
| 2026-10-26-1820-02 | Abstimmung | -60 ms | 0.126 | – | – | 0 % | 5.0 |

## Schwerkraft mit der Drehrate fortgeschrieben (`.drehrate`)

### Abstimmung (vor 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 50 | -40 ms | 40 ms | 0.139 | 0.354 | 22 | 3 % | 8.0 | nein | nein |
| kurzhantel | 62 | -40 ms | 40 ms | 0.148 | 0.096 | 6 | 61 % | 2.5 | nein | nein |
| langhantel | 17 | -40 ms | 40 ms | 0.137 | 0.122 | 2 | 3 % | 5.0 | nein | nein |

### Prüfung (ab 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 8 | -30 ms | 30 ms | 0.101 | 0.188 | 3 | 32 % | 2.5 | nein | nein |
| kurzhantel | 21 | -60 ms | 60 ms | 0.180 | 0.115 | 4 | 59 % | 1.5 | nein | nein |
| langhantel | 0 | – | – | – | – | – | – | – | – | – |

**Warnung:** langhantel hat in der Prüfung nur 0 Sätze (unter 5); daraus folgt keine Aussage.

#### stapel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-14-1747-01 | Abstimmung | 0 ms | 0.472 | – | ja | 0 % | 10.0 |
| 2026-10-18-1642-01 | Abstimmung | -40 ms | 0.401 | – | – | 0 % | 19.0 |
| 2026-10-18-1652-01 | Abstimmung | -40 ms | 0.377 | 0.462 | ja | 2 % | 17.5 |
| 2026-10-18-1648-01 | Abstimmung | -40 ms | 0.280 | – | – | 0 % | 37.5 |
| 2026-10-26-1738-01 | Abstimmung | -100 ms | 0.227 | 0.356 | ja | 4 % | 4.5 |
| 2026-10-26-1813-04 | Abstimmung | 20 ms | 0.212 | 0.193 | – | 93 % | 0.5 |
| 2026-10-14-1758-01 | Abstimmung | -120 ms | 0.210 | 0.610 | ja | 9 % | 3.0 |
| 2026-10-14-1755-01 | Abstimmung | -100 ms | 0.210 | 0.585 | ja | 6 % | 4.5 |
| 2026-10-18-1645-01 | Abstimmung | -80 ms | 0.207 | – | – | 0 % | 13.5 |
| 2026-10-14-1751-01 | Abstimmung | -120 ms | 0.205 | 0.296 | ja | 4 % | 3.5 |

#### kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-16-1147-03 | Abstimmung | 0 ms | 0.528 | – | ja | 0 % | 6.0 |
| 2026-10-16-0943-02 | Abstimmung | -200 ms | 0.466 | – | – | 0 % | 9.0 |
| 2026-10-16-0940-01 | Abstimmung | -200 ms | 0.404 | – | ja | 0 % | 10.0 |
| 2026-11-10-1822-03 | Prüfung | -240 ms | 0.324 | – | – | 0 % | 1.0 |
| 2026-11-10-1830-03 | Prüfung | -100 ms | 0.297 | – | – | 0 % | 13.5 |
| 2026-10-14-1826-02 | Abstimmung | -140 ms | 0.290 | – | – | 0 % | 9.5 |
| 2026-10-18-1610-02 | Abstimmung | -100 ms | 0.272 | – | – | 0 % | 11.5 |
| 2026-10-16-0941-01 | Abstimmung | -160 ms | 0.268 | 0.471 | – | 16 % | 7.0 |
| 2026-10-16-1325-02 | Abstimmung | -80 ms | 0.260 | – | – | 0 % | 4.5 |
| 2026-10-16-1325-03 | Abstimmung | -60 ms | 0.259 | – | – | 0 % | 3.0 |

#### langhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-18-1704-01 | Abstimmung | -40 ms | 0.261 | 0.603 | ja | 3 % | 12.0 |
| 2026-10-26-1821-02 | Abstimmung | 20 ms | 0.209 | 0.141 | – | 69 % | 5.0 |
| 2026-10-18-1621-01 | Abstimmung | -140 ms | 0.185 | – | – | 0 % | 0.5 |
| 2026-10-08-0837-01 | Abstimmung | -60 ms | 0.165 | 0.217 | – | 53 % | 3.5 |
| 2026-10-18-1654-01 | Abstimmung | -80 ms | 0.165 | – | – | 0 % | 20.0 |
| 2026-10-18-1619-01 | Abstimmung | -40 ms | 0.150 | 0.122 | – | 82 % | 2.5 |
| 2026-10-26-1816-01 | Abstimmung | -60 ms | 0.146 | – | – | 0 % | 12.0 |
| 2026-10-08-0836-01 | Abstimmung | -80 ms | 0.137 | – | – | 0 % | 3.5 |
| 2026-10-26-1820-02 | Abstimmung | -60 ms | 0.137 | – | – | 0 % | 13.0 |
| 2026-10-14-1832-01 | Abstimmung | -60 ms | 0.133 | – | – | 0 % | 16.0 |
