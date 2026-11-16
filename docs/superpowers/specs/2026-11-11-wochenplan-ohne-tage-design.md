# Wochenplan ohne feste Tage (P2) – Design

**Stand:** 11.11.2026 · **Quelle:** Testnotizen 10.11. #8–#10 (`docs/superpowers/plans/2026-11-10-testnotizen-pakete.md`, P2), Logikfragen mit Tim am 10./11.11. (alle Empfehlungen angenommen), Designwahl am 11.11. (Leinwand „Plan-Woche Varianten“, Fläche „Gewählt · Kalender B + Karten A“).

**Ersetzt:** die festen Kraft-/Cardio-/Kurs-Tage aus PR #96 (Plan `2026-10-28-trainingsplan-wochenplan-tab.md`, E2–E4, E7) und die Slot-Regeln aus `2026-11-05-ux-vereinheitlichung-design.md` §1.1 (Start nur am geplanten Tag) und §1.3 (verpasst/verschoben).

## 1. Warum

Tim (Notiz #8): Tage festzulegen ist „verkopft“. Man plant, **was** diese Woche ansteht (z. B. 2× Kraft, 1× Cardio 30 min), nicht **wann**. Erledigt = Haken dran. Damit gibt es kein „verpasst“. Was am Sonntag nicht mehr geht, bleibt stehen; Montag beginnt die Woche neu. Ausnahme: Kurse haben ihren festen Termin. Der Kalender bleibt, zeigt aber nur Geleistetes und Kurse (#10). „Einheiten“ heißen im Plan „Kraft“ (#9).

**Erfolg:** Wer die App öffnet, sieht die Woche als Liste von Haken, die sich durch Trainieren von selbst füllen. Niemand wird für einen ausgelassenen Dienstag gerügt.

**Anti-Ziele (wäre ein Fehlschlag, auch wenn es technisch läuft):**
- irgendwo „verpasst“, rote/gestrichelte Versäumnis-Marken oder Übertrag in die nächste Woche
- ein Wochentag, den man wählen muss, um trainieren zu dürfen
- Cardio nach dem Krafttraining, das nicht als Cardio zählt

**Nicht in diesem Paket:** Plan-Rotation/Mini-Zirkel (eigene Session), Kartenaussehen der Trainings-Startseite (P3), Einheit-Seite und Übungszeilen (P4), Wischen im Home-Kalender (P6 #1).

## 2. Entscheidungen (mit Tim abgestimmt)

| # | Frage | Entscheidung |
|---|---|---|
| 1 | Was zählt als Kraft | Jedes **beendete** Training (`completed_at` gesetzt) mit mindestens einem Kraftsatz (Satz ohne Cardiowerte) – Plan-Einheit **oder** freies Training. Jedes Training = ein Haken. Mehr als das Ziel wird gezeigt, ohne Strafe. Die Reihenfolge der Plan-Einheiten (A → B → A, F5, `naechsteEinheitKey`) läuft unverändert weiter; freies Training zählt als Kraft, rückt die Reihenfolge aber nicht weiter. |
| 2 | Cardio | Ziel = **Anzahl × Minuten pro Einheit** (z. B. 1× 30 min). Erledigt automatisch, wenn die Cardio-Sätze **eines** beendeten Trainings zusammen ≥ Zielminuten ergeben (Summe `dauer_s`); Minuten aus verschiedenen Trainings werden nicht addiert. Zusätzlich von Hand abhaken (z. B. Laufen draußen). Ein Training kann zugleich Kraft und Cardio abhaken. Ein Training gibt höchstens einen Cardio-Haken. |
| 3 | Wochenwechsel | Woche Mo–So in der Zeitzone des Studios (wie heute, E1). Montag startet neu, kein Übertrag, kein „verpasst“. Start mitten in der Woche: volles Ziel. |
| 4 | Kurse | Nur aus Buchungen (gebucht, nicht abgesagt), fest am Tag. Zählen **nicht** zum Wochenziel. Nach Kursbeginn mit Haken. `kurs_tage` fällt aus der Logik. |
| 5 | Kalender | Vergangenheit/heute: nur Geleistetes (Kraft, Cardio, Kurs). Zukunft: nur gebuchte Kurse. Keine geplanten Einheiten, kein „verpasst“. Woche/Monat bleibt, Filter **Alle / Kraft / Kurse / Cardio**. Überall im Plan „Kraft“ statt „Einheiten“. |
| 6 | Serie und Home | Serie = Wochen in Folge mit mindestens einem Training **oder** Cardio-Haken (von Hand) **oder** begonnenem gebuchten Kurs. Home zeigt „Kraft 1/2 · Cardio 0/1“ statt „X von Y Tagen“. „Training starten“ für die nächste Einheit immer, nicht nur am geplanten Tag. |
| 7 | Datenmodell | Neue Profilspalten `kraft_pro_woche`, `cardio_pro_woche`, `cardio_minuten`, einmalig aus den Tageslisten befüllt. `kraft_tage`, `cardio_tage`, `kurs_tage`, `training_plans.wochenraster` bleiben in der DB, werden nicht mehr gelesen (späteres Aufräumen in eigener Migration). Generator nimmt die Kraft-Anzahl direkt (Regelversion 1.4.0). Auto-Cardio wird aus `workout_sets.dauer_s` berechnet, nicht gespeichert. `cardio_checks` bleibt für Handhaken, ohne „einer pro Tag“. `weekly_days` wird beim Speichern auf Kraft + Cardio gesetzt. |

## 3. Wochenansicht (Plan-Tab, Ansicht „Woche“)

Vorlage: Leinwand-Fläche „Gewählt · Kalender B + Karten A“. Von oben:

1. **Kopf** wie heute: „PLAN“, Umschalter Woche/Monat. Filterleiste Alle / Kraft / Kurse / Cardio wie heute (nur sichtbar, wenn es Kurse oder Cardio gibt).
2. **Wochenzeile** „KW 46 · 9.–15. Nov“, Wochen blättern wie heute (zurück bis Planbeginn, vor bis +4 Wochen).
3. **Wochenstreifen** (aus Variante B): sieben Tage. Ein Tag mit Geleistetem trägt das Symbol im Akzentring (Hantel = Kraft, Cardio-Symbol, Kurs-Symbol; bei mehreren Arten das erste nach Kraft > Kurs > Cardio plus kleiner Punkt). Heute = weiß gefüllt. Gebuchter, noch nicht begonnener Kurs = gestrichelter Ring. Sonst nur die Zahl. **Keine Zähler** über oder neben dem Streifen (Tim: „1/2 0/1 oben lassen wir weg“). Tippen auf einen Tag mit Inhalt öffnet ein Blatt mit dem, was an dem Tag war (Training → `SessionDetailView`, Kurs → Kursdetail) – *meine Entscheidung*.
4. **„DIESE WOCHE“** (Karten aus Variante A), Reihenfolge:
   - **Kraft erledigt**: je beendetes Kraft-Training eine Karte, älteste zuerst. Links Muskelbild der Einheit (freies Training: Hantelsymbol), Titel „Kraft A · Ganzkörper“ bzw. „Freies Training“, darunter „erledigt Mo, 9. · 58 min“, rechts gefüllter Akzent-Haken. Tipp → `SessionDetailView`.
   - **Kraft offen**: `max(0, kraftProWoche − erledigt)` Karten. Inhalt = die nächsten Einheiten der Reihe ab `naechsteEinheitKey` (k-te offene Karte = Einheit an Position `(i + k) mod n`). Die erste trägt „ALS NÄCHSTES“ und Akzentrand. Rechts leerer Kreis. Untertitel „7 Übungen · ca. 63 min“. Tipp → `PlanEinheitView` (Starten wie heute nur für die nächste Einheit – *meine Entscheidung*, P3/P4 können das ändern).
   - **Cardio erledigt**: je Haken eine Karte, Cardio-Symbol in Akzentgrün. Automatisch: „nach Kraft B · 32 min“ bzw. „Ruderergometer · 31 min“ (Tipp → Training). Von Hand: „abgehakt Di, 10.“ mit „Rückgängig“.
   - **Cardio offen**: `max(0, cardioProWoche − erledigt)` Karten „Cardio · 30 min“, Untertitel „zählt auch nach dem Krafttraining“, Knopf „Abhaken“ (setzt einen Handhaken für heute).
5. **„KURSE“**: gebuchte, nicht abgesagte Kurse der Woche, Datumskachel links (gestrichelt solange zukünftig, mit Haken nach Beginn), Name, „18:00 · gebucht“. Ohne Kurse entfällt der Abschnitt.
6. Unten: Knopf **„Woche anpassen“** (ersetzt „Einheit oder Kurs einplanen“).

**Vergangene Wochen** (zurückgeblättert): nur erledigte Karten und begonnene Kurse; keine offenen Karten, kein Hinweis auf Fehlendes. **Künftige Wochen**: nur gebuchte Kurse und ein ruhiger Satz „Diese Woche: 2× Kraft, 1× Cardio“ – *meine Entscheidung*.

**Filter:** Kraft blendet Cardio/Kurse aus (Streifen und Karten), entsprechend Kurse und Cardio.

**Monat:** gleiches Gitter wie heute, gleiche Marken wie der Wochenstreifen, Legende ohne „verpasst“ (Kraft / Kurs / Cardio). Unter dem Gitter die Inhalte des gewählten Tags.

**Ohne Plan:** wie heute (Kurse + PlanEinrichtenKarte); Kraft-Karten entfallen, Cardio-Karten erscheinen, wenn ein Cardio-Ziel gesetzt ist.

## 4. „Woche anpassen“ (ersetzt Einplanen-Sheet und Wochentage)

Blatt mit drei Zählern und den Cardio-Arten:
- Kraft pro Woche 1–7
- Cardio pro Woche 0–7
- Cardio-Minuten 10–90 in 5er-Schritten (nur sichtbar bei Cardio ≥ 1), Vorgabe 30
- Cardio-Arten (wie heute)

Speichern = `PUT me/training-profile` mit den neuen Feldern, danach Bootstrap neu (wie heute). Der Plan wird **nicht** neu erzeugt (F14). Hinweistext: „Du legst fest, wie oft – nicht wann. Montag beginnt die Woche neu.“

**Onboarding:** Der Schritt „Kurstage“ entfällt. Der Cardio-Schritt fragt Anzahl, Minuten, Arten. „Deine Woche“ zeigt statt Tagen die Zusammenfassung „2× Kraft · 1× Cardio 30 min · Kurse nach Buchung“ mit denselben Zählern. Tauschen von Tagen entfällt.

## 5. Home

- Wochenstreifen: Marken nur aus Geleistetem und gebuchten Kursen (gleiche Funktion wie im Plan-Tab), keine geplanten Einheiten.
- Unter der Serie statt „X von Y Tagen“: „Kraft 1/2 · Cardio 0/1“ (Cardio-Teil nur mit Cardio-Ziel). Ohne Plan und ohne Ziel wie heute.
- „Nächste Einheit“: die Einheit `naechsteEinheitKey`, „Training starten“ immer. `TrainingstageFestlegenZeile` entfällt.
- Serie (Server, `serienstand`): eine Woche zählt, wenn es mindestens einen Trainingsbeginn **oder** einen Handhaken in `cardio_checks` **oder** einen begonnenen, gebuchten, nicht abgesagten Kurs gibt. Die übrigen Regeln (laufende Woche erst ab erstem Eintrag, keine Zukunftstage) bleiben. `trainedDays` enthält dann alle drei Arten. Kurse (*meine Entscheidung*): eigene Buchungen in **allen** Studios des Mitglieds, ausgeschlossen sind vom Mitglied stornierte Buchungen und vom Studio abgesagte Termine (`course_sessions.status = 'cancelled'`); Grenze ist der Kursbeginn. Falls RLS das Lesen über Wochen hinweg nicht hergibt, eine schlanke Lese-Funktion in 0072.

## 6. Datenmodell (Migration 0072)

`training_profiles`:
- `kraft_pro_woche smallint null check (between 1 and 7)`
- `cardio_pro_woche smallint not null default 0 check (between 0 and 7)`
- `cardio_minuten smallint not null default 30 check (between 10 and 180)`
- Befüllen: `kraft_pro_woche` = `cardinality(kraft_tage)` wenn > 0, sonst Anzahl der `kraft`-Einträge im `wochenraster` des aktiven Plans wenn > 0, sonst `null`. `cardio_pro_woche` = `cardinality(cardio_tage)`.
- Die Overlap-Checks der Tagesspalten bleiben (alte Werte bleiben gültig); neue Schreibwege lassen die Tagesspalten unangetastet.

`cardio_checks`:
- neue Spalte `id uuid not null default gen_random_uuid()`, Primärschlüssel wird `id`; Index `(user_id, day)`. Optional `minuten smallint null check (between 1 and 600)`.
- RLS bleibt (eigene Zeilen, select/insert/delete).

`training_plans.wochenraster`: neue Pläne schreiben `[]`. Die RPCs bleiben unverändert.

Ziel `weekly_days`: Beim Speichern des Profils mit gesetztem `kraft_pro_woche` wird das aktive `weekly_days`-Ziel auf `kraft_pro_woche + cardio_pro_woche` (max. 7) gesetzt bzw. angelegt – im selben Domain-Aufruf.

**Wirksames Kraft-Ziel**, wenn `kraft_pro_woche` null ist: Anzahl der Plan-Einheiten-Tage aus `plan.eingabe.tage`, sonst `weekly_days`, sonst 2. Wird im Bootstrap als `wochenziel` ausgeliefert, damit die App nicht selbst ableitet.

## 7. API

- `GET/PUT me/training-profile`: neue Felder `kraftProWoche`, `cardioProWoche`, `cardioMinuten`. Die Tagesfelder werden weiter gelesen/akzeptiert (alte App), aber von der neuen App nicht mehr geschrieben. `pruefeWoche` läuft nur noch, wenn Tagesfelder mitkommen.
- `me/cardio-checks`: `GET ?from&to` → `{checks: [{id, day, minuten}], days: [...]}` (`days` bleibt für die alte App). Neu `POST {day, minuten?}` → 201 `{id, day, minuten}`; `DELETE ?id`. Das alte `PUT/DELETE ?day` bleibt (PUT legt nur an, wenn der Tag noch keinen Haken hat; DELETE ?day löscht alle des Tages). Tagesprüfung wie heute (nicht später als morgen UTC).
- `me/bootstrap`: `member.plans[]` unverändert plus nichts Neues; `member.wochenziel = {kraft, cardio, cardioMinuten}` (immer, auch ohne Plan, aus Profil/Ziel abgeleitet).
- `me/sessions`: `streak` nach §5. Die Sitzungsliste trägt bereits Sätze mit Cardiowerten; daraus rechnet die App.
- Generator (`trainingsplan-generator.ts`): `GeneratorEingabe.kraftProWoche` ersetzt `kursTage/cardioTage/kraftTage`; Struktur = `strukturFuerTage(kraftProWoche ?? tage)`; kein `wochenraster` mehr (`[]`); Grund `kraft_tage_auf_eins` entfällt für neue Pläne (Text in `PlanWarumText` bleibt für alte). `PLAN_REGEL_VERSION = "1.4.0"`. Der Bestands-Snapshot wird bewusst neu geschrieben und die Änderung im Commit begründet.

## 8. Wochenrechnung in der App

Eine reine Funktion (Swift, Workout/) `PlanWochenStand.berechne(woche:, sitzungen:, erledigt:, cardioChecks:, kurse:, wochenziel:, einheiten:, naechsteEinheitKey:, zeitzone:)` → Liste der Karten (Art, Zustand erledigt/offen, Quelle, Datum) und Tagesmarken für Streifen/Monat. Regeln aus §2/§3. Sie ersetzt `PlanKalender.termine/einheitenAufSlots`, `PlanTabZustand.anzeigeRaster`, „verpasst“ und `istGeplanterTag`. Home und Plan-Tab nutzen dieselbe Funktion (über `PlanKalenderKontext`).

Kraft-Haken (*meine Entscheidung*, präzisiert §2 #1): eine **beendete** Sitzung zählt, wenn sie in `erledigt[]` des Servers steht (Plan-Einheit nach F5, auch eine reine Cardio-Plan-Einheit) **oder** mindestens einen Kraftsatz hat. Titel/Muskelbild aus `erledigt[].einheitKey`, sonst „Freies Training“. Eine laufende Sitzung gibt noch keinen Haken, auch wenn sie die Reihenfolge schon weiterrückt. Die Server-Regel `einheitZaehlt` bleibt unverändert.

Cardio automatisch: je beendete Sitzung Summe `cardio.dauerS` aller Sätze ≥ `cardioMinuten·60` → ein Haken am Ortsdatum von `startedAt`.

Hinweis Verlauf: Die Sitzungsliste reicht 50 Trainings zurück; für die laufende und die Vorwochen genügt das. Ältere Wochen zeigen, was in der Liste liegt (wie heute `verlaufAb`), ohne Lücke als Fehler zu werten.

## 9. Was wegfällt

`PlanKalender` verpasst/verschoben und Slot-Verteilung, `PlanWochentage`, Legende „verpasst“, `TrainingstageFestlegenZeile`, Bedingung „nur am geplanten Tag“ (Home, `PlanEinheitView`), Onboarding-Tagesauswahl und Tauschen, Kurstage-Schritt, `kraftAnzahl/verteileKraft/planeKrafttage` im Generator (Funktionen dürfen bleiben, wenn Tests sie noch brauchen; ungenutzte löschen). Tests, die diese Regeln festschreiben, werden durch Tests der neuen Regeln ersetzt, nicht stillschweigend gelöscht.

## 10. Prüfen und Ausrollen

- Domain: Vitest für Profil (neue Felder, Befüllregel als SQL-Integrationstest), Cardio-Checks (mehrere pro Tag, POST/DELETE id, alte Wege), Serie mit Cardio/Kurs, Generator 1.4.0, Wochenziel im Bootstrap.
- App: Swift-Tests für `PlanWochenStand` (Fälle: Kraft aus Plan und frei, Ziel überschritten, Cardio auto ≥/< Minuten, zwei Trainings je 20 min = kein Haken, Hand-Haken mehrfach, Kurs vor/nach Beginn, Wochenwechsel Montag 00:30 Studiozeit, vergangene/künftige Woche ohne offene Karten), Home-Zeile, Profil-Codierung.
- Simulator: Plan-Tab Woche/Monat, Woche anpassen, Home.
- Stand Prod (geprüft 11.11.): 0069–0071 laufen dort seit 29.10.; `cardio_checks` ist also live und wird mit 0072 umgeschlüsselt (Daten bleiben, `id` per Default befüllt). Die Kompatibilitätswege in §7 bleiben deshalb nötig.
- Migration 0072 auf Prod und API-Deploy **nur mit ausdrücklicher Freigabe von Tim** (per MCP `apply_migration`, wie 0062–0065). Die alte App läuft weiter, weil Tagesspalten und alte Endpunkte bleiben.

## 11. Dem Umsetzer überlassen

Benennung der Swift-Typen und Dateien, Aufteilung in Commits, genaue Symbole (SF Symbols) für Kurs/Cardio, Animationen beim Abhaken, ob `PlanKalenderKontext` umbenannt wird.
