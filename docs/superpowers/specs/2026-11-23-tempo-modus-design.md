# iOS Member-App — Bewegungssensor: Tempo-Modus (Teilprojekt C)

**Stand:** 23. November 2026
**Status:** Entwurf, gegengelesen, wartet auf Tims Freigabe. Danach Umsetzungsplan.
**Vorbedingung:** Teilprojekt A und B (`2026-09-19-sensor-anbindung-aufzeichnung-design.md`, `2026-10-10-sensor-wiederholungszaehler-design.md`, im Folgenden „Spec A“ und „Spec B“) samt Satztakt und Satzautomatik sind auf `master`.
**Bildentwürfe:** https://claude.ai/artifact/7fSsT27eVcYq3PBNTbdJLJ (privat, nur für Tim). Maßgeblich sind die Bilder „A · Welle im Vollbild“, „A1 · Start“, „A2 · Ziel in Sicht“ und „D · Satzende“. B und C sind verworfen.
**Wer was entschieden hat:** „Tim“ heißt im Gespräch entschieden. „Vorschlag“ heißt von Claude festgelegt und von Tim nicht ausdrücklich bestätigt; beim Lesen prüfen.

---

## 1. Warum und was

Mitglieder sollen Kraftübungen im sauberen Tempo ausführen. Vorbild ist die Anzeige an eGym-Geräten: Eine wellenförmige Bahn läuft über den Bildschirm, ein Punkt zeigt die eigene Bewegung, und wer den Punkt in der Bahn hält, bewegt sich im richtigen Tempo.

Der Tempo-Modus ist ein zuschaltbarer Modus der Übungsansicht. Er nutzt den vorhandenen Bewegungssensor (WitMotion WT9011DCL-BT50), schätzt daraus live die Position der Last im Bewegungsumfang und zeigt sie als Punkt vor einer Soll-Welle. Am Satzende steht eine Trefferquote.

**Erfolg heißt:** Tim trainiert am Gerät einen Satz Latzug (Stapel) und einen Satz mit der Kurzhantel im Tempo-Modus, der Punkt folgt der Bewegung ohne spürbare Verzögerung und ohne wegzulaufen, und die Trefferquote am Ende deckt sich mit dem eigenen Eindruck.

## 2. Entscheidungen

| # | Frage | Entscheidung | Von |
|---|---|---|---|
| 1 | Für welche Befestigungen | Stapel und Hanteln von Anfang an | Tim |
| 2 | Was der Punkt zeigt | Geschätzte Position, die an jedem Umkehrpunkt neu einrastet (Weg C, Abschnitt 5) | Tim |
| 3 | Anzeige | Welle im Vollbild, ersetzt während des Satzes die Räder | Tim |
| 4 | Form der Welle | Flacher Ausschlag, Bahn im Verhältnis breit (Bild A) | Tim |
| 5 | Soll-Tempo | Ein Standard für alle Übungen; Kraftweg schneller als Ablassen | Tim |
| 6 | Werte des Standards | 1,5 s Kraftweg, 2,5 s Ablassen | Vorschlag |
| 7 | Tempo verstellen | Im Modus, je Weg in Schritten von 0,5 s zwischen 1 und 4 s; gilt für alle Übungen, lokal gespeichert | Vorschlag |
| 8 | Start | Flache Linie läuft heran, an einer Los-Marke beginnt die Welle | Tim |
| 9 | Ende | Zielmarke nach der Soll-Wiederholungszahl; die Bahn läuft gedämpft weiter, man kann weitermachen | Tim |
| 10 | Bewegungsumfang | Vom letzten Satz dieser Übung gemerkt, in den ersten zwei Wiederholungen nachgeführt | Tim |
| 11 | Ergebnis | Trefferquote am Satzende, nicht gespeichert | Tim |
| 12 | Trefferquote | Anteil der Zeit, in der der Punkt in der Bahn liegt; zählt ab der dritten Wiederholung bis zum Satzende, auch über das Ziel hinaus | Vorschlag |
| 13 | Punkte auf der Welle | Reine Taktmarken, leuchten auf, wenn man sie in der Bahn passiert. Kein Punktestand. | Vorschlag |
| 14 | Welcher Weg der Kraftweg ist | Hebt sich die Last, ist das der Kraftweg (Abschnitt 6.3) | Vorschlag |
| 15 | Einschalten | Schalter in der Übungsansicht; nur bei Kraftübungen mit Wiederholungen, verbundenem Sensor und freigegebener Befestigungsart | Vorschlag |
| 16 | Sichtbarkeit | Wie die übrige Sensorik nur im Debug-Build | Vorschlag |
| 17 | Ziel bei einer Spanne im Plan (z. B. 8–12) | Die Zielmarke steht an der Obergrenze | Vorschlag |
| 18 | Sichern am Satzende | Der Satz wird beim Ende sofort gesichert, die Pause läuft; die Auswertung liegt über der Pause | Vorschlag |
| 19 | Was eine „Wiederholung“ in der Auswertung ist | Eine Periode der Soll-Welle, nicht eine erkannte Wiederholung | Vorschlag |
| 20 | Zirkel | Kein Tempo-Modus im Zirkel | Vorschlag |
| 21 | Beginn des zweiten und jedes weiteren Satzes | Von selbst bei Pausenablauf, mit flacher Linie und Los-Marke (Abschnitt 7.3) | Tim |

## 3. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**
- Der Punkt folgt der echten Bewegung, auch einem Stocken mitten im Weg.
- Start und Ziel sind ohne Lesen erkennbar.
- Die Anzeige ist aus etwa einem Meter Abstand lesbar (das Handy liegt beim Training meist weg).
- Kein Eingriff in Datenbank, API oder Trainerportal.

**Nicht-Ziele**
- Soll-Tempo je Übung im Katalog oder je Planposition, Tempo aus einem Trainingsziel. Der Standard wird so abgelegt, dass ein solcher Wert ihn später ersetzen kann (Abschnitt 7.1).
- Trefferquote speichern oder im Trainerportal zeigen.
- Geschwindigkeit oder Weg in m/s bzw. cm anzeigen. Die Zentimeter aus der Schätzung sind nicht belastbar, nur das Verhältnis zum eigenen Umfang.
- Kabel, Hebel und Körper als Befestigungsart. Dafür fehlen Aufnahmen mit bekannter Wahrheit.
- Freigabe für Mitglieder (Release).

**Anti-Ziele**
- Ein Punkt, der bei sauberem Training aus der Bahn wandert. Lieber schaltet sich der Modus für eine Befestigungsart nicht frei.
- Ein Punkt, der nur den Takt nachbildet und Fehler erst eine halbe Wiederholung später zeigt.
- Der Tempo-Modus darf weder das Zählen noch das Sichern eines Satzes verschlechtern oder blockieren.

## 4. Was heute da ist

- Sensor: 50 Hz, Beschleunigung (g), Drehrate (°/s), Winkel (°). Kein Zeitstempel vom Sensor; `t` ist die Empfangszeit am iPhone, Pakete kommen gebündelt mit etwa 30 ms Auflösung. BLE-Lücken werden abschnittsweise behandelt (PR #87).
- `Packages/Sensorik`: `Zaehler` (live, Halbwellen, Profile je Befestigungsart), `Satztakt` und `Phasenzaehler` (nachträglich), `SatzAutomatik` (Start nach 2 Wiederholungen, Ende nach 8 s Ruhe). Der Zähler liefert je Wiederholung Beginn, Umkehr, Ende, kennt aber nur Hin- und Rückweg, nicht welcher der Kraftweg ist.
- Eine anzeigbare Position oder Geschwindigkeit gibt es nicht.
- Naht zur App: `Workout/SatzZaehler.swift`, `Workout/Sensor/ZaehlerKoordinator.swift`. Abspielen von Aufnahmen: `AbspielSensorQuelle.swift`.
- Übungsansicht: `Screens/Geraet/GeraetView.swift` und `GeraetModel.swift`, Phasen `bereit` (Countdown) → `eingabe` (Räder) → `pause` → `abschluss`. Reines SwiftUI; `Canvas`/`TimelineView` sind schon im Einsatz (`Minikurve`, `PausenRad`, `Trainingsuhr`).
- Aufnahmen: `data/sensoraufnahmen/`, Wahrheit in `korrekturen.json` (`repsWahr`, `befestigungsart`).

**Nachrechnung vom 23. November** (148 lückenlose Aufnahmen mit `repsWahr` ≥ 5; Beschleunigung auf die Schwerkraftrichtung projiziert, zweimal aufsummiert, je über eine Periode vom Mittelwert befreit, auf den aktiven Teil des Satzes beschnitten):

| Befestigung | Sätze | Hub schwankt von Wdh. zu Wdh. (Median) | Abweichung erkannte Wdh. (Median) |
|---|---|---|---|
| Stapel | 58 | 13 % | 0 |
| Kurzhantel | 73 | 17 % | 1 |
| Langhantel | 17 | 18 % | 4 |

Der Neigungswinkel taugt nicht als allgemeiner Weg für Hanteln: Bei vielen Kurzhantel-Sätzen dreht sich die Hantel kaum, der Winkelhub schwankt dort etwa doppelt so stark (31 %). Die Rechnung kannte jeweils den ganzen Satz; die Verzögerung im Live-Betrieb ist **nicht** gemessen.

Das Skript liegt unter `tools/sensorik-sim/tempo_nachrechnung.py` (Aufruf und Auswahlregeln im Kopf der Datei). Es ist der Bezug für das Gütetor in Abschnitt 6.4. Bei drehender Hantel nähert es die Schwerkraftrichtung nur über das Mittel der Beschleunigung; die Zentimeter-Werte sind dort unbrauchbar, das Verhältnis von Wiederholung zu Wiederholung trägt.

## 5. Wege

**A – Reine Positionsschätzung.** Beschleunigung laufend zur Position aufsummieren, der Punkt zeigt genau das. Reagiert sofort, wandert aber über den Satz weg.

**B – Nur Takt.** Aus den Umkehrpunkten des Zählers eine glatte Bewegung nachbilden. Ruhig und erprobt, zeigt aber nicht die echte Bewegung; Fehler erscheinen eine halbe Wiederholung zu spät.

**C – Schätzung mit Einrasten an den Umkehrpunkten.** Wie A, aber an jedem erkannten Umkehrpunkt werden Nullpunkt und Hub neu gesetzt. Folgt der echten Bewegung und kann nicht dauerhaft weglaufen. Preis: ein möglicher kleiner Sprung beim Einrasten, der geglättet werden muss, und Abhängigkeit von der Umkehrerkennung.

**Gewählt: C** (Tim). A scheitert am Wegdriften, B verfehlt den Kern der Idee. Die Nachrechnung in Abschnitt 4 entspricht im Prinzip C.

## 6. Positionsschätzung (Package `Sensorik`)

### 6.1 Was sie liefert

Ein neuer, reiner Baustein in `Packages/Sensorik`, gespeist mit denselben `SensorMesswert`en wie der Zähler. Je Messwert liefert er:

- `lage`: Position im eigenen Bewegungsumfang, 0 = Ruhelage der Last (unten), 1 = oberer Umkehrpunkt. Werte leicht außerhalb sind erlaubt.
- `richtung`: Kraftweg, Ablassen oder unbekannt.
- `sicher`: ob die Schätzung gerade trägt (nach Lücken, in Ruhe und vor dem ersten Einrasten nicht).

Für alle freigegebenen Befestigungsarten gilt derselbe Weg über die Beschleunigung. Der Winkel wird in diesem Projekt nicht genutzt.

### 6.2 Einrasten und Umfang

- An jedem Umkehrpunkt werden Nullpunkt und Hub neu gesetzt. Die Umkehrpunkte erkennt die Schätzung selbst. Der vorhandene Live-`Zaehler` taugt dafür nicht: Er rechnet bei Hanteln auf der Drehrate (`ZaehlerProfil.swift`), hält nach einer Lücke für den Rest des Satzes an (`Zaehler.swift`), und die angezeigte Zahl für Stapel und Hantel kommt aus `Satztakt`, höchstens einmal pro Sekunde.
- Der Sprung beim Einrasten wird über kurze Zeit ausgeglichen, sodass der Punkt nicht springt.
- **Umfang merken:** Der Hub des letzten Satzes wird je Station und Übung lokal auf dem Gerät gespeichert (kein Server), nach dem Muster von `Workout/Sensor/Befestigungsspeicher.swift`. Der nächste Satz startet damit und führt ihn in den ersten zwei Wiederholungen nach. Ohne gemerkten Wert (erster Satz einer Übung) wächst der Umfang mit den beobachteten Umkehrpunkten; der Punkt kann in dieser Zeit daneben liegen. Die Trefferquote zählt deshalb immer erst ab der dritten Wiederholung.
- BLE-Lücke oder Empfangsabstand über 0,5 s: Die Schätzung meldet `sicher = false` bis zum nächsten Umkehrpunkt.

### 6.3 Kraftweg

Die Schwerkraftrichtung ist aus der Beschleunigung bekannt. Regel: **Bewegt sich die Last nach oben, ist das der Kraftweg.** Das gilt am Stapel immer und bei Hanteln in aller Regel, auch wenn die Übung mit dem Ablassen beginnt (Kniebeuge, Bankdrücken).

- Beginnt die erste Bewegung abwärts, dreht die App die Welle einmal um (flache Linie oben, erster Weg abwärts mit dem Ablass-Tempo) und merkt sich das zusammen mit dem Umfang für diese Übung.
- Läuft die Bewegung überwiegend waagerecht, greift die Regel nicht. Dann gilt für beide Wege dieselbe Dauer (Mittel aus beiden Werten), und das Satzende spricht von „Hinweg“ und „Rückweg“. Die Schwelle legt der Bauende anhand der Aufnahmen fest.

### 6.4 Gütetor

Vor jeder Anzeige wird die Schätzung gegen die Aufnahmen abgespielt (E1) und ein Bericht `data/sensoraufnahmen/tempobericht.md` erzeugt, nach dem Muster von `guetebericht.md`. Bezug ist die nachträgliche Rechnung aus Abschnitt 4 auf derselben Aufnahme.

Eine Befestigungsart wird für den Tempo-Modus freigegeben, wenn über ihre Aufnahmen gilt (Vorschlag, in E1 mit Tim nachzuschärfen, sobald Zahlen vorliegen):

- Verzögerung der Live-Schätzung gegenüber dem Bezug im Median höchstens 150 ms,
- mittlere Abweichung der `lage` höchstens 15 % des Hubs,
- kein Satz, in dem die Schätzung länger als eine Wiederholung außerhalb von −0,25 … 1,25 liegt.

Erwartung: Stapel und Kurzhantel bestehen, die Langhantel ist offen. Besteht sie nicht, bleibt der Schalter dort aus; das ist kein Scheitern des Projekts.

## 7. Welle und Ablauf (App)

### 7.1 Soll-Welle

- Je Wiederholung ein Kraftweg und ein Ablassen, jeweils als weicher Übergang zwischen unten und oben (Kosinus-Flanke), ohne Haltezeit an den Umkehrpunkten.
- Das Tempo ist ein kleiner Wert `Tempovorgabe(kraftweg:ablassen:)`. Er kommt heute aus dem lokal gespeicherten Standard (1,5 s / 2,5 s) und wird an einer Stelle bezogen, an der später ein Wert aus Katalog oder Plan ihn ersetzen kann.
- Die Welle ist feste Zeitvorgabe ab der Los-Marke. Sie passt sich nicht an das Mitglied an: Wer langsamer wird, fällt hinter die Bahn.

### 7.2 Anzeige (Bild A)

- Die Bahn füllt etwa die obere Bildschirmhälfte. Sie läuft von rechts nach links; der eigene Punkt steht an einer festen senkrechten „Jetzt“-Linie im linken Drittel und bewegt sich nur auf und ab.
- Sichtbar sind rund zwei Wiederholungen voraus. Der Ausschlag ist flach, die Bahn etwa ±20 % des Bewegungsumfangs breit. Die genaue Breite wird am Gerät eingestellt.
- Der Teil links der Jetzt-Linie ist abgedunkelt.
- Taktmarken sitzen an den Umkehrpunkten und in der Mitte jedes Wegs. Passiert der Punkt eine Marke innerhalb der Bahn, leuchtet sie auf.
- Darunter: Wiederholungen (Ist / Soll), Gewicht, laufende Trefferquote. Unten „Satz beenden“.
- Farben und Schrift aus dem Designsystem (`DesignSystem.swift`): Bahn `accentMuted`, Punkt `accent`, Grund `bg`.
- Ist `sicher = false`, wird der Punkt blass dargestellt und die Zeit zählt nicht in die Trefferquote.
- Gezeichnet wird mit `Canvas`/`TimelineView`; die Welle hängt allein an der Uhr, der Punkt an der letzten Schätzung.

### 7.3 Start (Bild A1)

- Erster Satz: Mit eingeschaltetem Tempo-Modus zeigt die Phase `bereit` (nach „Übung starten“) statt des Zahlen-Countdowns die Bahn als flache Linie auf Höhe der Ruhelage. Der Punkt ruht darin. Anders als der heutige Countdown lässt sich der Vorlauf nicht per Tipp überspringen.
- Zweiter und jeder weitere Satz: Läuft die Pause ab, erscheint von selbst die flache Linie mit demselben Vorlauf und der Los-Marke. Ein Tipp in der Pause startet den Vorlauf früher.
- Im Tempo-Modus beginnt die Satzautomatik keinen Satz, auch nicht aus der Pause heraus. Bewegung während der Pause oder des Vorlaufs löst nichts aus.
- Hat sich das Mitglied nach zwei Wellenperioden nicht bewegt, wird die Bahn wieder flach und die App wartet auf einen Tipp, der den Vorlauf neu startet. Ein Satz ist bis dahin nicht begonnen; es wird nichts gesichert.
- Eine Marke „LOS“ läuft heran; unten zählt „Los in … s“ herunter. Vorlauf 3 s (Vorschlag).
- Erreicht die Los-Marke die Jetzt-Linie, beginnt der Satz. Im Tempo-Modus bestimmt dieser Moment den Satzbeginn, nicht die Satzautomatik.
- Bewegt sich das Mitglied vor der Los-Marke, passiert nichts weiter; die Welle startet wie angekündigt.

### 7.4 Ziel (Bild A2)

- Die Soll-Wiederholungszahl kommt aus der Planposition (bei einer Spanne `wdhVon`–`wdhBis` die Obergrenze), sonst aus dem eingestellten Wiederholungsrad. Ohne Vorgabe gibt es keine Marke.
- Die Soll-Zahl wird beim Satzbeginn festgehalten, weil das Rad während des Satzes dem Zähler folgt.
- Am Ende der letzten Soll-Wiederholung steht eine Marke „ZIEL · n“. Dahinter läuft die Bahn in gedämpfter Farbe im selben Tempo weiter.
- Das Passieren des Ziels beendet den Satz nicht.

### 7.5 Satzende (Bild D)

- Der Satz endet per „Satz beenden“ oder nach 8 s Ruhe. Die 8-s-Regel gilt im Tempo-Modus immer, auch wenn die Satzautomatik sonst ausgeschaltet ist.
- In beiden Fällen wird der Satz sofort auf dem bestehenden Weg gesichert (`satzSichern`) und die Pause beginnt, wie heute nach einem Auto-Ende. Die Zählung bleibt unverändert, einschließlich Satztakt am Satzende. Der Tempo-Modus hält das Sichern nie auf.
- Über der laufenden Pause liegt die Auswertung: Trefferquote groß, ein Balken je Wiederholung (Anteil in der Bahn), je eine Zeile für Kraftweg und Ablassen („durchgehend im Tempo“ / „bei x von n zu schnell“ / „zu langsam“).
- „Weiter zur Pause“ schließt die Auswertung nur. Wer nicht tippt, sieht sie, bis die Pause endet.
- Die Wiederholungszahl korrigiert man wie heute nach einem Auto-Ende; einen eigenen Korrekturweg hat die Auswertung nicht.
- Nichts von der Auswertung wird gespeichert oder gesendet.

**Was gezählt wird:** Die Auswertung rechnet in Perioden der Soll-Welle, nicht in erkannten Wiederholungen. „Ab der dritten Wiederholung“ heißt ab der dritten Wellenperiode, ein Balken steht für eine Wellenperiode, und „zu schnell“ bzw. „zu langsam“ heißt, dass der Punkt in diesem Weg überwiegend vor bzw. hinter der Bahn lag. Die angezeigte und gesicherte Wiederholungszahl bleibt die des Zählers.

### 7.6 Einschalten

- Ein Schalter „Tempo“ in der Übungsansicht, sichtbar nur, wenn die Übung Wiederholungen zählt, der Sensor verbunden ist und die Befestigungsart das Gütetor bestanden hat. Die Stellung wird lokal gemerkt.
- Der Tempo-Modus führt eine eigene Liste freigegebener Befestigungsarten. `Befestigungsart.freigegeben` (Spec B, E5) ist leer und bleibt davon unberührt.
- Im Zirkel gibt es den Schalter nicht.
- Dort ist auch das Tempo verstellbar (Entscheidung 7).
- Alles steht hinter `#if DEBUG`, wie die übrige Sensor-Oberfläche. `GeraetModel` wird auch im Release gebaut: Tempo-Typen dürfen dort nicht im Konstruktor stehen, die Anbindung läuft über eine immer kompilierte Naht nach dem Muster von `SatzZaehler`.

## 8. Etappen

| Etappe | Inhalt | Fertig, wenn |
|---|---|---|
| E1 | Positionsschätzung im Package, Abspielen gegen alle Aufnahmen, `tempobericht.md` | Bericht liegt vor, Tim hat das Gütetor je Befestigungsart bestätigt |
| E2 | Soll-Welle, Trefferquote und Auswertung je Wiederholung als reine Logik | Tests mit künstlichen Signalen grün |
| E3 | Vollbild-Anzeige, an abgespielten Aufnahmen im Simulator sichtbar | Tim hat die Anzeige im Simulator gesehen |
| E4 | Schalter, Start, Ziel, Satzende, gemerkter Umfang, Anbindung an den Satzpfad | Satz am Gerät im Tempo-Modus trainiert und gesichert |

E1 kommt zuerst und entscheidet, ob und für welche Befestigungen es weitergeht.

## 9. Tests

- `Packages/Sensorik/Tests`: künstliche Signale (saubere Sinusbewegung, Stocken, Drift, Lücke, Start abwärts, waagerechte Bewegung) und Abspieltests über alle Aufnahmen mit Bericht.
- Soll-Welle und Trefferquote als reine Funktionen der Zeit, ohne UI getestet.
- App-Tests nach dem Muster der vorhandenen Koordinator-Tests: Tempo-Modus an und aus, Satz sichern mit und ohne Auswertung, Sensorabriss mitten im Satz.

## 10. Fehlerfälle

| Fall | Verhalten |
|---|---|
| Sensor reißt im Satz ab | Punkt verblasst, Hinweis im Kopf; die Welle läuft weiter, der Satz lässt sich beenden und sichern wie ohne Sensor |
| Schätzung länger als eine Wiederholung nicht sicher | Wie oben; diese Zeit zählt nicht in die Trefferquote |
| Weniger als drei Wiederholungen | Auswertung zeigt keine Quote, nur „Zu kurz für eine Auswertung“ |
| Gemerkter Umfang passt nicht mehr (andere Einstellung am Gerät) | Wird in den ersten zwei Wiederholungen überschrieben |
| App geht in den Hintergrund | Der Satz läuft wie heute weiter; die Trefferquote zählt nur Zeit mit sicherer Schätzung |

## 11. Dem Bauenden überlassen

- Der genaue Filter der Schätzung (Leckrate, Hochpass, Glättung beim Einrasten) und die Erkennung der Umkehrpunkte darin.
- Schwelle für „überwiegend waagerecht“.
- Typen- und Dateinamen, Aufteilung zwischen Package und App, Ablageort des gemerkten Umfangs.
- Verhalten bei „Bewegung reduzieren“ und Feinheiten der Animation.
- Genaue Texte, sofern sie den Bildern entsprechen.

## 12. Nicht enthalten

- Migrationen, API, Domänenpaket, Trainerportal.
- Katalog- oder Planfelder für das Tempo.
- Kabel, Hebel, Körper.
- Tempo-Modus im Zirkel.
- Release für Mitglieder.
- Punktestand, Bestenlisten, Spielmechanik (Teilprojekt D).
