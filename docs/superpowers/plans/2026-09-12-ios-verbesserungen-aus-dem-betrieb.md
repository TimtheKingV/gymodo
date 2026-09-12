# iOS-Mitglieder-App — Verbesserungen aus dem Betrieb

Gesammelt aus annotierten Screenshots vom 11./12. September 2026. Das
Dokument ist eine **Sammelstelle, kein Umsetzungsplan**: es hält fest, was
gemeint ist, welchen Code es trifft und was noch offen ist. Es wächst mit
jeder weiteren Runde Screenshots.

## Vorbemerkung: der Build ist dem Repo voraus

Die Screenshots zeigen Screens, die es auf `origin/master` (`58d4fb5`) noch
nicht gibt:

- **Home** hat dort einen Sieben-Tage-Serienstreifen (`HomeSerieView`), keinen
  Monatskalender, kein Aufklappen „Wochenansicht", keine Tagesgruppierung
  („FREITAG, 11. SEPTEMBER") und Karten mit Datum statt Uhrzeitspanne.
- **Training (leer)** hat dort den Erklärtext, aber keine Überschrift
  „Training starten" und kein Feld „Suchen".
- **Session-Detail** hat dort keine Gerätenummer vor dem Übungsnamen.

Deckungsgleich sind nur „Training beendet" (`TrainingAbschlussView`) und der
Kurse-Wochenplan (`KurseWochenView`). Der aktuelle Stand wird vor der
Umsetzung nachgezogen; die Dateiverweise unten zeigen deshalb auf den Ort der
Sache, nicht zwingend auf die Zeile.

## Eine Regel, die mehrfach auftaucht: heute vs. ausgewählt

Zwei Kalenderstreifen, zwei verschiedene Antworten auf dieselbe Frage — und
in beiden fehlt die jeweils andere Hälfte. Der Kurse-Streifen färbt den
**ausgewählten** Tag akzentgrün und markiert **heute** gar nicht
(`KurseWochenView.tagesboxen`); der Home-Kalender markiert **heute** mit
grünem Ring und Hantel, kennt aber keine sichtbare **Auswahl**.

Festlegung aus den Notizen (Bild 4 und Bild 8 zusammengelesen):

- **Heute** trägt den Akzent — grün, in beiden Streifen, immer.
- **Ausgewählt** trägt Weiß — Fläche oder Kontur, in beiden Streifen gleich.
- Beides zugleich (heute ist ausgewählt) muss unterscheidbar bleiben.

Das ist eine Änderung am Designsystem-Kapitel „eine Akzentfläche je Screen"
(`docs/superpowers/specs/2026-08-30-designsystem.md` §2): der Akzent wandert
von der Auswahl auf „heute". Beim Nachziehen mitschreiben.

## Die Punkte

### 1. Home — „Wochenansicht" nach oben rechts

Der Umschalter zwischen Monats- und Wochenansicht steht unter der
Trainingsliste, also unter dem, was er umschaltet. Er gehört nach oben
rechts, auf die Höhe der Monatsüberschrift („SEPTEMBER 2026").

*Bild 1. Trifft den Home-Kalender (im Repo noch nicht vorhanden).*

### 2. Training beendet — Grafik, Entwicklung, Rekord

Der Abschluss-Screen zeigt drei Zahlen und die Vorschläge fürs nächste Mal.
Dazu soll die **Entwicklung** kommen: eine Grafik statt einer weiteren Zahl,
plus die Kennzeichnung eines **Rekords**, wenn ein Satz die bisherige
Bestleistung schlägt.

Offen: Grafik je Übung (Gewichtsverlauf über die letzten Einheiten) oder eine
je Training? Rekord als Marke auf der Übungskarte?

Datenlage: `getSessions`/`ExerciseProgress` liefern heute nur den aktuellen
Wert und die Veränderung (`changeKg`); für eine Verlaufskurve braucht es die
Reihe der letzten N Werte je Übung — entweder aus dem vorhandenen
Fortschrittsfenster (`Verlauf/Fortschrittsfenster.swift`,
`UebungsfortschrittView`) oder als eigene Serverantwort.

*Bild 2. `Screens/Training/TrainingAbschlussView.swift`.*

### 3. Training starten — der Block nach unten

QR-Code, NFC und Suchen stehen im oberen Drittel, darunter ist der Screen
leer. Die Gruppe rutscht nach unten in die Daumenzone. **Bestätigt.**

*Bild 3, zusammen mit Punkt 10 (was oben frei wird, füllt „Training läuft").*
*`Screens/Training/TrainingRootView.swift`, `leerInhalt`.*

### 4. Home-Kalender — ausgewählter Tag in Weiß

Siehe die Festlegung oben. **Bestätigt.**

*Bild 4.*

### 5. Übungsfortschritt — nach Muskelgruppe gruppieren

Die Liste („22 · Beincurler liegend  55,0 kg  ±0") wird nach Muskelgruppe
**gruppiert**, mit Überschrift je Gruppe. **Bestätigt (gruppiert, nicht nur
sortiert).**

Dafür fehlt die Datengrundlage vollständig: weder `exercises`
(`supabase/migrations/0005_exercises.sql`) noch `equipment_models` tragen eine
Muskelgruppe, und im ganzen Repo kommt der Begriff nicht vor. Nötig sind
also:

1. Migration: Muskelgruppe an der Übung (Aufzählung, studioweit gleich —
   „Beine", „Brust", „Rücken", „Schultern", „Arme", „Rumpf", „Ganzkörper").
2. Pflege im Trainerportal, damit das Studio zuordnen kann.
3. Durchreichen in `getSessions`/Katalog und Gruppieren im View.

Zwischenlösung wäre eine feste Zuordnung im Client — die wäre aber bei jedem
studioeigenen Übungsnamen falsch und ist damit keine.

*Bild 5. `Screens/Home/HomeRootView.swift` (`fortschritt`), Server + Portal.*

### 6. Kurse — heute markieren

Im Wochenstreifen ist nur der gewählte Tag zu sehen; welcher Tag heute ist,
steht nirgends. Heute bekommt den Akzent (siehe Festlegung oben).

*Bild 8. `Screens/Kurse/KurseWochenView.swift`, `tagesboxen`.*

### 7. Kurse — Überschrift „Nächste Woche"

Unter „Angemeldet" steht bei Auswahl von Freitag, 11., eine Karte für Montag,
den 14. — ohne Hinweis, dass sie nicht mehr zu dieser Woche gehört. Termine
späterer Kalenderwochen brauchen eine Überschrift.

Die Zuordnung gibt es bereits und ist getestet:
`KurseMeineEinteilung.spaeter` (Abschnitt hieß früher „Nächste Woche", heute
„Später", weil das Ladefenster 14 Tage weit reicht). Das Band zeigt seit der
Zusammenlegung nur noch `alleZeilen`, also eine flache Liste. Die Überschrift
kommt zurück — Wortlaut prüfen, „Später" trifft es bei zwei Wochen Fenster
genauer als „Nächste Woche".

*Bild 9. `Kurse/KurseMeineEinteilung.swift`, `Screens/Kurse/KurseBandView.swift`.*

### 8. Training starten — „Training läuft" anzeigen

Auf der freien Fläche unter dem Startblock soll sichtbar sein, dass gerade
ein Training läuft. Im Repo ist das heute ein ausschließender Zustand
derselben Wurzel (`laufendInhalt` statt `leerInhalt`); gemeint ist
offenbar, dass beides zusammen steht — Startwege unten, laufendes Training
darüber.

Offen: Zusammenspiel mit Punkt 3 bestätigen.

*Bild 10. `Screens/Training/TrainingRootView.swift`.*

### 9. Session-Detail — noch nicht entziffert

Bild 7 trägt drei Notizen über den Satzkarten, die ich nicht sicher lese:
etwas wie „Ein Auf…" über der Beinpresse, „2. Stock" in der Mitte und
„+ Erfolg(e)" unten. Rückfrage läuft.

*Bild 6 ist derselbe Screen ohne Markierung (Referenz).*
*`Screens/Home/SessionDetailView.swift`.*

## Offene Fragen

1. Punkt 2: Grafik je Übung oder je Training, und was genau zählt als Rekord?
2. Punkt 8: läuft ein Training, stehen Startwege und laufendes Training
   gemeinsam auf dem Screen?
3. Punkt 9: Bild 7 entziffern.
4. Punkt 5: Muskelgruppe sauber ins Datenmodell (Migration + Portal) — oder
   erst einmal ohne Portalpflege, mit einer Vorgabeliste je Studio?
