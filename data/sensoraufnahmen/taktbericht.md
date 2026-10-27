# Takt-Bericht (Satztakt, ganzer Satz)

Ziel: höchstens ±1 neben der Wahrheit. Erzeugt von `TaktBerichtTests.berichtSchreiben`.

**Grenzen:** Alle Sätze stammen von einer Person, ihren Geräten und vier Trainingstagen (14., 16., 18. und 26.10.); die Aussage gilt nur dafür. Beinpresse, Waden und Kniebeuge haben 2 bis 4 Sätze, die Blindprüfung ist dort nur ein Hinweis. Aufteilung: je Art jeder zweite Satz (nach Ordnername) zum Abstimmen, der Rest blind. Die Blindsätze wurden erst nach dem Einfrieren der Parameter gelesen; eine Ausnahme: Der erste Bericht vor jedem Abstimmen zeigte schon die Baseline der Blindsätze (Stapel 56 % bei ±1).

Seit der Lückenbehandlung werden Empfangsabstände über 0,5 s und explizite Abrisse getrennt ausgewertet. Hintergrund-Bündelung lässt sich anhand der Empfangszeiten nicht sicher von fehlenden Paketen unterscheiden. Solche Sätze bleiben unsicher; auch zuvor richtige Zahlen können sich ändern. Schwellen und Profile wurden unverändert gelassen.

### Abstimmung

| Art | Sätze | exakt | ±1 |
|---|---|---|---|
| stapel | 19 | 79 % | 95 % |
| langhantel | 6 | 33 % | 83 % |
| kurzhantel | 7 | 86 % | 86 % |
| **gepoolt** | 32 | 72 % | 91 % |

### Blindprüfung (nur Arten mit eingefrorenen Parametern: kurzhantel, langhantel, stapel)

| Art | Sätze | exakt | ±1 |
|---|---|---|---|
| stapel | 18 | 89 % | 94 % |
| langhantel | 5 | 40 % | 80 % |
| kurzhantel | 7 | 57 % | 86 % |
| **gepoolt** | 30 | 73 % | 90 % |

### Früher abgestimmt (Kurzhantel 16.10., nur Regressionsschutz)

| Art | Sätze | exakt | ±1 |
|---|---|---|---|
| kurzhantel | 35 | 80 % | 100 % |
| **gepoolt** | 35 | 80 % | 100 % |

### Gegenprobe 26.10. – aktuell neu berechnet

| Art | Sätze | exakt | ±1 |
|---|---|---|---|
| stapel | 12 | 100 % | 100 % |
| langhantel | 4 | 100 % | 100 % |
| kurzhantel | 11 | 73 % | 82 % |
| **gepoolt** | 27 | 89 % | 93 % |

### Gegenprobe 26.10. – unverändert gespeicherte App-Ergebnisse

| Art | Sätze | exakt | ±1 |
|---|---|---|---|
| stapel | 12 | 100 % | 100 % |
| langhantel | 4 | 100 % | 100 % |
| kurzhantel | 11 | 91 % | 100 % |
| **gepoolt** | 27 | 96 % | 100 % |

Tim hat alle 27 Labels unabhängig mitgezählt und bestätigt. Diese Einheit wurde nicht zur Profilabstimmung verwendet. Die Lückenbehandlung wurde nach Sichtung der Einheit geändert: der neue Replay ist eine Regression, keine unangesehene Blindprüfung.

| Ordner | Art | bestätigt | App gespeichert | Replay aktuell | unsicher |
|---|---|---|---|---|---|
| 2026-10-26-1729-01 | stapel | 12 | 12 | 12 | – |
| 2026-10-26-1731-01 | stapel | 12 | 12 | 12 | – |
| 2026-10-26-1733-01 | stapel | 12 | 12 | 12 | – |
| 2026-10-26-1735-01 | stapel | 12 | 12 | 12 | – |
| 2026-10-26-1736-01 | stapel | 12 | 12 | 12 | – |
| 2026-10-26-1738-01 | stapel | 12 | 12 | 12 | – |
| 2026-10-26-1808-01 | stapel | 25 | 25 | 25 | – |
| 2026-10-26-1809-02 | stapel | 36 | 36 | 36 | – |
| 2026-10-26-1810-02 | stapel | 25 | 25 | 25 | – |
| 2026-10-26-1811-02 | stapel | 30 | 30 | 30 | – |
| 2026-10-26-1813-02 | stapel | 18 | 18 | 18 | – |
| 2026-10-26-1813-04 | stapel | 20 | 20 | 20 | – |
| 2026-10-26-1816-01 | langhantel | 20 | 20 | 20 | – |
| 2026-10-26-1818-02 | langhantel | 14 | 14 | 14 | – |
| 2026-10-26-1820-02 | langhantel | 20 | 20 | 20 | – |
| 2026-10-26-1821-02 | langhantel | 10 | 10 | 10 | – |
| 2026-10-26-1741-01 | kurzhantel | 20 | 19 | 22 | luecke |
| 2026-10-26-1742-02 | kurzhantel | 9 | 9 | 10 | luecke |
| 2026-10-26-1743-02 | kurzhantel | 12 | 12 | 12 | – |
| 2026-10-26-1744-02 | kurzhantel | 10 | 10 | 10 | – |
| 2026-10-26-1745-02 | kurzhantel | 20 | 20 | 20 | – |
| 2026-10-26-1746-02 | kurzhantel | 9 | 9 | 9 | – |
| 2026-10-26-1747-02 | kurzhantel | 10 | 10 | 10 | – |
| 2026-10-26-1747-04 | kurzhantel | 16 | 16 | 20 | luecke |
| 2026-10-26-1748-02 | kurzhantel | 8 | 8 | 8 | signalSchwach |
| 2026-10-26-1749-02 | kurzhantel | 10 | 10 | 10 | – |
| 2026-10-26-1750-02 | kurzhantel | 20 | 20 | 20 | – |

### Sätze außerhalb ±1

| Ordner | Art | Gruppe | wahr | gezählt |
|---|---|---|---|---|
| 2026-10-18-1628-01 | stapel | abstimmen | 12 | 1 |
| 2026-10-18-1630-01 | stapel | blind | 14 | – |
| 2026-10-18-1623-01 | langhantel | abstimmen | 12 | 7 |
| 2026-10-18-1658-03 | langhantel | blind | 30 | 33 |
| 2026-10-18-1611-02 | kurzhantel | abstimmen | 12 | 8 |
| 2026-10-18-1614-02 | kurzhantel | blind | 9 | 6 |
| 2026-10-26-1741-01 | kurzhantel | gegenprobe | 20 | 22 |
| 2026-10-26-1747-04 | kurzhantel | gegenprobe | 16 | 20 |
