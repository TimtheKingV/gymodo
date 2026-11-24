# Winkellage

Erzeugt von `WinkelBerichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.

Der Winkel ist eine direkte Messung der Lage der Last; deshalb wird die `Winkellage` hier gegen die gezählten Wiederholungen geprüft, nicht gegen eine nachträgliche Rechnung.

Signal: Drehung der Schwerkraftrichtung ĝ = (−sin p, sin r · cos p, cos r · cos p) aus Roll r und Pitch p gegenüber der Ruherichtung, in der Drehebene der ersten Bewegung gemessen und über ±180° entfaltet. Es hat keine Sprungstelle bei Pitch ±90°. Grenze: Eine Drehung um die Senkrechte (waagerecht schwenkende Hebelarme) ändert die Schwerkraftrichtung nicht und ist für den Winkel unsichtbar.

Auswahl: alle Aufnahmen mit bekannter Wiederholungszahl ≥ 5, auch ohne oder mit anderer Befestigungsart: `repsWahr` aus `korrekturen.json`, bei den Mac-Aufnahmen mit Metronom (`tempo` in `aufnahme.json`) die von Hand gezählten Perioden aus `label.reps`. Live-Lauf ohne gemerkten Hub; Lücken gehen an die `Winkellage`.
Sätze gelesen: 171, ausgelassen: 0 (ohne `messwerte.csv`).
„geeignet“: gemerkter Hub am Satzende ≥ 40°. Wdh.-Fehler = Median von |Umkehrpunkte/2 − Wiederholungen|; Sicher = Anteil sicherer Messwerte zwischen dem dritten und letzten Umkehrpunkt; Streuung = Standardabweichung/Mittel des Hubs je Wiederholung; „Sprung“ = ein Schritt der Lage über 0.2 zwischen zwei Messwerten (Lücken nicht ausgenommen).
„tragfähig“: Wdh.-Fehler ≤ 1, Sicher ≥ 0.9 und kein Satz mit Sprung.

Jede Zelle zeigt zwei Läufe: **ohne Start / geschätzter Start**. „Ohne Start“: die `Winkellage` legt die Ruherichtung mit der ersten Bewegung fest; das Aufnehmen der Hantel zählt mit, die ganze Aufnahme läuft durch. „Geschätzter Start“: diese Aufnahmen haben keine Start-Marke. Der Start wird nachträglich aus der ganzen Aufnahme geraten (Satzband = Mittelrichtung von ĝ über die mittlere Hälfte der Aufnahme, Radius = größter Abstand dort + 15°; aktiver Teil = der zusammenhängende Abschnitt im Satzband um diese Mitte; `los()` am Ende des ersten Stillstands (0.5 s, 4°), der in den ersten 2 s dieses Abschnitts beginnt, ohne Stillstand dort am ersten Messwert, an dem die Drehung unter 20 °/s fällt). **Diese Schätzung kann falsch sein; ein Fehler in dieser Spalte kann von der Schätzung kommen und nicht von der `Winkellage`.** Die Sätze, bei denen der geschätzte Start schlechter ist als ohne Start, stehen unten einzeln. Ausnahme: In den Zeilen „mit Los-Marke“ (Mac-Aufnahmen) ist die zweite Zahl der echte Ablauf, `los()` an `# los`, Ende an `# ende`.
Kein Start bestimmbar: keine.

Die Kennzahlen jedes Laufs sind Mediane über die Sätze, die **in diesem Lauf** geeignet sind; die Mengen unterscheiden sich. „nur in einem Lauf geeignet“ zählt Sätze, die nur ohne Start / nur mit Start geeignet sind. Der faire Vergleich steht je Teil in der Tabelle „in beiden Läufen geeignet“.

## Abstimmung (vor 2026-11-01)

| Art | Sätze | geeignet | nur in einem Lauf geeignet | Hub (Median) | Wdh.-Fehler | Sicher | Streuung | Sätze mit Sprung | tragfähig |
|---|---|---|---|---|---|---|---|---|---|
| stapel | 50 | 0 / 0 | 0 / 0 | – / – | – / – | – / – | – / – | – / – | nein / nein |
| langhantel | 17 | 6 / 4 | 3 / 1 | 59 ° / 73 ° | 4.5 / 3.5 | 90 % / 88 % | 0.773 / 1.404 | 3 / 3 | nein / nein |
| kurzhantel | 63 | 47 / 39 | 11 / 3 | 108 ° / 117 ° | 1.5 / 1.0 | 100 % / 100 % | 0.307 / 0.119 | 20 / 5 | nein / nein |
| koerper | 1 | 1 / 1 | 0 / 0 | 108 ° / 109 ° | 7.0 / 7.0 | 100 % / 100 % | 0.534 / 0.529 | 0 / 0 | nein / nein |

### Abstimmung: in beiden Läufen geeignet

| Art | Sätze | Wdh.-Fehler | Sicher | Sätze mit Sprung |
|---|---|---|---|---|
| stapel | 0 | – | – | – |
| langhantel | 3 | 5.0 / 5.0 | 96 % / 96 % | 2 / 3 |
| kurzhantel | 36 | 1.0 / 1.0 | 100 % / 100 % | 11 / 5 |
| koerper | 1 | 7.0 / 7.0 | 100 % / 100 % | 0 / 0 |

## Prüfung (ab 2026-11-01)

| Art | Sätze | geeignet | nur in einem Lauf geeignet | Hub (Median) | Wdh.-Fehler | Sicher | Streuung | Sätze mit Sprung | tragfähig |
|---|---|---|---|---|---|---|---|---|---|
| stapel | 8 | 0 / 0 | 0 / 0 | – / – | – / – | – / – | – / – | – / – | nein / nein |
| kurzhantel | 21 | 15 / 13 | 3 / 1 | 195 ° / 160 ° | 1.0 / 1.0 | 100 % / 100 % | 0.256 / 0.086 | 0 / 3 | ja / nein |
| kurzhantel mit Los-Marke | 11 | 7 / 7 | 0 / 0 | 149 ° / 134 ° | 1.0 / 0.5 | 100 % / 100 % | 0.050 / 0.049 | 1 / 0 | nein / ja |

### Prüfung: in beiden Läufen geeignet

| Art | Sätze | Wdh.-Fehler | Sicher | Sätze mit Sprung |
|---|---|---|---|---|
| stapel | 0 | – | – | – |
| kurzhantel | 12 | 0.5 / 0.8 | 100 % / 100 % | 0 / 2 |
| kurzhantel mit Los-Marke | 7 | 1.0 / 0.5 | 100 % / 100 % | 1 / 0 |

## Aufnahmen mit Los-Marke

Echter Ablauf: `los()` am ersten Messwert ab `# los`; eingespeist werden die Messwerte nur bis vor den ersten mit t ≥ `# ende` (die Taste, mit der das Mitglied den Satz beendet; in der App hält dort die `Winkellage` an). Ohne Start läuft die ganze Aufnahme, auch das Ablegen nach dem Satz und die 5 s danach zählen als Satzzeit. Wiederholungen = `label.reps`, die von Hand gezählten vollen Metronom-Perioden; Taktgipfel = Zahl der Zeilen `# takt oben`.

Mit Los-Marke bis Ende, über die 7 geeigneten: Wdh.-Fehler im Median 0.5 (Schwelle ≤ 1); zu viel erkannt: 2144-01, 2147-01, 2149-01, davon höchstens so viele wie Taktgipfel: 2144-01, 2147-01, 2149-01 (das Mitglied hat zum letzten Taktgipfel noch gehoben, `label.reps` zählt diese letzte, nicht volle Periode nicht); zu wenig: 2137-01; halbe Werte: 2137-01, 2144-01 (der Satz endete an `# ende` vor dem letzten unteren Umkehrpunkt). Nicht geeignet und in keinem Median: 2152-01 (Schrägbankdrücken Kurzhantel), 2153-01 (Schrägbankdrücken Kurzhantel), 2154-01 (Bankdrücken), 2155-01 (Bankdrücken); der Sensor dreht sich dort nur um 19–25° (größter Ausschlag), unter dem Mindesthub von 40°.

| Aufnahme | Übung | Wiederholungen | Taktgipfel | erkannt ganze Aufnahme (ohne Start) | erkannt los bis ende | Hub | Sicher | größter Schritt |
|---|---|---|---|---|---|---|---|---|
| 2026-11-23-2137-01 | Kurzhantel-Bizepscurl | 23 | 23 | 25.0 | 22.5 | 143 ° | 100 % | 0.08 |
| 2026-11-23-2144-01 | Kurzhantel-Bizepscurl | 21 | 22 | 22.0 | 21.5 | 157 ° | 100 % | 0.09 |
| 2026-11-23-2146-01 | Kurzhantel-Bizepscurl | 7 | 8 | 7.0 | 7.0 | 125 ° | 100 % | 0.07 |
| 2026-11-23-2147-01 | Kurzhantel-Bizepscurl | 6 | 7 | 7.0 | 7.0 | 134 ° | 100 % | 0.08 |
| 2026-11-23-2148-01 | Kurzhantel-Bizepscurl | 10 | 10 | 10.0 | 10.0 | 135 ° | 100 % | 0.08 |
| 2026-11-23-2149-01 | Seitheben | 14 | 15 | 15.0 | 15.0 | 86 ° | 100 % | 0.12 |
| 2026-11-23-2150-01 | Seitheben | 10 | 10 | 10.0 | 10.0 | 92 ° | 100 % | 0.05 |
| 2026-11-23-2152-01 | Schrägbankdrücken Kurzhantel | 9 | 10 | 3.0 | 3.5 | 21 ° | 0 % | 0.31 |
| 2026-11-23-2153-01 | Schrägbankdrücken Kurzhantel | 8 | 8 | 0.0 | 0.0 | – | 0 % | 0.09 |
| 2026-11-23-2154-01 | Bankdrücken | 10 | 10 | 0.0 | 1.0 | – | 0 % | 0.28 |
| 2026-11-23-2155-01 | Bankdrücken | 9 | 10 | 1.0 | 1.0 | – | 0 % | 0.10 |

## Geschätzter Start schlechter als ohne Start

Aufnahmen ohne Los-Marke, in mindestens einem Lauf geeignet, bei denen der Wdh.-Fehler mit geschätztem Start größer ist oder der größte Schritt über 0.2 liegt und größer ist als ohne Start: 26. Je Zelle ohne Start / geschätzter Start.

| Aufnahme | Teil | Art | Übung | Wiederholungen | Hub | Wdh.-Fehler | größter Schritt |
|---|---|---|---|---|---|---|---|
| 2026-10-08-0846-02 | Abstimmung | kurzhantel | Rudern sitzend | 10 | 89 ° / 89 ° | 3.0 / 4.0 | 0.14 / 0.14 |
| 2026-10-14-1826-02 | Abstimmung | kurzhantel | Kurzhantel-Seitheben | 10 | 53 ° / 110 ° | 0.0 / 1.0 | 0.10 / 0.06 |
| 2026-10-14-1827-02 | Abstimmung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 12 | 158 ° / 158 ° | 0.0 / 1.0 | 0.08 / 0.09 |
| 2026-10-16-0940-01 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 10 | 72 ° / 113 ° | 1.0 / 1.0 | 0.13 / 0.72 |
| 2026-10-16-0944-01 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 8 | 120 ° / 34 ° | 2.0 / 2.5 | 0.83 / 0.28 |
| 2026-10-16-0945-01 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 10 | 48 ° / 0 ° | 6.0 / 9.5 | 0.28 / 0.11 |
| 2026-10-16-1149-04 | Abstimmung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 6 | 197 ° / 39 ° | 1.5 / 5.5 | 7.98 / 0.57 |
| 2026-10-16-1326-01 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 6 | 237 ° / 118 ° | 1.0 / 1.5 | 0.09 / 0.16 |
| 2026-10-18-1606-02 | Abstimmung | kurzhantel | Kurzhantel-Seitheben – sitzend | 14 | 121 ° / 113 ° | 1.0 / 1.5 | 0.10 / 0.11 |
| 2026-10-18-1608-01 | Abstimmung | kurzhantel | Kurzhantel-Schrägbankdrücken | 15 | 187 ° / 23 ° | 6.0 / 12.0 | 5.83 / 0.71 |
| 2026-10-18-1654-01 | Abstimmung | langhantel | High-Bar-Kniebeuge | 28 | 102 ° / 89 ° | 5.0 / 5.0 | 0.16 / 0.22 |
| 2026-10-18-1656-02 | Abstimmung | langhantel | Langhantelrudern – Obergriff | 30 | 56 ° / 28 ° | 0.0 / 5.0 | 0.17 / 0.29 |
| 2026-10-18-1702-01 | Abstimmung | langhantel | Langhantelrudern – Obergriff | 25 | 61 ° / 21 ° | 4.0 / 22.0 | 0.12 / 0.37 |
| 2026-10-26-1741-01 | Abstimmung | kurzhantel | Kurzhantel-Bankdrücken | 20 | 149 ° / 149 ° | 4.5 / 4.5 | 1.32 / 1.33 |
| 2026-10-26-1742-02 | Abstimmung | kurzhantel | Kurzhantel-Bankdrücken | 9 | 108 ° / 0 ° | 7.0 / 9.0 | 6.67 / 0.10 |
| 2026-10-26-1747-04 | Abstimmung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 16 | 225 ° / 25 ° | 14.0 / 6.0 | 0.06 / 0.32 |
| 2026-10-26-1748-02 | Abstimmung | kurzhantel | Kurzhantel-Bankdrücken | 8 | 208 ° / 25 ° | 5.0 / 3.0 | 0.09 / 0.28 |
| 2026-10-26-1821-02 | Abstimmung | langhantel | High-Bar-Kniebeuge | 10 | 55 ° / 56 ° | 21.0 / 23.0 | 4.13 / 4.12 |
| 2026-11-03-1802-02 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 10 | 197 ° / 0 ° | 8.0 / 10.0 | 0.07 / 0.10 |
| 2026-11-03-1803-01 | Prüfung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 8 | 69 ° / 86 ° | 1.0 / 2.0 | 0.09 / 0.07 |
| 2026-11-03-1807-01 | Prüfung | kurzhantel | Kurzhantel-Seitheben | 19 | 194 ° / 103 ° | 16.0 / 17.0 | 0.09 / 6.69 |
| 2026-11-03-1809-01 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 7 | 195 ° / 0 ° | 5.0 / 6.0 | 0.06 / 0.42 |
| 2026-11-10-1822-01 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 10 | 0 ° / 102 ° | 9.0 / 8.0 | 0.07 / 6.76 |
| 2026-11-10-1822-03 | Prüfung | kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 5 | 276 ° / 56 ° | 0.0 / 0.5 | 0.08 / 0.43 |
| 2026-11-10-1824-01 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 9 | 198 ° / 22 ° | 6.0 / 5.0 | 0.11 / 0.78 |
| 2026-11-10-1825-04 | Prüfung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 10 | 168 ° / 170 ° | 2.0 / 3.0 | 0.07 / 0.08 |

## Geeignete Sätze mit Sprung

Je Zelle ohne Start / geschätzter Start (Mac: Los-Marke bis Ende); „–“: in diesem Lauf nicht geeignet.

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

## Die zehn geeigneten Sätze mit dem größten Wiederholungsfehler ohne Start

Je Zelle ohne Start / geschätzter Start (Mac: Los-Marke bis Ende).

| Aufnahme | Teil | Art | Übung | Wiederholungen | Hub | Wdh.-Fehler | Sicher |
|---|---|---|---|---|---|---|---|
| 2026-10-26-1821-02 | Abstimmung | langhantel | High-Bar-Kniebeuge | 10 | 55 ° / 56 ° | 21.0 / 23.0 | 12 % / 12 % |
| 2026-10-26-1746-02 | Abstimmung | kurzhantel | Kurzhantel-Bankdrücken | 9 | 195 ° / 27 ° | 20.0 / 7.0 | 100 % / 0 % |
| 2026-11-03-1807-01 | Prüfung | kurzhantel | Kurzhantel-Seitheben | 19 | 194 ° / 103 ° | 16.0 / 17.0 | 100 % / 0 % |
| 2026-10-26-1747-04 | Abstimmung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 16 | 225 ° / 25 ° | 14.0 / 6.0 | 100 % / 0 % |
| 2026-11-10-1830-03 | Prüfung | kurzhantel | Kurzhantelrudern – einarmig, abgestützt | 16 | 213 ° / 213 ° | 13.0 / 13.0 | 100 % / 100 % |
| 2026-10-18-1611-02 | Abstimmung | kurzhantel | Kurzhantel-Schrägbankdrücken | 12 | 103 ° / 23 ° | 10.0 / 7.0 | 0 % / 0 % |
| 2026-10-16-0940-02 | Abstimmung | kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 10 | 55 ° / 141 ° | 8.0 / 0.5 | 0 % / 100 % |
| 2026-11-03-1802-02 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 10 | 197 ° / 0 ° | 8.0 / 10.0 | 100 % / 0 % |
| 2026-11-03-1805-02 | Prüfung | kurzhantel | Kurzhantel-Bizepscurl – stehend | 10 | 199 ° / 199 ° | 8.0 / 8.0 | 100 % / 100 % |
| 2026-10-08-0852-01 | Abstimmung | koerper | Brust | 10 | 108 ° / 109 ° | 7.0 / 7.0 | 100 % / 100 % |

## Wo der Winkel trägt

Je Befestigungsart und Übung (`kontext.exerciseName`): Aufnahmen und wie viele davon einen Hub von mindestens 40° erreichen. Gezählt wird der Lauf ohne Start (kein nachträgliches Wissen), bei den Aufnahmen mit Los-Marke der Lauf von `# los` bis `# ende`.

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
| langhantel | Langhantelrudern – Obergriff | 4 | 2 |
| langhantel | Langhantel-Bankdrücken | 3 | 0 |
| langhantel | Beinpresse | 1 | 0 |
| langhantel | Kabelzug hoch | 1 | 1 |
| langhantel | Rumänisches Kreuzheben – Langhantel | 1 | 0 |
| kurzhantel | Kurzhantel-Bizepscurl – stehend | 24 | 17 |
| kurzhantel | Kurzhantel-Schulterdrücken – sitzend | 12 | 10 |
| kurzhantel | Trizepsstrecken über Kopf – eine Kurzhantel | 11 | 10 |
| kurzhantel | Kurzhantel-Seitheben | 10 | 7 |
| kurzhantel | Kurzhantel-Schrägbankdrücken | 7 | 5 |
| kurzhantel | Kurzhantel-Bankdrücken | 5 | 4 |
| kurzhantel | Kurzhantel-Bizepscurl | 5 | 5 |
| kurzhantel | Kurzhantelrudern – einarmig, abgestützt | 5 | 1 |
| kurzhantel | Kurzhantel-Hammercurl | 3 | 2 |
| kurzhantel | Kurzhantel-Schulterdrücken – stehend | 3 | 2 |
| kurzhantel | Kurzhantel-Seitheben – sitzend | 3 | 3 |
| kurzhantel | Bankdrücken | 2 | 0 |
| kurzhantel | Schrägbankdrücken Kurzhantel | 2 | 0 |
| kurzhantel | Seitheben | 2 | 2 |
| kurzhantel | Rudern sitzend | 1 | 1 |
| koerper | Brust | 1 | 1 |

## Winkel in Ruhe

Belegt die Konvention ĝ = (−sin p, sin r · cos p, cos r · cos p): Winkel zwischen ĝ aus Roll/Pitch und der gemessenen Beschleunigung an ruhenden Messwerten (Betrag auf 0,01 g bei 1 g, Drehrate unter 5 °/s, seit 0,5 s). Auswahl: stapel, kurzhantel, langhantel, `repsWahr` ≥ 5 aus `korrekturen.json`, ohne Lücke, ≥ 300 Messwerte. Über etwa 3° trüge die Konvention nicht.

| Art | ruhende Messwerte | Winkelfehler (Median) |
|---|---|---|
| stapel | 28304 | 1.66° |
| kurzhantel | 23725 | 1.35° |
| langhantel | 4946 | 1.48° |
