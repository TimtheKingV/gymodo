# Gymtavo-Katalog und offener Zugang — die App ohne Studio-Code

**Stand:** 6. Oktober 2026
**Status:** Entschieden, bereit für Umsetzungsplan.
**Vorbedingung:** Cardio-Datenmodell (Migration 0046) und Sensor-Aufzeichnung sind in `master`.
**Verhältnis zu anderen Dokumenten:** Ändert `2026-09-07-ios-fundament-zugang-design.md` (Studio-Pflicht nach dem Login) und `2026-09-01-scan-beitritt-design.md` (Scan eines fremden Geräts). Die Datenschutzgrenze aus Migration 0033 (Studios sehen keine Einzeldaten) bleibt; gelockert wird nur, was der Nutzer selbst sieht.

---

## 1. Ausgangslage

Heute ist jeder Inhalt studiogebunden: `equipment_models`, `exercises`, `machines`, Einstellungen und Videos tragen ein `studio_id not null`, gelesen wird nur mit `is_studio_member`. Ein Satz braucht Studio, Gerät und Übung (`workout_sets.machine_id not null`). Wer kein Studio hat, landet nach dem Onboarding auf „Noch kein Studio“ und kommt nicht weiter.

Der Code eines fremden Geräts macht serverseitig bereits zum Mitglied (`join_studio_by_tag` nimmt jede aktive Marke), die App ruft das im Training aber nicht auf, sondern meldet „Dieser Code ist nicht aktiv“ (`TrainingRootView.swift`, Scan-Pfad).

## 2. Ziel

Jeder kann die App nutzen, in jedem Studio und ohne Studio. Gymtavo pflegt eine eigene Geräte- und Übungsdatenbank, die jeder sieht. Studios bleiben die Ebene für eigene Geräte, QR-Codes, Kurse und eigene Übungen; beitreten geht im Profil oder per Scan.

## 3. Entscheidungen

| # | Frage | Entscheidung |
|---|---|---|
| E1 | Woher weiß das System, welche Gymtavo-Geräte ein Studio hat? | Jedes Studio-Gerätemodell wird einem Gymtavo-Gerätetyp zugeordnet. |
| E2 | Was heißt „Gymtavo-Übung übernehmen“? | Verweis, keine Kopie. Bankdrücken ist überall dieselbe Übung; das Studio darf eigene Videos ergänzen. |
| E3 | Wie kommt die Datenbank ins System? | Erst ein Import aus Datei, später ein Pflegebereich im Portal. |
| E4 | Mitglied von Studio A trainiert woanders | „Freies Training“ ist ein fester Eintrag im Studio-Umschalter; wer kein Studio hat, ist automatisch dort. |
| E5 | Wem gehört der Verlauf? | Dem Nutzer. Eigene Einheiten bleiben sichtbar, auch nach Austritt. |
| E6 | Wie wird der Katalog gebaut? | Gymtavo ist selbst ein Studio mit Kennzeichen `is_catalog` (Ansatz C). Portal-Masken, Import und Videoablage funktionieren damit ohne zweite Tabellenwelt. |

## 4. Begriffe

- **Gymtavo-Studio:** genau ein Datensatz in `studios` mit `is_catalog = true`. Seine Gerätemodelle heißen **Gymtavo-Gerätetypen** (Langhantel, Kurzhantel, Kabelzug, Beinpresse …), seine Übungen **Gymtavo-Übungen**.
- **Zuordnung:** `equipment_models.catalog_model_id` eines Studio-Modells zeigt auf einen Gymtavo-Gerätetyp.
- **Freies Training:** Einheiten, deren `studio_id` das Gymtavo-Studio ist.

## 5. Datenmodell (eine Migration, `0047_gymtavo_katalog.sql`)

### 5.1 Gymtavo-Studio

- `studios.is_catalog boolean not null default false`, eindeutiger Teilindex `where is_catalog` (höchstens eins).
- Funktion `is_catalog_studio(p_studio_id)` (security definer, stable, `search_path` fest wie in 0040).
- Die Migration legt das Gymtavo-Studio an (fester, dokumentierter UUID), `join_code_active = false`.
- Ein Wächter-Trigger auf `studio_memberships` verbietet die Rolle `member` im Gymtavo-Studio. Er deckt jeden heutigen und künftigen Beitrittsweg ab (Marke, Code), ohne drei Funktionsrümpfe neu zu schreiben. Trainer-Einladungen bleiben möglich – das Gymtavo-Team braucht sie für die Pflege (Etappe 6). Der erste Owner wird per Service-Rolle eingetragen.
- Ein zweiter Wächter-Trigger verhindert `machines` und `machine_tags` im Gymtavo-Studio.

### 5.2 Lesen für alle Angemeldeten

Die SELECT-Policies von `studios`, `equipment_models`, `equipment_setting_definitions`, `exercises`, `equipment_model_exercises`, `instruction_assets` und der Storage-Policy für Medien bekommen `or is_catalog_studio(…)`. Schreiben bleibt `is_studio_staff`, für das Gymtavo-Studio also nur dessen Owner. `machines` und `machine_tags` des Gymtavo-Studios gibt es nicht.

### 5.3 Zuordnung und Verweis

- `equipment_models.catalog_model_id uuid null references equipment_models on delete restrict`, Check per Trigger: Ziel liegt im Gymtavo-Studio, Quelle nicht.
- `equipment_model_exercises`: Die Regel „Übung und Modell im selben Studio“ wird zu „Übung im selben Studio **oder** im Gymtavo-Studio“ (Policies aus 0005, `attachExerciseToModel` in `catalog.ts`). Damit kann ein Studio eine Gymtavo-Übung an sein Gerät hängen und darunter eigene Videos ablegen; die Videos gehören dem Studio, weil sie am Studio-Verknüpfungsdatensatz hängen.

### 5.4 Sätze ohne Gerät mit QR-Code

- `workout_sets.equipment_model_id uuid not null references equipment_models` (Rückfüllung aus `machines.equipment_model_id`), `machine_id` wird nullable.
- Eindeutigkeit neu: `unique nulls not distinct (session_id, machine_id, equipment_model_id, exercise_id, set_index)`.
- Insert-/Update-Policy: `user_id = auth.uid()`; Einheit gehört dem Nutzer und hat dasselbe `studio_id`; Studio ist eines, in dem er Mitglied ist, **oder** das Gymtavo-Studio; Modell und Übung liegen im Studio der Einheit oder im Gymtavo-Studio; ein gesetztes `machine_id` gehört zum Studio der Einheit und zum Modell.
- `workout_sessions` Insert-Policy entsprechend: Mitglied **oder** Gymtavo-Studio.
- `progression_suggestions`: wie `workout_sets` (`equipment_model_id` dazu, `machine_id` nullable).
- `member_machine_calibrations` bleibt unverändert: Kalibrierung gibt es nur an echten Geräten.
- Ein Füll-Trigger setzt `equipment_model_id` aus `machine_id`, wenn es fehlt. So schreibt der heutige Satzpfad (`workout.ts`) bis Etappe 3 unverändert weiter.

### 5.5 Verlauf gehört dem Nutzer

- SELECT auf `workout_sessions`, `workout_sets`, `progression_suggestions`: nur noch `user_id = auth.uid()` (der `is_studio_member`-Teil aus 0033 fällt weg). Kein Staff-Zugriff, die Datenschutzgrenze bleibt.
- Nach einem Austritt sind Gerät und Studio-Übung nicht mehr lesbar. Damit der Verlauf trotzdem Namen zeigt, liefert eine security-definer-Funktion `my_history_labels()` Name von Übung, Gerät und Studio nur für IDs, die in eigenen Sätzen vorkommen.

## 6. Was die App anzeigt

| Aktiver Eintrag | Geräteliste |
|---|---|
| Studio mit Geräten | Die Geräte des Studios. Unter jedem Gerät: die eigenen Übungen des Modells **plus** alle Gymtavo-Übungen des zugeordneten Gymtavo-Gerätetyps (doppelt angehängte nur einmal). Belastungsstufen und Einstellungen kommen vom Studio-Modell. |
| Studio ohne Geräte | Alle Gymtavo-Gerätetypen mit ihren Übungen. Die Einheit läuft im Studio, die Sätze tragen das Gymtavo-Modell und kein Gerät. |
| Freies Training | Alle Gymtavo-Gerätetypen mit ihren Übungen. Die Einheit läuft im Gymtavo-Studio. |

Fortschritt und Verlauf laufen je Übung über alle Studios zusammen. Eine Studio-eigene Übung bleibt eine eigene Übung.

Die Sensor-Befestigung wird je `machineId` gemerkt, ohne Gerät je `equipmentModelId`.

## 7. Zugang und Beitritt (iOS)

- `RootDestination`: `.noStudio` entfällt. Nach dem Onboarding geht es immer nach `.main`. `MemberKeinStudioView` wird gelöscht.
- `CatalogStore`: Ein aktiver Eintrag ist ein Studio oder „Freies Training“. Ohne Mitgliedschaft und bei ungültigem gespeichertem Wert gilt Freies Training. Das Gymtavo-Studio erscheint nie als Studio in der Liste.
- In Freies Training blendet Home die Studio-Teile aus (Kurse, Studio-Name); der Kurse-Tab zeigt einen Hinweis „Tritt einem Studio bei, um Kurse zu sehen“ mit Knopf zum Beitreten.
- **Profil → Studios:** Die Liste zeigt „Freies Training“ und die eigenen Studios zum Umschalten und Austreten. Neu ist „Studio beitreten“: Scanner (Aushang oder Gerät) und darunter das Eingabefeld für den Studio-Code. Nach dem Beitritt wird das Studio aktiv.
- **Scan im Training:** Ist der Code nicht im Bootstrap, ruft die App `studios/join-by-tag` auf.
  - Gerätecode: beitreten, Bootstrap neu laden, Studio aktiv setzen, Gerät öffnen; Hinweis „Du bist jetzt Mitglied im {Studio}“.
  - Aushang: beitreten und Studio aktiv setzen.
  - Gerätecode eines Studios, in dem man schon ist, das aber nicht aktiv ist: Studio wechseln und Gerät öffnen.
  - Unbekannt oder gesperrt: die bisherige Meldung.
- Ein offener Tag-Link nach dem Login (`PendingTagStore`) läuft über denselben Pfad.
- Registrierung: Der Satz „Für dein Studio brauchst du ein Konto.“ wird neutral.

## 8. Domain und API

- `bootstrap.ts`: liefert zusätzlich `catalog` (Gymtavo-Studio-ID, Gerätetypen, Einstellungen, Übungen, Verknüpfungen) und an jedem Studio-Modell `catalogModelId`. `studios` enthält das Gymtavo-Studio nicht.
- `workout.ts`: Der Satz-PUT nimmt entweder `machineId` oder `equipmentModelId` + `studioId` (Studio oder Gymtavo). Das Studio der Einheit wird wie heute serverseitig bestimmt und geprüft; die Übung darf aus dem Studio oder dem Gymtavo-Studio stammen.
- `progression.ts`, `abschluss.ts`, `progress.ts`, `sessions.ts`: Schlüssel `machineId` wird zu (`machineId` oder `equipmentModelId`); der Fortschritt gruppiert nach Übung.
- `tag-context.ts`/`machine-context.ts`: ohne Änderung am Verhalten; der Scan-Beitritt passiert vorher.

### 8.1 Konkrete Form (Nachtrag zur Etappe 3, 7. Oktober 2026)

**Station:** Ein Block, eine Historie oder ein Vorschlag hängt künftig an einer *Station*. Das ist ein Gerät mit QR-Code, wenn es eines gibt, sonst ein Gerätetyp. Der Schlüssel lautet `geraet:<id>` bzw. `typ:<id>`.

**Bootstrap (nur ergänzend):**
- `catalog: { studioId, equipmentTypes: [{ …Modellfelder wie bei machines[].equipmentModel…, settingDefinitions, exercises }] } | null`
- `machines[].equipmentModel.catalogModelId: string | null`
- `machines[].exercises` enthält zusätzlich die Gymtavo-Übungen des zugeordneten Typs. Eigene Übungen kommen zuerst, jede Übung erscheint nur einmal.
- `lastSets` bleibt auf Sätze mit Gerät beschränkt, weil die heutige App `machineId` als Pflichtfeld dekodiert.
- Sätze ohne Gerät stehen in `lastTypeSets: [{ equipmentModelId, exerciseId, load, secondaryLoad, volume, rir, performedAt }]`.

**Satz-PUT:**
- Entweder `machineId` oder `equipmentModelId`, dazu optional `studioId`. Fehlt es, gilt das Gymtavo-Studio, also Freies Training.
- Das Studio leitet der Server ab: aus dem Gerät oder aus `studioId`. Ob der Nutzer dort schreiben darf, entscheidet RLS.
- `RecordedSet` bekommt `equipmentModelId`. `machineId` darf `null` sein.

**Typ-Kontext:** `GET /api/v1/equipment-models/{id}/context?studio=<id>` hat dieselbe Form wie der Gerätekontext.
- `machine` ist `null`, `calibration` ebenfalls `null`.
- Die Historie und der Vorschlag beruhen auf eigenen Sätzen **ohne Gerät** an diesem Typ und dieser Übung, über alle Studios hinweg. Die Belastungsstufen kommen vom Typ. Ein Studio-Gerät hat eigene Stufen und damit eine eigene Historie.

**Gerätekontext:** Er enthält zusätzlich die Gymtavo-Übungen des zugeordneten Typs, samt Katalogvideo, falls das Studio keines ergänzt hat.

**Verlauf, Abschluss:** Blöcke und Vorschläge tragen `equipmentModelId`. `machineId` ist `null` bei Sätzen ohne Gerät, `machineLabel` ist dann der Name des Typs.

**Fortschritt:** Er wird wie bisher je Übung gruppiert. Dieselbe Gymtavo-Übung an verschiedenen Stationen ergibt eine Kurve.

**Kompatibilität:**
- Die heutige iOS-App ignoriert unbekannte Felder. Sie scheitert aber an `null` in Pflichtfeldern.
- `machineId: null` entsteht nur durch Sätze ohne Gerät, und die schreibt erst die App aus Etappe 4. Sie dekodiert diese drei Felder deshalb optional.

## 9. Import (Etappe 2)

- Datei `catalog/gymtavo.json` im Repo, Skript `pnpm catalog:import [datei]` mit Service-Rolle.
- Jeder Gerätetyp und jede Übung hat einen festen `key` (z. B. `langhantel`, `bankdruecken-langhantel`); dafür bekommen `equipment_models` und `exercises` eine Spalte `catalog_key`, eindeutig im Gymtavo-Studio.
- Import ist ein Upsert über `key`: Neues wird angelegt, Vorhandenes aktualisiert. Fehlende Einträge werden nur gemeldet, nie gelöscht, weil Sätze darauf verweisen.
- Videos: Pfad in der Datei, Upload in den Medien-Bucket unter dem Gymtavo-Studio.
- Inhalt der Datei je Gerätetyp: Name, Kategorie, Belastungseinheit und -stufen, Nebenbelastung, Einstellungen; je Übung: Name, Umfangsart, Zielkorridor, Gerätetypen, Video.

## 10. Portal (Etappe 5)

- Gerätemodell anlegen und bearbeiten: Pflichtfeld „Gymtavo-Gerätetyp“ mit Suche; bestehende Modelle zeigen einen Hinweis, bis sie zugeordnet sind.
- Reiter Übungen: Die Gymtavo-Übungen des Typs stehen schreibgeschützt dabei, mit „Eigenes Video ergänzen“. Dazu kommt „Gymtavo-Übung anhängen“ für Übungen anderer Typen.
- Die spätere Gymtavo-Pflege (Etappe 6) ist das normale Portal im Gymtavo-Studio. Der Owner sieht es in seiner Studio-Liste.

## 11. Etappen

1. **Datenbank:** Migration 0047 (5.1–5.5) mit Integrationstests für jede Policy. Dazu Leser absichern, damit sich die App noch nicht ändert: Bootstrap und Startseite blenden das Gymtavo-Studio aus; Verlauf und Fortschritt fallen bei fehlenden Namen auf `my_history_labels()` zurück.
2. **Import:** `catalog_key`, Skript, Beispieldatei mit einer Handvoll Typen und Übungen.
3. **Domain/API:** Bootstrap, Satz ohne Gerät, Fortschritt je Übung, Verlaufsnamen.
4. **iOS:** Studio-Zwang weg, Freies Training, Beitreten im Profil, Scan fremder Studios.
5. **Portal:** Zuordnung zum Gymtavo-Typ, Gymtavo-Übungen anhängen und mit eigenem Video versehen.
6. **Später:** Gymtavo-Pflege im Portal.

Jede Etappe ist für sich lauffähig. Etappe 4 setzt 1–3 voraus, Etappe 5 nur 1.

## 12. Tests, die zeigen, dass es stimmt

- Ein Nutzer ohne Mitgliedschaft liest Gymtavo-Typen und -Übungen, aber keine Studio-Inhalte.
- Ein Nutzer ohne Mitgliedschaft legt eine Einheit im Gymtavo-Studio mit Sätzen ohne Gerät an; in einem fremden Studio scheitert das.
- Ein Mitglied legt im Studio einen Satz mit Gymtavo-Übung am Studio-Gerät an; mit der Übung eines dritten Studios scheitert das.
- Nach dem Austritt liest der Nutzer seine Einheiten und Sätze und bekommt über `my_history_labels()` die Namen; der Trainer des Studios sieht sie nicht.
- Niemand kann dem Gymtavo-Studio per Code, Marke oder Einladung beitreten.
- Der Import zweimal hintereinander ändert nichts (idempotent).
- iOS: Ohne Studio landet man nach dem Onboarding im Training mit Gymtavo-Geräten; der Scan eines fremden Gerätecodes führt zu Beitritt, Studiowechsel und geöffnetem Gerät.

## 13. Offen, bewusst später

- Darf ein Studio einzelne Gymtavo-Übungen an seinem Gerät ausblenden? Erst entscheiden, wenn es ein Studio verlangt.
- Kalibrierung und gemerkte Einstellungen für Geräte ohne QR-Code.
- `studio_overview` (0034) gibt dem Gymtavo-Owner Summen über Freies Training aus -- nur Summen, die Datenschutzgrenze bleibt. Falls unerwünscht, schließt Etappe 3 das Gymtavo-Studio dort aus.
- Ob „Freies Training“ in der App so heißt oder z. B. „Ohne Studio“: Wortlaut bei der iOS-Etappe.
