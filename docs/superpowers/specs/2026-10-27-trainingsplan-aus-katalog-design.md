# Trainingsplan aus dem Gymtavo-Katalog – Design

Stand: 27.10.2026. Entscheidungen im Gespräch mit Tim (Brainstorming). Baut auf `2026-10-21-trainingsplan-design.md` und `2026-10-25-trainingsplan-plangewichte-design.md` auf und **ersetzt deren Studio-Bindung (F20)**.

## Warum

Der Trainingsplan (Etappe 1–5, auf `master`) gehört heute einem echten Studio und wird aus dessen Geräten gebaut. Tim will das Training auch komplett nur mit „Gymtavo“ bzw. im Freien Training nutzen können: dort sind alle von uns gepflegten Übungen und Geräte, aber das Katalog-Studio hat keine Geräte (Prod am 27.10.: Studio „Gymtavo“ `is_catalog`, 0 Zeilen in `machines`, dafür 114 Katalogprodukte, 180 Übungen, 218 Modell-Übungs-Zuordnungen). Heute kann dort kein Plan entstehen. Zusätzlich: ein Mitglied hat nicht je Studio einen anderen Plan, das ist ein Randfall. Entscheidend für das Training ist die **Art der Übung**, nicht das konkrete Gerät.

## Entscheidungen von Tim

1. **Ein Plan je Mitglied, immer am Gymtavo-Katalog.** Es gibt keinen Studioplan mehr und keinen zweiten Plan daneben. Der Katalog ist die Grundlage, egal wo das Mitglied trainiert.
2. **Eine Planposition ist eine Übungsart, kein Gerät.** Welches Gerät (z. B. welches Butterfly) das Mitglied nimmt, ist egal. Gibt es die Übung in seinem Studio nicht, überspringt es sie.
3. **Übung entfernen, mit Grund.** Entfernt das Mitglied eine Übung aus dem Plan, fragt die App kurz nach dem Grund und bietet eine Alternative desselben Bausteins aus dem Katalog an:
   - **Nicht vorhanden:** die Übung wird am **aktiven Ort** nie wieder angeboten, nicht je Mitglied überall. Ort ist ein Studio oder das Freie Training; das Freie Training zählt als eigener Ort, die Antwort wird also auch dort gespeichert und gilt nur dort.
   - **Gefällt mir nicht:** die Übung ist nie mehr erste Wahl und nur noch optionale Alternative.
   - **Belegt:** die Standardoption.
4. **Gewicht hängt an der Übung, nicht am Gerät.** Grenzen und Stufen kommen vom Katalogmodell. Der nächste Zielwert rechnet aus dem letzten Satz dieser Übung, egal an welchem Gerät, auch aus dem Freien Training.
5. Die Karte „Plan einrichten“ gibt es auch im Freien Training, nicht nur mit aktivem Studio.

Von Claude gedeutet, Tim hat nicht widersprochen: „Belegt“ heißt nur heute ersetzen, nichts merken. „Gefällt mir nicht“ gilt für das Mitglied überall. „Nicht vorhanden“ im Freien Training: von Tim bestätigt, das Freie Training ist ein eigener Ort.

## Entscheidungen von Claude (Prüfung des Entwurfs, Tim kann widersprechen)

- **Harter Wechsel:** Bestehende Pläne (Prod hat keine, lokale und Testpläne zählen nicht) werden verworfen und neu erzeugt. Kein Doppelformat, keine Backfill-Migration, `machineId`-Positionen müssen nicht weiter lesbar bleiben.
- **Die Merkliste sperrt Übungen, keine Modelle:** Eine Position ist eine Übungsart. „Nicht vorhanden“ und „gefällt mir nicht“ gelten für die Übung (`exercise_id`), auch wenn mehrere Modelle sie anbieten.
- **Ein Zähler:** Es gibt einen Plan, deshalb zählen Katalog- und Studio-Sessions für Einheitenzähler und Anfängerübergang (nach 8 Einheiten) gemeinsam.
- **Auslieferbare Schnitte:** Jede Etappe muss einzeln auslieferbar sein, solange Prod bei `0065` steht. Reihenfolge: Datenbank und Server zuerst (nur mit Freigabe von Tim), dann die App. Weil Prod keine Pläne hat, ist ein alter Server mit neuer App der einzige Mischzustand, den die Planung abdecken muss.
- **Gewicht modellübergreifend:** Tim hat bestätigt, dass das Zielgewicht an der Übung hängt, auch wenn Gewichtsstapel verschieden skaliert sind. Schwankungen zwischen Geräten werden hingenommen. Startwert ohne Verlauf (z. B. `load_start` des Katalogmodells, Modellwahl bei mehreren Modellen) legt der Planer fest; braucht es dafür eine neue Regelversion, ist das so.

## Ziele

- Ein Mitglied ohne Studio bekommt einen Plan und kann ihn vollständig im Freien Training abarbeiten.
- Alles, was Etappe 3–5 liefern, bleibt für den Katalogplan erhalten: Einheitenfolge, Ablauf und Fortschritt, Tausch, Anfängerübergang nach 8 Einheiten, Zielgewichte mit Wiedereinstieg, „Warum so?“.
- Eine abgelehnte Übung („nicht vorhanden“ im Studio, „gefällt mir nicht“) taucht nicht wieder als erste Wahl auf.

## Nicht-Ziele

- Studiospezifische Pläne, ein Plan je Studio, Wechsel zwischen mehreren Plänen.
- Empfehlung oder Zuordnung eines bestimmten Geräts zur Position.
- Startcoach mit Testsätzen, Wochenvolumen-Prüfung, andere offene Punkte aus der Übergabe `2026-10-27-trainingsplan-nach-etappe5-uebergabe.md`.

## Anti-Ziele (wäre ein Misserfolg, auch wenn es technisch läuft)

- Das Mitglied bekommt Übungen, die es in seinem Studio nicht ausführen kann, und hat keinen schnellen Ausweg.
- Die Zielgewichte springen oder werden unsinnig, weil Sätze ohne Gerät (Freies Training) oder verschiedene Geräte gemischt werden.
- „Nie wieder anbieten“ gilt nicht oder gilt im falschen Studio.
- Bestehende Funktionen aus Etappe 3–5 gehen verloren oder Prod-Daten werden beschädigt.

## Randbedingungen

- Regeln laufen nur serverseitig (F15), die App rechnet nichts. Versionierte Regeln: neue Version, wo sich die Rechnung ändert.
- Prod-Stand: Datenbank bis Migration `0065`, **kein einziger Plan** in Prod (27.10. geprüft; vor Beginn erneut prüfen). Neue Migrationen ab `0066`. `supabase db push` geht gegen Prod nicht (Zeitstempel-Versionen 0057–0061), Prod-Migrationen nur mit ausdrücklicher Freigabe von Tim, jeweils einzeln.
- Datenschutz: Beschwerden und Merkliste bleiben beim Mitglied, nicht in Log, Testnotiz-Kontext oder Analyse.
- Der Debug-Build der iOS-App zeigt auf Prod: Tests nur mit Testkonto.
- Die „Warum so?“-Texte (`PlanWarumText`) nennen „dein Studio“ (z. B. `zeit_budget_nicht_ausgeschoepft`, `abnehmen_kein_cardio_geraet`); sie müssen zum Katalogplan passen.

## Befund aus dem Code (gelesen, nicht ausgeführt; als Eingabe für die Planung)

- `training_plans.studio_id` ist NOT NULL (Migration 0061); Unique je `(user_id, studio_id)` für aktiven Plan und Vorschlag. Insert/Update-Policies verlangen `is_studio_member(studio_id)`; das Katalog-Studio hat bewusst keine Mitgliedschaft (0047). **Das Freie Training läuft schon im Katalog-Studio** (Sessions und Sätze dort ohne Mitgliedschaft, `workout_sets.machine_id` nullable, `equipment_model_id` gesetzt). Ein Plan mit der Katalog-Studio-ID als `studio_id` passt deshalb zu Sessions, `record_session_plan` und `plan_gewichte` (Idee, nicht getestet).
- `training_plan_pruefen` (0062) und das Tausch-RPC (0065) prüfen Positionen gegen `machines` des Studios; Positionen sind JSON mit `machineId`/`exerciseId`. Für Katalogpläne braucht es eine Positionsform mit Modell statt Gerät und angepasste Prüfung und Tausch.
- Der Generator ist geräteneutral; die einzige Geräte-Eingabe ist `ladeKandidaten` (`trainingsplan-kandidaten.ts`). Baustein, Typ, Bereiche und Muskeln hängen schon an `exercises`. Katalogzweig über `equipment_models` fehlt.
- Zielgewichte (`plangewichte.ts`): Schlüssel `${machineId}:${exerciseId}`, Satzverlauf mit Filter `machine_id is not null`, Grenzen aus `machines → equipment_models(load_step, load_min, load_max, load_start)`. Sätze des Freien Trainings sind damit unsichtbar. Umstellung auf Übung/Modell nötig; ob `plangewicht-start.ts` ohne Geräteverlauf brauchbare Startwerte liefert, ist ungeprüft.
- Bootstrap und Plan-Ausspielung finden Pläne über `studio_memberships` (`trainingsplan.ts`, `trainingsplan-bootstrap.ts`); Katalogpläne fehlen dort.
- iOS: `PlanEinrichten.zeigtKarte`, `PlanAnzeige`, `PlanKarte`, `TrainingsplanAblaufStore` (mit persistierter Datei), `PlanTausch` und die Bildzuordnung über Geräte hängen an `activeStudioId`, im Freien Training `nil`.
- Eine Merkliste gibt es nicht. Nächstes Vorbild: `training_limits` (Beschwerden, 0060, Policy „eigene Zeilen“) und der Filter `filtereKandidaten` in `trainingsplan-auswahl.ts`.

## Dem Planer überlassen

Positionsform im Plan (z. B. Modell-ID statt Gerät-ID) und wie die Position eindeutig heißt; ob die Katalog-Studio-ID als `studio_id` dient oder eine andere Lösung besser ist; Schema und Policy der Merkliste und ihre Aufnahme in den Bootstrap; Schlüssel und Verlauf der Zielgewichte je Übung samt Startschätzung ohne Geräteverlauf; Umgang mit einem Mitglied, das später einem Studio beitritt oder wechselt (Zähler `ladeGezaehlteEinheiten`); wie „überspringen“ im Ablauf von „optional“ abgegrenzt wird; Anzeige der Bilder ohne Gerät; Reihenfolge und Zuschnitt in Etappen; ob Texte der Etappe 5 angepasst werden.
