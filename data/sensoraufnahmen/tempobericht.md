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
| stapel | 50 | -40 ms | 40 ms | 0.167 | 0.190 | 12 | 40 % | 1.5 | nein | nein |
| kurzhantel | 62 | -100 ms | 100 ms | 0.246 | 0.455 | 23 | 8 % | 2.0 | nein | nein |
| langhantel | 17 | -100 ms | 100 ms | 0.226 | 0.492 | 11 | 5 % | 9.0 | nein | nein |

### Prüfung (ab 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 8 | -40 ms | 40 ms | 0.276 | 0.241 | 3 | 39 % | 1.8 | nein | nein |
| kurzhantel | 21 | -120 ms | 120 ms | 0.227 | 0.367 | 10 | 21 % | 2.0 | nein | nein |
| langhantel | 0 | – | – | – | – | – | – | – | – | – |

**Warnung:** langhantel hat in der Prüfung nur 0 Sätze (unter 5); daraus folgt keine Aussage.

#### stapel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-11-03-1815-01 | Prüfung | -260 ms | 0.565 | 0.905 | ja | 23 % | 2.0 |
| 2026-10-18-1646-01 | Abstimmung | -40 ms | 0.486 | 0.532 | – | 83 % | 25.5 |
| 2026-11-03-1825-01 | Prüfung | -180 ms | 0.457 | 0.902 | – | 1 % | 1.5 |
| 2026-10-18-1649-02 | Abstimmung | -360 ms | 0.442 | 0.429 | – | 83 % | 24.0 |
| 2026-10-26-1813-02 | Abstimmung | -120 ms | 0.436 | 0.423 | ja | 43 % | 6.0 |
| 2026-10-14-1810-01 | Abstimmung | -120 ms | 0.400 | 0.203 | ja | 29 % | 9.0 |
| 2026-11-03-1821-01 | Prüfung | -160 ms | 0.398 | 0.339 | – | 32 % | 4.5 |
| 2026-10-18-1709-01 | Abstimmung | 40 ms | 0.393 | 0.130 | – | 38 % | 2.0 |
| 2026-10-18-1642-01 | Abstimmung | -20 ms | 0.360 | 0.241 | ja | 43 % | 6.5 |
| 2026-11-03-1813-01 | Prüfung | -20 ms | 0.328 | 0.169 | ja | 46 % | 4.5 |

#### kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-16-1149-02 | Abstimmung | -540 ms | 0.558 | 0.481 | – | 15 % | 3.0 |
| 2026-10-16-1325-02 | Abstimmung | 0 ms | 0.556 | – | ja | 0 % | 6.5 |
| 2026-10-16-1147-03 | Abstimmung | -460 ms | 0.553 | 0.440 | – | 4 % | 2.0 |
| 2026-10-16-1146-02 | Abstimmung | 340 ms | 0.547 | 0.721 | ja | 16 % | 4.5 |
| 2026-10-18-1613-01 | Abstimmung | -480 ms | 0.516 | 0.401 | ja | 4 % | 8.5 |
| 2026-10-14-1827-02 | Abstimmung | -260 ms | 0.506 | 1.140 | ja | 1 % | 5.5 |
| 2026-10-16-0943-02 | Abstimmung | 0 ms | 0.492 | 0.416 | – | 17 % | 4.5 |
| 2026-11-03-1800-01 | Prüfung | -60 ms | 0.482 | 0.539 | – | 22 % | 1.5 |
| 2026-10-18-1611-02 | Abstimmung | -320 ms | 0.459 | 0.726 | ja | 21 % | 6.5 |
| 2026-11-03-1803-01 | Prüfung | -900 ms | 0.455 | 0.489 | ja | 3 % | 3.0 |

#### langhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-14-1832-01 | Abstimmung | -300 ms | 0.566 | 0.607 | ja | 5 % | 15.5 |
| 2026-10-08-0836-01 | Abstimmung | -240 ms | 0.443 | – | ja | 0 % | 11.5 |
| 2026-10-14-1830-01 | Abstimmung | -240 ms | 0.409 | 0.493 | ja | 10 % | 15.5 |
| 2026-10-18-1621-01 | Abstimmung | -240 ms | 0.352 | 0.491 | – | 14 % | 0.0 |
| 2026-10-18-1654-01 | Abstimmung | -160 ms | 0.336 | 0.404 | ja | 12 % | 11.0 |
| 2026-10-26-1820-02 | Abstimmung | -160 ms | 0.319 | 0.501 | ja | 6 % | 17.5 |
| 2026-10-08-0837-01 | Abstimmung | -100 ms | 0.267 | 0.423 | ja | 1 % | 6.0 |
| 2026-10-18-1619-01 | Abstimmung | -320 ms | 0.245 | 0.462 | ja | 5 % | 2.5 |
| 2026-10-26-1821-02 | Abstimmung | -40 ms | 0.226 | 0.259 | – | 39 % | 2.5 |
| 2026-10-18-1658-03 | Abstimmung | -80 ms | 0.196 | 0.587 | ja | 4 % | 9.0 |

## Schwerkraft mit der Drehrate fortgeschrieben (`.drehrate`)

### Abstimmung (vor 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 50 | -40 ms | 40 ms | 0.153 | 0.172 | 12 | 40 % | 1.0 | nein | nein |
| kurzhantel | 62 | -100 ms | 100 ms | 0.238 | 0.486 | 23 | 8 % | 2.0 | nein | nein |
| langhantel | 17 | -100 ms | 100 ms | 0.216 | 0.492 | 11 | 6 % | 8.5 | nein | nein |

### Prüfung (ab 2026-11-01)

| Art | Sätze | Verzögerung | \|Verzögerung\| | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit | Tor erreicht | tragfähig (Vorschlag) |
|---|---|---|---|---|---|---|---|---|---|---|
| stapel | 8 | -40 ms | 40 ms | 0.278 | 0.241 | 3 | 39 % | 1.8 | nein | nein |
| kurzhantel | 21 | -140 ms | 140 ms | 0.238 | 0.250 | 9 | 22 % | 2.0 | nein | nein |
| langhantel | 0 | – | – | – | – | – | – | – | – | – |

**Warnung:** langhantel hat in der Prüfung nur 0 Sätze (unter 5); daraus folgt keine Aussage.

#### stapel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-11-03-1815-01 | Prüfung | -260 ms | 0.566 | 0.911 | ja | 22 % | 2.0 |
| 2026-10-26-1813-02 | Abstimmung | -300 ms | 0.462 | 0.469 | ja | 54 % | 11.0 |
| 2026-11-03-1825-01 | Prüfung | -180 ms | 0.456 | 0.911 | – | 1 % | 1.5 |
| 2026-10-18-1649-02 | Abstimmung | -380 ms | 0.443 | 0.430 | – | 83 % | 24.0 |
| 2026-10-14-1810-01 | Abstimmung | -120 ms | 0.400 | 0.204 | ja | 30 % | 9.0 |
| 2026-11-03-1821-01 | Prüfung | -160 ms | 0.399 | 0.340 | – | 32 % | 4.5 |
| 2026-10-18-1709-01 | Abstimmung | 40 ms | 0.392 | 0.129 | – | 38 % | 2.0 |
| 2026-10-18-1642-01 | Abstimmung | -20 ms | 0.362 | 0.244 | ja | 43 % | 6.5 |
| 2026-11-03-1813-01 | Prüfung | -20 ms | 0.328 | 0.168 | ja | 46 % | 4.5 |
| 2026-10-26-1808-01 | Abstimmung | -40 ms | 0.300 | 0.773 | ja | 7 % | 9.0 |

#### kurzhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-16-1325-02 | Abstimmung | -480 ms | 0.575 | 0.825 | ja | 8 % | 5.0 |
| 2026-10-16-1149-02 | Abstimmung | -540 ms | 0.559 | 0.483 | – | 15 % | 3.0 |
| 2026-10-16-1146-02 | Abstimmung | 340 ms | 0.545 | 0.738 | ja | 16 % | 4.5 |
| 2026-10-18-1613-01 | Abstimmung | -640 ms | 0.525 | 1.093 | ja | 2 % | 8.0 |
| 2026-10-14-1827-02 | Abstimmung | -280 ms | 0.511 | 1.132 | ja | 1 % | 6.0 |
| 2026-10-16-1147-03 | Abstimmung | -480 ms | 0.498 | 0.551 | – | 3 % | 1.5 |
| 2026-10-16-0940-01 | Abstimmung | -940 ms | 0.477 | – | – | 0 % | 8.0 |
| 2026-10-18-1611-02 | Abstimmung | -300 ms | 0.456 | 0.711 | ja | 21 % | 6.5 |
| 2026-11-03-1803-01 | Prüfung | -820 ms | 0.449 | 0.524 | ja | 3 % | 4.0 |
| 2026-10-16-0943-02 | Abstimmung | -120 ms | 0.443 | 0.320 | – | 34 % | 3.5 |

#### langhantel: die zehn schlechtesten Sätze

| Aufnahme | Teil | Verzögerung | Abweichung | Abweichung sicher | außerhalb (roh) | sicher | Wdh. gegen Wahrheit |
|---|---|---|---|---|---|---|---|
| 2026-10-08-0836-01 | Abstimmung | -80 ms | 0.456 | – | ja | 0 % | 11.0 |
| 2026-10-14-1830-01 | Abstimmung | -240 ms | 0.450 | 0.595 | ja | 12 % | 15.0 |
| 2026-10-26-1820-02 | Abstimmung | -180 ms | 0.358 | 0.515 | ja | 6 % | 17.0 |
| 2026-10-18-1621-01 | Abstimmung | -240 ms | 0.351 | 0.496 | – | 14 % | 0.0 |
| 2026-10-18-1654-01 | Abstimmung | -160 ms | 0.351 | 0.487 | ja | 8 % | 10.0 |
| 2026-10-26-1818-02 | Abstimmung | -240 ms | 0.299 | 0.378 | ja | 14 % | 6.0 |
| 2026-10-08-0837-01 | Abstimmung | -100 ms | 0.272 | 0.445 | ja | 1 % | 6.0 |
| 2026-10-26-1821-02 | Abstimmung | -60 ms | 0.238 | 0.300 | ja | 30 % | 0.5 |
| 2026-10-18-1619-01 | Abstimmung | -280 ms | 0.216 | 0.511 | ja | 3 % | 3.0 |
| 2026-10-26-1816-01 | Abstimmung | -120 ms | 0.191 | 0.423 | ja | 12 % | 8.5 |
