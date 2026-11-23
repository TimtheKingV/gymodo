# Winkellage

Der Winkel ist eine direkte Messung der Lage der Last; deshalb wird die `Winkellage` hier gegen die gezählten Wiederholungen geprüft, nicht gegen eine nachträgliche Rechnung.

Signal: Drehung der Schwerkraftrichtung ĝ = (−sin p, sin r · cos p, cos r · cos p) aus Roll r und Pitch p gegenüber der Ruherichtung, in der Drehebene der ersten Bewegung gemessen und über ±180° entfaltet. Es hat keine Sprungstelle bei Pitch ±90°. Grenze: Eine Drehung um die Senkrechte (waagerecht schwenkende Hebelarme) ändert die Schwerkraftrichtung nicht und ist für den Winkel unsichtbar.

Auswahl: alle Aufnahmen mit bekannter Wiederholungszahl ≥ 5, auch ohne oder mit anderer Befestigungsart: `repsWahr` aus `korrekturen.json`, bei den Mac-Aufnahmen mit Metronom (`tempo` in `aufnahme.json`) die von Hand gezählten Perioden aus `label.reps`. Live-Lauf ohne gemerkten Hub; Lücken gehen an die `Winkellage`.
„geeignet“: gemerkter Hub am Satzende ≥ 40°. Alle Kennzahlen sind Mediane über die geeigneten Sätze; Wdh.-Fehler = Median von |Umkehrpunkte/2 − Wiederholungen|; Sicher = Anteil sicherer Messwerte zwischen dem dritten und letzten Umkehrpunkt; Streuung = Standardabweichung/Mittel des Hubs je Wiederholung; „Sprung“ = ein Schritt der Lage über 0.2 zwischen zwei Messwerten (Lücken nicht ausgenommen).
„tragfähig“: Wdh.-Fehler ≤ 1, Sicher ≥ 0.9 und kein Satz mit Sprung.

Jede Zelle zeigt zwei Läufe: **ohne Start / mit Start**. „Ohne Start“: die `Winkellage` legt die Ruherichtung mit der ersten Bewegung fest; das Aufnehmen der Hantel zählt mit. „Mit Start“: `los()` kommt vor dem Satz. Bei den Mac-Aufnahmen steht der Start als Zeile `# los <t>` in der Aufnahme (Zeile „mit Los-Marke“), das ist der echte Ablauf. Bei allen anderen Aufnahmen gibt es keine Marke; der Start wird **nachträglich mit Wissen über den ganzen Satz** gesetzt und ist deshalb eine **obere Schranke, kein Ergebnis**: Satzband = Mittelrichtung von ĝ über die mittlere Hälfte der Aufnahme, Radius = größter Abstand dort + 15°; aktiver Teil = der zusammenhängende Abschnitt im Satzband um diese Mitte; `los()` am Ende des ersten Stillstands (0,5 s, 4°), der in den ersten 2 s dieses Abschnitts beginnt, ohne Stillstand dort am ersten Messwert, an dem die Drehung unter 20 °/s fällt (Ende des Aufnehmens).

## Abstimmung (vor 2026-11-01)

| Art | Sätze | geeignet | Hub (Median) | Wdh.-Fehler | Sicher | Streuung | Sätze mit Sprung | tragfähig |
|---|---|---|---|---|---|---|---|---|
| stapel | 50 | 0 / 0 | – / – | – / – | – / – | – / – | – / – | nein / nein |
| langhantel | 17 | 6 / 4 | 59 ° / 73 ° | 4.5 / 3.5 | 90 % / 88 % | 0.773 / 1.404 | 3 / 3 | nein / nein |
| kurzhantel | 63 | 47 / 39 | 108 ° / 117 ° | 1.5 / 1.0 | 100 % / 100 % | 0.307 / 0.119 | 20 / 5 | nein / nein |
| koerper | 1 | 1 / 1 | 108 ° / 109 ° | 7.0 / 7.0 | 100 % / 100 % | 0.534 / 0.529 | 0 / 0 | nein / nein |

## Prüfung (ab 2026-11-01)

| Art | Sätze | geeignet | Hub (Median) | Wdh.-Fehler | Sicher | Streuung | Sätze mit Sprung | tragfähig |
|---|---|---|---|---|---|---|---|---|
| stapel | 8 | 0 / 0 | – / – | – / – | – / – | – / – | – / – | nein / nein |
| kurzhantel | 21 | 15 / 13 | 195 ° / 160 ° | 1.0 / 1.0 | 100 % / 100 % | 0.256 / 0.086 | 0 / 3 | ja / nein |
| kurzhantel mit Los-Marke | 11 | 7 / 7 | 149 ° / 134 ° | 1.0 / 1.0 | 100 % / 100 % | 0.050 / 0.049 | 1 / 0 | nein / ja |

## Aufnahmen mit Los-Marke

Je Zelle ohne Start / mit Los-Marke.

| Aufnahme | Übung | Wiederholungen | Hub | erkannt | Sicher | größter Sprung |
|---|---|---|---|---|---|---|
| 2026-11-23-2137-01 | Kurzhantel-Bizepscurl | 23 | 174 ° / 143 ° | 25.0 / 24.0 | 98 % / 100 % | 0.45 / 0.08 |
| 2026-11-23-2144-01 | Kurzhantel-Bizepscurl | 21 | 160 ° / 157 ° | 22.0 / 22.0 | 100 % / 100 % | 0.09 / 0.09 |
| 2026-11-23-2146-01 | Kurzhantel-Bizepscurl | 7 | 138 ° / 125 ° | 7.0 / 7.0 | 100 % / 100 % | 0.06 / 0.07 |
| 2026-11-23-2147-01 | Kurzhantel-Bizepscurl | 6 | 149 ° / 134 ° | 7.0 / 7.0 | 100 % / 100 % | 0.08 / 0.08 |
| 2026-11-23-2148-01 | Kurzhantel-Bizepscurl | 10 | 152 ° / 135 ° | 10.0 / 10.0 | 100 % / 100 % | 0.08 / 0.08 |
| 2026-11-23-2149-01 | Seitheben | 14 | 86 ° / 86 ° | 15.0 / 15.0 | 100 % / 100 % | 0.06 / 0.12 |
| 2026-11-23-2150-01 | Seitheben | 10 | 86 ° / 92 ° | 10.0 / 10.0 | 100 % / 100 % | 0.09 / 0.05 |
| 2026-11-23-2152-01 | Schrägbankdrücken Kurzhantel | 9 | 20 ° / 21 ° | 3.0 / 3.5 | 0 % / 0 % | 0.34 / 0.31 |
| 2026-11-23-2153-01 | Schrägbankdrücken Kurzhantel | 8 | – / – | 0.0 / 0.0 | 0 % / 0 % | 0.03 / 0.09 |
| 2026-11-23-2154-01 | Bankdrücken | 10 | – / – | 0.0 / 1.0 | 0 % / 0 % | 0.02 / 0.28 |
| 2026-11-23-2155-01 | Bankdrücken | 9 | – / – | 1.0 / 1.0 | 0 % / 0 % | 0.10 / 0.10 |

## Geeignete Sätze mit Sprung

Je Zelle ohne Start / mit Start; „–“: in diesem Lauf nicht geeignet.

| Aufnahme | Teil | Art | Übung | Hub | größter Sprung | Lücken |
|---|---|---|---|---|---|---|
| 2026-10-08-0836-01 | Abstimmung | langhantel | Kabelzug hoch | 83 ° / 83 ° | 0.62 / 0.62 | 0 |
| 2026-10-14-1822-02 | Abstimmung | kurzhantel | Kurzhantel-Seitheben | 241 ° / 135 ° | 0.25 / 0.10 | 0 |
| 2026-10-16-0936-02 | Abstimmung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 57 ° / 134 ° | 0.29 / 0.11 | 0 |
| 2026-10-16-0937-01 | Abstimmung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 60 ° / 125 ° | 0.38 / 0.11 | 0 |
| 2026-10-16-0940-01 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 72 ° / 113 ° | 0.13 / 0.72 | 0 |
| 2026-10-16-0940-02 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 55 ° / 141 ° | 0.40 / 0.10 | 0 |
| 2026-10-16-0941-01 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 50 ° / 50 ° | 0.60 / 0.59 | 0 |
| 2026-10-16-0944-01 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 120 ° / – | 0.83 / – | 0 |
| 2026-10-16-0945-01 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 48 ° / – | 0.28 / – | 0 |
| 2026-10-16-1145-02 | Abstimmung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 49 ° / 49 ° | 0.95 / 0.95 | 0 |
| 2026-10-16-1147-01 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 49 ° / 124 ° | 0.37 / 0.14 | 0 |
| 2026-10-16-1149-04 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 197 ° / – | 7.98 / – | 0 |
| 2026-10-16-1325-02 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 78 ° / 101 ° | 0.55 / 0.12 | 0 |
| 2026-10-16-1325-03 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 127 ° / 63 ° | 0.28 / 0.14 | 0 |
| 2026-10-16-1327-02 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – stehend | 78 ° / – | 0.39 / – | 0 |
| 2026-10-16-1327-04 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – stehend | 99 ° / – | 0.94 / – | 0 |
| 2026-10-18-1608-01 | Abstimmung | kurzhantel | Kurzhantel-Schrägbankdrücken | 187 ° / – | 5.83 / – | 0 |
| 2026-10-18-1611-02 | Abstimmung | kurzhantel | Kurzhantel-Schrägbankdrücken | 103 ° / – | 5.30 / – | 0 |
| 2026-10-18-1654-01 | Abstimmung | langhantel | High-Bar-Kniebeuge | 102 ° / 89 ° | 0.16 / 0.22 | 0 |
| 2026-10-26-1741-01 | Abstimmung | kurzhantel | Kurzhantel-Bankdrücken | 149 ° / 149 ° | 1.32 / 1.33 | 1 |
| 2026-10-26-1742-02 | Abstimmung | kurzhantel | Kurzhantel-Bankdrücken | 108 ° / – | 6.67 / – | 0 |
| 2026-10-26-1743-02 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 146 ° / 146 ° | 0.25 / 0.25 | 0 |
| 2026-10-26-1746-02 | Abstimmung | kurzhantel | Kurzhantel-Bankdrücken | 195 ° / – | 0.51 / – | 0 |
| 2026-10-26-1818-02 | Abstimmung | langhantel | High-Bar-Kniebeuge | 48 ° / – | 0.40 / – | 0 |
| 2026-10-26-1821-02 | Abstimmung | langhantel | High-Bar-Kniebeuge | 55 ° / 56 ° | 4.13 / 4.12 | 0 |
| 2026-11-03-1807-01 | Prüfung | kurzhantel | Kurzhantel-Seitheben | 194 ° / 103 ° | 0.09 / 6.69 | 0 |
| 2026-11-10-1822-01 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | – / 102 ° | – / 6.76 | 0 |
| 2026-11-10-1822-03 | Prüfung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 276 ° / 56 ° | 0.08 / 0.43 | 0 |
| 2026-11-23-2137-01 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl | 174 ° / 143 ° | 0.45 / 0.08 | 0 |

## Die zehn geeigneten Sätze mit dem größten Wiederholungsfehler (mit Start)

Je Zelle ohne Start / mit Start.

| Aufnahme | Teil | Art | Übung | Wiederholungen | Hub | Wdh.-Fehler | Sicher |
|---|---|---|---|---|---|---|---|
| 2026-10-26-1821-02 | Abstimmung | langhantel | High-Bar-Kniebeuge | 10 | 55 ° / 56 ° | 21.0 / 23.0 | 12 % / 12 % |
| 2026-11-03-1807-01 | Prüfung | kurzhantel | Kurzhantel-Seitheben | 19 | 194 ° / 103 ° | 16.0 / 17.0 | 100 % / 0 % |
| 2026-11-10-1830-03 | Prüfung | kurzhantel | Kurzhantelrudern – einarmig, abgestützt | 16 | 213 ° / 213 ° | 13.0 / 13.0 | 100 % / 100 % |
| 2026-11-03-1805-02 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 10 | 199 ° / 199 ° | 8.0 / 8.0 | 100 % / 100 % |
| 2026-11-10-1822-01 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 10 | 0 ° / 102 ° | 9.0 / 8.0 | 0 % / 0 % |
| 2026-10-08-0852-01 | Abstimmung | koerper | Brust | 10 | 108 ° / 109 ° | 7.0 / 7.0 | 100 % / 100 % |
| 2026-10-16-1145-02 | Abstimmung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 8 | 49 ° / 49 ° | 5.0 / 5.0 | 79 % / 79 % |
| 2026-10-18-1654-01 | Abstimmung | langhantel | High-Bar-Kniebeuge | 28 | 102 ° / 89 ° | 5.0 / 5.0 | 100 % / 100 % |
| 2026-10-26-1741-01 | Abstimmung | kurzhantel | Kurzhantel-Bankdrücken | 20 | 149 ° / 149 ° | 4.5 / 4.5 | 100 % / 100 % |
| 2026-10-08-0846-02 | Abstimmung | kurzhantel | Rudern sitzend | 10 | 89 ° / 89 ° | 3.0 / 4.0 | 100 % / 100 % |

## Wo der Winkel trägt

Je Befestigungsart und Übung (`kontext.exerciseName`): Aufnahmen und wie viele davon mit Start einen Hub von mindestens 40° erreichen.

| Art | Übung | Aufnahmen | davon ab 40° |
|---|---|---|---|
| stapel | Latzug · Obergriff | 9 | 0 |
| stapel | Bauchbeugen am Gerät | 8 | 0 |
| stapel | Abduktorenmaschine | 7 | 0 |
| stapel | Schulterpresse | 6 | 0 |
| stapel | Adduktorenmaschine | 5 | 0 |
| stapel | Brustpresse – Obergriff | 3 | 0 |
| stapel | Butterfly – Handgriffe | 3 | 0 |
| stapel | Hip Thrust am Gerät | 3 | 0 |
| stapel | Latziehen an der Hebelmaschine | 3 | 0 |
| stapel | Trizepsstrecken am Gerät | 3 | 0 |
| stapel | Beinpresse – 45 Grad | 2 | 0 |
| stapel | Kabelrudern – enger Neutralgriff | 2 | 0 |
| stapel | Rudern am Gerät – enger Neutralgriff | 2 | 0 |
| stapel | Wadenheben – stehend | 2 | 0 |
| langhantel | High-Bar-Kniebeuge | 7 | 3 |
| langhantel | Langhantelrudern – Obergriff | 4 | 0 |
| langhantel | Langhantel-Bankdrücken | 3 | 0 |
| langhantel | Beinpresse | 1 | 0 |
| langhantel | Kabelzug hoch | 1 | 1 |
| langhantel | Rumänisches Kreuzheben – Langhantel | 1 | 0 |
| kurzhantel | Kurzhantel-Bizepscurl – stehend | 24 | 15 |
| kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 12 | 7 |
| kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 11 | 11 |
| kurzhantel | Kurzhantel-Seitheben | 10 | 7 |
| kurzhantel | Kurzhantel-Schrägbankdrücken | 7 | 3 |
| kurzhantel | Kurzhantel-Bankdrücken | 5 | 1 |
| kurzhantel | Kurzhantel-Bizepscurl | 5 | 5 |
| kurzhantel | Kurzhantelrudern – einarmig, abgestützt | 5 | 1 |
| kurzhantel | Kurzhantel-Hammercurl | 3 | 3 |
| kurzhantel | Kurzhantel-Schulterdrücken – stehend | 3 | 0 |
| kurzhantel | Kurzhantel-Seitheben – sitzend | 3 | 3 |
| kurzhantel | Bankdrücken | 2 | 0 |
| kurzhantel | Schrägbankdrücken Kurzhantel | 2 | 0 |
| kurzhantel | Seitheben | 2 | 2 |
| kurzhantel | Rudern sitzend | 1 | 1 |
| koerper | Brust | 1 | 1 |

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
