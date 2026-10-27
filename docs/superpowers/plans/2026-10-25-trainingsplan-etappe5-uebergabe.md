# Trainingsplan Etappe 5 – Übergabe nach Etappe 4

Stand: Etappe 4 (Plangewichte) ist auf Branch `claude/trainingsplan-etappe4` umgesetzt und reviewt (16 Commits seit `9d8b8b1`, nicht gepusht). Die Migrationen `0064` und `0065` liegen **nur lokal**; Prod hat laut Memory bis `0061`, und `0062`/`0063` sind ebenfalls noch nicht angewandt. Plan: `2026-10-25-trainingsplan-etappe4-plangewichte.md`, Spec: `../specs/2026-10-25-trainingsplan-plangewichte-design.md`. Der Haupt-Spec (Abschnitt 6, „Fortlaufende Anpassung“) verweist jetzt auf dieses Spec.

## Was es jetzt gibt

- **Regel `plangewicht.ts` 1.0.0** (`berechnePlanGewicht`, `PLANGEWICHT_ALGO_VERSION`): rechnet aus Zielbereich, Zielreserve, letztem Block und Gerätegrenzen das nächste Zielgewicht je Planposition. Ergebnis nach Steigerung oder Senkung wird auf die Gerätestufe abgerundet und in `loadMin..loadMax` geklemmt; ein Istwert zwischen den Stufen rastet auf die nächste Stufe ein. `progression.ts` bleibt plan-blind und exportiert dafür `uniformLoad`, `Belastungspaar`, `snapToNearestStep`.
- **Grund-Codes** (`PlanGewichtGrund`; `ProgressionReasonCode` in `progression.ts` enthält dieselben Codes): `korridor_oben_erreicht`, `korridor_unten_verfehlt`, `im_korridor`, `problem_gemeldet`, `geraetegrenze_erreicht`, `kein_verlauf`, `daten_uneindeutig`, `letztes_gewicht`, `startschaetzung`, `uebertragung`, `wiedereinstieg`.
- **Start, Übertragung, Wiedereinstieg** (`plangewicht-start.ts`): `schaetzeStartgewicht` (1.0.0, nimmt die Profil-Enums `SEX`/`AGE_BANDS` aus `profil.ts`), `startgewichtAusHistorie`, `uebertragungsFaktor` (3 % je Wiederholung Abweichung, Deckel 20 %), `wiedereinstieg` (Stufen nach Abstand, `WIEDEREINSTIEG_VERSION` 1.0.0). Gerätegrenzen: `Geraetegrenzen`.
- **Migration `0064_plan_gewichte.sql`:** Tabelle `plan_gewichte`, Schlüssel `(plan_id, einheit_key, position_key)` (der Plan nummeriert `position_key` je Einheit, `position_key` allein kollidiert); RPCs `set_plan_gewichte` (stand-gesteuert, idempotent, nur höherer Abschlussstand gewinnt) und `init_plan_gewichte`; Spalte `gewichte_berechnet_at` an der Session. Abschlussregel wie bei den bestehenden Sessions: `completed_at` gesetzt, sonst letzte Aktivität älter als 4 h.
- **Migration `0065_plan_tausch_typ.sql`:** `swap_training_plan_position` bekommt `p_vorgaben` (Bereich, Reserve, Pause der neuen Übung; validiert). Die alte 5-Argument-Signatur ist **entfernt**. Damit übernimmt ein Tausch über die Typgrenze (Mehrgelenk ↔ Isolation) den Bereich der neuen Übung.
- **`plangewichte.ts`:** `aktualisierePlanGewichte` (rechnet die Ziele der nächsten 3 Einheiten, `VORAUSSCHAU_EINHEITEN`; Einheiten mit **offener** Session sind eingefroren, die gerade abgeschlossene zählt für ihren nächsten Durchlauf mit; Historienfenster 43 Tage, seitenweise gelesen), `initialisierePlanGewichte` (Startwerte), `uebernehmePlanGewichte` (Tausch), `ladeZielgewichte`, `zielFuerGeraet`, `vorschlagAusZiel`, `zielSchluessel`, `ohneAbbruch` (Fehler loggen, nicht abbrechen).
- **Auslöser:** `completeSession` (`workout.ts`) ruft nach dem Abschluss `aktualisierePlanGewichte` und danach `initialisierePlanGewichte`; der Bootstrap holt Sessions nach, deren Neuberechnung fehlt (`nachzuholendeSessions`, höchstens 5 je Aufruf; Bedingung: `gewichte_berechnet_at` null oder älter als der Abschlussstand, wegen Wiedereröffnung); `acceptPlan` initialisiert die Startwerte; `tauschePlanPosition` übernimmt Ziele und initialisiert.
- **Bootstrap:** `PlanFuerApp.zielgewichte`, Record mit Schlüssel `"<einheitKey>:<positionKey>"` und Wert `{ load, secondaryLoad, aenderung, grund | null }`. `aenderung` ist die Differenz zum letzten tatsächlich trainierten Gewicht.
- **Vorschläge:** Für Planübungen kommen Vorschläge aus dem Zielgewicht, sonst aus dem letzten Gewicht (`letztes_gewicht`); `progression_suggestions` wird für Planübungen nicht mehr befüllt. Ohne Plan senkt `problem_gemeldet` nicht mehr (G17).
- **iOS:** Gewichtshinweis am Gerät (Startdrawer), z. B. „+2,5 kg, Bereich oben erreicht“. Der Hinweis hängt nur an `aenderung` (nil oder 0 = kein Hinweis), nicht am Grund; bei `im_korridor` und `letztes_gewicht` nur die Zahl. `VorschlagsAnzeige` kennt die neuen Codes `letztes_gewicht`, `startschaetzung`, `uebertragung`, `wiedereinstieg`.
- Tests bei Abschluss: Domain 581, Web 311, Swift 1655 (Task 8); Integrationstests siehe `task-9-report.md` im SDD-Ordner.

## Schnittstellen für Etappe 5 (Textbausteine „Warum so?“)

- Je Position liefert der Bootstrap `zielgewichte["<einheitKey>:<positionKey>"].grund` (oder `null`, wenn noch kein Grund vorliegt) und `aenderung`. Für jeden Grund-Code oben braucht Etappe 5 einen Textbaustein; die Codes sind versioniert über `PLANGEWICHT_ALGO_VERSION`, `STARTSCHAETZUNG_VERSION`, `WIEDEREINSTIEG_VERSION`.
- Die Plan-Begründungscodes der Generatorregel (`beschwerden_*`, `fokus_zweiter_entfallen`, …) bleiben getrennt von den Gewichts-Gründen.
- `PlanWarumView` zeigt bisher nur die Codes; die Gewichtsgründe sind dort noch nicht angebunden.
- Wortlaut des Gewichtshinweises (siehe unten) und die Texte aus Etappe 5 sollten dieselbe Sprache verwenden.

## Offene Punkte

### Aus der Etappe-3-Übergabe (Nr. 3, 4, 6–10), weiter gültig bzw. Stand

3. Widerruf der Beschwerden: erledigt in Etappe 3 (Trigger in `0062` bereinigt Pläne aller Studios). Kein offener Punkt mehr.
4. `accept` und `GET` prüfen die Studio-Mitgliedschaft nicht erneut (ehemalige Mitglieder sehen ihren Verlauf, können offene Vorschläge annehmen).
6. Fill-Positionen: in Etappe 3 mit Rolle `auffuellung` und Mehrgelenk vor Isolation gelöst (Regeln 1.2.0). Kein offener Punkt mehr.
7. Cardio-Position trägt `reserveVon/Bis` und `typ: isolation` ohne Bedeutung; Cardio nimmt immer das erste Gerät (keine Rotation).
8. Fokus kann eine Mehrgelenkübung sein, die eine Isolations-Ergänzung ersetzt (mehr Zeit als die ersetzte Übung).
9. Wochenvolumen-Plausibilitätsprüfung (Spec Abschnitt 3) ist nicht implementiert.
10. Anfängerübergang nach 8 Einheiten und Einheitenzähler: in Etappe 3 umgesetzt (`anfaengerBeendet`). Kein offener Punkt mehr.

### Aus der Etappe-4-Übergabe (Etappe 3), weiter gültig

- **`completeSession` läuft nicht über die Warteschlange:** wer offline beendet, sieht „heute dran“ bis zum Server-Abschluss (≤ 4 h) mit lokaler Zählung.
- **Drei gekoppelte 4-Stunden-Konstanten:** `sessions.ts` (`IDLE_HOURS_UNTIL_AUTO_COMPLETE`), `trainingsplan-bootstrap.ts` (Stillstand) und `WorkoutSessionStore.sessionPause`. Seit `0064` kommt eine vierte Stelle dazu: die Abschlussregel in `set_plan_gewichte`/`init_plan_gewichte` (4 h Inaktivität). Immer zusammen ändern.
- **Dauerhafter Tausch mitten in der Einheit:** Pausenzeit fällt auf die Profilpause zurück, Anfängerangebot wird für diese Einheit nicht geprüft.
- **Offene UX-Entscheidungen für Tim:** Karte 1.5 nicht wegwischbar, kann mit der Nachholkarte zusammen erscheinen; „Später“ zusätzlich in 1.4/4.2; Anfängerangebot nur einmal je Plan; ungeplante Übungen erscheinen im Training doppelt; Entwurfstexte „Schwerpunkt Po“, „am Gerät 12“ und Titel „Geschafft“ fehlen; Karte folgt nicht dem reinen Such-Studiowechsel in der Geräteliste.
- **Bekannte Tests:** `api-workout-sets` „beendet die eigene Session“ flackert (vorbestehend); der lokale Auth-Dienst ist unter Last langsam und lässt Integrationstests in Hooks timeouten (dann lokale Auth-/REST-Container neu starten); `legePlanStudiosAn` legt je Lauf zwei GYMTAVO-Gerätetypen an (FK `restrict`).
- **Debug-Build der App zeigt auf Prod** (`AppConfig`, `Config.xcconfig`): erste echte Durchläufe nur mit Testkonto.
- Aus Etappe 2 weiter offen: Punkt 7–9 (siehe oben).

### Neu aus Etappe 4

Für Tim:
- **Hinweiswortlaut prüfen:** „Bereich oben erreicht“, „nach deiner Meldung“, „erste Schätzung“, „von ähnlicher Übung“, „Grenze des Geräts“; bei `im_korridor`/`letztes_gewicht` nur die Zahl (z. B. „+2,0 kg“).
- **Manuelle Simulatorprüfung** steht aus und ist erst nach dem Server-Deploy sinnvoll (die App braucht `zielgewichte` aus dem Bootstrap).
- **Hinweis nur im Startdrawer**, nicht auf der Satzseite.
- **`im_korridor`-Hinweis:** Design offen; derzeit nur Zahl ohne Begründung. Der Server kann auch hier eine Änderung senden (z. B. Klemmung an Gerätegrenzen), dann erscheint der Hinweis nur mit Zahl.
- **Tausch mitten in der Einheit:** die neue Position hat kein Ziel (Fallback Kontextvorschlag).
- **Ziele aus einem Tausch verlieren den Stand** (`null`); ein späterer, älterer Abschluss kann sie überschreiben (Randfall, nur eigene Daten).
- **`geschaetzteMinuten` wird nach einem Typ-Tausch nicht neu berechnet** (Folge-Etappe).
- Für den PR-Text: `progression_suggestions` wird für Planübungen nicht mehr befüllt; ohne Plan senkt `problem_gemeldet` nicht mehr (G17).

Technisch (zurückgestellt):
- **`zielSchluessel`-Invariante:** Einheit- und Positionsschlüssel dürfen kein `:` enthalten (Kollision möglich); der Generator erzeugt keins, ist aber nicht abgesichert. iOS baut denselben Schlüssel.
- **Bootstrap-Latenz:** das erste Nachholen nach dem Deploy rechnet bis zu 5 Sessions im Bootstrap-Aufruf; `plan_gewichte` wird je Bootstrap zweimal gelesen. Dauerhaft scheiternde Sessions (z. B. `completed_at` in der Zukunft gegenüber DB-`now()`, `set_plan_gewichte` antwortet `plan_ungueltig`) werden bei jedem Bootstrap neu versucht; Zukunftsstand in `nachzuholendeSessions` überspringen oder Toleranz +1 min.
- **Fehlgeschlagene Kopie beim Tausch** überspringt die Initialisierung und ist nicht nachholbar (`uebernehme` und `init` teilen einen `ohneAbbruch`-Block). `ohneAbbruch` dupliziert die Grund-Formatierung.
- **Regel:** bei Istwert unter `loadMin` liefert die Regel `geraetegrenze_erreicht` auch bei echter Steigerung; `unveraendert()` reicht das alte Ziel ungeklemmt durch (veraltetes Ziel außerhalb geänderter Gerätegrenzen). `wiedereinstieg()` liefert für 8–14 Tage `grund: null`, der Aufrufer muss die Steigerung dort selbst unterdrücken; `startgewichtAusHistorie` filtert keine Aufwärmsätze (nur Arbeitssätze übergeben). `loadStart < loadMin` klemmt auf `loadMin`. Fließkomma: +1e-9-Fall (`loadStart 175, neu 0.7`) ist nicht getestet.
- **Datenbank:** `set_plan_gewichte` prüft nicht `session.plan_id = p_plan_id` und hat kein Obergrenzen-Cap auf `load` (nur eigene Daten). G15 (Einheiten mit Session eingefroren) ist in der DB nicht erzwungen, nur in der Domain-Schicht.
- **Vorschläge:** `ziel.grund = null` ergibt `kein_verlauf` (die App zeigt dann keine Zahl), besser `?? "letztes_gewicht"` (der Code schreibt nie `null`). Ein Fehler in `ladeZieleFuerPaare` lässt Scan und Abschluss-Vorschläge werfen. Ein veraltetes Ziel bei stiller Neuberechnungspanne landet im unveränderlichen `progression_suggestions`-Eintrag. `abschluss.ts` liest `exercises.target_min/max` nur als Existenzcheck. `ort.machine!` im Code. `neuerVorhanden` zählt freies Training als neu. O(n·m)-`find` in `plangewichte.ts`.
- **Tests, schwache Stellen:** Alt-Signatur-Test von `swap_training_plan_position` prüft nur „nicht null“ (besser PGRST202); Bad-Input-Tests ohne `"abc"`, `{}`, fehlendes Feld; die Casts in `0065` hängen an der Reihenfolge der `case when`-Zweige; anon-Test in `rls-plan-gewichte` prüft nur `error != null`; `bootstrap.test.ts` nutzt ein Fake ohne `rpc`; fehlender Test „gleiche Übung, anderes Gerät → keine Kopie“; Historienfenster 43 Tage: vorher > 43 Tage = `null`, `aenderung` null, wenn die letzte Nutzung > 43 Tage her ist; Task 1 (Regel) wurde erst nachträglich rot rekonstruiert, kein echter Red-Lauf.

## Deploy-Reihenfolge

1. Prod braucht `0059`–`0065` **vor** dem API-Deploy. Ohne `0063` fehlt `record_session_plan` (Sätze werden gespeichert, die App-Warteschlange wiederholt endlos); ohne `0064` fehlen `plan_gewichte` und die RPCs.
2. `0065` und der neue Domain-Code gehören zusammen ausgeliefert: die alte 5-Argument-Funktion `swap_training_plan_position` ist weg, der neue Code ruft die 6-Argument-Fassung. Ein alter API-Stand gegen eine Datenbank mit `0065` kann nicht tauschen, ein neuer gegen eine ohne `0065` ebenfalls nicht.
3. Migrationen mit `supabase db push` bzw. `migration up` anwenden, **nicht** von Hand in `schema_migrations` einfügen. Vorher einmal `pnpm supabase db reset` auf einer frischen lokalen Datenbank (lokal wurde `0064` per `docker exec psql` angewandt, weil `supabase migration up` timeoutete; `0060` war nach dem ersten lokalen Lauf von Hand ergänzt worden).
4. `pnpm catalog:import` gegen Prod nur, falls der Katalog noch nicht importiert ist (sonst 422 `kein_geraet`).
5. Nach dem Deploy: erster Bootstrap holt Sessions nach (Latenz, siehe oben); danach manuelle Simulatorprüfung durch Tim.
6. **Alle Prod-Aktionen (Migration, Deploy, Katalogimport, Push, PR, Merge) nur mit ausdrücklicher Freigabe von Tim**, jeweils einzeln. Der Debug-Build der App zeigt auf Prod: Tests nur mit Testkonto.
