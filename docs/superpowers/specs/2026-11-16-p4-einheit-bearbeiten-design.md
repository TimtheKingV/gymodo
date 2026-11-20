# P4 · Einheit ansehen und bearbeiten – Design

**Quelle:** Testnotizen 10.11. #3–#7 (`docs/superpowers/plans/2026-11-10-testnotizen-pakete.md`, Abschnitt P4). Entwürfe: Design-Canvas „P4 Einheit bearbeiten“ (https://claude.ai/artifact/WjzFjBaepfAUupoBSD9tN4), Tafeln 1–5.
**Basis:** Branch `claude/training-flows` (PR #102, noch offen). Die Bearbeiten-Ansicht, `ordnen` und Migration 0073 gibt es nur dort. P4 setzt darauf auf und wird erst nach #102 gemergt.

## Absicht

Tim will einen Plan selbst formen können, nicht nur umsortieren: Übungen frei hinzufügen, frei tauschen und Sätze/Wiederholungen/Pause ändern. Ansehen und Bearbeiten sollen gleich aussehen (eine Übungskarte überall), die ganze Seite scrollt, und „Abbrechen“ nimmt wirklich alles zurück.

## Bug #6 (Speichern ging nicht) – geklärt, kein Code-Fehler

„Fertig“ ruft `POST /me/plans/{id}/ordnen`. Die Route gibt es nur auf `training-flows`; die Prod-API (`gymodo-web.vercel.app`) antwortet mit 404-HTML, die App mappt eine Antwort ohne Fehlerumschlag auf `.server` → „Das hat nicht geklappt“. Behoben, sobald PR #102 gemergt/deployt und 0073 auf Prod ist. In P4 kein eigener Fix; der neue Endpunkt ersetzt den Aufruf ohnehin.

## Entscheidungen (mit Tim, 16.11.)

- **D1 Beliebige Übungen:** Hinzufügen und Tauschen erlauben jede Übung des Katalogs, nicht nur denselben Baustein. Die Vorschläge („Passt an diese Stelle“) bleiben oben, darunter die normale Suche wie im freien Training.
- **D2 Werte im Plan änderbar (Variante C):** Für jede Position änderbar: Sätze, Wiederholungen von–bis, Pause; bei Cardio die Dauer. Fest: Reserve, Aufwärmsatz.
- **D3 Werte bei Neuem:** Beim Tausch übernimmt die neue Übung Sätze, Wdh und Pause der alten. Wechselt die Art zwischen Kraft und Cardio, gelten die Standardwerte der neuen Art. Beim Hinzufügen gelten Standardwerte (unten).
- **D4 Ein Speichern:** Ordnen, Entfernen, Hinzufügen, Tauschen und Werte sammeln sich lokal und gehen mit „Fertig“ in **einem** Aufruf als **eine** neue Planversion an den Server. „Abbrechen“ verwirft alles (mit Rückfrage, wenn etwas geändert ist). Der Sofort-Tausch in der Bearbeiten-Ansicht entfällt.
- **D5 Übungskarte Variante A:** Thumbnail links (56 pt), Titel daneben, darunter Chips mit Icon: „3 Sätze“, „8–12 Wdh“, „90 s“. Cardio: nur „20 min“. Karten mit Rand (`line`), Radius 14.
- **D6 Gestaltung wie Canvas Tafel 2–5** (Ansehen, Bearbeiten, Anpassen-Blatt, Tauschen).

## Ansätze (Speichern)

1. **Ein Endpunkt „Einheit ersetzen“** – gewählt. Ganze Einheit in einem Aufruf, Domain prüft und rechnet, SQL schreibt eine Version. Atomar, passt zu D4.
2. Einzelne Endpunkte je Änderung, nacheinander – verworfen: mehrere Versionen, halbe Zustände bei Netzabbruch.
3. App schickt fertige Einheit, Server übernimmt – verworfen: Server müsste Werten der App glauben, Rechenlogik doppelt in Swift und TS.

## Server

### API `PUT /api/v1/me/plans/{id}/einheiten/{einheitKey}`

Rumpf:
```json
{ "positionen": [
  { "key": "0", "exerciseId": "…", "modelId": "…", "saetze": 4, "wdhVon": 6, "wdhBis": 8, "pauseSek": 120 },
  { "key": null, "exerciseId": "…", "modelId": "…" },
  { "key": "5", "exerciseId": "…", "modelId": "…", "dauerMin": 20 }
] }
```
- Reihenfolge der Liste = neue Reihenfolge. Fehlende alte Schlüssel = entfernt. `key: null` = neu.
- Werte sind optional; fehlt einer, gilt bei bestehender Position ihr alter Wert (bei geänderter Übung siehe D3), bei neuer der Standardwert.
- 1–20 Positionen, Schlüssel eindeutig, jeder nicht-null Schlüssel muss in der aktiven Version der Einheit stehen.
- Antwort 200: neue aktive Planversion (wie `ordnen`). Fehler wie `ordnen`/`swap`: fremder/nicht aktiver Plan 409, ungültig 422, Übung nicht im Studio/Katalog 422 mit eigener Meldung, „meiden“-Bereich 422 mit eigener Meldung.

### Domain `ersetzePlanEinheit(client, userId, planId, { einheitKey, positionen })`

Neu in `packages/domain/src/trainingsplan.ts` (oder eigene Datei `plan-einheit-ersetzen.ts`), Reinfunktion `baueEinheit(alt, eingabe, katalogInfos, vorgaben)` getrennt testbar:

- **Grenzen:** saetze 1–10 (ganz), wdhVon 1–50, wdhBis wdhVon–50, pauseSek 0–600 (ganz, wie `swap`), dauerMin 5–120. Cardio hat wdh null, saetze 1, pause 0. *(Claudes Entscheidung: der Server nimmt jeden Wert 0–600; die Stufen sind nur Sache des Pickers.)*
- **Tausch, Feld für Feld:** Sätze, Wdh, Pause bleiben von der Stelle (D3). typ, baustein-Fallback, hauptmuskeln kommen von der neuen Übung. **Aufwärmsatz** folgt dem typ der neuen Übung (mehrgelenk → ja), weil er zur Übung gehört, nicht zur Stelle. **Reserve** bleibt von der Stelle. Kraft ↔ Cardio: alle Werte aus den Vorgaben der neuen Art. Ein Wechsel mehrgelenk ↔ isolation ist kein Artwechsel. *(Claudes Entscheidung.)*
- **Art einer Übung:** aus `exercises` (`plan_typ`, `plan_baustein`, Primärmuskeln). Cardio = `plan_baustein = 'cardio'`.
- **Standardwerte (neu oder Artwechsel):** `tauschVorgaben({ziel, erfahrung, anfaengerBeendet})` aus der Planeingabe für wdh/reserve/pause/aufwaermsatz nach `typ`; Sätze = `zielprofil(...).saetze`; Cardio `dauerMin` 20.
- **Reserve und Aufwärmsatz** kommen nie vom Client: bei bestehender Position bleibt der Wert; bei neuer Übung/Artwechsel aus den Vorgaben.
- **Felder vom Server, nie vom Client:** baustein, typ, hauptmuskeln, rolle.
  - baustein/typ/bereiche: `exercises.plan_baustein`/`plan_typ`/`plan_bereiche`. **Übungen ohne diese Merkmale lehnt der Server ab** (422, Code `uebung_ohne_planmerkmale`), weil sonst der „meiden“-Check der Bereiche ins Leere liefe (Entscheidung Tim 16.11.). Heute tragen sie nur 46 von 162 Katalogübungen; die übrigen 116 werden in einem **eigenen Schritt vor P4** im Katalog (`catalog/gymtavo.json`, Feld `plan`) verschlagwortet und von Tim geprüft. Danach ist die freie Wahl vollständig, ohne Änderung an P4.
  - rolle: bestehende Position mit gleicher Übung behält ihre; getauscht → behält die der Stelle, außer Cardio ↔ Kraft: dann `cardio` bzw. `ergaenzung`; neu → `ergaenzung` (Cardio: `cardio`).
- **Neue Schlüssel:** `max(numerische Schlüssel der alten Version) + 1`, fortlaufend. Gewichte erben nur bei gleichem Schlüssel **und** gleicher Übung (`plangewichte.ts`), daher unschädlich.
- **geschaetzteMinuten:** vollständig neu gerechnet wie im Generator (Aufwärmen + Σ `uebungMinuten(typ, saetze)` + Cardio-Dauer). `minutenNachOrdnen` entfällt für diesen Weg.
- Danach wie `ordnePlanEinheit`: `uebernehmePlanGewichte`, `initialisierePlanGewichte`.

### Datenbank – Migration `0075_plan_einheit_ersetzen.sql`

`replace_training_plan_einheit(p_plan_id uuid, p_einheit_key text, p_positionen jsonb, p_minuten numeric) returns training_plans`, `security definer`, Muster von 0073/0070:
- auth, Besitz, Advisory-Lock `'training_plans:'||user||':'||studio`, `FOR UPDATE`, Status `aktiv` + Katalog-Studio, sonst `plan_nicht_annehmbar`.
- Prüft je Position Form und Grenzen (wie oben), Schlüssel eindeutig, `training_plan_pruefen` für jedes Modell/Übungs-Paar, „meiden“-Bereiche aus `training_limits`.
- Leitet `hauptmuskeln` aus `exercises.muscles` (primär) ab, wie `swap`.
- Neue Version (max+1, alte → `ersetzt`), kopiert `regel_version, eingabe, struktur, gruende, wochenraster`, ersetzt nur diese Einheit.
- `order_training_plan_einheit` (0073) bleibt unangetastet, die App ruft es nur nicht mehr auf. `swap` bleibt für den Tausch im laufenden Training.

## App (iOS)

- **`Uebungskarte`** (neu, `DesignSystem/Components/`): Modell aus `PlanZeilenModell` + Werte-Chips (Variante A). Optional rechts ein Griff (Bearbeiten) oder nichts (Ansehen). Markierung „statt X“ / „neu“ und grüne Chips für geänderte Werte.
- **`PlanEinheitView`** (Ansehen, Tafel 2): eine `ScrollView` für die ganze Seite, Übungen als `Uebungskarte`, Überschrift „N ÜBUNGEN · IN DIESER REIHENFOLGE“, Rest wie heute.
- **`PlanEinheitBearbeitenView`** (Tafel 3): die ganze Seite scrollt (Titel scrollt mit; kein `List` mehr unter festem Kopf). Ordnen per Griff (ziehen), Entfernen per Wischen nach links (min. eine bleibt), Tipp auf Karte → Anpassen-Blatt, unten gestrichelte Karte „Übung hinzufügen“. Kein rotes Minus, kein Tausch-Icon auf der Karte.
  - Umsetzung des Ziehens in einer ganzen Seite: `List` mit dem Kopf als erste Zeile/Section-Header (scrollt mit) ist erlaubt; Hauptsache, die ganze Seite scrollt. *(Builder entscheidet.)*
- **Anpassen-Blatt** (Tafel 4, neu): Sätze (Stepper 1–10), Wdh von–bis (zwei Picker, bis ≥ von), Pause (Picker aus `resttimerStufen` plus 150 s, plus der aktuelle Wert, falls er in keiner Stufe liegt – Öffnen und Schließen ändert nie etwas); bei Cardio nur Dauer. Im Kopf der Bearbeiten-Seite steht die geschätzte Dauer („ca. 55 min“), lokal mitgerechnet; keine Warnung bei Überschreiten des Zeitbudgets. Hinweis „Reserve und Aufwärmsatz legt der Plan fest.“ Knöpfe „Übung tauschen“, „Aus der Einheit entfernen“ (rot, nur wenn > 1), Hauptknopf „Übernehmen“.
- **Tauschen** (Tafel 5): Kasten „DU ERSETZT <alt>“ mit Thumbnail und „Sätze · Wdh bleiben“; Abschnitt „PASST AN DIESE STELLE“ (`PlanTausch.kandidaten`, wie heute); darunter „ODER EINE ANDERE ÜBUNG“ mit der Auswahl aus dem freien Training (`GeraeteAuswahlView` als Sheet wie `zirkelAuswahl` in `TrainingRootView`), Ergebnis → (exerciseId, catalogModelId). Bei Geräten mit mehreren Übungen die vorhandene Übungswahl.
- **Hinzufügen:** dieselbe Auswahl ohne „DU ERSETZT“ und ohne Vorschläge.
- **`PlanEinheitBearbeitung`** wird vom Schlüssel-Modell zum Positionsmodell: Liste von Entwurfspositionen (alter Schlüssel oder neu, Übung, Werte, Markierungen), `geaendert`, `verschieben`, `entfernen`, `hinzufuegen`, `tauschen`, `werteSetzen`. Anzeige der Standardwerte für Neues lokal aus der Planeingabe vorab (dieselben Tabellen wie die Domain sind nicht nötig: die App zeigt bei neuen Positionen „Standard“ bis zum Speichern **oder** rechnet die Werte nach denselben Regeln vor) *(Builder entscheidet, Hauptsache die Antwort des Servers gilt danach).*
- **`APIClient.ersetzePlanEinheit`** statt `ordnePlanEinheit`.
- „Abbrechen“ heißt immer „Abbrechen“ (`hatGetauscht`-Sonderfall entfällt).
- Einheitsname: rechnet die App wie heute aus den Muskeln; passt sich nach dem Speichern an.

## Nicht in P4

- Training-Tab-Karten und `PlanZeile` in `PlanKarte` (das ist P3; P3 übernimmt `Uebungskarte`).
- Ändern von Reserve/Aufwärmsatz, „Plan-Vorschlag wiederherstellen“, Änderungen „nur heute“.
- Löschen der alten `ordnen`-Route/Funktion.

## Tests (zuerst rot)

- Domain (vitest): `baueEinheit` – Ordnen/Entfernen, neue Schlüssel, Tausch übernimmt Werte, Artwechsel → Standardwerte, Grenzen → Fehler, Reserve/Aufwärmsatz nicht vom Client, Minuten neu gerechnet, fehlender plan_baustein/plan_typ.
- Integration (`tests/integration`, lokales Supabase): RPC schreibt eine Version, Lock/Status, `training_plan_pruefen`, „meiden“, fremder Plan 409; API-Route 200/409/422.
- iOS (`FitnessMemberTests`): `PlanEinheitBearbeitung` (alle Operationen, `geaendert`, Abbrechen), Werte-Grenzen des Blatts, `Uebungskarte`-Modell (Chips-Text, Cardio).

## Auswahl: was wählbar ist

- Wählbar sind Übungen an Stationen mit Katalogmodell (`catalogModelId`) **und** mit Plan-Merkmalen. Andere erscheinen in der Auswahl ausgegraut mit „Nicht im Plan möglich“ (kein Tipp). Studio-eigene Geräte für Pläne zu öffnen, ist ein eigenes Paket. *(Claudes Vorschlag, von Tim noch nicht ausdrücklich bestätigt.)*

## Abhängigkeiten

1. PR #102 (training-flows) gemergt, 0073 auf Prod.
2. Katalog-Verschlagwortung der 116 Übungen (eigener PR, Tim prüft die Liste) – nicht blockierend für den Code, aber für den vollen Umfang von D1.

## Claudes Entscheidungen (zu prüfen)

- Neue Position bekommt Rolle `ergaenzung`.
- Grenzen: Sätze 1–10, Wdh 1–50, Pause 0–600 s, Cardio 5–120 min.
- Pause-Picker mit 150 s und dem aktuellen Wert; Tausch: Aufwärmsatz nach neuer Übung, Reserve bleibt.
- Kein Hinweis bei Überschreiten des Zeitbudgets, nur die Minuten im Kopf.
