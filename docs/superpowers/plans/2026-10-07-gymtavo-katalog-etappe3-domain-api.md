# Gymtavo-Katalog Etappe 3: Domain und API — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Server liefert, was die App für Etappe 4 braucht:
- Den Gymtavo-Katalog in den Startdaten.
- Gymtavo-Übungen am Studio-Gerät.
- Einen Gerätekontext für Gymtavo-Typen ohne QR-Gerät.
- Sätze ohne Gerät beim Schreiben, im Verlauf, im Fortschritt und im Abschluss.

Die heutige App funktioniert danach **unverändert** weiter. Jede Änderung an einer Antwort ist ergänzend, bis auf zwei Felder, die nur bei Sätzen ohne Gerät `null` werden (siehe Global Constraints).

**Architecture:** Bisher hängt alles an der *Maschine*. Neu ist die **Station**: Gerät (falls vorhanden) plus Gerätetyp (`equipment_model_id`, seit 0047 an jedem Satz).
- Ein kleines Modul `station.ts` bildet den Schlüssel `geraet:<id>` oder `typ:<id>`.
- Blockbildung in Verlauf, Abschluss und Vorschlag läuft über diesen Schlüssel statt über `machine_id`.
- Gymtavo-Übungen kommen über `equipment_models.catalog_model_id` zum Studio-Gerät. Der Server mischt sie ein, die App muss nichts zusammensetzen.
- Keine Migration in dieser Etappe.

**Tech Stack:** TypeScript, Zod und Vitest in `packages/domain`, Next.js-Route-Handler in `apps/web/app/api/v1`, Integrationstests gegen ein lokales Supabase (Docker).

**Quelle:** `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md`, Abschnitte 6 und 8. Etappe 1 ist in `master` und in Produktion (0047). Etappe 2 (Import) ist auf Wunsch verschoben.

## Global Constraints

- **Kompatibilität mit der heutigen iOS-App.** Sie dekodiert mit Standard-`JSONDecoder` (camelCase). Unbekannte Felder ignoriert sie, Pflichtfelder dürfen nie fehlen oder `null` sein, und Aufzählungswerte sind streng. Daraus folgt:
  - `bootstrap.lastSets` bleibt **nur Sätze mit Gerät** (`machineId` Pflicht). Sätze ohne Gerät kommen in ein neues Feld `lastTypeSets`.
  - `bootstrap.calibrations` bleibt unverändert.
  - Neue Felder kommen nur dazu: `catalog`, `equipmentModel.catalogModelId`, `equipmentModelId` an Blöcken, Vorschlägen und gespeicherten Sätzen.
  - **Bewusst nullable**, nur bei Sätzen ohne Gerät:
    - `sessions[].blocks[].machineId`
    - `vorschlaege[].machineId`
    - `RecordedSet.machineId`

    Solche Sätze erzeugt erst die App aus Etappe 4. Sie muss diese Felder optional dekodieren, und das steht in ihrem Plan.
- **Kommentare in TS ohne Umlaute**, Nutzertexte mit Umlauten. Kommentare begründen, sie beschreiben nicht.
- **Testgetrieben:** Für jeden Task zuerst den roten Test (Unit oder Integration), dann die Umsetzung, dann grün, dann der Commit.
- Vor jedem Commit laufen `pnpm typecheck`, `pnpm -F @fitretro/domain test` und die betroffenen Integrationstests.
- **Ein Commit je Task** im Stil der Historie, mit den Trailern der Session. Push auf `claude/gymtavo-katalog-etappe3`.

---

## Task 1: Spec-Nachtrag — API-Form der Etappe 3

**Files:** Modify `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md`, Abschnitt 8.

- [x] Abschnitt 8 um die konkrete Form ergänzen:
  - `catalog`-Block im Bootstrap
  - `lastTypeSets`
  - nullable `machineId` an Blöcken, Vorschlägen und `RecordedSet`
  - neue Route `GET /api/v1/equipment-models/{id}/context?studio=`
  - Satz-PUT mit `equipmentModelId` und optional `studioId`
  - Kompatibilitätsregel für die iOS-App
- [x] Vorschläge an einem Gymtavo-Typ ohne Gerät rechnen auf der Historie desselben Typs und derselben Übung, **ohne Gerät**, über alle Studios.
  - Begründung: Die Belastungsstufen kommen vom Typ. Ein Studio-Gerät hat eigene Stufen und eine eigene Historie.
- [x] Commit `docs(spec): Gymtavo-Katalog -- API-Form der Etappe 3`.

## Task 2: `station.ts` — ein Schlüssel für Gerät oder Typ

**Files:** Create `packages/domain/src/station.ts` und `station.test.ts`.

**Interfaces:**
```ts
export type Station = { machineId: string | null; equipmentModelId: string };
export function stationsSchluessel(s: { machine_id: string | null; equipment_model_id: string }): string; // "geraet:<id>" | "typ:<id>"
```
- [x] **Roter Unit-Test:**
  - Ein Gerät gewinnt über den Typ.
  - Ohne Gerät entscheidet der Typ.
  - Zwei Typen ohne Gerät kollidieren nicht.
- [x] Umsetzen, grün, Commit `feat(domain): Station als Schluessel fuer Geraet oder Geraetetyp`.

## Task 3: Bootstrap — Katalog, Zuordnung, Gymtavo-Übungen am Gerät

**Files:** Modify `packages/domain/src/bootstrap.ts`, `tests/integration/domain-bootstrap.test.ts`.

**Interfaces (ergänzend):**
```ts
catalog: {
  studioId: string;
  equipmentTypes: Array<{
    id; name; manufacturer; photoPath; category; loadUnit; loadStep; loadMin; loadMax;
    secondaryUnit; secondaryStep; secondaryMin; secondaryMax;
    settingDefinitions: [...];               // wie bei machines[].equipmentModel
    exercises: Array<{ id; name; volumeKind; targetMin; targetMax }>;
  }>;
} | null;                                    // null nur, wenn kein Katalog-Studio existiert
machines[].equipmentModel.catalogModelId: string | null;
lastTypeSets: Array<{ equipmentModelId; exerciseId; load; secondaryLoad; volume; rir; performedAt }>;
```
- [x] **Rote Integrationstests:**
  - Ein Nutzer ohne Studio bekommt `catalog.studioId` = Gymtavo und alle Gymtavo-Typen samt Einstellungen und Übungen.
  - Ein Mitglied, dessen Studio-Modell einem Gymtavo-Typ zugeordnet ist, sieht unter dem Gerät:
    - zuerst die eigenen Übungen,
    - dann die Gymtavo-Übungen des Typs,
    - jede Übung nur einmal, auch wenn das Studio sie zusätzlich angehängt hat.
  - Ein Satz ohne Gerät erscheint in `lastTypeSets`, nicht in `lastSets`. `visitCount` zählt ihn nicht.
  - `catalogModelId` steht am Modell.
- [x] **Umsetzen:**
  - Katalog-Studio per `.eq("is_catalog", true)` lesen. Seine Modelle, Verknüpfungen und Einstellungen sind schon in den vorhandenen Abfragen enthalten (RLS liefert sie seit 0047).
  - `catalog_model_id` in die Geräteabfrage aufnehmen.
  - `exercisesByModel` für das Studio-Modell um die Liste des Katalog-Typs ergänzen, mit Deduplizierung nach `id`.
  - Satzabfrage um `equipment_model_id` erweitern. Sätze mit `machine_id` landen in `lastSets` und `visitCount`, die ohne in `lastTypeSets`.
- [x] Grün, dazu `api-me.test.ts`. Commit `feat(domain): Bootstrap liefert den Gymtavo-Katalog und Gymtavo-Uebungen am Geraet`.

## Task 4: Satz-PUT ohne Gerät

**Files:** Modify `packages/domain/src/workout.ts`, `workout.test.ts`, `tests/integration/domain-record-set.test.ts`, `tests/integration/api-workout-sets.test.ts`.

**Interfaces:**
- Eingabe: genau eins von beidem.
  - `machineId`
  - `equipmentModelId`, optional mit `studioId`. Fehlt es, gilt das Gymtavo-Studio.
- Ausgabe `RecordedSet`: `machineId: string | null`, neu `equipmentModelId: string`.

- [x] **Rote Tests:**
  - **Unit (Schema):** Beide gleichzeitig wird abgewiesen, keins von beiden ebenfalls.
  - **Integration:** Ein Nutzer ohne Studio speichert einen Satz am Gymtavo-Typ ohne `studioId`, die Einheit liegt im Gymtavo-Studio.
  - **Integration:** Ein Mitglied speichert in seinem Studio einen Satz am Gymtavo-Typ mit `studioId`.
  - **Integration:** Ein Mitglied speichert an seinem Gerät einen Satz mit einer Gymtavo-Übung. Bisher scheitert das an `.eq("studio_id", studioId)`.
  - **Integration, `not_found`:**
    - fremdes Studio
    - fremder Typ
    - Übung eines dritten Studios
  - **Integration:** Der bisherige Pfad mit `machineId` bleibt unverändert grün.
- [x] **Umsetzen:**
  - Das Studio kommt weiter vom Server: aus dem Gerät, sonst aus `studioId`. Ohne beides gilt das Gymtavo-Studio. Ob der Nutzer dort Mitglied ist, prüft RLS beim Schreiben.
  - Das Modell wird gelesen. Es muss im Studio oder im Katalog liegen.
  - Die Übung muss im Studio oder im Katalog liegen.
  - Nebenbelastung und Umfang werden wie bisher am Modell und an der Übung geprüft.
- [x] Grün. Commit `feat(domain): Satz am Geraetetyp ohne QR-Geraet speichern`.

## Task 5: Kontext für Gymtavo-Typen und Gymtavo-Übungen am Gerät

**Files:**
- Modify `packages/domain/src/machine-context.ts`
- Create Route `apps/web/app/api/v1/equipment-models/[modelId]/context/route.ts`
- Modify `tests/integration/domain-machine-context.test.ts`

**Interfaces:**
```ts
getEquipmentModelContext(client, modelId: string, studioId?: string): Promise<MachineContext & { machine: null }>
```
`MachineContext.machine` wird `{...} | null`. Die bestehende Route liefert weiter immer ein Gerät.

- [x] **Rote Integrationstests:**
  - Im Kontext eines Studio-Geräts mit zugeordnetem Typ stehen die Gymtavo-Übungen samt Katalogvideo (signierte URL).
  - Der Typ-Kontext für einen Nutzer ohne Studio liefert Typ, Einstellungen, Übungen und `calibration: null`.
  - Die Historie besteht nur aus eigenen Sätzen ohne Gerät an diesem Typ.
  - Der Vorschlag rechnet auf dieser Historie und wird in `progression_suggestions` mit `equipment_model_id` und ohne Gerät festgehalten.
  - Ein Typ aus einem fremden Studio liefert `not_found`.
  - `studio` ist ein fremdes Studio: auch `not_found`, weil RLS den Vorschlag dort nicht zulässt. Die Antwort verrät das Studio nicht.
- [x] **Umsetzen:**
  - Übungsliste und Video-Signierung in eine Hilfsfunktion ziehen. Sie liest die Verknüpfungen des Modells plus die des `catalog_model_id` und dedupliziert.
  - Ein Rumpf für beide Kontexte: Gerät oder Typ.
  - Route analog zu `machines/[machineId]/context`, `?studio=` optional.
- [x] Grün. Commit `feat(domain): Kontext fuer Gymtavo-Typen, Gymtavo-Uebungen im Geraetekontext`.

## Task 6: Verlauf, Abschluss und Fortschritt über Stationen

**Files:**
- Modify `packages/domain/src/sessions.ts`, `abschluss.ts`, `progress.ts`
- Tests: `domain-sessions`, `domain-complete-session`, `domain-progress`, `abschluss.test.ts`

- [x] **Rote Tests:**
  - **Sessions:** Eine Einheit im Freien Training zeigt ihre Blöcke mit `machineId: null`, `equipmentModelId`, `machineLabel` = Typname und Einheiten vom Typ. Der Filter aus Etappe 1 („ohne Gerät auslassen“) entfällt.
  - **Abschluss:** Eine Einheit ohne Gerät bekommt je Block einen Vorschlag mit `machineId: null` und `equipmentModelId`. Er wird mit `equipment_model_id` festgehalten. Ein erneuter Abschluss liest ihn zurück, statt neu zu rechnen.
  - **Abschluss:** Gemischte Einheit aus Studio-Gerät und Gymtavo-Typ ohne Gerät. Zwei Blöcke, die Schlüssel kollidieren nicht.
  - **Progress:** Dieselbe Gymtavo-Übung, einmal an einem Studio-Gerät und einmal frei, ergibt **eine** Kurve, die beschriftet ist wie der jüngste Satz.
  - **Unit `blockPaare`:** Blockbildung über die Station.
- [x] **Umsetzen:**
  - `blockPaare`, Historie, Einheiten und gespeicherte Vorschläge über `stationsSchluessel`.
  - Abfragen um `equipment_model_id` und `equipment_models (name, load_unit, secondary_unit)` ergänzen.
  - `mitVerlaufsnamen` bleibt der Rückfall nach einem Austritt.
- [x] Grün, dazu die gesamte Integrationssuite. Commit `feat(domain): Verlauf, Abschluss und Fortschritt kennen Saetze ohne Geraet`.

## Task 7: Gesamtprüfung

- [x] `supabase db reset`, `pnpm test:integration` vollständig, `pnpm typecheck`, Domain- und Web-Unit-Tests.
- [x] Diff adversarial lesen. Prüfen:
  - Ist jedes neue Antwortfeld ergänzend? Ausnahme sind nur die drei nullable `machineId`.
  - Ist kein bestehendes Pflichtfeld weggefallen?
  - Gibt es keinen Pfad, auf dem das Studio vom Client behauptet statt vom Server bzw. von RLS geprüft wird?
- [x] Plan abhaken, Ergebnis notieren, Push. Ein PR nur auf Tims Wunsch.

## Ergebnis (7. Oktober 2026)

- Tests gegen das lokale Supabase (Docker, Stand `master` mit 0047):
  - 63 Integrationsdateien mit 739 Tests grün (vorher 58 mit 711).
  - Domain-Unit-Tests 246, Web-Unit-Tests 251, `pnpm typecheck` grün (Exit-Code 0).
- Neue Tests:
  - `domain-bootstrap-katalog`
  - `domain-record-set-station`
  - `domain-typ-kontext`
  - `api-typ-kontext`
  - `domain-station-verlauf`
  - Unit-Tests `station`, `workout` (Station) und `abschluss` (Stationen)
- Abweichungen vom Plan:
  - `studioId` neben einem `machineId` wird weiter **ignoriert**, nicht abgewiesen. Das war schon bestehender Vertrag samt Test.
  - `getMachineContext` und `getTagContext` geben `GeraeteKontext` zurück, mit `machine` als Pflichtfeld. Nur der Typ-Kontext hat `machine: null`.
  - Ein Commit (`7789ee8`) ging mit roter Typprüfung der Integrationstests raus. `f71b756` behebt das.
- Gefunden und behoben: Der Abschluss einer Einheit mit Sätzen ohne Gerät stürzte mit `invalid input syntax for type uuid: "null"` ab. Erreichbar war das erst ab dieser Etappe.
- **Für Etappe 4 (iOS) festzuhalten:**
  - Eine Einheit gehört genau einem Studio. Ein Satz am Gymtavo-Typ im Studio braucht `studioId` des aktiven Studios. Ohne `studioId` landet er im Freien Training, und in einer Studio-Einheit weist RLS ihn ab (heute als interner Fehler).
  - `machineId` an Blöcken, Vorschlägen und `RecordedSet` optional dekodieren.
  - `lastTypeSets` und `catalog` aus dem Bootstrap lesen.
  - `machineId` beim Schreiben am Typ weglassen, nicht `null` schicken.
- Keine Migration. Ein Merge ist für die heutige App unschädlich, weil alle Antwortfelder nur ergänzt werden.
