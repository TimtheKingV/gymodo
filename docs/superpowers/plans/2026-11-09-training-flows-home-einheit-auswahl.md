# Training-Flows: Home-Tag, Einheit bearbeiten, Training-Auswahl – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drei Korrekturen nach dem UX-Update: (1) Ein Tag in der Serie-Woche auf Home bleibt auf Home und zeigt seine Termine darunter. (2) Eine Planeinheit lässt sich auf ihrer Detailseite bearbeiten: Übungen ziehen, ersetzen, löschen – dauerhaft. (3) Der Training-Tab zeigt vor dem Start eine Auswahl: heute Geplantes, die übrigen Termine der Woche (vorziehbar) und „Freies Training“.

**Architecture:** Neu am Server ist nur ein Schreibweg „Einheit ordnen“ (Reihenfolge + Löschen in einem). Er wird gebaut wie `swap_training_plan_position`: SECURITY-DEFINER-RPC, neue aktive Planversion, Domain-Funktion, API-Route. Auf iOS kommen reine Logik-Typen mit Swift-Testing-Tests dazu (`PlanEinheitBearbeitung`, `TrainingAuswahl`, `vorziehen` im Ablaufspeicher); die Views verdrahten sie mit vorhandenen Bausteinen (`EinheitKarte`, `PlanEinheitView`, `GeraeteAuswahlView`, `PlanTausch.kandidaten`).

**Tech Stack:** Supabase/Postgres (plpgsql), TypeScript + vitest (`packages/domain`, `tests/integration`), Next.js Route Handler (`apps/web`), SwiftUI + Swift Testing (`apps/ios-member`), xcodegen.

**Spec:** Es gibt kein eigenes Spec-Dokument. Die Vorlage ist die Design-Leinwand „Training-Flows Entwürfe“ (https://claude.ai/artifact/WxxKdoB8m4idzuBsiuNYw8, Artboards 1a–3c) mit Tims Kommentaren vom 09.11., ergänzt um die Entscheidungen unten. Sie baut auf `docs/superpowers/specs/2026-11-05-ux-vereinheitlichung-design.md` auf (Prämissen 1–6 gelten weiter).

## Entscheidungen dieses Plans

- **E1 Home bleibt Home:** Ein künftiger Tag mit Planmarke zeigt seine Termine unter dem Streifen, statt in den Plan-Tab zu springen. In den Plan geht es nur noch über den Link „Im Plan ›“ am Tag. **Kein Hinweistext** unter der Karte (Kommentar Tim zu 1b).
- **E2 Karte öffnet, Knopf startet:** Ein Tipp auf eine Einheitenkarte öffnet `PlanEinheitView`, gestartet wird nur über den eigenen Knopf darunter (Kommentar Tim zu 1a). Das gilt auf Home, im Plan-Tab und im Training-Tab. Home pusht die Einheit in den eigenen Stack (`HomeRoute.einheit`) und wechselt dafür nicht mehr in den Plan-Tab.
- **E3 Bearbeiten ist dauerhaft:** Ziehen, Löschen und Ersetzen legen eine neue Planversion an, wie der dauerhafte Tausch heute. Den Umschalter „Nur dieses Mal / Für diese Einheit“ aus Entwurf 2b gibt es nicht. Für „nur heute“ bleiben die vorhandenen Wege im laufenden Training (Umordnen, Auslassen, Tausch nur heute). **Bitte von Tim bestätigen lassen.**
- **E4 Nicht in diesem Plan:** „Übung hinzufügen“ (eine neue Position braucht Baustein, Rolle, Sätze und Vorgaben, das ist eine eigene Entscheidung) und „Plan-Vorschlag wiederherstellen“ (es gibt keine gespeicherte Ausgangsfassung). Aus Entwurf 2b fallen beide weg.
- **E5 Ersetzen nur mit passenden Übungen:** Der Server tauscht nur innerhalb desselben Bausteins (`swap_training_plan_position` prüft `plan_baustein`). Das Ersetzen-Blatt zeigt deshalb nur `PlanTausch.kandidaten` (Abschnitt „Passt an diese Stelle“), nicht „Alle Übungen · Rücken“ aus Entwurf 2c. Gespeichert wird über den vorhandenen Endpunkt `swap` ohne `grund`.
- **E6 Ordnen = Reihenfolge + Löschen in einem Aufruf:** `POST /me/plans/{id}/ordnen` mit `{ einheitKey, positionKeys }`. Die Liste ist die neue Reihenfolge; fehlende Schlüssel sind gelöscht. Mindestens eine Position bleibt. `geschaetzteMinuten` rechnet die Domain neu: alter Wert minus die Minuten der entfernten Positionen (`uebungMinuten(typ, saetze)`, bei Cardio `dauerMin`), nicht unter 0.
- **E7 Bearbeiten gesperrt, solange diese Einheit läuft:** Hängt am Ablauf eine Session (`gebundeneSessionId != nil`) und ist `einheitKey` die gezeigte Einheit, gibt es keinen „Bearbeiten“-Knopf.
- **E8 Training-Tab-Einstieg:** Ohne laufende Session und mit Plan zeigt der Tab `TrainingAuswahlView`. „Training starten“ führt in die heutige Plan-Ansicht (Plankarte über der Geräteliste, wie heute). „Freies Training“ führt in die Geräteliste ohne Plankarte, und Sätze binden dort nicht an den Plan (`GeraetModel(ablauf: nil)`). Ohne Plan bleibt alles wie heute (direkt Geräteliste). Während eine Session läuft, gibt es keine Auswahl. Endet die Session, steht wieder die Auswahl da.
- **E9 Vorziehen folgt der Folge:** Wer eine spätere Einheit startet, zieht sie vor (`vorziehen(einheitKey:)`). Danach kommt ihr Nachfolger in der Folge (`TrainingsplanFolge.naechsteEinheitKey`), so rechnen auch Server und Ablauf schon heute. Das Blatt nennt diesen Nachfolger („Danach: Brust, Trizeps“) und nicht „rückt auf Mittwoch“, weil das bei drei Einheiten falsch wäre.
- **E10 Cardio „Starten“** im Training-Tab öffnet das freie Training auf der Kategorie Cardio (`GeraetRoute.kategorie(.cardio)`). Gebuchte Kurse stehen ausgegraut in der Liste, ohne Start-Knopf.

## Global Constraints

- Kein Redesign: nur `DesignSystem`-Tokens und vorhandene Bausteine (`EinheitKarte`, `PrimaryButton`, `SecondaryButton`, `InlineBanner`). Eine Akzentfläche pro Screen (der Hauptknopf).
- Neue Planversionen nur über SECURITY-DEFINER-Funktionen (0062). Keine Tabellen-Grants. Nutzer nur aus `auth.uid()`.
- Fehler der RPC: `plan_nicht_annehmbar` → 409 (`conflict`), `plan_ungueltig` → 422 (`validation_failed`), Unique-Verstoß → 409, wie `tauschePlanPosition`.
- Nach jedem dauerhaften Schreiben auf iOS: `await katalog.load()`, dann `planAblauf.vorbereiten(bootstrap:)`, wie `PlanPositionSheet.neuLaden`.
- Texte deutsch, mit echten Umlauten. Testnotiz-IDs (`.testnotizElement`) für neue Bedienelemente vergeben.
- Tests iOS: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/<Suite> 2>&1 | tail -20`, Zeile „Test run with N tests“ prüfen. Nach neuen oder gelöschten Dateien `xcodegen generate` ausführen und `project.pbxproj` mitcommitten.
- Tests Server: `pnpm --filter @fitretro/domain test`; `pnpm test:integration -- <datei>` (lokales Supabase: `pnpm supabase start`, nach neuer Migration `pnpm supabase db reset`).
- Prod-Datenbank nur mit Tims ausdrücklicher Freigabe (siehe Memory „Migration 0057 Prod-Freigabe“: Freigaben gelten je Migration).
- Commits deutsch (`feat(ios): …`, `feat(plan): …`), Ende `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Arbeiten in einem Worktree von `origin/master` (Stand ba031724 oder neuer), nicht auf `codex/sensor-luecken-2026-10-26`.

## Review Focus

1. **Alle Positionen löschen:** Der letzte Löschen-Knopf ist gesperrt, und der Server lehnt eine leere Liste mit 422 ab. Die Einheit bleibt bestehen. → Tests in Task 1 und Task 3.
2. **Bearbeiten, während dieselbe Einheit schon vorbereitet, aber noch ohne Satz ist:** Nach „Fertig“ zeigt die Plankarte im Training-Tab sofort die neue Reihenfolge, und gelöschte Positionen sind weg (`vorbereiten` ersetzt den ungebundenen Ablauf). → Test in Task 6 (`vorbereiten` mit neuer Version nach `vorziehen`).
3. **Vorziehen, dann App ohne Satz bis zum nächsten Tag liegen lassen:** Der Vorzug verfällt nach `verfallOhneSatz`, und es gilt wieder die Folge. → Test in Task 6.
4. **Home: denselben künftigen Tag zweimal antippen:** Die Auswahl klappt wieder zu, und „Nächste Einheit“ steht wieder da. Es steht nie dieselbe Einheit zweimal auf dem Screen. → Test in Task 5 (reine Auswahl-Logik).
5. **Freies Training an einem Krafttag:** Ein Satz an einer Übung, die auch im Plan steht, hakt keine Planposition ab, und die Einheit bleibt offen. → Test in Task 8 (`GeraetModel` mit `ablauf: nil` liefert keine Momentaufnahme).

---

### Task 1: RPC `order_training_plan_einheit` und Domain-Funktion `ordnePlanEinheit`

**Files:**
- Create: `supabase/migrations/0073_plan_einheit_ordnen.sql`
- Modify: `packages/domain/src/trainingsplan.ts` (neben `tauschePlanPosition`, ab Z. 265), `packages/domain/src/index.ts` (Export)
- Test: `tests/integration/domain-trainingsplan.test.ts` (neuer `describe("ordnePlanEinheit")`), `packages/domain/src/trainingsplan.test.ts` oder neue `packages/domain/src/plan-ordnen.test.ts` für die reine Minutenrechnung

**Interfaces:**
- Produces (SQL): `public.order_training_plan_einheit(p_plan_id uuid, p_einheit_key text, p_position_keys text[], p_minuten numeric) returns public.training_plans`, nur für `authenticated` ausführbar.
- Produces (TS): `export type PlanOrdnen = { einheitKey: string; positionKeys: string[] }`; `export async function ordnePlanEinheit(client: SupabaseClient, userId: string, planId: string, input: PlanOrdnen): Promise<TrainingPlan>`; rein: `export function minutenNachOrdnen(einheit: PlanEinheit, positionKeys: string[]): number`.

- [ ] **Step 1: Failing tests schreiben**
  - Rein (`minutenNachOrdnen`): Einheit mit `geschaetzteMinuten: 40`, Positionen p0 (`typ: "mehrgelenk"`, `saetze: 3`), p1 (`isolation`, 3), p2 (`baustein: "cardio"`, `dauerMin: 10`). `["p1","p0","p2"]` → 40. `["p0","p2"]` → `40 - uebungMinuten("isolation", 3)`. `["p0"]` → `40 - uebungMinuten("isolation",3) - 10`. Ergebnis nie < 0.
  - Integration `ordnePlanEinheit`:
    - Reihenfolge `["p2","p0","p1"]` → neue Version (`version` +1, `status: "aktiv"`), die alte ist `ersetzt`, Positionen in genau dieser Reihenfolge, alle anderen Felder der Positionen unverändert.
    - Löschen: `["p0"]` → nur p0 übrig, `geschaetzteMinuten` wie `minutenNachOrdnen`.
    - Andere Einheiten bleiben unverändert, ebenso `wochenraster`.
    - Fehlerfälle → `DomainError("validation_failed")`: leere Liste, doppelter Schlüssel, unbekannter Schlüssel, unbekannte `einheitKey`.
    - Fremder Plan und nicht aktiver Plan → `DomainError("conflict")`.
    - Zielgewichte: Eine verbleibende Position behält ihr Ziel (wie G9 beim Tausch).
- [ ] **Step 2:** `pnpm --filter @fitretro/domain test` und `pnpm test:integration -- domain-trainingsplan` → FAIL (Funktion fehlt).
- [ ] **Step 3: Migration `0073_plan_einheit_ordnen.sql`.** Kopf-Kommentar mit Zweck (Entwurf 2b, E6). Die Funktion folgt `swap_training_plan_position` aus 0070:
  - `auth.uid()` prüfen; Studio lesen (`plan_nicht_annehmbar`, wenn kein eigener Plan).
  - Advisory-Lock mit demselben Schlüssel `'training_plans:' || user || ':' || studio`.
  - `for update`; `status = 'aktiv'` und `is_catalog_studio` (sonst `plan_nicht_annehmbar`).
  - `plan_ungueltig`, wenn: die Einheit fehlt, `p_position_keys` null oder leer ist, ein Schlüssel doppelt vorkommt, ein Schlüssel nicht in der Einheit steht, `p_minuten` null ist oder außerhalb 0–600 liegt.
  - Neue Positionen = die alten Positions-Objekte in der Reihenfolge von `p_position_keys` (`with ordinality` über das Array). `geschaetzteMinuten` = `p_minuten`. Die anderen Einheiten bleiben in ihrer Reihenfolge.
  - Version +1, alte Version `ersetzt`, neue einfügen. Dabei alle Spalten übernehmen wie in 0070 (`regel_version, eingabe, struktur, gruende, wochenraster`) und `accepted_at = now()` setzen.
  - `revoke all … from public, anon, authenticated, service_role; grant execute … to authenticated;`
  - Danach `pnpm supabase db reset`.
- [ ] **Step 4: `ordnePlanEinheit` implementieren.**
  - `einheiten` des Plans lesen, gefiltert auf `id` und `user_id`; fehlt der Plan → `conflict`.
  - `minutenNachOrdnen` auf die Einheit anwenden; fehlt die Einheit → `validation_failed`, ohne RPC-Aufruf.
  - RPC aufrufen; Fehler zuordnen wie in `tauschePlanPosition` (P0001-Meldungen, `istUniqueVerstoss`, `user_id`-Abgleich).
  - Danach `ohneAbbruch("Ziele nach Ordnen", …)` mit `uebernehmePlanGewichte` + `initialisierePlanGewichte`.
  - Meldungstexte: „Diese Einheit kann so nicht gespeichert werden.“ (422) und „Dieser Plan kann nicht mehr geändert werden.“ (409).
- [ ] **Step 5:** Beide Testläufe aus Step 2 → PASS. Danach `pnpm smoke:migrations` → PASS.
- [ ] **Step 6: Commit** `feat(plan): Einheit ordnen und Positionen entfernen als neue Planversion`

### Task 2: API-Route `POST /api/v1/me/plans/[id]/ordnen`

**Files:**
- Create: `apps/web/app/api/v1/me/plans/[id]/ordnen/route.ts`
- Test: `tests/integration/api-plans.test.ts` (neuer `describe("/me/plans/[id]/ordnen")`)

**Interfaces:**
- Consumes: `ordnePlanEinheit`, `PlanOrdnen` (Task 1).
- Produces: `POST` mit Rumpf `{ einheitKey: string (min 1), positionKeys: string[] (min 1, max 20, je min 1) }` → 200 mit der neuen aktiven Planversion (dieselbe Form wie `swap`).

- [ ] **Step 1: Failing tests** nach dem Muster von `describe("/me/plans/[id]/swap")`:
  - „401 ohne Token“.
  - „200 mit status aktiv, version +1 und neuer Reihenfolge“.
  - „422 bei leerer Liste, unbekanntem Schlüssel und kaputtem Rumpf“.
  - „422 bei ungültiger Plan-ID“.
  - „409 für fremden Plan“.
- [ ] **Step 2:** `pnpm test:integration -- api-plans` → FAIL.
- [ ] **Step 3: Route schreiben** als Kopie der `swap`-Route mit eigenem zod-Schema (`ordnenSchema`).
  - JSDoc: „Ordnet die Positionen einer Einheit neu; fehlende Schlüssel werden entfernt. Antwort ist die neue aktive Version.“
  - Validierungsmeldung: „Die Reihenfolge ist unvollständig oder ungültig.“
- [ ] **Step 4:** `pnpm test:integration -- api-plans` → PASS; `pnpm typecheck` → PASS.
- [ ] **Step 5: Commit** `feat(api): POST /me/plans/{id}/ordnen`

### Task 3: iOS – Bearbeitungslogik und API-Client

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/PlanEinheitBearbeitung.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift` (neben `swapPlanPosition`, Z. 268)
- Test: `apps/ios-member/FitnessMemberTests/PlanEinheitBearbeitungTests.swift` (neu), `apps/ios-member/FitnessMemberTests/APIClientTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct PlanEinheitBearbeitung: Equatable {
      init(einheit: TrainingsplanEinheit)
      private(set) var keys: [String]          // aktuelle Reihenfolge
      var geaendert: Bool                      // keys != Ausgangsreihenfolge
      var darfEntfernen: Bool                  // keys.count > 1
      mutating func verschieben(von: IndexSet, nach: Int)   // Semantik wie Array.move(fromOffsets:toOffset:)
      @discardableResult mutating func entfernen(_ offsets: IndexSet) -> Bool  // false und unveraendert, wenn danach nichts bliebe
      func positionen(in einheit: TrainingsplanEinheit) -> [TrainingsplanPosition]  // in keys-Reihenfolge, unbekannte Keys ausgelassen
      mutating func uebernehmen(neueEinheit: TrainingsplanEinheit)  // nach Tausch: Reihenfolge behalten, Keys, die es nicht mehr gibt, raus, neue hinten an
  }
  ```
  `APIClient.ordnePlanEinheit(planId: String, einheitKey: String, positionKeys: [String]) async throws(APIError) -> Trainingsplan`, gesendet als `POST me/plans/\(planId)/ordnen`.

- [ ] **Step 1: Failing tests** (`struct PlanEinheitBearbeitungTests`, Swift Testing):
  - `verschiebenAendertReihenfolge`: `["0","1","2"]`, `verschieben(von: [2], nach: 0)` → `["2","0","1"]` und `geaendert == true`.
  - `zurueckVerschobenIstUnveraendert`: hin und zurück → `geaendert == false`.
  - `entfernenLetzteBleibtVerweigert`: Einheit mit einer Position, `entfernen([0]) == false`, `keys == ["0"]`.
  - `entfernenNimmtRaus`: `entfernen([1])` → `["0","2"]` und `darfEntfernen == true`.
  - `uebernehmenNachTausch`: Reihenfolge `["2","0","1"]`, neue Einheit mit `["0","1","2"]` → bleibt `["2","0","1"]`. Ohne `"1"` → `["2","0"]`.
  - In `APIClientTests` nach dem Muster des `swapPlanPosition`-Tests: Pfad `me/plans/P1/ordnen`, Methode POST, Rumpf `{"einheitKey":"A","positionKeys":["1","0"]}`.
- [ ] **Step 2:** `xcodegen generate`, danach die Suites `PlanEinheitBearbeitungTests` und `APIClientTests` laufen lassen → FAIL.
- [ ] **Step 3:** Implementieren (`keys` = `einheit.positionen.map(\.key)`; Rumpf als `Encodable`-Struct wie bei `swapPlanPosition`).
- [ ] **Step 4:** Dieselben Suites → PASS.
- [ ] **Step 5: Commit** `feat(ios): Bearbeitungslogik und API-Aufruf für Einheit ordnen`

### Task 4: iOS – „Bearbeiten“ in der Einheiten-Detailseite

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Plan/PlanEinheitBearbeitenView.swift`, `apps/ios-member/FitnessMember/Screens/Plan/PlanEinheitErsatzSheet.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Plan/PlanEinheitView.swift` (Toolbar, Liste nummeriert lassen; Überschrift „N ÜBUNGEN · IN DIESER REIHENFOLGE“ statt „REIHENFOLGE EGAL“)
- Test: `apps/ios-member/FitnessMemberTests/PlanEinheitBearbeitungTests.swift` (Test für die Sperre)

**Interfaces:**
- Consumes: `PlanEinheitBearbeitung`, `APIClient.ordnePlanEinheit` (Task 3); vorhanden: `APIClient.swapPlanPosition(planId:einheitKey:positionKey:exerciseId:modelId:)`, `PlanTausch.kandidaten(position:plan:ort:…)` (`PlanTausch.swift:138`), `PlanTausch.ort(aktivesStudio:bootstrap:)`, `PlanTausch.fehlerText(_:)`.
- Produces: `static func PlanEinheitBearbeitung.darfBearbeiten(einheitKey: String, laufEinheitKey: String?, gebunden: Bool) -> Bool` (E7). `PlanEinheitView` bekommt `apiClient: APIClient` als neuen Parameter; die Aufrufer in `MainTabView` (Plan-Stack) sowie `HomeRootView` und `TrainingRootView` (Tasks 5 und 8) übergeben ihn.

- [ ] **Step 1: Failing test** `darfBearbeitenNichtWaehrendDieseEinheitLaeuft`:
  - `("A", lauf "A", gebunden true)` → false.
  - `("A", lauf "A", gebunden false)` → true.
  - `("B", lauf "A", gebunden true)` → true.
- [ ] **Step 2:** Suite laufen lassen → FAIL.
- [ ] **Step 3: Implementieren.**
  - `PlanEinheitView`: `.toolbar` mit „Bearbeiten“ (`.topBarTrailing`, nur wenn `darfBearbeiten`). Er öffnet `PlanEinheitBearbeitenView` als `.fullScreenCover`.
  - `PlanEinheitBearbeitenView`: Kopf „Einheit bearbeiten“, links „Abbrechen“, rechts „Fertig“ (Akzent). Darunter der Name der Einheit (`EinheitNamen.name`), darunter die Zeile „Der Name passt sich an, wenn du Übungen tauschst“ in `textMuted`.
  - Die Liste ist eine `List` mit `.environment(\.editMode, .constant(.active))`, `.onMove` → `verschieben`, `.onDelete` → `entfernen` (bei `false` gibt es keinen Effekt). `.deleteDisabled(!darfEntfernen)` steht an jeder Zeile.
  - Zeile: Vorschaubild (wie in `PlanZeile`), Name, Vorgabe (`PlanAnzeige`-Untertitel wie in `PlanEinheitView`), Knopf mit `arrow.left.arrow.right`, `accessibilityLabel` „<Name> ersetzen“.
  - Ersetzen öffnet `PlanEinheitErsatzSheet` mit den Kandidaten aus `PlanTausch.kandidaten` als Zeilen (Name + letzter Satz, wie `PlanErsatzKopf`). Wahl → `swapPlanPosition` ohne `grund`, dann neu laden (Global Constraints), dann `bearbeitung.uebernehmen(neueEinheit:)`. Ohne Kandidaten steht da „Für diese Stelle gibt es gerade keine passende Übung.“.
  - „Fertig“: Ist nichts geändert, wird nur geschlossen. Sonst `ordnePlanEinheit` mit der aktuellen `planId` aus dem Bootstrap, danach neu laden und schließen. Während des Schreibens sind die Knöpfe gesperrt, und `interactiveDismissDisabled` ist an.
  - Fehler erscheinen als `InlineBanner(tone: .danger, message: PlanTausch.fehlerText(fehler))` über der Liste. Die Liste bleibt dann im bearbeiteten Zustand.
  - „Abbrechen“ mit Änderungen fragt nach: `confirmationDialog` „Änderungen verwerfen?“.
  - Testnotiz-IDs: `einheit.bearbeiten`, `einheit.bearbeiten.fertig`, `einheit.bearbeiten.ersetzen`.
- [ ] **Step 4:** Suite → PASS. Bauen ohne Warnungen in den neuen Dateien.
- [ ] **Step 5: Commit** `feat(ios): Einheit bearbeiten – ziehen, ersetzen, löschen`

### Task 5: iOS – Home bleibt beim Tag

**Files:**
- Modify: `apps/ios-member/FitnessMember/Verlauf/HomeSerie.swift:36-41, 167-172` (`HomeSerieTipp`, `tippZiel`), `apps/ios-member/FitnessMember/Screens/Home/HomeSerieView.swift` (`auswaehlen`, neuer Callback), `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift` (Plan-Abschnitt statt „Nächste Einheit“, Route), `apps/ios-member/FitnessMember/Navigation/HomeRoute.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Home/HomePlanTagAbschnitt.swift`
- Test: `apps/ios-member/FitnessMemberTests/HomeSerieTests.swift` (bestehende `planTag`-Tests Z. 452–470 umschreiben)

**Interfaces:**
- Produces:
  - `HomeSerieTipp.planTag` wird zu `HomeSerieTipp.planZeigen` („Die Plantermine des Tages darunter zeigen“).
  - `HomeSerieView` bekommt `var beiPlanAuswahl: (String?) -> Void`: die Tages-Id bei `.planZeigen`, nil beim Zuklappen oder bei Auswahl eines anderen Tages. Der alte Callback `beiPlanTag` entfällt.
  - `HomeRoute.einheit(key: String)`.
  - `static func HomeSerie.zeigtNaechsteEinheit(planTagId: String?) -> Bool` (true genau dann, wenn kein Plantag gewählt ist).
- Consumes: `PlanKalenderKontext.tag(id:kalender:)`, `planTermine(_:jetzt:)` in `HomeRootView`, `EinheitKarte`, `EinheitKarteModell.einheit(…)`, `PlanEinheitView(apiClient:…)` (Task 4).

- [ ] **Step 1: Failing tests** (umschreiben, nicht ergänzen):
  - `kuenftigerTagMitMarkeZeigtPlan`: Freitag künftig mit Marke → `.planZeigen`, mit und ohne Inhalt.
  - `heuteMitMarkeOhneInhaltNichtAntippbar`: `tippZiel(heute, hatInhalt: false) == nil`. Heute steht schon in „Nächste Einheit“, und Tim will keine doppelte Information.
  - `heuteMitMarkeUndInhaltKlapptAuf` bleibt.
  - `naechsteEinheitNurOhneGewaehltenPlantag`: `zeigtNaechsteEinheit(planTagId: nil) == true`, `("2026-11-06") == false`.
- [ ] **Step 2:** Suite `HomeSerieTests` → FAIL.
- [ ] **Step 3: Implementieren.**
  - `auswaehlen`: Bei `.planZeigen` wird `auswahl` umgeschaltet (zweiter Tipp klappt zu), und `beiPlanAuswahl` meldet die Id oder nil. Ein Tipp auf einen vergangenen Tag meldet `nil`.
  - `gewaehlterTag` akzeptiert eine Plantag-Auswahl auch ohne Trainings oder Kurse, über eine Prüfung „Tag hat Planmarke“ (`geplant[id] != nil`). Die Tagesliste der Trainings bleibt an `hatInhalt` gebunden.
  - `HomeRootView`: `@State private var planTagId: String?`. Ist `planTagId` gesetzt, steht anstelle von `naechsteEinheit(…)` ein `HomePlanTagAbschnitt` mit den Terminen dieses Tages aus `termine`.
  - `HomePlanTagAbschnitt`:
    - Kopf: Label „<WOCHENTAG>, <d.> <MMM> · GEPLANT“ und rechts der Link-Knopf „Im Plan“ mit Chevron. Er ruft `beiPlanZeigen(.tag(tag))`.
    - Einheit → `EinheitKarte` ohne `aktion`, Tipp → `pfad.append(.einheit(key:))`.
    - Kurs → Zeile mit Titel und Uhrzeit, Tipp → `beiPlanZeigen(.tag(tag))`.
    - Cardio → Zeile „Cardio“, ebenfalls ohne Start.
    - **Kein Hinweistext.**
  - `NaechsteEinheitKarte.beiTippen` pusht bei `.einheit` künftig `.einheit(key:)` in den Home-Stack (E2); Kurs und Cardio springen weiter in den Plan.
  - `navigationDestination` bekommt einen Fall `.einheit(let key)` → `PlanEinheitView(einheitKey: key, apiClient: apiClient, beiTrainingStarten: { pfad.removeAll(); beiTrainingZeigen() })`.
  - Testnotiz-IDs: `home.plantag`, `home.plantag.imPlan`.
- [ ] **Step 4:** `HomeSerieTests`, `PlanKalenderKontextTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Tag in der Home-Woche bleibt auf Home und zeigt seine Termine`

### Task 6: iOS – Einheit vorziehen im Ablaufspeicher

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/TrainingsplanAblaufStore.swift` (`PlanAblaufDatei` Z. 357, `gewaehlteEinheit` Z. 328, `vorbereiten`, `abschliessen`, `einheitBeendet`, `reset`)
- Test: `apps/ios-member/FitnessMemberTests/TrainingsplanAblaufStoreTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct Vorgezogen: Codable, Equatable { let einheitKey: String; let am: Date }
  // PlanAblaufDatei: var vorgezogen: Vorgezogen?   (optional -> alte Dateien bleiben lesbar)
  @discardableResult func vorziehen(einheitKey: String, jetzt: Date = Date()) -> Bool
  func vorziehenZuruecknehmen(jetzt: Date = Date())
  var vorgezogenerKey: String? { get }
  ```
  `vorziehen` ist `false` und tut nichts, wenn eine Session gebunden ist oder der Key nicht in `vorlage.einheitKeys` steht. Sonst setzt es `vorgezogen`, ruft `ungebundenAuffrischen` auf und speichert.
- Consumes: vorhandenes `TrainingsplanFolge.naechsteEinheitKey`, `Self.verfallOhneSatz`.

- [ ] **Step 1: Failing tests:**
  - `vorziehenStartetGewaehlteEinheit`: Plan A/B mit nächster A, `vorziehen("B")` → `true`, `einheitKey == "B"` und `naechsteEinheitKey == "B"`.
  - `vorziehenMitGebundenerSessionVerweigert` → `false`, die Einheit bleibt A.
  - `vorziehenUnbekannterKey` → `false`.
  - `nachBeendetGiltFolgeDesVorgezogenen`: B vorgezogen, Satz binden, `einheitBeendet()` → `vorgezogenerKey == nil`, neue `naechsteEinheitKey == "A"` (Nachfolger von B).
  - `vorzugVerfaellt`: `vorziehen("B", jetzt: t)`, `vorbereiten(plan:, jetzt: t + verfallOhneSatz + 1)` → `einheitKey == "A"` und `vorgezogenerKey == nil`.
  - `neueVersionBehaeltVorzug`: B vorgezogen, `vorbereiten(plan: v2)` mit gleicher Einheit B → `einheitKey == "B"`, Positionen aus v2 (deckt Review Focus 2).
  - `alteDateiOhneVorzugLesbar`: JSON ohne `vorgezogen` dekodiert, und der Wert ist `nil`.
- [ ] **Step 2:** Suite `TrainingsplanAblaufStoreTests` → FAIL.
- [ ] **Step 3: Implementieren.**
  - `gewaehlteEinheit`: Ein gültiger `vorgezogen` mit bekanntem Key geht vor `lokalZuletzt` und `serverNaechste`.
  - `vorbereiten`: Ein Vorzug, der älter als `verfallOhneSatz` ist, wird vor `ungebundenAuffrischen` entfernt.
  - `abschliessen`, `einheitBeendet` (beide Zweige) und `reset` leeren `vorgezogen`.
- [ ] **Step 4:** Suite → PASS; `TrainingsplanAblaufTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Einheit vorziehen im Planablauf`

### Task 7: iOS – Auswahl-Modell für den Training-Tab

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/TrainingAuswahl.swift`
- Test: `apps/ios-member/FitnessMemberTests/TrainingAuswahlTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum TrainingEinstieg: Equatable { case auswahl, plan, frei }

  enum TrainingAuswahlOption: Equatable, Identifiable {
      case einheit(key: String, tag: Date)
      case cardio(tag: Date)
      case kurs(titel: String, beginn: Date, tag: Date)
      var id: String { get }   // "einheit-<key>", "cardio-<yyyy-MM-dd>", "kurs-<beginn ISO>"
  }

  struct TrainingAuswahlModell: Equatable {
      let heuteEinheitKey: String?            // die Einheit von "Heute geplant", nil an Tagen ohne Krafttermin heute
      let weitere: [TrainingAuswahlOption]    // chronologisch, heute bis Sonntag
  }

  enum TrainingAuswahl {
      static func modell(termine: [Date: [PlanTermin]], heute: Date, naechsteEinheitKey: String?,
                         kalender: Calendar) -> TrainingAuswahlModell
      /// "Danach: <Name>" im Vorziehen-Blatt (E9).
      static func danach(einheitKey: String, einheitKeys: [String]) -> String
  }
  ```
- Regeln:
  - Berücksichtigt werden nur Termine von heute bis Sonntag dieser Woche (Kalenderwoche ab Montag, `kalender`) mit Zustand `.geplant`.
  - `heuteEinheitKey` = `naechsteEinheitKey`, wenn heute ein `.einheit`-Termin liegt, sonst nil.
  - `weitere`: jede Einheit höchstens einmal und nie die von `heuteEinheitKey`; Cardio einmal je Tag; Kurse nur mit `angemeldet == true`.
  - Ohne heutigen Krafttermin steht die nächste Einheit als erstes Element in `weitere`. Ihr „Starten“ braucht dann kein Vorziehen, weil sie ohnehin dran ist.

- [ ] **Step 1: Failing tests** (Kalender Europe/Berlin, Montag 2026-11-09 als heute):
  - `heuteGeplantUndRestDerWoche`: Termine Mo A geplant, Mi B geplant, Fr Cardio, Sa Kurs angemeldet → `heuteEinheitKey == "A"`, `weitere == [.einheit("B", Mi), .cardio(Fr), .kurs(…Sa)]`.
  - `ohneKraftHeuteKeinHeute`: heute nur Cardio → `heuteEinheitKey == nil`, und die erste Option ist das Cardio von heute.
  - `erledigtesUndVerpasstesFehlt`: Zustand `.erledigt` oder `.verpasst(...)` → nicht enthalten.
  - `naechsteWocheFehlt`: Termin am folgenden Montag → nicht enthalten.
  - `einheitNurEinmal`: B an Mi und Fr → nur einmal (Mi).
  - `danachIstNachfolger`: `danach("B", ["A","B"]) == "A"`, `danach("B", ["A","B","C"]) == "C"`.
- [ ] **Step 2:** `xcodegen generate`, Suite `TrainingAuswahlTests` → FAIL.
- [ ] **Step 3:** Implementieren (`danach` über `TrainingsplanFolge.naechsteEinheitKey`).
- [ ] **Step 4:** Suite → PASS.
- [ ] **Step 5: Commit** `feat(ios): Auswahl-Modell für den Training-Tab`

### Task 8: iOS – Training-Tab: Auswahl, Vorziehen, freies Training

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Training/TrainingAuswahlView.swift`, `apps/ios-member/FitnessMember/Screens/Training/TrainingVorziehenSheet.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (`wurzel` Z. 443ff., `GeraetModel(…, ablauf:)` Z. 967–975, `onChange(of: sessions.aktiveSession() != nil)` Z. 364ff.), `apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift` (`case planEinheit(key: String)`)
- Test: `apps/ios-member/FitnessMemberTests/TrainingTabTests.swift`, `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift`

**Interfaces:**
- Consumes: `TrainingEinstieg`, `TrainingAuswahl.modell`, `TrainingAuswahl.danach` (Task 7); `planAblauf.vorziehen(einheitKey:)` (Task 6); `PlanEinheitView(apiClient:…)` (Task 4); `PlanKalenderKontext.termine(…, filter: .alle)` (dieselben Parameter wie in `HomeRootView.planTermine`).
- Produces:
  - `static func TrainingTab.zeigtAuswahl(einstieg: TrainingEinstieg, laeuft: Bool, hatPlan: Bool) -> Bool` (true genau bei `.auswahl`, ohne laufende Session und mit Plan).
  - `static func TrainingTab.zeigtPlankarte(einstieg: TrainingEinstieg) -> Bool` (false nur bei `.frei`).

- [ ] **Step 1: Failing tests:**
  - `TrainingTabTests.auswahlNurOhneSessionMitPlan`: alle 3×2×2 Kombinationen von `zeigtAuswahl`.
  - `TrainingTabTests.freiOhnePlankarte`: `zeigtPlankarte(.frei) == false`, `(.plan) == true`, `(.auswahl) == true`.
  - `GeraetModelTests.ohneAblaufKeineMomentaufnahme`: `GeraetModel` mit `ablauf: nil`, Satz an einer Übung, die im Plan steht → keine `PlanMomentaufnahme` und keine Planstelle (Review Focus 5). Das Setup folgt den vorhandenen Plan-Tests in `GeraetModelTests`.
- [ ] **Step 2:** Suites `TrainingTabTests`, `GeraetModelTests` → FAIL.
- [ ] **Step 3: Implementieren.**
  - `TrainingRootView`: `@State private var einstieg: TrainingEinstieg = .auswahl`. Wenn die Session endet (`laeuft` wird false), wird `einstieg = .auswahl` gesetzt.
  - `wurzel`: Bei `zeigtAuswahl` steht `TrainingAuswahlView`. Sonst gilt der bisherige Zweig, wobei `PlanKarteBereich` nur bei `zeigtPlankarte` erscheint.
  - Bei `.plan` und `.frei` ohne laufende Session steht oben links ein Zurück-Knopf „Auswahl“ (setzt `.auswahl`).
  - `GeraetModel(…, ablauf: einstieg == .frei ? nil : planAblauf)`.
  - `TrainingAuswahlView` nach Entwurf 3a:
    - Titel „TRAINING“.
    - Abschnitt „HEUTE GEPLANT“: `EinheitKarte` mit Tipp → `pfad.append(.planEinheit(key:))` und `PrimaryButton("Training starten")` → `einstieg = .plan`.
    - Abschnitt „AUCH DIESE WOCHE IM PLAN“: Zeilen mit Tag und Name und rechts dem Pillen-Knopf „Starten“.
      - Einheit, die nicht die nächste ist → `TrainingVorziehenSheet`. Die nächste → direkt `.plan`.
      - Cardio → `einstieg = .frei` und `pfad.append(.kategorie(.cardio))`.
      - Kurs ausgegraut, ohne Knopf.
    - Darunter die Karte „Freies Training · Geräte und Übungen selbst wählen“ → `.frei`.
    - Der Fuß mit `ScanWege` bleibt nur bei `.plan`/`.frei` (E8). Ein Scan aus der Auswahl heraus entfällt.
  - `TrainingVorziehenSheet` nach Entwurf 3b:
    - Titel „<Name> heute machen?“, Text „Dein Plan läuft in Reihenfolge.“.
    - Zeile „Danach: <danach-Name>“.
    - `PrimaryButton("<Name> starten")` → `planAblauf.vorziehen(einheitKey:)`; bei `true` folgt `einstieg = .plan`, bei `false` das Banner „Gerade läuft schon eine Einheit.“.
    - „Abbrechen“.
  - `GeraetRoute.planEinheit(key:)` → `PlanEinheitView(einheitKey:apiClient:beiTrainingStarten: { pfad.removeLast(); einstieg = .plan })`.
  - Testnotiz-IDs: `training.auswahl.start`, `training.auswahl.option`, `training.auswahl.frei`, `training.vorziehen.start`.
- [ ] **Step 4:** Suites → PASS, danach die ganze `FitnessMemberTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Training-Tab startet mit Auswahl aus dem Plan und freiem Training`

### Task 9: Gesamtprüfung im Simulator

**Files:** keine (nur Prüfung; Funde als eigene Commits in der zuständigen Task-Datei)

- [ ] **Step 1:** `pnpm typecheck && pnpm --filter @fitretro/domain test && pnpm test:integration -- api-plans domain-trainingsplan` → PASS.
- [ ] **Step 2:** Volle iOS-Suite → PASS, Zahl der Tests notieren.
- [ ] **Step 3: Simulator (iPhone 17 Pro, lokaler Server, Test-Mitglied mit A/B-Plan, Kraft Mo/Mi, Cardio Fr).** Je ein Screenshot pro Punkt:
  1. Home: Mi antippen → Abschnitt „MITTWOCH … · GEPLANT“, kein Wechsel in den Plan-Tab, kein Hinweistext. Erneut antippen → „Nächste Einheit“ ist zurück.
  2. Karte antippen → Einheiten-Detail im Home-Stack, dann „Bearbeiten“ → ziehen, löschen, ersetzen → „Fertig“ → Detail zeigt die neue Reihenfolge, und der Plan-Tab zeigt dieselbe.
  3. Training-Tab ohne Session → Auswahl. Mi-Einheit „Starten“ → Blatt mit „Danach: …“ → Start → Plankarte zeigt die Mi-Einheit.
  4. „Freies Training“ → Geräteliste ohne Plankarte. Ein Satz an einer Planübung → im Plan-Tab bleibt die Einheit offen.
- [ ] **Step 4:** Ergebnis und Screenshots an Tim. Prod-Migration 0073 und API-Deploy erst nach ausdrücklicher Freigabe.
