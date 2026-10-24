# Trainingsplan Etappe 3 – Übergabe nach Etappe 2

Stand: Etappe 2 (Profil und Plan auf dem Server) ist auf Branch `claude/trainingsplan-etappe2` umgesetzt und reviewt, Migrationen `0059`–`0061` liegen **nur lokal**. Plan: `2026-10-24-trainingsplan-etappe2-profil-und-plan.md`.

## Was es jetzt gibt

- Katalog: `plan`-Objekt je Übung (Baustein, Typ, Bereiche), 46 Übungen belegt (`review` bleibt `draft`; Freigabe durch Tim im PR).
- API: `GET/PUT /api/v1/me/training-profile`, `GET/PUT/DELETE /api/v1/me/training-limits`, `POST/GET /api/v1/me/plans`, `POST /api/v1/me/plans/[id]/accept`.
- Domain: `generierePlan` (Regelversion 1.1.0, rein, deterministisch), `ladeKandidaten`, `erzeugePlanVorschlag`, `acceptPlan`, `listPlaene`.
- Fehlervertrag: 422 mit `error.code` = `profil_unvollstaendig` (`detail.fehlt`) oder `plan_nicht_moeglich` (`detail.baustein`, `detail.grund`); 409 Plan nicht annehmbar / Parallelkonflikt; 404 Studio fremd.
- Plan-Form: `einheiten[].key` (`A`/`B`/`C` oder `OK_A`, `UK_A`, `OK_B`, `UK_B`), `positionen[].key` = Index als String; Schlüssel für Etappe 3: `(plan_id, einheit_key, position_key)`. `eingabe` enthält **keine** Beschwerden, nur `beschwerdenBeruecksichtigt`.

## Offene Punkte für Etappe 3 und später

1. **iOS `APIError.map`** kennt `profil_unvollstaendig` und `plan_nicht_moeglich` nicht (landen sonst in `.server`); beim Bau des Planscreens ergänzen.
2. **Plan-Positionen sind vom Mitglied schreibbar** (Update-Policy, kein Spaltenschutz). Etappe 3 muss `exerciseId`/`machineId` aus `einheiten` als nicht vertrauenswürdig behandeln und gegen das Studio des Plans prüfen. Offene Entscheidung für Tim: Spalten-Update auf `status`/`accepted_at` beschränken (bricht die Konvention „keine Tabellen-Grants“).
3. **Widerruf der Beschwerden** bereinigt Pläne nur in Studios, in denen das Mitglied noch Mitglied ist (Update-Policy prüft Mitgliedschaft). Sauber wäre eine `security definer`-Funktion `bereinige_plaene_nach_widerruf()`.
4. `accept` und `GET` prüfen die Studio-Mitgliedschaft nicht erneut (ehemalige Mitglieder sehen ihren Verlauf, können offene Vorschläge annehmen).
5. `erzeugePlanVorschlag` ist keine Transaktion (verwerfen, Version lesen, einfügen); Worst Case: alter Vorschlag verworfen, Insert scheitert, Mitglied postet erneut.
6. Fill-Positionen tragen Rolle `ergaenzung`, auch wenn es eine zweite Mehrgelenkübung eines Pflichtbausteins ist und sie nach den Isolationsübungen stehen. Option: eigene Rolle `auffuellung` oder Mehrgelenk zuerst (Regelversion erhöhen).
7. Cardio-Position trägt `reserveVon/Bis` und `typ: isolation` ohne Bedeutung; Cardio nimmt immer das erste Gerät (keine Rotation).
8. Fokus kann eine Mehrgelenkübung sein, die eine Isolations-Ergänzung ersetzt (mehr Zeit als die ersetzte Übung).
9. Wochenvolumen-Plausibilitätsprüfung (Spec Abschnitt 3) ist nicht implementiert.
10. Anfängerübergang nach 8 Einheiten und Einheitenzähler (F5) fehlen; Pläne für „neu“ bleiben in Phase 1.
11. Textbausteine zu den Begründungscodes (Etappe 5); `beschwerden_*` folgen der Eingabe, nicht der tatsächlichen Wirkung; `fokus_zweiter_entfallen` ist planweit.
12. Betrieb: Solange `pnpm catalog:import` auf Prod nicht lief, antwortet `POST /me/plans` mit 422 `kein_geraet` (Katalog ohne `plan`). Import direkt nach dem Merge.
13. `bootstrap`: `member.plan` und die Hauptmuskeln aller Studioübungen für F17 stehen noch aus.

## Prod

Reihenfolge: `0059`, `0060`, `0061` (alle additiv) **vor** dem Merge, jeweils mit ausdrücklicher Freigabe von Tim; vorher einmal `pnpm supabase db reset` auf einer frischen lokalen Datenbank (0060 wurde nach dem ersten lokalen Lauf von Hand ergänzt). Danach `pnpm catalog:import` gegen Prod, ebenfalls mit Freigabe.
