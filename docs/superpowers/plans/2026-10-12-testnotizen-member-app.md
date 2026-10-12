# Testnotizen 12.10. – Ein Kabelzug, Gerätekategorien im Training-Tab

## Kontext

- **Quelle:** Testsitzung `~/Downloads/2026-10-12-0725/sitzung.md`, iPhone14,4, iOS 26.6.2, Stand `36e1e98`, 5 Notizen.
- **Inhalt:** Alle betreffen „Gerät wählen“ im Training-Tab:
  - #1/#2: Die Kabelzug-Übungen sind auf vier Gerätetypen verteilt und sollen ein Gerät „Kabelzug“ werden.
  - #3: Die lange Liste bekommt Oberkategorien als Kacheln: Geräte, Freihantel, Kabelzug, Cardio.
  - #4: Kurz-, Lang- und SZ-Hantel stehen gemeinsam unter „Freihantel“.
  - #5: Eigengewicht, Kettlebell und Gummiband sind vorgemerkt und erscheinen erst, wenn sie Übungen haben.

**Vorgehen:**
- Ablauf nach Skill `finetuning`, für iOS übertragen wie in `2026-10-11-testnotizen-member-app-2.md`.
- Worktree `.claude/worktrees/testnotizen-1110b`, Branch `claude/testnotizen-1210-kategorien` von `master`.
- Je Etappe zuerst ein roter Test (Vitest, Swift Testing), dann die Umsetzung, dann ein Commit.
- Kommentare verweisen auf „(Testnotiz 12.10., #n)“.

**Befund vor dem Plan:**
- Der Katalog (`catalog/gymtavo.json`) hat vier Kabelzug-Typen mit zusammen 45 Übungen:
  - `high_cable` „Hoher Kabelzug“ (2)
  - `cable_adjustable` „Hoher Kabelzug + Seil“ (33)
  - `dual_cable` „Doppel-Kabelzug + zwei Einzelgriffe“ (4)
  - `dual_cable_station` „Doppelkabelzug mit zwei unabhängig belastbaren Rollen“ (6)
- Dazu kommen Latzugstation (2) und Tiefe Ruderstation (3).
- Eine Übung darf schon an mehreren Typen hängen: `equipment_model_exercises` ist eine Verknüpfungstabelle, `querPruefen` verlangt nur Eindeutigkeit je Typ.
- Der Import löscht nie (Spec 9.1). Ein Typ, der aus der Datei fällt, bliebe in der App stehen.
- Prod (nur lesend, 12.10.): An den vier Typen hängen 2 Sätze und 18 Fortschrittsvorschläge, kein Studiomodell (`catalog_model_id`). Vier Herstellerprodukte zeigen auf sie.
- `category` (kraft/cardio) treibt im Portal die Einheiten (`einheitenFuer`) und darf laut `kategorie-waechter.test.ts` nicht in die Regel. Die neue Einteilung ist deshalb ein eigenes Feld.

### Rückfragen (beantwortet: „bei allen Empfehlungen mitgehen“)

- **A, #1/#2:**
  - Die vier Kabelzug-Typen werden ein Typ „Kabelzug“. Basis ist `dual_cable_station`, damit Schlüssel, Foto und Historie bleiben.
  - „Latzug · Obergriff“ (`lat_pulldown_pronated`) wandert zur Latzugstation, weil die Übung das Oberschenkelpolster braucht.
  - Latzugstation und Ruderstation bleiben eigene Geräte unter „Geräte“.
- **B, #1:** „Kabelzug einzeln“ kommt später. Mit einem Kabelzug führt die Kategorie direkt in die Übungen (#3).
- **C, #3–#5, Datenmodell:**
  - Neues Feld `group` je Gymtavo-Typ im Katalog. Werte: `geraete`, `freihantel`, `kabelzug`, `cardio`, `eigengewicht`, `kettlebell`, `gummiband`.
  - In der Datenbank heißt die Spalte `equipment_group`, denn `group` ist ein SQL-Schlüsselwort.
  - `category` bleibt für die Einheiten zuständig.
  - Studiogeräte erben die Gruppe ihres zugeordneten Gymtavo-Typs. Ohne Zuordnung gilt `cardio` bei Cardio, sonst `geraete`.
  - Abgelöste Typen bekommen `retired: true` (Spalte `retired`). Sie werden in Listen ausgeblendet, sind aber weiter auflösbar, damit alte Blöcke und Sätze lesbar bleiben.
  - Die Übungs-IDs bleiben gleich, der Fortschritt je Übung also auch.
- **D, #3/#4, Navigation:**
  - Oben bleibt „Zuletzt bei dir“. Darunter stehen die Kategorie-Kacheln in fester Reihenfolge.
  - Leere Kategorien fehlen.
  - Hat eine Kategorie genau ein Gerät, öffnet der Tipp dessen Übungen. Sonst kommt eine Liste der Kategorie.
  - Die Suche bleibt eine flache Liste über alles.

## Etappe 1 – Katalogschema, Migration, Import (#1, #3, #5)

- **Ursache:** Der Katalog kennt nur `category`, und es gibt keinen Weg, einen Typ abzulösen.
- **Domain:**
  - `GROUPS` steht neben `CATEGORIES` (`belastung.ts`).
  - `geraetetypSchema` (`katalog-datei.ts:77`) bekommt `group: z.enum(GROUPS)` als Pflichtfeld und `retired: z.boolean().default(false)`.
  - Neue Querprüfungen in `querPruefen`:
    - `group: cardio` genau dann, wenn `category: cardio`.
    - Ein Produkt darf auf keinen abgelösten Typ zeigen.
    - Eine Übung, die nur an abgelösten Typen hängt, gilt als „hängt an keinem Gerätetyp“.
- **Migration `0051_geraetegruppe.sql`:**
  - `equipment_models.equipment_group text` mit Check auf die sieben Werte. Die Spalte ist nullbar, denn Studiomodelle haben keine eigene Gruppe.
  - `retired boolean not null default false`.
- **Import:** Beide Felder kommen in `GeraetetypZeile`, `GERAETETYP_FELDER`, den Zeilenbau (`katalog-plan.ts`) und den Ist-Select (`katalog-import.ts:73`).
- **Test zuerst:**
  - `katalog-datei.test.ts`: Fehlt `group`, gibt es einen Fehler. Es gelten Cardio⇔cardio, „Produkt auf abgelösten Typ“ und „Übung nur an abgelöstem Typ“. `retired` ist ohne Angabe `false`.
  - `katalog-plan.test.ts`: Eine geänderte Gruppe und `retired` erscheinen als geänderte Felder.
  - `tests/integration/katalog-import.test.ts`: Der Import schreibt beide Spalten, ein zweiter Lauf ist unverändert.

## Etappe 2 – Bootstrap und Portal liefern Gruppe und Ablösung

- **Bootstrap:**
  - `MODELL_SPALTEN` (`bootstrap.ts:147`) und `Geraetemodell` bekommen `equipmentGroup` und `retired`.
  - Die Katalogtypen bleiben vollständig, auch die abgelösten. Gefiltert wird erst in der Liste der App, damit `station(schluessel:)` alte `typ:`-Blöcke weiter auflöst.
- **Portal:**
  - `listCatalogTypes` liefert `retired` und `group` mit.
  - Die Auswahlfelder für einen Gymtavo-Typ blenden abgelöste Typen aus. Ein schon zugeordneter abgelöster Typ bleibt sichtbar.
  - Lookups per id (`einrichten/actions.ts:164`) bleiben ungefiltert.
- **Abweichung bei der Umsetzung:** Die Gruppe eines Studiogeräts löst der Server auf (`gruppeDesModells` in `bootstrap.ts`), nicht die App. So mischt er schon die Übungen, und die App muss die Regel nicht kennen. Die App fällt nur ohne oder bei unbekannter Gruppe auf die Kategorie zurück.
- **Test zuerst:**
  - `bootstrap.test.ts`: `gruppeDesModells` (eigene vor geerbter Gruppe, Rückfall über die Kategorie).
  - `domain-bootstrap-katalog.test.ts`: Ein Typ liefert `equipmentGroup` und `retired`.
  - Vitest am Typ-Auswahlfeld: Ein abgelöster Typ fehlt in der Auswahl, außer er ist der aktuelle.

## Etappe 3 – Katalog: ein Kabelzug, Gruppen für alle Typen (#1, #2, #4)

- **Änderung in `catalog/gymtavo.json`:**
  - `dual_cable_station` heißt künftig „Kabelzug“ und trägt alle Übungen der vier Kabelzug-Typen außer `lat_pulldown_pronated`, also 44.
  - Er bekommt die Einstellung „Rollenhöhe“.
  - `lat_pulldown_pronated` kommt an `cable_lat` (Latzugstation). Die Latzugstation bekommt „Oberschenkelpolster“.
  - `high_cable`, `cable_adjustable` und `dual_cable` erhalten `retired: true`.
  - Die vier Produkte zeigen nur noch auf aktive Typen: abgelöste Kabeltypen werden zu `dual_cable_station`, doppelte Einträge fallen weg.
  - „Benötigte Ausstattung“ in den Beschreibungen der verschobenen Übungen nennt „Kabelzug“ bzw. „Latzugstation“.
  - Gruppen:
    - Hanteln (`dumbbell`, `barbell`, `ez_bar`) sind `freihantel`.
    - Die vier Kabelzug-Typen sind `kabelzug`.
    - Die neun Cardio-Typen sind `cardio`.
    - Der Rest ist `geraete`.
- **Test zuerst:** Neuer Vitest `catalog/gymtavo.test.ts` (bzw. in `packages/domain`) gegen die echte Datei:
  - `pruefeKatalog` ist grün.
  - Es gibt genau einen aktiven Typ der Gruppe `kabelzug`.
  - Er enthält jede Übung der abgelösten Kabeltypen außer dem Latzug-Obergriff.
  - Kein aktiver Typ heißt wie ein abgelöster.

## Etappe 4 – App: Gruppe je Station, Kategorien, Ziel des Tipps (#3, #4, #5)

- **DTO:**
  - `EquipmentModel` und `Catalog.EquipmentType` bekommen `equipmentGroup: Geraetegruppe?` und `retired: Bool` (Vorgabe `false`, `decodeIfPresent`), damit alte Caches dekodieren.
  - `Station.init(typ:)` reicht beides durch.
- **`Geraetegruppe`** (neu, `Workout/Geraetegruppe.swift`): Sie hat die sieben Fälle in Anzeigereihenfolge, `titel` und `symbol`. Die reine Funktion `fuer(station:katalog:)` regelt die Herkunft:
  - die eigene Gruppe, sonst die des zugeordneten Gymtavo-Typs (`catalogModelId`)
  - sonst `cardio` bei Cardio, sonst `geraete`
- **`GeraeteAuswahl`:**
  - `typen()` lässt abgelöste Typen weg.
  - `Gruppen.kraft` und `.cardio` weichen `kategorien: [Kategorie]`. Jede `Kategorie` hat `gruppe` und `eintraege`, gezählt wird ohne die Einträge unter „Zuletzt“. Leere Gruppen fehlen.
  - Neu ist `ziel(kategorie) -> .station(Station) | .liste`.
  - Neu ist ein Filter `gruppen(..., gruppe:)` für die Kategorieliste. Er sucht dann nur in der Gruppe.
- **Test zuerst** (`GeraeteAuswahlTests`, neu `GeraetegruppeTests`):
  - Kategorien stehen in fester Reihenfolge, leere fehlen.
  - Ein abgelöster Typ fehlt in der Liste, `station(schluessel:)` löst ihn weiter auf.
  - Die Gruppe am Studiogerät kommt über `catalogModelId`, der Rückfall über die Kategorie.
  - Eine Kategorie mit einem Gerät liefert `.station`, mit mehreren `.liste`.
  - Ein Kategoriefilter mit Suchtext findet nur Geräte der Gruppe.

## Etappe 5 – App: Kacheln und Kategorieliste (#3, #4)

- **Wurzel:** `GeraeteAuswahlView` zeigt statt „KRAFT · A–Z“ und „CARDIO · A–Z“ ein zweispaltiges Raster `KATEGORIEN`.
  - Jede Kachel hat Symbol, Titel und Zahl („12 Geräte“; bei einem Gerät „44 Übungen“).
  - Kachelfläche `surface` mit Rand `line`, wie die Zeilen. Kein Akzent, denn die Hauptaktion bleiben QR/NFC.
  - Mindesthöhe 88 pt.
- **Route:** `GeraetRoute.kategorie(Geraetegruppe)` in `TrainingRootView.ziel`. Sie zeigt `GeraeteAuswahlView` im Modus Kategorie: Titel ist der Gruppenname, ohne Kopfinhalt, ohne Kacheln, Suche nur in der Gruppe.
- **Tipp:**
  - Bei `.station` folgt derselbe Weg wie ein Tipp auf eine Zeile (`waehle(_:)`).
  - Bei `.liste` wird `.kategorie(g)` gepusht.
- **Prüfung:** Reine Darstellung, deshalb ein Sichtcheck im Simulator gegen das lokale Backend mit importiertem Katalog. Zu prüfen:
  - Wurzel mit Kacheln
  - Freihantel mit drei Hanteln
  - Kabelzug direkt mit 44 Übungen
  - Cardio-Liste
  - Suche „Kabel“ ohne die abgelösten Typen

## Nach dem Merge (nur auf Freigabe)

- Migration 0051 nach Prod (`db push --linked`).
- Danach `pnpm catalog:import --dry-run` und `--ja` gegen Prod.
- **Reihenfolge:** Die App-Version mit den Kacheln liest `equipmentGroup` optional. Ohne Migration zeigt sie alles unter „Geräte“ bzw. „Cardio“, ohne Absturz.

## Geprüft

Etappen 1–5 umgesetzt in 5 Commits (`1f5b0ee` bis `5474564`).
- Etappe 1 enthält schon die Gruppen aller 55 Typen, sonst wäre `gymtavo.json` zwischen den Commits ungültig.
- Etappe 4 und 5 sind ein Commit, weil die Ansicht ohne die neue Logik nicht kompiliert.

- **Rot vor Grün:**
  - Schema, Plan, `gruppeDesModells`, Portal (`typVorlagen`, `GymtavoTypFeld`), Katalogtest und die iOS-Suites liefen nachweislich zuerst rot.
  - Die beiden Integrationsfälle (Import, Bootstrap) entstanden mit der Umsetzung, ein Rot-Lauf fehlt.
- **Domain/Web:**
  - `pnpm typecheck` grün, `npx tsc --noEmit` (Wurzel, inkl. e2e) grün.
  - Vitest: domain 324, web 306 grün.
  - Produktionsbau grün.
- **Integration:** Der Gesamtlauf von `pnpm test:integration` meldete 18 Fehler in 12 Dateien, darunter Kurse und Einladungen, die dieser Branch nicht berührt. Alle 12 Dateien laufen einzeln grün (190 Tests): Umgebung, geteilte lokale DB.
- **iOS:** `xcodebuild test` mit dem ganzen Satz grün, 1072 Tests in 109 Suites.
- **E2E:** Lokal nicht gelaufen, das übernimmt die CI. Die E2E-Tests legen eigene Typen an und kennen die alten Kabelzug-Namen nicht.
- **Lokaler Import:** aus einer Kopie ohne Produkte, damit die lokalen Testfotos bleiben. Ergebnis: 55 Typen, 2 Einstellungen, 45 Übungen, 39 Verknüpfungen, 39 Videos. Der Kabelzug hat 44 Übungen, die Latzugstation 3.
- **Sichtcheck im Simulator** (Wegwerf-UI-Test gegen das lokale Backend, Freies Training, frisches Mitglied):
  - #3: Unter „KATEGORIEN“ stehen vier Kacheln im Raster: Geräte, Freihantel, Kabelzug, Cardio. Eigengewicht, Kettlebell und Gummiband fehlen, wie geplant (#5).
  - #4: Freihantel zeigt Kurzhantel, Langhantel und SZ-Hantel.
  - #1/#2: Die Kachel Kabelzug zeigt „44 Übungen“ und öffnet gleich die Geräteseite „KABELZUG“ mit allen Übungen samt Video.
  - Die Suche „Kabel“ zeigt keinen der abgelösten Typen.
  - Die lokalen Zahlen (407 Geräte, 22 Cardio) kommen von Testresten anderer Suites in der geteilten DB.
  - Ein Rest des neuen Bootstrap-Integrationstests stand als zweites Gerät im Kabelzug. Behoben: Der Test legt seinen Typ jetzt abgelöst an (`5474564`).
- **Am Gerät noch ansehen:**
  - Die Kacheln auf dem 13 mini, besonders die Höhe von 88 pt und die Symbole.
  - Die Kabelzug-Seite mit 44 Übungen: Lässt sie sich gut scrollen, oder braucht sie eine Unterteilung (z. B. nach Muskel)?

## Für Prod offen (nur auf Freigabe)

- Migration 0051 mit `db push --linked`, danach `pnpm catalog:import --dry-run` gegen Prod.
- **Achtung Fotos:** Die Repo-Datei setzt die 69 Herstellerfotos, die in Prod nur testweise auf `cleared` stehen, beim Import auf `pending` zurück (Rechteentzug). Ein Import nur für den Kabelzug geht ohne diesen Nebeneffekt aus einer Kopie ohne `products`, wie beim lokalen Import. Die vier Produkt-Typ-Zuordnungen auf abgelöste Typen blieben dann bestehen. Sie sind unschädlich, weil das Portal abgelöste Typen nicht anbietet.
