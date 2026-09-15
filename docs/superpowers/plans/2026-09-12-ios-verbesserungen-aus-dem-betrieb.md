# iOS-Mitglieder-App — Verbesserungen aus dem Betrieb

Gesammelt aus annotierten Screenshots vom 11./12. September 2026. Das
Dokument ist eine **Sammelstelle, kein Umsetzungsplan**: es hält fest, was
gemeint ist, welchen Code es trifft und was noch offen ist. Es wächst mit
jeder weiteren Runde Screenshots.

## Stand: das Repo ist aktuell (14. September)

Die Sammelrunde lief gegen einen Build, den es im Repo noch nicht gab. Mit
`f8db46f` liegt er jetzt auf `master` — sieben Commits, die genau die Screens
der Screenshots bringen. Wo die Punkte unten hingreifen, hat sich damit
präzisiert:

- **Home** trägt den Kalender jetzt in `HomeSerieView` (Wochenstreifen,
  `monatsgitter`, Tagesauswahl mit `tagesliste`, Umschalter
  „Monatsansicht/Wochenansicht" unten rechts). „Letzte Trainings" ist ganz
  weg; die Karten hängen am gewählten Tag. Die Ableitungen dazu stehen in
  `HomeSerie` (`trainingstage`, `einheitenJeTag`, `monatstage`).
- **Auswahl und heute** sind im Home-Kalender schon getrennt, aber anders
  als besprochen: gewählt = Füllung in `Color.line` (grau), heute = Ring in
  Akzent (`HomeSerieView.fuellung`, `zelle`). Punkt 4 ist damit ein
  Farbwechsel grau → weiß, kein Umbau.
- **Kurse** haben den Kalender oben und den Umschalter Angemeldet/Alle
  darunter (`KurseAnsicht`, `KurseWochenView`, `KurseBandView`). Der gewählte
  Tag ist weiterhin akzentgefüllt, **heute trägt weiterhin keine Marke** —
  Punkt 6 steht unverändert, und mit ihm die Regel unten.
- **Training** teilt sich seit Schnitt 2 ein Gerüst aus Mitte und Fuß
  (`TrainingRootView`): die Startwege QR / NFC / Suchen (`ScanWege`) stehen
  in beiden Zuständen unten im Fuß, darüber steht — nur wenn ein Training
  läuft — die Mitte mit Uhr, Zahlen, Geräteliste und „Training beenden".
  Der Titel „TRAINING" steht nur im leeren Zustand; im laufenden übernimmt
  der Kopf („TRAINING LÄUFT" + Uhr) dessen Platz, damit auf kleinen iPhones
  genug Höhe für die Geräteliste bleibt. Ohne Training bleibt die Mitte
  leer. Punkt 3 und 8 sind damit umgesetzt.
- **Gerät** hat seit `8f73fa0` eine Trainingsuhr im Kopf
  (`GeraetView.trainingsuhr`); `radOffen` gibt es weiterhin, Punkt 11 bis 13
  bleiben wie beschrieben.
- **Die Karten** heißen jetzt `HomeZeilen.kartenTitel` (Zeitraum, sonst „ab
  18:04") und `zeilenText` („41 min · 1 Gerät · 3 Sätze") — das sind die
  beiden Zeilen, die Punkt 17 tauscht.

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
Dazu kommt die **Entwicklung** als Grafik statt als weitere Zahl, und die
**Erfolge** des Trainings (Rekorde und übersetzte Stats — siehe den eigenen
Abschnitt „Stats und Erfolge" weiter unten; es ist dieselbe Ableitung wie in
Punkt 9, nur ein anderer Ort).

Datenlage für die Grafik: `getSessions`/`ExerciseProgress` liefern heute nur
den aktuellen Wert und die Veränderung (`changeKg`). Eine Verlaufskurve
braucht die Reihe der letzten N Werte je Übung — entweder aus dem vorhandenen
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

### 7. Kurse — Überschriften nach Woche

Unter „Angemeldet" steht bei Auswahl von Freitag, 11., eine Karte für Montag,
den 14. — ohne Hinweis, dass sie nicht mehr zu dieser Woche gehört. Die Liste
bekommt Überschriften, und zwar **nach Abstand in Wochen**, nicht nach Status:

- „Diese Woche"
- „Nächste Woche"
- „Übernächste Woche"
- „Bald" — alles, was noch weiter weg ist

Die Zuordnung existiert halb: `KurseMeineEinteilung` teilt heute in
`angemeldet` / `warteliste` / `spaeter` (der Abschnitt hieß früher „Nächste
Woche" und wurde zu „Später" umbenannt, weil das Ladefenster 14 Tage weit
reicht). Aus dem einen `spaeter` werden jetzt drei Stufen, gerechnet auf
Kalenderwochen ab dem Montag der laufenden Woche (Studio-Zeitzone) — die
Rechnung dafür steht schon in `KurseWochenBerechnung.montag`. Der Status
(Warteliste) bleibt auf der Karte, er ist keine Überschrift mehr.

„Bald" bleibt beim heutigen 14-Tage-Fenster leer; die Stufe wird trotzdem
gebaut, damit ein größeres Fenster sie nur noch füllen muss.

*Bild 9. `Kurse/KurseMeineEinteilung.swift`, `Screens/Kurse/KurseBandView.swift`.*

### 8. Training starten — „Training läuft" in der Mitte

Gehört zu Punkt 3: die Startwege rutschen nach unten, und **in die Mitte des
Screens kommt das laufende Training** — der Satz „Training läuft" plus die
**bisher gelaufene Zeit**. Beides steht gleichzeitig da, Startwege unten,
Laufendes darüber.

Heute sind das zwei sich ausschließende Zustände derselben Wurzel
(`laufendInhalt` statt `leerInhalt`). Die laufende Uhr gibt es schon: die
innere `TimelineView` im laufenden Zustand tickt sekundengenau, die äußere
schaltet im Minutentakt um. Wenn kein Training läuft, bleibt die Mitte leer —
dort steht keine Null.

*Bild 3 + Bild 10. `Screens/Training/TrainingRootView.swift`.*

### 9. Stats und Erfolge — die eigentliche Idee hinter Bild 2 und Bild 7

Nicht mehr Zahlen, sondern Zahlen, die man jemandem erzählt. Zwei Sorten:

**a) Erfolge (Rekorde).** „Höchstes Gewicht" und „meiste Wiederholungen" je
Gerät und Übung, und die Marke „neuer Rekord", wenn ein Satz die bisherige
Bestleistung schlägt. Die Daten liegen vollständig vor: `workout_sets` trägt
`weight_kg`, `reps`, `performed_at` je Satz, `machine_id` und `exercise_id`
daneben. Zu klären ist nur, ob der Rekord serverseitig als eigene Antwort
kommt (sauber, eine Abfrage über die ganze Historie) oder im Client aus dem
geladenen Fenster gerechnet wird (fällt bei mehr als 50 Einheiten falsch aus —
dieselbe Falle wie bei der Serie, siehe `HomeSerie`: „hier wird nicht
gerechnet, hier wird gelesen").

**b) Übersetzte Stats.** „Heute hast du ein Auto in den 2. Stock getragen" —
Hubarbeit aus Gewicht, Wiederholungen, Sätzen und Hubweg, übersetzt in etwas
Anschauliches.

Die Rechnung: `Arbeit = Σ (Gewicht × Wiederholungen × Hubweg)` in kg·m.
Vergleich: ein Kleinwagen (1.400 kg) sechs Meter hoch (2. Stock) sind
8.400 kg·m.

Zwei Dinge fallen dabei auf:

1. **Der Hubweg fehlt in den Daten.** Weder `exercises` noch
   `equipment_models` kennen eine Bewegungsstrecke. Drei Wege: ein Feld an der
   Übung (Meter, vom Studio gepflegt — genau, aber Pflegeaufwand für jedes
   Studio), ein Vorgabewert je Muskelgruppe (0,3–0,6 m — kommt mit Punkt 5
   ohnehin ins Datenmodell), oder ganz ohne Weg, nur bewegtes Volumen in
   Kilogramm („2,3 t bewegt — ein Kleinwagen"). Der mittlere Weg ist der
   billigste ehrliche.
2. **Der Vergleich muss zur Zahl passen, nicht umgekehrt.** Ein reales
   Training aus den Screenshots (3 Sätze × 10 Wdh × 60 kg, 0,4 m Hubweg) sind
   720 kg·m — ein Zwölftel des Autos. Es braucht deshalb eine Leiter von
   Vergleichen (Wasserkasten in den 3. Stock, Fahrrad aufs Dach, Kühlschrank,
   Klavier, Kleinwagen, Elefant), aus der die passende Stufe gewählt wird.
   Sonst trägt jedes Training ein Auto, und der Satz ist beim zweiten Mal
   nichts mehr wert.

**Ehrlichkeit.** Der Screen sagt heute „gymodo misst nichts. Es zeigt, was du
bestätigst." Eine Beinpresse drückt schräg, ein Kabelzug lenkt um — die
Hubarbeit ist ein Überschlag, kein Messwert, und muss auch so beschriftet sein
(„ungefähr", „überschlagen"). Die Rekorde dagegen sind exakt: sie stehen so in
den bestätigten Sätzen.

**Wo das steht:** Trainingsabschluss (Bild 2) und Session-Detail (Bild 7) —
eine Ableitung, zwei Orte. Ob auch Home einen Platz dafür bekommt, ist offen.

*Bild 6 (Referenz ohne Markierung), Bild 7, Bild 2.*
*`Screens/Home/SessionDetailView.swift`, `Screens/Training/TrainingAbschlussView.swift`,*
*neue Ableitung neben `Verlauf/HomeZeilen.swift`.*

### 10. Geräteeinstieg — das Training startet nach diesem Screen

Heute entsteht die Einheit beim **ersten gesicherten Satz**
(`WorkoutSessionStore.satzSichern` legt sie an, davor gibt es sie nicht).
Künftig startet sie, **wenn der Einstiegsscreen verlassen wird** — also mit
dem Tap auf die Übung unter „Was machst du heute?".

Was daran hängt:

- **Drei Texte werden falsch.** „Dein Training startet von selbst, sobald du
  den ersten Satz sicherst — es gibt keinen Startknopf"
  (`TrainingRootView.leerInhalt`), „Sätze sichern — meistens reicht ein
  Antippen. Das Training startet dabei von selbst" (`HomeRootView.leer`), und
  „Ein Tap genügt — du landest direkt beim Satz" auf dem Einstieg selbst.
- **Leere Einheiten werden möglich.** Wer scannt, die Übung antippt und dann
  weggeht, hinterlässt eine Einheit ohne einen einzigen Satz. Regel nötig:
  eine Einheit ohne Satz wird beim Verlassen bzw. beim Ablauf verworfen und
  nie an den Server gemeldet — sonst stehen im Verlauf Einheiten mit „0 Sätze",
  und die Serie zählt Tage, an denen nichts passiert ist.
- **Die Dauer wird ehrlicher.** Sie enthält dann Einweisung und Einstellung,
  nicht erst ab dem ersten Satz — und die Uhr aus Punkt 8 („Training läuft")
  hat einen Anfang, den das Mitglied selbst gesetzt hat.

**Entschieden (15. September): ein eigener Screen „Training starten“.** Die
Einheit beginnt nicht schon mit dem Tap auf die Übung, sondern auf einem
eigenen Screen nach Geräte- und Übungswahl. Mit dem Tap dort beginnt die
Uhr. Das hebt M1-Spec §5.6 („es gibt keinen Startknopf“) auf, die Spec wird
beim Umsetzen nachgezogen. Für Schnitt 4 offen:

- Kommt der Screen nur, wenn noch kein Training läuft? Das nächste Gerät
  mitten im Training soll vermutlich ohne ihn auskommen, sonst kostet jeder
  Gerätewechsel einen Tap mehr.
- Die Regel für leere Einheiten bleibt nötig: wer „Training starten“
  drückt und geht, hinterlässt eine Einheit ohne Satz.

*Bild 11. `Screens/Geraet/GeraetEinstieg*`, `Workout/WorkoutSessionStore.swift`.*

### 11. Satzpfad — die Räder sind immer aktiv

Heute sind die Räder zu, bis man eine der beiden Zahlen antippt
(`GeraetModel.radOffen`, Kopfzeile „antippen und scrollen" → „scrollen, dann
sichern"). Der Tap fällt weg: **gescrollt wird sofort.**

Damit fällt auch der Grund für zwei Layouts weg (siehe Punkt 13) — es gibt nur
noch einen Zustand.

**Wohin mit Rückblick und Empfehlung.** Beide stehen heute nur im
geschlossenen Zustand: „Zuletzt 55,0 kg × 10" (`GeraetModel.zuletztText`) unter
den Werten, „Vorschlag · +2,5" (`vorschlagText`) in der Kontextzeile. Sie
ziehen in einen **Drawer, der beim Öffnen des Geräts von unten hereinkommt** —
einmal am Anfang, nicht nach jedem Satz. Weggewischt bleibt der Satzpfad
zurück: Räder aktiv, ein Layout, nichts, was ihn höher macht (Punkt 12).

Zwei Regeln dazu stehen fest: er kommt **nur vor dem ersten Satz** eines
Geräteblocks, nicht vor jedem weiteren, und beim **ersten Mal an diesem Gerät**
kommt er gar nicht — ohne letzten Satz und ohne Vorschlag hätte er nichts zu
sagen.

*Bild 12, Bild 15. `Screens/Geraet/WertZeile.swift`, `Screens/Geraet/GeraetModel.swift`.*

### 12. Satzpfad — alles auf einen Screen

Der Satzpfad soll ohne Scrollen der Seite lesbar sein: Kopf, Einstellwerte,
beide Räder, „Satz N sichern", „Gerät abschließen". Gescrollt wird nur in den
Rädern.

Das ist mit Punkt 11 zusammen zu rechnen — der offene Zustand ist der höhere.
Kandidaten zum Kürzen: die Einstellwerte als eine Zeile (Punkt 13), „Problem
melden" als Zeile statt als dritter Knopf.

*Bild 13. `Screens/Geraet/GeraetView.swift`.*

### 13. Einstellwerte — eine Darstellung statt zwei

„Sitzhöhe 1 · Rückenlehne 1 · ändern" (eine schmale Zeile) und die Karte mit
großen Zahlen („SITZHÖHE 4 / RÜCKENLEHNE 2 / ändern") sind derselbe Inhalt in
zwei Gestalten — heute umgeschaltet über `radOffen` (`GeraetView.einstellung`).
Es bleibt eine. Mit Punkt 11 entscheidet sich das von selbst: die schmale
Zeile, weil sie in Punkt 12 den Platz nicht frisst.

*Bild 14, Bild 15. `Screens/Geraet/GeraetView.swift`, `einstellung`.*

### 14. Geräteeinstieg — ein Bild der Übung

Oben auf dem Einstieg steht heute ein leerer Kasten mit Platzhalter-Symbol.
Dort gehört ein Bild hin, und zwar **von der Übung**, nicht nur vom Gerät.

Was da ist und was fehlt:

- Angezeigt wird heute `equipmentModel.photoUrl` — **ein** Foto je
  Gerätemodell (Bucket `equipment-photos`, `machine-context.ts`). Steht die
  Rudermaschine für „Rudern sitzend" und „Rudern eng", zeigen beide dasselbe
  Bild; ist keins hochgeladen, steht der leere Kasten da.
- Je **Modell und Übung** gibt es bereits eine Ablage:
  `instruction_assets.equipment_model_exercise_id` — aber nur mit
  `kind = 'video'` (Einweisungsvideo, Bucket `instruction-videos`). Ein Bild
  gehört genau dorthin: **`check (kind = 'video')` wird auf
  `('video','image')` erweitert** (entschieden, keine eigene Tabelle), Bucket
  `exercise-photos` oder die Fotos mit in `equipment-photos`, Pflege im Portal
  neben dem Video. `duration_s` muss dabei für Bilder nullable werden — der
  Check `duration_s > 0 and <= 45` gilt nur noch für Videos.
- Bis ein Studio ein Übungsbild hinterlegt hat, bleibt das Gerätefoto der
  Rückfall — und wenn auch das fehlt, steht besser gar kein Kasten da als ein
  leerer.

*Bild 19. `Screens/Geraet/GeraetErkanntView.swift`, `packages/domain/src/machine-context.ts`,*
*`supabase/migrations/0006_instruction_assets.sql`, Portal-Medienpflege.*

### 15. Home — Trainings teilweise zusammenfassen

Ein Freitag mit fünf Einträgen (08:32, 10:14, 13:20, 14:00, 15:36) sind nicht
fünf Trainings. Was zeitlich zusammengehört, gehört in eine Karte.

Der Grund liegt in der heutigen Regel: eine Einheit endet selbsttätig, wenn
vier Stunden lang kein Satz kam (`WorkoutSessionStore.sessionPause`) — und
sonst nur, wenn jemand „Training beenden" drückt. Wer das vergisst und später
wiederkommt, erzeugt eine zweite Einheit; wer zwischendurch beendet und nach
zwanzig Minuten weitermacht, auch. Mit Punkt 10 (Start schon beim
Geräteeinstieg) wird das eher häufiger.

Die Regel steht (entschieden):

- **Zusammengefasst wird nur in der Anzeige** (`HomeZeilen`). Die Einheiten
  bleiben in den Daten getrennt, die Karte fasst sie zusammen; keine
  Serverabfrage hängt rückwirkend Sätze um, und das Session-Detail zeigt die
  Teile untereinander.
- **Unter 60 Minuten Lücke** gehört es zusammen, darüber ist es ein neues
  Training. Gemessen zwischen dem Ende der einen und dem Beginn der nächsten
  Einheit.

Offen bleibt nur die Beschriftung: die zusammengefasste Karte trägt die
Spanne über alle Teile (Beginn des ersten bis Ende des letzten), Zeit und
Sätze summiert — die enthaltene Pause zählt dabei nicht als Trainingszeit,
sonst wäre die große Zahl aus Punkt 17 gelogen.

*Bild 20. `Verlauf/HomeZeilen.swift`, `Screens/Home/HomeRootView.swift`,*
*`Screens/Home/SessionDetailView.swift`.*

### 16. Gerät wählen — Bild je Gerät in der Liste

Die Liste („Rudermaschine · 20 · Freihantelbereich Nord · vor 2 Stunden ·
7,5 kg") ist reine Typografie. Ein kleines Bild je Zeile macht das Suchen im
Studio schneller als jeder Name.

Genutzt wird dasselbe Foto wie auf dem Einstieg (`equipment_models.photo_url`),
also ohne neue Datenhaltung — nur als Vorschaugröße. Ohne Foto bleibt die
Zeile wie heute, ohne grauen Platzhalterkasten.

*Bild 21. `Workout/GeraeteAuswahl.swift`, `Screens/Geraet/GeraeteAuswahlView.swift`.*

### 17. Home — Uhrzeit kleiner, Zeit und Sätze groß

Auf der Trainingskarte ist heute die **Uhrzeitspanne** die größte Zahl
(„15:36 – 16:16"), darunter klein „41 min · 1 Gerät · 3 Sätze". Das dreht sich
um: **Zeit und Satzzahl werden groß, die Uhrzeitspanne klein.**

Keine Intensität — entschieden. Die Idee (Volumen je Minute) war ein
Kandidat, sie fällt vorerst weg; Zeit und Sätze reichen. Die Gerätezahl bleibt
klein neben der Uhrzeit stehen, sie beantwortet „was war das für ein
Training", nicht „wie viel".

*Bild 22. `Verlauf/HomeZeilen.swift` (`zeilenText`), `Screens/Home/HomeRootView.swift`.*

### 18. Übungsfortschritt — Bild der Übung je Zeile

Dieselbe Sache wie Punkt 14, an zweiter Stelle: die Zeilen des
Übungsfortschritts („22 · Beincurler liegend  55,0 kg  ±0") bekommen das
Übungsbild als kleine Vorschau. Setzt Punkt 14 voraus (Bild je Modell und
Übung); bis dahin bliebe nur das Gerätefoto, das für zwei Übungen am selben
Gerät dasselbe wäre.

*Bild 23. `Screens/Home/HomeRootView.swift` (`fortschrittsZeile`).*

### 19. Ein Training nachträglich löschen

Ein Fehlstart, ein Test, eine Einheit, die jemand anders auf dem Gerät
ausgelöst hat — das muss weggehen können. Heute geht es nicht: es gibt
**keine Delete-Policy** auf `workout_sessions` und `workout_sets`
(0012/0013 kennen nur select, insert, update), und keinen Weg in der App.

Was dazugehört:

- **Server.** Eine Delete-Policy für die eigenen Zeilen — `user_id =
  auth.uid()`, wie bei select seit der Datenschutzgrenze (0033). Die Sätze
  hängen mit `on delete cascade` an der Session, sie gehen von selbst mit.
  Löschen statt Verstecken: es sind die Daten des Mitglieds, und ein
  `deleted_at`, das überall mitgefiltert werden muss, ist die schlechtere
  Wahrheit.
- **Was sich mitbewegt.** Serie (`serie.ts`), Fortschritt und die Rekorde aus
  Punkt 9a rechnen aus denselben Zeilen — sie stimmen nach dem Löschen von
  selbst, auch wenn eine Serie dadurch rückwirkend reißt. Das ist richtig so.
  Der Studio-Überblick (`0034_studio_ueberblick.sql`) zählt Einheiten pro Tag
  und wird ebenfalls kleiner; das ist die ehrliche Folge und kein Fehler.
- **Client.** Warteschlange mitnehmen: liegen für die gelöschte Einheit noch
  ungesendete Sätze in `PendingWriteStore`, müssen die mit weg, sonst
  erscheint die Einheit nach dem nächsten Reconnect wieder.
- **Zwei Wege in der App.** Im Session-Detail, mit Rückfrage und ohne
  Rückgängig — nicht als Wisch auf der Home-Karte, dafür liegen Öffnen und
  Löschen zu nah beieinander. Und **auf dem Abschluss-Screen**: wer „Training
  beenden" drückt, sieht die Zusammenfassung, und dort steht neben „Fertig"
  ein **„Verwerfen"** (entschieden). Das ist der Moment, in dem man merkt,
  dass die Einheit ein Fehlstart war — nicht drei Tage später im Verlauf.
  Verwerfen ist dort die Nebenaktion, „Fertig" bleibt die Hauptaktion, und
  die Rückfrage bleibt auch hier.

Beim Löschen eines Teils einer zusammengefassten Karte (Punkt 15) geht nur
dieser Teil, nicht der ganze Tag.

*Ohne Bild, aus der Besprechung. `Screens/Home/SessionDetailView.swift`,*
*neue Migration, `packages/domain/src/sessions.ts`, `Catalog/PendingWriteStore.swift`.*

### 20. Kursteilnahme zählt als Einheit

Wer im Kurs war, hat trainiert — heute sieht die App das nicht. Verlauf,
Serie und „Einheiten gesamt" kennen ausschließlich `workout_sessions`; ein
Body-Pump am Montag hinterlässt dort nichts.

Künftig steht die Teilnahme **in der Liste der Einheiten** (mit **Name und
Dauer** des Kurses statt Geräten und Sätzen: „Body-Pump · 60 min") und
**zählt in der Serie** wie ein Gerätetraining.

Der Haken sitzt in den Daten: **es gibt keine Anwesenheit.**
`course_bookings.status` kennt nur `booked`, `waitlisted`, `cancelled` — ob
jemand wirklich da war, weiß niemand. Drei Wege:

1. **Aus der Buchung ableiten:** `booked` + Termin vorbei + nicht abgesagt =
   teilgenommen. Kostet nichts, ist aber eine Annahme — und die App sagt sonst
   „gymodo misst nichts, es zeigt, was du bestätigst". Vertretbar, weil sich
   die Einheit über Punkt 19 löschen lässt: wer doch nicht da war, nimmt sie
   weg.
2. **Nachfragen:** nach dem Kurs einmal „Warst du dabei?" — ehrlich, aber ein
   Schritt mehr, und wer nicht antwortet, verliert den Tag in der Serie.
3. **Einchecken lassen** (Aufkleber am Kursraum, wie am Gerät) oder das Studio
   abhaken lassen — am genauesten, am teuersten.

Mein Vorschlag ist 1, mit der Löschmöglichkeit als Korrektur.

Was daran hängt:

- **Serie und Zählung** (`serie.ts`, `getSessions`) rechnen heute auf
  `workout_sessions`. Die Kurstermine kommen als zweite Quelle dazu — die
  Trainingstage sind dann die Vereinigung beider, ein Tag mit Kurs UND
  Gerätetraining zählt einmal.
- **Die Karte ist eine andere.** Kein „3 Geräte · 7 Sätze", sondern Name und
  Dauer; das Antippen führt ins Kursdetail, nicht ins Session-Detail. Zeit und
  Sätze groß (Punkt 17) heißt hier: Dauer groß, Kursname darüber.
- **Zusammenfassen (Punkt 15) gilt hier nicht.** Ein Kurs neben einem
  Gerätetraining bleibt eine eigene Karte, auch wenn beides in einer Stunde
  liegt — es sind zwei verschiedene Dinge.
- **Stats (Punkt 9) lassen den Kurs aus.** Ohne Sätze gibt es kein Volumen und
  keinen Rekord; die Karte trägt Name und Dauer, mehr nicht.

*Ohne Bild, aus der Besprechung. `packages/domain/src/serie.ts`,*
*`packages/domain/src/sessions.ts`, `Verlauf/VerlaufStore.swift`, `Verlauf/HomeSerie.swift`,*
*`Screens/Home/HomeRootView.swift`.*

### 21. Home — laufendes Training oben rechts

Läuft ein Training, soll es auch auf Home zu sehen sein, oben rechts: wie
im Training-Tab mit „Training läuft“ und der gelaufenen Zeit. Ohne
laufendes Training steht dort nichts, wie in der Mitte des Training-Tabs.

Die Ableitung gibt es mit Schnitt 2 schon (`TrainingTab.mitte`), die
Anzeige wäre eine zweite Stelle dafür. Offen ist der Platz: oben rechts
steht seit Schnitt 1 der Umschalter „Monatsansicht/Wochenansicht“ in der
Kopfzeile von `HomeSerieView`. Einer von beiden muss ausweichen. Ob ein
Tap darauf in den Training-Tab führt, ist ebenfalls offen.

*Ohne Bild, aus der Besprechung zu Schnitt 2 (15. September).*
*`Screens/Home/HomeSerieView.swift` (`kopfzeile`), `Workout/TrainingTab.swift`.*

## Umsetzung: Schnitte und Reihenfolge

Zwanzig Punkte sind kein Vorhaben, sondern sieben. Geschnitten ist nach
**einem Grund je Schnitt** — nicht nach Screen und nicht nach Bildnummer:
was dieselbe Regel ändert, dieselbe Migration braucht oder denselben
Zustand umbaut, gehört zusammen. Sortiert ist nach **Risiko und
Abhängigkeit**: erst was nur die Oberfläche anfasst, dann was das Verhalten
ändert, dann was das Datenmodell erweitert.

Jeder Schnitt ist für sich auslieferbar und endet grün (`xcodebuild test`,
`pnpm test`, betroffene Specs nachgezogen).

### Schnitt 0 — Stand nachziehen (Voraussetzung, nicht meine Arbeit)

Der Monatskalender auf Home, der Startblock mit „Suchen" und die
Gerätenummern im Session-Detail liegen nur im Build, nicht im Repo (siehe
Vorbemerkung). Ohne diesen Schritt arbeitet jeder Schnitt unten gegen einen
Screen, den es hier nicht gibt.

### Schnitt 1 — Kalender, Karten, Überschriften (Client, ohne Server)

**Punkte 1, 4, 6, 7, 15, 17.** Ein Grund: der Verlauf soll auf einen Blick
lesbar sein.

- Die Regel „heute = Akzent, ausgewählt = Weiß" in beiden Streifen
  (Home-Kalender und Kurse-Wochenplan), Designsystem §2 nachziehen.
- „Wochenansicht" nach oben rechts.
- Kurse-Band: Überschriften nach Wochenabstand.
- Trainingskarte: Zeit und Sätze groß, Uhrzeit klein.
- Benachbarte Einheiten (< 60 min Lücke) in einer Karte zusammenfassen,
  Session-Detail zeigt die Teile untereinander.

Reine Ableitungen, alle in `HomeZeilen` / `KurseMeineEinteilung` prüfbar —
der Schnitt kostet wenig und macht die vier folgenden sichtbar besser.
Er geht zuerst, weil er nichts voraussetzt und nichts blockiert.

### Schnitt 2 — Training-Tab (Client, ohne Server)

**Punkte 3, 8, 16.** Ein Grund: der Tab soll zeigen, was gerade ist, und den
Start in die Daumenzone holen.

- Startwege nach unten, laufendes Training samt Uhr in die Mitte.
- Geräteliste mit Vorschaubild (nutzt `equipment_models.photo_url`, also
  ohne neue Daten — deshalb hier und nicht im Bilder-Schnitt).

### Schnitt 3 — Satzpfad am Gerät (Client, ohne Server)

**Punkte 11, 12, 13.** Ein Grund: `radOffen` verschwindet, und damit fällt
alles weg, was daran hing.

- Räder immer aktiv, Kopfzeile ohne „antippen".
- Empfehlung und letzter Satz als Drawer von unten — nur vor dem ersten Satz
  eines Blocks, beim ersten Mal am Gerät gar nicht.
- Einstellwerte nur noch als schmale Zeile.
- Ergebnis messen: passt der Pfad ohne Seiten-Scrollen auf ein iPhone mini
  bei Standard-Dynamic-Type?

### Schnitt 4 — Was eine Einheit ist (Client + eine Migration)

**Punkte 10, 19.** Ein Grund: der Anfang und das Ende einer Einheit ändern
sich — und beides gehört in denselben Schnitt, weil der frühere Start genau
die Fehleinheiten erzeugt, die das Löschen wieder wegnimmt.

- Einheit entsteht auf einem eigenen Screen „Training starten“ nach
  Geräte- und Übungswahl (entschieden 15. September, siehe Punkt 10), dort
  beginnt die Uhr; drei Texte umschreiben; M1-Spec §5.6 nachziehen; eine
  Einheit ohne Satz wird verworfen und nie gemeldet.
- Delete-Policy auf `workout_sessions` (Sätze per Cascade), Warteschlange
  miträumen.
- „Verwerfen" auf dem Abschluss-Screen, Löschen im Session-Detail.

Riskantester Schnitt der Reihe: er ändert, was gezählt wird. Deshalb nach
den drei Oberflächenschnitten, aber vor allem, was auf Einheiten aufbaut.
Wer die Testdaten früher loswerden will, kann das Löschen (19) auch schon in
Schnitt 1 mitnehmen — es hängt an nichts.

### Schnitt 5 — Bild der Übung (Server + Portal + Client)

**Punkte 14, 18.** Ein Grund: ein fehlendes Medium an der Übung, nur mit
Pflege im Portal sinnvoll — eine Migration, ein Portalfeld, ein
Durchreichen.

- `instruction_assets.kind` auf `('video','image')`, `duration_s` nullable,
  Bild je Modell und Übung, Pflege neben dem Video.
- Anzeige auf dem Geräteeinstieg (Rückfall Gerätefoto, sonst kein Kasten)
  und in den Fortschrittszeilen.

Der einzige Schnitt des ersten Umfangs, der das Trainerportal anfasst — und
der einzige, der externe Arbeit braucht: ohne hochgeladene Bilder sieht man
nichts. Deshalb früh anfangen, spät bewerten.

### Schnitt 6 — Kurse zählen als Einheit (Server + Client)

**Punkt 20.** Ein Grund: eine zweite Quelle für „Einheit" — Liste, Zählung
und Serie lesen ab hier aus zwei Töpfen.

- Teilnahme aus der Buchung ableiten (gebucht, Termin vorbei, nicht
  abgesagt), Korrektur über das Löschen aus Schnitt 4.
- `serie.ts` und `getSessions` um Kurstermine erweitern, Trainingstage als
  Vereinigung.
- Eigene Karte mit Name und Dauer, Antippen führt ins Kursdetail; kein
  Zusammenfassen mit Gerätetrainings.

### Schnitt 7 — Rekorde und die Grafik (Server + Client)

**Punkte 2, 9a.** Ein Grund: alles, was aus der eigenen Historie gerechnet
wird.

- Rekorde je Gerät und Übung **serverseitig** über die ganze Historie, nicht
  aus dem 50er-Fenster.
- Verlaufsreihe **je Übung** für die Grafik auf dem Abschluss-Screen, die
  Rekordmarke darin.
- Kurse bleiben außen vor (keine Sätze, kein Volumen).

Zuletzt im ersten Umfang, weil er auf einer sauberen Einheitendefinition aus
Schnitt 4 und auf dem sitzt, was Schnitt 6 zusätzlich zählt.

### Umfang 2 — Muskelgruppe und die übersetzten Stats

**Punkte 5, 9b.** Bewusst abgetrennt: die Muskelgruppe kommt ins
Datenmodell, aber die Ausgestaltung kommt noch (Aufzählung, Pflege, wer
zuordnet). Ohne sie hat auch die Hubarbeit keinen Hubweg — beide warten
zusammen.

- Muskelgruppe an der Übung, Pflege im Portal, Gruppierung im
  Übungsfortschritt.
- Hubweg als Vorgabe je Muskelgruppe, daraus die Hubarbeit, daraus die
  Vergleichsleiter („ein Wasserkasten in den 3. Stock" bis „ein Elefant"),
  überall als Überschlag beschriftet.

### Was wovon abhängt

- 12, 13 ⟵ 11 (ohne `radOffen` kein zweites Layout)
- 15 ⟵ 10 (der frühere Start erzeugt mehr Bruchstücke)
- 19 ⟶ 10, 20 (die Korrektur für Fehleinheiten und falsche Kurstage)
- 18 ⟵ 14 (ohne Übungsbild bliebe das Gerätefoto, für zwei Übungen dasselbe)
- 9b ⟵ 5 (Hubweg je Muskelgruppe — deshalb beide in Umfang 2)
- 2 ⟵ 9a (der Rekord ist die Marke in der Grafik)

Alles andere steht für sich und könnte auch einzeln gehen.

## Entschieden

Alle sieben Fragen der Sammelrunde sind beantwortet (14. September):

1. **Zusammengefasste Karte** trägt die summierte Trainingszeit groß, die
   Spanne klein daneben — die Pause zählt nicht als Training.
2. **Einheit ohne Satz** wird verworfen und nie gemeldet.
3. **Muskelgruppe** kommt ins Datenmodell, aber erst in Umfang 2; wie genau
   sie geschnitten wird, kommt noch.
4. **Kursteilnahme** wird aus der Anmeldung abgeleitet.
5. **Rekorde** rechnet der Server über die ganze Historie.
6. **Grafik je Übung**, nicht je Training.
7. **Hubweg** als Vorgabe je Muskelgruppe (damit in Umfang 2).

Offen bleibt nur eines, und es kommt von außen: die Ausgestaltung der
Muskelgruppe für Umfang 2.
