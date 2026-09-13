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
- **Der Weg in der App.** Im Session-Detail (nicht auf der Home-Karte —
  Wischen zum Löschen neben einer Liste, die man zum Öffnen antippt, ist zu
  nah beieinander), mit Rückfrage und ohne Rückgängig.

Zu klären: darf auch die **laufende** Einheit verworfen werden („Training
verwerfen" statt „Training beenden")? Und was passiert beim Löschen eines
Teils einer zusammengefassten Karte (Punkt 15) — nur der Teil, nehme ich an.

*Ohne Bild, aus der Besprechung. `Screens/Home/SessionDetailView.swift`,*
*neue Migration, `packages/domain/src/sessions.ts`, `Catalog/PendingWriteStore.swift`.*

## Offene Fragen

1. Punkt 2: Grafik je Übung (Gewichtsverlauf über die letzten Einheiten) oder
   eine je Training?
2. Punkt 9a: Rekorde vom Server oder aus dem geladenen Fenster gerechnet?
3. Punkt 9b: Hubweg als gepflegtes Feld, als Vorgabe je Muskelgruppe oder gar
   nicht (nur Volumen in Kilogramm)?
4. Punkt 5: Muskelgruppe ins Datenmodell mit Pflege im Portal — oder erst
   einmal mit einer Vorgabeliste je Studio?
5. Punkt 10: Einheit ohne einen einzigen Satz — verwerfen (mein Vorschlag)
   oder als leere Einheit behalten?
6. Punkt 15: trägt die zusammengefasste Karte die summierte Trainingszeit
   (ohne die Pause dazwischen) — oder die Spanne von Anfang bis Ende?
7. Punkt 19: darf auch die laufende Einheit verworfen werden?
