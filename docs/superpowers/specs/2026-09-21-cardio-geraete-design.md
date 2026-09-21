# Cardio-Geräte — Belastung und Umfang statt Kilogramm und Wiederholungen

**Stand:** 21. September 2026
**Status:** Entschieden, bereit für Umsetzungsplan.
**Vorbedingung:** Der Satzpfad aus `2026-09-07-ios-geraet-kernflow-design.md` und der Abschluss-Screen aus `2026-09-08-ios-training-kurse-design.md` sind gebaut und in `master`.
**Zitierweise:** `M1 §n` verweist auf `2026-08-28-fitness-retrofit-m1-design.md`, `Blueprint §n` auf `fitness-retrofit-technical-blueprint.md`; Verweise innerhalb dieses Dokuments stehen als „Abschnitt n".
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber M1 (Produktverhalten) und `2026-08-30-designsystem.md`. Dieses Dokument ändert eine Grundannahme von M1 §7.1 und §8.4: dass die Belastung eines Geräts ein Gewicht in Kilogramm ist und der Umfang eines Satzes eine Wiederholungszahl. Alles andere bleibt.

---

## 1. Ausgangslage und Kernbefund

Die Plattform kann heute nur Kraftgeräte. Ein Laufband, ein Ergometer, ein Crosstrainer oder ein Rudergerät lässt sich zwar als Gerätemodell anlegen, aber `weight_step_kg` und `target_reps_min` bedeuten dort nichts.

Der Befund nach Durchsicht von `progression.ts`, `machine-context.ts`, `abschluss.ts`, `progress.ts`, den Migrationen 0004 bis 0017 und den iOS-Rädern: **Cardio ist kein neuer Fall, sondern derselbe Fall mit anderen Einheiten.** Die bestehende Logik kennt vier Begriffe, die alle fest an Kraft gebunden sind:

| Begriff | Wo er heute lebt | Bedeutung |
|---|---|---|
| Belastung | `weight_kg`, `weight_step_kg`, `min/max_weight_kg` am Modell | Das, was am Gerät gedreht wird und das die Regel steigert |
| Umfang | `reps`, `target_reps_min/max` an der Übung | Das, was das Mitglied schafft und gegen den Korridor geprüft wird |
| Reserve | `rir` | Subjektiv: war noch etwas drin? |
| Problem | `problem_flag`, `problem_reason` | Sicherheitsstopp |

Cardio braucht exakt dieselben vier Begriffe. Nur die Einheiten wechseln: die Belastung heißt Watt, Level oder km/h, der Umfang heißt Minuten statt Wiederholungen. Die Regel in `suggestNextWeight` ist bereits einheitenfrei formuliert (uniforme Belastung im Block, Korridor oben mit Reserve erreicht → eine Stufe hoch, zweimal unten verfehlt → eine Stufe runter, Problem → halten). Sie entscheidet für „20 min bei 8,5 km/h, Reserve 2" unverändert richtig.

Die Anpassung ist deshalb **keine Cardio-Logik, sondern das Herauslösen der Einheiten aus den Spaltennamen**. Danach gibt es im Regelwerk keinen Zweig „wenn Cardio".

---

## 2. Scope

**Enthalten:**

- Datenmodell: Belastungseinheit am Gerätemodell, Umfangsart an der Übung, generische Wertspalten am Satz (Abschnitt 4, Migration 0045)
- Domain: Umbenennung der Typen, ein Formatierer für Belastungswerte, Algorithmusversion 2.0.0 ohne Regeländerung (Abschnitt 5)
- API: Feldnamen in Gerätekontext, Bootstrap, Satz-PUT, Sessions, Progress, Abschluss (Abschnitt 6)
- Portal: Belastungsart am Modell, Umfangsart an der Übung, Räder mit Wertelisten je Einheit (Abschnitt 7)
- iOS: Zeit- und Streckenrad, Einheit an allen Stellen, an denen heute „kg" hart steht (Abschnitt 8)
- Tests, die zeigen, dass die Regel für Watt/Minuten dasselbe tut wie für kg/Wiederholungen (Abschnitt 12)

**Nicht enthalten** (bewusst, siehe Abschnitt 10):

- Strukturierte Intervallprogramme mit wechselnder Belastung innerhalb eines Blocks
- Pulszonen, Kalorien, Distanz als Nebenwerte eines Satzes
- Geräteanbindung (Blueprint §2.2)
- Eine zweite Regel für Dauer-Progression („erst länger, dann härter")
- Ein laufender Timer im Geräte-Screen

---

## 3. Begriffsmodell

### 3.1 Belastung gehört ans Gerätemodell

Das Modell bestimmt, was man drehen kann: den Gewichtsstapel, den Widerstandsregler, das Tempo. Deshalb trägt das Modell die **Belastungseinheit** und die Rastung (Minimum, Maximum, Schritt):

| `load_unit` | Beispiel | Typischer Schritt |
|---|---|---|
| `kg` | Beinpresse, Latzug | 2,5 |
| `watt` | Ergometer, Spinning-Bike | 5 oder 10 |
| `level` | Crosstrainer, Stairmaster, Rudergerät | 1 |
| `kmh` | Laufband | 0,5 |

**Genau eine Belastung pro Modell.** Das ist die Entscheidung, die die „hundert Anpassungen" verhindert. Ein Laufband hat Tempo und Neigung, ein Ergometer Watt und Trittfrequenz. Nur eine davon dreht die Progression. Die andere ist ein **Einstellwert**, und dafür gibt es `equipment_setting_definitions` heute schon: „Neigung, number, 0–15 %, Schritt 0,5" wird beim Modell angelegt wie „Sitzhöhe 1–10", und das Mitglied kalibriert sie einmal.

Weitere Einheiten (`mph`, `kmh` vs. `min_per_km`, `spm`) kommen, wenn ein Studio sie braucht, als ein Eintrag im Check-Constraint und eine Zeile im Formatierer (Abschnitt 5.3). Sie ändern nichts an der Regel.

### 3.2 Umfang gehört an die Übung

Die Übung sagt, was das Mitglied schaffen soll. Heute ist das ein Wiederholungskorridor (M1 §8.4, Vorgabe 8–12). Künftig trägt die Übung eine **Umfangsart** und denselben Korridor in dieser Einheit:

| `volume_kind` | Gespeichert als | Rad im Geräte-Screen | Vorgabe |
|---|---|---|---|
| `reps` | Wiederholungen | 1–40, Schritt 1 (wie heute) | 8–12 |
| `seconds` | Sekunden | 0:30–90:00, Schritt 0:30 | 15–20 min |
| `meters` | Meter | 100–20 000, Schritt 100 | 2 000–5 000 |

`seconds` deckt Laufband, Ergometer, Crosstrainer, Stairmaster. `meters` ist für Rudergeräte da, an denen üblicherweise auf Strecke trainiert wird. Beides ist eine ganze Zahl, wie `reps` heute.

Zwischen Belastungseinheit und Umfangsart gibt es **keine erzwungene Kopplung.** Eine Übung „Halten 60 s" an einer Kraftmaschine (isometrisch) ist eine `seconds`-Übung an einem `kg`-Modell und damit ohne Sonderfall ausdrückbar. Der Trainer entscheidet, was sinnvoll ist.

### 3.3 Reserve und Problem bleiben

`rir` bleibt Spalte, Skala 0–10 und Schwelle `>= 1`. Nur der Wortlaut im Geräte-Screen wird einheitenfrei: „Wie viel hattest du noch?" statt „Wiederholungen in Reserve". `2026-09-07-ios-geraet-kernflow-design.md` Abschnitt 7.6 nennt den Chip ohnehin schon „Reserve".

Die Problemmeldung (M1 §5.8) ändert sich nicht. `zu_schwer` liest sich am Ergometer als „zu hart" und bleibt derselbe Code.

### 3.4 Der Satz bleibt der Satz

Ein Cardio-Block hat meist genau einen Satz („20 Minuten bei 120 W"). Das ist für die Regel kein Sonderfall: `HISTORY_WINDOW` zählt Blöcke je Trainingstag, nicht Sätze. Block, Session, Zirkel-Logik (M1 §5.3), Resttimer, Abschluss: alles unverändert. Das Wort „Satz" bleibt auch im UI; Abschnitt 13 hält die Alternative fest.

---

## 4. Datenmodell

### 4.1 Änderungen je Tabelle

**`equipment_models`**

| Heute | Künftig | Anmerkung |
|---|---|---|
| — | `load_unit text not null default 'kg'` | Check `in ('kg','watt','level','kmh')` |
| `weight_step_kg` | `load_step` | Constraint `> 0` bleibt |
| `min_weight_kg` | `load_min` | Constraint `>= 0` bleibt |
| `max_weight_kg` | `load_max` | Constraint bleibt |

**`exercises`**

| Heute | Künftig | Anmerkung |
|---|---|---|
| — | `volume_kind text not null default 'reps'` | Check `in ('reps','seconds','meters')` |
| `target_reps_min` | `target_min` | `integer`, Constraint `> 0` bleibt |
| `target_reps_max` | `target_max` | Constraint `>= target_min` bleibt |

**`workout_sets`**

| Heute | Künftig | Anmerkung |
|---|---|---|
| `weight_kg numeric(6,2)` | `load numeric(6,2)` | Constraint `>= 0` bleibt; 9999,99 reicht für Watt |
| `reps int` | `volume int` | Check `> 0 and <= 100000`; die Obergrenze je Art prüft die Domain (Abschnitt 5.1) |

**`progression_suggestions`**

| Heute | Künftig |
|---|---|
| `result_weight_kg` | `result_load` |

Der `inputs`-Datensatz ändert seine Schlüssel (Abschnitt 5.2). Alte Zeilen behalten die alten Schlüssel; dafür gibt es `algo_version`.

**Unverändert:** `member_machine_calibrations` (die Einstellwerte sind bereits generisch), `workout_sessions`, alle RLS-Policies, alle Indizes. **`body_measurements.weight_kg` bleibt `weight_kg`**: das ist Körpergewicht, keine Belastung, und darf bei der Umbenennung nicht mitgezogen werden.

### 4.2 Warum generische Spalten und nicht `reps` plus `duration_s`

Die additive Variante (`reps` bleibt, `duration_s` kommt hinzu, Check „genau eins von beiden") ist sprechender, aber jede Auswertung muss dann wählen: `progression.ts`, `progress.ts`, `abschluss.ts`, `sessions.ts`, die Blockliste in iOS. Genau an diesen Wahlstellen entstehen über die Zeit die Sonderfälle, die dieses Dokument vermeiden will.

Mit `load` und `volume` als reinen Zahlen hat die Regel-Engine null Verzweigungen. Die Bedeutung lebt an genau zwei Stellen: `load_unit` am Modell, `volume_kind` an der Übung. Der Preis ist, dass `reps` nicht mehr `reps` heißt. Dafür steht in jedem Typ und jeder Migration ein Kommentar, der das Wort erklärt.

### 4.3 Migrationsskizze `0045_belastung_umfang.sql`

```sql
-- Belastung und Umfang statt Kilogramm und Wiederholungen.
--
-- Ein Laufband hat keinen Gewichtsstapel und ein Dauerlauf keine
-- Wiederholungen. Die Regel in progression.ts war schon einheitenfrei;
-- nur die Spaltennamen behaupteten Kilogramm. Ab hier: das Modell traegt
-- die Belastungseinheit, die Uebung die Umfangsart, der Satz zwei Zahlen.
--
-- body_measurements.weight_kg bleibt: Koerpergewicht ist keine Belastung.

alter table public.equipment_models
  rename column weight_step_kg to load_step;
alter table public.equipment_models
  rename column min_weight_kg to load_min;
alter table public.equipment_models
  rename column max_weight_kg to load_max;
alter table public.equipment_models
  add column load_unit text not null default 'kg'
    check (load_unit in ('kg', 'watt', 'level', 'kmh'));

alter table public.exercises
  rename column target_reps_min to target_min;
alter table public.exercises
  rename column target_reps_max to target_max;
alter table public.exercises
  add column volume_kind text not null default 'reps'
    check (volume_kind in ('reps', 'seconds', 'meters'));

alter table public.workout_sets
  rename column weight_kg to load;
alter table public.workout_sets
  rename column reps to volume;
-- Die alte Grenze (1000) war eine Wiederholungsgrenze. Sekunden und Meter
-- brauchen mehr; die Grenze je Umfangsart prueft die Domain.
alter table public.workout_sets
  drop constraint workout_sets_reps_check;
alter table public.workout_sets
  add constraint workout_sets_volume_check
    check (volume > 0 and volume <= 100000);

alter table public.progression_suggestions
  rename column result_weight_kg to result_load;
```

Der Check auf `reps` ist in 0013 inline und unbenannt; PostgreSQL vergibt dafür `workout_sets_reps_check`. Vor dem Schreiben mit `\d workout_sets` gegenprüfen. `smoke:migrations` und die RLS-Tests laufen danach unverändert, weil keine Policy eine der umbenannten Spalten anfasst.

Die Umbenennungen geschehen **in place**, nicht über neue Spalten mit Kopie: alle Bestandsdaten sind Kraftdaten mit `kg` und `reps`, die Defaults machen sie korrekt. Es gibt vor dem Pilot keine Fremdclients, die die alten Namen bräuchten.

---

## 5. Domain

### 5.1 Typen und Validierung

`recordSetInputSchema` in `workout.ts`:

```ts
load: z.number().min(0).max(9999),
volume: z.number().int().min(1).max(100000),
```

Die feinere Obergrenze je Umfangsart prüft `recordSet` gegen die Übung, die ohnehin geladen wird: `reps` ≤ 1000, `seconds` ≤ 14 400 (vier Stunden), `meters` ≤ 100 000. Ein Wert darüber ist `validation_failed` mit dem Wortlaut der Art („Mehr als vier Stunden sind kein Satz.").

**Kompatibilität für einen Release:** `recordSetInputSchema` nimmt `weightKg` und `reps` zusätzlich als Aliase an und bildet sie auf `load`/`volume` ab. Grund: `PendingWriteStore` auf einem Gerät, das vor dem Update offline trainiert hat, schickt noch die alten Namen. Ohne Alias gingen diese Sätze verloren. Der Alias wird mit dem übernächsten Release entfernt; ein Test hält fest, dass er existiert.

### 5.2 Progression: Version 2.0.0 ohne Regeländerung

`progression.ts` benennt um, entscheidet aber identisch:

| Heute | Künftig |
|---|---|
| `WorkoutSetInput.weightKg` / `.reps` | `.load` / `.volume` |
| `ProgressionInput.targetRepsMin/Max` | `.targetMin/Max` |
| `ProgressionInput.weightStepKg/minWeightKg/maxWeightKg` | `.loadStep/loadMin/loadMax` |
| `ProgressionSuggestion.resultWeightKg` | `.resultLoad` |
| `ProgressionInputsRecord.currentWeightKg` | `.currentLoad` |
| `suggestNextWeight` | `suggestNextLoad` |

`PROGRESSION_ALGO_VERSION` wird `2.0.0`, weil der persistierte `inputs`-Datensatz andere Schlüssel trägt. Die Begründungscodes bleiben wörtlich (`korridor_oben_erreicht`, `geraetegrenze_erreicht` usw.); sie waren nie an kg gebunden. `snapToNearestStep` und `withinMachineLimits` rechnen bereits nur mit Zahlen.

`HISTORY_WINDOW = 2` bleibt. Für Cardio heißt das: zwei Trainingstage in Folge am oberen Korridorende mit Reserve, dann eine Stufe hoch. Das ist konservativ und vor dem Pilot fachlich zu prüfen, wie die Kraftschwellen auch (M1 §8.4).

### 5.3 Ein Formatierer, nicht viele

Neues Modul `packages/domain/src/belastung.ts`:

```ts
export type LoadUnit = "kg" | "watt" | "level" | "kmh";
export type VolumeKind = "reps" | "seconds" | "meters";

/** "80 kg", "120 W", "Level 8", "8,5 km/h" -- EIN Ort fuer die Einheit. */
export function formatLoad(value: number, unit: LoadUnit): string;
/** "+2,5 kg", "+10 W", "+1 Level", "+0,5 km/h" */
export function formatLoadDelta(delta: number, unit: LoadUnit): string;
/** "12 Wdh.", "20:00 min", "2.000 m" */
export function formatVolume(value: number, kind: VolumeKind): string;
/** Wertelisten fuer Portal-Raeder und Vorgaben je Einheit. */
export function defaultLoadRange(unit: LoadUnit): { min: number; max: number | null; step: number };
export function defaultTargetRange(kind: VolumeKind): { min: number; max: number };
```

Das ist die Stelle, die bei einer neuen Einheit wächst: eine Zeile je Funktion. Nichts sonst.

### 5.4 Weitere Domain-Dateien

- `abschluss.ts`: `Blockvorschlag.deltaKg` → `deltaLoad`, `resultWeightKg` → `resultLoad`, dazu `loadUnit` im Vorschlag, damit der Abschluss-Screen ohne zweiten Lookup formatieren kann.
- `machine-context.ts`: `equipmentModel.loadUnit`, `loadStep/loadMin/loadMax`; `exercises[].volumeKind`, `targetMin/Max`; `history[].load`, `history[].volume: number[]`.
- `bootstrap.ts`: dieselben Felder in `machines[].equipmentModel`, `exercises[]`, `lastSets[]`.
- `sessions.ts`: `sets[].load`, `.volume`; die Blockzusammenfassung „3 Sätze · 80 kg" wird serverseitig mit `formatLoad` gebildet oder liefert `loadUnit` mit.
- `progress.ts`: `firstWeightKg/currentWeightKg/changeKg/topWeightKg` → `firstLoad/currentLoad/changeLoad/topLoad`, plus `loadUnit` je Übung.
- `catalog.ts`: Modell-Schemas mit `loadUnit`, Übungs-Schemas mit `volumeKind`; Vorgaben aus `belastung.ts`.

---

## 6. API

Alle Verträge sind screenorientiert (M1 §6.3) und ändern nur Feldnamen:

| Endpoint | Änderung |
|---|---|
| `GET /machines/{id}/context`, `GET /tags/{token}/context` | Felder wie in Abschnitt 5.4 |
| `GET /me/bootstrap` | Felder wie in Abschnitt 5.4 |
| `PUT /workout-sessions/{id}/sets/{setId}` | `load`, `volume`; Aliase `weightKg`, `reps` für einen Release |
| `GET /me/sessions` | `sets[].load/.volume`, `blocks[].loadUnit` |
| `GET /me/progress` | `…Load`, `loadUnit` |
| `POST /workout-sessions/{id}/complete` | `suggestions[].deltaLoad`, `.loadUnit` |

Keine neuen Endpunkte. Keine Versionierung des Pfads: es gibt vor dem Pilot keinen zweiten Client, und der Alias im Satz-PUT deckt den einzigen realen Übergangsfall (Abschnitt 5.1).

---

## 7. Portal

**Modell anlegen / Stammdaten** (`StammdatenFormular.tsx`, Halle `TelefonModellNeu`): ein Auswahlfeld **Belastung** mit den vier Einheiten vor dem Rad. `ModellGewichtRad` wird `ModellBelastungRad` und bekommt seine drei Wertelisten aus `defaultLoadRange(unit)` in `einstellungVorschlaege.ts`: für `kg` wie heute, für `watt` 0–600 in 5er-Schritten, für `level` 1–30, für `kmh` 0–25 in 0,5er-Schritten. Die Spaltenlabels sind „Minimum", „Maximum", „Schritt" wie heute, die Einheit steht im Kopf des Rads.

**Übung anlegen** (`UebungSheet.tsx`, `TelefonUebungNeu`): ein Auswahlfeld **Umfang** (Wiederholungen / Minuten / Meter). `UebungRepsRad` wird `UebungUmfangRad`; die Werteliste folgt der Art: Wiederholungen 1–50 (heute), Minuten 1–90, Meter 500–20 000. Minuten werden im Formular als Minuten eingegeben und als Sekunden gespeichert; die Umrechnung liegt in der Server-Action, nicht im Rad.

**Geräteliste und Übungsreiter:** überall, wo heute „2,5 kg" oder „8–12" steht, formatieren `formatLoad`/`formatVolume`.

Kein neuer Screen. Die Artboards `Modell`, `ModellUebungen`, `TelefonModellNeu`, `TelefonUebungNeu` bekommen je ein Auswahlfeld dazu; das wird im Umsetzungsplan als Artboard-Nachtrag geführt, nicht als eigenes Design.

---

## 8. iOS

### 8.1 Räder

`Rastwerte.wiederholungen` wird zu `Rastwerte.umfang(kind:)`:

| Art | Liste | Länge |
|---|---|---|
| `reps` | 1…40 | 40 |
| `seconds` | 30, 60, … 5400 | 180 |
| `meters` | 100, 200, … 20 000 | 200 |

Das Belastungsrad `Rastwerte.gewichte(min:max:schritt:)` bleibt unverändert und wird zu `Rastwerte.belastung(…)` umbenannt; es rechnet nur mit Zahlen. `maxRastenOhneObergrenze = 200` passt für alle vier Einheiten.

`RastRad` zeigt für `seconds` das Format „20:00" statt „1200" und für `meters` „2.000 m". Das ist Anzeige, nicht Wert; der gespeicherte Wert bleibt die ganze Zahl.

### 8.2 Modelle und DTOs

- `LokalerSatz.weightKg/reps` → `load/volume`. `SessionFileStore` liest alte Dateien mit einem `CodingKeys`-Fallback, damit eine laufende Session das App-Update überlebt.
- DTOs `TagContextResponse`, `BootstrapResponse`, `WorkoutSet`, `SessionSummary`, `ExerciseProgress`: Felder nach Abschnitt 5.4.
- `GeraetModel`: `gewicht` → `belastung`, `wiederholungen` → `umfang`; Vorbelegung aus `letzter?.load ?? modell.min` und `letzter?.volume ?? uebung.targetMin` wie heute. Der Zieltext „Ziel 8 – 12" wird „Ziel 15 – 20 min" über `formatVolume`.
- `Zahlformat.gewichtMitEinheit` bleibt für Körpergewicht. Neu: `Zahlformat.belastung(_:einheit:)` und `Zahlformat.umfang(_:art:)`, Spiegel von `belastung.ts`.

### 8.3 Screens

- **Geräte-Screen:** Belastungsrad mit Einheit im Kopf; Umfangsrad je Art; Reserve-Chip mit einheitenfreiem Wortlaut. Der Dreischritt (Abschnitt 7.3 der Kernflow-Spec) bleibt.
- **TrainingLaeuft:** Blockzeile „1 Satz · 120 W" statt „3 Sätze · 80 kg", über `Zahlformat.belastung`.
- **TrainingAbschluss:** `VorschlagsAnzeige(reasonCode:deltaKg:)` → `(reasonCode:deltaLoad:loadUnit:)`, Text „+10 W" oder „+0,5 km/h". Der Grundsatz „Zahl, nie Aufforderung" bleibt.
- **SessionDetail, Uebungsfortschritt:** Achsen- und Zeilenbeschriftung über die Einheit.

Kein neues Artboard. Alle Änderungen sind Beschriftung und Wertelisten auf bestehenden Screens.

---

## 9. Probe aufs Exempel

Das Modell gilt als allgemein genug, wenn diese vier Geräte ohne neue Spalte und ohne Zweig in der Regel durchgehen:

| Gerät | Belastung (Modell) | Einstellwert (Kalibrierung) | Übung (Umfang) | Regel steigert |
|---|---|---|---|---|
| Laufband | `kmh`, 0–20, Schritt 0,5 | Neigung 0–15 %, Schritt 0,5 | Dauerlauf, `seconds` 15–20 min | +0,5 km/h |
| Ergometer | `watt`, 25–400, Schritt 5 | Sitzhöhe 1–12 | Grundlage, `seconds` 20–30 min | +5 W |
| Stairmaster | `level`, 1–20, Schritt 1 | — | Stufen, `seconds` 10–15 min | +1 Level |
| Rudergerät | `level`, 1–10, Schritt 1 | Fußschlaufe 1–6 | 2 km, `meters` 2 000–2 000 | +1 Level |

Das Rudergerät zeigt den Grenzfall: bei einem festen Ziel („genau 2 km") ist `target_min = target_max`. Dann entscheidet allein die Reserve über die Steigerung. Das ist korrekt und braucht keine Sonderregel; der Trainer kann den Korridor auch weiter fassen.

Und die Gegenprobe: eine Beinpresse mit `kg`, 0–200, Schritt 2,5 und „Beidbeinig, `reps` 8–12" ist nach der Migration Bit für Bit dasselbe wie heute.

---

## 10. Verworfene Alternativen

**Eigene Tabellen `cardio_sets`, `cardio_exercises`.** Verdoppelt RLS, Session-Lebenszyklus, Historienpfad, Abschluss und Progress. Jede spätere Funktion (Pläne, Trainerloop, Kennzahlen) müsste beides kennen. Verworfen.

**Zwei Belastungsdimensionen pro Modell (Tempo und Neigung).** Die Regel müsste dann entscheiden, welche sie dreht, und der Vorschlag hätte zwei Zahlen. Verworfen; die zweite Dimension ist ein Einstellwert (Abschnitt 3.1).

**Nebenwerte am Satz (Distanz, Puls, kcal).** Sie gehen nie in die Regel ein und das Gerät zeigt sie selbst; die Plattform misst nichts (Blueprint §2.3). Wenn sie ein Studio will, passt das Muster aus `member_machine_calibrations`: `observations jsonb` mit `schema_version`. Für v1 gestrichen.

**Eine zweite Regel für Dauer-Progression.** Anfänger sollen erst länger, dann härter. Das löst der Trainer über den Korridor (15–20 min, dann eine neue Übung 25–30 min) oder über zwei Übungen, nicht über eine zweite Engine. Kommt allenfalls mit den Trainingsplänen (M3).

**Laufender Timer im Geräte-Screen.** Nett, aber das Gerät hat eine Uhr, und das Mitglied liest die Endanzeige ab wie beim Gewicht. Verworfen für v1.

**`modality`-Enum am Modell (`strength` / `cardio`).** Verführt zu `if (modality === 'cardio')` an genau den Stellen, die keinen Zweig haben sollen. Die Einheit reicht.

---

## 11. Betroffene Dateien

**Migration:** `supabase/migrations/0045_belastung_umfang.sql` (neu).

**Domain (`packages/domain/src/`):** `belastung.ts` (neu), `progression.ts`, `abschluss.ts`, `machine-context.ts`, `bootstrap.ts`, `workout.ts`, `sessions.ts`, `progress.ts`, `catalog.ts`, `index.ts`. Dazu die Tests `progression.test.ts`, `abschluss.test.ts`, `workout.test.ts`, `index.test.ts`.

**Integrationstests (`tests/integration/`):** `api-workout-sets`, `api-tag-context`, `api-me`, `domain-record-set`, `domain-machine-context`, `domain-tag-context`, `domain-bootstrap`, `domain-catalog`, `domain-exercises`, `domain-progress`, `domain-sessions`, `rls-workout-sets`, `rls-progression-suggestions`, `rls-equipment-models`, `rls-exercises`, `studio-ueberblick` sowie alle Tests, deren Seed ein Modell oder eine Übung anlegt (`api-machine-photos`, `fallback-inhalt`, `join-studio-by-tag`, `machine-tags-kind`, `resolve-tag-fallback`, `rls-machines`, `rls-member-machine-calibrations`, `tag-binden`, `tag-chargen`, `updated-at-trigger`, `equipment-setting-definitions-enum`). Bei den letzteren ändert sich nur der Seed.

**Portal (`apps/web/app/portal/`):** `actions.ts`, `[studioId]/einrichten/actions.ts`, `bausteine/einstellungVorschlaege.ts`, `bausteine/ModellGewichtRad.tsx` → `ModellBelastungRad.tsx`, `bausteine/UebungRepsRad.tsx` → `UebungUmfangRad.tsx`, `[studioId]/(schreibtisch)/geraete/[modelId]/StammdatenFormular.tsx`, `…/layout.tsx`, `…/uebungen/page.tsx`, `[studioId]/einrichten/geraet/[machineId]/uebungen/UebungSheet.tsx`, `…/uebungen/page.tsx`. Dazu `EinstellungRad.test.tsx` und die E2E-Tests, die ein Modell anlegen.

**iOS (`apps/ios-member/FitnessMember/`):** `Workout/Rastwerte.swift`, `Workout/LokaleSession.swift`, `Workout/SessionFileStore.swift`, `Workout/WorkoutSessionStore.swift`, `Workout/Trainingszusammenfassung.swift`, `Workout/GeraeteAuswahl.swift`, `Networking/DTOs/TagContextResponse.swift`, `…/BootstrapResponse.swift`, `…/WorkoutSet.swift`, `…/SessionSummary.swift`, `…/ExerciseProgress.swift`, `DesignSystem/Zahlformat.swift`, `Screens/Geraet/GeraetModel.swift`, `…/GeraetErkanntView.swift`, `…/UebungWechselnSheet.swift`, `Screens/Training/TrainingRootView.swift`, `…/TrainingAbschlussView.swift`, `Screens/Home/SessionDetailView.swift`, `…/UebungsfortschrittView.swift`, `Verlauf/VerlaufStore.swift`. Dazu die Tests `RastwerteTests`, `GeraetModelTests`, `WorkoutSessionStoreTests`, `TrainingszusammenfassungTests`, `TrainingAbschlussZeilenTests`, `DTOTests`, `VerlaufStoreTests`, `PendingWriteStoreTests`, `GeraetKontextLadenTests`, `TrainingTabTests`.

**Nicht anfassen**, obwohl `weight` darin vorkommt: `measurements.ts`, `goals.ts`, `0042_body_measurements.sql`, `GewichtEintragenSheet`, `GewichtsverlaufView`, `HomeZiele`, `ZielSheet`, `Messwert.swift`, `OnboardingSchreiber`, `ProfilZeilen`. Das ist Körpergewicht.

**Dokumente:** M1 §7.1 und §8.4 sowie `designsystem.md` §7 (nennt `equipment_models.weight_step_kg` beim Namen) bekommen je eine Fußnote mit Verweis hierher. Der Grundsatz dort, „Die Rastung kommt aus dem Gerät, nicht aus dem Entwurf", gilt unverändert und trägt jetzt auch Watt und km/h.

---

## 12. Tests

Zusätzlich zu den mechanisch angepassten Bestandstests:

- **`progression.test.ts`:** Jeder bestehende Fall einmal mit `kg`/`reps` und einmal mit `watt`/`seconds` bei identischer Erwartung. Das ist der Beleg, dass die Regel keinen Zweig hat. Dazu: `target_min = target_max` (Rudergerät), Steigerung nur mit Reserve.
- **`belastung.test.ts`:** Formatierung aller vier Einheiten und drei Arten inkl. `de_DE`-Dezimaltrennzeichen und `20:00`-Format.
- **`workout.test.ts`:** Obergrenze je Umfangsart; Alias `weightKg`/`reps` wird angenommen und abgebildet.
- **`smoke:migrations`:** 0045 läuft auf einem Bestand mit Sätzen, Vorschlägen und Kalibrierungen durch; danach lesen `machine-context` und `progress` dieselben Werte wie vorher.
- **`RastwerteTests`:** Längen und Endpunkte der drei Umfangslisten; `naechster(zu:in:)` rastet 1195 s auf 1200.
- **`SessionFileStore`:** Eine Session-Datei im alten Format (`weightKg`, `reps`) lädt und ergibt `load`/`volume`.
- **Portal E2E:** Ein Laufband mit `kmh` und einer Minuten-Übung anlegen, im Gerätekontext erscheinen `loadUnit: "kmh"` und `volumeKind: "seconds"`.

---

## 13. Offene Punkte

1. **Wortlaut „Satz" bei Cardio.** Bleibt in v1. Wenn Pilotmitglieder stolpern, wird es ein Anzeigetext je Umfangsart („Durchgang" für `seconds`/`meters`), kein Datenmodellwort.
2. **Hinweis im Portal bei unplausibler Kombination** (Wiederholungs-Übung an einem Watt-Modell). Bewusst nicht erzwungen (Abschnitt 3.2). Ob ein Hinweis nötig ist, zeigt das Onboarding im Pilot.
3. **Schwellen für Cardio** (Reserve ≥ 1, zwei Tage in Folge) sind Kraftschwellen. Vor dem Pilot mit dem Trainer prüfen, wie M1 §8.4 es für Kraft vorsieht.
4. **`kmh` vs. Pace.** Läufer denken in min/km. Anzeige-Umrechnung ist eine Zeile im Formatierer; gespeichert wird km/h, weil das Laufband so rastet.

---

## 14. Nächste Schritte

1. Umsetzungsplan `docs/superpowers/plans/…-cardio-geraete.md` in drei Schnitten: (a) Migration + Domain + Integrationstests, (b) Portal, (c) iOS. Schnitt (a) ist ohne (b) und (c) deploybar, weil alle Bestandsdaten `kg`/`reps` sind und der Satz-PUT die Aliase annimmt.
2. Artboard-Nachtrag für die vier Portal-Screens (je ein Auswahlfeld).
3. Fachliche Prüfung der Cardio-Schwellen vor dem Pilot (Offener Punkt 3).
