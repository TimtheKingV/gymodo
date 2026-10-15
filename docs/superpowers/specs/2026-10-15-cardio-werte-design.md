# Cardio-Werte – Design (E2)

## Anlass

Testsitzung 14.10., 18:45, Notiz #7 (GeraetView, Ruderergometer):

> Bei Cardiogeräten brauchen wir teils mehrere Einstellmöglichkeiten. Keine Scrollräder, sondern Buttons, die eine Zahleneingabe fordern. Beim Rudergerät gibt es keine Stufe, nur Meter und Zeit. Daher teils unterschiedliche Sachen eingebaut, aber nicht Pflicht. Laufen: Strecke, Zeit, Steigung, Geschwindigkeit.

Die Notizen #5 (Ring „Fertig“) und #6 (Cardio ohne Startwerte) sind als E1 umgesetzt (PR #60). Diese Spec baut darauf auf.

**Hebt auf:** Cardio-Spec `2026-09-21-cardio-geraete-design.md` §10, „mehrere beobachtete Werte je Satz“ – das kommt jetzt. Ebenso die Progression der Cardio-Belastung (§3.1).

## Entscheidungen (Brainstorming 15.10.)

1. **Der Gerätetyp im Katalog legt fest, welche Werte ein Gerät anbietet.** Studio-Modelle erben die Liste und können sie im Portal überschreiben. Das Mitglied sieht nur passende Knöpfe.
2. **Vorbelegung mit den Werten vom letzten Mal** an diesem Gerät. Ohne Vorwert steht „–“, und der Wert wird nicht gespeichert.
3. **Cardio wird nicht mehr gesteigert, nur festgehalten.** Kein Vorschlag unter „Beim nächsten Mal“.
4. **Acht Werte insgesamt:** Zeit, Strecke, Stufe, Geschwindigkeit, Steigung, Watt, Kalorien, Frequenz (Tritt- bzw. Schlagzahl).
5. **Speicher:** eigene typisierte Spalten je Wert (Ansatz A). `load` und `volume` werden für Cardio-Sätze leer. JSON (B) und eine Wertetabelle (C) sind verworfen.
6. **Altdaten werden umgeschrieben und `load`/`volume` dort geleert,** nicht doppelt gehalten. Die Reihenfolge der Auslieferung verhindert, dass eine App bricht (§8).

## Abgrenzung

- Kein Cardio-Diagramm (Tempo, Strecke über Zeit). Der Fortschritt zeigt für Cardio eine Liste.
- Keine Werte vom Gerät oder Sensor (Bluetooth FTMS o. Ä.). Alles wird eingetippt.
- Kein Puls, keine Intervalle.
- Der Sensor zum Zählen von Wiederholungen bleibt an Cardio-Geräten aus, wie heute.

## 1. Die acht Werte

| Schlüssel | Spalte `workout_sets` | Typ | Bereich | Anzeige |
|---|---|---|---|---|
| `zeit` | `dauer_s` | integer | 1–86 400 | `8:30`, ab 1 h `1:05:00` |
| `strecke` | `strecke_m` | integer | 1–200 000 | `850 m`, ab 1 000 m `2,0 km` (eine Nachkommastelle) |
| `stufe` | `stufe` | integer | 0–100 | `Stufe 5` |
| `kmh` | `kmh` | numeric(4,1) | 0–50 | `10,5 km/h` |
| `steigung` | `steigung_pct` | numeric(4,1) | −10–40 | `2,5 %` |
| `watt` | `watt` | integer | 0–3 000 | `142 W` |
| `kcal` | `kcal` | integer | 0–10 000 | `310 kcal` |
| `frequenz` | `frequenz` | integer | 0–300 | `85 /min` |

**Feste Reihenfolge überall** (Knöpfe, Satzzeile): Zeit, Strecke, Stufe, km/h, Steigung, Watt, Frequenz, kcal.

Die Liste der Schlüssel steht einmal in `packages/domain/src/belastung.ts` (`CARDIO_WERTE`) und einmal in Swift (`CardioWert`, `Workout/Belastung.swift`), beide mit Tests auf Gleichheit der Reihenfolge.

## 2. Datenmodell

### 2.1 Gerät

- `equipment_models.cardio_werte text[] not null default '{}'`.
  - Check: jedes Element liegt in der Liste aus §1, ohne Dubletten.
  - **Ein Modell mit nicht-leerer Liste ist ein Cardio-Gerät.** Das ist die einzige Verhaltensregel. `category` und `equipment_group` bleiben reine Anzeige (wie bisher).
- **Vererbung:** Ein Studio-Modell mit leerer Liste und einem Katalog-Typ (`catalog_model_id`) erbt die Liste des Typs. Das geschieht beim Lesen (Bootstrap, Gerätekontext, `recordSet`), wie schon bei `equipment_group` und `load_start`.

### 2.2 Satz

- `workout_sets` bekommt die acht Spalten aus §1, alle nullable, mit Bereichs-Checks.
- `load` und `volume`: `drop not null`.
- **Check `workout_sets_art`:**
  - Kraft: `load is not null and volume is not null` und alle acht Cardio-Spalten leer, oder
  - Cardio: `load is null and volume is null and secondary_load is null` und mindestens eine Cardio-Spalte gesetzt.
- **Check `workout_sets_herkunft_consistent` (0049):** Im Zweig `gemessen`/`korrigiert` kommt `volume is not null` dazu, sonst lässt eine `null`-Auswertung den Check durch. Cardio-Sätze sind immer `eingegeben`.

## 3. Server

### 3.1 `recordSet`

- **Zod:** `load` und `volume` werden optional, dazu ein optionales Objekt `cardio` mit den acht Schlüsseln (Zahlen, Bereiche wie §1; ganzzahlig, wo die Spalte integer ist).
- **Am Cardio-Gerät** (vererbte Liste nicht leer):
  - `cardio` muss mindestens einen Wert haben, und jeder Schlüssel muss in der Liste des Geräts stehen. Sonst 422: „Dieser Wert gehört nicht zu diesem Gerät.“ bzw. „Mindestens ein Wert fehlt.“
  - `load`, `volume`, `secondaryLoad` sind nicht erlaubt (422).
  - **Ausnahme – alte App:** Kommen `load`/`volume` ohne `cardio`, wandelt der Server um:
    - `volume` wird zu `zeit`, wenn die Übung `volume_kind = 'seconds'` hat, und zu `strecke` bei `meters`.
    - `load` (und `secondary_load`) werden je `load_unit` (bzw. `secondary_unit`) zu `stufe` (`level`), `kmh`, `watt`, `steigung` (`pct`) oder `frequenz` (`rpm`).
    - Werte außerhalb der Geräteliste werden dabei verworfen, nicht abgelehnt.
    - Bleibt kein Wert übrig, gibt es 422.
- **Am Kraftgerät:** wie heute. `cardio` ist nicht erlaubt (422).
- `volumeSource` bleibt `eingegeben` für Cardio.

### 3.2 Progression und Abschluss

- `suggestNextLoad` und die Abschluss-Vorschläge überspringen Blöcke an Cardio-Geräten. Für sie gibt es keinen Vorschlag.
- Die Historie, die in die Progression geht, filtert Cardio-Sätze heraus (`load is not null`).

### 3.3 Lesewege

- **`lastSets`/`lastTypeSets` (Bootstrap), `sessions`, Gerätekontext (`HistoryEntry`):**
  - `load` und `volume` werden `number | null`.
  - Dazu `cardio: { zeit?, strecke?, … }` mit den gesetzten Werten.
  - Kein `Number(null)` mehr, das hätte 0 ergeben.
- **Bootstrap und Gerätekontext liefern am Modell `cardioWerte: string[]`,** schon vererbt aufgelöst.
- **`progress` (Bestlast-Diagramm):** nur Sätze mit `load is not null`. Für eine Cardio-Übung liefert es die letzten Einheiten als Liste mit ihren Cardio-Werten (ein Satz je Einheit, der jüngste).

## 4. App – Eingabe

1. **Ablauf:** Am Cardio-Gerät gibt es keine Startwerte (E1). Nach dem Countdown erscheint die Eingabe.
2. **Raster statt Rädern:**
   - Ein Knopf je Eintrag aus `cardioWerte`, in der Reihenfolge aus §1, zwei Spalten.
   - Jeder Knopf zeigt den Namen (Label-Stil, groß geschrieben) und den Wert, z. B. „STRECKE / 2,0 km“, oder „–“.
3. **Vorbelegung:**
   - Erster Satz: der letzte Cardio-Satz an diesem Gerät (bzw. Typ), aus `lastSets`/`lastTypeSets` oder dem Kontext.
   - „Weiterer Satz“: die Werte des eben gesicherten Satzes.
4. **Zahleneingabe:**
   - Ein Tipp öffnet ein Sheet mit Name, Eingabefeld (`.decimalPad` bzw. `.numberPad`), Einheit, „Übernehmen“ und „Leeren“.
   - **Zeit:** zwei Felder Minuten:Sekunden, ein drittes für Stunden erst ab Eingabe ≥ 60 min.
   - **Grenzen wie §1:** Ein Wert außerhalb bleibt im Feld stehen, „Übernehmen“ ist gesperrt, darunter der Hinweis („Höchstens 50 km/h.“).
   - Komma und Punkt werden beide akzeptiert.
5. **Speichern:**
   - „Satz sichern“ ist aktiv, sobald mindestens ein Wert gesetzt ist.
   - Danach Abschluss mit dem Ring „Fertig“ (Satzziel 1, E1).
6. **Lokal:**
   - `LokalerSatz` und `SetWrite` bekommen `cardio: CardioWerte?`; `load`/`volume` werden optional.
   - Alle neuen Felder werden mit `decodeIfPresent` gelesen, alte Dateien (laufende Session, Warteschlange, Verlauf-Cache) dekodieren weiter.
   - Alte, noch nicht gesendete Cardio-Sätze in der Warteschlange gehen unverändert raus; der Server wandelt sie um (§3.1).

## 5. App – Anzeige

- **`Zahlformat.cardio(_:)`:** die gesetzten Werte in Reihenfolge, getrennt durch „ · “, z. B. „8:30 · 2,0 km · Stufe 5 · 142 W“. Für VoiceOver gibt es eine ausgeschriebene Fassung („8 Minuten 30 Sekunden, 2,0 Kilometer, …“).
- **Detail einer Einheit, „Zuletzt“ am Gerät und Abschluss:** Ein Cardio-Satz zeigt diese Zeile statt Belastung × Umfang.
- **Abschluss „Beim nächsten Mal“:** Cardio-Blöcke stehen dort nicht.
- **Home und Übungsfortschritt:**
  - Bestlast-Diagramm und Satzvergleich bleiben Kraft. Cardio-Sätze fallen heraus.
  - Für eine Cardio-Übung zeigt der Fortschritt eine Liste der letzten Einheiten mit Datum und Zeile.
- **Geräteliste „Zuletzt“** (`GeraeteAuswahl`): für Cardio die Zeile statt der Belastung.

## 6. Katalog

- `catalog/gymtavo.json`: Jeder Cardio-Typ bekommt `cardio_values`:

| Typ | Werte |
|---|---|
| Laufband | Zeit, Strecke, km/h, Steigung, kcal |
| Aufrechtes Fahrradergometer, Liegeergometer, Indoor Bike | Zeit, Strecke, Stufe, Watt, Frequenz, kcal |
| AirBike | Zeit, Strecke, Watt, kcal |
| Crosstrainer | Zeit, Strecke, Stufe, Frequenz, kcal |
| Ruderergometer | Zeit, Strecke, Watt, Frequenz, kcal |
| Treppenmaschine | Zeit, Stufe, kcal |
| Ski-Ergometer | Zeit, Strecke, Watt, kcal |

- **`katalog-datei.ts`:**
  - Das Schema kennt das Feld.
  - Kreuzprüfung: Cardio-Typen brauchen eine nicht-leere Liste, andere dürfen keine haben.
- **`katalog-plan.ts`:** Das Feld wird gemappt und landet in der Diff-Liste.

## 7. Portal

- **Formular des Gerätemodells (`ModellBelastungRad` und seine Verwender):** Bei Kategorie Cardio stehen statt des Belastungsrads die acht Werte zum Ankreuzen.
  - Vorbelegt ist die Liste des Typs (bei einem Studio-Modell mit Katalog-Typ) bzw. die eigene.
  - Ist nichts angekreuzt, wird die Liste leer gespeichert und vom Typ geerbt.
  - Ein eigenes Cardio-Modell ohne Typ braucht mindestens einen Wert.
- Die Belastungsfelder bleiben in der DB, werden für Cardio nicht gezeigt und nicht mehr geändert.

## 8. Auslieferung

Jeder Schritt ist einzeln lauffähig, und kein Zwischenstand bricht eine App.

1. **Migration 0054 `cardio_werte`:**
   - Die Spalten an `workout_sets` und `equipment_models` sowie die Checks aus §2.
   - `cardio_werte` für die vorhandenen Katalog-Typen nach §6 setzen (per `update` über die Katalog-Schlüssel).
   - Eigene Cardio-Modelle eines Studios ohne Katalog-Typ (`category = 'cardio'`, `catalog_model_id is null`) bekommen Zeit plus den Wert, der zu ihrer `load_unit` passt (§9).
   - **Altdaten bleiben unberührt.**
   - Danach `pnpm catalog:import`, damit Datei und DB übereinstimmen.
2. **Web-Deploy:** `recordSet` mit Umwandlung (§3.1) und alle Lesewege (§3.3).
   - Alte Apps funktionieren weiter: Ihre Cardio-Sätze werden umgewandelt.
   - Sie lesen weiter `load`/`volume`, die bei alten Sätzen noch gefüllt sind.
3. **App:** Raster, Anzeige, optionale DTOs.
4. **Migration 0055 `cardio_altdaten`:** Alte Cardio-Sätze (an Modellen mit vererbter, nicht-leerer Liste) werden nach der Regel aus §3.1 umgeschrieben, danach `load`/`volume`/`secondary_load = null`.

## 9. Fehlerfälle

- **Wert nicht im Gerät, kein Wert oder Belastung am Cardio-Gerät:** 422 mit Text. Ein Satz aus der Warteschlange wird nach der bestehenden 4xx-Regel verworfen und gemeldet.
- **Werteliste geändert, während ein Satz unterwegs ist:** derselbe 422. Das ist selten und vertretbar.
- **Gerät ohne Liste und ohne Typ, aber Kategorie Cardio** (Altbestand eines Studios): Es gilt als Kraftgerät, bis im Portal Werte angekreuzt sind. Die Migration 0054 setzt für solche Modelle Zeit plus den Wert, der zu ihrer `load_unit` passt.

## 10. Tests

- **Domain (Vitest):**
  - Zod Cardio/Kraft.
  - Prüfung gegen die Geräteliste.
  - Umwandlung der alten Eingabe je `load_unit` und `volume_kind`.
  - Progression überspringt Cardio.
  - Katalog-Kreuzprüfung.
  - `CARDIO_WERTE`-Reihenfolge.
- **Integration (lokales Supabase):**
  - `recordSet` Cardio gültig, Wert außerhalb, ohne Wert, mit Belastung.
  - Umwandlung einer alten Eingabe.
  - Check `workout_sets_art` direkt per SQL (Mischfälle werden abgelehnt).
  - Migration 0055 an einem alten Cardio-Satz.
  - Bootstrap, Sessions und Kontext liefern `cardio` und `cardioWerte`, vererbt.
- **Swift:**
  - Dekodieren alter Dateien und Antworten ohne die neuen Felder.
  - Antworten mit `load: null`.
  - Vorbelegung vom letzten Mal und nach „Weiterer Satz“.
  - Zeit mm:ss ↔ Sekunden.
  - Grenzen der Eingabe.
  - `Zahlformat.cardio`.
  - `CardioWert`-Reihenfolge.
- **Portal:** Form-Parsing der Werteliste, leer = erben.

## Auf dem Gerät (nach Auslieferung)

1. **Ruderer:** Startet ohne Drawer. Das Raster zeigt Zeit, Strecke, Watt, Frequenz, kcal, aber keine Stufe. Zeit und Strecke eintippen, sichern, Ring „Fertig“.
2. **Laufband:** Zeit, Strecke, km/h, Steigung. Beim nächsten Mal sind die Knöpfe vorbelegt.
3. Das Detail der Einheit auf Home zeigt die Zeile „8:30 · 2,0 km · …“.
4. **Alter Cardio-Satz** aus der Zeit vor E2: Im Verlauf steht er als „20:00 · Stufe 5“.
