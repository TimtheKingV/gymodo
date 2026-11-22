# Übungskatalog glattziehen und erweitern

## Kontext

Der Gymtavo-Katalog (`catalog/gymtavo.json`, 162 Übungen) wirkt uneinheitlich und überladen:

- Namen folgen keinem Schema (drei Trennzeichen-Varianten, Gerät mal vorn, mal hinten, mal gar nicht).
- Jede Beschreibung hat sechs Abschnitte (403–1222 Zeichen) und enthält interne Notizen („Gewicht pro Kurzhantel erfassen.“, „keine Messwerterfassung in dieser Vorschau“).
- Es gibt keinen Stilleitfaden und keine Prüfung für Wording.

Tims Entscheidungen aus dem Gespräch:

- **Name ohne Gerät.** Die Übung heißt „Curls“, das Gerät steht als eigenes Etikett daneben: `Curls [Kurzhantel]`.
- **Etikett = Gerätetyp aus dem Katalog, immer sichtbar**, auch wenn es sich mit dem Namen doppelt (`Beinpresse [Beinpresse]`).
- **Varianten bleiben im Namen** (`Latzug – Obergriff`).
- Stören: Länge, interne Notizen, uneinheitliche Namen. Der Ton der Formulierungen an sich ist in Ordnung.

Meine Annahmen (von Tim noch nicht bestätigt, bei der Freigabe änderbar):

- Beschreibung auf drei Abschnitte kürzen: `Einstellen:`, `Bewegung:`, `Achte auf:`.
- Neue Übungen: Tims Wunschliste plus Lückenvorschläge von mir, Auswahl durch Tim.

Wichtige Befunde:

- Gleiche Namen sind technisch unkritisch: alles verknüpft über `exerciseId` / `catalog_key`, kein Unique auf `name`. **Der `key` einer Übung wird nie geändert.**
- Ein Gerätetyp-Name steht heute in keinem Übungsobjekt, und etwa 15 Typnamen sind als Etikett zu lang („Horizontale Beinpresse, feste Sitzposition“).
- Es ist kein TestFlight-/App-Store-Build erkennbar und es gibt keinen Force-Update. Reihenfolge deshalb: erst Etikett in App/API, dann Namen einspielen.
- Der Haupt-Checkout (`codex/sensor-luecken-2026-10-26`) hängt hinter master. Gearbeitet wird in einem neuen Worktree von `origin/master`.
- Ob Prod der Datei entspricht, ist ungeprüft (Daten vom 16.11. kamen per SQL statt Import).

## Etappe 0 – Vorarbeit

1. Neuer Worktree/Branch von `origin/master`.
2. Diesen Plan nach `docs/superpowers/plans/2026-11-22-katalog-glattziehen.md` übernehmen, Kurzdesign nach `docs/superpowers/specs/2026-11-22-katalog-glattziehen-design.md`.
3. Abgleich Datei ↔ Prod, nur lesend (SQL-Abfrage auf `exercises` des Gymtavo-Studios: `catalog_key`, `name`, `md5(description)`, Plan-Felder). Abweichungen zuerst in die Datei holen.
4. Stilleitfaden `docs/katalog-stilleitfaden.md` schreiben (Regeln aus Etappe 2 und 3). Er ist ab dann die Vorgabe für jede neue Übung.

## Etappe 1 – Geräte-Etikett (Technik, vor jeder Umbenennung)

**Datenweg (mein Vorschlag):** Das Etikett wird an der Übung gespeichert, damit jede Stelle, die eine Übung hat, es ohne Nachschlagen bekommt.

- `catalog/gymtavo.json`: neues Feld `label` je Gerätetyp (kurz, ≤ 20 Zeichen, z. B. „Kurzhantel“, „Kabelzug“, „Beinpresse“, „Latzug“). Schema in `packages/domain/src/katalog-datei.ts` erweitern; Querprüfung: jeder nicht abgelöste Typ hat ein `label`.
- Migration `0076_uebung_geraet_label.sql`: `exercises.geraet_label text null` (eigene Studio-Übungen bleiben `null`, dann kein Etikett).
- Import (`packages/domain/src/katalog-plan.ts`, `katalog-import.ts`): `geraet_label` aus dem einen nicht abgelösten Typ der Übung ableiten und mit vergleichen.
- Durchreichen: `bootstrap.ts`, `machine-context.ts`, `catalog.ts`, `progress.ts` (plus `my_history_labels()` bzw. Join in der Migration), `sessions.ts`. iOS-DTOs `BootstrapResponse.Exercise`, `ExerciseProgress` (Feld optional, damit alte Antworten weiter dekodieren).

**Anzeige iOS** (nur Stellen ohne Gerätekontext):

- Zentrale Funktion `PlanZeilenModell.uebungsname(...)` in `Screens/Training/PlanZeile.swift` um das Etikett erweitern; darüber laufen Planzeile, Plankarte, Onboarding-Vorschau, Ablaufliste, Pause, Tausch.
- `DesignSystem/Components/Uebungskarte.swift` (`UebungskarteModell` bekommt `geraetLabel`), eine kleine Etikett-Komponente im DesignSystem.
- `Screens/Home/HomeRootView.swift` (Fortschrittsliste), Zirkel-Sheets, „statt X“ in `Workout/PlanEinheitEntwurf.swift` (wird „statt Bankdrücken (Langhantel)“).
- Suche in `Workout/GeraeteAuswahl.swift`: Treffer auch auf das Etikett.
- Überschrift in `Screens/Geraet/EinweisungSchritt.swift` von „Worauf du achten musst“ auf „So geht’s“ ändern, sonst doppelt sie sich mit „Achte auf:“.

**Portal:**

- `geraete/[modelId]/uebungen/gymtavo.ts`: `anhaengbareUebungen` nutzt das Etikett und überspringt abgelöste Typen (heute zeigt es bei Kabelzug-Übungen vermutlich „Doppel-Kabelzug …“). `GymtavoAnhaengen.tsx` behält das Muster „Name · Etikett“.

**Tests zuerst (rot → grün):** `katalog-datei.test.ts`, `katalog-plan.test.ts`, `tests/integration/katalog-import.test.ts`, `domain-bootstrap-katalog.test.ts`, iOS-Unit-Test für Namensfunktion und Suche.

## Etappe 2 – Namen

**Regeln (Stilleitfaden):**

- Aufbau `Übung` oder `Übung – Variante`. Einziges Trennzeichen ist „ – “.
- Kein Gerät im Namen (Kurzhantel, Langhantel, SZ, Kabel, „am Gerät“, Maschine).
- Variante = Griff, Körperlage, Winkel, einarmig/einbeinig. Höchstens eine Variante; zwei nur mit Komma (`Curls – Schrägbank, einarmig`).
- Etablierte englische Begriffe bleiben (Hip Thrust, Face Pull, Goblet Squat, Pallof Press). Sonst deutsch.
- Gleiche Übung, gleiches Wort (ein Begriff für Latzug/Latziehen, Scottcurl, Schulterheben).
- Paar aus Name und Etikett ist eindeutig.

**Vorgehen:**

1. Ich erstelle eine Tabelle alt → neu + Etikett für alle 162 Übungen (`docs/katalog-namen-2026-11.md`), gruppiert nach Baustein.
2. **Tim sieht die Tabelle durch und gibt sie frei**, bevor die JSON geändert wird.
3. Namen in `catalog/gymtavo.json` umsetzen.
4. Neue Prüfungen in `packages/domain/src/gymtavo-katalog.test.ts`: Trennzeichen, verbotene Gerätewörter, Eindeutigkeit von Name + Etikett.
5. `tools/sensorik-sim/lib.py` (`FAM`-Zuordnung per Namensteil) gegen die neuen Namen prüfen und bei Bedarf Kernwörter ergänzen. Alte Aufnahmen behalten ihre alten Namen.

## Etappe 3 – Beschreibungen

**Regeln (Stilleitfaden):**

- Genau drei Abschnitte: `Einstellen:`, `Bewegung:`, `Achte auf:`.
- Je Abschnitt 1–3 Punkte, ein kurzer Satz pro Punkt, Infinitiv-Stil wie bisher. Richtwert 250–450 Zeichen gesamt.
- „Häufige Fehler“ gehen als positive Anweisung in „Achte auf“ auf.
- Es entfallen: „Positionen“, „Benötigte Ausstattung“, alle Erfassungssätze, alle „Vorschau“-Reste, der lange Cardio-Absatz.
- „Bewegung“ in natürlicher Reihenfolge (erst absenken, dann aufrichten), nicht nach dem Videostart.
- Nur was der Trainierende am Gerät braucht; nichts, was Name, Etikett oder Muskelkarte schon sagen.

**Vorgehen:**

1. Zuerst 10 Musterübungen quer durch alle Bausteine umschreiben, Tim prüft sie in der Einweisung im Simulator.
2. Danach in neun Paketen je Baustein (arme, druecken, ziehen, schulter, beine_knie, beine_huefte, beine_ergaenzung, cardio, rumpf); je Paket ein Commit und eine kurze Durchsicht durch Tim.
3. Prüfungen in `gymtavo-katalog.test.ts`: genau diese drei Überschriften, Punktzahl, Längengrenze, verbotene Wörter („erfassen“, „Vorschau“).
4. Den bisherigen Test an „Benötigte Ausstattung:“ (Zeilen 47–55) ersetzen: die Aussage „keine abgelösten Typen“ direkt über die Geräteverknüpfung prüfen, sonst bleibt er still grün.
5. `review` bleibt `draft`, bis Tim ein Paket durchgesehen hat; dann `reviewed`.

Nicht Teil dieses Plans: Der Hinweis „Gewicht pro Kurzhantel“ ist eigentlich eine Eingabehilfe. Falls er fehlt, gehört er später an das Gewichtsfeld, nicht in den Text.

## Etappe 4 – Neue Übungen

1. Tim nennt seine Wunschübungen.
2. Ich lege eine Lückenliste dazu (`docs/katalog-neue-uebungen-2026-11.md`): Abgleich gegen Bausteine und Muskelabdeckung. Erkennbare Lücken heute: Rumpf (9 Übungen), Beine-Ergänzung (11), und es gibt keinen Gerätetyp für Körpergewicht/Matte (Liegestütz, Plank, Klimmzug frei, Dips).
3. Tim wählt aus der Liste.
4. Je Übung nach Stilleitfaden anlegen: `key`, `name`, `description`, `volume_kind`, Zielwerte, `grip`, `muscles` (mindestens ein primärer), `plan`-Block, `sources`, `review: "draft"`, `video: null`, Eintrag in `equipment[].exercises`. Neue Gerätetypen nur mit `label`.
5. Videos sind ein eigenes Thema und hier nicht enthalten.

## Etappe 5 – Einspielen

- Nach jeder Etappe: `pnpm catalog:import --dry-run` lokal, dann echter Lauf lokal.
- Prod: Migration 0076 und `catalog:import --ja` **nur nach Tims ausdrücklicher Freigabe je Schritt**. Reihenfolge: Etappe 1 (API/App mit Etikett) zuerst, erst danach die neuen Namen.
- PR je Etappe, Merge nach grüner CI.

## Prüfung

- `pnpm test` in `packages/domain` (Katalog- und Import-Tests), Integrationstests `tests/integration/katalog-*.test.ts`, `domain-bootstrap-katalog.test.ts`, RLS-Tests.
- iOS-Unit-Tests, danach im Simulator: Plankarte, Einheit bearbeiten, Tausch, Fortschrittsliste, Zirkel und Suche zeigen `Name [Etikett]`; die Einweisung zeigt die drei Abschnitte unter „So geht’s“.
- Portal: „Gymtavo-Übung anhängen“ zeigt „Name · Etikett“ ohne abgelöste Typen.
- Dry-Run-Bericht des Imports: nur „geändert“ und „neu“, kein „nur in DB“ (das hieße, ein `key` wurde versehentlich geändert).
