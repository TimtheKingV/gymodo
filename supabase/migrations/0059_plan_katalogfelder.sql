-- Katalogfelder fuer Trainingsplaene, Spec Trainingsplan Abschnitte 2, 7, 8.
--
-- Der Generator waehlt Uebungen je Baustein und Typ und sperrt sie bei
-- Beschwerden ueber die belasteten Bereiche. Diese Angaben sind redaktionell
-- und kommen mit dem Katalogimport, nicht von Mitgliedern -- deshalb Spalten
-- an exercises statt einer eigenen Tabelle.
--
-- plan_baustein und plan_typ gehoeren zusammen: beide gesetzt = die Uebung
-- ist fuer Plaene freigegeben, beide null = nicht. Eine halbe Angabe wuerde
-- der Generator stillschweigend uebergehen; der Check macht sie unmoeglich.
-- Die Werte spiegeln packages/domain/src/trainingsplan-typen.ts; Checks statt
-- Enum-Typen, damit eine neue Sorte keine Typ-Migration braucht.
--
-- Keine neue Policy: exercises hat seine Lesezugriffe bereits, die Spalten
-- erben sie.

alter table public.exercises
  add column plan_baustein text,
  add column plan_typ text,
  add column plan_bereiche text[] not null default '{}';

alter table public.exercises
  add constraint exercises_plan_baustein_check check (
    plan_baustein is null or plan_baustein in (
      'beine_knie', 'beine_huefte', 'druecken', 'ziehen', 'schulter',
      'arme', 'rumpf', 'beine_ergaenzung', 'cardio'
    )
  ),
  add constraint exercises_plan_typ_check check (
    plan_typ is null or plan_typ in ('mehrgelenk', 'isolation')
  ),
  add constraint exercises_plan_paar_check check (
    (plan_baustein is null) = (plan_typ is null)
  ),
  add constraint exercises_plan_bereiche_check check (
    plan_bereiche <@ array['knie', 'huefte', 'unterer_ruecken', 'schulter', 'ellenbogen_handgelenk']
  );
