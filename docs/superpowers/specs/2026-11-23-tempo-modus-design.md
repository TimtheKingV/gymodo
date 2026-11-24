# iOS Member-App — Bewegungssensor: Tempo-Modus (Teilprojekt C)

**Stand:** 23. November 2026
**Status:** Am 23. November freigegeben und begonnen. **Der Nachtrag am Ende (23. November abends) ändert Zuschnitt und Lageschätzung und geht den Abschnitten 2–12 vor, wo er ihnen widerspricht.** Der Nachtrag wartet auf Tims Freigabe.
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

---

## Nachtrag vom 23. November 2026 (abends): Winkel als Lage, zuerst nur drehende Übungen

**Wer was entschieden hat:** wie oben. „Tim“ = im Gespräch entschieden, „Vorschlag“ = von Claude festgelegt.

### N1. Was die Umsetzung gezeigt hat

Plan-Tasks 1, 2 und 5 sind umgesetzt (Branch `claude/tempo-modus`), dazu ein Versuch mit der Schwerkraft aus den Sensorwinkeln. Ergebnis:

- **Kein Gütetor erreicht** (`data/sensoraufnahmen/tempobericht.md`). An den Prüf-Aufnahmen ab 1.11.: Stapel 0,10–0,28 Abweichung bei 32–39 % sicher, Kurzhantel 0,18 bei 47–59 %, Langhantel ohne Prüfdaten.
- **Die Annahme „Winkel wird nicht genutzt“ (6.1) war falsch.** Hanteln drehen sich im Satz um im Median 77°; ohne bekannte Schwerkraftrichtung trägt die Beschleunigung nicht. Die Sensorwinkel passen in Ruhe auf 1,4–1,7° zur gemessenen Schwerkraft (Konvention ĝ = (−sin p, sin r·cos p, cos r·cos p), r = Roll, p = Pitch).
- **Erste Aufnahmen mit echter Wahrheit** (23.11., 11 Kurzhantel-Sätze, 1 kg, Takt 1,5/2,5 s, aufgenommen am Mac mit `tools/sensorik-aufnahme/`):
  - 7 drehende Sätze (Curl, Seitheben; Hub des Rollwinkels 92–179°): Der Winkel ist ein klares, gleichmäßiges Signal (Hub-Streuung im Probesatz 7° bei 144°) und läuft dem eigenen Drehratensignal um weniger als einen Messwert (20 ms) nach.
  - 4 Drücksätze ohne Drehung: Der Schätzer erkennt 0–4 von 8–10 Wiederholungen und meldet nie „sicher“. Bei 1,5/2,5 s liegt die Beschleunigung nur bei etwa 0,3–0,9 m/s²; ein um wenige Grad schiefer Sensor erzeugt einen ebenso großen Fehler.
  - Tim folgte dem Takt (ohne eigenen Punkt auf dem Bildschirm) mit 0,23–0,43 s Vorlauf.

### N2. Geänderte Entscheidungen

| # (oben) | Neu | Von |
|---|---|---|
| 1 | Der Tempo-Modus kommt zuerst nur für Übungen, bei denen sich der Sensor im Satz dreht: Kurzhantel-Übungen mit Drehung, Geräte mit Hebelarm, Kabelgriffe, soweit sie drehen. Stapel, Drücken, Kniebeuge und alles ohne Drehung sind nicht Teil dieses Projekts. | Tim |
| 2 | Der Punkt zeigt den Winkel des Sensors, auf den eigenen Bewegungsumfang normiert (Weg D, N3). Keine Schätzung aus der Beschleunigung. | Tim |
| 14 | Kraftweg ist der Weg aus der Ruhelage heraus, Ablassen der Weg zurück. Die Ruhelage ist immer Lage 0; die Welle beginnt immer mit dem Kraftweg. „Start oben“, das Umdrehen der Welle und der Sonderfall „waagerecht“ (6.3) entfallen. | Vorschlag |
| 15 | Ob eine Übung geeignet ist, entscheidet die Messung, nicht die Befestigungsart (N4). | Vorschlag |

Unverändert gelten: Welle im Vollbild, flacher Ausschlag, Standard-Tempo 1,5/2,5 s und verstellbar, Start mit flacher Linie und Los-Marke, Zielmarke, Umfang merken, Trefferquote am Satzende (nicht gespeichert, in Wellenperioden, ab der dritten), Sichern sofort am Satzende, kein Zirkel, nur Debug-Build, Satzbeginn ab dem zweiten Satz von selbst.

### N3. Weg D: Winkellage (ersetzt Abschnitt 6)

Ein neuer, reiner Baustein `Winkellage` im Package `Sensorik`, mit derselben Ausgabe wie in 6.1 beschrieben (`Lage` mit `lage`, `richtung`, `sicher`; Typen aus `Lage.swift`).

- **Signal:** Roll (`winkel.x`) und Pitch (`winkel.y`), je für sich über ±180° hinweg entfaltet. Yaw wird nicht benutzt. (überholt, siehe N9)
- **Achse:** die der beiden mit dem größeren Ausschlag. Sie wird in der ersten Wiederholung gewählt, gilt für den Rest des Satzes und wird mit dem Umfang gemerkt. (überholt, siehe N9)
- **Ruhelage:** der Winkel in der Ruhe vor der Los-Marke. Lage 0. (überholt, siehe N9)
- **Umfang:** Hub in Grad zwischen Ruhelage und oberem Umkehrpunkt. Gemerkt je Station und Übung (wie 6.2), in den ersten zwei Wiederholungen nachgeführt, danach nur noch langsam; kurze Wiederholungen verkleinern ihn nicht.
- **Umkehrpunkte:** Richtungswechsel des Winkels mit einer Hysterese von 10 % des Hubs (Vorschlag). (überholt, siehe N9)
- **Richtung:** `.hin` (Kraftweg), solange sich die Lage von der Ruhelage entfernt, `.rueck` beim Rückweg.
- **Sicher:** sobald der Umfang bekannt ist (gemerkt oder nach der ersten vollen Wiederholung) und mindestens 40° beträgt (Vorschlag) (überholt, siehe N9); nach einer Empfangslücke über 0,5 s sofort wieder, sobald Messwerte kommen. Der Winkel driftet nicht, ein Einrasten oder Einschwingen braucht es nicht.
- **Bekanntes Risiko:** Nahe Pitch ±90° wird Roll unzuverlässig. Zeigt der Bericht (N5) Sätze, in denen die gewählte Achse springt, ist das festzuhalten; eine Lösung über die aufsummierte Drehrate ist dann ein eigener Schritt. (überholt, siehe N9)

Die Schätzung aus der Beschleunigung (`Lageschaetzer`, `Gleichanteil`, `Hilfslage`, `Schwerkraftquelle`) bleibt als Versuch auf dem Branch, wird von der App nicht benutzt und in diesem Projekt nicht weiterentwickelt. Ob sie mit in den Merge geht, entscheidet Tim vor dem Merge. (überholt, siehe N9)

### N4. Eignung (ersetzt die Freigabe nach Befestigungsart in 7.6)

- Der Schalter „Tempo“ ist bei jeder Kraftübung mit Wiederholungen und verbundenem Sensor sichtbar, solange die Übung an dieser Station nicht als ungeeignet gemerkt ist.
- Beträgt der Hub nach zwei Wellenperioden weniger als 40°, bricht der Tempo-Modus für diesen Satz ab: Die Anzeige wechselt auf die gewohnte Ansicht mit dem Hinweis „Für diese Übung reicht die Drehung des Sensors nicht“, der Satz läuft und zählt normal weiter. Übung und Station werden als ungeeignet gemerkt; der Schalter erscheint dort ausgegraut mit demselben Hinweis und lässt sich durch Antippen wieder freigeben (z. B. nach anderer Befestigung).
- `Tempofreigabe.arten` entfällt.

### N5. Messung (ersetzt 6.4)

Der Winkel ist eine direkte Messung, kein Schätzwert. Geprüft wird deshalb nicht die Abweichung gegen eine Rechnung, sondern:

- **Wiederholungen gegen die Wahrheit:** Umkehrpunkte der `Winkellage` gegen `repsWahr`, je Aufnahme. (überholt, siehe N9)
- **Sicher-Anteil** im aktiven Teil des Satzes. (überholt, siehe N9)
- **Stabilität:** Streuung des Hubs von Wiederholung zu Wiederholung; Sprünge der Lage zwischen zwei Messwerten.

Ausgewertet werden alle Aufnahmen mit `repsWahr` ≥ 5, deren Winkelhub im Satz mindestens 40° beträgt, gleich welcher Befestigungsart, getrennt nach „vor 1.11.“ und „ab 1.11.“ (inklusive der Mac-Aufnahmen vom 23.11.). `tempobericht.md` bekommt dafür einen Abschnitt „Winkellage“ vor den bisherigen. (überholt, siehe N9)

Tragfähig heißt (Vorschlag, mit Tim nachzuschärfen, sobald Zahlen vorliegen): Wiederholungsfehler im Median ≤ 1, Sicher-Anteil im Median ≥ 0,9, kein Satz mit einem Sprung der Lage über 0,2 zwischen zwei Messwerten. Der Bericht nennt außerdem, wie viele Aufnahmen je Befestigungsart die 40° erreichen: das ist der Kreis der Übungen, für den der Modus taugt.

### N6. Was sich im Rest ändert

- **7.3 Start:** Die flache Linie liegt immer auf Lage 0. Der Satz über die abwärts beginnende erste Bewegung entfällt.
- **7.5 Satzende:** Die zwei Zeilen heißen immer „Kraftweg“ und „Ablassen“.
- **Bahnbreite:** bleibt ±0,2 als Startwert und wird am Gerät eingestellt. Tims Vorlauf von 0,23–0,43 s ohne eigenen Punkt spricht dafür, dass die Bahn eher breiter werden muss; entschieden wird das erst mit der Anzeige.
- **3 Nicht-Ziele:** Stapel, Langhantel und alle Übungen ohne Drehung kommen hinzu.
- **8 Etappen:** E1 = `Winkellage` und der Abschnitt im Bericht; Tim bestätigt die Zahlen. E2 = Soll-Welle und Trefferquote (Plan-Tasks 7 und 8, unverändert) (überholt, siehe N9). E3 und E4 wie oben, mit der Eignung aus N4. Die Plan-Tasks 3, 4 und 6 entfallen.
- **10 Fehlerfälle:** „Schätzung länger als eine Wiederholung nicht sicher“ wird zu „Hub unter 40° nach zwei Wellenperioden“ (N4).

### N7. Aufnahme-Werkzeug

`tools/sensorik-aufnahme/` (Seite und `bruecke.py`, Kurzentwurf `2026-11-23-sensor-aufnahme-seite-design.md`) nimmt Sätze am Mac mit Takt auf. Für drehende Übungen ist der Winkel die Wahrheit; Tasten braucht es dort nicht.

### N8. Festlegungen aus der Gegenprüfung (alle Vorschlag)

- **Vorzeichen:** Die Lage wird mit dem Vorzeichen des ersten Wegs aus der Ruhelage normiert: `lage = vorzeichen · (winkel − ruhewinkel) / hub`. Dreht der Sensor in negative Gradrichtung, ist das Vorzeichen −1. (überholt, siehe N9)
- **Ruhewinkel:** Median des Winkels über den Teil des Vorlaufs, in dem der Sensor still ist (Drehrate klein). War er nie still, gilt der Winkel zu Beginn des Vorlaufs. (überholt, siehe N9) Das gilt für jeden Satz neu, auch für den zweiten und folgende.
- **Achse, solange sie nicht feststeht:** die mit dem bisher größeren Ausschlag seit der Ruhe; sie darf wechseln, bis ein Ausschlag von 20° erreicht ist, danach steht sie für den Satz fest. Mit gemerktem Wert steht sie von Anfang an fest. (überholt, siehe N9)
- **Umfang ohne gemerkten Wert:** Der Punkt wird sofort gezeigt. Maßstab ist das Größere aus 40° und dem bisher größten Ausschlag; `sicher` ist dabei falsch. Mit der ersten vollen Wiederholung gilt deren Hub, mit der zweiten der Mittelwert beider. (überholt, siehe N9) Danach folgt der Umfang nur noch langsam (N3).
- **Sicher in Ruhe:** Sobald der Umfang bekannt ist und mindestens 40° beträgt, ist `sicher` wahr, auch wenn die Last ruht. Wer im Satz unten pausiert, liegt zu Recht neben der Bahn; diese Zeit zählt in die Trefferquote. Die Aussage in 6.1 („in Ruhe nicht sicher“) galt der Schätzung aus der Beschleunigung und entfällt.
- **Gemerkter Wert:** ein eigener Typ für den Winkel (Achse, Vorzeichen, Hub in Grad), nicht `GemerkterUmfang`. (überholt, siehe N9) Schlüssel wie beim `Befestigungsspeicher`: Station und Übung.
- **Ungeeignet-Marke:** Schlüssel Station und Übung, unabhängig von Gewicht und Befestigung. Gesetzt nur beim Abbruch nach N4. Gibt das Mitglied den Schalter wieder frei und läuft der nächste Satz mit mindestens 40° Hub durch, wird die Marke gelöscht.
- **Wer abbricht:** die App, nicht `Winkellage`. `Winkellage` meldet den bisher größten Ausschlag; die App prüft ihn zwei Wellenperioden nach der Los-Marke.
- **Nach einem Abbruch:** keine Tempo-Auswertung am Satzende. Für den Rest des Satzes gelten Zählung und Satzautomatik wie ohne Tempo-Modus.
- **Sichtbarkeit des Schalters:** N4 geht 7.6 vor. Das Anti-Ziel „lieber nicht freischalten“ erfüllt der Abbruch nach N4.

### N9. Stand nach der Umsetzung (24. November 2026)

Ersetzt, wo sie abweicht, die mit „(überholt, siehe N9)“ gekennzeichneten Aussagen in N3–N8. Gebaut auf `claude/tempo-modus`, alles im Package `Sensorik`.

**Signal.** Je Messwert die Schwerkraftrichtung ĝ = (−sin p, sin r·cos p, cos r·cos p) aus Roll r und Pitch p. Gemessen wird ihre Drehung φ gegenüber der Ruherichtung ĝ₀ in der Ebene der ersten Bewegung: Die Drehachse n = normiert(ĝ₀ × ĝ) steht fest, sobald die Drehung 20° erreicht, danach φ = atan2((ĝ₀ × ĝ)·n, ĝ₀·ĝ), über ±180° hinweg entfaltet. Es gibt keine Wahl zwischen Roll- und Pitch-Achse und kein Vorzeichen; φ ist in Richtung der ersten Bewegung positiv. Gemerkt wird nur der Hub in Grad (`GemerkterWinkel(hubGrad:)`). `lage = φ / hub`.

**Ruhe, Umkehrpunkte, Sicher.**
- Still heißt: ĝ weicht über 0,5 s höchstens 4° von seinem Mittel ab; die Drehrate wird nicht benutzt. Das stille Mittel ist das der letzten Sekunde, wenn sie still ist, sonst das der letzten halben.
- Umkehrpunkte über eine Hysterese von 10 % des Hubs, solange der Hub nicht bekannt ist mindestens 10°; ein unterer Umkehrpunkt entsteht auch durch Stillstand bei Lage < 0,35.
- Richtung aus dem Trend der Lage über 0,1 s (Totzone 1 % des Hubs).
- Maßstab: in der ersten Wiederholung vorläufig das Größere aus 40° und dem bisherigen Gipfel; nach dem ersten Gipfel dessen Höhe, nach dem zweiten der Mittelwert beider, danach höchstens 10 % je Wiederholung (nur bei mindestens 80 % des Hubs). Jeder neue Maßstab gilt erst ab dem unteren Umkehrpunkt.
- Sicher: ab dem ersten unteren Umkehrpunkt (oder mit gemerktem Hub), Hub mindestens 40°, und nicht nahe der Drehachse: Liegt ĝ weniger als 20° von n, ist φ nicht bestimmt, wird gehalten, und die Lage ist unsicher.

**Ablauf.** Eine Instanz je Satz, `init → (los) → verarbeite … → ende`, kein Zurücksetzen.
- Ausdrücklicher Start `los()`: Bis dahin Lage 0; `los()` nimmt das stille Mittel, wenn es gerade still ist, sonst das zuletzt stille Mittel, wenn es höchstens 3 s alt ist, sonst den letzten Messwert. Ohne `wartetAufLos` steht die Ruhe mit der ersten Bewegung über 5° fest.
- Ende `ende()`: Danach steht die Lage (unsicher), Umkehrpunkte, gemerkter Hub und größter Ausschlag ändern sich nicht mehr; eine angefangene Wiederholung (oberer Umkehrpunkt ohne unteren) fällt heraus und geht nicht in den Hub ein.
- Zeit: `Lage.t` ist Sensorzeit. `losZeit` ist die Sensorzeit des Messwerts, bei dem `los()` wirksam wurde (ohne `wartetAufLos` die der ersten Bewegung); `sekundenSeitLos(t)` liefert die Zeit, die `Sollwelle` und `Tempoauswertung.erfasse(_:bei:)` erwarten.
- Eine Rate, die nicht endlich oder nicht positiv ist, gilt als 50 Hz.

**Grenzen.** Eine Drehung um die Senkrechte ändert ĝ nicht und ist unsichtbar (waagerecht schwenkende Hebelarme, Drücken ohne Drehung des Sensors). Das frühere Risiko „Pitch ±90°“ ist behoben: ĝ ist dort stetig, ein Test prüft das an einem Kunstsignal mit Euler-Sprung (`WinkellageTests`).

**Messung (`data/sensoraufnahmen/tempobericht.md`, erzeugt von `WinkelBerichtTests`).**
- Auswahl: alle Aufnahmen mit bekannter Wiederholungszahl ≥ 5 (171 Sätze), gleich welcher Art: `repsWahr` aus `korrekturen.json`; die Mac-Aufnahmen mit `tempo` in `aufnahme.json` (ausgewählt über `label.reps` ≥ 5). „geeignet“ = gemerkter Hub am Satzende ≥ 40°.
- Je Aufnahme zwei Läufe: ohne Start (Ruhe mit der ersten Bewegung, das Aufnehmen zählt mit) und mit geschätztem Start (nachträglich aus der ganzen Aufnahme geraten). Die Mac-Aufnahmen laufen statt geschätzt im echten Ablauf: `los()` an `# los`, `ende()` an `# ende`, der Rest der Aufnahme wird weiter eingespeist.
- Soll der Mac-Sätze: die Taktgipfel, die Zeilen `# takt oben` bis `# ende`. Die Person folgte einem Metronom ohne unabhängige Zählung; die Soll-Zahl kommt von der Uhr. `label.reps` war von der Seite aus der Satzdauer vorbelegt und ist keine Zählung.
- Gemessen sind nur die Zahl der Umkehrpunkte gegen das Soll und Sprünge der Lage zwischen zwei Messwerten. Nicht gemessen sind die Genauigkeit der Lage, die Verzögerung der Anzeige und der Lauf mit gemerktem Hub. Die Mac-Zeile beruht auf 7 geeigneten Sätzen einer Person an einem Abend mit 1 kg und zwei Übungen (Curl, Seitheben). „Sicher“ beginnt nach dem ersten unteren Umkehrpunkt und sagt deshalb wenig; „geeignet“ wählt nach dem Ergebnis der `Winkellage` selbst aus.
- Zahlen (Bericht vom 24.11.2026; je Zelle ohne Start / geschätzter bzw. echter Start):

| Teil, Art | Sätze | geeignet | Wdh.-Fehler | Sicher | Sätze mit Sprung | tragfähig |
|---|---|---|---|---|---|---|
| Abstimmung, kurzhantel | 63 | 45 / 37 | 1,0 / 1,0 | 100 % / 100 % | 22 / 12 | nein / nein |
| Abstimmung, langhantel | 17 | 5 / 3 | 4,0 / 2,0 | 100 % / 96 % | 2 / 3 | nein / nein |
| Abstimmung, stapel | 50 | 0 / 0 | – | – | – | nein / nein |
| Prüfung, kurzhantel | 21 | 15 / 14 | 1,0 / 1,5 | 100 % / 100 % | 4 / 8 | nein / nein |
| Prüfung, kurzhantel mit Los-Marke (Mac) | 11 | 7 / 7 | 0,0 / 0,0 | 100 % / 100 % | 0 / 3 | ja / nein |
| Prüfung, stapel | 8 | 0 / 0 | – | – | – | nein / nein |

  Im echten Ablauf der Mac-Sätze (von `los()` bis `ende()`) trifft die Zahl der Umkehrpunkte das Soll im Median genau (3 von 7 einen zu wenig), der Ruhefehler beim Los liegt im Median bei 1,3° (größter 5,2°; mit der früheren Regel „letzter Messwert“ 4,5–12,9° bei 4 Sätzen). Die Messlatte verfehlt er wegen dreier Sprünge über 0,2 (0,28 / 0,33 / 0,40), alle am Los: Die Lage steht bis `los()` auf 0 und springt dann auf die Bewegung, die vor dem Los schon begonnen hatte. Die neuen Sprünge in den Läufen ohne Start (Prüfung Kurzhantel 0 → 4) entstehen alle dort, wo die Lage nahe der Drehachse gehalten war und danach auf den wieder bestimmten Winkel springt. Beides ist so gebaut, wie entschieden, und nicht nachgestellt; ob die Anzeige es glätten soll, gehört zum App-Plan.

**Entfernt.** Der Schätzer aus der Beschleunigung (`Lageschaetzer`, `Gleichanteil`, `Hilfslage`, `Schwerkraftquelle`, `Lagebezug`, der alte Tempobericht und `tools/sensorik-sim/tempo_nachrechnung.py`) ist vom Branch entfernt; der Code liegt unter dem Tag `archiv/tempo-beschleunigungsschaetzer`, seine Berichtsabschnitte eingefroren in `data/sensoraufnahmen/tempobericht-beschleunigung-2026-11-23.md`. `Tempofreigabe` entfällt.

**Soll-Welle und Auswertung.** Die Plan-Tasks 7 und 8 sind ohne `startetOben` und ohne `gleichmaessig` umgesetzt (`Tempovorgabe`, `Sollwelle`, `Tempoauswertung`). Die Bahnbreite ist je Welle einstellbar (`Sollwelle(vorgabe:halbeBahnbreite:)`, Standard ±0,2); `Tempoergebnis` hat einen öffentlichen Initialisierer.

**Offen für den App-Plan.**
- Startauslöser ab dem zweiten Satz: Ohne ausdrücklichen Start (`los()`) zählt das Aufnehmen der Hantel mit. Mit `los()` und `ende()` treffen die Mac-Sätze die Soll-Zahl im Median genau und die Ruhelage auf im Median 1,3°; wegen des Sprungs am Los (nächster Punkt) gilt die Zeile im Bericht dennoch als nicht tragfähig.
- Lage vor dem Los: `Winkellage` gibt bis `los()` den Platzhalter 0 aus. Bewegt sich das Mitglied schon vorher, springt die Lage am Los auf den richtigen Wert (0,28–0,40 in drei Mac-Sätzen). Das ist eine Frage der Ausgabe von `Winkellage`, nicht der Anzeige: Vor dem Los sollte sie die Lage gegenüber der mitgeführten Ruherichtung liefern (`sicher = false`), dann ist der Übergang stetig.
- Nahe der Drehachse: Die Lage wird dort gehalten und springt beim Wiedereinsetzen (vier Prüf-Sätze). Entweder über 0,1–0,2 s zurückführen oder den Kegel von 20° verkleinern.
- Satzende: `ende()` verwirft einen offenen oberen Umkehrpunkt auch dann, wenn das Ablassen schon unten angekommen, der untere Umkehrpunkt aber noch nicht erkannt ist; ein Ende direkt nach der letzten Wiederholung zählt dann eine zu wenig. Bei Lage ≤ 0,35 sollte die Wiederholung abgeschlossen statt verworfen werden.
- Glättung der Anzeige: Die Messwerte kommen paarweise mit gleichem `t`.
- Bestätigung an echter Last (mehr als 1 kg, mehrere Personen) und an Geräten mit Hebelarm.
