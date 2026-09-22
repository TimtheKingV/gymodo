# Cardio-Geräte — Belastung und Umfang statt Kilogramm und Wiederholungen

**Stand:** 22. September 2026 (Fassung 3: Nebenbelastung und Kategorie, Abschnitte 3.1b und 3.5)
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

- Datenmodell: Belastungseinheit und optionale Nebenbelastung am Gerätemodell, Umfangsart an der Übung, generische Wertspalten am Satz, Kategorie Kraft/Cardio am Modell (Abschnitt 4, Migration 0045)
- Domain: Umbenennung der Typen, ein Formatierer für Belastungswerte, Algorithmusversion 2.0.0 mit genau einer Regelergänzung: die Nebenbelastung muss gleich bleiben (Abschnitt 5)
- API: Feldnamen in Gerätekontext, Bootstrap, Satz-PUT, Sessions, Progress, Abschluss (Abschnitt 6)
- Portal: Belastungsart am Modell, Umfangsart an der Übung, Räder mit Wertelisten je Einheit (Abschnitt 7)
- iOS: Zeit- und Streckenrad, ein drittes Rad für die Nebenbelastung, Einheit an allen Stellen, an denen heute „kg" hart steht, Gerätesuche nach Kategorie (Abschnitt 8)
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

**Genau eine Belastung pro Modell wird progressiert.** Das ist die Entscheidung, die die „hundert Anpassungen" verhindert. Ein Laufband hat Tempo und Neigung, ein Ergometer ohne Wattanzeige Stufe und Trittfrequenz. Nur eine davon dreht die Regel. Wohin die andere gehört, entscheidet eine Frage, die für jedes Gerät gleich lautet:

- **Verändert der Regler die Intensität?** Dann ist er entweder die **Belastung** (die Regel steigert ihn) oder die **Nebenbelastung** (Abschnitt 3.1b: sie wird mitgeschrieben, und die Regel verlangt, dass sie gleich bleibt). Was der Trainer darüber hinaus festlegen will („Bergauf-Gehen: 8 %"), steht in der Übung, wie „Breiter Griff" am Latzug.
- **Verändert der Regler nur die Passform?** Dann ist er ein **Einstellwert** in `equipment_setting_definitions`, wie heute: Sitzhöhe, Fußschlaufe, Rückenpolster. Das Mitglied kalibriert ihn einmal, die Regel sieht ihn nie, und das ist richtig, weil er die Intensität nicht ändert.

Die Neigung als Einstellwert zu führen wäre der Fehler, den die Frage verhindert: das Mitglied liefe 8 km/h bei 2 %, dann 8 km/h bei 6 %, und die Regel sähe „gleiche Belastung, Korridor erreicht" und schlüge mehr Tempo vor, obwohl die Intensität schon gestiegen ist.

### 3.1b Die Nebenbelastung

Die Fassung 2 dieses Dokuments legte die Neigung allein in die Übung („Dauerlauf 0 %", „Bergauf-Gehen 8 %"). Beim Ergometer taucht dasselbe Muster zum zweiten Mal auf: Stufe, Trittfrequenz, Zeit. Zeigt das Rad Watt, ist Watt die Belastung und die Trittfrequenz steckt darin. Zeigt es nur die Stufe, ist die Trittfrequenz die versteckte zweite Intensitätsdimension. Zweimal dasselbe Problem verdient eine Struktur statt eines Namensschemas.

Deshalb kann ein Modell **genau eine Nebenbelastung** tragen, optional:

| Am Modell | Am Satz | Bedeutung |
|---|---|---|
| `secondary_unit` (nullable), `secondary_step`, `secondary_min`, `secondary_max` | `secondary_load` (nullable) | Der zweite Intensitätsregler, mit eigener Rastung |

| Gerät | Belastung | Nebenbelastung |
|---|---|---|
| Laufband | `kmh` | Neigung, `pct`, 0–15, Schritt 0,5 |
| Ergometer mit Stufenanzeige | `level` | Trittfrequenz, `rpm`, 50–120, Schritt 5 |
| Ergometer mit Wattanzeige | `watt` | keine |
| Beinpresse | `kg` | keine |

Drei Regeln halten das klein:

1. **Die Regel steigert nie die Nebenbelastung.** Sie verlangt nur, dass sie im Block und zwischen den zwei betrachteten Blöcken gleich ist (Abschnitt 5.2). Ändert das Mitglied die Neigung, gibt es keinen Vorschlag statt eines falschen.
2. **Das dritte Rad erscheint nur, wenn das Modell eine Nebenbelastung hat**, und ist vom letzten Satz vorbelegt. Im Normalfall bleibt sie gleich, und das Mitglied fasst das Rad nicht an; die Interaktionszahl (Blueprint §2.1, Punkt 8) steigt nicht.
3. **Für Kraftgeräte ist alles null.** Kein Rad, keine Spalte in der Anzeige, kein Zweig in der Regel: der Tupelvergleich `(load, secondary_load)` mit `(80, null)` ist derselbe Vergleich wie mit `(8.5, 6)`.

Das ist die eine kontrollierte Stelle, an der Cardio-Geräte anders aussehen als Kraftgeräte. Sie liegt im Datenmodell, nicht in der Regel.

Weitere Einheiten (`mph`, `spm`, `min_per_km`) kommen, wenn ein Studio sie braucht, als ein Eintrag im Check-Constraint und eine Zeile im Formatierer (Abschnitt 5.3). Belastung und Nebenbelastung teilen sich dieselbe Einheitenliste. Sie ändern nichts an der Regel.

### 3.2 Umfang gehört an die Übung

Die Übung sagt, was das Mitglied schaffen soll. Heute ist das ein Wiederholungskorridor (M1 §8.4, Vorgabe 8–12). Künftig trägt die Übung eine **Umfangsart** und denselben Korridor in dieser Einheit:

| `volume_kind` | Gespeichert als | Rad im Geräte-Screen | Vorgabe |
|---|---|---|---|
| `reps` | Wiederholungen | 1–40, Schritt 1 (wie heute) | 8–12 |
| `seconds` | Sekunden | 0:30–90:00, Schritt 0:30 | 15–20 min |
| `meters` | Meter | 100–20 000, Schritt 100 | 2 000–5 000 |

`seconds` deckt Laufband, Ergometer, Crosstrainer, Stairmaster. `meters` ist für Rudergeräte da, an denen üblicherweise auf Strecke trainiert wird. Beides ist eine ganze Zahl, wie `reps` heute.

Zwischen Belastungseinheit und Umfangsart gibt es **keine erzwungene Kopplung.** Eine Übung „Halten 60 s" an einer Kraftmaschine (isometrisch) ist eine `seconds`-Übung an einem `kg`-Modell und damit ohne Sonderfall ausdrückbar. Der Trainer entscheidet, was sinnvoll ist.

### 3.3 Reserve ist schon gefallen, Problem bleibt

Die App erfasst die Reserve (RIR) seit dem 11. September nicht mehr: Eingabe, Profilschalter und Verlaufsanzeige sind weg, neue Sätze schreiben `null` (`2026-09-11-satzpfad-feinschliff.md`, Punkt 4). `rir` bleibt als Spalte und als Regelpfad für Altdaten bestehen, bekommt aber kein Cardio-Rad und keinen neuen Wortlaut. Für Cardio wie für Kraft entscheidet damit in der Praxis der Zwei-Tage-Pfad: zweimal in Folge das obere Korridorende erreicht, eine Stufe hoch.

Die Problemmeldung (M1 §5.8) ändert sich nicht. `zu_schwer` liest sich am Ergometer als „zu hart" und bleibt derselbe Code.

### 3.4 Der Satz bleibt der Satz

Ein Cardio-Block hat meist genau einen Satz („20 Minuten bei 120 W"). Das ist für die Regel kein Sonderfall: `HISTORY_WINDOW` zählt Blöcke je Trainingstag, nicht Sätze. Block, Session, Zirkel-Logik (M1 §5.3), Resttimer, Abschluss: alles unverändert. Das Wort „Satz" bleibt auch im UI; Abschnitt 13 hält die Alternative fest.

### 3.5 Kategorie: Kraft oder Cardio, nur für Listen

Die Gerätesuche (`2026-09-10-ios-geraet-ohne-scan-design.md`) und die Geräteliste im Portal sollen nach Kraft und Cardio trennen können. Dafür trägt das Modell `category text not null default 'kraft'` mit Check `in ('kraft', 'cardio')`, vom Trainer gesetzt.

Die Kategorie wird **nicht** aus der Belastungseinheit abgeleitet. `level` gibt es an hydraulischen Kraftmaschinen wie an Crosstrainern, und ein Rudergerät ordnet ein Studio als Cardio ein, ein anderes als Ganzkörperkraft. Der Trainer weiß es, die Einheit nicht.

Und sie ist **ausschließlich Anzeige**: Gruppierung in der Suche, Filter im Portal, später eine Kennzahl im Studio-Überblick. Die Regel, der Satzpfad, der Abschluss und der Verlauf lesen sie nie. Genau das unterscheidet sie von dem `modality`-Schalter, den Abschnitt 10 verwirft: der hätte in `progression.ts` gelebt, die Kategorie lebt in `GeraeteAuswahl` und einer Portal-Liste. Ein Wächter-Test in `packages/domain` hält fest, dass `category` in `progression.ts`, `abschluss.ts`, `workout.ts` und `machine-context.ts` nicht vorkommt. Damit bringt die Trennung in der Suche das Modell keinen Schritt näher an getrennte Tabellen.

---

## 4. Datenmodell

### 4.1 Änderungen je Tabelle

**`equipment_models`**

| Heute | Künftig | Anmerkung |
|---|---|---|
| — | `load_unit text not null default 'kg'` | Check `in ('kg','watt','level','kmh','pct','rpm')` |
| `weight_step_kg` | `load_step` | Constraint `> 0` bleibt |
| `min_weight_kg` | `load_min` | Constraint `>= 0` bleibt |
| `max_weight_kg` | `load_max` | Constraint bleibt |
| — | `secondary_unit text` (nullable) | Dieselbe Einheitenliste wie `load_unit` |
| — | `secondary_step`, `secondary_min`, `secondary_max numeric` | Check: alle drei gesetzt genau dann, wenn `secondary_unit` gesetzt ist; `secondary_step > 0`, `secondary_max >= secondary_min` |
| — | `category text not null default 'kraft'` | Check `in ('kraft','cardio')`; nur Anzeige (Abschnitt 3.5) |

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
| — | `secondary_load numeric(6,2)` (nullable) | Check `>= 0`; ob es gesetzt sein muss, prüft die Domain gegen das Modell (Abschnitt 5.1) |

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
    check (load_unit in ('kg', 'watt', 'level', 'kmh', 'pct', 'rpm'));

-- Optionale Nebenbelastung (Spec Abschnitt 3.1b): der zweite
-- Intensitaetsregler, den die Regel nie steigert, aber konstant verlangt.
-- Alle vier Spalten zusammen oder keine -- eine Einheit ohne Rastung
-- haette kein Rad, eine Rastung ohne Einheit keinen Namen.
alter table public.equipment_models
  add column secondary_unit text
    check (secondary_unit is null
           or secondary_unit in ('kg', 'watt', 'level', 'kmh', 'pct', 'rpm')),
  add column secondary_step numeric check (secondary_step is null or secondary_step > 0),
  add column secondary_min  numeric check (secondary_min is null or secondary_min >= 0),
  add column secondary_max  numeric,
  add constraint equipment_models_secondary_all_or_none
    check ((secondary_unit is null) = (secondary_step is null)
       and (secondary_unit is null) = (secondary_min is null)
       and (secondary_unit is null) = (secondary_max is null)),
  add constraint equipment_models_secondary_range
    check (secondary_max is null or secondary_max >= secondary_min);

-- Nur Anzeige: Suche, Filter, Kennzahl. Keine Regel liest sie
-- (Spec Abschnitt 3.5, Waechter-Test in packages/domain).
alter table public.equipment_models
  add column category text not null default 'kraft'
    check (category in ('kraft', 'cardio'));

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
alter table public.workout_sets
  add column secondary_load numeric(6, 2)
    check (secondary_load is null or secondary_load >= 0);

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
secondaryLoad: z.number().min(0).max(9999).nullish(),
```

`recordSet` lädt das Modell ohnehin (für `studio_id`) und prüft: hat das Modell eine `secondary_unit`, muss `secondaryLoad` gesetzt sein; hat es keine, muss es fehlen. Beides sonst `validation_failed`. Der Wert wird wie die Belastung auf die Rastung des Modells gerundet, damit „82 rpm" und „85 rpm" nicht als zwei verschiedene Bedingungen zählen.

Die feinere Obergrenze je Umfangsart prüft `recordSet` gegen die Übung, die ohnehin geladen wird: `reps` ≤ 1000, `seconds` ≤ 14 400 (vier Stunden), `meters` ≤ 100 000. Ein Wert darüber ist `validation_failed` mit dem Wortlaut der Art („Mehr als vier Stunden sind kein Satz.").

**Kompatibilität für einen Release:** `recordSetInputSchema` nimmt `weightKg` und `reps` zusätzlich als Aliase an und bildet sie auf `load`/`volume` ab. Grund: `PendingWriteStore` auf einem Gerät, das vor dem Update offline trainiert hat, schickt noch die alten Namen. Ohne Alias gingen diese Sätze verloren. Der Alias wird mit dem übernächsten Release entfernt; ein Test hält fest, dass er existiert.

### 5.2 Progression: Version 2.0.0 mit einer Ergänzung

`progression.ts` benennt um:

| Heute | Künftig |
|---|---|
| `WorkoutSetInput.weightKg` / `.reps` | `.load` / `.volume`, neu `.secondaryLoad: number \| null` |
| `ProgressionInput.targetRepsMin/Max` | `.targetMin/Max` |
| `ProgressionInput.weightStepKg/minWeightKg/maxWeightKg` | `.loadStep/loadMin/loadMax` |
| `ProgressionSuggestion.resultWeightKg` | `.resultLoad` |
| `ProgressionInputsRecord.currentWeightKg` | `.currentLoad`, neu `.currentSecondaryLoad` |
| `suggestNextWeight` | `suggestNextLoad` |

Die einzige Änderung an der Entscheidung: `uniformWeight(block)` wird `uniformLoad(block)` und vergleicht das Paar `(load, secondaryLoad)` statt der einen Zahl. Wechselt innerhalb des neuesten Blocks eine der beiden, ist das `daten_uneindeutig` wie heute bei wechselndem Gewicht. In den Pfaden, die den vorigen Block heranziehen (`topTwice`, `missedTwice`), muss das Paar des vorigen Blocks gleich sein; sonst zählt er nicht als zweiter Beleg, und es bleibt bei `im_korridor`. Der Pfad „Korridor oben mit Reserve" schaut nur auf den neuesten Block und braucht den vorigen nicht: wer bei 8 km/h und 6 % den Korridor mit Reserve erreicht, bekommt +0,5 km/h bei 6 %, egal, was letzte Woche die Neigung war.

Für Kraftgeräte ist `secondaryLoad` in jedem Satz `null`, und `(80, null) === (80, null)` ist der Vergleich von heute. Es gibt keinen Zweig „wenn Nebenbelastung vorhanden".

`PROGRESSION_ALGO_VERSION` wird `2.0.0`, weil der persistierte `inputs`-Datensatz andere Schlüssel trägt. Die Begründungscodes bleiben wörtlich (`korridor_oben_erreicht`, `geraetegrenze_erreicht` usw.); sie waren nie an kg gebunden. `snapToNearestStep` und `withinMachineLimits` rechnen bereits nur mit Zahlen und steigern nur die Belastung; die Nebenbelastung wird im Vorschlag unverändert mitgegeben (`resultSecondaryLoad = currentSecondaryLoad`), damit der Abschluss-Screen „+0,5 km/h bei 6 %" schreiben kann.

`HISTORY_WINDOW = 2` bleibt. Weil die App keine Reserve mehr erfasst (Abschnitt 3.3), heißt das für Cardio wie für Kraft: zwei Trainingstage in Folge am oberen Korridorende, dann eine Stufe hoch. Das ist konservativ und vor dem Pilot fachlich zu prüfen, wie die Kraftschwellen auch (M1 §8.4).

### 5.3 Ein Formatierer, nicht viele

Neues Modul `packages/domain/src/belastung.ts`:

```ts
export type LoadUnit = "kg" | "watt" | "level" | "kmh" | "pct" | "rpm";
export type VolumeKind = "reps" | "seconds" | "meters";

/** "80 kg", "120 W", "Level 8", "8,5 km/h", "6 %", "85 U/min" -- EIN Ort fuer die Einheit. */
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

- `abschluss.ts`: `Blockvorschlag.deltaKg` → `deltaLoad`, `resultWeightKg` → `resultLoad`, dazu `loadUnit`, `secondaryLoad` und `secondaryUnit` im Vorschlag, damit der Abschluss-Screen ohne zweiten Lookup formatieren kann.
- `machine-context.ts`: `equipmentModel.loadUnit`, `loadStep/loadMin/loadMax`, `secondaryUnit/Step/Min/Max` (alle null bei Kraft); `exercises[].volumeKind`, `targetMin/Max`; `history[].load`, `history[].secondaryLoad`, `history[].volume: number[]`.
- `bootstrap.ts`: dieselben Felder in `machines[].equipmentModel` (plus `category`), `exercises[]`, `lastSets[]`.
- `sessions.ts`: `sets[].load`, `.volume`; die Blockzusammenfassung „3 Sätze · 80 kg" wird serverseitig mit `formatLoad` gebildet oder liefert `loadUnit` mit.
- `progress.ts`: `firstWeightKg/currentWeightKg/changeKg/topWeightKg` → `firstLoad/currentLoad/changeLoad/topLoad`, plus `loadUnit` je Übung.
- `catalog.ts`: Modell-Schemas mit `loadUnit`, `category` und optionaler Nebenbelastung (alle vier Felder oder keines, wie der Constraint), Übungs-Schemas mit `volumeKind`; Vorgaben aus `belastung.ts`.

---

## 6. API

Alle Verträge sind screenorientiert (M1 §6.3) und ändern nur Feldnamen:

| Endpoint | Änderung |
|---|---|
| `GET /machines/{id}/context`, `GET /tags/{token}/context` | Felder wie in Abschnitt 5.4 |
| `GET /me/bootstrap` | Felder wie in Abschnitt 5.4 |
| `PUT /workout-sessions/{id}/sets/{setId}` | `load`, `volume`, `secondaryLoad` (Pflicht genau dann, wenn das Modell eine Nebenbelastung hat); Aliase `weightKg`, `reps` für einen Release |
| `GET /me/sessions` | `sets[].load/.volume`, `blocks[].loadUnit` |
| `GET /me/progress` | `…Load`, `loadUnit` |
| `POST /workout-sessions/{id}/complete` | `suggestions[].deltaLoad`, `.loadUnit`, `.secondaryLoad`, `.secondaryUnit` |

Keine neuen Endpunkte. Keine Versionierung des Pfads: es gibt vor dem Pilot keinen zweiten Client. Der Alias im Satz-PUT deckt nur den Übergangsfall der Offline-Warteschlange (Abschnitt 5.1); die **Antworten** ändern ihre Feldnamen ohne Alias, und die heutigen iOS-DTOs (`BootstrapResponse`, `TagContextResponse`, `WorkoutSet`) verlangen die alten Namen als Pflichtfelder. Datenbank und API gehen deshalb **zusammen mit dem iOS-Stand aus Schnitt 3** live, nicht davor (Abschnitt 14).

---

## 7. Portal

**Modell anlegen / Stammdaten** (`StammdatenFormular.tsx`, Halle `TelefonModellNeu`): ein Auswahlfeld **Kategorie** (Kraft / Cardio) und ein Auswahlfeld **Belastung** mit den Einheiten vor dem Rad. Darunter ein aufklappbarer Block **Nebenbelastung** („keine" ist die Vorgabe), der bei Auswahl einer Einheit dasselbe Dreier-Rad noch einmal zeigt. Für ein Kraftgerät bleibt der Block zu; das Formular sieht aus wie heute plus zwei Auswahlfelder. `ModellGewichtRad` wird `ModellBelastungRad` und bekommt seine drei Wertelisten aus `defaultLoadRange(unit)` in `einstellungVorschlaege.ts`: für `kg` wie heute, für `watt` 0–600 in 5er-Schritten, für `level` 1–30, für `kmh` 0–25 in 0,5er-Schritten. Die Spaltenlabels sind „Minimum", „Maximum", „Schritt" wie heute, die Einheit steht im Kopf des Rads.

**Übung anlegen** (`UebungSheet.tsx`, `TelefonUebungNeu`): ein Auswahlfeld **Umfang** (Wiederholungen / Minuten / Meter). `UebungRepsRad` wird `UebungUmfangRad`; die Werteliste folgt der Art: Wiederholungen 1–50 (heute), Minuten 1–90, Meter 500–20 000. Minuten werden im Formular als Minuten eingegeben und als Sekunden gespeichert; die Umrechnung liegt in der Server-Action, nicht im Rad.

**Geräteliste und Übungsreiter:** überall, wo heute „2,5 kg" oder „8–12" steht, formatieren `formatLoad`/`formatVolume`. Die Geräteliste (`Geraete`-Artboard) bekommt einen Filter Kraft / Cardio / Alle über `category`.

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

Das Belastungsrad `Rastwerte.gewichte(min:max:schritt:)` bleibt unverändert und wird zu `Rastwerte.belastung(…)` umbenannt; es rechnet nur mit Zahlen und dient auch der Nebenbelastung. `maxRastenOhneObergrenze = 200` passt für alle Einheiten.

Das **dritte Rad** für die Nebenbelastung erscheint nur, wenn `equipmentModel.secondaryUnit` gesetzt ist. Es steht zwischen Belastung und Umfang, ist vom letzten Satz vorbelegt (sonst von `secondaryMin`) und ist im Dreischritt kein eigener Schritt: wer es nicht anfasst, bestätigt den Vorwert. Für ein Kraftgerät gibt es das Rad nicht, und der Screen ist Pixel für Pixel der heutige.

`RastRad` zeigt für `seconds` das Format „20:00" statt „1200" und für `meters` „2.000 m". Das ist Anzeige, nicht Wert; der gespeicherte Wert bleibt die ganze Zahl.

### 8.2 Modelle und DTOs

- `LokalerSatz.weightKg/reps` → `load/volume`, neu `secondaryLoad: Double?`. `SessionFileStore` liest alte Dateien mit einem `CodingKeys`-Fallback, damit eine laufende Session das App-Update überlebt.
- DTOs `TagContextResponse`, `BootstrapResponse`, `WorkoutSet`, `SessionSummary`, `ExerciseProgress`: Felder nach Abschnitt 5.4.
- `GeraetModel`: `gewicht` → `belastung`, `wiederholungen` → `umfang`; Vorbelegung aus `letzter?.load ?? modell.min` und `letzter?.volume ?? uebung.targetMin` wie heute. Der Zieltext „Ziel 8 – 12" wird „Ziel 15 – 20 min" über `formatVolume`.
- `Zahlformat.gewichtMitEinheit` bleibt für Körpergewicht. Neu: `Zahlformat.belastung(_:einheit:)` und `Zahlformat.umfang(_:art:)`, Spiegel von `belastung.ts`.
- `GeraeteAuswahl`: `Zuletzt.gewichtKg` → `load` plus Einheit; `Gruppen` bekommt die Kategorie: ohne Suchtext zwei Abschnitte „Kraft" und „Cardio" unter „Zuletzt", mit Suchtext eine flache Trefferliste wie heute. Die reine Funktion bleibt netzfrei und ohne UI prüfbar.

### 8.3 Screens

- **Geräte-Screen:** Belastungsrad mit Einheit im Kopf; bei Nebenbelastung ein drittes Rad (Abschnitt 8.1); Umfangsrad je Art; Reserve-Chip mit einheitenfreiem Wortlaut. Der Dreischritt (Abschnitt 7.3 der Kernflow-Spec) bleibt.
- **Geräteauswahl:** Abschnitte Kraft und Cardio (Abschnitt 8.2), sonst unverändert.
- **TrainingLaeuft:** Blockzeile „1 Satz · 8,5 km/h · 6 %" statt „3 Sätze · 80 kg", über `Zahlformat.belastung`; ohne Nebenbelastung entfällt der dritte Teil.
- **TrainingAbschluss:** `VorschlagsAnzeige(reasonCode:deltaKg:)` → `(reasonCode:deltaLoad:loadUnit:secondary:)`, Text „+10 W" oder „+0,5 km/h bei 6 %". Der Grundsatz „Zahl, nie Aufforderung" bleibt.
- **SessionDetail, Uebungsfortschritt:** Achsen- und Zeilenbeschriftung über die Einheit.

Kein neues Artboard. Alle Änderungen sind Beschriftung und Wertelisten auf bestehenden Screens.

---

## 9. Probe aufs Exempel

Das Modell gilt als allgemein genug, wenn diese vier Geräte ohne neue Spalte und ohne Zweig in der Regel durchgehen:

| Gerät | Kategorie | Belastung (Modell) | Nebenbelastung (Modell) | Einstellwert (Kalibrierung) | Übung (Umfang) | Regel steigert |
|---|---|---|---|---|---|---|
| Laufband | cardio | `kmh`, 0–20, Schritt 0,5 | Neigung `pct`, 0–15, Schritt 0,5 | — | Dauerlauf, `seconds` 15–20 min | +0,5 km/h, Neigung bleibt |
| Ergometer (Stufenanzeige) | cardio | `level`, 1–20, Schritt 1 | Trittfrequenz `rpm`, 50–120, Schritt 5 | Sitzhöhe 1–12 | Grundlage, `seconds` 20–30 min | +1 Stufe, Trittfrequenz bleibt |
| Ergometer (Wattanzeige) | cardio | `watt`, 25–400, Schritt 5 | — | Sitzhöhe 1–12 | Grundlage, `seconds` 20–30 min | +5 W |
| Stairmaster | cardio | `level`, 1–20, Schritt 1 | — | — | Stufen, `seconds` 10–15 min | +1 Level |
| Rudergerät | cardio | `level`, 1–10, Schritt 1 | — | Fußschlaufe 1–6 | 2 km, `meters` 2 000–2 000 | +1 Level |

Das Rudergerät zeigt den Grenzfall: bei einem festen Ziel („genau 2 km") ist `target_min = target_max`. Dann entscheidet der Zwei-Tage-Pfad: zweimal in Folge das Ziel erreicht, eine Stufe hoch. Das ist korrekt und braucht keine Sonderregel; der Trainer kann den Korridor auch weiter fassen.

Das Laufband zeigt den Zweck der Nebenbelastung: läuft das Mitglied diese Woche bei 6 % statt 2 %, sieht die Regel ein anderes Paar, zählt die Vorwoche nicht als zweiten Beleg und schlägt nichts auf falscher Grundlage vor.

Und die Gegenprobe: eine Beinpresse mit `kraft`, `kg`, 0–200, Schritt 2,5, ohne Nebenbelastung und „Beidbeinig, `reps` 8–12" ist nach der Migration Bit für Bit dasselbe wie heute. Kein drittes Rad, kein zusätzlicher Vergleich, kein Text mehr auf dem Screen.

---

## 10. Verworfene Alternativen

**Eigene Tabellen `cardio_sets`, `cardio_exercises`.** Verdoppelt RLS, Session-Lebenszyklus, Historienpfad, Abschluss und Progress. Jede spätere Funktion (Pläne, Trainerloop, Kennzahlen) müsste beides kennen. Verworfen.

**Zwei progressierte Belastungsdimensionen pro Modell.** Die Regel müsste dann entscheiden, welche sie dreht, und der Vorschlag hätte zwei Zahlen. Verworfen; die Nebenbelastung wird mitgeschrieben und konstant verlangt, aber nie gesteigert (Abschnitt 3.1b).

**Neigung als persönlicher Einstellwert.** Klingt naheliegend, weil das Rad dafür schon existiert. Aber ein Einstellwert ist für die Regel unsichtbar, und die Neigung verändert die Intensität. Verworfen, Begründung in Abschnitt 3.1.

**Neigung als Übungsvariante („Bergauf-Gehen 8 %").** Fassung 2 dieses Dokuments. Funktioniert, kostet keine Spalte, verliert aber die Zahl und macht die Regel blind, wenn das Mitglied die Neigung innerhalb derselben Übung ändert. Beim Ergometer (Stufe plus Trittfrequenz) trat das Muster zum zweiten Mal auf; zweimal dasselbe verdient eine Struktur. Ersetzt durch die Nebenbelastung (Abschnitt 3.1b). Übungsvarianten bleiben möglich, wenn der Trainer einen festen Wert vorgeben will.

**Beobachtungswerte als jsonb am Satz** (Distanz, Puls, Trittfrequenz als freie Schlüssel). Hält die Daten, aber unstrukturiert, und lädt dazu ein, später doch Logik darauf zu bauen. Die eine Dimension, die die Regel braucht, ist als Spalte ehrlicher. Verworfen.

**Getrennte Cardio-Tabellen und eigene Cardio-Regel** (`cardio_sets` mit Dauer, Distanz, Stufe, Tempo, Neigung, Puls). Drei- bis vierfacher Aufwand, und dauerhaft: RLS doppelt, Session-Lebenszyklus doppelt, Blockliste, Abschluss, Progress, Bootstrap und die iOS-Session brauchen einen zweiten Satztyp; jede künftige Funktion kostet zweimal. Und die Spaltenliste je Gerät ist genau die Hundert-Anpassungen-Falle. Verworfen. Die Trennung von Kraft und Cardio in Suche und Listen (Abschnitt 3.5) ist eine Kategorie am Modell und kein Schritt in diese Richtung.

**Nebenwerte am Satz (Distanz, Puls, kcal).** Sie gehen nie in die Regel ein und das Gerät zeigt sie selbst; die Plattform misst nichts (Blueprint §2.3). Wenn sie ein Studio will, passt das Muster aus `member_machine_calibrations`: `observations jsonb` mit `schema_version`. Für v1 gestrichen.

**Eine zweite Regel für Dauer-Progression.** Anfänger sollen erst länger, dann härter. Das löst der Trainer über den Korridor (15–20 min, dann eine neue Übung 25–30 min) oder über zwei Übungen, nicht über eine zweite Engine. Kommt allenfalls mit den Trainingsplänen (M3).

**Laufender Timer im Geräte-Screen.** Nett, aber das Gerät hat eine Uhr, und das Mitglied liest die Endanzeige ab wie beim Gewicht. Verworfen für v1.

**`modality`-Enum als Regelschalter.** Verführt zu `if (modality === 'cardio')` an genau den Stellen, die keinen Zweig haben sollen. Verworfen. Die `category` aus Abschnitt 3.5 ist etwas anderes: sie wird nur von Listen gelesen, und ein Wächter-Test hält die Regel davon fern.

---

## 11. Betroffene Dateien

**Migration:** `supabase/migrations/0045_belastung_umfang.sql` (neu).

**Domain (`packages/domain/src/`):** `belastung.ts` (neu), `kategorie-waechter.test.ts` (neu), `progression.ts`, `abschluss.ts`, `machine-context.ts`, `bootstrap.ts`, `workout.ts`, `sessions.ts`, `progress.ts`, `catalog.ts`, `index.ts`. Dazu die Tests `progression.test.ts`, `abschluss.test.ts`, `workout.test.ts`, `index.test.ts`.

**Integrationstests (`tests/integration/`):** `api-workout-sets`, `api-tag-context`, `api-me`, `domain-record-set`, `domain-machine-context`, `domain-tag-context`, `domain-bootstrap`, `domain-catalog`, `domain-exercises`, `domain-progress`, `domain-sessions`, `rls-workout-sets`, `rls-progression-suggestions`, `rls-equipment-models`, `rls-exercises`, `studio-ueberblick` sowie alle Tests, deren Seed ein Modell oder eine Übung anlegt (`api-machine-photos`, `fallback-inhalt`, `join-studio-by-tag`, `machine-tags-kind`, `resolve-tag-fallback`, `rls-machines`, `rls-member-machine-calibrations`, `tag-binden`, `tag-chargen`, `updated-at-trigger`, `equipment-setting-definitions-enum`). Bei den letzteren ändert sich nur der Seed.

**Portal (`apps/web/app/portal/`):** `actions.ts`, `[studioId]/einrichten/actions.ts`, `bausteine/einstellungVorschlaege.ts`, `bausteine/ModellGewichtRad.tsx` → `ModellBelastungRad.tsx`, `bausteine/UebungRepsRad.tsx` → `UebungUmfangRad.tsx`, `[studioId]/(schreibtisch)/geraete/[modelId]/StammdatenFormular.tsx`, `…/layout.tsx`, `…/uebungen/page.tsx`, `[studioId]/einrichten/geraet/[machineId]/uebungen/UebungSheet.tsx`, `…/uebungen/page.tsx`. Dazu `EinstellungRad.test.tsx` und die E2E-Tests, die ein Modell anlegen.

**iOS (`apps/ios-member/FitnessMember/`):** `Workout/Rastwerte.swift`, `Workout/GeraeteAuswahl.swift` und die zugehörige Listenansicht, `Workout/LokaleSession.swift`, `Workout/SessionFileStore.swift`, `Workout/WorkoutSessionStore.swift`, `Workout/Trainingszusammenfassung.swift`, `Workout/GeraeteAuswahl.swift`, `Networking/DTOs/TagContextResponse.swift`, `…/BootstrapResponse.swift`, `…/WorkoutSet.swift`, `…/SessionSummary.swift`, `…/ExerciseProgress.swift`, `DesignSystem/Zahlformat.swift`, `Screens/Geraet/GeraetModel.swift`, `…/GeraetErkanntView.swift`, `…/UebungWechselnSheet.swift`, `Screens/Training/TrainingRootView.swift`, `…/TrainingAbschlussView.swift`, `Screens/Home/SessionDetailView.swift`, `…/UebungsfortschrittView.swift`, `Verlauf/VerlaufStore.swift`. Dazu die Tests `RastwerteTests`, `GeraetModelTests`, `WorkoutSessionStoreTests`, `TrainingszusammenfassungTests`, `TrainingAbschlussZeilenTests`, `DTOTests`, `VerlaufStoreTests`, `PendingWriteStoreTests`, `GeraetKontextLadenTests`, `TrainingTabTests`.

**Nicht anfassen**, obwohl `weight` darin vorkommt: `measurements.ts`, `goals.ts`, `0042_body_measurements.sql`, `GewichtEintragenSheet`, `GewichtsverlaufView`, `HomeZiele`, `ZielSheet`, `Messwert.swift`, `OnboardingSchreiber`, `ProfilZeilen`. Das ist Körpergewicht.

**Dokumente:** M1 §7.1 und §8.4 sowie `designsystem.md` §7 (nennt `equipment_models.weight_step_kg` beim Namen) bekommen je eine Fußnote mit Verweis hierher. Der Grundsatz dort, „Die Rastung kommt aus dem Gerät, nicht aus dem Entwurf", gilt unverändert und trägt jetzt auch Watt und km/h.

---

## 12. Tests

Zusätzlich zu den mechanisch angepassten Bestandstests:

- **`progression.test.ts`:** Jeder bestehende Fall einmal mit `kg`/`reps` und einmal mit `watt`/`seconds` bei identischer Erwartung. Das ist der Beleg, dass die Regel keinen Zweig hat. Dazu: `target_min = target_max` (Rudergerät), Steigerung nur mit Reserve. Nebenbelastung: wechselnde Neigung im Block → `daten_uneindeutig`; andere Neigung im Vorblock → kein `topTwice`, kein `missedTwice`; gleiche Neigung → identisch zum Fall ohne Nebenbelastung; `null` gegen `null` verhält sich wie heute.
- **`kategorie-waechter.test.ts`:** liest `progression.ts`, `abschluss.ts`, `workout.ts`, `machine-context.ts` als Text und schlägt fehl, wenn `category` darin vorkommt. Billig, und die einzige Stelle, die die Zusage aus Abschnitt 3.5 hält.
- **`belastung.test.ts`:** Formatierung aller vier Einheiten und drei Arten inkl. `de_DE`-Dezimaltrennzeichen und `20:00`-Format.
- **`workout.test.ts`:** Obergrenze je Umfangsart; Alias `weightKg`/`reps` wird angenommen und abgebildet; `secondaryLoad` ist Pflicht bei Modell mit Nebenbelastung und verboten ohne; Rundung auf `secondary_step`.
- **`smoke:migrations`:** 0045 läuft auf einem Bestand mit Sätzen, Vorschlägen und Kalibrierungen durch; danach lesen `machine-context` und `progress` dieselben Werte wie vorher.
- **`RastwerteTests`:** Längen und Endpunkte der drei Umfangslisten; `naechster(zu:in:)` rastet 1195 s auf 1200.
- **`GeraeteAuswahlTests`:** ohne Suchtext zwei Abschnitte nach Kategorie, leere Abschnitte entfallen; mit Suchtext flache Liste wie heute.
- **`GeraetModelTests`:** drittes Rad nur bei `secondaryUnit`; Vorbelegung aus dem letzten Satz; Satz-PUT trägt `secondaryLoad` genau dann.
- **`SessionFileStore`:** Eine Session-Datei im alten Format (`weightKg`, `reps`) lädt und ergibt `load`/`volume`.
- **Portal E2E:** Ein Laufband mit Kategorie Cardio, `kmh`, Nebenbelastung `pct` und einer Minuten-Übung anlegen; im Gerätekontext erscheinen `category: "cardio"`, `loadUnit: "kmh"`, `secondaryUnit: "pct"` und `volumeKind: "seconds"`. Ein Kraftgerät ohne Nebenbelastung liefert `secondaryUnit: null`.

---

## 13. Offene Punkte

1. **Wortlaut „Satz" bei Cardio.** Bleibt in v1. Wenn Pilotmitglieder stolpern, wird es ein Anzeigetext je Umfangsart („Durchgang" für `seconds`/`meters`), kein Datenmodellwort.
2. **Hinweis im Portal bei unplausibler Kombination** (Wiederholungs-Übung an einem Watt-Modell). Bewusst nicht erzwungen (Abschnitt 3.2). Ob ein Hinweis nötig ist, zeigt das Onboarding im Pilot.
3. **Schwellen für Cardio** (Reserve ≥ 1, zwei Tage in Folge) sind Kraftschwellen. Vor dem Pilot mit dem Trainer prüfen, wie M1 §8.4 es für Kraft vorsieht.
4. **`kmh` vs. Pace.** Läufer denken in min/km. Anzeige-Umrechnung ist eine Zeile im Formatierer; gespeichert wird km/h, weil das Laufband so rastet.
5. **Progression über die Nebenbelastung** (eine Übung, die die Neigung steigern soll statt des Tempos). In v1 steigert die Regel nur die Belastung; der Trainer löst das über gestufte Übungen („Bergauf 4 %", „6 %", „8 %"). Wird es im Pilot gebraucht, ist die saubere Erweiterung ein Feld an der Übung, das sagt, ob sie Belastung oder Nebenbelastung progressiert (`exercises.progresses = 'load' | 'secondary'`). Die Regel tauscht dann nur, welches Element des Paars sie steigert und welches sie konstant verlangt. Das bricht nichts an diesem Modell und bleibt bewusst draußen, bis ein Trainer es verlangt.
6. **Kategorie als Kennzahl.** Der Studio-Überblick könnte Kraft- und Cardio-Nutzung getrennt zeigen. Reine Anzeige, liest `category`, passt zu Abschnitt 3.5. Kommt, wenn ein Betreiber danach fragt.

---

## 14. Nächste Schritte

1. Umsetzungspläne in drei Schnitten: (a) Migration + Domain + Integrationstests (`2026-09-22-cardio-schnitt1-datenmodell-domain.md`, umgesetzt), (b) Portal, (c) iOS. Schnitt (a) ist **baubar** ohne (b) und (c), aber nicht allein **deploybar**: die API-Antworten tragen neue Feldnamen, die die heutige App als Pflichtfelder unter den alten Namen erwartet. Live gehen (a) und (c) gemeinsam, als ein TestFlight-Schnitt vor dem Pilot; (b) kann davor oder danach.
2. Artboard-Nachtrag für die vier Portal-Screens (je ein Auswahlfeld).
3. Fachliche Prüfung der Cardio-Schwellen vor dem Pilot (Offener Punkt 3).
