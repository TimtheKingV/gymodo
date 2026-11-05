# Trainingsplan Etappe 4 – Übergabe nach Etappe 3

Stand: Etappe 3 (Plan im Studio, iOS) ist auf Branch `claude/trainingsplan-etappe3` umgesetzt und reviewt (21 + 4 Commits, nicht gepusht). Migrationen `0062` und `0063` liegen **nur lokal**; Prod hat laut Memory bis `0061`. Plan: `2026-10-24-trainingsplan-etappe3-plan-im-studio.md`.

## Was es jetzt gibt

- **Regeln 1.2.0:** Rolle `auffuellung`, Anzeigereihenfolge (Mehrgelenk vor Isolation, Cardio zuletzt, Schlüssel = Index), `anfaengerBeendet` (Erfahrung „neu“ plant nach 8 Einheiten wie „unregelmäßig“).
- **Schreibwege (0062):** `training_plans` ist nur noch per `security definer`-RPC beschreibbar (`create_training_plan`, `accept_training_plan`, `swap_training_plan_position`; `training_plan_pruefen` intern). Widerruf der Beschwerden bereinigt über einen Trigger die Pläne aller Studios. API: `POST /me/plans/[id]/swap`.
- **Session ↔ Planeinheit (0063):** `workout_sessions.plan_id/plan_einheit_key/plan_stand`, Tabelle `session_plan_status`, RPC `record_session_plan` (nur höherer `stand` gewinnt). Der Satz-PUT nimmt `plan` an; Planfehler ergeben 200 mit `planUebernommen: false`, nur flüchtige Fehler 5xx.
- **Bootstrap:** `member.trainingProfile` und `member.plans[]` (Plan, `naechsteEinheitKey`, `zuletztEinheitKey`, `einheitenErledigt`, `anfaengerUebergang`, `alternativen` je Baustein, ohne Beschwerdendaten). Fällt der Planteil aus, kommt `plans: []`.
- **iOS:** Onboarding-Block (Schritte 1.1–1.4, Fehlerzustände), Home-Karte „Plan einrichten“, Plankarte „heute dran“ mit Ablaufstatus (offline, `TrainingsplanAblauf` gegen `packages/domain/fixtures/plan-ablauf.json`), Positions-Sheet und Tausch (heute / dauerhaft), Anfängerangebot nach Einheit 8, Platzhalterseite „Warum so?“, Profilzeile „Beschwerden“ (Einwilligung widerrufen; **über die freigegebenen Entwürfe hinaus**), Pausenzeit aus der Planposition (F6).

## Schnittstellen für Etappe 4 (Gewichte)

- Zielbereich und Zielreserve stehen an der Planposition (`wdhVon/Bis`, `reserveVon/Bis`, `saetze`, `pauseSek`); die App zeigt sie nur an. Die Progression (`progression.ts`) nutzt sie noch nicht.
- Die Session kennt Plan und Einheit (`workout_sessions.plan_id`, `plan_einheit_key`) und je Position den Status. Daraus lässt sich in Etappe 4 das Vorschlagsprotokoll um Planversion und Übertragungskorrektur erweitern.
- Lasthistorie bleibt je Gerätemodell + Übung.

## Offene Punkte

1. **Deploy-Reihenfolge:** `0059`–`0063` auf Prod **vor** dem API-Deploy (Neuer Server ohne `0063`: `record_session_plan` fehlt → Sätze werden gespeichert, die App-Warteschlange wiederholt endlos). Alle Prod-Schritte nur mit ausdrücklicher Freigabe von Tim; danach `pnpm catalog:import` nur falls nötig.
2. **Tausch über die Typgrenze:** `swap_training_plan_position` übernimmt `typ`, Wiederholungsbereich und Pause der alten Position (Mehrgelenk → Isolation trainiert mit Mehrgelenk-Vorgabe). Bei Etappe 4/5 klären.
3. **`completeSession` läuft nicht über die Warteschlange:** Wer offline beendet, sieht „heute dran“ bis zum Server-Abschluss (≤ 4 h) mit lokaler Zählung; die lokale Zählung hält jetzt, bis der Server die Einheit zählt oder 4 h vergangen sind.
4. **Drei gekoppelte 4-Stunden-Konstanten:** `packages/domain/src/sessions.ts` (`IDLE_HOURS_UNTIL_AUTO_COMPLETE`), `trainingsplan-bootstrap.ts` (Stillstand) und `WorkoutSessionStore.sessionPause`. Immer zusammen ändern.
5. **Nach dauerhaftem Tausch mitten in der Einheit** fällt die Pausenzeit bis zum Ende der Einheit auf die Profilpause zurück, und das Anfängerangebot wird für diese Einheit nicht geprüft (Planversion der Session ≠ Bootstrap).
6. **Offene UX-Entscheidungen für Tim:** Karte 1.5 nicht wegwischbar und kann mit der Nachholkarte zusammen erscheinen; „Später“ zusätzlich in 1.4/4.2; Anfängerangebot nur einmal je Plan (kein späterer Einstieg); ungeplante Übungen erscheinen im Training doppelt (Plankarte und Blockliste); Entwurfstexte „Schwerpunkt Po“, „am Gerät 12“ und Titel „Geschafft“ fehlen; Karte folgt nicht dem reinen Such-Studiowechsel in der Geräteliste.
7. **Bekannte Tests:** `api-workout-sets` „beendet die eigene Session“ flackert (vorbestehend); lokaler Auth-Dienst (gotrue) ist unter Last langsam (`/admin/users` 10–16 s) und lässt Integrationstests in Hooks timeouten; `legePlanStudiosAn` legt je Lauf zwei GYMTAVO-Gerätetypen an (FK `restrict`).
8. **Debug-Build der App zeigt auf Prod** (`AppConfig`, `Config.xcconfig`): erste echte Durchläufe nur mit Testkonto.
9. **Textbausteine (Etappe 5):** `PlanWarumView` zeigt bisher nur die Begründungscodes; `beschwerden_*` und `fokus_zweiter_entfallen` bleiben wie in der Etappe-2-Übergabe beschrieben.
10. Aus der Etappe-2-Übergabe weiter offen: Punkt 7 (Cardio-Felder ohne Bedeutung, immer das erste Cardiogerät), 8 (Fokus-Mehrgelenk ersetzt Isolation), 9 (Wochenvolumen-Prüfung).
