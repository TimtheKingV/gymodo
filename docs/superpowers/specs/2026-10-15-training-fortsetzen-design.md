# Training fortsetzen – Design

## Anlass

Die Testsitzung vom 14.10., 18:45 hatte zwei Notizen dazu.

- **#3:** Ein Training soll man innerhalb von 30 min fortsetzen können. Ein Tipp auf die Karte auf Home öffnet die Zusammenfassung, dort steht „Fortsetzen“.
- **#4:** „Fortsetzen“ ist ein Play-Button oben rechts.

**Typischer Fall:** zu früh auf „Training beenden“ getippt, oder nach dem Beenden doch noch eine Übung gemacht.

## Entscheidungen (Brainstorming 14./15.10.)

1. **Die Lücke zählt als Pause.**
   - Beispiel: beendet 18:52, fortgesetzt 19:10, fertig 19:30. Das ergibt ein Training 17:47–19:30. Die 18 Minuten dazwischen zählen nicht zur Dauer.
   - Die Uhr läuft beim Fortsetzen da weiter, wo sie stand.
2. **Das Zeitfenster sind 30 Minuten ab „Training beenden“** (`completed_at`), nicht ab dem letzten Satz.
3. **Nach „Fortsetzen“ geht es in den Training-Tab** mit laufendem Training („Gerät wählen“ mit Uhr und Blöcken).
4. **Dieselbe Einheit wird wieder geöffnet** (Ansatz 1), statt eine neue zu beginnen, die nur in der Anzeige mit der alten zusammengelegt würde.
   - **Begründung:** Die Uhr läuft weiter, die Blöcke bleiben, die Gesamtzahl der Einheiten stimmt, und die Vorschläge rechnen über das ganze Training.
5. **Der Server bekommt eine Pausensumme.** Sonst würde die Lücke auf Home mitzählen.
   - Sie gilt auch für normale Pausen. Ein Training zeigt auf Home künftig die Dauer ohne Pausen.
   - Alte Trainings haben 0 und bleiben unverändert.

## Abgrenzung

- **Fortsetzen geht nur auf dem Gerät, auf dem beendet wurde.** Die App braucht dafür die lokale Ablage der Einheit. Einen Wiederaufbau aus dem Server-Verlauf gibt es nicht (YAGNI).
- **Kein Fortsetzen einer selbsttätig beendeten Einheit.** Bei ihr liegt `completed_at` beim letzten Satz, mindestens vier Stunden zurück. Sie fällt also ohnehin aus dem Fenster.
- **Kein Fortsetzen ohne Netz.** Der Server muss die Einheit wieder offen führen, bevor neue Sätze kommen.
- **Kein Play-Button auf der Abschluss-Seite direkt nach dem Beenden.** Nur auf der Zusammenfassung über Home, wie notiert.

## 1. Server

### Migration `0053_pausensumme.sql`

```sql
alter table public.workout_sessions
  add column paused_seconds integer not null default 0
  check (paused_seconds >= 0);
```

RLS bleibt, wie sie ist. Die Spalte wird von denselben Policies abgedeckt wie `completed_at`.

### `completeSession` (`packages/domain/src/workout.ts`)

- `completeSessionInputSchema` bekommt `pausedSeconds: z.number().int().min(0).optional()`.
- **Erster Abschluss:** `update` setzt `completed_at`, `completed_reason = 'manual'` und `paused_seconds`, sofern übergeben.
- **Schon beendet (der Frühausstieg):** Es wird unverändert nichts geschrieben, auch nicht `paused_seconds`. Ein Wiederholer ändert nichts.
- **Route `POST /api/v1/workout-sessions/[sessionId]/complete`:**
  - Liest einen optionalen JSON-Rumpf `{ pausedSeconds }`.
  - Ein leerer Rumpf, wie ihn alte Apps schicken, ist gültig.

### Neu: `reopenSession` und `POST /api/v1/workout-sessions/[sessionId]/reopen`

```ts
export const REOPEN_FENSTER_MS = 30 * 60 * 1000;
export async function reopenSession(client, { sessionId }, jetzt = new Date()): Promise<{ id: string; startedAt: string }>
```

- **Nicht gefunden** (auch eine fremde Einheit, RLS): `not_found`.
- **`completed_at` ist null** (schon offen): Erfolg ohne Schreiben. Das macht den Aufruf idempotent, etwa für einen Netzwiederholer.
- **`completed_reason` ist `'auto'`:** `conflict`, „Dieses Training wurde automatisch beendet.“
- **`jetzt - completed_at > REOPEN_FENSTER_MS`:** `conflict`, „Zu spät zum Fortsetzen.“
- **Sonst:** `update completed_at = null, completed_reason = null`. `paused_seconds` bleibt stehen. Das nächste `complete` überschreibt es mit der neuen Gesamtsumme.

`listSessions` hält eine wieder geöffnete Einheit wie jede offene. Sie gilt nach vier Stunden ohne Satz als selbsttätig beendet. Daran ändert sich nichts.

### Vorschläge beim zweiten Abschluss

- `completeSession` rechnet wie beim ersten Mal und fügt neue Zeilen in `progression_suggestions` ein. Die Zeilen des ersten Abschlusses bleiben als Protokoll stehen.
- **Problem:** `gespeicherteVorschlaege` liest im Fenster ±10 min um `completed_at`. Bei einem Fortsetzen nach wenigen Minuten liegen beide Generationen im Fenster.
- **Lösung:** Je Block gilt die jüngste Zeile.
  - Liest es heute schon so? Dann bleibt alles, wie es ist, und ein Test beweist es.
  - Sonst wird die Zuordnung auf „jüngste je Block“ angepasst.

### `listSessions` / DTO

`SessionSummary` liefert `pausedSeconds` (Zahl, 0 bei alten Zeilen).

## 2. App – Daten

### Ablage der beendeten Einheit

- **Neue Datei** neben der laufenden Einheit: `zuletzt-beendet.json` im selben Verzeichnis wie `SessionFileStore`.
- **Inhalt:** `{ session: LokaleSession, beendetAm: Date }`.

**`WorkoutSessionStore`:**

- **`beenden(jetzt:)`:**
  - Legt die Einheit als `zuletztBeendet` ab, sofern sie Sätze hat. Danach wird die laufende Einheit wie bisher geleert.
  - Eine Einheit ohne Satz wird nicht abgelegt. Sie wird verworfen, nach Entschieden 2.
- **`beendenFuerOrtswechsel()`:** Legt nichts ab. Wer den Ort wechselt, will dort ein neues Training.
- **`reset()`** (Abmelden): Löscht auch die Ablage.
- **`kannWiederaufnehmen(sessionId:jetzt:) -> Bool`** ist genau dann wahr, wenn alle drei Bedingungen gelten:
  - Die Ablage hat diese ID.
  - Es gilt `jetzt - beendetAm <= 30 min`.
  - `aktiveSession(jetzt:)` ist nil.
- **`wiederaufnehmen(jetzt:) -> LokaleSession?`:**
  1. Nimmt die Ablage. Stand sie auf Pause (`pausiertSeit` gesetzt), wird die Pause zuerst bis `beendetAm` abgeschlossen.
  2. Rechnet `pausenDauer += jetzt - beendetAm`.
  3. Speichert das Ergebnis als laufende Einheit und leert die Ablage.
  - Der Name ist bewusst nicht `fortsetzen`, denn das heißt hier schon „Pause beenden“.
- **`pausenSekunden(jetzt:)`** an `LokaleSession` gibt `pausenDauer` plus eine laufende Pause zurück, gerundet auf ganze Sekunden.

### Pausensumme an den Server

- `APIClient.completeSession(sessionId:pausedSeconds:)` schickt `{ "pausedSeconds": n }`.
- `Trainingszusammenfassung` trägt `pausedSeconds`, erfasst in `TrainingRootView.beenden()` vor dem Leeren der Einheit.
- `TrainingAbschlussView` reicht die Summe beim Complete-Aufruf weiter.
- `WorkoutSessionStore.melden(_:loader:)` (der Ortswechsel) schickt sie ebenso. Das Ergebnis von `beendenFuerOrtswechsel` trägt sie mit.

### Neu: `APIClient.reopenSession(sessionId:)`

`POST workout-sessions/{id}/reopen`. Fehler kommen als `APIError` wie bei den anderen Aufrufen.

### Home

- `SessionSummary.pausedSeconds: Int?`. Fehlt der Wert, etwa in einem alten Cache, gilt 0.
- `HomeZeilen.dauerMinuten` rechnet (Ende − Start − pausedSeconds) / 60, mindestens 0.

## 3. App – Oberfläche

### `SessionDetailView`

**Play-Button:**
- Ein runder Button oben rechts, gleiche Größe und Fläche wie der Zurück-Button.
- Symbol `play.fill`.
- Accessibility-Label „Training fortsetzen“, Testnotiz-ID `session.fortsetzen`.

**Sichtbar,** wenn `Fortsetzbarkeit.sichtbar(karte:store:jetzt:)` wahr ist. Das ist eine reine Funktion.
- Sie nimmt den jüngsten Teil der Karte, nach `startedAt`.
- Sie fragt für ihn `kannWiederaufnehmen`.
- Ein `TimelineView(.everyMinute)` prüft neu, sodass der Button nach 30 Minuten auch auf einer offenen Seite verschwindet.

**Tipp auf Play:**
1. Der Button zeigt einen `ProgressView` und ist gesperrt.
2. `reopenSession`.
3. **Erfolg:**
   - `sessions.wiederaufnehmen()`.
   - Den Home-Pfad leeren (`dismiss`) und auf den Training-Tab wechseln (`beiTrainingZeigen`, bis zur Detailseite durchgereicht).
4. **Fehler:** Ein `InlineBanner` mit dem Text.
   - Bei jedem `conflict` („zu spät“ wie „automatisch beendet“) wird zusätzlich die Ablage verworfen, und der Button verschwindet. Die App unterscheidet die beiden nicht, sie zeigt nur die Meldung des Servers.
   - Ohne Netz erscheint „Ohne Verbindung geht Fortsetzen nicht.“
   - Sonst erscheint die Meldung des Servers.

### `TrainingRootView`

- Ändert sich die ID der aktiven Einheit (nil → gesetzt), während `pfad` mit `.abschluss` endet, wird `pfad` geleert.
- Sonst stünde nach dem Fortsetzen noch die alte Zusammenfassung im Tab.

## Tests

### Vitest (`packages/domain`)

- **`reopenSession`:**
  - offen bleibt offen,
  - `auto` liefert conflict,
  - 31 min liefert conflict,
  - 29 min öffnet,
  - fremde Einheit liefert not_found.
- Die Regeln liegen in einer reinen Funktion `wiederoeffnenEntscheidung(row, jetzt)` und lassen sich so ohne Datenbank testen.
- **`completeInput`:** `pausedSeconds` optional, nicht negativ.

### Integration (`tests/integration`, lokale DB)

Ablauf: beenden mit Pausensumme, dann wieder öffnen, einen Satz schreiben und erneut beenden. Danach gilt:
- `completed_at` ist neu,
- `paused_seconds` ist neu,
- `listSessions` liefert die Summe,
- die Vorschläge kommen aus dem zweiten Abschluss.

### Swift

- **`WorkoutSessionStore`:**
  - Ablage nach `beenden`,
  - keine Ablage ohne Satz und beim Ortswechsel,
  - das Fenster bei 30 und 31 min,
  - die Lücke als Pause,
  - eine offene Pause beim Beenden,
  - kein Wiederaufnehmen, solange ein Training läuft,
  - `reset` löscht die Ablage.
- **`HomeZeilen`:** Die Dauer ohne Pausen. `pausedSeconds` fehlt bedeutet 0.
- **`Fortsetzbarkeit.sichtbar`:** Der jüngste Teil einer zusammengelegten Karte zählt.
- **DTO:** `pausedSeconds` wird dekodiert.

### Auf dem Gerät

- Beenden, über Home zur Zusammenfassung, Play: Die Uhr läuft weiter, die Blöcke sind da.
- Einen Satz machen, beenden: Home zeigt ein Training mit der Dauer ohne die Lücke.

## Reihenfolge der Auslieferung

1. Migration 0053 auf Prod.
2. Web-Deploy mit `reopen` und `pausedSeconds`.
3. App.

Die alte App läuft gegen den neuen Server unverändert: Ohne Rumpf ist die Pausensumme 0, und `reopen` wird nicht aufgerufen.
