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

### 9.1 Importformat (Nachtrag zur Etappe 2, 10. Oktober 2026)

**Herkunft:** Der erste Bestand stammt aus dem GYMTAVO-Paket (Originalkatalog Schema 0.11.0: 55 trainierbare Gerätetypen, 162 Übungen, 162 Videos). Ein einmaliger Konverter, der nicht ins Repo kommt, erzeugt daraus `catalog/gymtavo.json` und `catalog/media/`. Ab dann ist diese Datei die gepflegte Quelle. Die Python- und SQL-Importskripte des Pakets werden nicht verwendet, weil sie nur einfügen und nie aktualisieren.

**Schlüssel:** Die festen String-IDs des Pakets (`chest_press`, `chest_press_neutral`), Muster `^[a-z0-9_]+$`. Das Beispiel oben (`bankdruecken-langhantel`) ist damit überholt. Die Medien des Pakets heißen schon so, und der Abgleich mit Originalkatalog und Herstellerkandidaten bleibt eins zu eins.

**Werte stehen ausdrücklich in der Datei.** Das Skript kennt keine Defaults. Der Konverter übernimmt die technischen Platzhalter des Pakets (Kraft 8–12 Wiederholungen und 1 kg Stufe, Laufband 0,1 km/h, andere Cardiotypen Stufe 1 und 60 s, keine Grenzen, keine Nebenbelastung). Korrekturen geschehen in der Datei und kommen per Upsert an.

**Aufbau** (Feldnamen wie die Spalten, Medienpfade relativ zur Datei):

```json
{
  "format": 1,
  "muscles": [{ "key": "pectorals", "name": "Brust" }],
  "sources": [{ "key": "nasm_chest", "title": "NASM – Chest Press Machine",
                "url": "https://www.nasm.org/…", "accessed_at": "2026-09-13" }],
  "equipment": [{
    "key": "chest_press", "name": "Brustpresse", "category": "kraft",
    "manufacturer": null, "photo": "media/photos/chest_press.png",
    "load_unit": "kg", "load_step": 1, "load_min": 0, "load_max": null,
    "secondary": null,
    "settings": [
      { "key": "seat_height", "label": "Sitzhöhe", "kind": "number",
        "min": null, "max": null, "step": null, "unit": null },
      { "key": "mode", "label": "Modus", "kind": "enum",
        "allowed_values": ["a", "b"] }
    ],
    "exercises": ["chest_press_neutral"]
  }],
  "exercises": [{
    "key": "chest_press_neutral", "name": "Brustpresse · neutraler Griff",
    "description": "Einstellen:\n- …", "volume_kind": "reps",
    "target_min": 8, "target_max": 12,
    "video": { "file": "media/videos/chest_press_neutral.mp4", "duration_s": 6 },
    "grip": "neutral",
    "muscles": [{ "muscle": "pectorals", "role": "primary" }],
    "review": "draft",
    "sources": ["nasm_chest"]
  }]
}
```

**Regeln, die das Skript vor jedem Schreiben prüft.** Es sammelt alle Fehler und nennt jeweils den Ort, z. B. `equipment[3] "treadmill": secondary braucht unit, step, min und max (max fehlt)`.
- `format` ist `1`. Namen, Bezeichnungen und Titel sind nicht leer. Schlüssel (auch die der Einstellungen) folgen dem Muster oben und sind je Liste (Gerätetypen, Übungen, Muskeln, Quellen, Einstellungen eines Typs) eindeutig.
- Gerätetyp: `category` ist `kraft` oder `cardio`. `load_unit` ist eins von `kg`, `watt`, `level`, `kmh`, `pct`, `rpm`. `load_step > 0`, `load_min ≥ 0`, `load_max` ist `null` oder `≥ load_min`.
- `secondary` ist `null` oder `{ unit, step, min, max }` vollständig, mit denselben Einheiten, `step > 0`, `0 ≤ min ≤ max`. Das Schema verlangt alle vier Werte.
- Einstellung: `kind` ist `number` (ohne `allowed_values`; `min`, `max`, `step`, `unit` dürfen `null` sein, `min ≤ max`) oder `enum` (mindestens zwei verschiedene, nicht leere `allowed_values`). Die Reihenfolge in der Liste ergibt `sort_order`.
- `photo` ist `null` oder ein vorhandenes PNG bzw. JPEG. Vorerst wird es die Startpose einer zugehörigen Übung. Herstellerfotos bleiben wegen ungeklärter Rechte (`permission_pending`) draußen.
- `equipment[].exercises` ist die Zuordnung. Die Reihenfolge ergibt `sort_order` je Gerätetyp. Jeder Schlüssel muss eine Übung der Datei sein, eine Übung darf an mehreren Typen hängen. Jede Übung hängt an mindestens einem Typ.
- Übung: `volume_kind` ist `reps`, `seconds` oder `meters`. `target_min` und `target_max` sind ganze Zahlen mit `0 < min ≤ max ≤` Obergrenze der Umfangsart aus `belastung.ts`. `description` ist `null` oder nicht leer.
- `video` ist `null` oder ein vorhandenes MP4 mit `duration_s` als ganze Zahl von 1 bis 45. Lässt sich die Dauer aus dem MP4 lesen, muss sie übereinstimmen. Das Video gilt für die Übung, der Import hängt es an jede ihrer Verknüpfungen.
- Zusatzdaten, die die Datei pflegt und die Prüfung kontrolliert, der Import aber **noch nicht schreibt**:
  - `grip` ist `null` oder eins von `neutral`, `pronated`, `supinated`, `semi_pronated`, `semi_supinated`, `rotating`, `front_rack`, `none`.
  - `muscles`: mindestens ein `primary`, Rollen `primary` oder `secondary`, jeder Muskel aus `muscles[]` höchstens einmal.
  - `review` ist `draft` oder `reviewed`.
  - `sources`: Schlüssel aus `sources[]`, deren `url` mit `https://` beginnt.

  Tabellen dafür und eine App-Anzeige sind eine eigene spätere Etappe. Der Beschreibungstext enthält deshalb keinen Abschnitt „Muskelgruppen“ mehr. Muskelkarten kommen nicht ins Repo, die App zeichnet sie später aus den Daten.

**Migration `0048_catalog_key.sql`:** `catalog_key text` an `equipment_models` und `exercises`, Check auf das Muster, `unique (studio_id, catalog_key)` als Constraint (Upsert braucht einen echten Constraint, `NULL` kollidiert nicht).

**Medien:**
- Videos liegen in `instruction-videos`, Fotos in `equipment-photos`, unter `<Gymtavo-ID>/catalog/videos/<key>-<sha256, 8 Zeichen>.mp4` bzw. `…/catalog/photos/<key>-<hash>.<ext>`.
- Ein vorhandener Pfad wird übersprungen. Eine geänderte Datei bekommt einen neuen Pfad, und der Datensatz zeigt per Upsert darauf. Das alte Objekt bleibt liegen und wird gemeldet.

**Ablauf von `pnpm catalog:import [datei]`** (Vorgabe `catalog/gymtavo.json`):
1. Datei prüfen. Bei Fehlern: Liste ausgeben, Exit-Code 1, nichts schreiben.
2. Ziel aus `.env` (`SUPABASE_URL`, Service-Schlüssel) nennen. Außerhalb von `127.0.0.1` ist `--ja` Pflicht. Fehlt das Gymtavo-Studio, bricht das Skript ab.
3. Ist-Stand lesen, Plan bilden: je Tabelle neu, geändert (mit Feldern), unverändert, nur in der Datenbank.
4. `--dry-run` gibt den Plan aus und endet. Kein Upload, kein Schreiben, kein `--ja` nötig.
5. Sonst: Medien hochladen, dann Gerätetypen, Einstellungen, Übungen, Verknüpfungen, Videos, jeweils als Upsert über `(studio_id, catalog_key)`, `(equipment_model_id, key)` bzw. `(equipment_model_id, exercise_id)`.
   - Ein Video einer Verknüpfung gehört dem Import nur, wenn sein Pfad mit `<Gymtavo-ID>/catalog/videos/<key>-` beginnt. Andere Videos, etwa im Portal hochgeladene, fasst er nie an.
   - Eine Transaktion über alles gibt es nicht. Nach einem Abbruch setzt ein zweiter Lauf sauber fort.

**Nie löschen, nur melden:** Gerätetypen und Übungen mit Schlüssel, die die Datei nicht mehr nennt; Einstellungen und Verknüpfungen, die fehlen; ein Video, das auf `null` gesetzt wurde; ersetzte Medienobjekte; Katalogzeilen ohne Schlüssel. Der zweite Lauf hintereinander meldet nur „unverändert“ und schreibt nichts.

**Tests:**
- Unit-Tests für Prüfung und Planbildung im Domain-Paket.
- Integrationstests gegen das geteilte lokale Supabase ohne Reset: Zufallsschlüssel `t_<zufall>_…` im Gymtavo-Studio, nur die eigenen Zeilen und Objekte werden abgeräumt. Abgedeckt sind Erstimport, idempotenter zweiter Lauf, Änderung, gemeldetes Entfernen, Trockenlauf ohne Schreiben und unberührtes fremdes Video.
- Zum Schluss der volle Import lokal als Sichtprobe. Gegen Produktion läuft das Skript erst nach dem Merge und auf Freigabe.

## 10. Portal (Etappe 5)

- Gerätemodell anlegen und bearbeiten: Pflichtfeld „Gymtavo-Gerätetyp“ mit Suche; bestehende Modelle zeigen einen Hinweis, bis sie zugeordnet sind.
- Reiter Übungen: Die Gymtavo-Übungen des Typs stehen schreibgeschützt dabei, mit „Eigenes Video ergänzen“. Dazu kommt „Gymtavo-Übung anhängen“ für Übungen anderer Typen.
- Die spätere Gymtavo-Pflege (Etappe 6) ist das normale Portal im Gymtavo-Studio. Der Owner sieht es in seiner Studio-Liste.

### 10.1 Konkrete Form (Nachtrag zur Etappe 5, 10. Oktober 2026)

**Ausgangslage:** Der Import (Etappe 2) ist verschoben, der Katalog ist lokal und in Produktion leer. Keine Migration nötig: 0047 trägt Spalte, Trigger, Verknüpfungs-Policy und Videoablage bereits.

**Pflicht, sobald es Typen gibt:**
- Hat der Katalog mindestens einen Gerätetyp, verlangt das Portal den Gymtavo-Typ beim Anlegen eines Modells und beim Speichern seiner Stammdaten; eine Zuordnung lässt sich ändern, aber nicht entfernen. Ist der Katalog leer, entfallen Feld und Hinweis, und nichts blockiert. Im Gymtavo-Studio selbst gilt die Regel nicht (`catalogTypeRequired`).
- Die Regel steht in den Server-Actions des Portals, nicht in `createEquipmentModel`. Grund: Das lokale Supabase ist geteilt; eine Domain-Regel, die vom Inhalt des Katalogs abhängt, würde jeden bestehenden Integrationstest brechen, sobald ein anderer Test Gymtavo-Typen anlegt. Modelle legt nur das Portal an, die API nicht.
- Für ein exotisches Gerät gibt es keinen Ausweg im Code. Der Katalog bekommt bei Bedarf einen allgemeinen Typ (z. B. „Sonstiges Gerät“) ohne Übungen.

**Domain (`catalog.ts`):**
- `createEquipmentModel` und `updateEquipmentModel` nehmen `catalogModelId` (nullish). Der Trigger-Fehler `gymtavo_zuordnung_ungueltig` wird zu `validation_failed`.
- `attachExerciseToModel` erlaubt Übungen aus dem Studio des Modells oder aus dem Gymtavo-Studio. Eine Übung aus einem dritten Studio bleibt `not_found`.
- `getStudioCatalog` liefert zusätzlich `isCatalog` am Studio, `catalogModelId` am Modell und `fromCatalog` an jeder Übungsverknüpfung.
- Neu: `listCatalogTypes(client)` liefert alle Gymtavo-Typen mit ihren Übungen samt Katalogvideo, nach Namen sortiert. Nur die Seiten, die es brauchen, rufen es auf; `ladeKatalog` hängt an jeder Portalseite und bleibt schlank.
- Neu: `catalogTypeRequired(client, studioId)` – `false` im Gymtavo-Studio, sonst ob der Katalog Typen hat. Die Server-Actions fragen damit die Pflicht ab.

**Portal:**
- Modellformulare (Assistent `modell/neu`, `StammdatenFormular`): Feld „Gymtavo-Gerätetyp“ mit Textsuche über die Typliste.
- Hinweis für Altbestände: neuer Punkt in `offenePunkte` – „Kein Gymtavo-Typ“, Grund „Mitglieder sehen an diesem Gerät keine Gymtavo-Übungen.“ Er erscheint damit im Band über den Modellreitern und in der Modellliste, nur solange der Katalog Typen hat.
- Reiter Übungen in zwei Teilen:
  1. **Gymtavo-Übungen:** die des zugeordneten Typs („vom Typ“) und angehängte anderer Typen („angehängt“). Schreibgeschützt; je Übung Katalog- oder eigenes Video mit „Eigenes Video ergänzen“ und Ersetzen (Löschen eines Videos kennt das Portal auch für eigene Übungen nicht). „Lösen“ einer angehängten Gymtavo-Übung löscht ihr eigenes Video mit; die Rückfrage sagt das (`detachCatalogExercise`). „Lösen“ nur bei angehängten. Darüber „Gymtavo-Übung anhängen“ mit Suche über alle noch nicht gezeigten Gymtavo-Übungen.
  2. **Eigene Übungen:** wie bisher, samt Reihenfolge-Dialog. Der Reihenfolge-Dialog ordnet nur eigene Übungen.
- „Eigenes Video ergänzen“ an einer Typ-Übung ohne Verknüpfung legt erst die Verknüpfung an (`attachExerciseToModel`); das Video hängt daran und gehört damit dem Studio (5.3).
- Übungsschritt im Assistenten (`einrichten/geraet/…/uebungen`): Die Übungen des Typs stehen schreibgeschützt als „kommen automatisch mit“ dabei, damit niemand Bankdrücken ein zweites Mal anlegt.

**Gymtavo-Studio im Portal (bis Etappe 6):**
- Navigation nur mit dem Gerätebereich (als „Gerätetypen“) und den Einstellungen.
- Überblick, Leute, Kurse, Tags und Einrichten liefern `notFound` oder leiten auf den Gerätebereich.
- Kein Reiter Instanzen. Keine offenen Punkte zu Gerät, Tag oder Typzuordnung.

**Tests:**
- Integration gegen das geteilte Supabase, nie zurückgesetzt. Die Tests legen eigene Gymtavo-Typen mit eindeutigen Namen an und räumen sie wieder ab.
- Unit: `offenePunkte` und die Typsuche.
- Playwright:
  1. Modell mit Typ anlegen.
  2. Altes Modell zuordnen; der Hinweis verschwindet.
  3. Gymtavo-Übung anhängen und eigenes Video ergänzen.
  4. Das Gymtavo-Studio zeigt keine Mitglieder, keine Geräte und keinen QR-Code.

## 11. Etappen

1. **Datenbank:** Migration 0047 (5.1–5.5) mit Integrationstests für jede Policy. Dazu Leser absichern, damit sich die App noch nicht ändert: Bootstrap und Startseite blenden das Gymtavo-Studio aus; Verlauf und Fortschritt fallen bei fehlenden Namen auf `my_history_labels()` zurück.
2. **Import:** `catalog_key`, Skript, `catalog/gymtavo.json` mit dem vollen Bestand aus dem GYMTAVO-Paket (siehe 9.1).
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
