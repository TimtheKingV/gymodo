# Zusammenführung — Phase 2.3/2.4 und Phase 3

> **Für agentische Ausführung:** Schritt für Schritt, die Reihenfolge ist nicht wählbar. Checkboxen (`- [ ]`) zum Mitführen.

**Ziel:** Zwei fertige Bauabschnitte, die vom selben Punkt abzweigen und dieselbe lokale Datenbank teilen, zu einem `master` zusammenführen — ohne dass einer der beiden etwas verliert.

**Warum das nicht trivial ist:** beide fassen das Trainerportal an. Phase 3 hat die Schreibtischseiten in eine Route-Gruppe verschoben; Phase 2.3/2.4 legt fünf neue Seiten genau dort an, wo die Gruppe jetzt greift. Git sieht das nicht — die Dateien sind neu, und neue Dateien kollidieren mit nichts.

---

## Ausgangslage

| | Commit | Commits über `master` | Zustand |
| --- | --- | --- | --- |
| `master` | `a52254a` | — | nur Dokumente über dem gemeinsamen Punkt |
| `worktree/calm-forest-3c59` | `05be485` | **24** | Arbeitsverzeichnis sauber |
| `phase3-einrichtung-am-geraet` | `a4e4057` | **15** | Arbeitsverzeichnis sauber |

Beide zweigen von `7580758` ab. `master` trägt darüber nur den Phase-3-Umsetzungsplan (`a52254a`, reine Dokumentation).

**Der Worktree bringt:** `0032_studio_einstellungen`, `0033_datenschutzgrenze`, `0034_studio_ueberblick`, die Einstellungsseite mit zwei Reitern, den Überblick als neue Wurzelseite, den Katalog nach `/modelle`, `getStudioOverview` in der Fachschicht, 871 Zeilen Tests — und die Anpassung der vier RLS-Tests an die Datenschutzgrenze.

**Phase 3 bringt:** den sechsschrittigen Gang durch die Halle, die Route-Gruppe `(schreibtisch)`, vier neue Fachschichtfunktionen, den Fix an `stripImageMetadata` und `bodySizeLimit`.

---

## Der Zustand der lokalen Datenbank

Er ist der Grund, warum diese Zusammenführung überhaupt aufgefallen ist.

| | |
| --- | --- |
| Migrationen in `supabase_migrations.schema_migrations` | **34** |
| Migrationsdateien auf `master` | **31** |
| `0032`, `0033` — Datei gegen Datenbank | identisch (auf dem Worktree-Branch) |
| `0034` — Datei gegen **Verzeichniseintrag** | **weichen ab**: Datei 8354 B, Eintrag 5482 B |
| `0034` — Datei gegen **lebende Funktion** | **identisch** (4180 Zeichen Rumpf, samt der Korrektur aus `0918448`) |

**Berichtigt am 3. September, nachdem Schritt 1.3 die Annahme widerlegt hat.** Der Verdacht war, die Datenbank trage die alte Fassung von `studio_overview`, weil `0918448 fix(db): die Mindestzahl haengt an den Erfassenden` die Migration nach dem Anwenden überarbeitet hat. Der Testlauf im Worktree war jedoch **vollständig grün (40 Dateien, 457 Tests)**, und die Gegenprobe an `pg_proc` zeigt: die Funktion ist auf dem Stand der Datei.

Veraltet ist allein die in `supabase_migrations.schema_migrations` **mitgeschriebene Anweisungsliste** — jemand hat die Funktion neu eingespielt, ohne dass der Eintrag nachgezogen wurde. Funktional folgenlos (`create or replace`), aber es heißt: **der Verzeichniseintrag ist kein verlässlicher Zeuge dafür, was in der Datenbank steht.** Das war der eigentliche Grund, warum die verschollenen Migrationen überhaupt rekonstruierbar waren — und zugleich der Grund, dem Text dort nicht blind zu glauben.

> **Kein `supabase db reset`, bevor der Worktree gemerged ist.** Solange `0032`–`0034` nur in der Datenbank stehen und nicht auf `master`, löscht ein Reset sie unwiederbringlich. Nach dem Merge ist er der sauberste Weg.

---

## Die Überschneidungen, vollständig

**Nach Dateiname überschneidet sich genau eine Datei:**

| Datei | Konflikt |
| --- | --- |
| `packages/domain/src/index.ts` | beide ergänzen die Exportliste — Vereinigungsmenge, kein inhaltlicher Widerspruch |

**Ändern/Umbenennen — Git löst das in aller Regel selbst, ist aber zu prüfen:**

| Der Worktree ändert | Phase 3 hat verschoben nach |
| --- | --- |
| `[studioId]/page.tsx` | `[studioId]/(schreibtisch)/page.tsx` |
| `[studioId]/leute/page.tsx` | `[studioId]/(schreibtisch)/leute/page.tsx` |
| `[studioId]/leute/LeuteActions.tsx` | `[studioId]/(schreibtisch)/leute/LeuteActions.tsx` |

**Neu angelegt und deshalb unsichtbar für Git — die eigentliche Arbeit:**

| Neue Datei aus dem Worktree | muss nach |
| --- | --- |
| `[studioId]/modelle/page.tsx` | `[studioId]/(schreibtisch)/modelle/page.tsx` |
| `[studioId]/einstellungen/page.tsx` | `[studioId]/(schreibtisch)/einstellungen/page.tsx` |
| `[studioId]/einstellungen/konto/page.tsx` | `.../(schreibtisch)/einstellungen/konto/page.tsx` |
| `[studioId]/einstellungen/Reiter.tsx` | `.../(schreibtisch)/einstellungen/Reiter.tsx` |
| `[studioId]/einstellungen/EinstellungenActions.tsx` | `.../(schreibtisch)/einstellungen/EinstellungenActions.tsx` |

**Bleiben, wo sie sind — kein Konflikt:** `[studioId]/Rail.tsx`, `portal/actions.ts`, `portal/portal.module.css`. Phase 3 hat sie nicht angefasst.

---

## Warum Merge und nicht Rebase

Der Repo-Verlauf kennt beides, aber hier spricht die Sachlage für Merge: ein Rebase spielt fünfzehn Phase-3-Commits gegen einen Stand ab, den sie nie gesehen haben — darunter die Verschiebung von acht Dateien. Jeder einzelne Konflikt wäre dann in einem Zwischenzustand zu lösen, in dem nichts läuft und nichts prüfbar ist.

Ein Merge löst dieselben Konflikte **einmal**, in einem Zustand, in dem Typecheck und Testlauf sofort etwas sagen.

**Reihenfolge:** der Worktree zuerst nach `master`, dann `master` in Phase 3. Der Worktree ist fertig, geprüft und älter; sein Zweig soll nicht die Kollision tragen, die der jüngere verursacht hat.

---

## Schritt 1: Den Worktree-Branch prüfen, bevor er nach master geht

Er gilt als fertig, aber er ist seit seinem letzten Lauf nicht gegen den heutigen Datenbankstand geprüft worden.

- [ ] **1.1** In den Worktree wechseln und den Stand bestätigen

```bash
cd C:/Users/bttm/.herdr/worktrees/Fitness-App/worktree-calm-forest-3c59
git status --short          # muss leer sein
git log --oneline -1        # 05be485 erwartet
```

- [ ] **1.2** Typecheck und Unit-Tests

```bash
pnpm typecheck && pnpm test
```

Erwartet: grün.

- [ ] **1.3** Integrationstests

```bash
pnpm test:integration
```

Erwartet: **vollständig grün.** Gemessen am 3. September: **40 Dateien, 457 Tests**, kein Fehlschlag — auch die vier RLS-Tests zur Datenschutzgrenze und die beiden Überblick-Dateien.

Schlägt etwas fehl, hier anhalten und klären. Nicht weitermergen.

- [ ] **1.4** Zurück ins Hauptverzeichnis

```bash
cd C:/Users/bttm/Documents/Fitness-App
```

---

## Schritt 2: Worktree nach master

- [ ] **2.1** Auf `master`, Stand prüfen

```bash
git checkout master
git status --short          # muss leer sein
```

- [ ] **2.2** Mergen

```bash
git merge --no-ff worktree/calm-forest-3c59
```

Erwartet: **konfliktfrei.** `master` trägt über dem gemeinsamen Punkt nur den Phase-3-Plan (`a52254a`), und den fasst der Worktree nicht an.

Kommt wider Erwarten ein Konflikt, ist die Annahme falsch — dann anhalten und die Lage neu ansehen.

- [ ] **2.3** Belegen, dass die Migrationen jetzt auf Platte liegen

```bash
ls supabase/migrations/*.sql | wc -l        # 34 erwartet
ls supabase/migrations/003{2,3,4}_*.sql
```

---

## Schritt 3: master in Phase 3 mergen

- [ ] **3.1** Auf den Phase-3-Branch

```bash
git checkout phase3-einrichtung-am-geraet
git merge --no-ff master
```

Erwartet: **ein Konflikt in `packages/domain/src/index.ts`**, dazu möglicherweise Meldungen zu den drei Ändern/Umbenennen-Paaren.

- [ ] **3.2** `packages/domain/src/index.ts` auflösen — Vereinigungsmenge

Beide Seiten ergänzen nur Exporte. Es gehören **alle** hinein: aus Phase 3 `tag-scan`, `nummern`, `listStudioExercises`/`StudioExercise`; aus dem Worktree die Einstellungen- und Überblick-Exporte. Danach:

```bash
grep -n "parseTagScan\|naechsteGeraeteNummer\|listStudioExercises\|getStudioOverview\|getStudioSettings" packages/domain/src/index.ts
```

Erwartet: jeder der fünf Namen genau einmal.

- [ ] **3.3** Die drei Ändern/Umbenennen-Paare nachsehen

Git legt sie meist richtig ab, aber nicht immer. Es darf **keine** dieser Dateien am alten Ort liegen:

```bash
ls "apps/web/app/portal/[studioId]/" 
```

Erwartet: nur `(schreibtisch)`, `Rail.tsx`, `catalog.ts`, `einrichten`. Taucht `page.tsx` oder `leute/` wieder auf, gehört der Inhalt nach `(schreibtisch)/` und die Kopie am alten Ort weg.

- [ ] **3.4** Den Merge abschließen

```bash
git add -A
git commit
```

---

## Schritt 4: Die fünf neuen Seiten in die Route-Gruppe einsortieren

Der Kern der Arbeit. Nach dem Merge liegen sie außerhalb — und damit ohne Hülle und ohne Rail.

- [ ] **4.1** Verschieben

```bash
cd "apps/web/app/portal/[studioId]"
git mv einstellungen "(schreibtisch)/einstellungen"
git mv modelle/page.tsx "(schreibtisch)/modelle/page.tsx"
cd C:/Users/bttm/Documents/Fitness-App
```

`modelle/` selbst existiert unter `(schreibtisch)` bereits (dort liegt `[modelId]/page.tsx`) — deshalb nur die Datei, nicht das Verzeichnis.

- [ ] **4.2** Die Importtiefe nachziehen

Jede Datei liegt eine Ebene tiefer. Genau diese Zeilen ändern sich:

| Datei unter `(schreibtisch)/` | alt → neu |
| --- | --- |
| `einstellungen/page.tsx` | `../../Form` → `../../../Form`; `../../actions` → `../../../actions`; `../../portal.module.css` → `../../../portal.module.css` |
| `einstellungen/EinstellungenActions.tsx` | dieselben drei |
| `einstellungen/Reiter.tsx` | `../../portal.module.css` → `../../../portal.module.css` |
| `einstellungen/konto/page.tsx` | `../../../portal.module.css` → `../../../../portal.module.css` |
| `modelle/page.tsx` | `../../Form` → `../../../Form`; `../../actions` → `../../../actions`; `../catalog` → `../../catalog`; `../../portal.module.css` → `../../../portal.module.css` |

`./Reiter`, `./EinstellungenActions`, `../Reiter` und `../EinstellungenActions` bleiben — sie zeigen innerhalb des mitverschobenen Verzeichnisses.

- [ ] **4.3** Prüfen, dass nichts übersehen wurde

```bash
grep -rn 'from "\.' "apps/web/app/portal/[studioId]/(schreibtisch)/einstellungen" \
                     "apps/web/app/portal/[studioId]/(schreibtisch)/modelle/page.tsx"
```

- [ ] **4.4** `Reiter.tsx` braucht **keine** Änderung an seiner Logik

Er vergleicht über `usePathname()`. Route-Gruppen erscheinen im Pfad nicht — `/portal/<id>/einstellungen` bleibt `/portal/<id>/einstellungen`. Das ist derselbe Grund, aus dem der ganze Umbau in Phase 3 keine URL verschoben hat.

- [ ] **4.5** Alte Typen wegräumen und übersetzen

```bash
rm -rf apps/web/.next/types
pnpm typecheck
```

`next typegen` legt die Routentypen neu an, löscht die alten aber nicht. Ohne das `rm` meldet der Typecheck `TS2307` auf Dateien, die es nicht mehr gibt — Müll von vorher, der wie ein kaputter Umbau aussieht.

- [ ] **4.6** Committen

```bash
git add -A
git commit -m "fix(web): Einstellungen und Modellliste in die Route-Gruppe (schreibtisch)"
```

---

## Schritt 5: Verzeichniseintrag und Platte in Übereinstimmung bringen

**Kein Reparaturschritt.** Nach der Berichtigung oben steht fest: das Schema ist in Ordnung, die Tests laufen. Es geht allein darum, dass der Verzeichniseintrag zu `0034` wieder das enthält, was in der Datei steht — damit der nächste, der ihn liest, nicht dieselbe falsche Fährte aufnimmt wie dieser Plan.

Jetzt — und keinen Schritt früher — ist ein Reset ungefährlich: alle 34 Migrationen liegen als Dateien vor.

- [ ] **5.1** Zurücksetzen und neu anwenden

```bash
supabase db reset
```

**Das leert die lokale Datenbank.** Was dabei verlorengeht, sind die Studios, Konten und Tags aus den Testläufen — kein Bestand, an dem etwas hängt. Gibt es doch lokale Daten, die zählen, vorher sichern.

Scheitert der Befehl (die Supabase-CLI kommt auf dieser Maschine an der Netzstrecke nicht durch, siehe Gesamtfahrplan §4d), ist der Ersatz, `0034` von Hand einzuspielen:

```bash
docker exec -i supabase_db_m0-fundament psql -U postgres -d postgres \
  < supabase/migrations/0034_studio_ueberblick.sql
```

`studio_overview` entsteht per `create or replace`, das ist wiederholbar. Der Eintrag im Migrationsverzeichnis trägt dann allerdings weiterhin die alten Anweisungen — ein Schönheitsfehler, der beim nächsten echten Reset verschwindet.

- [ ] **5.2** Belegen, dass Datenbank und Platte übereinstimmen

```bash
docker exec supabase_db_m0-fundament psql -U postgres -d postgres -tA \
  -c "select count(*) from supabase_migrations.schema_migrations;"
ls supabase/migrations/*.sql | wc -l
```

Erwartet: beide **34**.

- [ ] **5.3** Die Datenschutzgrenze in der Datenbank belegen

```bash
docker exec supabase_db_m0-fundament psql -U postgres -d postgres -A -F'|' \
  -c "select polname, pg_get_expr(polqual, polrelid) from pg_policy p join pg_class c on c.oid = p.polrelid where c.relname = 'workout_sessions' and polname = 'workout_sessions_select';"
```

Erwartet: `is_studio_member(...) AND (user_id = auth.uid())` — **ohne** `is_studio_staff`. Das ist `0033`, und es ist der Grund, warum die vier RLS-Tests jetzt den neuen Vertrag prüfen.

---

## Schritt 6: Abnahme des zusammengeführten Stands

- [ ] **6.1** Typecheck und Unit-Tests

```bash
pnpm typecheck && pnpm test
```

- [ ] **6.2** Integrationstests — **jetzt vollständig grün**

```bash
pnpm test:integration
```

Erwartet: alle Dateien grün. Die vier RLS-Tests prüfen den neuen Vertrag, `studio-ueberblick` die neue `0034`.

Der einzige zulässige Wackler ist `rls-workout-sessions > positiv: ein Mitglied beendet seine eigene Session` — er setzt `completed_at` aus der Node-Uhr gegen `started_at` aus der Datenbank und fällt bei Uhrendrift sporadisch (gemessen: zwei von drei Läufen grün). Er gehört repariert, aber nicht hier.

- [ ] **6.3** Bau

```bash
pnpm build
```

Erwartet: grün. Die Routentabelle muss zeigen:

```
/portal/[studioId]                       ← Überblick
/portal/[studioId]/einstellungen
/portal/[studioId]/einstellungen/konto
/portal/[studioId]/modelle               ← Katalogliste
/portal/[studioId]/modelle/[modelId]
/portal/[studioId]/einrichten…           ← acht Routen des Gangs
```

**Kein `(schreibtisch)` in irgendeiner URL.** Steht dort eines, ist die Gruppe falsch geschrieben.

- [ ] **6.4** E2E

```bash
pnpm test:e2e
```

Erwartet: **die 25 aus Phase 3 plus die aus `einstellungen.spec.ts`**, alle grün. `trainerportal.spec.ts` liegt in der Fassung des Worktrees vor — sie weiß, dass der Katalog nach `/modelle` gezogen ist.

- [ ] **6.5** Von Hand ansehen, was kein Test prüft

`pnpm --filter @fitretro/web dev`, dann:

- `/portal/<id>` — der Überblick trägt die Rail
- `/portal/<id>/einstellungen` — **trägt die Rail** (der eigentliche Beweis für Schritt 4), Reiter *Studio* ist aktiv
- `/portal/<id>/einstellungen/konto` — Reiter *Konto* ist aktiv
- `/portal/<id>/einrichten` — trägt **keine** Rail, 390 px

---

## Schritt 7: Die Pläne nachziehen

- [ ] **7.1** `2026-09-01-gesamtfahrplan.md`

- Abschnitt 3: **Studio-Einstellungen** und **Datenschutzgrenze** auf ✅
- Abschnitt 3: **Einrichtung am Gerät** auf ✅ mit dem Vorbehalt, dass der Sucher (9b) offen ist
- Abschnitt 5, Phase 2: alle vier Punkte zu
- Kopftabelle: Bezugsstand auf den neuen `master`
- Abschnitt 4: eine dritte Drift-Notiz — diesmal **Platte hinter Datenbank**, verursacht durch einen unvermergten Worktree. Die Lehre ist nicht dieselbe wie in §4c/§4d: dort fehlten Migrationen in der Cloud, hier fehlten sie im Repository. Ein `supabase db reset` hätte sie gelöscht.

- [ ] **7.2** `2026-09-02-einrichtung-am-geraet.md`

Der Eintrag in der Abnahmeliste über die „lokale Datenbank weicht ab" ist **falsch** und gehört berichtigt: es war kein Defekt der Datenbank, sondern unvermergte Arbeit auf `worktree/calm-forest-3c59`. Die Messungen darin stimmen, die Schlussfolgerung nicht.

- [ ] **7.3** Committen

```bash
git add docs/
git commit -m "docs: Planstand nach der Zusammenfuehrung von Phase 2.3/2.4 und Phase 3"
```

---

## Was danach offen bleibt

| Punkt | Woher |
| --- | --- |
| **9b — der Sucher** (`jsqr`, `Sucher.tsx`, Hauptaktion umstellen, Handprüfung am Telefon) | Phase 3, auf Ansage vertagt |
| **Der Probe-Scan** auf der Fertig-Seite — braucht den Klartext-Token, den `0026` dem Portal entzieht | Phase 3, Aufgabe 12 |
| **`rls-workout-sessions`** setzt `completed_at` aus der Node-Uhr | Bestand, vor beiden Bauabschnitten |
| **Cloud gegen Platte** — ob das Produktivprojekt 31 oder 34 Migrationen trägt, ist ungeprüft | diese Zusammenführung |

Der letzte Punkt ist der dringlichste: dieselbe Frage hat den Gesamtfahrplan schon zweimal beschäftigt (§4c, §4d), und nach diesem Merge stehen drei Migrationen mehr an, die die Cloud noch nicht kennt.
