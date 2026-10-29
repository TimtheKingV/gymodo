# Trainingsplan Wochenplan-Tab – Übergabe

Stand 28./29.10.2026. Branch `claude/trainingsplan-wochenplan` (Worktree `.claude/worktrees/wochenplan`), Basis `origin/master` (2fc4a4d6). **Nichts gepusht, nichts auf Prod angewendet.**

Plan: `docs/superpowers/plans/2026-10-28-trainingsplan-wochenplan-tab.md`. Design: Leinwand „Trainingsplan Designs“ (Idee 2).

## Was fertig ist

| Task | Inhalt | Commits |
|---|---|---|
| 1 | Wochenlogik `trainingsplan-woche.ts` (`kraftAnzahl`, `verteileKraft`, `pruefeWoche`) | f9c1904 |
| 2 | Profil-Spalten `kurs_tage`, `cardio_tage`, `cardio_arten`, `kraft_tage` (Migration 0069) | f8d49b3 |
| 3 | Generator plant um feste Kurs-/Cardio-Tage, `wochenraster` am Plan, Regelversion 1.3.0, Migration 0070 (`create_training_plan` mit `p_wochenraster`) | ce4e27d, 59c6d5d |
| 4 | Cardio abhaken (Migration 0071, `/me/cardio-checks`) | 98e8ac7 |
| 5 | iOS-Modelle und `PlanWoche` | c200992, 1c85233 |
| 6 | Plan-Tab statt Kurse-Tab | 4619dbe, 5eae366 |
| 7 | Onboarding: Kurse, Cardio, Deine Woche | f8df56b, 9feb0b1 |
| 8 | Home: „Heute dran“ plus Wochenkarte | b7af8b5 |
| Final | Review-Fixes: 0070 mit Default, Rechte auf `cardio_checks`, Bestandspläne, Home folgt der Folge | f07d56a, d52f87d |

## Prod-Stand und Freigaben (alle noch offen, einzeln bei Tim einholen)

Migrationen **0069, 0070 und 0071** (nicht nur 0069/0070 wie im Plan) sind nur lokal von Hand per psql angewandt. Prod steht bei 0065 (laut Notiz) bzw. dem letzten Stand von master.

Reihenfolge:

1. Migrationen 0069, 0070, 0071 auf Prod (je Freigabe).
2. Sofort danach API-Deploy. 0070 hat `p_wochenraster` mit Default, die alte API läuft also auch in der Lücke weiter; ein Rollback der API ist ebenfalls gefahrlos.
3. Erst danach die iOS-App ausliefern: gegen eine alte API verwirft der Server die neuen Profilfelder still, und die Cardio-Routen liefern 404.
4. Vorher auf Prod zählen: aktive Pläne mit `wochenraster = '[]'` (Bestandspläne, siehe unten).
5. Nach 0071 Rechte prüfen: `\dp public.cardio_checks` (kein `update`/`truncate` für `authenticated`, nichts für `anon`).

## Vor dem Merge zu prüfen

- `supabase db reset` von Null mit 0069 bis 0071 und `pnpm smoke:migrations`. Lokal scheitert `supabase db reset` an der CLI-Konfiguration (CLI 2.116.0, `CliConfigParseError`), die Migrationen sind nie von Null gelaufen.
- `domain-bootstrap` und `domain-plangewichte` liefen unter hoher Rechnerlast nie komplett grün durch; einmal sauber wiederholen.
- Simulator-Durchklick mit Testkonto (Debug-Build zeigt auf Prod, es gibt kein Testkonto in Seed/Fixtures): Bestandsnutzer mit Plan, Kurs-Filter, ohne Studio, Sonntag mit Cardio, Einplanen, frisches Onboarding mit und ohne Studio, Home mit und ohne Plan.

## Entscheidungen (Rulings) – bitte überfliegen

- Migrationsnummern: Task 3 hat 0070 belegt, Cardio-Checks heißen deshalb `0071_cardio_checks.sql`.
- Cardio-Checks: `validation_failed` ist im Repo 422, nicht 400.
- Kurs ∪ Cardio dürfen nicht alle 7 Tage belegen (`keine_freien_tage`); das Onboarding sperrt den siebten Tag lokal.
- Gebuchte Kurse sind im Plan immer sichtbar, auch ohne Kurs-Rasterplatz.
- Anzeige-Raster im Plan-Tab: Profilfeld je Art, wenn gesetzt (leer = nicht gesetzt), sonst Planraster. `plan.wochenraster` bleibt stabil (F14).
- Onboarding: Reihenfolge Beschwerden → Kurse (nur mit Studio) → Cardio → Deine Woche → Vorschau; zwei `createPlan` pro Durchlauf (der zweite verwirft den ersten Vorschlag serverseitig); „Tauschen“ = Krafttag ↔ freier Tag; Schrittzähler dynamisch statt „von 8“; keine Kursauswahl „Welche?“ (kein Profilfeld).
- Home: „Training starten“ als SecondaryButton und Akzent-Outline für heute (eine Akzentfläche pro Screen); Kraft-Felder neutral mit Symbol statt Rasterbuchstabe; „Als nächstes“ nennt die Einheit der Folge (F5).
- Bestandspläne (`wochenraster = '[]'`, leeres Profil): Plan-Tab zeigt „Lege deine Trainingstage fest“ mit Button ins Einplanen-Sheet, Home zeigt „Trainingstage festlegen“. Kein Backfill, die App rechnet keine Tage selbst (F15).

## Offene Produktentscheidungen für Tim

- **I4:** Einmal gespeicherte `kraft_tage` überstimmen eine spätere Änderung von „Tage pro Woche“ (der Generator richtet sich nach `kraftTage.length`). Zudem kann „Einplanen“ die Zahl der Krafttage über die Regel `weekly_days − |Kurs ∪ Cardio|` hinaus erhöhen. Optionen: Generator nimmt `kraftTage` nur bei passender Anzahl, oder Server leert `kraft_tage` beim Ändern des Ziels.
- Sollen Einheiten im Plan als „erledigt“ gelten? Dafür fehlt eine Datenquelle (Sessions tragen keinen Einheit-Key).

## Offen (später)

- Cardio: Umfang und Tempo, Kurs-Art im Plan, Strava/Health.
- Gemerkte Minors: `sessionId` in `PlanTermin.kurs` (gleichnamige Kurse zur selben Minute), Studio-Filter im Plan-Modus, toleranter Decode unbekannter `art`-Werte, SQL-Check der Rasterelemente, Kraft+Kurs am selben Tag im Anzeige-Raster nach Onboarding-Abbruch (M2), Grenztest `heute+1/+2` bei Cardio-Checks, GET-Bereichslimit, Mitternachtswechsel auf Home, Flow-Tests für das Onboarding, Previews der neuen Schritte, Test-Helper räumt Katalogmodelle nicht auf (lokale DB sammelt sie an).
