# Plan-Merkmale für alle Katalogübungen – Vorschlag zur Prüfung

Stand 16.11.2026. **Von Tim freigegeben (16.11.):** Tabelle, E1a, E2, E3a.

Umgesetzt:
- **E1a:** `druecken`, `ziehen`, `beine_knie` werden vom Generator nur mit Mehrgelenk belegt (`NUR_MEHRGELENK_PFLICHT`, gilt für Pflicht-, Ergänzungs- und Auffüllplätze); Flys/Pullover kommen nur über Fokus oder freie Wahl. Regeln 1.5.0.
- **E2:** Planpositionen außer Cardio kennen nur Wiederholungen (iOS `PlanZeile`, `Ablaufzeile`). `db_farmers_walk` bleibt **ohne** Plan-Merkmale.
- **E3a:** `plan.vorschlag` (Default `true`), Spalte `exercises.plan_vorschlag` (Migration 0074). `false` für alle `bb_*`/`ez_*`, `db_goblet_squat`, `db_squat_sides`, `db_reverse_lunge`, `db_forward_lunge`, `db_bulgarian_split_squat`, `db_step_up`, `db_romanian_deadlift`, `cable_pull_through` (28 Übungen).
- 115 `plan`-Blöcke in `catalog/gymtavo.json`; 161 von 162 Übungen haben jetzt Plan-Merkmale.

Anlass: P4 (Einheit bearbeiten) erlaubt freies Hinzufügen und Tauschen. Der Server lehnt Übungen ohne Plan-Merkmale ab, weil sonst der Verletzungs-Check („meiden“) ins Leere liefe. Heute haben 46 von 162 Übungen einen `plan`-Block, 116 fehlen.

## 1. Befund: Wer liest das Feld?

- **Import** (`packages/domain/src/katalog-datei.ts`, `katalog-plan.ts`, `katalog-import.ts`): prüft `plan` per zod (Werte aus `BAUSTEINE`, `PLAN_TYPEN`, `BEREICHE`) und schreibt es nach `exercises.plan_baustein / plan_typ / plan_bereiche`. Reiner Durchreicher, keine Logik.
- **Generator** (`trainingsplan-kandidaten.ts` → `ladeKandidaten`): **jede** Übung mit `plan_baustein` und `plan_typ` wird Kandidat. Innerhalb eines Bausteins rotiert `waehleKandidat` (`trainingsplan-auswahl.ts`) über alle Kandidaten, sortiert nach Übungs-ID (UUID). Es gibt keinen Vorrang für Geräte vor Freihanteln.
- **Tauschalternativen** (`alternativenJeBaustein`, `trainingsplan-bootstrap.ts`): ebenfalls alle Kandidaten je Baustein, „meiden“ gefiltert.
- **Server-Check** (`0070_plan_wochenraster_schreibwege.sql` ~Z. 166): liest `plan_bereiche` der gewählten Übung gegen `training_limits.areas`.

**Folge:** Plan-Merkmale heißen heute zugleich „wählbar“ **und** „wird vom Generator vorgeschlagen“. Nach dem Import würde z. B. der Pflichtbaustein *Drücken* über 29 statt 6 Übungen rotieren, darunter Langhantel-Bankdrücken; *Beine – Hüfte* über 13 statt 4, darunter Kreuzheben. Auch für „neu“-Einsteiger, denn die Erfahrung filtert keine Übungen. Welche Übung kommt, hängt an der UUID-Reihenfolge – also praktisch zufällig.

**Bestehende Pläne:** bleiben unverändert. Positionen speichern `exerciseId`/`modelId`; nichts wird neu generiert. Ändern würden sich neue Pläne, Neu-Generieren und die Tauschliste.

**Generator-Bestandstest** (`trainingsplan-generator.bestand.json`): läuft gegen den festen Test-`KATALOG` in `trainingsplan-generator.test.ts`, nicht gegen `gymtavo.json`. Er bleibt grün, sagt über die echte Auswahl aber nichts. `gymtavo-katalog.test.ts` prüft gegen die echte Datei: Pflichtbausteine `druecken`, `ziehen`, `beine_knie` nie `isolation`, Cardio ohne Bereiche.

## 2. Regeln der Verschlagwortung (abgeleitet aus den 46 vorhandenen)

- Drücken/Ziehen (Brust, Schulterpresse, Rudern, Latzug) → `[schulter]`.
- Arme → `[ellenbogen_handgelenk]`; Seitheben/Reverse Fly → `[schulter]`.
- Kniestreckung/-beugung (Presse, Squat, Beinstrecker, Beinbeuger) → `[knie]`; Ab-/Adduktion → `[huefte]`; Hüftstrecken/Hip Thrust → `[huefte, unterer_ruecken]`; Waden → `[]`.
- **Neu, wo das Vorbild nichts sagt** (zum Prüfen): Im Zweifel ein Bereich **mehr**. Ein zusätzlicher Bereich schließt bei „meiden“ nur zusätzlich aus, ein fehlender lässt eine belastende Übung durch.
  - Ohne Stütze vorgebeugt oder stehend mit Last (Langhantelrudern, vorgebeugte Flys, stehendes Drücken) → `+ unterer_ruecken`.
  - Langhantel mit fixiertem Griff, Dips, enger Griff, Untergriff-Klimmzug, schwere Shrugs → `+ ellenbogen_handgelenk`.
  - Arme über Kopf / hinter dem Körper (Überkopf-Trizeps, Schrägbankcurl, Holzhacken) → `+ schulter`.
  - Freie Kniebeugen und Ausfallschritte → `[knie, huefte]`; mit Stange auf dem Rücken `+ unterer_ruecken, schulter`; Frontkniebeuge `+ unterer_ruecken, ellenbogen_handgelenk`.
  - Kreuzheben (klassisch, Sumo) → `[huefte, unterer_ruecken, knie]`.

## 3. Entscheidungen für Tim

**E1 – Brust- und Lat-Isolation (10 Übungen: Butterfly, Flys, Pullover, gestrecktes Armziehen).** Kein passender Baustein: *Drücken* und *Ziehen* sind laut Spec und Test nur Mehrgelenk, die Ergänzungsbausteine sind Schulter/Arme/Rumpf/Beine.
- (a) *Empfehlung:* `druecken`/`ziehen` mit `typ: isolation`. Dazu Generator-Änderung: Pflichtplätze von `druecken`, `ziehen`, `beine_knie` nehmen nur `mehrgelenk`; Isolation kommt nur über Fokus und freie Wahl. Katalogtest entsprechend anpassen. Wiederholungen/Pause stimmen dann (Isolation 10–15).
- (b) Neuer Baustein (z. B. `brust_ergaenzung`): Domain, DB-Check `exercises_plan_baustein_check`, Labels in App. Größer.
- (c) Als `mehrgelenk` eintragen: falsche Vorgaben (Aufwärmsatz, Pause, 8–12). Nicht empfohlen.

**E2 – Farmer’s Walk** (`volume_kind: seconds`). Planpositionen außer Cardio rechnen in Wiederholungen. Vorschlag: `rumpf/isolation [ellenbogen_handgelenk, unterer_ruecken]` nur, wenn eine Sekunden-Position außerhalb von Cardio funktioniert – sonst vorerst **ohne** Plan-Merkmale lassen (dann nicht frei wählbar).

**E3 – Wählbar vs. vorgeschlagen.** Mit dem Import schlägt der Generator auch Langhantel-Kniebeuge, Kreuzheben, Bulgarian Split Squat usw. vor (Abschnitt 1).
- (a) *Empfehlung:* Zusatzfeld `plan.vorschlag` (Default `true`; `false` = nur frei wählbar/tauschbar, kein Generator-Kandidat). `ladeKandidaten` filtert für den Generator, Tauschliste und Server-Check bleiben bei allen. Braucht Spalte + Import + Kandidatenfilter, eigener kleiner PR vor dem Katalog-Import. Vorschlag für `false`: alle Langhantel- und SZ-Übungen, freie Kniebeugen/Ausfallschritte/Step-ups, Kurzhantel-RDL, Pull-through, Farmer’s Walk.
- (b) Akzeptieren, dass der Generator breiter rotiert.
- (c) Nur Gerät-/Kabelübungen verschlagworten, Freihanteln später.

## 4. Vorschlag je Übung (116)

Hauptmuskeln aus `muscles[role=primary]`. Gerätegruppe aus `equipment[].group`. Begründung „wie X“ = gleiche Belastung wie die schon verschlagwortete Übung X.

### druecken (16)

| Übung | Name | Hauptmuskeln | Gerätegruppe | typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `assisted_dip` | Dips mit Gegengewicht | triceps | geraete | mehrgelenk | schulter, ellenbogen_handgelenk | tiefe Schulterstreckung, Stütz auf den Handgelenken |
| `seated_dip_machine` | Trizepsdrücken am Sitz-Dip-Gerät | triceps | geraete | mehrgelenk | schulter, ellenbogen_handgelenk | Dip-Bewegung, Ellenbogen streckt unter Last |
| `chest_press_single` | Brustpresse – einarmig | pectorals | geraete | mehrgelenk | schulter | wie Brustpresse |
| `cable_chest_press_single` | Brustdrücken am Kabel – einarmig | pectorals | kabelzug | mehrgelenk | schulter | wie Kabel-Brustdrücken |
| `db_incline_press` | Kurzhantel-Schrägbankdrücken | pectorals | freihantel | mehrgelenk | schulter | wie Kurzhantel-Bankdrücken |
| `db_shoulder_press_seated` | Kurzhantel-Schulterdrücken – sitzend | deltoid_anterior, deltoid_lateral | freihantel | mehrgelenk | schulter | wie Schulterpresse |
| `cable_bench_press` | Kabel-Bankdrücken – Flachbank | pectorals | kabelzug | mehrgelenk | schulter | wie Brustpresse |
| `cable_incline_press` | Kabel-Schrägbankdrücken | pectorals | kabelzug | mehrgelenk | schulter | wie Schrägbrustpresse |
| `cable_shoulder_press` | Schulterdrücken am Kabel – stehend | deltoid_anterior, deltoid_lateral | kabelzug | mehrgelenk | schulter | wie Schulterpresse |
| `db_arnold_press` | Arnold Press – sitzend | deltoid_anterior, deltoid_lateral | freihantel | mehrgelenk | schulter | Rotation im Schultergelenk |
| `db_bench_neutral` | Kurzhantel-Bankdrücken – Neutralgriff | pectorals | freihantel | mehrgelenk | schulter | wie Kurzhantel-Bankdrücken |
| `db_press_standing` | Kurzhantel-Schulterdrücken – stehend | deltoid_anterior, deltoid_lateral | freihantel | mehrgelenk | schulter, unterer_ruecken | stehend über Kopf: Lendenwirbelsäule stabilisiert |
| `bb_bench` | Langhantel-Bankdrücken | pectorals | freihantel | mehrgelenk | schulter, ellenbogen_handgelenk | Stange fixiert die Handgelenke, hohe Last |
| `bb_incline` | Langhantel-Schrägbankdrücken | pectorals | freihantel | mehrgelenk | schulter, ellenbogen_handgelenk | wie Langhantel-Bankdrücken |
| `bb_close_bench` | Enges Langhantel-Bankdrücken | triceps, pectorals | freihantel | mehrgelenk | schulter, ellenbogen_handgelenk | enger Griff: Ellenbogen und Handgelenk stark belastet |
| `bb_seated_press` | Langhantel-Schulterdrücken – sitzend | deltoid_anterior, deltoid_lateral | freihantel | mehrgelenk | schulter, ellenbogen_handgelenk | Stange über Kopf, Handgelenke fixiert |

### ziehen (19)

| Übung | Name | Hauptmuskeln | Gerätegruppe | typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `row_machine_pronated` | Rudern am Gerät – Obergriff | upper_back | geraete | mehrgelenk | schulter | wie Rudern am Gerät |
| `lat_machine_pronated` | Latziehen an der Hebelmaschine | lats | geraete | mehrgelenk | schulter | wie Latzug |
| `assisted_pullup` | Klimmzug mit Gegengewicht – Obergriff | lats | geraete | mehrgelenk | schulter | Arme über Kopf, wie Latzug |
| `lat_pulldown_pronated` | Latzug · Obergriff | lats | geraete/kabelzug | mehrgelenk | schulter | wie Latzug |
| `lat_pulldown_supinated` | Latzug – Untergriff | lats | geraete | mehrgelenk | schulter | wie Latzug |
| `cable_row_wide` | Kabelrudern – breiter Obergriff | upper_back | geraete | mehrgelenk | schulter | wie Kabelrudern |
| `cable_row_single` | Kabelrudern – einarmig, sitzend | lats, upper_back | geraete | mehrgelenk | schulter | wie Kabelrudern |
| `row_machine_single` | Rudern am Gerät – einarmig | lats, upper_back | geraete | mehrgelenk | schulter | wie Rudern am Gerät |
| `cable_lat_single_kneeling` | Latzug am Kabel – einarmig, kniend | lats | kabelzug | mehrgelenk | schulter | wie Latzug |
| `db_row_supported` | Kurzhantelrudern – einarmig, abgestützt | lats, upper_back | freihantel | mehrgelenk | schulter | abgestützt, Rücken entlastet |
| `cable_incline_row` | Kabelrudern – brustgestützt auf Schrägbank | lats, upper_back | kabelzug | mehrgelenk | schulter | brustgestützt, wie Kurzhantelrudern brustgestützt |
| `cable_high_row_kneeling` | Kabel-High-Row – kniend | lats, upper_back | kabelzug | mehrgelenk | schulter | wie High Row |
| `cable_row_standing_v` | Kabelrudern – stehend mit V-Griff | lats, upper_back | kabelzug | mehrgelenk | schulter, unterer_ruecken | stehend ohne Stütze: Rumpf hält |
| `cable_row_rope` | Kabelrudern – sitzend mit Seil | lats, upper_back | kabelzug | mehrgelenk | schulter | wie Kabelrudern |
| `db_row_bent` | Kurzhantelrudern – beidarmig vorgebeugt | lats, upper_back | freihantel | mehrgelenk | schulter, unterer_ruecken | vorgebeugt ohne Stütze: Lendenwirbelsäule hält |
| `bb_row_over` | Langhantelrudern – Obergriff | lats, upper_back | freihantel | mehrgelenk | schulter, unterer_ruecken | vorgebeugt ohne Stütze |
| `bb_row_under` | Langhantelrudern – Untergriff | lats, upper_back | freihantel | mehrgelenk | schulter, unterer_ruecken, ellenbogen_handgelenk | vorgebeugt; Untergriff belastet Ellenbogen |
| `assisted_pullup_neutral` | Klimmzug mit Gegengewicht – Neutralgriff | lats | geraete | mehrgelenk | schulter | wie Klimmzug |
| `assisted_pullup_supinated` | Klimmzug mit Gegengewicht – Untergriff | lats | geraete | mehrgelenk | schulter, ellenbogen_handgelenk | Untergriff belastet den Ellenbogen (Bizepssehne) |

### schulter (12)

| Übung | Name | Hauptmuskeln | Gerätegruppe | typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `cable_face_pull` | Face Pull am Seil | deltoid_posterior, upper_back | kabelzug | isolation | schulter | Außenrotation unter Last |
| `cable_reverse_fly_standing` | Reverse Fly am Kabel – stehend | deltoid_posterior | kabelzug | isolation | schulter | wie Reverse Butterfly |
| `cable_front_raise_bar` | Frontheben am Kabel – Stange | deltoid_anterior | kabelzug | isolation | schulter | Arm vor dem Körper bis Schulterhöhe |
| `cable_shoulder_external_rotation` | Schulter-Außenrotation am Kabel | rotator_cuff | kabelzug | isolation | schulter | Rotatorenmanschette direkt |
| `cable_shoulder_internal_rotation` | Schulter-Innenrotation am Kabel | rotator_cuff | kabelzug | isolation | schulter | Rotatorenmanschette direkt |
| `db_lateral_raise` | Kurzhantel-Seitheben | deltoid_lateral | freihantel | isolation | schulter | wie Seitheben |
| `db_front_raise` | Kurzhantel-Frontheben | deltoid_anterior | freihantel | isolation | schulter | wie Frontheben |
| `db_reverse_fly` | Kurzhantel-Reverse-Flys – vorgebeugt | deltoid_posterior | freihantel | isolation | schulter, unterer_ruecken | vorgebeugt ohne Stütze |
| `cable_shrug` | Schulterheben am Kabel | upper_back | kabelzug | isolation | schulter | Schultergürtel; Nacken |
| `db_shrug` | Kurzhantel-Schulterheben | upper_back | freihantel | isolation | schulter, ellenbogen_handgelenk | Schultergürtel; schwere Hanteln im Griff |
| `db_lateral_seated` | Kurzhantel-Seitheben – sitzend | deltoid_lateral | freihantel | isolation | schulter | wie Seitheben |
| `bb_shrug` | Langhantel-Schulterheben | upper_back | freihantel | isolation | schulter, ellenbogen_handgelenk | Schultergürtel; schwere Stange im Griff |

### arme (29)

| Übung | Name | Hauptmuskeln | Gerätegruppe | typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `triceps_pushdown_bar` | Trizepsdrücken – Stange | triceps | kabelzug | isolation | ellenbogen_handgelenk | wie Trizepsdrücken |
| `cable_triceps_overhead` | Trizepsstrecken über Kopf – Seil | triceps | kabelzug | isolation | ellenbogen_handgelenk, schulter | Arme über Kopf: Schulter in Endstellung |
| `cable_hammer_curl` | Hammercurl am Kabel – Seil | biceps, forearms | kabelzug | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `cable_high_curl` | Hoher Bizepscurl am Kabel – beidarmig | biceps | kabelzug | isolation | ellenbogen_handgelenk, schulter | Arme seitlich auf Schulterhöhe |
| `cable_triceps_overhead_single` | Trizepsstrecken über Kopf am Kabel – einarmig | triceps | kabelzug | isolation | ellenbogen_handgelenk, schulter | über Kopf |
| `db_curl_standing` | Kurzhantel-Bizepscurl – stehend | biceps | freihantel | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `db_hammer_curl` | Kurzhantel-Hammercurl | biceps, forearms | freihantel | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `db_incline_curl` | Kurzhantel-Schrägbankcurl | biceps | freihantel | isolation | ellenbogen_handgelenk, schulter | Arm hinter dem Körper: vordere Schulter gedehnt |
| `db_triceps_overhead` | Trizepsstrecken über Kopf – eine Kurzhantel | triceps | freihantel | isolation | ellenbogen_handgelenk, schulter | über Kopf |
| `db_triceps_lying` | Liegendes Trizepsstrecken – Kurzhanteln | triceps | freihantel | isolation | ellenbogen_handgelenk | Ellenbogen unter Last gebeugt |
| `db_kickback_supported` | Kurzhantel-Kickback – einarmig, abgestützt | triceps | freihantel | isolation | ellenbogen_handgelenk | wie Trizepsdrücken |
| `cable_preacher_curl` | Scottcurl am Kabel | biceps | kabelzug | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `cable_concentration_curl` | Konzentrationscurl am Kabel | biceps | kabelzug | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `cable_reverse_curl` | Reverse Curl am Kabel | forearms, biceps | kabelzug | isolation | ellenbogen_handgelenk | Obergriff: Unterarm/Handgelenk stark |
| `cable_pushdown_supinated` | Trizepsdrücken am Kabel – Untergriff | triceps | kabelzug | isolation | ellenbogen_handgelenk | wie Trizepsdrücken |
| `cable_pushdown_vbar` | Trizepsdrücken am Kabel – V-Stange | triceps | kabelzug | isolation | ellenbogen_handgelenk | wie Trizepsdrücken |
| `cable_kickback` | Trizeps-Kickback am Kabel – einarmig | triceps | kabelzug | isolation | ellenbogen_handgelenk | wie Trizepsdrücken |
| `db_concentration` | Kurzhantel-Konzentrationscurl | biceps | freihantel | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `db_preacher` | Kurzhantel-Scottcurl – beidarmig | biceps | freihantel | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `db_spider` | Kurzhantel-Spider-Curl | biceps | freihantel | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `db_cross_hammer` | Cross-Body-Hammercurl – einseitig | biceps, forearms | freihantel | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `db_zottman` | Zottman Curl | biceps, forearms | freihantel | isolation | ellenbogen_handgelenk | Griffwechsel: Handgelenk/Unterarm |
| `db_reverse_curl` | Kurzhantel-Reverse-Curl | forearms, biceps | freihantel | isolation | ellenbogen_handgelenk | Obergriff: Unterarm/Handgelenk stark |
| `bb_curl` | Langhantel-Bizepscurl | biceps | freihantel | isolation | ellenbogen_handgelenk | Stange fixiert die Handgelenke |
| `ez_curl` | SZ-Bizepscurl | biceps | freihantel | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `ez_reverse` | SZ-Reverse-Curl | forearms, biceps | freihantel | isolation | ellenbogen_handgelenk | Obergriff |
| `ez_preacher` | SZ-Scottcurl – enger Griff | biceps | freihantel | isolation | ellenbogen_handgelenk | wie Bizepscurl |
| `ez_lying_triceps` | Liegendes SZ-Trizepsstrecken hinter den Kopf | triceps | freihantel | isolation | ellenbogen_handgelenk, schulter | hinter den Kopf: Schulter in Beugung |
| `ez_overhead` | SZ-Trizepsstrecken über Kopf – stehend | triceps | freihantel | isolation | ellenbogen_handgelenk, schulter | über Kopf |

### beine_knie (10)

| Übung | Name | Hauptmuskeln | Gerätegruppe | typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `leg_press_horizontal_single` | Horizontale Beinpresse – einbeinig | quads, glutes | geraete | mehrgelenk | knie | wie Beinpresse |
| `db_goblet_squat` | Goblet Squat – Kurzhantel | quads, glutes | freihantel | mehrgelenk | knie, huefte | freie tiefe Kniebeuge |
| `db_reverse_lunge` | Ausfallschritt rückwärts – Kurzhanteln | quads, glutes | freihantel | mehrgelenk | knie, huefte | einbeinig, Hüfte stabilisiert |
| `db_bulgarian_split_squat` | Bulgarian Split Squat – Kurzhanteln | quads, glutes | freihantel | mehrgelenk | knie, huefte | tiefe einbeinige Beugung, Hüftbeuger gedehnt |
| `db_forward_lunge` | Ausfallschritt vorwärts – Kurzhanteln | quads, glutes | freihantel | mehrgelenk | knie, huefte | Abbremsen nach vorn: Knie stärker als rückwärts |
| `db_step_up` | Step-up – Kurzhanteln | quads, glutes | freihantel | mehrgelenk | knie, huefte | einbeinig |
| `db_squat_sides` | Kniebeuge – zwei Kurzhanteln seitlich | quads, glutes | freihantel | mehrgelenk | knie, huefte | freie Kniebeuge |
| `bb_high_squat` | High-Bar-Kniebeuge | quads, glutes | freihantel | mehrgelenk | knie, huefte, unterer_ruecken, schulter | Stange auf dem Rücken: Wirbelsäule axial, Schulter in Außenrotation |
| `bb_front_squat` | Frontkniebeuge | quads, glutes | freihantel | mehrgelenk | knie, huefte, unterer_ruecken, ellenbogen_handgelenk | Frontablage belastet Handgelenke; Wirbelsäule axial |
| `bb_reverse_lunge` | Ausfallschritt rückwärts – Langhantel | quads, glutes | freihantel | mehrgelenk | knie, huefte, unterer_ruecken, schulter | Stange auf dem Rücken |

### beine_huefte (9)

| Übung | Name | Hauptmuskeln | Gerätegruppe | typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `leg_curl_standing` | Beinbeuger – stehend, einbeinig | hamstrings | geraete | isolation | knie | wie Beinbeuger |
| `cable_hip_extension` | Hüftstrecken am Kabel – einbeinig | glutes | kabelzug | isolation | huefte, unterer_ruecken | wie Hüftstrecken am Gerät |
| `leg_curl_seated_single` | Beinbeuger sitzend – einbeinig | hamstrings | geraete | isolation | knie | wie Beinbeuger |
| `cable_pull_through` | Pull-through am Kabel – Seil | glutes | kabelzug | mehrgelenk | huefte, unterer_ruecken | Hüftbeugung unter Last |
| `db_romanian_deadlift` | Rumänisches Kreuzheben – Kurzhanteln | hamstrings, glutes | freihantel | mehrgelenk | huefte, unterer_ruecken | Hüftbeugung mit langem Hebel |
| `bb_deadlift` | Kreuzheben – Langhantel | glutes, hamstrings | freihantel | mehrgelenk | huefte, unterer_ruecken, knie | Last vom Boden: Rücken, Hüfte, Knie |
| `bb_rdl` | Rumänisches Kreuzheben – Langhantel | hamstrings, glutes | freihantel | mehrgelenk | huefte, unterer_ruecken | wie RDL, höhere Last |
| `bb_sumo` | Sumo-Kreuzheben | glutes, quads | freihantel | mehrgelenk | huefte, unterer_ruecken, knie | weiter Stand: Hüfte und Knie stark |
| `bb_glute_bridge` | Glute Bridge – Langhantel | glutes | freihantel | mehrgelenk | huefte, unterer_ruecken | wie Hip Thrust |

### beine_ergaenzung (6)

| Übung | Name | Hauptmuskeln | Gerätegruppe | typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `leg_extension_single` | Beinstrecker – einbeinig | quads | geraete | isolation | knie | wie Beinstrecker |
| `calf_press_45` | Wadenpressen an der 45°-Beinpresse | calves | geraete | isolation | – | wie Wadenheben |
| `cable_hip_abduction` | Hüftabduktion am Kabel – einbeinig | abductors | kabelzug | isolation | huefte | wie Abduktorenmaschine |
| `cable_hip_adduction` | Hüftadduktion am Kabel – einbeinig | adductors | kabelzug | isolation | huefte | wie Adduktorenmaschine |
| `db_calf_raise` | Wadenheben stehend – Kurzhanteln | calves | freihantel | isolation | – | wie Wadenheben |
| `db_calf_seated` | Wadenheben sitzend – zwei Kurzhanteln | calves | freihantel | isolation | – | wie Wadenheben |

### rumpf (4)

| Übung | Name | Hauptmuskeln | Gerätegruppe | typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `cable_rotation` | Rumpfrotation am Kabel – Brusthöhe | obliques | kabelzug | isolation | unterer_ruecken | wie Rumpfrotation |
| `cable_chop_high_low` | Kabel-Holzhacken – oben nach unten | obliques | kabelzug | isolation | unterer_ruecken, schulter | Rotation; Arme über Kopf |
| `cable_lift_low_high` | Diagonales Kabelheben – unten nach oben | obliques | kabelzug | isolation | unterer_ruecken, schulter | Rotation; Arme enden über Kopf |
| `db_side_bend` | Seitneigen – eine Kurzhantel | obliques | freihantel | isolation | unterer_ruecken | Seitneigung der Lendenwirbelsäule |

### Offen – Vorschlag hängt an Entscheidung E1/E2 (11)

| Übung | Name | Hauptmuskeln | Gerätegruppe | Vorschlag baustein/typ | bereiche | Begründung Bereiche |
|---|---|---|---|---|---|---|
| `pec_deck_handles` | Butterfly – Handgriffe | pectorals | geraete | druecken/isolation | schulter | Arm in Abspreizung, vordere Schulter gedehnt |
| `pullover_machine` | Überzüge am Gerät | lats | geraete | ziehen/isolation | schulter | Arm über Kopf |
| `cable_straight_arm_pulldown` | Gestrecktes Armziehen am Kabel | lats | kabelzug | ziehen/isolation | schulter | Arm über Kopf |
| `cable_fly_mid` | Butterfly am Kabel – Brusthöhe | pectorals | kabelzug | druecken/isolation | schulter | wie Butterfly |
| `db_flat_fly` | Kurzhantel-Flys – Flachbank | pectorals | freihantel | druecken/isolation | schulter | langer Hebel, Schulter in Dehnung |
| `cable_decline_fly` | Kabel-Flys – Negativbank | pectorals | kabelzug | druecken/isolation | schulter | wie Flys |
| `cable_low_fly` | Kabel-Flys – von unten nach oben | pectorals | kabelzug | druecken/isolation | schulter | wie Flys |
| `cable_incline_fly` | Kabel-Flys – Schrägbank | pectorals | kabelzug | druecken/isolation | schulter | wie Flys |
| `db_incline_fly` | Kurzhantel-Flys – Schrägbank | pectorals | freihantel | druecken/isolation | schulter | wie Flys |
| `db_pullover` | Kurzhantel-Pullover – eine Hantel | pectorals, lats | freihantel | ziehen/isolation | schulter | Arm hinter dem Kopf, große Dehnung |
| `db_farmers_walk` | Farmer’s Walk – Kurzhanteln | forearms | freihantel | rumpf/isolation | ellenbogen_handgelenk, unterer_ruecken | schwere Last im Griff; Wirbelsäule axial |

## 5. Danach (nach Freigabe)

1. Gegebenenfalls E1/E3 umsetzen (Generator-Filter, Feld `vorschlag`), mit Tests.
2. `plan`-Blöcke in `catalog/gymtavo.json` übernehmen (Mapping liegt vorbereitet vor), `pnpm --filter @fitretro/domain test`.
3. PR. `catalog:import` gegen Prod nur mit Tims ausdrücklicher Freigabe.
