# Befund: `completed_at` kommt vom App-Server, `started_at` von der Datenbank

Stand 11.09.2026. **Nicht behoben** — bewusst offen gelassen, hier festgehalten,
damit der nächste, der über rote `domain-complete-session`-Tests stolpert, nicht
wieder bei null anfängt.

## Was falsch ist

`packages/domain/src/workout.ts`, in `completeSession`:

```ts
.update({
  completed_at: new Date().toISOString(),   // Uhr des App-Servers (Node)
  completed_reason: "manual",
})
```

`workout_sessions.started_at` dagegen entsteht aus dem Spaltendefault `now()` —
also aus der **Uhr der Datenbank**. Zwei Uhren auf zwei Maschinen schreiben in
zwei Spalten, über die ein CHECK-Constraint wacht:

```
workout_sessions_completed_after_start: completed_at >= started_at
```

Läuft die Datenbankuhr der App-Server-Uhr voraus, und liegt zwischen dem Anlegen
der Session und ihrem Abschluss weniger Zeit als dieser Vorlauf, dann ist
`completed_at < started_at` und der Abschluss scheitert. Der Aufrufer sieht
`internal` / HTTP 500 — eine Fehlermeldung, die nichts über die Ursache sagt.

## Wie es aufgefallen ist

Beim Deploy am 11.09. liefen drei Integrationstests rot, die auf demselben
Codestand Stunden zuvor zweimal grün waren:

- `domain-complete-session > beendet die eigene Session und haelt den Grund fest`
- `domain-complete-session > Idempotenz: ein zweiter Abschluss verschiebt den Zeitpunkt nicht`
- `api-workout-sets > POST .../complete > beendet die eigene Session` (500 statt 200)

Gemessen wurde danach ein Vorlauf der Container-Uhr von **85–145 ms** gegenüber
dem Host (drei Messungen mit `clock_timestamp()` gegen die Node-Uhr). Die Tests
legen eine Session an und schließen sie Millisekunden später ab — sie liegen
also genau im Fenster. Eine Uhr, kein Code: nichts am Repository hatte sich
zwischen grün und rot geändert.

Hinweis: `f4a8830 test(rls): Abschlusszeitpunkt aus der Datenbank statt aus dem
Testlauf` hat dieselbe Klasse schon einmal umschifft — dort in **einem Test**.
Die Ursache im Produktionscode steht seitdem unverändert.

## Wie groß das Risiko in Produktion ist

Klein, aber nicht null. App-Server (Vercel) und Datenbank (Supabase) sind
verschiedene Maschinen; ihre Uhren laufen über NTP, aber nie identisch. Damit
es knallt, müsste eine Einheit innerhalb des Uhrenversatzes nach ihrem ersten
Satz beendet werden — `started_at` entsteht erst mit dem ersten Satz. Für einen
Menschen am Gerät ist das praktisch ausgeschlossen. Ein automatisierter
Aufrufer oder ein Test trifft das Fenster dagegen zuverlässig.

Es gibt eine zweite, unauffälligere Wirkung: schon ohne Constraint-Verletzung
ist die Trainingsdauer (`completed_at - started_at`) um den Uhrenversatz falsch,
weil ihre beiden Enden aus verschiedenen Uhren stammen.

## Was die Reparatur wäre

`completed_at` gehört auf dieselbe Uhr wie `started_at` — die der Datenbank.
Kein Einzeiler: PostgREST kann in einem `update` kein `now()` schreiben, der
Wert muss also aus einem Spaltendefault, einem Trigger oder einer RPC kommen.

Wer das angeht, sollte die Idempotenz mitdenken: der Frühausstieg oben in
`completeSession` liest den vorhandenen `completed_at` und darf ihn nicht
verschieben — ein Trigger, der bei jedem `update` neu stempelt, bräche genau
den Test, der das absichert.

## Zwischenzeitlicher Umgang

Sind die drei Tests rot, **erst die Uhren vergleichen**, bevor im Code gesucht
wird:

```bash
docker exec supabase_db_<projekt> psql -U postgres -tAc "select clock_timestamp();"
date
```

Läuft der Container vor, ist es dieser Befund und kein neuer. Ein Neustart von
Docker Desktop synchronisiert die VM-Uhr; danach sind die Tests wieder grün.
