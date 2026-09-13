# iOS Member-App — Persönliche Ziele & Fortschritt

**Stand:** 13. September 2026
**Status:** Entschieden am 13. September (Abschnitt 9), Artboards unter `docs/superpowers/design/ziele/`. Noch kein Umsetzungsplan.
**Vorbedingung:** Sub-Projekte 1–4 der Member-App stehen (`0001`–`0040`, Home mit Serien-Streifen, Profil mit Name, `PUT /me/profile`).
**Zitierweise:** `§n` ohne Dokumentangabe verweist auf `2026-08-30-designsystem.md`.
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` (Produktgrenze, M3-Abgrenzung) und `2026-09-09-ios-home-profil-design.md` (Home, Profil, Verlauf-Cache). Es ergänzt beide um eine zweite Sorte Fortschritt: die Person statt das Gerät.

---

## 1. Worum es geht

Heute kennt die App genau eine Art Fortschritt: mehr Gewicht je Übung. Das ist ehrlich, aber schmal — wer ins Studio geht, um abzunehmen oder einfach dranzubleiben, sieht davon nichts.

Dieser Bauabschnitt fügt drei Dinge hinzu:

1. **Ein Onboarding** nach der Registrierung: ein paar Screens mit Angaben zur Person und einem Ziel.
2. **Ziele, die man erreichen kann:** Trainingstage pro Woche, ein Zielgewicht, ein Trainingsziel als Richtung („Abnehmen", „Muskeln aufbauen", …).
3. **Fortschritt auf Home:** Wochenziel neben der Serie, Gewichtsverlauf, Abstand zum Ziel.

**Was es nicht ist:** kein Trainingsplan (M3, M1-Spec §5.5 und Zeile 490), keine Ernährungs- oder Gesundheitsberatung, keine Sensorik. Alles, was hier gespeichert wird, gibt das Mitglied selbst ein — die Produktgrenze aus M1 §4.3 („gymodo misst nichts") gilt unverändert und wird für Körperdaten sogar strenger (Abschnitt 6).

---

## 2. Scope

**Enthalten:**

- Onboarding-Flow (fünf Screens), einmalig, überspringbar, im Profil nachholbar
- Stammdaten: Vorname (bereits da), Geschlecht, Altersspanne, Größe — alle optional
- Körpergewicht als Verlauf: eintragen, ansehen, korrigieren, löschen
- Drei Zielsorten: Trainingstage je Woche · Zielgewicht · Trainingsziel (Richtung)
- Home: Block „Deine Ziele" mit Wochenziel und Gewichtskarte
- Neuer Screen: Gewichtsverlauf (Swift Charts, wie `Uebungsfortschritt`)
- Profil: Abschnitte „Über dich" und „Ziele", alles änderbar und einzeln löschbar
- Serveranteil: drei Migrationen, drei neue Endpoints, zwei erweiterte
- Tests auf allen drei Ebenen (Abschnitt 8)

**Nicht enthalten, mit Grund:**

- **Übungsziele** („100 kg Beinpresse bis Dezember") — fachlich naheliegend, aber `ExerciseProgress` zeigt die Steigerung schon; das Datenmodell lässt sie als vierte Zielsorte zu (Abschnitt 3.3), gebaut werden sie in einer zweiten Runde
- **Apple Health / HealthKit** — ein Import wäre Messdaten von außen; Produktgrenze und App-Review-Aufwand sprechen dagegen, solange das manuelle Eintragen nicht erprobt ist
- **BMI, Kalorien, Körperfett, „gesundes Gewicht"** — jede dieser Zahlen ist eine Gesundheitsaussage; M1 §4.3 verbietet sie der Plattform, und der Betreibervertrag baut darauf
- **Erinnerungen / Push** — existiert nicht (Home-Profil-Spec §2)
- **Sichtbarkeit für Trainer** — Körperdaten kommen nicht in `studio_overview`, auch nicht als Summe (Abschnitt 6)

---

## 3. Datenmodell

Drei Migrationen, alle additiv. Nichts an `workout_*`, nichts an `studios`.

### 3.1 `0041_profil_stammdaten.sql` — Spalten an `profiles`

| Spalte | Typ | Bemerkung |
| --- | --- | --- |
| `sex` | enum `member_sex` (`female`, `male`, `diverse`) | nullable; „keine Angabe" ist `null`, kein vierter Wert |
| `age_band` | enum `age_band` (`under_18`, `18_24`, `25_34`, `35_44`, `45_54`, `55_64`, `65_plus`) | nullable; **Spanne statt Jahr** — noch eine Stufe sparsamer als das Geburtsjahr, und für alles, was die App je damit tun soll (Vorschläge, Pläne), reicht die Spanne. Sie altert nicht mit: wer 35 wird, bleibt in `25_34`, bis er es selbst ändert — ehrlicher als ein Alter, das die App aus einem Jahr rechnet |
| `height_cm` | `smallint` | nullable, Check `between 100 and 250` |
| `training_goal` | enum `training_goal` (`lose_weight`, `build_muscle`, `stay_fit`, `get_stronger`) | nullable; die Richtung, kein Zahlwert |
| `onboarding_completed_at` | `timestamptz` | nullable; gesetzt beim Abschluss **oder** beim Überspringen — das Onboarding erscheint nie zweimal |

`profiles_select_own`, `_update_own`, `_insert_own` aus `0001`/`0039` decken die neuen Spalten ohne Änderung. Kein Spaltenrecht für Personal existiert, keines kommt dazu.

**Warum Geschlecht erhoben wird, obwohl heute keine Funktion damit rechnet:** Entscheidung vom 13. September (Abschnitt 9) — als Grundlage für Startgewicht-Vorschläge am Gerät und später für Trainingspläne (M3). Beides ist nicht Teil dieser Runde; die Spalte ist vorbereitet, nicht ausgewertet. Bis eine Funktion sie liest, sagt der Onboarding-Screen, wofür sie gedacht ist.

### 3.2 `0042_body_measurements.sql` — Körpergewicht als Verlauf

```
body_measurements
  id            uuid pk
  user_id       uuid not null -> auth.users on delete cascade
  measured_on   date not null           -- Ortstag, vom Client geliefert
  weight_kg     numeric(5,1) not null   -- Check 20.0 .. 400.0
  created_at    timestamptz not null default now()
  unique (user_id, measured_on)
```

Drei Entscheidungen darin:

- **Kein `studio_id`.** Jede Trainingstabelle seit `0012` hängt am Studio, und wer austritt, verliert den Blick auf seine dortige Historie. Für das Körpergewicht wäre das falsch: es gehört zur Person, nicht zur Halle. Wer das Studio wechselt, nimmt seine Kurve mit. Das ist eine bewusste Abweichung von der `0012`-Regel und steht deshalb hier und im Migrationskommentar.
- **Ein Wert je Tag.** Zwei Wiegungen am selben Tag sind keine zwei Messpunkte, sondern eine Korrektur — der Schreibweg ist ein `upsert` auf `(user_id, measured_on)`. Dasselbe Muster wie `getProgress`: je Tag ein Punkt.
- **`measured_on` als `date`, nicht `timestamptz`.** Gewogen wird morgens; der Tag ist die Wahrheit, die Uhrzeit Rauschen. Der Client liefert den Ortstag, der Server rechnet keine Zeitzone.

RLS: `select`/`insert`/`update`/`delete` ausschließlich `user_id = auth.uid()`. **Keine Staff-Klausel, keine Mitgliedschaftsprüfung** — es gibt kein Studio, das mitreden könnte.

### 3.3 `0043_member_goals.sql` — Ziele mit Geschichte

```
member_goals
  id            uuid pk
  user_id       uuid not null -> auth.users on delete cascade
  kind          enum goal_kind ('weekly_days', 'target_weight')   -- später: 'exercise_weight'
  target_value  numeric(6,1) not null   -- Tage (1..7) bzw. kg (20..400), je Sorte geprüft
  exercise_id   uuid null -> exercises  -- nur für 'exercise_weight', in dieser Runde immer null
  status        enum goal_status ('active', 'reached', 'dropped')
  created_at    timestamptz not null default now()
  reached_at    timestamptz null
  unique-partial (user_id, kind) where status = 'active'
```

**Warum eine Tabelle und nicht zwei Spalten an `profiles`.** Ein Ziel hat einen Anfang und ein Ende. „Zielgewicht 78 kg — erreicht am 3. November" ist genau der Moment, für den man das Feature baut; zwei Spalten könnten ihn nicht festhalten. Und wer sein Wochenziel von 2 auf 3 hebt, soll das alte nicht verlieren, sondern abschließen. Der Preis ist eine Tabelle mit einem Partial-Unique-Index — überschaubar.

**Das Trainingsziel (Richtung) bleibt an `profiles`.** Es hat keinen Zahlwert und kein „erreicht"; es ist eine Eigenschaft der Person, kein Ziel im Sinn dieser Tabelle.

**Ziel-Prüfung je Sorte** in einer Check-Funktion, nicht im Client: `weekly_days` ganzzahlig 1–7, `target_weight` 20–400 mit einer Nachkommastelle.

---

## 4. Server-Anteil

Sechs Änderungen, alle in `packages/domain` plus je eine Route.

### 4.1 `GET /me/bootstrap` — `member` wird breiter

```
member: {
  displayName:            string | null,     // wie bisher
  sex:                    "female" | "male" | "diverse" | null,
  ageBand:                "under_18" | "18_24" | "25_34" | "35_44" | "45_54" | "55_64" | "65_plus" | null,
  heightCm:               number | null,
  trainingGoal:           "lose_weight" | "build_muscle" | "stay_fit" | "get_stronger" | null,
  onboardingCompletedAt:  string | null,
  goals: {
    weeklyDays:   { id, targetValue, createdAt } | null,   // das aktive Ziel je Sorte
    targetWeight: { id, targetValue, createdAt } | null
  },
  latestWeight: { measuredOn: string, weightKg: number } | null
}
```

Der Lesepfad hängt am Abruf, der beim Start ohnehin läuft — und **das Onboarding-Gate braucht ihn genau dort** (Abschnitt 5.1): ob die Screens erscheinen, muss feststehen, bevor die Tab-Leiste aufgeht, auch ohne Netz beim zweiten Start. `latestWeight` liegt hier, damit die Gewichtskarte auf Home ohne den Verlaufsabruf einen Wert hat.

### 4.2 `PUT /me/profile` — ein Schreibweg für alle Stammdaten

Der bestehende Endpoint nimmt statt `{ displayName }` ein Teilobjekt: jedes Feld optional, `null` löscht. `anzeigenameSchema` wird zu `profilSchema` mit denselben Prüfungen für den Namen und neuen für die vier Felder; `setDisplayName` wird zu `updateProfile` und behält `upsert`. `onboardingCompletedAt` ist **kein** freies Feld, sondern wird über einen eigenen Schalter `{ onboardingDone: true }` gesetzt — der Client soll das Datum nicht liefern.

Kein zweiter Endpoint für „Stammdaten" neben „Name": Home-Profil-Spec §3.4 hat für den Namen entschieden, dass *ein* Weg für Registrierung und Ändern besser ist als zwei. Das gilt für vier weitere Felder erst recht.

### 4.3 `PUT /me/measurements` und `GET /me/measurements`

- `PUT { measuredOn: "YYYY-MM-DD", weightKg }` — `upsert` auf den Tag, antwortet mit der gespeicherten Zeile. `measuredOn` darf nicht in der Zukunft liegen (geprüft gegen UTC-Tag + 1, damit ein Mitglied in Neuseeland nicht abgewiesen wird).
- `DELETE /me/measurements/[measuredOn]` — löscht den Tag.
- `GET /me/measurements?since=` — alle Punkte aufsteigend, Deckel 1000 (drei Jahre täglich), plus eine Kopfzeile:

```
summary: {
  first:    { measuredOn, weightKg } | null,
  latest:   { measuredOn, weightKg } | null,
  changeKg: number | null            // latest - first
}
```

**Kein gleitender Durchschnitt, kein Trend-Pfeil.** Der Verlauf ist eine Liste eingetragener Zahlen; jede Glättung wäre eine Interpretation, die die Plattform nicht abgibt. Die Kurve zeigt Punkte, die Kopfzeile zeigt Differenz.

### 4.4 `PUT /me/goals` und `DELETE /me/goals/[kind]`

- `PUT { kind, targetValue }` — schließt ein aktives Ziel derselben Sorte als `dropped` ab und legt das neue an, in einer Transaktion (Postgres-Funktion `set_member_goal`, damit der Partial-Unique-Index nie zwischen zwei Statements verletzt wird).
- `DELETE` — setzt das aktive Ziel auf `dropped`. Es gibt kein hartes Löschen; die Geschichte bleibt beim Mitglied bis zur M3-Löschung.

### 4.5 `GET /me/sessions` — die Kopfzeile kennt das Wochenziel

`summary.streak` bekommt ein Feld:

```
streak: {
  weeks, weekStart, today, trainedDays,       // wie bisher, unverändert gerechnet
  weeklyTarget:   number | null               // aktives weekly_days-Ziel
}
```

**Die Serie bleibt, was sie ist: Wochen in Folge mit mindestens einer Einheit.** Entschieden am 13. September (Abschnitt 9, Punkt 5). Das Wochenziel ändert an `serienstand` nichts — keine zweite Schwelle, keine „Wochen im Ziel". Wer sich drei Tage vornimmt und zwei schafft, hat seine Serie nicht gerissen; er hat sein Ziel diese Woche nicht erreicht, und genau das steht in der Zeile unter dem Streifen. Zwei Zahlen, zwei Aussagen, und die strengere von beiden bleibt eine Zeile, keine Flamme.

`weeklyTarget` liegt trotzdem hier und nicht nur im Bootstrap: die Zeile „2 von 3 Tagen" braucht `trainedDays` und das Ziel aus demselben Abruf, sonst zeigt ein alter Cache das eine gegen das andere. Der Vergleich selbst — Anzahl gegen Ziel — ist die eine Rechnung, die der Client macht; sie ist ein Zählen, keine Wochengrenze.

### 4.6 Was „Ziel erreicht" für das Gewicht heißt

Das Zielgewicht wird beim Schreiben eines Messwerts geprüft, nicht beim Lesen: `PUT /me/measurements` vergleicht nach dem Upsert den neuen Wert mit dem aktiven `target_weight`-Ziel und setzt es auf `reached`, wenn die Richtung stimmt. **Die Richtung ergibt sich aus dem ersten Messwert:** lag der Start über dem Ziel, gilt „≤ Ziel" als erreicht, sonst „≥ Ziel". Kein eigenes Feld „abnehmen/zunehmen" — das Feld wäre eine zweite Wahrheit neben den Zahlen.

Die Antwort des `PUT` trägt `goalReached: true`, damit der Client den Moment zeigen kann, ohne ein zweites Mal zu laden.

---

## 5. iOS

### 5.1 Das Gate: ein fünfter `RootDestination`

`RootDestinationLogic.destination` bekommt einen Fall zwischen Katalog und Tab-Leiste:

```
authFlow → loadingCatalog → onboarding → noStudio | main
```

`onboarding`, wenn `bootstrap.member.onboardingCompletedAt == nil`. **Vor `noStudio`**, nicht danach: die Angaben gehören zur Person, nicht zum Studio, und wer noch keinem beigetreten ist, soll trotzdem nicht zwei Einstiege hintereinander sehen.

**Bestandsmitglieder** — jedes heute existierende Konto — haben `null` und sehen das Onboarding beim nächsten Start einmal. Das ist gewollt: es sind die Entwicklerkonten und synthetische Daten (M1 §3, „keine echten Personendaten bis M2"). Deshalb muss jeder Screen überspringbar sein und „Später" das Gate genauso schließen wie „Fertig".

`RootDestinationTests` bekommt die neuen Fälle; die Ableitung bleibt rein.

### 5.2 Die fünf Screens

Ein `OnboardingFlow` mit eigenem `NavigationStack`, Schrittanzeige oben (`1 / 5`), „Später" rechts oben auf jedem Screen. Kein Zurück zum Login; die Session besteht bereits.

| # | Screen | Eingabe | Vorgabe |
| --- | --- | --- | --- |
| 1 | **Über dich** | Geschlecht (drei Chips), Altersspanne (sieben Chips); „keine Angabe" heißt, nichts zu wählen | nichts gewählt |
| 2 | **Dein Körper** | Größe in cm (`Stepper44`/Rad), Gewicht in kg mit einer Nachkommastelle (`RastRad`, Schritt 0,5) | leer |
| 3 | **Dein Ziel** | vier Kacheln: Abnehmen · Muskeln aufbauen · Fit bleiben · Stärker werden | nichts gewählt |
| 4 | **Wie oft?** | Trainingstage pro Woche, 1–7 | 3 |
| 5 | **Zielgewicht** | nur wenn Schritt 2 ein Gewicht hat, sonst übersprungen; `RastRad` startet beim aktuellen Gewicht | leer |

Danach **„Los geht's"**: schreibt in dieser Reihenfolge `PUT /me/profile` (Stammdaten + `onboardingDone`), `PUT /me/measurements` (falls Gewicht), `PUT /me/goals` (je gesetztem Ziel). Alles, was leer blieb, wird nicht gesendet.

**Bausteine, die schon da sind:** `RastRad` (Gewicht, dieselbe Komponente wie am Gerät), `Stepper44`, `Chip`, `PrimaryButton`/`SecondaryButton`, `LabeledField`, `InlineBanner`. Neu ist nur die Kachel für Schritt 3 — vier Kacheln mit Symbol und Zeile, eine gewählt, Akzent markiert den aktiven Wert (§2).

**Ohne Netz:** das Onboarding braucht eine Verbindung, und das steht auf dem letzten Screen. Schlägt ein Schreibvorgang fehl, bleiben die Antworten im Speicher, der Banner sagt, was fehlt, „Erneut versuchen" wiederholt nur das Fehlende. Kein `PendingWriteStore`-Eintrag — der ist für Sätze da, und Home-Profil-Spec §3.4 hat für den Namen dieselbe Entscheidung getroffen. **Was nie passieren darf:** `onboardingDone` gesetzt, Ziele verloren. Deshalb geht das Profil zuerst und die Ziele danach — scheitern die Ziele, öffnet sich das Gate zwar nicht mehr, aber Home zeigt die Nachholkarte (5.3), und die trägt dieselben Eingaben.

### 5.3 Home: der Block „Deine Ziele"

Zwischen Serien-Streifen und „Letzte Trainings". Drei Zustände:

**Nichts gesetzt** (übersprungen): eine Karte „Ziele festlegen — Wochenziel, Gewicht, Richtung. Dauert eine Minute." mit Knopf, der den `OnboardingFlow` als Sheet öffnet. Dieselben fünf Screens, kein zweiter Flow.

**Wochenziel gesetzt:** der bestehende `HomeSerieView` bekommt rechts im Kopf „Ziel 3 Tage" und unter dem Streifen eine Zeile „2 von 3 Tagen diese Woche" mit einem Strich je Zieltag, gefüllt für jeden Trainingstag. **Flamme und Fußnote bleiben unverändert** — die Flamme zählt weiter jede Woche mit mindestens einer Einheit, die Fußnote weiter „34 Einheiten gesamt · zuletzt gestern". Ohne Ziel fehlt nur die neue Zeile.

**Gewicht gesetzt:** eine Karte mit aktuellem Wert, Datum, Differenz zum ersten Eintrag, Abstand zum Ziel („noch 3,5 kg"), Mini-Kurve der letzten 12 Punkte, und „Eintragen" als Sekundäraktion, die ein Sheet mit dem `RastRad` öffnet, Vorgabe heutiges Datum. Tippen auf die Karte öffnet den Gewichtsverlauf (5.4).

**Ziel erreicht:** einmalig eine Zeile unter der Karte („Zielgewicht erreicht — 78,0 kg am 3. November"), solange kein neues Ziel steht. Kein Konfetti; §5 hält Bewegung für Zustandswechsel, nicht für Belohnung.

Der Verlauf-Cache (`VerlaufFileStore`) trägt die Messwerte mit — sie ändern sich, wie der Verlauf, nur durch eigenes Tun, und `VerlaufHerkunft` gilt unverändert.

### 5.4 Gewichtsverlauf

`Gewichtsverlauf.dc.html` nach dem Vorbild von `Uebungsfortschritt`: eine Kurve, Achse beginnt nicht bei null, Bereich beschriftet, Zeitraum-Umschalter aus `Fortschrittsfenster` (3 Monate · 6 Monate · Alles, lokal gefiltert), darunter die Rohwerte als Liste. Jede Zeile ist per Wischen löschbar (`DELETE /me/measurements/[tag]`), Tippen öffnet dasselbe Eintrag-Sheet mit dem Tag vorbelegt. Zielgewicht als gestrichelte Linie in `text-faint`, wenn gesetzt.

### 5.5 Profil: zwei neue Abschnitte

**„ÜBER DICH"** — Name (bestehende Kopfkarte), Geschlecht, Alter (Spanne), Größe; jede Zeile öffnet einen Picker, jede hat „Entfernen". Schreibt über `PUT /me/profile` mit `null`.

**„ZIELE"** — Trainingsziel (Richtung), Tage pro Woche, Zielgewicht; „Gewicht eintragen" als Zeile; „Gewichtsverlauf" als `NavigationLink`. Dropdown-Änderung schreibt sofort, wie die drei Schalter darunter.

Der Produktgrenze-Satz unter „DEINE DATEN" bekommt einen zweiten: „Deine Körperdaten und Ziele sieht niemand außer dir — auch dein Studio nicht."

### 5.6 Stores

Kein neuer Store. `CatalogStore.bootstrap.member` trägt Stammdaten, aktive Ziele und `latestWeight`; `VerlaufStore` trägt die Messwertliste und ihre Kopfzeile. Beide werden in `RootView` beim Abmelden bereits zurückgesetzt — der Reset gilt damit auch für Körperdaten, ohne eine vierte Zeile.

Neue DTOs: `MemberProfile` (statt `member: { displayName }`), `MeasurementsResponse`, `GoalWrite`. `APIClient` bekommt `updateProfile`, `putMeasurement`, `deleteMeasurement`, `measurements`, `setGoal`, `dropGoal`.

---

## 6. Datenschutz und Produktgrenze

Dieser Bauabschnitt ist der erste, der **Gesundheitsdaten im Sinn von Art. 9 DSGVO** speichert: Gewicht, Größe, Geschlecht. Das ändert drei Dinge gegenüber allem, was bisher gebaut wurde:

1. **Alles freiwillig, alles nullable, alles einzeln löschbar.** Kein Feld ist Voraussetzung für irgendeine Funktion. Die App läuft für ein Mitglied, das fünfmal „Später" tippt, genauso wie heute.
2. **Personal sieht nichts, auch nicht als Summe.** `0033` hat die Trainingsdaten vor dem Personal geschlossen und `studio_overview` als einzige Öffnung gelassen. Körperdaten bekommen **keine** solche Öffnung: `body_measurements` und die neuen `profiles`-Spalten tauchen in keiner `SECURITY DEFINER`-Funktion auf. Der Migrationskommentar hält das fest, damit es später eine Entscheidung ist und kein Versehen.
3. **Keine Interpretation.** Kein BMI, keine Kalorien, kein „gesund"/„übergewichtig", keine Empfehlung, wie viel man abnehmen sollte. Die App zeigt eingetragene Zahlen und ihre Differenz. Das Trainingsziel „Abnehmen" ist eine Absicht des Mitglieds, keine Bewertung durch die Plattform — und der Screen sagt das.

**Datensparsamkeit:** Altersspanne statt Geburtsdatum oder -jahr; Geschlecht ohne Vorauswahl; keine Angabe wird zur Nutzung erzwungen.

**Für M3 (DSGVO-Löschung und -Export):** beide neuen Tabellen hängen mit `on delete cascade` an `auth.users`; der Export ist eine `select`-Abfrage je Tabelle. Nichts hier macht M3 schwerer.

**Vertrag:** Die Rollenverteilung (Studio Verantwortlicher, Plattform Auftragsverarbeiter, M1 §4.3) muss um die Körperdaten ergänzt werden — das Studio bekommt sie nie zu sehen, verarbeitet sie aber formal. Das ist eine Frage für den Rechtstext, nicht für den Code, und blockiert das Bauen nicht.

---

## 7. Design vor Code

Wie bei jedem Bauabschnitt seit Phase 3: erst die Artboards, dann der Plan. Neu zu zeichnen unter `docs/superpowers/design/ziele/`:

- `Onboarding1` bis `Onboarding5` — der letzte Screen landet direkt auf Home; ein eigener „Fertig"-Screen wäre ein Zwischenschritt ohne Inhalt
- `Main` (Home mit Zielen), `HomeNachholen` (übersprungen), `HomeZielErreicht`
- `Gewichtsverlauf` und `GewichtEintragen` (Sheet)
- `Profil` (beide neuen Abschnitte) und `ProfilAlter` (ein Picker-Sheet mit „Entfernen", stellvertretend für alle)
- `Bausteine` — Chips, Zielkachel, Wochenzielmarke, Gewichtskarte

Gezeichnet am 13. September, Canvas: `docs/superpowers/design/ziele/`.

Bausteine aus `member/Fundament.dc.html`; neu nur die Zielkachel.

---

## 8. Tests

**Unit (`packages/domain`), weil rein:**

- `serienstand` bleibt unverändert — ein Test sichert zu, dass ein gesetztes Wochenziel die Serie nicht verändert: Ziel 3, Woche mit 2 Tagen, Serie läuft weiter
- `profilSchema`: jedes Feld einzeln gültig, ungültig, `null`; `ageBand` nur aus der Liste; `onboardingDone` nur `true`
- `zielErreicht(start, ziel, neu)`: Richtung aus dem Start, Gleichstand zählt, kein Start → nie erreicht
- `messwertSchema`: Datum in der Zukunft, Gewicht außerhalb 20–400, zwei Nachkommastellen

**Integration (`tests/integration`), neben den bestehenden:**

- `rls-body-measurements`: eigene Zeilen lesbar, fremde nicht, **Trainer des eigenen Studios sieht nichts**, Austritt aus dem Studio ändert nichts
- `rls-member-goals`: dasselbe Muster; zwei aktive Ziele derselben Sorte scheitern am Index; `set_member_goal` schließt das alte ab
- `domain-measurements`: Upsert je Tag, `summary` mit einem und mit vielen Punkten, `goalReached` in beide Richtungen
- `api-profil`: Teilobjekt ändert nur die gesendeten Felder, `null` löscht, `onboardingCompletedAt` ist nicht direkt beschreibbar
- `domain-bootstrap`: `member` vollständig für ein Konto ohne Zeile (alles `null`) und mit
- `studio-ueberblick`: bleibt unverändert — ein Test, der zusichert, dass der Rückgabewert keinen Schlüssel mit Körperdaten enthält

**iOS, reine Ableitungen ohne UI:**

- `RootDestinationTests`: `onboarding` vor `noStudio`, nie bei gesetztem Datum, nie ohne Session
- `OnboardingSchritteTests`: Schritt 5 fällt ohne Gewicht weg; „Später" auf Schritt 2 lässt die Antworten aus Schritt 1 stehen; Schreibreihenfolge und Teilwiederholung nach Fehler
- `HomeSerieTests`: Zielzeile „2 von 3 Tagen"; Fußnote mit und ohne Ziel; Vorlesetext
- `HomeZielkarteTests`: Abstand zum Ziel mit Vorzeichen, „erreicht"-Zeile nur ohne neues Ziel, Mini-Kurve nimmt die letzten 12
- `ZahlformatTests`: Gewicht mit einer Nachkommastelle in beide Richtungen (`78,5`, gesprochen „78 Komma 5 Kilogramm")

**Verifikation** wie in SP2–SP4: Kaltbau mit isoliertem `-derivedDataPath`, Verzeichnisse danach löschen; keine neue Warnung in einer Datei, die dieser Bauabschnitt schreibt.

---

## 9. Entscheidungen

Vier Fragen standen offen; entschieden am 13. September.

1. **Geschlecht und Alter bleiben.** Alter als **Spanne**, nicht als Jahr (3.1). Geschlecht als Grundlage für spätere Startgewicht-Vorschläge am Gerät und für Trainingspläne (M3) — in dieser Runde gespeichert, nicht ausgewertet.
2. **Wochenziel in Tagen.** Der Streifen zählt Tage, das Ziel auch; zwei Einheiten an einem Tag sind ein Trainingstag.
3. **Onboarding-Gate vor dem Studiobeitritt.** Die Angaben gehören zur Person; „Später" hält den Weg zum Scan kurz.
4. **Übungsziele in Runde 2.** Das Datenmodell lässt sie zu (`exercise_weight`, `exercise_id`); `ExerciseProgress` zeigt die Steigerung schon.
5. **Die Serie hängt nicht am Wochenziel.** Sie zählt weiter Wochen mit mindestens einer Einheit, wie seit dem Serien-Streifen. Das Wochenziel ist eine eigene Zeile darunter — wer sein Ziel verfehlt, verliert dadurch keine Serie. Die frühere Fassung dieser Spec („Wochen im Ziel" in der Flamme) ist damit zurückgenommen.

---

## 10. Reihenfolge der Umsetzung

Für den Umsetzungsplan (`writing-plans`), grob in Aufgaben:

1. Artboards (Abschnitt 7) und Freigabe der offenen Fragen (Abschnitt 9)
2. `0041`–`0043` mit RLS-Tests, einschließlich des Nicht-Sichtbarkeitstests für Personal
3. Fachschicht: `profil.ts` erweitern, `measurements.ts`, `goals.ts`, `serie`-Schwelle in `sessions.ts`, `bootstrap.ts`; Unit-Tests
4. Routen und Integrationstests
5. iOS: DTOs, `APIClient`, `RootDestination`-Gate, Store-Erweiterungen
6. `OnboardingFlow` mit seinen Schritten und dem Schreibweg
7. Home-Block, Gewichtsverlauf, Eintrag-Sheet
8. Profil-Abschnitte
9. Manuelle Abnahme nach dem Muster von `2026-09-11-satzpfad-feinschliff.md`, mit Gegenprobe im Portal: ein Trainer sieht im Überblick nichts Neues

Migrationen vor Deploy, wie in `2026-09-01-gesamtfahrplan.md` §4f begründet: der neue `bootstrap` liest Spalten, die es ohne `0041` nicht gibt.

---

## 11. Selbstprüfung

- Kein Bedienelement ohne Ziel: die Nachholkarte erscheint nur ohne Ziele, die Zielgewicht-Linie nur mit Ziel, Screen 5 nur mit Gewicht.
- Keine Zahl ohne Deckung: die Serie rechnet weiter nur der Server, `changeKg` steht neben seinen Rohwerten, kein Trend, kein BMI.
- Keine zweite Antwort auf eine bestehende Frage: ein Profil-Schreibweg, ein Onboarding-Flow für Erststart und Nachholen, ein Rad für Gewicht am Gerät und am Körper, ein Reset beim Abmelden.
- Die Produktgrenze wird enger, nicht weiter: mehr Daten, aber weniger, die jemand außer dem Mitglied sieht.
- Alles Neue ist nullable, löschbar und überspringbar.
