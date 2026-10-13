# Testnotizen 12.10. (Abend) – Satzseite, Countdown, Startwerte je Gerät

## Kontext

- **Quelle:** Testsitzung 12.10., 19:46 Uhr (`sitzung.md`, ohne Screenshots), iPhone14,4, iOS 26.6.2, Stand `741d497`, 7 Notizen.
- **Inhalt:**
  - #1: „Übung starten“ im Start-Drawer unten bündig.
  - #2: Der Countdown-Ring ist nach den 5 Sekunden nicht voll.
  - #3: Startwerte je Gerät realistisch statt 0, mit realistischen Schritten.
  - #4, #6, #7: Beschriftungen und Knöpfe in der Pause.
  - #5: „Übung abschließen“ während der Eingabe fragt nach dem offenen Satz.

**Vorgehen:**
- Ablauf nach Skill `finetuning`, für iOS übertragen wie in `2026-10-12-testnotizen-member-app.md`.
- Branch `claude/testnotizen-1210-satzseite` von `master`.
- Je Etappe zuerst ein roter Test (Vitest bzw. Swift Testing), dann die Umsetzung, dann ein Commit.
- Kommentare verweisen auf „(Testnotiz 12.10., #n)“. Gemeint ist die Abendsitzung 19:46. Die Morgensitzung (Kabelzug, Kategorien) hat andere Nummern; wo es zu Verwechslungen käme, steht „abends“ dabei.
- **Einschränkung:** Diese Runde lief in einer Cloud-Session unter Linux. Dort gibt es weder Swift noch Xcode. Die Swift-Tests sind geschrieben, aber erst auf dem Mac oder in der CI gelaufen. Vitest, Typecheck und Build laufen hier.

### Rückfragen (beantwortet: alle Empfehlungen)

- **A, #3, Startwerte:**
  - Neues Katalogfeld `load_start` je Gymtavo-Typ, Spalte `equipment_models.load_start` (nullbar).
  - Realistische `load_step` im Katalog: Hanteln 1 kg, Geräte, Kabel und Stangen 2,5 kg. Cardio bleibt.
  - Studiomodelle tragen keinen eigenen Startwert und erben den ihres Gymtavo-Typs. Der Server löst das im Bootstrap auf, wie bei der Gruppe, aber nur bei gleicher Einheit.
  - Die App startet mit: letzter Satz → `loadStart` → Minimum.
  - Das ist eine bewusste Ausnahme von designsystem §8 („Beim ersten Mal schlägt gymodo kein Gewicht vor“). Der Startwert ist ein Ausgangspunkt je Gerät, keine Empfehlung je Person.
  - Später möglich: Vorschläge aus anderen Übungen. Nicht in dieser Runde.
- **B, #5:** Ein Drawer mit „Satz speichern“ und „Satz verwerfen“. Danach geht es wie bisher weiter: Bei mehreren Übungen am Gerät kommt die Frage nach der weiteren Übung, sonst geht es zurück zum Training. Wegwischen bricht ab, die Räder bleiben stehen.
- **C, #7:** „Nächste Übung“ tut, was „Abschließen“ tat. Auch im Zustand „Sätze geschafft“ heißt der Knopf so.
- **D, #2:** Der Ring füllt sich fließend über die 5 Zählsekunden und ist bei „Los!“ voll.

## Etappe 1 – Pause: „± kg“, „Nächste Übung“, „Nächster Satz“ (#4, #6, #7)

- **Ursache:** `PausenRad` hat drei kleine Knöpfe („+30 s“, „Gewicht“, „Abschließen“) und „Weiter“ als einzige Hauptaktion.
- **Änderung:**
  - #4: „Gewicht“ heißt „± kg“. Die Einheit kommt vom Gerät, am Laufband also „± km/h“. Das Accessibility-Label bleibt „Gewicht für den nächsten Satz ändern“.
  - #6/#7: „Abschließen“ fällt aus der Zeile. Neu ist ein zweiter großer grüner Knopf „Nächste Übung“ mit derselben Aktion.
  - „Weiter“ heißt „Nächster Satz“ und bleibt ganz unten, wo der Daumen vom Sichern her liegt (Testnotiz 06.10., #7). „Nächste Übung“ steht darüber.
  - Zwei Akzentflächen sind eine bewusste Ausnahme von designsystem §2 und hier ausdrücklich gewünscht. Grund: Wer im Zirkel trainiert, wechselt nach jedem Satz die Übung.
  - Im Zustand „Sätze geschafft“ heißt „Übung abschließen“ ebenfalls „Nächste Übung“ (C).
- **Test zuerst:** `UebungsstartTests`: `PausenRad.gewichtTitel(.kg) == "± kg"`, `(.kmh) == "± km/h"`. Die übrigen Beschriftungen sind feste Texte, die prüft der Sichtcheck.

## Etappe 2 – Countdown-Ring voll bei „Los!“ (#2)

- **Ursache:**
  - `Zeitring` liest `Resttimer.fortschritt` über die ganze Dauer von 6 s, also über 5 Ziffern und „Los!“.
  - Der Wert steigt in ganzen Sekunden (`restsekunden` rundet auf), und die 1-s-Animation läuft ihm hinterher.
  - Bei „Los!“ steht der Ring daher bei 4/6 bis 5/6. Voll wird er nie, weil die Räder vorher kommen.
- **Änderung:**
  - `Startcountdown.fortschritt(start:jetzt:)` ist fließend über `zaehldauer = 5` s und ab da 1.
  - `Zeitring` bekommt optional eine eigene Fortschrittsfunktion. Mit ihr läuft die TimelineView im Animationstakt statt im Sekundentakt. So gibt es keine Nachlaufanimation, und Bogen und Ziffer lesen dasselbe Datum.
  - Mit Reduce Motion bleibt es beim Sekundentakt.
  - Die Pause bleibt unverändert.
- **Test zuerst:** `UebungsstartTests`: 0 → 0, 2,5 s → 0,5, 5 s → 1, 6 s → 1, vor dem Start → 0.

## Etappe 3 – „Übung starten“ unten bündig (#1)

- **Ursache:** Mit Einweisung hat der Drawer volle Höhe (`.large`). `StartwerteSchritt` steht oben bündig, darum hängt „Übung starten“ mitten im Drawer statt in der Daumenzone. Allein (bekannte Übung) ist der Drawer so hoch wie der Inhalt, dort sitzt der Knopf schon unten.
- **Änderung:** Im mehrschrittigen Ablauf schiebt ein `Spacer` den Knopfblock nach unten, wie auf der Satzseite. Allein bleibt es ohne Spacer, sonst misst `onGeometryChange` die volle Höhe und der Drawer wächst.
- **Test:** keiner, reines Layout. Prüfung im Sichtcheck.

## Etappe 4 – Satz speichern oder verwerfen vor dem Abschluss (#5)

- **Ursache:** „Übung abschließen“ unter den Rädern führt sofort zur Frage oder zurück zum Training. Der eingestellte, noch nicht gesicherte Satz geht dabei kommentarlos verloren, obwohl man erwarten kann, dass er gespeichert wird.
- **Änderung:**
  - `GeraetModel.abschlussFragtNachSatz` gilt in der Phase `eingabe`. In Pause und „Sätze geschafft“ ist der letzte Satz schon gesichert, dort bleibt der Weg wie er ist.
  - Neuer Drawer `SatzOffenSheet` mit „Satz N speichern“ (Akzent) und „Satz verwerfen“ (sekundär).
  - Speichern ruft `satzSichern` auf. Danach folgt derselbe Weg wie bisher, über `onDismiss`, weil SwiftUI zwei Sheets nur nacheinander zeigt.
  - Lehnt das Sichern ab (Ortswechsel-Konflikt), schließt der Drawer, und die Satzseite zeigt den Grund wie beim normalen Sichern. Weiter geht es dann nicht.
- **Test zuerst:** `GeraetModelTests`: `abschlussFragtNachSatz` ist in `eingabe` wahr, nach einem gesicherten Satz (Pause) falsch, im Countdown falsch.

## Etappe 5 – Startwert und Schritt je Gymtavo-Typ (#3)

- **Ursache:** Alle 52 aktiven Typen stehen auf `load_min 0`, `load_step 1`. Ohne Historie startet das Rad bei `loadMin`, also bei 0 kg.
- **Domain/Katalog:**
  - `geraetetypSchema`: `load_start: zahl ≥ 0, nullable, default null`.
  - `querPruefen`: Der Startwert liegt in `[load_min, load_max]` und auf dem Raster.
  - `gymtavo-katalog.test.ts`: Jeder aktive Typ der echten Datei hat einen Startwert.
- **Migration `0052_startbelastung.sql`:** `equipment_models.load_start numeric`, nullbar, mit Check `load_start >= load_min`.
- **Import:** `load_start` in `GeraetetypZeile`, `GERAETETYP_FELDER`, Zeilenbau und Ist-Select.
- **Bootstrap:** `loadStart` je Modell. Ein Studiomodell erbt vom Gymtavo-Typ, wenn die Einheit gleich ist (`startDesModells`). Sonst ist der Wert null.
- **iOS:**
  - `EquipmentModel.loadStart` und `Catalog.EquipmentType.loadStart` sind optional, für ältere Server und Caches.
  - `GeraetModel` startet beim Öffnen und beim Übungswechsel mit letzter Satz → `loadStart` → Minimum. Gerastet wird wie bisher.
- **Werte im Katalog (kg, Schritt):**
  - Hantel 8 / 1. SZ-Stange 15 / 2,5. Langhantel 20 / 2,5. Kabelzug 10 / 2,5.
  - Pressen und Beinpressen 40–50, Brust und Rudern 20–25, Isolation für Arme und Schultern 10–15. Alles mit Schritt 2,5.
  - Cardio: Laufband 6,0 km/h, sonst Level 5. Die Schritte bleiben.
- **Test zuerst:**
  - `katalog-datei.test.ts`: Ein Startwert unter dem Minimum oder neben dem Raster gibt einen Fehler. Ohne Angabe ist er null.
  - `katalog-plan.test.ts`: `load_start` erscheint als geändertes Feld.
  - `bootstrap.test.ts`: `startDesModells` nimmt den eigenen Wert, sonst den geerbten bei gleicher Einheit, sonst null.
  - `GeraetModelTests`: ohne Historie `loadStart` (gerastet), mit Historie der letzte Satz.
- **Für Prod (nur auf Freigabe):** Migration 0052 und danach `pnpm catalog:import`. Dabei gilt wieder der Hinweis zu den Herstellerfotos aus dem Plan vom 12.10. (Import aus einer Kopie ohne `products`).

## Geprüft

_nach der Umsetzung ausfüllen_
